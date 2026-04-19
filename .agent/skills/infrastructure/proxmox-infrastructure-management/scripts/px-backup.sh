#!/bin/bash
# Proxmox Backup Script
# Backup VMs and containers to Proxmox Backup Server or local storage
# Usage: ./px-backup.sh <vmid> [--storage] [--mode] [--compress] [--mail] | --all

set -euo pipefail

# Configuration
DEFAULT_STORAGE="${DEFAULT_STORAGE:-local-bak}"
DEFAULT_MODE="${DEFAULT_MODE:-snapshot}"
DEFAULT_COMPRESS="${DEFAULT_COMPRESS:-zstd}"
MAILNOTIFICATION="${MAILNOTIFICATION:-always}"
LOG_DIR="${LOG_DIR:-/var/log/proxmox-backup}"
LOG_FILE="${LOG_FILE:-${LOG_DIR}/backup-$(date +%Y%m%d).log}"

# PBS Configuration
PBS_ENABLED="${PBS_ENABLED:-false}"
PBS_SERVER="${PBS_SERVER:-}"
PBS_NAMESPACE="${PBS_NAMESPACE:-}"
PBS_FINGERPRINT="${PBS_FINGERPRINT:-}"

# Retention
RETENTION_KEEP_LAST="${RETENTION_KEEP_LAST:-10}"
RETENTION_KEEP_HOURLY="${RETENTION_KEEP_HOURLY:-24}"
RETENTION_KEEP_DAILY="${RETENTION_KEEP_DAILY:-7}"
RETENTION_KEEP_WEEKLY="${RETENTION_KEEP_WEEKLY:-4}"
RETENTION_KEEP_MONTHLY="${RETENTION_KEEP_MONTHLY:-3}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] $1"
    echo -e "${GREEN}${msg}${NC}"
    echo "$msg" >> "$LOG_FILE"
}

log_warn() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] [WARN] $1"
    echo -e "${YELLOW}${msg}${NC}"
    echo "$msg" >> "$LOG_FILE"
}

log_error() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] $1"
    echo -e "${RED}${msg}${NC}"
    echo "$msg" >> "$LOG_FILE"
}

init_logging() {
    mkdir -p "$LOG_DIR"
    touch "$LOG_FILE"
    chmod 600 "$LOG_FILE"
}

check_vm_exists() {
    local vmid="$1"

    if qm config "$vmid" &>/dev/null; then
        log_info "VM $vmid found"
        return 0
    elif pct config "$vmid" &>/dev/null; then
        log_info "Container $vmid found"
        return 0
    else
        log_error "VMID $vmid does not exist"
        return 1
    fi
}

get_vm_type() {
    local vmid="$1"

    if qm config "$vmid" &>/dev/null; then
        echo "vm"
    else
        echo "ct"
    fi
}

backup_vm() {
    local vmid="$1"
    local storage="$2"
    local mode="$3"
    local compress="$4"
    local mailnotification="$5"

    local vm_type
    vm_type=$(get_vm_type "$vmid")

    log_info "Starting backup for $vm_type $vmid"
    log_info "Storage: $storage"
    log_info "Mode: $mode"
    log_info "Compression: $compress"

    local backup_cmd="vzdump $vmid --storage $storage --mode $mode --compress $compress"

    # Add mail notification
    if [[ -n "$mailnotification" ]]; then
        backup_cmd="$backup_cmd --mailnotification $mailnotification"
    fi

    # Add retention settings
    if [[ "$RETENTION_KEEP_LAST" -gt 0 ]]; then
        backup_cmd="$backup_cmd --keep-last $RETENTION_KEEP_LAST"
    fi

    # Add notes
    backup_cmd="$backup_cmd --notes 'Automated backup $(date +%Y-%m-%d)'"

    log_info "Executing: $backup_cmd"

    if $backup_cmd 2>&1 | tee -a "$LOG_FILE"; then
        log_info "Backup completed successfully for $vm_type $vmid"
        return 0
    else
        log_error "Backup failed for $vm_type $vmid"
        return 1
    fi
}

backup_to_pbs() {
    local vmid="$1"
    local namespace="${2:-}"

    log_info "Backing up to Proxmox Backup Server"
    log_info "Server: $PBS_SERVER"

    local vm_type
    vm_type=$(get_vm_type "$vmid")

    # Construct PBS backup command
    local backup_cmd="vzdump $vmid --storage pbs --mode snapshot"

    if [[ -n "$namespace" ]]; then
        backup_cmd="$backup_cmd --namespace $namespace"
    fi

    backup_cmd="$backup_cmd --notes 'Automated PBS backup $(date +%Y-%m-%d)'"

    log_info "Executing: $backup_cmd"

    if $backup_cmd 2>&1 | tee -a "$LOG_FILE"; then
        log_info "PBS backup completed successfully for $vm_type $vmid"
        return 0
    else
        log_error "PBS backup failed for $vm_type $vmid"
        return 1
    fi
}

backup_all() {
    local storage="$1"
    local mode="$2"
    local compress="$3"
    local mailnotification="$4"

    log_info "Starting backup for all VMs and containers"

    local all_vmid
    all_vmid=$(pvesh get /cluster/resources --type vm --output-format json | \
        jq -r '.[].vmid' 2>/dev/null || true)

    if [[ -z "$all_vmid" ]]; then
        log_error "No VMs or containers found"
        return 1
    fi

    local success_count=0
    local fail_count=0

    for vmid in $all_vmid; do
        if backup_vm "$vmid" "$storage" "$mode" "$compress" "$mailnotification"; then
            success_count=$((success_count + 1))
        else
            fail_count=$((fail_count + 1))
        fi
    done

    log_info "Backup summary: $success_count successful, $fail_count failed"

    return $fail_count
}

cleanup_old_backups() {
    local storage="$1"

    log_info "Cleaning up old backups on $storage"

    # Find old backups
    local backups
    backups=$(pvesh get /nodes/$(hostname)/storage/"$storage"/content --content backup --output-format json 2>/dev/null || echo '[]')

    local backup_count
    backup_count=$(echo "$backups" | jq 'length')

    if [[ "$backup_count" -le "$RETENTION_KEEP_LAST" ]]; then
        log_info "No old backups to clean (total: $backup_count, retention: $RETENTION_KEEP_LAST)"
        return 0
    fi

    local excess=$((backup_count - RETENTION_KEEP_LAST))
    log_info "Found $backup_count backups, removing $excess oldest backups"

    # Delete oldest backups
    echo "$backups" | jq -r '.sort_by(.ctime) | .[0:'"$excess"'] | .[].volid' | while read -r volid; do
        log_info "Deleting old backup: $volid"

        if pvesh delete /nodes/$(hostname)/storage/"$storage"/content/"$volid" 2>&1 | tee -a "$LOG_FILE"; then
            log_info "Deleted old backup: $volid"
        else
            log_warn "Failed to delete old backup: $volid"
        fi
    done
}

verify_backup() {
    local vmid="$1"
    local storage="$2"

    log_info "Verifying backup integrity"

    local backups
    backups=$(pvesh get /nodes/$(hostname)/storage/"$storage"/content --content backup --output-format json 2>/dev/null || echo '[]')

    local latest_backup
    latest_backup=$(echo "$backups" | jq -r "[.[] | select(.volid | contains(\"$vmid\"))] | sort_by(.ctime) | reverse | .[0].volid")

    if [[ -z "$latest_backup" ]] || [[ "$latest_backup" == "null" ]]; then
        log_error "No backup found for VMID $vmid"
        return 1
    fi

    log_info "Latest backup: $latest_backup"

    # Get backup file size
    local backup_size
    backup_size=$(echo "$backups" | jq -r "[.[] | select(.volid == \"$latest_backup\")] | .[0].size")

    if [[ "$backup_size" -gt 0 ]]; then
        log_info "Backup size: $((backup_size / 1024 / 1024)) MB"
        return 0
    else
        log_error "Backup size is invalid"
        return 1
    fi
}

send_notification() {
    local status="$1"
    local message="$2"

    log_info "Sending notification: $status"

    # Add your notification logic here (email, webhook, etc.)
    # Example: curl -X POST "$WEBHOOK_URL" -d "{\"status\": \"$status\", \"message\": \"$message\"}"
}

print_usage() {
    cat << EOF
Usage: $0 <vmid> [options] | --all [options]

Arguments:
  vmid          VM ID to backup (or --all for all VMs/containers)

Options:
  --storage     Storage backend (default: $DEFAULT_STORAGE)
  --mode        Backup mode: snapshot, suspend, stop (default: $DEFAULT_MODE)
  --compress    Compression: lzo, gzip, zstd (default: $DEFAULT_COMPRESS)
  --mail        Mail notification: always, never (default: $MAILNOTIFICATION)
  --pbs         Backup to Proxmox Backup Server
  --namespace   PBS namespace for backup
  --cleanup     Clean up old backups after backup
  --verify      Verify backup integrity after completion
  --all         Backup all VMs and containers
  --dry-run     Show what would be backed up without actually doing it

Environment Variables:
  DEFAULT_STORAGE        Default storage backend
  DEFAULT_MODE           Default backup mode
  DEFAULT_COMPRESS       Default compression algorithm
  PBS_ENABLED            Enable PBS backups
  PBS_SERVER             Proxmox Backup Server hostname
  PBS_NAMESPACE          PBS namespace
  RETENTION_KEEP_LAST    Number of backups to keep (default: 10)
  RETENTION_KEEP_HOURLY  Hourly retention (default: 24)
  RETENTION_KEEP_DAILY   Daily retention (default: 7)
  RETENTION_KEEP_WEEKLY  Weekly retention (default: 4)
  RETENTION_KEEP_MONTHLY Monthly retention (default: 3)

Examples:
  # Backup single VM
  $0 200

  # Backup all VMs to specific storage
  $0 --all --storage backup-nas

  # Backup with verification
  $0 200 --verify --cleanup

  # Backup to Proxmox Backup Server
  $0 200 --pbs --namespace production

  # Dry run
  $0 --all --dry-run
EOF
}

main() {
    if [ "$#" -lt 1 ]; then
        print_usage
        exit 1
    fi

    local target="$1"
    shift

    local storage="$DEFAULT_STORAGE"
    local mode="$DEFAULT_MODE"
    local compress="$DEFAULT_COMPRESS"
    local mailnotification="$MAILNOTIFICATION"
    local use_pbs="false"
    local pbs_namespace="$PBS_NAMESPACE"
    local do_cleanup="false"
    local do_verify="false"
    local dry_run="false"

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --storage)
                storage="$2"
                shift 2
                ;;
            --mode)
                mode="$2"
                shift 2
                ;;
            --compress)
                compress="$2"
                shift 2
                ;;
            --mail)
                mailnotification="$2"
                shift 2
                ;;
            --pbs)
                use_pbs="true"
                shift
                ;;
            --namespace)
                pbs_namespace="$2"
                shift 2
                ;;
            --cleanup)
                do_cleanup="true"
                shift
                ;;
            --verify)
                do_verify="true"
                shift
                ;;
            --dry-run)
                dry_run="true"
                shift
                ;;
            *)
                log_error "Unknown option: $1"
                print_usage
                exit 1
                ;;
        esac
    done

    init_logging

    log_info "=== Proxmox Backup Started ==="
    log_info "Target: $target"
    log_info "Storage: $storage"
    log_info "Mode: $mode"
    log_info "Compression: $compress"

    if [[ "$dry_run" == "true" ]]; then
        log_warn "DRY-RUN MODE: No backups will be created"
        if [[ "$target" == "--all" ]]; then
            pvesh get /cluster/resources --type vm --output-format json | jq -r '.[].vmid' | while read -r vmid; do
                log_info "Would backup: VMID $vmid"
            done
        else
            log_info "Would backup: VMID $target"
        fi
        exit 0
    fi

    local backup_result=0

    if [[ "$use_pbs" == "true" ]]; then
        if [[ -z "$PBS_SERVER" ]]; then
            log_error "PBS_SERVER not configured"
            exit 1
        fi

        if [[ "$target" == "--all" ]]; then
            pvesh get /cluster/resources --type vm --output-format json | jq -r '.[].vmid' | while read -r vmid; do
                if ! backup_to_pbs "$vmid" "$pbs_namespace"; then
                    backup_result=1
                fi
            done
        else
            if ! check_vm_exists "$target"; then
                exit 1
            fi
            if ! backup_to_pbs "$target" "$pbs_namespace"; then
                backup_result=1
            fi
        fi
    else
        if [[ "$target" == "--all" ]]; then
            if ! backup_all "$storage" "$mode" "$compress" "$mailnotification"; then
                backup_result=1
            fi
        else
            if ! check_vm_exists "$target"; then
                exit 1
            fi
            if ! backup_vm "$target" "$storage" "$mode" "$compress" "$mailnotification"; then
                backup_result=1
            fi
        fi
    fi

    if [[ "$do_verify" == "true" ]]; then
        if [[ "$target" != "--all" ]]; then
            verify_backup "$target" "$storage"
        fi
    fi

    if [[ "$do_cleanup" == "true" ]]; then
        cleanup_old_backups "$storage"
    fi

    log_info "=== Proxmox Backup Completed ==="

    if [[ "$backup_result" -eq 0 ]]; then
        send_notification "success" "Backup completed successfully"
    else
        send_notification "failure" "Backup completed with errors"
        exit 1
    fi
}

main "$@"
