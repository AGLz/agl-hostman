#!/bin/bash
# System Baseline Performance Test
# Tests: CPU, Memory, Disk I/O, System Load
# Author: Tester Agent (Hive Mind)
# Date: 2025-11-02

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESULTS_DIR="${RESULTS_DIR:-/tmp/performance-results}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
RESULT_FILE="${RESULTS_DIR}/system-baseline_${TIMESTAMP}.json"
DURATION="${DURATION:-60}"
VERBOSE="${VERBOSE:-0}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Create results directory
mkdir -p "$RESULTS_DIR"

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*"
}

# Check dependencies
check_dependencies() {
    local deps=("bc" "awk" "grep" "uptime" "free" "df" "vmstat")
    local missing=()

    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing+=("$dep")
        fi
    done

    if [ ${#missing[@]} -gt 0 ]; then
        log_error "Missing dependencies: ${missing[*]}"
        log_info "Install with: apt-get install -y ${missing[*]}"
        return 1
    fi

    log_success "All dependencies available"
    return 0
}

# Get system information
get_system_info() {
    local hostname=$(hostname)
    local kernel=$(uname -r)
    local arch=$(uname -m)
    local cpu_model=$(grep "model name" /proc/cpuinfo | head -1 | cut -d: -f2 | xargs)
    local cpu_cores=$(nproc)
    local total_mem=$(free -h | awk '/^Mem:/ {print $2}')

    cat <<EOF
{
  "hostname": "$hostname",
  "kernel": "$kernel",
  "architecture": "$arch",
  "cpu_model": "$cpu_model",
  "cpu_cores": $cpu_cores,
  "total_memory": "$total_mem",
  "timestamp": "$(date -Iseconds)"
}
EOF
}

# CPU baseline test
test_cpu_baseline() {
    log_info "Testing CPU baseline..."

    # Get CPU info
    local cpu_cores=$(nproc)
    local cpu_load_1m=$(uptime | awk -F'load average:' '{print $2}' | awk -F',' '{print $1}' | xargs)
    local cpu_load_5m=$(uptime | awk -F'load average:' '{print $2}' | awk -F',' '{print $2}' | xargs)
    local cpu_load_15m=$(uptime | awk -F'load average:' '{print $2}' | awk -F',' '{print $3}' | xargs)

    # CPU frequency
    local cpu_freq=$(grep "cpu MHz" /proc/cpuinfo | head -1 | awk '{print $4}')

    # CPU usage (average over 5 seconds)
    local cpu_usage=$(top -bn2 -d 0.5 | grep "Cpu(s)" | tail -1 | awk '{print 100-$8}')

    # Context switches per second
    local ctx_switches=$(vmstat 1 2 | tail -1 | awk '{print $12}')

    cat <<EOF
  "cpu": {
    "cores": $cpu_cores,
    "frequency_mhz": ${cpu_freq:-0},
    "load_1m": $cpu_load_1m,
    "load_5m": $cpu_load_5m,
    "load_15m": $cpu_load_15m,
    "usage_percent": ${cpu_usage:-0},
    "context_switches_per_sec": ${ctx_switches:-0},
    "status": "$([ $(echo "$cpu_load_1m < $cpu_cores" | bc -l) -eq 1 ] && echo "GOOD" || echo "HIGH")"
  }
EOF

    log_success "CPU baseline: Load=${cpu_load_1m}/${cpu_cores} cores, Usage=${cpu_usage}%"
}

# Memory baseline test
test_memory_baseline() {
    log_info "Testing memory baseline..."

    # Get memory stats
    local total=$(free -m | awk '/^Mem:/ {print $2}')
    local used=$(free -m | awk '/^Mem:/ {print $3}')
    local free=$(free -m | awk '/^Mem:/ {print $4}')
    local available=$(free -m | awk '/^Mem:/ {print $7}')
    local cached=$(free -m | awk '/^Mem:/ {print $6}')

    # Calculate percentage
    local used_percent=$(echo "scale=2; ($used / $total) * 100" | bc)
    local available_percent=$(echo "scale=2; ($available / $total) * 100" | bc)

    # Swap usage
    local swap_total=$(free -m | awk '/^Swap:/ {print $2}')
    local swap_used=$(free -m | awk '/^Swap:/ {print $3}')
    local swap_percent=0
    if [ "$swap_total" -gt 0 ]; then
        swap_percent=$(echo "scale=2; ($swap_used / $swap_total) * 100" | bc)
    fi

    cat <<EOF
  "memory": {
    "total_mb": $total,
    "used_mb": $used,
    "free_mb": $free,
    "available_mb": $available,
    "cached_mb": $cached,
    "used_percent": $used_percent,
    "available_percent": $available_percent,
    "swap_total_mb": $swap_total,
    "swap_used_mb": $swap_used,
    "swap_percent": $swap_percent,
    "status": "$([ $(echo "$used_percent < 80" | bc -l) -eq 1 ] && echo "GOOD" || echo "HIGH")"
  }
EOF

    log_success "Memory baseline: ${used_mb}MB/${total}MB (${used_percent}% used)"
}

# Disk I/O baseline test
test_disk_baseline() {
    log_info "Testing disk I/O baseline..."

    # Get disk usage
    local disk_usage=$(df -h / | tail -1 | awk '{print $5}' | sed 's/%//')
    local disk_total=$(df -h / | tail -1 | awk '{print $2}')
    local disk_used=$(df -h / | tail -1 | awk '{print $3}')
    local disk_available=$(df -h / | tail -1 | awk '{print $4}')

    # I/O stats (simple measurement)
    local io_stats=$(iostat -x 1 2 2>/dev/null | tail -n +4 | head -1 || echo "0 0 0 0 0")
    local reads_per_sec=$(echo "$io_stats" | awk '{print $4}')
    local writes_per_sec=$(echo "$io_stats" | awk '{print $5}')

    # Disk I/O wait
    local io_wait=$(vmstat 1 2 | tail -1 | awk '{print $16}')

    cat <<EOF
  "disk": {
    "total": "$disk_total",
    "used": "$disk_used",
    "available": "$disk_available",
    "usage_percent": $disk_usage,
    "reads_per_sec": ${reads_per_sec:-0},
    "writes_per_sec": ${writes_per_sec:-0},
    "io_wait_percent": ${io_wait:-0},
    "status": "$([ $disk_usage -lt 80 ] && echo "GOOD" || echo "HIGH")"
  }
EOF

    log_success "Disk baseline: ${disk_used}/${disk_total} (${disk_usage}% used)"
}

# Network baseline test
test_network_baseline() {
    log_info "Testing network baseline..."

    # Get network interfaces
    local interfaces=$(ip -o link show | awk -F': ' '{print $2}' | grep -v "^lo$" | head -3)

    echo '  "network": {'
    echo '    "interfaces": ['

    local first=1
    for iface in $interfaces; do
        [ $first -eq 0 ] && echo ","
        first=0

        # Get RX/TX stats
        local rx_bytes=$(cat /sys/class/net/$iface/statistics/rx_bytes 2>/dev/null || echo 0)
        local tx_bytes=$(cat /sys/class/net/$iface/statistics/tx_bytes 2>/dev/null || echo 0)
        local rx_packets=$(cat /sys/class/net/$iface/statistics/rx_packets 2>/dev/null || echo 0)
        local tx_packets=$(cat /sys/class/net/$iface/statistics/tx_packets 2>/dev/null || echo 0)
        local rx_errors=$(cat /sys/class/net/$iface/statistics/rx_errors 2>/dev/null || echo 0)
        local tx_errors=$(cat /sys/class/net/$iface/statistics/tx_errors 2>/dev/null || echo 0)

        # Convert bytes to MB
        local rx_mb=$(echo "scale=2; $rx_bytes / 1048576" | bc)
        local tx_mb=$(echo "scale=2; $tx_bytes / 1048576" | bc)

        cat <<EOF
      {
        "interface": "$iface",
        "rx_bytes": $rx_bytes,
        "tx_bytes": $tx_bytes,
        "rx_mb": $rx_mb,
        "tx_mb": $tx_mb,
        "rx_packets": $rx_packets,
        "tx_packets": $tx_packets,
        "rx_errors": $rx_errors,
        "tx_errors": $tx_errors,
        "status": "$([ $rx_errors -eq 0 ] && [ $tx_errors -eq 0 ] && echo "GOOD" || echo "ERRORS")"
      }
EOF
    done

    echo '    ]'
    echo '  }'

    log_success "Network baseline: $(echo "$interfaces" | wc -w) interfaces monitored"
}

# Process baseline test
test_process_baseline() {
    log_info "Testing process baseline..."

    # Process counts
    local total_processes=$(ps aux | wc -l)
    local running_processes=$(ps aux | awk '{print $8}' | grep -c "^R" || echo 0)
    local sleeping_processes=$(ps aux | awk '{print $8}' | grep -c "^S" || echo 0)

    # Top 5 CPU consumers
    local top_cpu=$(ps aux --sort=-%cpu | head -6 | tail -5 | awk '{printf "      {\"pid\": %s, \"cpu\": %.1f, \"mem\": %.1f, \"command\": \"%s\"},\n", $2, $3, $4, $11}' | sed '$ s/,$//')

    # Top 5 Memory consumers
    local top_mem=$(ps aux --sort=-%mem | head -6 | tail -5 | awk '{printf "      {\"pid\": %s, \"cpu\": %.1f, \"mem\": %.1f, \"command\": \"%s\"},\n", $2, $3, $4, $11}' | sed '$ s/,$//')

    cat <<EOF
  "processes": {
    "total": $total_processes,
    "running": $running_processes,
    "sleeping": $sleeping_processes,
    "top_cpu": [
$top_cpu
    ],
    "top_memory": [
$top_mem
    ]
  }
EOF

    log_success "Process baseline: $total_processes total, $running_processes running"
}

# Main test execution
main() {
    log_info "=== System Baseline Performance Test ==="
    log_info "Duration: ${DURATION}s"
    log_info "Results: $RESULT_FILE"
    echo

    # Check dependencies
    if ! check_dependencies; then
        exit 1
    fi

    # Run tests and build JSON
    {
        echo "{"
        get_system_info | tail -n +2 | head -n -1
        echo ","
        test_cpu_baseline
        echo ","
        test_memory_baseline
        echo ","
        test_disk_baseline
        echo ","
        test_network_baseline
        echo ","
        test_process_baseline
        echo "}"
    } > "$RESULT_FILE"

    # Display summary
    echo
    log_info "=== Test Results Summary ==="

    # Extract key metrics
    local cpu_status=$(jq -r '.cpu.status' "$RESULT_FILE")
    local mem_status=$(jq -r '.memory.status' "$RESULT_FILE")
    local disk_status=$(jq -r '.disk.status' "$RESULT_FILE")

    echo -e "CPU Status:    $([ "$cpu_status" = "GOOD" ] && echo -e "${GREEN}$cpu_status${NC}" || echo -e "${YELLOW}$cpu_status${NC}")"
    echo -e "Memory Status: $([ "$mem_status" = "GOOD" ] && echo -e "${GREEN}$mem_status${NC}" || echo -e "${YELLOW}$mem_status${NC}")"
    echo -e "Disk Status:   $([ "$disk_status" = "GOOD" ] && echo -e "${GREEN}$disk_status${NC}" || echo -e "${YELLOW}$disk_status${NC}")"

    echo
    log_success "Results saved to: $RESULT_FILE"

    # Pretty print if jq available
    if command -v jq &> /dev/null && [ "$VERBOSE" -eq 1 ]; then
        echo
        log_info "Detailed Results:"
        jq '.' "$RESULT_FILE"
    fi
}

# Run main function
main "$@"
