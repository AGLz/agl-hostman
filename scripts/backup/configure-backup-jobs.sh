#!/bin/bash
# Proxmox Backup Job Configuration Script
# Automates backup job setup for all VMs/CTs in AGL infrastructure
#
# Usage: sudo ./configure-backup-jobs.sh [--dry-run] [--verify]

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROXMOX_HOST="${PROXMOX_HOST:-aglsrv1}"
PBS_SERVER="${PBS_SERVER:-10.6.0.14}"
PBS_PORT="${PBS_PORT:-8007}"
PBS_DATASTORE="${PBS_DATASTORE:-aglsrv6-pbs}"
ADMIN_EMAIL="${ADMIN_EMAIL:-admin@agl.io}"

# Dry run mode
DRY_RUN=false
VERIFY_ONLY=false

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --verify)
            VERIFY_ONLY=true
            shift
            ;;
        --help)
            echo "Usage: $0 [--dry-run] [--verify]"
            echo ""
            echo "Options:"
            echo "  --dry-run    Show what would be configured without making changes"
            echo "  --verify     Verify existing backup jobs"
            echo "  --help       Show this help message"
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Verify PBS connectivity
verify_pbs_connection() {
    log_info "Verifying PBS connectivity..."

    if ! ping -c 1 -W 2 "$PBS_SERVER" >/dev/null 2>&1; then
        log_error "Cannot reach PBS server at $PBS_SERVER"
        return 1
    fi

    if ! nc -z -w 2 "$PBS_SERVER" "$PBS_PORT" 2>/dev/null; then
        log_error "PBS port $PBS_PORT not accessible on $PBS_SERVER"
        return 1
    fi

    log_info "PBS connection verified: $PBS_SERVER:$PBS_PORT"
    return 0
}

# Configure PBS storage on Proxmox
configure_pbs_storage() {
    log_info "Configuring PBS storage on Proxmox..."

    local storage_id="aglsrv6-pbs"

    # Check if storage already exists
    if pvesm status | grep -q "^${storage_id}"; then
        log_warn "Storage '$storage_id' already exists, skipping..."
        return 0
    fi

    local cmd="pvesm add pbs ${storage_id} \
        --server ${PBS_SERVER} \
        --port ${PBS_PORT} \
        --username 'root@pam' \
        --password '' \
        --fingerprint '' \
        --datastore ${PBS_DATASTORE} \
        --content backup \
        --maxfiles 10"

    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY-RUN] Would execute: $cmd"
    else
        log_warn "PBS storage requires fingerprint. Please configure manually:"
        echo "pvesm add pbs ${storage_id} \\"
        echo "  --server ${PBS_SERVER} \\"
        echo "  --port ${PBS_PORT} \\"
        echo "  --username 'root@pam' \\"
        echo "  --fingerprint <FINGERPRINT> \\"
        echo "  --datastore ${PBS_DATASTORE}"
    fi

    return 0
}

# Create backup job configuration
create_backup_job() {
    local job_id=$1
    local schedule=$2
    local dow=$3
    local vmid=$4
    local retention=$5
    local priority=$6

    log_info "Creating backup job: $job_id (VMs: $vmid, Schedule: $schedule $dow)"

    local cmd="pvesh create /cluster/backup \
        --id ${job_id} \
        --starttime '${schedule}' \
        --dow '${dow}' \
        --vmid '${vmid}' \
        --storage '${PBS_DATASTORE}' \
        --compress zstd \
        --mode snapshot \
        --mailnotification always \
        --mailnotification ${priority}"

    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY-RUN] Would execute: $cmd"
    else
        eval "$cmd" || {
            log_error "Failed to create backup job: $job_id"
            return 1
        }
        log_info "Created backup job: $job_id"
    fi

    return 0
}

# Configure retention policy
configure_retention() {
    local job_id=$1
    local keep_daily=$2
    local keep_weekly=$3
    local keep_monthly=$4

    log_info "Configuring retention for job: $job_id"

    local cmd="pvesh set /cluster/backup/${job_id} \
        --prune-options 'keep-daily=${keep_daily} keep-weekly=${keep_weekly} keep-monthly=${keep_monthly}'"

    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY-RUN] Would execute: $cmd"
    else
        eval "$cmd" || {
            log_error "Failed to configure retention for: $job_id"
            return 1
        }
        log_info "Retention configured: ${keep_daily}d, ${keep_weekly}w, ${keep_monthly}m"
    fi

    return 0
}

# List all backup jobs
list_backup_jobs() {
    log_info "Current backup jobs:"

    pvesh get /cluster/backup --output-format json | jq -r '.[] | "\(.id): \(.vmid) @ \(.starttime) on \(.dow)"'
}

# Verify backup job configuration
verify_backup_jobs() {
    log_info "Verifying backup job configuration..."

    local all_ok=true

    # Check storage
    if ! pvesm status | grep -q "^aglsrv6-pbs"; then
        log_error "PBS storage 'aglsrv6-pbs' not configured"
        all_ok=false
    else
        log_info "PBS storage: OK"
    fi

    # Check backup jobs
    local jobs=$(pvesh get /cluster/backup --output-format json)
    local job_count=$(echo "$jobs" | jq 'length')

    if [[ $job_count -eq 0 ]]; then
        log_error "No backup jobs configured"
        all_ok=false
    else
        log_info "Backup jobs configured: $job_count"
    fi

    # Check for critical systems
    for vmid in 183 184 180 182 173; do
        local has_backup=$(echo "$jobs" | jq --arg vmid "$vmid" '[.[] | select(.vmid == ($vmid|tonumber))] | length')
        if [[ $has_backup -eq 0 ]]; then
            log_error "No backup job for CT$vmid"
            all_ok=false
        else
            log_info "CT$vmid: Backup job found"
        fi
    done

    if [[ "$all_ok" == true ]]; then
        log_info "All verification checks passed"
        return 0
    else
        log_error "Some verification checks failed"
        return 1
    fi
}

# Main execution
main() {
    log_info "=== Proxmox Backup Job Configuration ==="
    log_info "Target: $PROXMOX_HOST"
    log_info "PBS: $PBS_SERVER:$PBS_PORT"
    log_info "Datastore: $PBS_DATASTORE"

    # Verify PBS connection
    verify_pbs_connection || exit 1

    # Verify mode
    if [[ "$VERIFY_ONLY" == true ]]; then
        verify_backup_jobs
        exit $?
    fi

    # Configure PBS storage
    configure_pbs_storage

    # Backup job definitions
    # Format: job_id, schedule, day_of_week, vmid, retention, priority

    # Job 1: Critical Systems (Daily)
    create_backup_job \
        "critical-daily" \
        "02:00" \
        "mon,tue,wed,thu,fri,sat,sun" \
        "183,184" \
        "7,4,12" \
        "always"

    configure_retention "critical-daily" 7 4 12

    # Job 2: High Priority Systems (Daily)
    create_backup_job \
        "high-priority-daily" \
        "03:00" \
        "mon,tue,wed,thu,fri,sat" \
        "180,182" \
        "7,4,6" \
        "failure"

    configure_retention "high-priority-daily" 7 4 6

    # Job 3: Standard Systems (Weekly)
    create_backup_job \
        "standard-weekly" \
        "04:00" \
        "sun" \
        "173" \
        "0,4,6" \
        "failure"

    configure_retention "standard-weekly" 0 4 6

    # Job 4: Weekly Full Backup (All Systems)
    create_backup_job \
        "full-weekly" \
        "05:00" \
        "sun" \
        "173,180,182,183,184" \
        "7,4,12" \
        "always"

    configure_retention "full-weekly" 7 4 12

    # List all configured jobs
    echo ""
    list_backup_jobs

    # Verify configuration
    echo ""
    verify_backup_jobs

    if [[ "$DRY_RUN" == true ]]; then
        log_info "Dry run completed. No changes were made."
        log_info "Run without --dry-run to apply changes."
    else
        log_info "Backup job configuration completed successfully!"
    fi
}

# Run main function
main "$@"
