#!/bin/bash
# Proxmox Cluster Status Script
# Check cluster health, quorum status, and resource availability
# Usage: ./px-cluster-status.sh [--verbose] [--json] [--monitor]

set -euo pipefail

# Configuration
PROXMOX_API_HOST="${PROXMOX_API_HOST:-root@pam}"
QUORUM_TIMEOUT="${QUORUM_TIMEOUT:-5}"
MONITOR_INTERVAL="${MONITOR_INTERVAL:-30}"

# Thresholds
CPU_WARN="${CPU_WARN:-70}"
CPU_CRIT="${CPU_CRIT:-90}"
MEM_WARN="${MEM_WARN:-80}"
MEM_CRIT="${MEM_CRIT:-95}"
DISK_WARN="${DISK_WARN:-80}"
DISK_CRIT="${DISK_CRIT:-95}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
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
    if [[ "$VERBOSE" == "true" ]]; then
        echo -e "${CYAN}[DEBUG]${NC} $1"
    fi
}

print_header() {
    echo ""
    echo -e "${BOLD}=== $1 ===${NC}"
}

# Check if this is a cluster node
check_cluster_mode() {
    if pvecm status &>/dev/null; then
        return 0
    else
        return 1
    fi
}

# Get cluster status
get_cluster_status() {
    local output=""
    local json_output=""

    if check_cluster_mode; then
        output=$(pvecm status 2>/dev/null || echo "Cluster status unavailable")

        # Parse cluster info
        local cluster_name
        local quorum
        local nodes
        local votes

        cluster_name=$(echo "$output" | grep "Cluster Information" -A 5 | grep "Name:" | awk '{print $2}')
        quorum=$(echo "$output" | grep "Quorum:" | awk '{print $2}')
        nodes=$(echo "$output" | grep "Nodes:" | awk '{print $2}')
        votes=$(echo "$output" | grep "node votes:" | awk '{print $3}')

        json_output=$(cat << EOF
{
  "cluster_name": "$cluster_name",
  "quorum": "$quorum",
  "nodes": "$nodes",
  "votes": "$votes"
}
EOF
        )
    else
        output="Standalone node (not in cluster)"
        json_output='{"cluster_name": "standalone", "quorum": "N/A", "nodes": "1", "votes": "1"}'
    fi

    if [[ "$JSON_OUTPUT" == "true" ]]; then
        echo "$json_output"
    else
        echo "$output"
    fi
}

# Get node status
get_node_status() {
    local node_name="$1"
    local json_output=""

    local status
    local cpu
    local memory_used
    local memory_total
    local uptime

    status=$(pvesh get /nodes/"$node_name"/status --output-format json 2>/dev/null || echo '{"error": "unavailable"}')

    if [[ "$status" =~ "error" ]]; then
        if [[ "$JSON_OUTPUT" == "true" ]]; then
            echo '{"node": "'"$node_name"'", "status": "offline"}'
        else
            echo "$node_name: OFFLINE"
        fi
        return 1
    fi

    local node_status
    local cpu_usage
    local mem_usage
    local disk_usage
    local uptime_str

    node_status=$(echo "$status" | jq -r '.status // "unknown"')
    cpu_usage=$(echo "$status" | jq -r '.cpu // 0')
    mem_usage=$(echo "$status" | jq -r '.memory // {} | (.used / .total * 100) // 0')
    disk_usage=$(echo "$status" | jq -r '.rootfs // {} | (.used / .total * 100) // 0')
    uptime_str=$(echo "$status" | jq -r '.uptime // 0 | tonumber | if . > 86400 then (. / 86400 | floor | tostring + " days") elif . > 3600 then (. / 3600 | floor | tostring + " hours") else (. / 60 | floor | tostring + " minutes") end')

    if [[ "$JSON_OUTPUT" == "true" ]]; then
        json_output=$(cat << EOF
{
  "node": "$node_name",
  "status": "$node_status",
  "cpu_usage": $cpu_usage,
  "memory_usage": $mem_usage,
  "disk_usage": $disk_usage,
  "uptime": "$uptime_str"
}
EOF
        )
        echo "$json_output"
    else
        # Color code based on thresholds
        local cpu_color="$NC"
        local mem_color="$NC"
        local disk_color="$NC"

        if (( $(echo "$cpu_usage >= $CPU_CRIT" | bc -l) )); then
            cpu_color="$RED"
        elif (( $(echo "$cpu_usage >= $CPU_WARN" | bc -l) )); then
            cpu_color="$YELLOW"
        fi

        if (( $(echo "$mem_usage >= $MEM_CRIT" | bc -l) )); then
            mem_color="$RED"
        elif (( $(echo "$mem_usage >= $MEM_WARN" | bc -l) )); then
            mem_color="$YELLOW"
        fi

        if (( $(echo "$disk_usage >= $DISK_CRIT" | bc -l) )); then
            disk_color="$RED"
        elif (( $(echo "$disk_usage >= $DISK_WARN" | bc -l) )); then
            disk_color="$YELLOW"
        fi

        printf "%-12s %-8s CPU: ${cpu_color}%.1f%%${NC} MEM: ${mem_color}%.1f%%${NC} DISK: ${disk_color}%.1f%%${NC} UP: %s\n" \
            "$node_name" "$node_status" "$cpu_usage" "$mem_usage" "$disk_usage" "$uptime_str"
    fi
}

# Get storage status
get_storage_status() {
    local node_name="$1"
    local json_output=""

    local storage
    storage=$(pvesh get /nodes/"$node_name"/storage --output-format json 2>/dev/null || echo '[]')

    if [[ "$JSON_OUTPUT" == "true" ]]; then
        echo "$storage" | jq -r '.[] | {storage: .storage, type: .type, content: .content, used: (.used // 0), total: (.total // 1), usage_percent: (.used / .total * 100 // 0)}'
    else
        echo "$storage" | jq -r '.[] | "\(.storage) (\(.type)): \(.content) | \(.used / .total * 100 | floor)% used | \((.total - .used) / 1024 / 1024 / 1024 | floor)GB free"'
    fi
}

# Get VM/Container count
get_vm_count() {
    local node_name="${1:-}"

    local filter=""
    if [[ -n "$node_name" ]]; then
        filter="?node=$node_name"
    fi

    local resources
    resources=$(pvesh get /cluster/resources --type vm --output-format json 2>/dev/null || echo '[]')

    if [[ "$JSON_OUTPUT" == "true" ]]; then
        echo "$resources" | jq "[.[] | select(.node == \"$node_name\" or \"$node_name\" == \"\")] | length"
    else
        local total
        local running
        local stopped

        total=$(echo "$resources" | jq 'length')
        running=$(echo "$resources" | jq '[.[] | select(.status == "running")] | length')
        stopped=$(echo "$resources" | jq '[.[] | select(.status == "stopped")] | length')

        echo "Total: $total | Running: $running | Stopped: $stopped"
    fi
}

# Monitor mode
monitor_mode() {
    log_info "Starting monitor mode (interval: ${MONITOR_INTERVAL}s)"
    log_info "Press Ctrl+C to exit"

    while true; do
        clear
        display_status

        local next_run
        next_run=$(date -d "+$MONITOR_INTERVAL seconds" +%H:%M:%S)

        echo ""
        log_info "Next update at: $next_run"
        sleep "$MONITOR_INTERVAL"
    done
}

# Display full status
display_status() {
    print_header "Proxmox Cluster Status"

    echo ""
    print_header "Cluster Information"
    get_cluster_status

    echo ""
    print_header "Node Status"
    if [[ "$JSON_OUTPUT" == "true" ]]; then
        echo "["
        local first=true
        for node in $(pvesh get /nodes --output-format json | jq -r '.[].node'); do
            if [[ "$first" != "true" ]]; then
                echo ","
            fi
            get_node_status "$node" | jq -r '.'
            first=false
        done
        echo "]"
    else
        printf "%-12s %-8s %-12s %-12s %-12s %s\n" "Node" "Status" "CPU" "Memory" "Disk" "Uptime"
        printf "%-12s %-8s %-12s %-12s %-12s %s\n" "----" "------" "---" "------" "----" "------"

        for node in $(pvesh get /nodes --output-format json | jq -r '.[].node'); do
            get_node_status "$node"
        done
    fi

    echo ""
    print_header "Storage Status"
    for node in $(pvesh get /nodes --output-format json | jq -r '.[].node'); do
        if [[ "$JSON_OUTPUT" != "true" ]]; then
            echo "Storage on $node:"
        fi
        get_storage_status "$node"
    done

    echo ""
    print_header "VM/Container Summary"
    if [[ "$JSON_OUTPUT" != "true" ]]; then
        echo "Cluster-wide:"
        get_vm_count
    fi

    echo ""
    print_header "Network Status"
    if [[ "$JSON_OUTPUT" != "true" ]]; then
        ip -br addr show | grep -E "^(vmbr|bond|enp|ens|eth)"
        echo ""
        echo "WireGuard status:"
        wg show 2>/dev/null || echo "WireGuard not configured"
    fi

    echo ""
    print_header "Recent Tasks"
    if [[ "$JSON_OUTPUT" != "true" ]]; then
        pvesh get /cluster/tasks --output-format json | \
            jq -r '.[0:5] | .[] | "\(.starttime) [\(.status)] \(.type) on \(.node) (VMID: \(.vmid // "N/A"))"' 2>/dev/null || echo "No recent tasks"
    fi
}

print_usage() {
    cat << EOF
Usage: $0 [options]

Options:
  --verbose, -v     Enable verbose output
  --json, -j        Output in JSON format
  --monitor, -m     Enable continuous monitoring mode
  --help, -h        Show this help message

Environment Variables:
  CPU_WARN          CPU warning threshold (default: 70%)
  CPU_CRIT          CPU critical threshold (default: 90%)
  MEM_WARN          Memory warning threshold (default: 80%)
  MEM_CRIT          Memory critical threshold (default: 95%)
  DISK_WARN         Disk warning threshold (default: 80%)
  DISK_CRIT         Disk critical threshold (default: 95%)
  MONITOR_INTERVAL  Monitoring refresh interval in seconds (default: 30)

Examples:
  # Show cluster status
  $0

  # Show verbose status
  $0 --verbose

  # Output as JSON
  $0 --json

  # Monitor mode (continuous updates)
  $0 --monitor

  # Custom thresholds
  CPU_WARN=60 CPU_CRIT=80 $0 --verbose
EOF
}

main() {
    local VERBOSE="false"
    local JSON_OUTPUT="false"
    local MONITOR_MODE="false"

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --verbose|-v)
                VERBOSE="true"
                shift
                ;;
            --json|-j)
                JSON_OUTPUT="true"
                shift
                ;;
            --monitor|-m)
                MONITOR_MODE="true"
                shift
                ;;
            --help|-h)
                print_usage
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                print_usage
                exit 1
                ;;
        esac
    done

    if [[ "$MONITOR_MODE" == "true" ]]; then
        monitor_mode
    else
        display_status
    fi
}

main "$@"
