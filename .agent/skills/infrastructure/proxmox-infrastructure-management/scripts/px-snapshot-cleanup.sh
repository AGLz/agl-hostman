#!/bin/bash
# Proxmox Snapshot Cleanup Script
# Remove old snapshots based on retention policy
# Retention: 7 daily, 4 weekly, 3 monthly snapshots
# Usage: ./px-snapshot-cleanup.sh <vmid> [--dry-run] [--force]

set -euo pipefail

# Configuration
RETENTION_DAILY="${RETENTION_DAILY:-7}"
RETENTION_WEEKLY="${RETENTION_WEEKLY:-4}"
RETENTION_MONTHLY="${RETENTION_MONTHLY:-3}"

# Patterns
AUTO_PATTERN="${AUTO_PATTERN:-auto-}"
BACKUP_PATTERN="${BACKUP_PATTERN:-backup-}"

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

log_debug() {
    echo -e "${BLUE}[DEBUG]${NC} $1"
}

classify_snapshot() {
    local snapname="$1"
    local snaptime="$2"

    # Parse snapshot time from name or timestamp
    local snap_date
    if [[ "$snapname" =~ ([0-9]{8}) ]]; then
        snap_date="${BASH_REMATCH[1]}"
    elif [[ -n "$snaptime" ]]; then
        snap_date=$(date -d "$snaptime" +%Y%m%d 2>/dev/null || echo "")
    else
        snap_date=$(date +%Y%m%d)
    fi

    if [[ -z "$snap_date" ]]; then
        echo "manual"
        return
    fi

    local snap_year="${snap_date:0:4}"
    local snap_month="${snap_date:4:2}"
    local snap_day="${snap_date:6:2}"

    local current_year
    local current_month
    local current_day
    local current_week
    current_year=$(date +%Y)
    current_month=$(date +%m)
    current_day=$(date +%d)
    current_week=$(date +%U)

    local snap_week
    snap_week=$(date -d "${snap_year}-${snap_month}-${snap_day}" +%U 2>/dev/null || echo "0")

    # Calculate age in days
    local snap_epoch
    local current_epoch
    snap_epoch=$(date -d "${snap_year}-${snap_month}-${snap_day}" +%s 2>/dev/null || echo "0")
    current_epoch=$(date +%s)

    local age_days
    age_days=$(( (current_epoch - snap_epoch) / 86400 ))

    # Classify based on age
    if [ "$age_days" -le 7 ]; then
        echo "daily"
    elif [ "$age_days" -le 30 ]; then
        echo "weekly"
    else
        echo "monthly"
    fi
}

get_snapshots() {
    local vmid="$1"
    local is_vm="$2"

    if [[ "$is_vm" == "true" ]]; then
        qm listsnapshot "$vmid" --no-output 2>/dev/null || true
    else
        pct listsnapshot "$vmid" --no-output 2>/dev/null || true
    fi
}

delete_snapshot() {
    local vmid="$1"
    local snapname="$2"
    local is_vm="$3"
    local dry_run="$4"
    local force="$5"

    if [[ "$dry_run" == "true" ]]; then
        log_info "[DRY-RUN] Would delete snapshot: $snapname"
        return 0
    fi

    if [[ "$force" != "true" ]]; then
        log_warn "Skipping deletion (use --force to delete): $snapname"
        return 0
    fi

    if [[ "$is_vm" == "true" ]]; then
        qm delsnapshot "$vmid" "$snapname" 2>/dev/null
    else
        pct delsnapshot "$vmid" "$snapname" 2>/dev/null
    fi

    if [[ $? -eq 0 ]]; then
        log_info "Deleted snapshot: $snapname"
        return 0
    else
        log_error "Failed to delete snapshot: $snapname"
        return 1
    fi
}

cleanup_snapshots() {
    local vmid="$1"
    local dry_run="$2"
    local force="$3"

    log_info "Processing VM/Container: $vmid"

    # Detect if VM or container
    local is_vm="false"
    if qm config "$vmid" &>/dev/null; then
        is_vm="true"
        log_debug "Detected as VM"
    elif pct config "$vmid" &>/dev/null; then
        is_vm="false"
        log_debug "Detected as container"
    else
        log_error "VMID $vmid not found"
        return 1
    fi

    # Get snapshots
    local snapshots
    snapshots=$(get_snapshots "$vmid" "$is_vm")

    if [[ -z "$snapshots" ]]; then
        log_info "No snapshots found"
        return 0
    fi

    # Parse snapshots into arrays
    declare -a daily_snaps
    declare -a weekly_snaps
    declare -a monthly_snaps

    while IFS= read -r line; do
        local snapname
        local snaptime

        snapname=$(echo "$line" | awk '{print $1}')
        snaptime=$(echo "$line" | awk '{print $2" "$3}')

        # Skip current snapshot
        if [[ "$snapname" == "current" ]]; then
            continue
        fi

        local classification
        classification=$(classify_snapshot "$snapname" "$snaptime")

        case "$classification" in
            daily)
                daily_snaps+=("$snapname|$snaptime")
                ;;
            weekly)
                weekly_snaps+=("$snapname|$snaptime")
                ;;
            monthly)
                monthly_snaps+=("$snapname|$snaptime")
                ;;
            manual)
                log_warn "Manual snapshot (preserved): $snapname"
                ;;
        esac
    done <<< "$snapshots"

    # Clean up old snapshots (keep newest, delete oldest)
    log_info "Daily snapshots: ${#daily_snaps[@]} (keeping: $RETENTION_DAILY)"
    log_info "Weekly snapshots: ${#weekly_snaps[@]} (keeping: $RETENTION_WEEKLY)"
    log_info "Monthly snapshots: ${#monthly_snaps[@]} (keeping: $RETENTION_MONTHLY)"

    local deleted_count=0

    # Delete excess daily snapshots
    if [[ ${#daily_snaps[@]} -gt $RETENTION_DAILY ]]; then
        local excess=$(( ${#daily_snaps[@]} - RETENTION_DAILY ))
        log_info "Deleting $excess old daily snapshots"

        for ((i=0; i<$excess; i++)); do
            local snap_info="${daily_snaps[$i]}"
            local snap_name="${snap_info%%|*}"

            if delete_snapshot "$vmid" "$snap_name" "$is_vm" "$dry_run" "$force"; then
                deleted_count=$((deleted_count + 1))
            fi
        done
    fi

    # Delete excess weekly snapshots
    if [[ ${#weekly_snaps[@]} -gt $RETENTION_WEEKLY ]]; then
        local excess=$(( ${#weekly_snaps[@]} - RETENTION_WEEKLY ))
        log_info "Deleting $excess old weekly snapshots"

        for ((i=0; i<$excess; i++)); do
            local snap_info="${weekly_snaps[$i]}"
            local snap_name="${snap_info%%|*}"

            if delete_snapshot "$vmid" "$snap_name" "$is_vm" "$dry_run" "$force"; then
                deleted_count=$((deleted_count + 1))
            fi
        done
    fi

    # Delete excess monthly snapshots
    if [[ ${#monthly_snaps[@]} -gt $RETENTION_MONTHLY ]]; then
        local excess=$(( ${#monthly_snaps[@]} - RETENTION_MONTHLY ))
        log_info "Deleting $excess old monthly snapshots"

        for ((i=0; i<$excess; i++)); do
            local snap_info="${monthly_snaps[$i]}"
            local snap_name="${snap_info%%|*}"

            if delete_snapshot "$vmid" "$snap_name" "$is_vm" "$dry_run" "$force"; then
                deleted_count=$((deleted_count + 1))
            fi
        done
    fi

    log_info "Deleted $deleted_count snapshots for VMID $vmid"
}

cleanup_all() {
    local dry_run="$1"
    local force="$2"

    log_info "Cleaning snapshots for all VMs and containers"

    # Get all VMs and containers
    local all_vmid
    all_vmid=$(pvesh get /cluster/resources --type vm -output-format json | \
        jq -r '.[].vmid' 2>/dev/null || true)

    for vmid in $all_vmid; do
        cleanup_snapshots "$vmid" "$dry_run" "$force"
        echo ""
    done
}

print_usage() {
    cat << EOF
Usage: $0 <vmid> [options] | --all [options]

Arguments:
  vmid          VM ID to cleanup (or --all for all VMs/containers)

Options:
  --dry-run     Show what would be deleted without actually deleting
  --force       Actually delete snapshots (required for deletion)
  --all         Process all VMs and containers

Environment Variables:
  RETENTION_DAILY     Number of daily snapshots to keep (default: 7)
  RETENTION_WEEKLY    Number of weekly snapshots to keep (default: 4)
  RETENTION_MONTHLY   Number of monthly snapshots to keep (default: 3)

Snapshot Naming:
  Snapshots are classified by name patterns:
  - auto-YYYYMMDD-HHMMSS: Auto-classified by date
  - backup-YYYYMMDD: Backup snapshots
  - Manual names: Preserved unless aged out

Retention Policy:
  - Daily: Keep $RETENTION_DAILY most recent days
  - Weekly: Keep $RETENTION_WEEKLY most recent weeks
  - Monthly: Keep $RETENTION_MONTHLY most recent months

Examples:
  # Dry run for specific VM
  $0 200 --dry-run

  # Delete old snapshots for VM 200
  $0 200 --force

  # Dry run for all VMs
  $0 --all --dry-run

  # Clean all VMs and containers
  $0 --all --force
EOF
}

main() {
    if [ "$#" -lt 1 ]; then
        print_usage
        exit 1
    fi

    local target="$1"
    shift

    local dry_run="false"
    local force="false"

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --dry-run)
                dry_run="true"
                shift
                ;;
            --force)
                force="true"
                shift
                ;;
            *)
                log_error "Unknown option: $1"
                print_usage
                exit 1
                ;;
        esac
    done

    if [[ "$dry_run" == "true" ]]; then
        log_warn "DRY-RUN MODE: No snapshots will be deleted"
    elif [[ "$force" != "true" ]]; then
        log_error "DRY-RUN MODE: Use --force to actually delete snapshots"
        dry_run="true"
    fi

    if [[ "$target" == "--all" ]]; then
        cleanup_all "$dry_run" "$force"
    else
        cleanup_snapshots "$target" "$dry_run" "$force"
    fi

    log_info "Snapshot cleanup completed"
}

main "$@"
