#!/bin/bash
# cost-analyze.sh - Analyze infrastructure costs by resource type
# Part of the cost-optimization-resource-efficiency skill

set -euo pipefail

# Configuration
PROXMOX_HOST="${PROXMOX_HOST:-192.168.0.245}"
PROXMOX_PORT="${PROXMOX_PORT:-8006}"
PROXMOX_USER="${PROXMOX_USER:-root@pam}"
ANALYSIS_PERIOD="${1:-7d}"
OUTPUT_FORMAT="${2:-text}"
OUTPUT_FILE="${3:-}"

# Cost constants (USD per unit)
COST_PER_VCPU_HOUR="${COST_PER_VCPU_HOUR:-0.01}"
COST_PER_GB_RAM_HOUR="${COST_PER_GB_RAM_HOUR:-0.005}"
COST_PER_GB_STORAGE_HOUR="${COST_PER_GB_STORAGE_HOUR:-0.0001}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
    exit 1
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1" >&2
}

# Convert period to seconds
period_to_seconds() {
    local period=$1
    local value=${period%[a-z]*}
    local unit=${period#$value}

    case $unit in
        d) echo $((value * 86400)) ;;
        w) echo $((value * 604800)) ;;
        m) echo $((value * 2592000)) ;;
        *) echo 604800 ;; # Default: 1 week
    esac
}

# Get all containers
get_containers() {
    pvesh get /cluster/resources --type lxc --output-format json 2>/dev/null || \
        pct list | awk 'NR>1 {print $1}'
}

# Get all VMs
get_vms() {
    pvesh get /cluster/resources --type vm --output-format json 2>/dev/null || \
        qm list | awk 'NR>1 {print $1}'
}

# Get container status
get_container_status() {
    local vmid=$1
    pct status "$vmid" 2>/dev/null || echo "unknown"
}

# Calculate container cost
calculate_container_cost() {
    local vmid=$1
    local hours=$2

    # Get container config
    local config="/etc/pve/lxc/${vmid}.conf"
    if [[ ! -f "$config" ]]; then
        echo "0.00"
        return
    fi

    # Parse resources
    local cores=$(grep -oP '^cores:\s*\K\d+' "$config" || echo "2")
    local memory_mb=$(grep -oP '^memory:\s*\K\d+' "$config" || echo "4096")
    local rootfs=$(grep -oP '^rootfs:\s*\K[\d.]+' "$config" || echo "32")

    # Calculate hourly cost
    local cpu_cost=$(echo "scale=4; $cores * $COST_PER_VCPU_HOUR" | bc)
    local memory_cost=$(echo "scale=4; ($memory_mb / 1024) * $COST_PER_GB_RAM_HOUR" | bc)
    local storage_cost=$(echo "scale=4; $rootfs * $COST_PER_GB_STORAGE_HOUR" | bc)
    local hourly_cost=$(echo "scale=4; $cpu_cost + $memory_cost + $storage_cost" | bc)

    # Calculate period cost
    local period_cost=$(echo "scale=2; $hourly_cost * $hours" | bc)
    echo "$period_cost"
}

# Analyze container costs
analyze_containers() {
    local period_seconds=$(period_to_seconds "$ANALYSIS_PERIOD")
    local hours=$((period_seconds / 3600))

    log "Analyzing container costs over $ANALYSIS_PERIOD ($hours hours)"

    echo ""
    echo "=== Container Cost Analysis ==="
    echo ""

    local total_cost=0
    local total_running=0
    local total_stopped=0

    for vmid in $(get_containers); do
        local status=$(get_container_status "$vmid")
        local name=$(pct config "$vmid" | grep -oP '^hostname:\s*\K.+' || echo "ct${vmid}")
        local cost=$(calculate_container_cost "$vmid" "$hours")

        # Adjust cost for runtime
        if [[ "$status" == "running" ]]; then
            local total_running=$((total_running + 1))
        else
            # Stopped containers use less (storage only)
            cost=$(echo "scale=2; $cost * 0.1" | bc)
            local total_stopped=$((total_stopped + 1))
        fi

        total_cost=$(echo "scale=2; $total_cost + $cost" | bc)

        # Format output
        if [[ "$OUTPUT_FORMAT" == "json" ]]; then
            echo "{\"vmid\":$vmid,\"name\":\"$name\",\"status\":\"$status\",\"cost\":$cost}"
        else
            printf "CT %3d (%-20s) %8s: \$%7.2f/month\n" "$vmid" "$name" "$status" "$cost"
        fi
    done

    echo ""
    echo "Summary:"
    echo "  Running containers: $total_running"
    echo "  Stopped containers: $total_stopped"
    echo "  Total monthly cost: \$$(echo "scale=2; $total_cost" | bc)"
}

# Analyze VM costs
analyze_vms() {
    local period_seconds=$(period_to_seconds "$ANALYSIS_PERIOD")
    local hours=$((period_seconds / 3600))

    log "Analyzing VM costs over $ANALYSIS_PERIOD"

    echo ""
    echo "=== VM Cost Analysis ==="
    echo ""

    local total_cost=0

    for vmid in $(get_vms); do
        local status=$(qm status "$vmid" 2>/dev/null | awk '{print $2}' || echo "unknown")
        local name=$(qm config "$vmid" | grep -oP '^name:\s*\K.+' || echo "vm${vmid}")

        # Parse VM config
        local config="/etc/pve/qemu-server/${vmid}.conf"
        if [[ ! -f "$config" ]]; then
            continue
        fi

        local cores=$(grep -oP '^cores:\s*\K\d+' "$config" || echo "2")
        local memory_mb=$(grep -oP '^memory:\s*\K\d+' "$config" || echo "4096")

        # Calculate disk usage (sum of all disks)
        local disk_gb=0
        while read -r disk; do
            disk_gb=$(echo "$disk_gb + $disk" | bc)
        done < <(grep -oP '^[^0]+:\s*\K[\d.]+' "$config" | head -5)

        # Calculate cost
        local cpu_cost=$(echo "scale=4; $cores * $COST_PER_VCPU_HOUR" | bc)
        local memory_cost=$(echo "scale=4; ($memory_mb / 1024) * $COST_PER_GB_RAM_HOUR" | bc)
        local storage_cost=$(echo "scale=4; $disk_gb * $COST_PER_GB_STORAGE_HOUR" | bc)
        local hourly_cost=$(echo "scale=4; $cpu_cost + $memory_cost + $storage_cost" | bc)
        local cost=$(echo "scale=2; $hourly_cost * $hours" | bc)

        if [[ "$status" == "running" ]]; then
            total_cost=$(echo "scale=2; $total_cost + $cost" | bc)
        else
            cost=$(echo "scale=2; $cost * 0.1" | bc)
        fi

        if [[ "$OUTPUT_FORMAT" == "json" ]]; then
            echo "{\"vmid\":$vmid,\"name\":\"$name\",\"status\":\"$status\",\"cost\":$cost}"
        else
            printf "VM %3d (%-20s) %8s: \$%7.2f/month\n" "$vmid" "$name" "$status" "$cost"
        fi
    done

    echo ""
    echo "Total VM monthly cost: \$$(echo "scale=2; $total_cost" | bc)"
}

# Analyze by resource type
analyze_by_resource_type() {
    log "Analyzing costs by resource type"

    echo ""
    echo "=== Cost by Resource Type ==="
    echo ""

    local total_cpu=0
    local total_memory=0
    local total_storage=0

    # Containers
    for vmid in $(get_containers); do
        local config="/etc/pve/lxc/${vmid}.conf"
        [[ ! -f "$config" ]] && continue

        local cores=$(grep -oP '^cores:\s*\K\d+' "$config" || echo "2")
        local memory_mb=$(grep -oP '^memory:\s*\K\d+' "$config" || echo "4096")
        local storage_gb=$(grep -oP '^rootfs:\s*\K[\d.]+' "$config" || echo "32")

        total_cpu=$((total_cpu + cores))
        total_memory=$((total_memory + memory_mb))
        total_storage=$(echo "scale=2; $total_storage + $storage_gb" | bc)
    done

    # VMs
    for vmid in $(get_vms); do
        local config="/etc/pve/qemu-server/${vmid}.conf"
        [[ ! -f "$config" ]] && continue

        local cores=$(grep -oP '^cores:\s*\K\d+' "$config" || echo "2")
        local memory_mb=$(grep -oP '^memory:\s*\K\d+' "$config" || echo "4096")

        total_cpu=$((total_cpu + cores))
        total_memory=$((total_memory + memory_mb))

        while read -r disk; do
            total_storage=$(echo "scale=2; $total_storage + $disk" | bc)
        done < <(grep -oP '^[^0]+:\s*\K[\d.]+' "$config" | head -5)
    done

    # Calculate costs (monthly = 730 hours)
    local monthly_hours=730
    local cpu_cost=$(echo "scale=2; $total_cpu * $COST_PER_VCPU_HOUR * $monthly_hours" | bc)
    local memory_cost=$(echo "scale=2; ($total_memory / 1024) * $COST_PER_GB_RAM_HOUR * $monthly_hours" | bc)
    local storage_cost=$(echo "scale=2; $total_storage * $COST_PER_GB_STORAGE_HOUR * $monthly_hours" | bc)
    local grand_total=$(echo "scale=2; $cpu_cost + $memory_cost + $storage_cost" | bc)

    if [[ "$OUTPUT_FORMAT" == "json" ]]; then
        cat <<EOF
{
  "cpu": {
    "units": $total_cpu,
    "monthly_cost": $cpu_cost
  },
  "memory": {
    "gb": $(echo "scale=2; $total_memory / 1024" | bc),
    "monthly_cost": $memory_cost
  },
  "storage": {
    "gb": $(echo "scale=0; $total_storage" | bc),
    "monthly_cost": $storage_cost
  },
  "total_monthly_cost": $grand_total
}
EOF
    else
        echo "Resource Allocation:"
        echo "  CPU cores:         $total_cpu"
        echo "  Memory:           $(echo "scale=2; $total_memory / 1024" | bc) GB"
        echo "  Storage:          $(echo "scale=0; $total_storage" | bc) GB"
        echo ""
        echo "Monthly Cost Breakdown:"
        echo "  CPU:              \$$(echo "scale=2; $cpu_cost" | bc)"
        echo "  Memory:           \$$(echo "scale=2; $memory_cost" | bc)"
        echo "  Storage:          \$$(echo "scale=2; $storage_cost" | bc)"
        echo "  ────────────────"
        echo "  Total:            \$$(echo "scale=2; $grand_total" | bc)"
    fi
}

# Detect anomalies
detect_anomalies() {
    log "Detecting cost anomalies"

    echo ""
    echo "=== Anomaly Detection ==="
    echo ""

    # Check for over-provisioned containers
    echo "Over-provisioned containers (potential rightsizing):"
    for vmid in $(get_containers); do
        local status=$(get_container_status "$vmid")
        [[ "$status" != "running" ]] && continue

        # Get actual memory usage
        local memory_mb=$(pct exec "$vmid" -- free -m 2>/dev/null | awk '/^Mem:/ {print $2}' || echo "0")
        local memory_limit=$(pct config "$vmid" | grep -oP '^memory:\s*\K\d+' || echo "4096")
        local utilization=$(echo "scale=0; ($memory_mb * 100) / $memory_limit" | bc)

        if [[ $utilization -lt 30 ]]; then
            local name=$(pct config "$vmid" | grep -oP '^hostname:\s*\K.+' || echo "ct${vmid}")
            echo "  CT $vmid ($name): ${utilization}% memory usage (limit: ${memory_limit}MB)"
        fi
    done

    echo ""
    echo "Stopped containers (consider for cleanup):"
    for vmid in $(get_containers); do
        local status=$(get_container_status "$vmid")
        if [[ "$status" == "stopped" ]]; then
            local name=$(pct config "$vmid" | grep -oP '^hostname:\s*\K.+' || echo "ct${vmid}")
            echo "  CT $vmid ($name): $status"
        fi
    done
}

# Main execution
main() {
    log "Starting cost analysis for period: $ANALYSIS_PERIOD"

    case "$OUTPUT_FORMAT" in
        json)
            echo "{"
            echo "  \"period\": \"$ANALYSIS_PERIOD\","
            echo "  \"containers\": ["
            analyze_containers | sed '1d;$d' | sed 's/$/,/' | sed '$ s/,$//'
            echo "  ],"
            echo "  \"vms\": ["
            analyze_vms | sed '1d;$d' | sed 's/$/,/' | sed '$ s/,$//'
            echo "  ],"
            echo "  \"by_resource_type\":"
            analyze_by_resource_type | sed '1d;$d'
            echo "}"
            ;;
        *)
            analyze_containers
            echo ""
            analyze_vms
            echo ""
            analyze_by_resource_type
            echo ""
            detect_anomalies
            ;;
    esac

    # Save to file if specified
    if [[ -n "$OUTPUT_FILE" ]]; then
        log "Saving report to $OUTPUT_FILE"
        main > "$OUTPUT_FILE"
    fi

    log "Cost analysis complete"
}

# Run main function
main "$@"
