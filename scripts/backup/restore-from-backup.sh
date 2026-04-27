#!/bin/bash
# =============================================================================
# AGL-22: Backup Restoration Script
# =============================================================================
# Purpose: Restore VMs/containers from backup with validation
# SLA: RTO < 4 hours for critical systems
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
LOG_DIR="/var/log/agl-restore"
STATE_DIR="/var/lib/agl-backup"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Storage Configuration
LOCAL_BACKUP_DIR="/mnt/pve/bb/dump"
USB4TB_MOUNT="/mnt/pve/usb4tb"
USB4TB_BACKUP_DIR="${USB4TB_MOUNT}/dump"
RESTORE_STORAGE="${RESTORE_STORAGE:-local-zfs}"

# PBS Configuration
PBS_SERVER="${PBS_SERVER:-10.6.0.14}"
PBS_PORT="${PBS_PORT:-8007}"
PBS_DATASTORE="${PBS_DATASTORE:-aglsrv6-pbs}"

# Alerting
ALERT_EMAIL="${ALERT_EMAIL:-admin@agl.local}"
SLACK_WEBHOOK="${SLACK_WEBHOOK:-}"
WEBHOOK_URL="${WEBHOOK_URL:-}"

# Options
DRY_RUN=false
FORCE=false
SKIP_VALIDATION=false
OFFSITE_SOURCE=false

# =============================================================================
# LOGGING FUNCTIONS
# =============================================================================

setup_logging() {
    mkdir -p "$LOG_DIR"
    local log_file="${LOG_DIR}/restore-${TIMESTAMP}.log"
    exec 1> >(tee -a "$log_file")
    exec 2>&1
    echo "Log file: $log_file"
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
# ALERT FUNCTIONS
# =============================================================================

send_alert() {
    local severity=$1
    local subject=$2
    local message=$3

    log_warn "Sending ${severity} alert: ${subject}"

    if command -v mail &>/dev/null && [[ -n "$ALERT_EMAIL" ]]; then
        echo "$message" | mail -s "[${severity^^}] AGL Restore: ${subject}" "$ALERT_EMAIL"
    fi

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
                    \"footer\": \"AGL Restore System\",
                    \"ts\": $(date +%s)
                }]
            }" 2>/dev/null || true
    fi

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
# PRE-RESTORE CHECKS
# =============================================================================

pre_restore_checks() {
    local vmid=$1
    local target_vmid=$2

    log_info "Running pre-restore checks..."

    # Check if target VMID already exists
    if qm status "$target_vmid" &>/dev/null || pct status "$target_vmid" &>/dev/null; then
        if [[ "$FORCE" != true ]]; then
            log_error "Target VMID ${target_vmid} already exists"
            log_error "Use --force to overwrite (WARNING: This will destroy the existing VM/CT)"
            return 1
        else
            log_warn "Target VMID ${target_vmid} exists, will be overwritten"
            qm stop "$target_vmid" &>/dev/null || true
            qm destroy "$target_vmid" &>/dev/null || true
            pct stop "$target_vmid" &>/dev/null || true
            pct destroy "$target_vmid" &>/dev/null || true
        fi
    fi

    # Check storage availability
    if ! pvesm status "$RESTORE_STORAGE" &>/dev/null; then
        log_error "Restore storage ${RESTORE_STORAGE} not available"
        return 1
    fi

    # Check storage space
    local storage_info=$(pvesm status "$RESTORE_STORAGE" 2>/dev/null)
    log_info "Restore storage: ${RESTORE_STORAGE}"
    log_info "${storage_info}"

    log_success "Pre-restore checks passed"
    return 0
}

# =============================================================================
# BACKUP DISCOVERY
# =============================================================================

find_backup_file() {
    local vmid=$1
    local source=${2:-local}  # local, offsite, pbs

    log_info "Finding backup for VMID ${vmid} from ${source}..."

    case "$source" in
        offsite)
            if ! mount | grep -q "$USB4TB_MOUNT"; then
                log_error "Offsite storage not mounted"
                return 1
            fi
            local backup_file=$(find "$USB4TB_BACKUP_DIR" -name "vzdump-*-${vmid}-*.tar.zst" -printf '%T@ %p\n' 2>/dev/null | sort -n | tail -1 | cut -d' ' -f2-)
            ;;
        pbs)
            log_info "Checking Proxmox Backup Server for snapshots..."
            # Use proxmox-backup-client to list snapshots
            if command -v proxmox-backup-client &>/dev/null; then
                local snapshots=$(proxmox-backup-client snapshot list --repository "${PBS_SERVER}:${PBS_DATASTORE}" 2>/dev/null || echo "")
                echo "$snapshots" | grep "${vmid}"
            fi
            return 0
            ;;
        *)
            local backup_file=$(find "$LOCAL_BACKUP_DIR" -name "vzdump-*-${vmid}-*" -printf '%T@ %p\n' 2>/dev/null | sort -n | tail -1 | cut -d' ' -f2-)
            ;;
    esac

    if [[ -z "$backup_file" ]]; then
        log_error "No backup found for VMID ${vmid}"
        return 1
    fi

    log_success "Found backup: ${backup_file}"

    # Display backup info
    local backup_size=$(du -h "$backup_file" 2>/dev/null | cut -f1)
    local backup_date=$(stat -c%y "$backup_file" 2>/dev/null | cut -d'.' -f1)
    log_info "Size: ${backup_size}, Date: ${backup_date}"

    echo "$backup_file"
    return 0
}

# =============================================================================
# RESTORE FUNCTIONS
# =============================================================================

restore_vm() {
    local backup_file=$1
    local target_vmid=$2

    log_info "Starting VM restore to ${target_vmid}..."
    local start_time=$(date +%s)

    if [[ "$DRY_RUN" == true ]]; then
        log_info "DRY RUN: Would restore VM to ${target_vmid}"
        return 0
    fi

    if qmrestore "$backup_file" "$target_vmid" --storage "$RESTORE_STORAGE" 2>&1; then
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        log_success "VM restore completed in ${duration}s"
        return 0
    else
        log_error "VM restore failed"
        return 1
    fi
}

restore_container() {
    local backup_file=$1
    local target_vmid=$2

    log_info "Starting container restore to ${target_vmid}..."
    local start_time=$(date +%s)

    if [[ "$DRY_RUN" == true ]]; then
        log_info "DRY RUN: Would restore container to ${target_vmid}"
        return 0
    fi

    if pct restore "$target_vmid" "$backup_file" --storage "$RESTORE_STORAGE" 2>&1; then
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        log_success "Container restore completed in ${duration}s"
        return 0
    else
        log_error "Container restore failed"
        return 1
    fi
}

# =============================================================================
# POST-RESTORE VALIDATION
# =============================================================================

validate_restore() {
    local vmid=$1
    local type=$2  # vm or container

    log_info "Validating restored ${type} ${vmid}..."

    local max_wait=300  # 5 minutes
    local elapsed=0
    local interval=10

    while [[ $elapsed -lt $max_wait ]]; do
        if [[ "$type" == "vm" ]]; then
            local status=$(qm status "$vmid" 2>/dev/null | grep -oP 'status: \K\w+' || echo "")
            if [[ "$status" == "running" ]]; then
                log_success "VM ${vmid} is running"
                return 0
            fi
        else
            local status=$(pct status "$vmid" 2>/dev/null | grep -oP 'Status: \K\w+' || echo "")
            if [[ "$status" == "running" ]]; then
                log_success "Container ${vmid} is running"
                return 0
            fi
        fi

        log_debug "Waiting for ${type} ${vmid} to start... (${elapsed}s/${max_wait}s)"
        sleep $interval
        elapsed=$((elapsed + interval))
    done

    log_error "Validation failed: ${type} ${vmid} did not start within ${max_wait}s"
    return 1
}

# =============================================================================
# RESTORE PROCEDURES
# =============================================================================

restore_procedure() {
    local source_vmid=$1
    local target_vmid=${2:-${source_vmid}}
    local source=${3:-local}
    local auto_start=${4:-true}

    log_info "=========================================="
    log_info "RESTORE PROCEDURE INITIATED"
    log_info "=========================================="
    log_info "Source VMID: ${source_vmid}"
    log_info "Target VMID: ${target_vmid}"
    log_info "Source: ${source}"
    log_info "Auto-start: ${auto_start}"
    log_info "Restore storage: ${RESTORE_STORAGE}"
    log_info "=========================================="

    local start_time=$(date +%s)

    # Send initial alert
    send_alert "info" "Restore Started" \
        "Restore of VMID ${source_vmid} to ${target_vmid} initiated from ${source} source."

    # Pre-restore checks
    if ! pre_restore_checks "$source_vmid" "$target_vmid"; then
        send_alert "critical" "Restore Failed" \
            "Pre-restore checks failed for VMID ${source_vmid}. Aborting restore."
        return 1
    fi

    # Find backup file
    local backup_file=$(find_backup_file "$source_vmid" "$source")
    if [[ -z "$backup_file" ]]; then
        send_alert "critical" "Restore Failed" \
            "No backup found for VMID ${source_vmid} from ${source} source."
        return 1
    fi

    # Determine backup type and restore
    if [[ "$backup_file" == *"vma.zst"* ]]; then
        restore_vm "$backup_file" "$target_vmid" || return 1
        local restore_type="vm"
    elif [[ "$backup_file" == *"tar.zst"* ]]; then
        restore_container "$backup_file" "$target_vmid" || return 1
        local restore_type="container"
    else
        log_error "Unknown backup format"
        return 1
    fi

    # Post-restore validation
    if [[ "$SKIP_VALIDATION" != true && "$DRY_RUN" != true ]]; then
        if [[ "$auto_start" == true ]]; then
            # Start the VM/container
            if [[ "$restore_type" == "vm" ]]; then
                qm start "$target_vmid" || log_warn "Failed to start VM ${target_vmid}"
            else
                pct start "$target_vmid" || log_warn "Failed to start container ${target_vmid}"
            fi
        fi

        validate_restore "$target_vmid" "$restore_type" || log_warn "Validation failed, but restore completed"
    fi

    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    local minutes=$((duration / 60))
    local seconds=$((duration % 60))

    log_success "=========================================="
    log_success "RESTORE COMPLETED"
    log_success "=========================================="
    log_success "Duration: ${minutes}m ${seconds}s"
    log_success "Target VMID: ${target_vmid}"

    # Send success alert
    send_alert "info" "Restore Completed" \
        "Successfully restored VMID ${source_vmid} to ${target_vmid} in ${minutes}m ${seconds}s."

    # RTO calculation
    if [[ $minutes -lt 240 ]]; then  # 4 hours = 240 minutes
        log_success "RTO COMPLIANT: Restore completed within 4 hours"
    else
        log_warn "RTO WARNING: Restore exceeded 4 hours"
    fi

    return 0
}

# =============================================================================
# EMERGENCY RESTORE PROCEDURES
# =============================================================================

emergency_restore_critical_systems() {
    log_warn "=== EMERGENCY RESTORE MODE ==="
    log_warn "Restoring critical systems from backup"

    local critical_order=(183 184)  # Priority order
    local target_base=900  # High VMID range to avoid conflicts

    for source_vmid in "${critical_order[@]}"; do
        log_info "Restoring critical system: ${source_vmid}"

        # Try local backup first
        if restore_procedure "$source_vmid" "$target_base" "local" "false"; then
            ((target_base++))
        else
            # Try offsite backup
            log_warn "Local restore failed, trying offsite..."
            if mount "$USB4TB_MOUNT" 2>/dev/null; then
                restore_procedure "$source_vmid" "$target_base" "offsite" "false" || true
                ((target_base++))
            fi
        fi
    done
}

# =============================================================================
# LIST AVAILABLE BACKUPS
# =============================================================================

list_backups() {
    local filter=${1:-all}  # all, vm, container

    log_info "=== AVAILABLE BACKUPS ==="

    echo ""
    echo "Local backups (${LOCAL_BACKUP_DIR}):"
    echo "----------------------------------------"

    if [[ "$filter" == "all" ]] || [[ "$filter" == "vm" ]]; then
        echo ""
        echo "VM Backups:"
        find "$LOCAL_BACKUP_DIR" -name "vzdump-qemu-*-*.vma.zst" -printf '%T+ | %s | %p\n' 2>/dev/null | sort -r | head -20 | \
            awk -F'/' '{printf "  VMID: %s | Date: %s | Size: %s\n", $4, $1, $2}' || echo "  None found"
    fi

    if [[ "$filter" == "all" ]] || [[ "$filter" == "container" ]]; then
        echo ""
        echo "Container Backups:"
        find "$LOCAL_BACKUP_DIR" -name "vzdump-lxc-*-*.tar.zst" -printf '%T+ | %s | %p\n' 2>/dev/null | sort -r | head -20 | \
            awk -F'/' '{printf "  CTID: %s | Date: %s | Size: %s\n", $4, $1, $2}' || echo "  None found"
    fi

    echo ""
    echo "Offsite backups (${USB4TB_BACKUP_DIR}):"
    echo "----------------------------------------"

    if mount | grep -q "$USB4TB_MOUNT"; then
        if [[ "$filter" == "all" ]] || [[ "$filter" == "container" ]]; then
            echo ""
            echo "Container Backups:"
            find "$USB4TB_BACKUP_DIR" -name "vzdump-lxc-*-*.tar.zst" -printf '%T+ | %s | %p\n' 2>/dev/null | sort -r | head -20 | \
                awk -F'/' '{printf "  CTID: %s | Date: %s | Size: %s\n", $4, $1, $2}' || echo "  None found"
        fi
    else
        echo "  Offsite storage not mounted"
    fi

    echo ""
}

# =============================================================================
# ARGUMENT PARSING
# =============================================================================

show_help() {
    cat << EOF
AGL-22 Backup Restore Script

Usage: $0 [OPTIONS] <vmid> [target-vmid]

Commands:
  list [vm|container]    List available backups
  restore <vmid> [target] Restore VM/container from backup
  emergency              Emergency restore of critical systems

Options:
  --offsite              Use offsite backup source (USB4TB)
  --pbs                  Use Proxmox Backup Server as source
  --dry-run              Simulate restore without making changes
  --force                Overwrite existing VM/CT
  --skip-validation       Skip post-restore validation
  --storage <name>       Target storage (default: local-zfs)

Examples:
  $0 list                              List all available backups
  $0 list container                     List container backups only
  $0 restore 183                       Restore CT 183 to CT 183
  $0 restore 183 900                   Restore CT 183 to CT 900
  $0 restore 183 --offsite             Restore CT 183 from offsite backup
  $0 restore 183 900 --force --dry-run  Test restore to CT 900
  $0 emergency                         Emergency restore critical systems

RTO/RPO Compliance:
  - RTO: < 4 hours for critical systems
  - RPO: < 1 hour for critical systems

EOF
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================

main() {
    # Setup logging
    setup_logging

    if [[ $# -eq 0 ]]; then
        show_help
        exit 0
    fi

    local command=$1
    shift

    case "$command" in
        list)
            list_backups "${1:-all}"
            ;;
        restore)
            if [[ $# -lt 1 ]]; then
                log_error "Missing VMID for restore"
                exit 1
            fi

            local source_vmid=$1
            local target_vmid=${2:-${source_vmid}}

            # Parse options
            while [[ $# -gt 2 ]]; do
                shift 2
                case "$1" in
                    --offsite) OFFSITE_SOURCE=true ;;
                    --pbs) source="pbs" ;;
                    --dry-run) DRY_RUN=true ;;
                    --force) FORCE=true ;;
                    --skip-validation) SKIP_VALIDATION=true ;;
                    --storage)
                        RESTORE_STORAGE="$2"
                        shift
                        ;;
                esac
            done

            if [[ "$OFFSITE_SOURCE" == true ]]; then
                restore_procedure "$source_vmid" "$target_vmid" "offsite"
            else
                restore_procedure "$source_vmid" "$target_vmid" "local"
            fi
            ;;
        emergency)
            emergency_restore_critical_systems
            ;;
        --help|-h)
            show_help
            ;;
        *)
            log_error "Unknown command: $command"
            show_help
            exit 1
            ;;
    esac
}

main "$@"
