#!/bin/bash
################################################################################
# Proxmox Diagnostics
#
# Description: Check Proxmox cluster health
# Output: JSON report with findings and recommendations
# Usage: ./diag-proxmox.sh [--node nodename]
################################################################################

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NODE_NAME="${1:-$(hostname)}"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# JSON output structure
json_output='{
  "scan_info": {
    "timestamp": "'"$TIMESTAMP"'",
    "scan_version": "1.0.0",
    "node": "'"$NODE_NAME"'"
  },
  "checks": {}
}'

# Helper functions
add_finding() {
    local category="$1"
    local check="$2"
    local status="$3"
    local message="$4"
    local recommendation="${5:-}"

    json_output=$(echo "$json_output" | jq --arg cat "$category" --arg chk "$check" --arg st "$status" --arg msg "$message" --arg rec "$recommendation" '
        .checks[$cat] |= . + {
            $chk: {
                "status": $st,
                "message": $msg,
                "recommendation": $rec
            }
        }
    ')
}

# Check if Proxmox CLI is available
if ! command -v pvesh &> /dev/null; then
    echo "ERROR: Proxmox CLI (pvesh) not found. This script must be run on a Proxmox node." >&2
    exit 1
fi

################################################################################
# Cluster Status Check
################################################################################
check_cluster_status() {
    echo "Checking cluster status..."

    local cluster_output
    cluster_output=$(pvesh get /cluster/status 2>/dev/null || echo "")

    if [ -z "$cluster_output" ]; then
        add_finding "cluster" "status" "critical" "Cannot connect to Proxmox cluster" "Check Proxmox API connectivity"
        return
    fi

    # Count online nodes
    local online_nodes=$(echo "$cluster_output" | jq '[.[] | select(.type == "node" and .status == "online")] | length')
    local total_nodes=$(echo "$cluster_output" | jq '[.[] | select(.type == "node")] | length')

    echo "  Nodes: $online_nodes/$total_nodes online"

    if [ "$online_nodes" -eq "$total_nodes" ]; then
        add_finding "cluster" "nodes" "pass" "All nodes online ($online_nodes/$total_nodes)" ""
    else
        add_finding "cluster" "nodes" "warning" "$((total_nodes - online_nodes)) node(s) offline" "Check offline nodes"
    fi

    # Check quorum
    local quorum=$(echo "$cluster_output" | jq -r '.[] | select(.type == "cluster") | .quorate // "1"')
    if [ "$quorum" = "1" ]; then
        echo "  Cluster has quorum"
        add_finding "cluster" "quorum" "pass" "Cluster has quorum" ""
    else
        echo "  CRITICAL: Cluster does NOT have quorum"
        add_finding "cluster" "quorum" "critical" "Cluster does NOT have quorum" "Check cluster connectivity or use: pvecm expected 1"
    fi
}

################################################################################
# Node Status Check
################################################################################
check_node_status() {
    echo "Checking node: $NODE_NAME"

    local node_output
    node_output=$(pvesh get /nodes/"$NODE_NAME"/status/current 2>/dev/null || echo "")

    if [ -z "$node_output" ]; then
        add_finding "node" "status" "critical" "Cannot get node status for $NODE_NAME" "Verify node name and connectivity"
        return
    fi

    # Extract metrics
    local cpu=$(echo "$node_output" | jq -r '.cpu // 0')
    local memory_total=$(echo "$node_output" | jq -r '.memory.total // 0')
    local memory_used=$(echo "$node_output" | jq -r '.memory.used // 0')
    local memory_percent=$(awk "BEGIN {printf \"%.0f\", ($memory_used / $memory_total) * 100}")
    local load=$(echo "$node_output" | jq -r '.loadavg // "[0,0,0]"')

    echo "  CPU: $(awk "BEGIN {printf \"%.1f\", $cpu * 100}")%"
    echo "  Memory: $memory_percent% ($((memory_used / 1024 / 1024))MB / $((memory_total / 1024 / 1024))MB)"
    echo "  Load: $load"

    # Check CPU
    local cpu_percent=$(awk "BEGIN {printf \"%.0f\", $cpu * 100}")
    if [ "$cpu_percent" -gt 85 ]; then
        add_finding "node" "cpu" "critical" "CPU usage: ${cpu_percent}%" "Identify and migrate high-usage VMs"
    elif [ "$cpu_percent" -gt 70 ]; then
        add_finding "node" "cpu" "warning" "CPU usage: ${cpu_percent}%" "Monitor CPU usage"
    else
        add_finding "node" "cpu" "pass" "CPU usage: ${cpu_percent}%" ""
    fi

    # Check memory
    if [ "$memory_percent" -gt 90 ]; then
        add_finding "node" "memory" "critical" "Memory usage: ${memory_percent}%" "Migrate VMs or add memory"
    elif [ "$memory_percent" -gt 80 ]; then
        add_finding "node" "memory" "warning" "Memory usage: ${memory_percent}%" "Monitor memory usage"
    else
        add_finding "node" "memory" "pass" "Memory usage: ${memory_percent}%" ""
    fi
}

################################################################################
# VM Status Check
################################################################################
check_vm_status() {
    echo "Checking VMs..."

    local vms_output
    vms_output=$(pvesh get /nodes/"$NODE_NAME"/qemu --output-format json 2>/dev/null || echo "[]")

    local total_vms=$(echo "$vms_output" | jq 'length')
    local running_vms=$(echo "$vms_output" | jq '[.[] | select(.status == "running")] | length')
    local stopped_vms=$(echo "$vms_output" | jq '[.[] | select(.status == "stopped")] | length')

    echo "  VMs: $running_vms running, $stopped_vms stopped, $total_vms total"

    if [ "$running_vms" -eq "$total_vms" ]; then
        add_finding "vms" "status" "pass" "All VMs running ($running_vms/$total_vms)" ""
    else
        add_finding "vms" "status" "warning" "$stopped_vms VM(s) stopped" "Check stopped VMs"
    fi

    # Check for VMs with high resource usage
    echo "$vms_output" | jq -r '.[] | select(.status == "running") | "\(.vmid) \(.name) \(.cpu)"' | while read -r vmid name cpu; do
        local cpu_percent=$(awk "BEGIN {printf \"%.0f\", $cpu * 100}")
        if [ "$cpu_percent" -gt 80 ]; then
            echo "  WARNING: VM $vmid ($name) - CPU: ${cpu_percent}%"
        fi
    done
}

################################################################################
# Container Status Check
################################################################################
check_container_status() {
    echo "Checking containers..."

    local lxc_output
    lxc_output=$(pvesh get /nodes/"$NODE_NAME"/lxc --output-format json 2>/dev/null || echo "[]")

    local total_containers=$(echo "$lxc_output" | jq 'length')
    local running_containers=$(echo "$lxc_output" | jq '[.[] | select(.status == "running")] | length')
    local stopped_containers=$(echo "$lxc_output" | jq '[.[] | select(.status == "stopped")] | length')

    echo "  Containers: $running_containers running, $stopped_containers stopped, $total_containers total"

    if [ "$running_containers" -eq "$total_containers" ]; then
        add_finding "containers" "status" "pass" "All containers running ($running_containers/$total_containers)" ""
    else
        add_finding "containers" "status" "warning" "$stopped_containers container(s) stopped" "Check stopped containers"
    fi
}

################################################################################
# Storage Status Check
################################################################################
check_storage_status() {
    echo "Checking storage..."

    local storage_output
    storage_output=$(pvesm status --output-format json 2>/dev/null || echo "[]")

    local storage_issues=0

    echo "$storage_output" | jq -r '.[]' | while read -r storage; do
        local storage_name=$(echo "$storage" | jq -r '.storage // "unknown"')
        local storage_type=$(echo "$storage" | jq -r '.type // "unknown"')
        local storage_content=$(echo "$storage" | jq -r '.content // ""')
        local storage_status=$(echo "$storage" | jq -r '.status // "unknown"')
        local storage_used=$(echo "$storage" | jq -r '.used // 0')
        local storage_total=$(echo "$storage" | jq -r '.total // 1')
        local storage_percent=$(awk "BEGIN {printf \"%.0f\", ($storage_used / $storage_total) * 100}")

        if [ "$storage_status" != "available" ]; then
            echo "  ERROR: Storage $storage_name status: $storage_status"
            add_finding "storage" "$storage_name" "critical" "Storage status: $storage_status" "Check storage health"
        else
            echo "  Storage $storage_name ($storage_type): ${storage_percent}% used"
            if [ "$storage_percent" -gt 90 ]; then
                add_finding "storage" "$storage_name" "critical" "Storage $storage_name: ${storage_percent}% full" "Clean old backups or expand storage"
            elif [ "$storage_percent" -gt 80 ]; then
                add_finding "storage" "$storage_name" "warning" "Storage $storage_name: ${storage_percent}% full" "Monitor storage usage"
            else
                add_finding "storage" "$storage_name" "pass" "Storage $storage_name: ${storage_percent}% used" ""
            fi
        fi
    done
}

################################################################################
# Network Status Check
################################################################################
check_network_status() {
    echo "Checking network..."

    local node_info
    node_info=$(pvesh get /nodes/"$NODE_NAME"/status/network 2>/dev/null || echo "[]")

    # Check for network interfaces
    local iface_count=$(echo "$node_info" | jq 'length')
    echo "  Network interfaces: $iface_count"

    # Check for active interfaces
    local active_ifaces=$(echo "$node_info" | jq '[.[] | select(.active == true)] | length')
    echo "  Active interfaces: $active_ifaces"

    if [ "$active_ifaces" -eq 0 ]; then
        add_finding "network" "interfaces" "critical" "No active network interfaces" "Check network configuration"
    else
        add_finding "network" "interfaces" "pass" "$active_ifaces active interface(s)" ""
    fi
}

################################################################################
# Subscription Check
################################################################################
check_subscription() {
    echo "Checking subscription..."

    local subscription
    subscription=$(pvesh get /nodes/"$NODE_NAME"/subscription 2>/dev/null || echo "")

    if [ -n "$subscription" ]; then
        local product_name=$(echo "$subscription" | jq -r '.productname // "unknown"')
        local status=$(echo "$subscription" | jq -r '.status // "unknown"')
        local due_date=$(echo "$subscription" | jq -r '.duedate // "N/A"')

        echo "  Subscription: $product_name"
        echo "  Status: $status"
        echo "  Due date: $due_date"

        if [ "$status" = "Active" ]; then
            add_finding "subscription" "status" "pass" "Subscription active (expires: $due_date)" ""
        else
            add_finding "subscription" "status" "warning" "Subscription status: $status" "Check subscription"
        fi
    else
        add_finding "subscription" "status" "skip" "No subscription info available" ""
    fi
}

################################################################################
# Main Execution
################################################################################
main() {
    echo "=== Proxmox Diagnostic Scan ==="
    echo "Node: $NODE_NAME"
    echo "Timestamp: $TIMESTAMP"
    echo ""

    # Run all checks
    check_cluster_status
    check_node_status
    check_vm_status
    check_container_status
    check_storage_status
    check_network_status
    check_subscription

    # Output JSON report
    echo ""
    echo "=== JSON Report ==="
    echo "$json_output" | jq '.'

    # Check for critical issues
    local critical=$(echo "$json_output" | jq '[.checks[][] | select(.status == "critical")] | length')
    if [ "$critical" -gt 0 ]; then
        exit 1
    fi

    exit 0
}

main "$@"
