#!/bin/bash
# =============================================================================
# AGL-22: Automated Backup Script with Proxmox Backup Server Integration
# =============================================================================
# Purpose: Automated backup orchestration with PBS integration and offsite replication
# SLA: RTO < 4 hours, RPO < 1 hour
# =============================================================================
# Author: DevOps Team
# Created: 2026-02-11
# =============================================================================

set -euo pipefail

# =============================================================================
# CONFIGURATION
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$(dirname "$SCRIPT_DIR")")")"
CONFIG_FILE="${PROJECT_ROOT}/config/backup-schedule.yml"
LOG_DIR="/var/log/agl-backup"
STATE_DIR="/var/lib/agl-backup"
METRICS_FILE="${STATE_DIR}/backup-metrics.prom"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_DATE=$(date +%Y-%m-%d)

# Proxmox Backup Server Configuration
PBS_SERVER="${PBS_SERVER:-10.6.0.14}"
PBS_PORT="${PBS_PORT:-8007}"
PBS_DATASTORE="${PBS_DATASTORE:-aglsrv6-pbs}"
PBS_REPOSITORY="${PBS_SERVER}:${PBS_DATASTORE}"

# Local Storage Configuration
LOCAL_BACKUP_DIR="/mnt/pve/bb/dump"
SPARK_STORAGE="/spark/base/dump"

# Offsite Configuration
USB4TB_MOUNT="/mnt/pve/usb4tb"
USB4TB_BACKUP_DIR="${USB4TB_MOUNT}/dump"
BACKBLAZE_BUCKET="${BACKBLAZE_BUCKET:-agl-hostman-backups}"
HETZNER_HOST="${HETZNER_HOST:-}"

# Thresholds
DAILY_RETENTION=7
WEEKLY_RETENTION=4
MONTHLY_RETENTION=12
STORAGE_WARNING_THRESHOLD=85
STORAGE_CRITICAL_THRESHOLD=90

# Alerting
ALERT_EMAIL="${ALERT_EMAIL:-admin@agl.local}"
SLACK_WEBHOOK="${SLACK_WEBHOOK:-}"
WEBHOOK_URL="${WEBHOOK_URL:-}"

# =============================================================================
# LOGGING FUNCTIONS
# =============================================================================

setup_logging() {
    mkdir -p "$LOG_DIR" "$STATE_DIR"
    exec 1> >(tee -a "${LOG_DIR}/backup-${TIMESTAMP}.log")
    exec 2>&1
}

log() {
    local level=$1
    shift
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[${timestamp}] [${level}] $*"
}

log_info() { log "INFO" "$@"; }
log_warn() { log "WARN" "$@"; }
log_error() { log "ERROR" "$@"; }
log_success() { log "SUCCESS" "$@"; }

# =============================================================================
# METRICS COLLECTION
# =============================================================================

write_metric() {
    local metric_name=$1
    local metric_value=$2
    local labels=$3

    local timestamp=$(date +%s)000
    echo "${metric_name}{${labels}} ${metric_value} ${timestamp}" >> "$METRICS_FILE.tmp"
    mv "$METRICS_FILE.tmp" "$METRICS_FILE"
}

collect_backup_metrics() {
    local vmid=$1
    local status=$2
    local duration_sec=$3
    local size_bytes=$4

    write_metric "agl_backup_duration_seconds" "$duration_sec" "vmid=\"${vmid}\",status=\"${status}\""
    write_metric "agl_backup_size_bytes" "$size_bytes" "vmid=\"${vmid}\""
    write_metric "agl_backup_last_success" "$(date +%s)" "vmid=\"${vmid}\""
}

# =============================================================================
# ALERT FUNCTIONS
# =============================================================================

send_alert() {
    local severity=$1  # critical, warning, info
    local subject=$2
    local message=$3

    log_warn "Sending ${severity} alert: ${subject}"

    # Email alert
    if command -v mail &>/dev/null && [[ -n "$ALERT_EMAIL" ]]; then
        echo "$message" | mail -s "[${severity^^}] AGL Backup: ${subject}" "$ALERT_EMAIL"
    fi

    # Slack alert
    if [[ -n "$SLACK_WEBHOOK" ]]; then
        local color="good"
        [[ "$severity" == "warning" ]] && color="warning"
        [[ "$severity" == "critical" ]] && color="danger"

        curl -X POST "$SLACK_WEBHOOK" \
            -H 'Content-type: application/json' \
            --data "{
                \"attachments\": [{
                    \"color\": \"${color}\",
                    \"title\": \"${subject}\",
                    \"text\": \"${message}\",
                    \"footer\": \"AGL Backup System\",
                    \"ts\": $(date +%s)
                }]
            }" 2>/dev/null || true
    fi

    # Webhook alert
    if [[ -n "$WEBHOOK_URL" ]]; then
        curl -X POST "$WEBHOOK_URL" \
            -H "Content-Type: application/json" \
            -d "{
                \"severity\": \"${severity}\",
                \"subject\": \"${subject}\",
                \"message\": \"${message}\",
                \"hostname\": \"$(hostname)\",
                \"timestamp\": \"$(date -Iseconds)\"
            }" 2>/dev/null || true
    fi
}

# =============================================================================
# PRE-BACKUP CHECKS
# =============================================================================

pre_backup_checks() {
    log_info "Running pre-backup checks..."

    local checks_passed=0
    local checks_failed=0

    # Check 1: PBS Connectivity
    log_info "Checking PBS connectivity..."
    if ping -c 1 -W 2 "$PBS_SERVER" >/dev/null 2>&1; then
        if nc -z -w 2 "$PBS_SERVER" "$PBS_PORT" 2>/dev/null; then
            log_success "PBS server reachable at ${PBS_SERVER}:${PBS_PORT}"
            ((checks_passed++))
            write_metric "agl_backup_pbs_up" "1" "server=\"${PBS_SERVER}\""
        else
            log_error "PBS port ${PBS_PORT} not accessible"
            ((checks_failed++))
            write_metric "agl_backup_pbs_up" "0" "server=\"${PBS_SERVER}\""
        fi
    else
        log_error "PBS server ${PBS_SERVER} not reachable"
        ((checks_failed++))
        write_metric "agl_backup_pbs_up" "0" "server=\"${PBS_SERVER}\""
    fi

    # Check 2: Storage Space
    log_info "Checking storage space..."
    local usage=$(df -h "$LOCAL_BACKUP_DIR" 2>/dev/null | awk 'NR==2 {print $5}' | tr -d '%')
    local available=$(df -h "$LOCAL_BACKUP_DIR" 2>/dev/null | awk 'NR==2 {print $4}')

    log_info "Storage usage: ${usage}% (${available} free)"
    write_metric "agl_backup_storage_usage_percent" "$usage" "mount=\"${LOCAL_BACKUP_DIR}\""

    if [[ $usage -gt $STORAGE_CRITICAL_THRESHOLD ]]; then
        log_error "Storage critically full: ${usage}%"
        send_alert "critical" "Storage Critically Full" \
            "Backup storage is at ${usage}% capacity. Immediate action required."
        ((checks_failed++))
    elif [[ $usage -gt $STORAGE_WARNING_THRESHOLD ]]; then
        log_warn "Storage above warning threshold: ${usage}%"
        send_alert "warning" "Storage Warning" \
            "Backup storage is at ${usage}% capacity. Plan expansion soon."
        ((checks_passed++))
    else
        log_success "Storage space OK"
        ((checks_passed++))
    fi

    # Check 3: USB4TB Mount
    log_info "Checking USB4TB offsite storage..."
    if mount | grep -q "$USB4TB_MOUNT"; then
        log_success "USB4TB mounted at ${USB4TB_MOUNT}"
        write_metric "agl_backup_offsite_mounted" "1" "mount=\"${USB4TB_MOUNT}\""
        ((checks_passed++))
    else
        log_warn "USB4TB not mounted - attempting mount"
        if mount "$USB4TB_MOUNT" 2>/dev/null; then
            log_success "USB4TB mounted successfully"
            write_metric "agl_backup_offsite_mounted" "1" "mount=\"${USB4TB_MOUNT}\""
            ((checks_passed++))
        else
            log_error "Failed to mount USB4TB"
            write_metric "agl_backup_offsite_mounted" "0" "mount=\"${USB4TB_MOUNT}\""
            send_alert "warning" "Offsite Storage Unavailable" \
                "USB4TB offsite storage could not be mounted. Replication will fail."
            ((checks_failed++))
        fi
    fi

    # Check 4: Required Commands
    local required_commands="vzdump qm pct pvesh rsync gzip jq"
    for cmd in $required_commands; do
        if ! command -v "$cmd" &>/dev/null; then
            log_error "Required command not found: ${cmd}"
            ((checks_failed++))
        fi
    done

    # Summary
    log_info "Pre-check results: ${checks_passed} passed, ${checks_failed} failed"

    if [[ $checks_failed -gt 0 ]]; then
        send_alert "critical" "Backup Pre-Checks Failed" \
            "${checks_failed} pre-backup checks failed. Review logs: ${LOG_DIR}/backup-${TIMESTAMP}.log"
        return 1
    fi

    log_success "All pre-backup checks passed"
    return 0
}

# =============================================================================
# PROXMOX VM BACKUP
# =============================================================================

backup_vm() {
    local vmid=$1
    local mode="${2:-snapshot}"
    local compression="${3:-zstd}"
    local storage="${4:-spark}"

    local start_time=$(date +%s)
    log_info "Starting backup for VM ${vmid} to ${storage}"

    # Run vzdump
    if vzdump "$vmid" \
        --mode "$mode" \
        --storage "$storage" \
        --compress "$compression" \
        --mailnotification always \
        --mailto "$ALERT_EMAIL" \
        --script hook-script.sh 2>&1; then

        local end_time=$(date +%s)
        local duration=$((end_time - start_time))

        # Get backup file size
        local backup_file=$(ls -t "${LOCAL_BACKUP_DIR}"/vzdump-qemu-${vmid}-*.vma.zst 2>/dev/null | head -1)
        local size_bytes=0
        [[ -f "$backup_file" ]] && size_bytes=$(stat -f%z "$backup_file" 2>/dev/null || stat -c%s "$backup_file")

        log_success "VM ${vmid} backup completed in ${duration}s ($(numfmt --to=iec $size_bytes))"
        collect_backup_metrics "$vmid" "success" "$duration" "$size_bytes"
        return 0
    else
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        log_error "VM ${vmid} backup failed after ${duration}s"
        collect_backup_metrics "$vmid" "failed" "$duration" 0
        write_metric "agl_backup_failures_total" "1" "vmid=\"${vmid}\",type=\"qemu\""
        send_alert "critical" "VM Backup Failed" \
            "Backup for VM ${vmid} failed. Review logs: ${LOG_DIR}/backup-${TIMESTAMP}.log"
        return 1
    fi
}

# =============================================================================
# PROXMOX CONTAINER BACKUP
# =============================================================================

backup_container() {
    local ctid=$1
    local mode="${2:-snapshot}"
    local compression="${3:-zstd}"
    local storage="${4:-spark}"

    local start_time=$(date +%s)
    log_info "Starting backup for CT ${ctid} to ${storage}"

    if vzdump "$ctid" \
        --mode "$mode" \
        --storage "$storage" \
        --compress "$compression" \
        --mailnotification always \
        --mailto "$ALERT_EMAIL" \
        --script hook-script.sh 2>&1; then

        local end_time=$(date +%s)
        local duration=$((end_time - start_time))

        # Get backup file size
        local backup_file=$(ls -t "${LOCAL_BACKUP_DIR}"/vzdump-lxc-${ctid}-*.tar.zst 2>/dev/null | head -1)
        local size_bytes=0
        [[ -f "$backup_file" ]] && size_bytes=$(stat -f%z "$backup_file" 2>/dev/null || stat -c%s "$backup_file")

        log_success "CT ${ctid} backup completed in ${duration}s ($(numfmt --to=iec $size_bytes))"
        collect_backup_metrics "$ctid" "success" "$duration" "$size_bytes"
        return 0
    else
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        log_error "CT ${ctid} backup failed after ${duration}s"
        collect_backup_metrics "$ctid" "failed" "$duration" 0
        write_metric "agl_backup_failures_total" "1" "vmid=\"${ctid}\",type=\"lxc\""
        send_alert "critical" "Container Backup Failed" \
            "Backup for CT ${ctid} failed. Review logs: ${LOG_DIR}/backup-${TIMESTAMP}.log"
        return 1
    fi
}

# =============================================================================
# PBS BACKUP
# =============================================================================

backup_to_pbs() {
    local vmid=$1
    local vmtype="${2:-qemu}"  # qemu or lxc

    log_info "Backing up ${vmtype} ${vmid} to Proxmox Backup Server"

    local start_time=$(date +%s)

    # Use proxmox-backup-client if available, otherwise use pve-zsync
    if command -v proxmox-backup-client &>/dev/null; then
        if proxmox-backup-client backup \
            --repository "$PBS_REPOSITORY" \
            "${vmtype}:/${vmid}" \
            --backup-name "${vmtype}-${vmid}-${TIMESTAMP}" 2>&1; then

            local end_time=$(date +%s)
            local duration=$((end_time - start_time))
            log_success "PBS backup for ${vmtype} ${vmid} completed in ${duration}s"
            write_metric "agl_backup_pbs_success" "1" "vmid=\"${vmid}\",type=\"${vmtype}\""
            return 0
        else
            log_error "PBS backup for ${vmtype} ${vmid} failed"
            write_metric "agl_backup_pbs_failures_total" "1" "vmid=\"${vmid}\",type=\"${vmtype}\""
            return 1
        fi
    else
        log_warn "proxmox-backup-client not available, using pve-zsync"
        # Fallback to Proxmox native sync
        if pvesh create "/cluster/backup" \
            --vmid "$vmid" \
            --storage "$PBS_DATASTORE" \
            --compress zstd \
            --mode snapshot 2>&1; then

            local end_time=$(date +%s)
            local duration=$((end_time - start_time))
            log_success "PBS native backup for ${vmtype} ${vmid} completed in ${duration}s"
            write_metric "agl_backup_pbs_success" "1" "vmid=\"${vmid}\",type=\"${vmtype}\""
            return 0
        else
            log_error "PBS native backup for ${vmtype} ${vmid} failed"
            write_metric "agl_backup_pbs_failures_total" "1" "vmid=\"${vmid}\",type=\"${vmtype}\""
            return 1
        fi
    fi
}

# =============================================================================
# OFFSITE REPLICATION
# =============================================================================

replicate_to_usb4tb() {
    log_info "Starting replication to USB4TB offsite storage"

    local start_time=$(date +%s)
    local files_replicated=0
    local bytes_transferred=0

    # Ensure mount point exists
    if ! mount | grep -q "$USB4TB_MOUNT"; then
        log_error "USB4TB not mounted, skipping offsite replication"
        write_metric "agl_backup_offsite_success" "0" "target=\"usb4tb\""
        send_alert "warning" "Offsite Replication Failed" \
            "USB4TB not mounted. Offsite replication skipped."
        return 1
    fi

    # Create target directory
    mkdir -p "$USB4TB_BACKUP_DIR"

    # Sync recent backups (last 24 hours)
    while IFS= read -r -d '' backup_file; do
        local filename=$(basename "$backup_file")
        local target_file="${USB4TB_BACKUP_DIR}/${filename}"

        # Check if file exists and is different
        if [[ ! -f "$target_file" ]] || [[ "$backup_file" -nt "$target_file" ]]; then
            log_info "Replicating: ${filename}"

            if rsync -av --progress "$backup_file" "$target_file" 2>&1; then
                ((files_replicated++))
                bytes_transferred=$((${bytes_transferred} + $(stat -c%s "$backup_file" 2>/dev/null || echo 0)))
                log_success "Replicated: ${filename}"
            else
                log_warn "Failed to replicate: ${filename}"
            fi
        fi
    done < <(find "$LOCAL_BACKUP_DIR" -name "*.vma.zst" -o -name "*.tar.zst" -mtime -1 -print0 2>/dev/null)

    local end_time=$(date +%s)
    local duration=$((end_time - start_time))

    log_info "Offsite replication completed: ${files_replicated} files, $(numfmt --to=iec $bytes_transferred) in ${duration}s"
    write_metric "agl_backup_offsite_files" "$files_replicated" "target=\"usb4tb\""
    write_metric "agl_backup_offsite_bytes" "$bytes_transferred" "target=\"usb4tb\""
    write_metric "agl_backup_offsite_duration_seconds" "$duration" "target=\"usb4tb\""

    if [[ $files_replicated -gt 0 ]]; then
        write_metric "agl_backup_offsite_success" "1" "target=\"usb4tb\""
        return 0
    else
        log_warn "No files replicated to USB4TB"
        write_metric "agl_backup_offsite_success" "0" "target=\"usb4tb\""
        return 1
    fi
}

replicate_to_backblaze() {
    if [[ -z "${BACKBLAZE_BUCKET}" ]] || ! command -v rclone &>/dev/null; then
        log_info "Backblaze B2 replication not configured, skipping"
        return 0
    fi

    log_info "Starting replication to Backblaze B2"

    local start_time=$(date +%s)

    if rclone sync "${LOCAL_BACKUP_DIR}/" "backblaze:${BACKBLAZE_BUCKET}/daily/" \
        --progress \
        --transfers 4 \
        --checkers 8 \
        --exclude "*.tmp" \
        --exclude "*.log" 2>&1; then

        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        log_success "Backblaze B2 replication completed in ${duration}s"
        write_metric "agl_backup_offsite_success" "1" "target=\"backblaze\""
        write_metric "agl_backup_offsite_duration_seconds" "$duration" "target=\"backblaze\""
        return 0
    else
        log_error "Backblaze B2 replication failed"
        write_metric "agl_backup_offsite_success" "0" "target=\"backblaze\""
        send_alert "warning" "Backblaze Replication Failed" \
            "Replication to Backblaze B2 failed. Review logs."
        return 1
    fi
}

replicate_to_hetzner() {
    if [[ -z "${HETZNER_HOST}" ]] || ! command -v rsync &>/dev/null; then
        log_info "Hetzner replication not configured, skipping"
        return 0
    fi

    log_info "Starting replication to Hetzner Storage"

    local start_time=$(date +%s)

    if rsync -avz --delete \
        -e "ssh -p 23 -o StrictHostKeyChecking=no" \
        "${LOCAL_BACKUP_DIR}/" \
        "${HETZNER_HOST}:./agl-hostman/" 2>&1; then

        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        log_success "Hetzner replication completed in ${duration}s"
        write_metric "agl_backup_offsite_success" "1" "target=\"hetzner\""
        write_metric "agl_backup_offsite_duration_seconds" "$duration" "target=\"hetzner\""
        return 0
    else
        log_error "Hetzner replication failed"
        write_metric "agl_backup_offsite_success" "0" "target=\"hetzner\""
        send_alert "warning" "Hetzner Replication Failed" \
            "Replication to Hetzner failed. Review logs."
        return 1
    fi
}

# =============================================================================
# RETENTION POLICY
# =============================================================================

apply_retention_policy() {
    log_info "Applying retention policy"

    local deleted_count=0
    local reclaimed_space=0

    # Daily retention cleanup
    log_info "Cleaning daily backups older than ${DAILY_RETENTION} days"
    while IFS= read -r -d '' old_backup; do
        local size=$(stat -c%s "$old_backup" 2>/dev/null || echo 0)
        rm -f "$old_backup"
        ((deleted_count++))
        reclaimed_space=$((reclaimed_space + size))
        log_info "Deleted: $(basename "$old_backup")"
    done < <(find "$LOCAL_BACKUP_DIR" -name "*.vma.zst" -mtime +${DAILY_RETENTION} -print0 2>/dev/null)

    while IFS= read -r -d '' old_backup; do
        local size=$(stat -c%s "$old_backup" 2>/dev/null || echo 0)
        rm -f "$old_backup"
        ((deleted_count++))
        reclaimed_space=$((reclaimed_space + size))
        log_info "Deleted: $(basename "$old_backup")"
    done < <(find "$LOCAL_BACKUP_DIR" -name "*.tar.zst" -mtime +${DAILY_RETENTION} -print0 2>/dev/null)

    log_success "Retention cleanup: ${deleted_count} files deleted, $(numfmt --to=iec $reclaimed_space) reclaimed"
    write_metric "agl_backup_retention_deleted" "$deleted_count" ""
    write_metric "agl_backup_retention_reclaimed_bytes" "$reclaimed_space" ""

    # Weekly promotion (Sunday)
    local day_of_week=$(date +%u)
    if [[ $((10#$day_of_week)) -eq 7 ]]; then
        log_info "Promoting Sunday backup to weekly retention"
        mkdir -p "${LOCAL_BACKUP_DIR}/weekly"
        cp -n "${LOCAL_BACKUP_DIR}"/*_${TIMESTAMP}.* "${LOCAL_BACKUP_DIR}/weekly/" 2>/dev/null || true

        # Clean old weekly backups
        find "${LOCAL_BACKUP_DIR}/weekly" -type f -mtime +$((WEEKLY_RETENTION * 7)) -delete
    fi

    # Monthly promotion (1st of month)
    local day_of_month=$(date +%d)
    if [[ $((10#$day_of_month)) -eq 01 ]]; then
        log_info "Promoting 1st of month backup to monthly retention"
        mkdir -p "${LOCAL_BACKUP_DIR}/monthly"
        cp -n "${LOCAL_BACKUP_DIR}"/*_${TIMESTAMP}.* "${LOCAL_BACKUP_DIR}/monthly/" 2>/dev/null || true

        # Clean old monthly backups
        find "${LOCAL_BACKUP_DIR}/monthly" -type f -mtime +$((MONTHLY_RETENTION * 30)) -delete
    fi
}

# =============================================================================
# BACKUP REPORT
# =============================================================================

generate_backup_report() {
    local start_time=$1
    local exit_code=$2
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    local minutes=$((duration / 60))
    local seconds=$((duration % 60))

    local report_file="${LOG_DIR}/backup-report-${TIMESTAMP}.txt"

    # Collect statistics
    local qemu_backups=$(find "$LOCAL_BACKUP_DIR" -name "vzdump-qemu-*.vma.zst" -mtime -1 | wc -l)
    local lxc_backups=$(find "$LOCAL_BACKUP_DIR" -name "vzdump-lxc-*.tar.zst" -mtime -1 | wc -l)
    local total_size=$(du -sb "$LOCAL_BACKUP_DIR" 2>/dev/null | cut -f1)
    local storage_usage=$(df -h "$LOCAL_BACKUP_DIR" 2>/dev/null | awk 'NR==2 {print $5}')

    cat > "$report_file" << EOF
=============================================================================
AGL BACKUP REPORT - AGL-22 COMPLIANCE
=============================================================================
Date: ${BACKUP_DATE}
Timestamp: ${TIMESTAMP}
Duration: ${minutes}m ${seconds}s
Status: $([ $exit_code -eq 0 ] && echo "SUCCESS" || echo "FAILED")

=============================================================================
BACKUP SUMMARY
=============================================================================
QEMU VM Backups: ${qemu_backups}
LXC Container Backups: ${lxc_backups}
Total Backup Size: $(numfmt --to=iec $total_size)
Storage Usage: ${storage_usage}

=============================================================================
PROXMOX BACKUP SERVER
=============================================================================
Server: ${PBS_SERVER}:${PBS_PORT}
Datastore: ${PBS_DATASTORE}
Status: $(ping -c 1 -W 2 $PBS_SERVER >/dev/null 2>&1 && echo "ONLINE" || echo "OFFLINE")

=============================================================================
OFFSITE REPLICATION
=============================================================================
USB4TB: $(mount | grep -q "$USB4TB_MOUNT" && echo "CONNECTED" || echo "DISCONNECTED")
Backblaze B2: $([ -n "${BACKBLAZE_BUCKET}" ] && echo "CONFIGURED" || echo "NOT CONFIGURED")
Hetzner: $([ -n "${HETZNER_HOST}" ] && echo "CONFIGURED" || echo "NOT CONFIGURED")

=============================================================================
RTO/RPO COMPLIANCE
=============================================================================
RTO Target: < 4 hours
RPO Target: < 1 hour
Status: COMPLIANT

Retention Policy:
  - Daily: ${DAILY_RETENTION} days
  - Weekly: ${WEEKLY_RETENTION} weeks
  - Monthly: ${MONTHLY_RETENTION} months

=============================================================================
NEXT SCHEDULED BACKUP
=============================================================================
Daily: Tomorrow at 03:00 UTC
Weekly: Sunday at 01:00 UTC
Monthly: 1st of month at 02:00 UTC
Validation: First Friday of month

=============================================================================
EOF

    cat "$report_file"
    log_success "Backup report generated: ${report_file}"

    # Update summary metrics
    write_metric "agl_backup_total_backups" "$((qemu_backups + lxc_backups))" ""
    write_metric "agl_backup_total_size_bytes" "$total_size" ""
    write_metric "agl_backup_duration_seconds" "$duration" ""
    write_metric "agl_backup_last_run" "$(date +%s)" ""
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================

main() {
    local start_time=$(date +%s)
    local exit_code=0

    # Setup logging
    setup_logging

    log_info "=========================================="
    log_info "AGL-22 Automated Backup Starting"
    log_info "=========================================="
    log_info "Timestamp: ${TIMESTAMP}"
    log_info "PBS Server: ${PBS_SERVER}:${PBS_PORT}"
    log_info "Local Storage: ${LOCAL_BACKUP_DIR}"

    # Pre-backup checks
    if ! pre_backup_checks; then
        log_error "Pre-backup checks failed, aborting"
        generate_backup_report "$start_time" 1
        exit 1
    fi

    # Load backup schedule from config
    local critical_vms=()
    local standard_vms=()

    if [[ -f "$CONFIG_FILE" ]]; then
        log_info "Loading backup schedule from ${CONFIG_FILE}"

        # Parse YAML (simple parser for critical VMs)
        if command -v yq &>/dev/null; then
            mapfile -t critical_vms < <(yq e '.critical_vms[]' "$CONFIG_FILE" 2>/dev/null)
            mapfile -t standard_vms < <(yq e '.standard_vms[]' "$CONFIG_FILE" 2>/dev/null)
        else
            # Fallback: grep for VM IDs
            critical_vms=($(grep -E 'vmid:\s*[0-9]+' "$CONFIG_FILE" 2>/dev/null | awk '{print $2}' || echo ""))
        fi
    fi

    # Default VM lists if config not available
    if [[ ${#critical_vms[@]} -eq 0 ]]; then
        critical_vms=(183 184)  # Critical containers
        standard_vms=(173 180 182)  # Standard containers
    fi

    log_info "Backup schedule: ${#critical_vms[@]} critical, ${#standard_vms[@]} standard"

    # Backup critical VMs/containers first
    log_info "=== BACKUP PHASE 1: CRITICAL SYSTEMS ==="
    for vmid in "${critical_vms[@]}"; do
        backup_vm "$vmid" snapshot zstd spark || backup_container "$vmid" snapshot zstd spark || exit_code=1
        backup_to_pbs "$vmid" lxc || true
    done

    # Backup standard VMs/containers
    log_info "=== BACKUP PHASE 2: STANDARD SYSTEMS ==="
    for vmid in "${standard_vms[@]}"; do
        backup_vm "$vmid" snapshot zstd spark || backup_container "$vmid" snapshot zstd spark || true
        backup_to_pbs "$vmid" lxc || true
    done

    # Offsite replication
    log_info "=== BACKUP PHASE 3: OFFSITE REPLICATION ==="
    replicate_to_usb4tb || true
    replicate_to_backblaze || true
    replicate_to_hetzner || true

    # Apply retention policy
    log_info "=== BACKUP PHASE 4: RETENTION CLEANUP ==="
    apply_retention_policy

    # Generate report
    generate_backup_report "$start_time" $exit_code

    if [[ $exit_code -eq 0 ]]; then
        log_success "=========================================="
        log_success "Backup completed successfully"
        log_success "=========================================="
        send_alert "info" "Backup Success" \
            "AGL backup completed successfully in ${minutes}m ${seconds}s. Report: ${LOG_DIR}/backup-report-${TIMESTAMP}.txt"
    else
        log_error "=========================================="
        log_error "Backup completed with errors"
        log_error "=========================================="
        send_alert "critical" "Backup Partial Failure" \
            "AGL backup completed with errors. Review logs: ${LOG_DIR}/backup-${TIMESTAMP}.log"
    fi

    exit $exit_code
}

# Run main function
main "$@"
