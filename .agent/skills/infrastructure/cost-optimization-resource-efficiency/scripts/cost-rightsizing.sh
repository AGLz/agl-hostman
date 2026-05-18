#!/bin/bash
# cost-rightsizing.sh - Recommend and apply rightsizing based on utilization
# Part of the cost-optimization-resource-efficiency skill

set -euo pipefail

# Configuration
ANALYSIS_PERIOD="${1:-7d}"  # How long to analyze
ACTION="${2:-analyze}"      # analyze, apply, rollback
DRY_RUN="${DRY_RUN:-true}"  # true = no changes, false = apply changes
STATE_FILE="/tmp/cost-rightsizing-state.json"
ROLLBACK_TIMESTAMP="${3:-}"

# Thresholds for rightsizing
CPU_LOW_THRESHOLD="${CPU_LOW_THRESHOLD:-30}"    # % - Downsize if below
MEMORY_LOW_THRESHOLD="${MEMORY_LOW_THRESHOLD:-30}" # % - Downsize if below
CPU_HIGH_THRESHOLD="${CPU_HIGH_THRESHOLD:-80}"    # % - Upsize if above
MEMORY_HIGH_THRESHOLD="${MEMORY_HIGH_THRESHOLD:-80}" # % - Upsize if above

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Logging
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
    exit 1
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

# Save state for rollback
save_state() {
    local vmid=$1
    local current_cores=$2
    local current_memory=$3
    local current_swap=$4

    local timestamp=$(date +%s)
    local state_entry="{\"vmid\":$vmid,\"cores\":$current_cores,\"memory\":$current_memory,\"swap\":$current_swap,\"timestamp\":$timestamp}"

    if [[ -f "$STATE_FILE" ]]; then
        # Append to existing state
        local temp=$(mktemp)
        jq ". += [$state_entry]" "$STATE_FILE" > "$temp"
        mv "$temp" "$STATE_FILE"
    else
        # Create new state file
        echo "[$state_entry]" > "$STATE_FILE"
    fi
}

# Get current container config
get_container_config() {
    local vmid=$1
    local config="/etc/pve/lxc/${vmid}.conf"

    if [[ ! -f "$config" ]]; then
        error "Container config not found: $config"
    fi

    local cores=$(grep -oP '^cores:\s*\K\d+' "$config" || echo "2")
    local memory=$(grep -oP '^memory:\s*\K\d+' "$config" || echo "4096")
    local swap=$(grep -oP '^swap:\s*\K\d+' "$config" || echo "2048")

    echo "$cores:$memory:$swap"
}

# Get utilization metrics for a container
get_container_utilization() {
    local vmid=$1
    local status=$(pct status "$vmid" 2>/dev/null | awk '{print $2}')

    if [[ "$status" != "running" ]]; then
        echo "stopped:0:0:0"
        return
    fi

    # Get CPU utilization (average over 5 samples)
    local cpu_util=0
    for i in {1..5}; do
        local sample=$(pct exec "$vmid" -- top -bn1 2>/dev/null | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1 || echo "0")
        cpu_util=$(echo "$cpu_util + $sample" | bc)
        sleep 1
    done
    cpu_util=$(echo "scale=1; $cpu_util / 5" | bc)

    # Get memory utilization
    local memory_info=$(pct exec "$vmid" -- free -m 2>/dev/null | awk '/^Mem:/ {print $2,$3}' || echo "0 0")
    local memory_total=$(echo "$memory_info" | awk '{print $1}')
    local memory_used=$(echo "$memory_info" | awk '{print $2}')

    if [[ $memory_total -gt 0 ]]; then
        local memory_util=$(echo "scale=1; ($memory_used * 100) / $memory_total" | bc)
    else
        local memory_util=0
    fi

    # Get disk utilization
    local disk_usage=$(pct exec "$vmid" -- df -h / 2>/dev/null | awk 'NR==2 {print $5}' | cut -d'%' -f1 || echo "0")

    echo "running:${cpu_util}:${memory_util}:${disk_usage}"
}

# Recommend new size based on utilization
recommend_size() {
    local current_cores=$1
    local current_memory_mb=$2
    local current_swap_mb=$3
    local cpu_util=$4
    local memory_util=$5

    local new_cores=$current_cores
    local new_memory=$current_memory_mb
    local new_swap=$current_swap_mb
    local reason=""

    # CPU rightsizing
    local cpu_int=$(echo "$cpu_util" | cut -d'.' -f1)
    if [[ $cpu_int -lt $CPU_LOW_THRESHOLD ]] && [[ $current_cores -gt 1 ]]; then
        # Can reduce CPU
        local reduction=$((current_cores / 2))
        new_cores=$((current_cores - reduction))
        [[ $new_cores -lt 1 ]] && new_cores=1
        reason="$reason CPU: $cpu_util% utilization -> reduce from $current_cores to $new_cores cores."
    elif [[ $cpu_int -gt $CPU_HIGH_THRESHOLD ]]; then
        # Need more CPU
        new_cores=$((current_cores * 2))
        reason="$reason CPU: $cpu_util% utilization -> increase from $current_cores to $new_cores cores."
    fi

    # Memory rightsizing
    local mem_int=$(echo "$memory_util" | cut -d'.' -f1)
    if [[ $mem_int -lt $MEMORY_LOW_THRESHOLD ]] && [[ $current_memory_mb -gt 2048 ]]; then
        # Can reduce memory (minimum 2GB)
        local reduction=$((current_memory_mb / 4))
        new_memory=$((current_memory_mb - reduction))
        [[ $new_memory -lt 2048 ]] && new_memory=2048
        reason="$reason Memory: $memory_util% utilization -> reduce from ${current_memory_mb}MB to ${new_memory}MB."
    elif [[ $mem_int -gt $MEMORY_HIGH_THRESHOLD ]]; then
        # Need more memory
        new_memory=$((current_memory_mb * 2))
        reason="$reason Memory: $memory_util% utilization -> increase from ${current_memory_mb}MB to ${new_memory}MB."
    fi

    # Adjust swap proportionally to memory
    new_swap=$((new_memory / 2))

    echo "$new_cores:$new_memory:$new_swap:$reason"
}

# Analyze all containers and recommend changes
analyze_containers() {
    log "Analyzing container utilization over $ANALYSIS_PERIOD"

    echo ""
    echo "=== Rightsizing Recommendations ==="
    echo ""

    local total_savings=0

    for vmid in $(pct list | awk 'NR>1 {print $1}'); do
        local name=$(pct config "$vmid" | grep -oP '^hostname:\s*\K.+' || echo "ct${vmid}")
        local config=$(get_container_config "$vmid")
        IFS=':' read -r current_cores current_memory current_swap <<< "$config"

        local utilization=$(get_container_utilization "$vmid")
        IFS=':' read -r status cpu_util mem_util disk_util <<< "$utilization"

        if [[ "$status" != "running" ]]; then
            echo -e "${YELLOW}CT $vmid ($name)${NC}: $status - skip rightsizing"
            continue
        fi

        local recommendation=$(recommend_size "$current_cores" "$current_memory" "$current_swap" "$cpu_util" "$mem_util")
        IFS=':' read -r new_cores new_memory new_swap reason <<< "$recommendation"

        # Calculate savings
        local current_cost=$(calculate_container_cost "$vmid" "$current_cores" "$current_memory")
        local new_cost=$(calculate_container_cost "$vmid" "$new_cores" "$new_memory")
        local savings=$(echo "scale=2; $current_cost - $new_cost" | bc)
        total_savings=$(echo "scale=2; $total_savings + $savings" | bc)

        if [[ $new_cores -ne $current_cores ]] || [[ $new_memory -ne $current_memory ]]; then
            echo -e "${GREEN}CT $vmid ($name)${NC}"
            echo "  Current:  $current_cores cores, ${current_memory}MB RAM, ${current_swap}MB swap"
            echo "  Util:     CPU ${cpu_util}%, Memory ${mem_util}%, Disk ${disk_util}%"
            echo "  Recommended: $new_cores cores, ${new_memory}MB RAM, ${new_swap}MB swap"
            echo "  Savings:  \$${savings}/month"
            echo "  Reason:   $reason"
            echo ""
        fi
    done

    echo "Total potential monthly savings: \$${total_savings}"
}

# Calculate container cost
calculate_container_cost() {
    local vmid=$1
    local cores=$2
    local memory_mb=$3

    # Cost constants (from cost-analyze.sh)
    local monthly_hours=730
    local cost_per_vcpu_hour=0.01
    local cost_per_gb_ram_hour=0.005

    local cpu_cost=$(echo "scale=4; $cores * $cost_per_vcpu_hour * $monthly_hours" | bc)
    local memory_cost=$(echo "scale=4; ($memory_mb / 1024) * $cost_per_gb_ram_hour * $monthly_hours" | bc)
    local total=$(echo "scale=2; $cpu_cost + $memory_cost" | bc)

    echo "$total"
}

# Apply rightsizing changes
apply_rightsizing() {
    if [[ "$DRY_RUN" != "false" ]]; then
        log "DRY RUN: No changes will be made"
        log "Set DRY_RUN=false to apply changes"
    fi

    local changed=0

    for vmid in $(pct list | awk 'NR>1 {print $1}'); do
        local name=$(pct config "$vmid" | grep -oP '^hostname:\s*\K.+' || echo "ct${vmid}")
        local config=$(get_container_config "$vmid")
        IFS=':' read -r current_cores current_memory current_swap <<< "$config"

        local utilization=$(get_container_utilization "$vmid")
        IFS=':' read -r status cpu_util mem_util disk_util <<< "$utilization"

        if [[ "$status" != "running" ]]; then
            continue
        fi

        local recommendation=$(recommend_size "$current_cores" "$current_memory" "$current_swap" "$cpu_util" "$mem_util")
        IFS=':' read -r new_cores new_memory new_swap reason <<< "$recommendation"

        if [[ $new_cores -ne $current_cores ]] || [[ $new_memory -ne $current_memory ]]; then
            log "Rightsizing CT $vmid ($name)"

            if [[ "$DRY_RUN" == "false" ]]; then
                # Save state for rollback
                save_state "$vmid" "$current_cores" "$current_memory" "$current_swap"

                # Apply changes
                pct set "$vmid" --cores "$new_cores" --memory "$new_memory" --swap "$new_swap"

                # Restart if needed (memory change requires restart)
                if [[ $new_memory -ne $current_memory ]]; then
                    pct reboot "$vmid" --timeout 60
                fi

                log "Applied: CT $vmid -> $new_cores cores, ${new_memory}MB RAM"
                changed=$((changed + 1))
            else
                log "[DRY RUN] Would resize CT $vmid: $new_cores cores, ${new_memory}MB RAM"
                changed=$((changed + 1))
            fi
        fi
    done

    log "Rightsizing complete: $changed containers changed"
}

# Rollback changes
rollback_changes() {
    if [[ -z "$ROLLBACK_TIMESTAMP" ]]; then
        error "Rollback timestamp required. Usage: $0 <period> rollback <timestamp>"
    fi

    if [[ ! -f "$STATE_FILE" ]]; then
        error "No state file found. Cannot rollback."
    fi

    log "Rolling back changes from timestamp: $ROLLBACK_TIMESTAMP"

    local timestamp=$(date -d "$ROLLBACK_TIMESTAMP" +%s 2>/dev/null || echo "$ROLLBACK_TIMESTAMP")

    # Read state file and restore
    local entries=$(jq -r ".[] | select(.timestamp == $timestamp) | @json" "$STATE_FILE")

    if [[ -z "$entries" ]]; then
        error "No entries found for timestamp: $ROLLBACK_TIMESTAMP"
    fi

    echo "$entries" | while read -r entry; do
        local vmid=$(echo "$entry" | jq -r '.vmid')
        local cores=$(echo "$entry" | jq -r '.cores')
        local memory=$(echo "$entry" | jq -r '.memory')
        local swap=$(echo "$entry" | jq -r '.swap')

        log "Restoring CT $vmid: $cores cores, ${memory}MB RAM, ${swap}MB swap"
        pct set "$vmid" --cores "$cores" --memory "$memory" --swap "$swap"
        pct reboot "$vmid" --timeout 60
    done

    log "Rollback complete"
}

# Show usage
show_usage() {
    cat <<EOF
Usage: $0 [period] [action] [options]

Arguments:
  period      Analysis period (default: 7d)
              Examples: 1d, 1w, 1m

  action      Action to perform:
              analyze   - Show recommendations (default)
              apply     - Apply rightsizing changes
              rollback  - Rollback to previous state

Options:
  DRY_RUN=false    Apply changes (default: true)
  ROLLBACK_TIMESTAMP=<ts>  Timestamp for rollback

Examples:
  $0 7d analyze              # Analyze and recommend
  $0 7d apply                # Apply changes (dry run)
  DRY_RUN=false $0 7d apply  # Apply changes for real
  $0 7d rollback 1699200000  # Rollback to timestamp

Environment Variables:
  CPU_LOW_THRESHOLD=30       % utilization to downsize CPU
  MEMORY_LOW_THRESHOLD=30    % utilization to downsize memory
  CPU_HIGH_THRESHOLD=80      % utilization to upsize CPU
  MEMORY_HIGH_THRESHOLD=80   % utilization to upsize memory
EOF
}

# Main execution
main() {
    case "$ACTION" in
        analyze)
            analyze_containers
            ;;
        apply)
            apply_rightsizing
            ;;
        rollback)
            rollback_changes
            ;;
        help|--help|-h)
            show_usage
            ;;
        *)
            error "Unknown action: $ACTION. Use analyze, apply, or rollback."
            ;;
    esac
}

# Run main
main "$@"
