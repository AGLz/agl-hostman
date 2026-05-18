#!/bin/bash
# =============================================================================
# PBS Emergency Restore Script
# =============================================================================
# Purpose: Emergency restore procedures for PBS backups
# Version: 1.0.0
# Date: 2026-02-07
#
# This script provides automated restore capabilities for disaster recovery.
# Use with caution - restores can overwrite existing VMs/CTs.
#
# =============================================================================

set -euo pipefail

# Configuration
PBS_HOST="10.6.0.14"
PBS_HOST_TS="100.65.189.83"
PBS_PORT="8007"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# ============================================================================
# FUNCTIONS
# =============================================================================

log() {
    echo -e "${BLUE}[$(date '+%H:%M:%S')]${NC} $*"
}

log_success() {
    echo -e "${GREEN}✓${NC} $*"
}

log_error() {
    echo -e "${RED}✗${NC} $*"
}

log_warning() {
    echo -e "${YELLOW}⚠${NC} $*"
}

confirm_dangerous() {
    local message="$1"
    echo ""
    log_warning "=============================================="
    log_warning "WARNING: $message"
    log_warning "=============================================="
    echo ""
    read -p "Are you sure you want to continue? (type 'yes' to confirm): " -r
    echo ""
    if [[ ! "$REPLY" == "yes" ]]; then
        log_error "Operation cancelled"
        exit 1
    fi
}

check_pbs_connectivity() {
    log "Checking PBS server connectivity..."

    # Try WireGuard first, then Tailscale
    for ip in "$PBS_HOST" "$PBS_HOST_TS"; do
        if timeout 5 ssh -o ConnectTimeout=3 root@${ip} "echo OK" > /dev/null 2>&1; then
            PBS_IP="$ip"
            log_success "Connected to PBS: $ip"
            return 0
        fi
    done

    log_error "Cannot connect to PBS server"
    return 1
}

list_available_backups() {
    local datastore="${1:-}"
    local vmid="${2:-}"

    log "Listing available backups..."

    if [[ -z "$datastore" ]]; then
        echo "Available datastores:"
        ssh root@${PBS_IP} "proxmox-backup-manager datastore list" 2>/dev/null | grep "^datastore"
    else
        echo "Snapshots in $datastore:"
        ssh root@${PBS_IP} "proxmox-backup-manager snapshot-list '$datastore'" 2>/dev/null | tail -n +2
    fi
}

get_backup_details() {
    local datastore="$1"
    local snapshot="$2"

    log "Backup details: $datastore/$snapshot"

    ssh root@${PBS_IP} "proxmox-backup-manager snapshot-list '$datastore'" 2>/dev/null | grep "$snapshot"
}

restore_container() {
    local vmid="$1"
    local datastore="$2"
    local snapshot="$3"
    local storage="${4:-local-zfs}"
    local new_vmid="${5:-}"

    confirm_dangerous "About to RESTORE CT${vmid} from backup"

    log "Restoring CT${vmid} from ${datastore}/${snapshot}..."

    if [[ -n "$new_vmid" ]]; then
        log "Restoring to new VMID: CT${new_vmid}"
        pct restore "$new_vmid" "$datastore:$snapshot" --storage "$storage" --force
    else
        log_warning "This will OVERWRITE existing CT${vmid}"
        confirm_dangerous "CT${vmid} will be destroyed and restored"
        pct destroy "$vmid" --destroy-unreferenced-disks yes --purge 1
        pct restore "$vmid" "$datastore:$snapshot" --storage "$storage"
    fi

    log_success "CT${vmid} restored successfully"
    log "Starting container..."
    pct start "$vmid"
}

restore_vm() {
    local vmid="$1"
    local datastore="$2"
    local snapshot="$3"
    local storage="${4:-local-zfs}"
    local new_vmid="${5:-}"

    confirm_dangerous "About to RESTORE VM${vmid} from backup"

    log "Restoring VM${vmid} from ${datastore}/${snapshot}..."

    if [[ -n "$new_vmid" ]]; then
        log "Restoring to new VMID: VM${new_vmid}"
        qmrestore "$datastore:$snapshot" "$new_vmid" --storage "$storage" --force
    else
        log_warning "This will OVERWRITE existing VM${vmid}"
        confirm_dangerous "VM${vmid} will be destroyed and restored"
        qm destroy "$vmid" --destroy-unreferenced-disks yes --purge 1
        qmrestore "$datastore:$snapshot" "$vmid" --storage "$storage"
    fi

    log_success "VM${vmid} restored successfully"
    log "Starting VM..."
    qm start "$vmid"
}

restore_from_file() {
    local backup_file="$1"
    local vmid="$2"
    local storage="${3:-local-zfs}"

    if [[ ! -f "$backup_file" ]]; then
        log_error "Backup file not found: $backup_file"
        return 1
    fi

    confirm_dangerous "About to RESTORE from file: $backup_file"

    # Determine if it's a VM or CT backup
    if [[ "$backup_file" == *"-vzdump-lxc-"* ]]; then
        log "Detected LXC container backup"
        pct restore "$vmid" "$backup_file" --storage "$storage" --force
    elif [[ "$backup_file" == *"-vzdump-qemu-"* ]]; then
        log "Detected QEMU VM backup"
        qmrestore "$backup_file" "$vmid" --storage "$storage" --force
    else
        log_error "Unknown backup format"
        return 1
    fi

    log_success "Restore completed from file"
}

emergency_restore_all() {
    local target_host="${1:-100.107.113.33}"  # Default to AGLSRV1
    local datastore="${2:-datastore-aglsrv1}"

    log_warning "=========================================="
    log_warning "EMERGENCY RESTORE ALL"
    log_warning "=========================================="
    log "Target: $target_host"
    log "Datastore: $datastore"
    log ""

    confirm_dangerous "This will restore ALL VMs/CTs from backup. Existing data will be LOST!"

    log "Fetching backup list..."
    local backups=$(ssh root@${PBS_IP} "proxmox-backup-manager snapshot-list '$datastore'" 2>/dev/null | tail -n +2)

    local count=0
    echo "$backups" | while read -r snapshot_line; do
        local snapshot=$(echo "$snapshot_line" | awk '{print $1}')
        local type=$(echo "$snapshot_line" | awk '{print $2}' | grep -oP '(?<=type:)[^,]+')

        # Extract VMID from snapshot (format: host/vm-type/vmid/...)
        local vmid=$(echo "$snapshot" | cut -d'/' -f3)

        log "Restoring $type VMID: $vmid from $snapshot"

        if [[ "$type" == "ct" ]]; then
            restore_container "$vmid" "$datastore" "$snapshot" "local-zfs" "$vmid" &
        elif [[ "$type" == "vm" ]]; then
            restore_vm "$vmid" "$datastore" "$snapshot" "local-zfs" "$vmid" &
        fi

        ((count++))

        # Don't overload the system
        if [[ $((count % 3)) -eq 0 ]]; then
            log "Waiting for current restores to complete..."
            wait
        fi
    done

    wait
    log_success "Emergency restore completed"
}

list_failed_vms() {
    log "Checking for failed VMs/CTs that need restore..."

    for host in "${PROMOX_HOSTS[@]}"; do
        log "Host: $host"

        ssh root@${host} bash << 'EOF'
# Check for VMs with status "stopped" but should be "running"
pvesh get /cluster/resources --type vm | jq -r '.[] | select(.status == "stopped") | "\(.vmid) \(.name) \(.type)"'
EOF
    done
}

interactive_restore() {
    log "Starting interactive restore wizard..."
    echo ""

    # Step 1: Choose datastore
    log "Available datastores:"
    local datastores=$(ssh root@${PBS_IP} "proxmox-backup-manager datastore list" 2>/dev/null | grep "^datastore" | awk '{print $1}')

    local i=1
    echo "$datastores" | while read -r ds; do
        echo "  [$i] $ds"
        ((i++))
    done

    echo ""
    read -p "Select datastore (by name): " datastore

    if [[ -z "$datastore" ]]; then
        log_error "No datastore selected"
        return 1
    fi

    # Step 2: List backups
    log "Available backups in $datastore:"
    local backups=$(ssh root@${PBS_IP} "proxmox-backup-manager snapshot-list '$datastore'" 2>/dev/null | tail -n +2)

    i=1
    echo "$backups" | while read -r snap; do
        local time=$(echo "$snap" | awk '{print $1 " " $2}')
        local vmid=$(echo "$snap" | cut -d'/' -f3)
        echo "  [$i] VMID: $vmid | Time: $time"
        ((i++))
    done

    echo ""
    read -p "Enter VMID to restore: " vmid

    if [[ -z "$vmid" ]]; then
        log_error "No VMID specified"
        return 1
    fi

    # Step 3: Choose storage target
    log "Available storage targets:"
    pvesm list | grep -v "pbs:" | awk '{print "  " $1}'

    echo ""
    read -p "Target storage (default: local-zfs): " storage
    storage="${storage:-local-zfs}"

    # Step 4: Confirm new VMID or overwrite
    read -p "Restore to new VMID (leave empty to overwrite CT${vmid}): " new_vmid

    # Get latest snapshot
    local snapshot=$(echo "$backups" | grep "/${vmid}/" | tail -1 | awk '{print $1}')

    if [[ -z "$snapshot" ]]; then
        log_error "No backup found for VMID $vmid"
        return 1
    fi

    # Step 5: Perform restore
    if [[ "$vmid" -ge 100 && "$vmid" -lt 1000 ]]; then
        # Container
        restore_container "$vmid" "$datastore" "$snapshot" "$storage" "$new_vmid"
    else
        # VM
        restore_vm "$vmid" "$datastore" "$snapshot" "$storage" "$new_vmid"
    fi
}

# ============================================================================
# MAIN MENU
# =============================================================================

show_usage() {
    cat << 'EOF'
PBS Emergency Restore Script

Usage: ./scripts/pbs-emergency-restore.sh [command] [options]

Commands:
  list [datastore]          List available backups
  details <datastore> <snapshot>  Show backup details
  restore-ct <vmid> <datastore> <snapshot> [storage] [new_vmid]
  restore-vm <vmid> <datastore> <snapshot> [storage] [new_vmid]
  restore-file <backup_file> <vmid> [storage]
  restore-all [host] [datastore]
  interactive              Interactive restore wizard
  failed                   List VMs/CTs that may need restore

Examples:
  # List all backups
  ./scripts/pbs-emergency-restore.sh list

  # List backups for specific datastore
  ./scripts/pbs-emergency-restore.sh list datastore-aglsrv1

  # Restore container to new VMID
  ./scripts/pbs-emergency-restore.sh restore-ct 179 datastore-aglsrv1 "2026-01-15 03:15:00" local-zfs 999

  # Interactive restore
  ./scripts/pbs-emergency-restore.sh interactive

  # Emergency restore all to host
  ./scripts/pbs-emergency-restore.sh restore-all 100.107.113.33 datastore-aglsrv1

EOF
}

# Main execution
main() {
    if [[ $# -eq 0 ]]; then
        show_usage
        exit 0
    fi

    local command="$1"
    shift

    # Check connectivity first
    check_pbs_connectivity || {
        log_error "Cannot proceed without PBS connectivity"
        exit 1
    }

    case "$command" in
        list)
            list_available_backups "$@"
            ;;
        details)
            get_backup_details "$@"
            ;;
        restore-ct)
            restore_container "$@"
            ;;
        restore-vm)
            restore_vm "$@"
            ;;
        restore-file)
            restore_from_file "$@"
            ;;
        restore-all)
            emergency_restore_all "$@"
            ;;
        failed)
            list_failed_vms
            ;;
        interactive)
            interactive_restore
            ;;
        help|--help|-h)
            show_usage
            ;;
        *)
            log_error "Unknown command: $command"
            show_usage
            exit 1
            ;;
    esac
}

main "$@"
