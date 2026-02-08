#!/bin/bash
# Proxmox VM Migration Script
# Live migrate VM to another node with optional storage migration
# Usage: ./px-vm-migrate.sh <vmid> <target-node> [--with-local-disks] [--online] [--target-storage]

set -euo pipefail

# Configuration
MIGRATION_TIMEOUT="${MIGRATION_TIMEOUT:-600}"  # 10 minutes default
CHECK_INTERVAL="${CHECK_INTERVAL:-5}"           # Check every 5 seconds

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

check_vm_exists() {
    local vmid="$1"

    if ! qm config "$vmid" &>/dev/null; then
        log_error "VM $vmid does not exist"
        exit 1
    fi

    log_info "VM $vmid found"
}

check_vm_status() {
    local vmid="$1"

    local status
    status=$(qm status "$vmid" --no-output || true)

    if [[ "$status" == "running" ]]; then
        log_info "VM is currently running"
        return 0
    elif [[ "$status" == "stopped" ]]; then
        log_warn "VM is currently stopped"
        return 1
    else
        log_error "Unknown VM status: $status"
        exit 1
    fi
}

check_target_node() {
    local target_node="$1"

    if ! pvesh get /nodes/"$target_node" &>/dev/null; then
        log_error "Target node $target_node not found or not accessible"
        exit 1
    fi

    log_info "Target node $target_node is accessible"
}

check_storage_migration() {
    local vmid="$1"
    local target_storage="${2:-}"

    log_step "Checking storage requirements"

    # Get VM disks
    local disks
    disks=$(qm config "$vmid" | grep -E '(scsi|sata|virtio|ide)[0-9]+:' | grep -oP 'storage=\K[^,]+' || true)

    if [[ -z "$disks" ]]; then
        log_info "No local disks found, migration without storage"
        return 0
    fi

    log_info "Found disks on storage: $disks"

    # Check if storage is shared
    local storage_type
    for disk in $disks; do
        storage_type=$(pvesm get "$disk" --type 2>/dev/null || echo "unknown")

        if [[ "$storage_type" != "nfs" ]] && [[ "$storage_type" != "cephfs" ]] && [[ "$storage_type" != "pbs" ]]; then
            log_warn "Storage $disk is not shared ($storage_type)"

            if [[ -n "$target_storage" ]]; then
                log_info "Target storage specified: $target_storage"
            else
                log_error "Storage migration required but --target-storage not specified"
                exit 1
            fi
        fi
    done

    return 0
}

perform_migration() {
    local vmid="$1"
    local target_node="$2"
    local with_local_disks="$3"
    local online="$4"
    local target_storage="$5"

    log_step "Initiating migration"

    local migrate_cmd="qm migrate $vmid --target $target_node"

    if [[ "$with_local_disks" == "true" ]]; then
        migrate_cmd="$migrate_cmd --with-local-disks"
        log_info "Storage migration enabled"
    fi

    if [[ "$online" == "true" ]]; then
        migrate_cmd="$migrate_cmd --online"
        log_info "Live migration enabled"
    fi

    if [[ -n "$target_storage" ]]; then
        migrate_cmd="$migrate_cmd --target-storage $target_storage"
        log_info "Target storage: $target_storage"
    fi

    log_info "Migration command: $migrate_cmd"

    # Execute migration
    if $migrate_cmd; then
        log_info "Migration command submitted successfully"
    else
        log_error "Migration command failed"
        exit 1
    fi
}

monitor_migration() {
    local vmid="$1"
    local timeout="$2"

    log_step "Monitoring migration progress"

    local elapsed=0

    while [ $elapsed -lt "$timeout" ]; do
        # Check if migration is complete (VM is on target node)
        local current_node
        current_node=$(pvesh get /cluster/resources --type vm | \
            jq -r ".[] | select(.vmid == $vmid) | .node" 2>/dev/null || echo "")

        if [[ -n "$current_node" ]]; then
            log_info "VM is now on node: $current_node"
            return 0
        fi

        # Check task status
        local task_status
        task_status=$(pvesh get /cluster/tasks 2>/dev/null | \
            jq -r ".[] | select(.type == \"qmigrate\" and .vmid == $vmid) | .status" 2>/dev/null || echo "")

        if [[ "$task_status" == "OK" ]]; then
            log_info "Migration completed successfully"
            return 0
        elif [[ "$task_status" == "err" ]]; then
            log_error "Migration failed (task status: err)"
            return 1
        fi

        log_info "Migration in progress... (${elapsed}s elapsed)"
        sleep "$CHECK_INTERVAL"
        elapsed=$((elapsed + CHECK_INTERVAL))
    done

    log_error "Migration timed out after ${timeout}s"
    return 1
}

verify_migration() {
    local vmid="$1"
    local expected_node="$2"

    log_step "Verifying migration"

    local current_node
    current_node=$(pvesh get /cluster/resources --type vm | \
        jq -r ".[] | select(.vmid == $vmid) | .node" 2>/dev/null || echo "")

    if [[ "$current_node" == "$expected_node" ]]; then
        log_info "VM successfully migrated to $expected_node"
        return 0
    else
        log_error "VM verification failed. Expected: $expected_node, Got: $current_node"
        return 1
    fi
}

print_usage() {
    cat << EOF
Usage: $0 <vmid> <target-node> [options]

Arguments:
  vmid          VM ID to migrate
  target-node   Destination node name

Options:
  --with-local-disks   Migrate local disk storage
  --online            Perform live migration (default: true if VM running)
  --target-storage    Target storage for disk migration
  --timeout           Migration timeout in seconds (default: 600)

Environment Variables:
  MIGRATION_TIMEOUT    Maximum migration time (default: 600s)
  CHECK_INTERVAL      Status check interval (default: 5s)

Examples:
  # Live migrate with storage
  $0 200 AGLSRV6 --with-local-disks

  # Live migrate without storage (shared storage)
  $0 201 AGLSRV6

  # Offline migration with specific storage
  $0 202 AGLSRV6 --with-local-disks --target-storage local-zfs

  # Custom timeout
  $0 203 AGLSRV6 --with-local-disks --timeout 1200
EOF
}

main() {
    if [ "$#" -lt 2 ]; then
        print_usage
        exit 1
    fi

    local vmid="$1"
    local target_node="$2"
    shift 2

    local with_local_disks="false"
    local online="false"
    local target_storage=""
    local timeout="$MIGRATION_TIMEOUT"

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --with-local-disks)
                with_local_disks="true"
                shift
                ;;
            --online)
                online="true"
                shift
                ;;
            --target-storage)
                target_storage="$2"
                shift 2
                ;;
            --timeout)
                timeout="$2"
                shift 2
                ;;
            *)
                log_error "Unknown option: $1"
                print_usage
                exit 1
                ;;
        esac
    done

    log_info "Starting VM migration"
    log_info "VMID: $vmid"
    log_info "Target Node: $target_node"

    # Pre-flight checks
    check_vm_exists "$vmid"

    if check_vm_status "$vmid"; then
        online="true"
    fi

    check_target_node "$target_node"
    check_storage_migration "$vmid" "$target_storage"

    # Perform migration
    perform_migration "$vmid" "$target_node" "$with_local_disks" "$online" "$target_storage"

    # Monitor and verify
    if monitor_migration "$vmid" "$timeout"; then
        verify_migration "$vmid" "$target_node"
        log_info "Migration completed successfully"
    else
        log_error "Migration monitoring failed"
        exit 1
    fi
}

main "$@"
