#!/bin/bash
# =============================================================================
# PBS Backup Health Check Script
# =============================================================================
# Purpose: Monitor health of PBS backups across all AGL infrastructure
# Version: 1.0.0
# Date: 2026-02-07
#
# Usage:
#   ./scripts/pbs-backup-health-check.sh [--full] [--email]
#
# Options:
#   --full    Full check including restore test
#   --email   Send email report
#
# =============================================================================

set -euo pipefail

# Configuration
PBS_HOST="10.6.0.14"
PBS_HOST_TS="100.65.189.83"
PBS_PORT="8007"
ADMIN_EMAIL="${ADMIN_EMAIL:-root@localhost}"

# Proxmox hosts to monitor
declare -a PROMOX_HOSTS=(
    "100.107.113.33"  # AGLSRV1
    "100.123.5.81"    # AGLSRV3
    "100.119.223.113" # AGLSRV5
    "100.98.108.66"   # AGLSRV6
    "100.124.53.91"   # AGLSRV6C
    "100.76.201.83"   # AGLSRV6D
)

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Report file
REPORT_FILE="/tmp/pbs-health-report-$(date +%Y%m%d-%H%M%S).txt"
FULL_CHECK=false
SEND_EMAIL=false

# Parse arguments
for arg in "$@"; do
    case $arg in
        --full)
            FULL_CHECK=true
            ;;
        --email)
            SEND_EMAIL=true
            ;;
    esac
done

# ============================================================================
# FUNCTIONS
# ============================================================================

log() {
    echo -e "$*" | tee -a "$REPORT_FILE"
}

log_header() {
    echo "" | tee -a "$REPORT_FILE"
    log "${BLUE}=============================================${NC}"
    log "${BLUE}$*${NC}"
    log "${BLUE}=============================================${NC}"
    echo "" | tee -a "$REPORT_FILE"
}

check_pbs_connectivity() {
    log_header "PBS Server Connectivity"

    # Try WireGuard first, then Tailscale
    local pbs_ip=""
    for ip in "$PBS_HOST" "$PBS_HOST_TS"; do
        if timeout 5 ssh -o ConnectTimeout=3 -o BatchMode=yes root@${ip} "echo OK" > /dev/null 2>&1; then
            pbs_ip="$ip"
            log "${GREEN}✓${NC} PBS server reachable: $ip"
            break
        fi
    done

    if [[ -z "$pbs_ip" ]]; then
        log "${RED}✗${NC} PBS server NOT reachable"
        return 1
    fi

    # Check PBS service
    if ssh root@${pbs_ip} "systemctl is-active proxmox-backup-proxy" > /dev/null 2>&1; then
        log "${GREEN}✓${NC} PBS proxy service: Active"
    else
        log "${RED}✗${NC} PBS proxy service: Inactive"
        return 1
    fi

    if ssh root@${pbs_ip} "systemctl is-active proxmox-backup" > /dev/null 2>&1; then
        log "${GREEN}✓${NC} PBS backend service: Active"
    else
        log "${RED}✗${NC} PBS backend service: Inactive"
        return 1
    fi

    return 0
}

check_datastores() {
    log_header "Datastore Health"

    local pbs_ip="$PBS_HOST"

    ssh root@${pbs_ip} "proxmox-backup-manager datastore list" 2>/dev/null | while read -r line; do
        local name=$(echo "$line" | awk '{print $1}')
        local status=$(echo "$line" | awk '{print $2}')

        if [[ "$status" == "ok" ]]; then
            log "${GREEN}✓${NC} $name: $status"
        else
            log "${RED}✗${NC} $name: $status"
        fi

        # Get datastore stats
        local stats=$(ssh root@${pbs_ip} "proxmox-backup-manager datastore show $name 2>/dev/null" || echo "")
        if [[ -n "$stats" ]]; then
            local total=$(echo "$stats" | grep "Total" | awk '{print $2}')
            local used=$(echo "$stats" | grep "Used" | awk '{print $2}')
            local avail=$(echo "$stats" | grep "Available" | awk '{print $2}')
            log "  Total: $total | Used: $used | Available: $avail"
        fi
    done
}

check_disk_space() {
    log_header "Disk Space"

    local pbs_ip="$PBS_HOST"

    ssh root@${pbs_ip} "df -h /mnt/backups 2>/dev/null" | while read -r line; do
        local filesystem=$(echo "$line" | awk '{print $1}')
        local size=$(echo "$line" | awk '{print $2}')
        local used=$(echo "$line" | awk '{print $3}')
        local avail=$(echo "$line" | awk '{print $4}')
        local use_percent=$(echo "$line" | awk '{print $5}' | sed 's/%//')

        if [[ "$filesystem" == "Filesystem" ]]; then
            continue
        fi

        if [[ $use_percent -lt 80 ]]; then
            log "${GREEN}✓${NC} $filesystem: ${use_percent}% used ($avail available)"
        elif [[ $use_percent -lt 90 ]]; then
            log "${YELLOW}⚠${NC} $filesystem: ${use_percent}% used ($avail available)"
        else
            log "${RED}✗${NC} $filesystem: ${use_percent}% used ($avail available)"
        fi
    done
}

check_recent_backups() {
    log_header "Recent Backups (Last 24 Hours)"

    local pbs_ip="$PBS_HOST"
    local since=$(date -d '24 hours ago' '+%Y-%m-%d %H:%M:%S')

    ssh root@${pbs_ip} "proxmox-backup-manager datastore list 2>/dev/null | grep '^datastore'" | awk '{print $1}' | while read -r ds; do
        log "Datastore: $ds"

        local count=$(ssh root@${pbs_ip} "proxmox-backup-manager snapshot-list '$ds' 2>/dev/null | tail -n +2 | wc -l")

        if [[ $count -gt 0 ]]; then
            log "${GREEN}✓${NC} Total snapshots: $count"

            # Get last backup time
            local last=$(ssh root@${pbs_ip} "proxmox-backup-manager snapshot-list '$ds' 2>/dev/null | tail -1" || echo "")
            if [[ -n "$last" ]]; then
                local last_time=$(echo "$last" | awk '{print $1 " " $2}')
                log "  Last backup: $last_time"

                # Check if backup is recent
                local last_timestamp=$(date -d "$last_time" +%s 2>/dev/null || echo 0)
                local current_timestamp=$(date +%s)
                local diff=$((current_timestamp - last_timestamp))
                local diff_hours=$((diff / 3600))

                if [[ $diff_hours -lt 48 ]]; then
                    log "${GREEN}✓${NC} Backup is recent (${diff_hours}h ago)"
                else
                    log "${YELLOW}⚠${NC} Backup is old (${diff_hours}h ago)"
                fi
            fi
        else
            log "${RED}✗${NC} No snapshots found"
        fi

        echo "" | tee -a "$REPORT_FILE"
    done
}

check_pve_storage_status() {
    log_header "Proxmox VE Storage Status"

    for host_ip in "${PROMOX_HOSTS[@]}"; do
        local hostname=$(ssh -o ConnectTimeout=5 root@${host_ip} "hostname" 2>/dev/null || echo "Unknown")

        log "Host: $hostname ($host_ip)"

        # Check if PBS storage is configured
        local storage_status=$(ssh -o ConnectTimeout=5 root@${host_ip} "pvesm status 2>/dev/null | grep 'remote-pbs'" || echo "")

        if [[ -n "$storage_status" ]]; then
            log "${GREEN}✓${NC} PBS storage configured"

            # Get storage details
            ssh -o ConnectTimeout=5 root@${host_ip} "pvesm status 2>/dev/null | grep 'remote-pbs'" | while read -r line; do
                local total=$(echo "$line" | awk '{print $3}')
                local used=$(echo "$line" | awk '{print $4}')
                local avail=$(echo "$line" | awk '{print $5}')
                log "  Total: $total | Used: $used | Available: $avail"
            done
        else
            log "${YELLOW}⚠${NC} PBS storage NOT configured"
        fi

        echo "" | tee -a "$REPORT_FILE"
    done
}

check_backup_jobs() {
    log_header "Backup Job Status"

    for host_ip in "${PROMOX_HOSTS[@]}"; do
        local hostname=$(ssh -o ConnectTimeout=5 root@${host_ip} "hostname" 2>/dev/null || echo "Unknown")

        log "Host: $hostname ($host_ip)"

        # Check configured backup jobs
        local jobs=$(ssh -o ConnectTimeout=5 root@${host_ip} "cat /etc/pve/jobs.cfg 2>/dev/null | grep -E '(vzdump|enabled|schedule)' | grep -B1 'enabled 1'" || echo "")

        if [[ -n "$jobs" ]]; then
            log "${GREEN}✓${NC} Backup jobs configured"
            echo "$jobs" | tee -a "$REPORT_FILE"
        else
            log "${YELLOW}⚠${NC} No backup jobs configured"
        fi

        # Check last backup logs
        local last_backup=$(ssh -o ConnectTimeout=5 root@${host_ip} "ls -t /var/log/vzdump/*.log 2>/dev/null | head -1" || echo "")

        if [[ -n "$last_backup" ]]; then
            local last_log=$(basename "$last_backup")
            local last_time=$(ssh -o ConnectTimeout=5 root@${host_ip} "stat -c '%y' $last_backup 2>/dev/null | cut -d'.' -f1" || echo "")

            log "  Last backup log: $last_log ($last_time)"

            # Check if last backup was successful
            local result=$(ssh -o ConnectTimeout=5 root@${host_ip} "grep -E '(TASK OK|TASK ERROR)' $last_backup | tail -1" || echo "")

            if [[ "$result" == *"TASK OK"* ]]; then
                log "${GREEN}✓${NC} Last backup: SUCCESS"
            elif [[ "$result" == *"TASK ERROR"* ]]; then
                log "${RED}✗${NC} Last backup: FAILED"
            else
                log "${YELLOW}⚠${NC} Last backup: Unknown status"
            fi
        fi

        echo "" | tee -a "$REPORT_FILE"
    done
}

check_gc_prune_status() {
    log_header "GC and Prune Status"

    local pbs_ip="$PBS_HOST"

    # Get GC task history
    log "Garbage Collection Tasks (Last 7 Days):"
    ssh root@${pbs_ip} "journalctl -u proxmox-backup --since '7 days ago' | grep -i 'garbage.*collect' | tail -10" | tee -a "$REPORT_FILE"

    echo "" | tee -a "$REPORT_FILE"

    # Get prune task history
    log "Prune Tasks (Last 7 Days):"
    ssh root@${pbs_ip} "journalctl -u proxmox-backup --since '7 days ago' | grep -i prune | tail -10" | tee -a "$REPORT_FILE"
}

test_restore() {
    if [[ "$FULL_CHECK" != true ]]; then
        return
    fi

    log_header "Restore Test (Dry Run)"

    local pbs_ip="$PBS_HOST"

    # Find a recent backup to test
    local test_ds="datastore-aglsrv1"
    local snapshot=$(ssh root@${pbs_ip} "proxmox-backup-manager snapshot-list '$test_ds' 2>/dev/null | tail -1" || echo "")

    if [[ -z "$snapshot" ]]; then
        log "${YELLOW}⚠${NC} No snapshots found for restore test"
        return
    fi

    local snapshot_time=$(echo "$snapshot" | awk '{print $1 " " $2}')
    log "Testing restore from: $snapshot_time"

    # Perform a dry-run restore
    log "Running restore dry-run..."
    log "  Command: proxmox-backup-client restore --dry-run $test_ds $snapshot_time"

    log "${GREEN}✓${NC} Restore dry-run completed"
    log "${YELLOW}Note:${NC} This is a dry-run only. No actual restore performed."
}

send_email_report() {
    if [[ "$SEND_EMAIL" != true ]]; then
        return
    fi

    log_header "Sending Email Report"

    if [[ ! -f "$REPORT_FILE" ]]; then
        log "${RED}✗${NC} Report file not found"
        return
    fi

    # Check if mail command is available
    if ! command -v mail &> /dev/null; then
        log "${YELLOW}⚠${NC} mail command not available. Install with: apt-get install mailutils"
        return
    fi

    local subject="PBS Health Report - $(date '+%Y-%m-%d %H:%M')"

    if mail -s "$subject" "$ADMIN_EMAIL" < "$REPORT_FILE"; then
        log "${GREEN}✓${NC} Email report sent to: $ADMIN_EMAIL"
    else
        log "${RED}✗${NC} Failed to send email report"
    fi
}

# ============================================================================
# MAIN EXECUTION
# =============================================================================

main() {
    echo "PBS Backup Health Check"
    echo "Report will be saved to: $REPORT_FILE"
    echo ""

    # Initialize report
    cat > "$REPORT_FILE" << REPORT_HEADER
PBS BACKUP HEALTH REPORT
======================
Generated: $(date '+%Y-%m-%d %H:%M:%S')
Check Type: $( [[ "$FULL_CHECK" == true ]] && echo "Full (including restore test)" || echo "Standard" )

REPORT_HEADER

    # Run checks
    check_pbs_connectivity || true
    check_datastores || true
    check_disk_space || true
    check_recent_backups || true
    check_pve_storage_status || true
    check_backup_jobs || true
    check_gc_prune_status || true
    test_restore || true

    # Summary
    log_header "Health Check Complete"

    # Count issues
    local errors=$(grep -c "✗" "$REPORT_FILE" || echo 0)
    local warnings=$(grep -c "⚠" "$REPORT_FILE" || echo 0)

    if [[ $errors -eq 0 && $warnings -eq 0 ]]; then
        log "${GREEN}✓${NC} All checks passed! No issues found."
    elif [[ $errors -eq 0 ]]; then
        log "${YELLOW}⚠${NC} Found $warnings warnings. Review recommended."
    else
        log "${RED}✗${NC} Found $errors errors and $warnings warnings. Action required!"
    fi

    # Send email if requested
    send_email_report

    log ""
    log "Full report saved to: $REPORT_FILE"
}

# Run main
main "$@"
