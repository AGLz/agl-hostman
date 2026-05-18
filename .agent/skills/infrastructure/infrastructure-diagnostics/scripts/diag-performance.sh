#!/bin/bash
################################################################################
# Performance Diagnostics
#
# Description: Check system performance metrics
# Output: JSON report with findings and recommendations
# Usage: ./diag-performance.sh [--duration seconds]
################################################################################

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DURATION="${1:-5}"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Thresholds (from monitoring config)
CPU_WARNING=70
CPU_CRITICAL=85
MEM_WARNING=80
MEM_CRITICAL=90
DISK_WARNING=80
DISK_CRITICAL=90

# JSON output structure
json_output='{
  "scan_info": {
    "timestamp": "'"$TIMESTAMP"'",
    "scan_version": "1.0.0",
    "duration": '"$DURATION"'
  },
  "checks": {},
  "metrics": {}
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

add_metric() {
    local category="$1"
    local metric="$2"
    local value="$3"

    json_output=$(echo "$json_output" | jq --arg cat "$category" --arg met "$metric" --arg val "$value" '
        .metrics[$cat] |= . + {
            ($met): ($val | tonumber? // $val)
        }
    ')
}

################################################################################
# CPU Analysis
################################################################################
check_cpu() {
    echo "Checking CPU performance..."

    # Get overall CPU usage
    local cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)
    local cpu_idle=$(top -bn1 | grep "Cpu(s)" | awk '{print $8}' | cut -d'%' -f1)

    echo "  CPU usage: ${cpu_usage}%"
    echo "  CPU idle: ${cpu_idle}%"

    add_metric "cpu" "usage_percent" "$cpu_usage"
    add_metric "cpu" "idle_percent" "$cpu_idle"

    local cpu_status="pass"
    local cpu_message="CPU usage: ${cpu_usage}%"
    local cpu_recommendation=""

    # Use awk for floating point comparison
    if (( $(echo "$cpu_usage > $CPU_CRITICAL" | bc -l) )); then
        cpu_status="critical"
        cpu_recommendation="Identify and stop high CPU processes, or scale up"
        echo "  CRITICAL: CPU usage above ${CPU_CRITICAL}%"
    elif (( $(echo "$cpu_usage > $CPU_WARNING" | bc -l) )); then
        cpu_status="warning"
        cpu_recommendation="Monitor CPU usage closely"
        echo "  WARNING: CPU usage above ${CPU_WARNING}%"
    fi

    add_finding "cpu" "usage" "$cpu_status" "$cpu_message" "$cpu_recommendation"

    # Get CPU load average
    local load_1min=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | tr -d ',')
    local load_5min=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $2}' | tr -d ',')
    local load_15min=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $3}')

    echo "  Load average: $load_1min (1min), $load_5min (5min), $load_15min (15min)"

    add_metric "cpu" "load_1min" "$load_1min"
    add_metric "cpu" "load_5min" "$load_5min"
    add_metric "cpu" "load_15min" "$load_15min"

    # Get number of CPU cores
    local cpu_cores=$(nproc)
    echo "  CPU cores: $cpu_cores"

    add_metric "cpu" "cores" "$cpu_cores"

    # Check if load is high relative to cores
    local load_per_core=$(awk "BEGIN {printf \"%.2f\", $load_1min / $cpu_cores}")
    if (( $(echo "$load_per_core > 2.0" | bc -l) )); then
        echo "  WARNING: Load per core is high ($load_per_core)"
        add_finding "cpu" "load" "warning" "Load per core: $load_per_core" "Investigate high load processes"
    elif (( $(echo "$load_per_core > 1.0" | bc -l) )); then
        add_finding "cpu" "load" "pass" "Load per core: $load_per_core (monitoring)" ""
    else
        add_finding "cpu" "load" "pass" "Load per core: $load_per_core" ""
    fi

    # Top CPU processes
    echo "  Top CPU processes:"
    ps aux --sort=-%cpu | head -6 | tail -5 | awk '{printf "    %s: %s%% CPU\n", $11, $3}'
}

################################################################################
# Memory Analysis
################################################################################
check_memory() {
    echo "Checking memory performance..."

    # Get memory info
    local mem_total=$(free -m | awk '/^Mem:/{print $2}')
    local mem_used=$(free -m | awk '/^Mem:/{print $3}')
    local mem_free=$(free -m | awk '/^Mem:/{print $4}')
    local mem_available=$(free -m | awk '/^Mem:/{print $7}')
    local mem_cached=$(free -m | awk '/^Mem:/{print $6}')
    local mem_percent=$(awk "BEGIN {printf \"%.0f\", ($mem_used / $mem_total) * 100}")

    echo "  Memory: ${mem_used}MB / ${mem_total}MB (${mem_percent}%)"
    echo "  Available: ${mem_available}MB"
    echo "  Cached: ${mem_cached}MB"

    add_metric "memory" "total_mb" "$mem_total"
    add_metric "memory" "used_mb" "$mem_used"
    add_metric "memory" "free_mb" "$mem_free"
    add_metric "memory" "available_mb" "$mem_available"
    add_metric "memory" "cached_mb" "$mem_cached"
    add_metric "memory" "usage_percent" "$mem_percent"

    local mem_status="pass"
    local mem_message="Memory: ${mem_percent}% used"
    local mem_recommendation=""

    if [ "$mem_percent" -gt "$MEM_CRITICAL" ]; then
        mem_status="critical"
        mem_recommendation="Free memory or add more RAM immediately"
        echo "  CRITICAL: Memory usage above ${MEM_CRITICAL}%"
    elif [ "$mem_percent" -gt "$MEM_WARNING" ]; then
        mem_status="warning"
        mem_recommendation="Monitor memory usage, consider freeing memory"
        echo "  WARNING: Memory usage above ${MEM_WARNING}%"
    fi

    add_finding "memory" "usage" "$mem_status" "$mem_message" "$mem_recommendation"

    # Check swap usage
    local swap_total=$(free -m | awk '/^Swap:/{print $2}')
    local swap_used=$(free -m | awk '/^Swap:/{print $3}')
    local swap_percent=0

    if [ "$swap_total" -gt 0 ]; then
        swap_percent=$(awk "BEGIN {printf \"%.0f\", ($swap_used / $swap_total) * 100}")
    fi

    echo "  Swap: ${swap_used}MB / ${swap_total}MB (${swap_percent}%)"

    add_metric "memory" "swap_total_mb" "$swap_total"
    add_metric "memory" "swap_used_mb" "$swap_used"
    add_metric "memory" "swap_percent" "$swap_percent"

    if [ "$swap_percent" -gt 50 ]; then
        echo "  WARNING: High swap usage indicates memory pressure"
        add_finding "memory" "swap" "warning" "Swap usage: ${swap_percent}%" "Check for memory leaks"
    else
        add_finding "memory" "swap" "pass" "Swap usage: ${swap_percent}%" ""
    fi

    # Top memory processes
    echo "  Top memory processes:"
    ps aux --sort=-%mem | head -6 | tail -5 | awk '{printf "    %s: %s%% Memory\n", $11, $4}'
}

################################################################################
# Disk Analysis
################################################################################
check_disk() {
    echo "Checking disk performance..."

    local disk_status="pass"
    local disk_message=""
    local disk_recommendation=""
    local has_disk_issue=false

    # Check each mount point
    df -H | grep -E '^/dev/' | while read -r filesystem size used avail percent mount; do
        local used_percent=${percent%\%}

        echo "  $mount: $used (used: $used_percent, avail: $avail)"

        add_metric "disk" "${mount}_used_percent" "$used_percent"
        add_metric "disk" "${mount}_available" "$avail"

        if [ "$used_percent" -gt "$DISK_CRITICAL" ]; then
            echo "    CRITICAL: Disk usage above ${DISK_CRITICAL}%"
            add_finding "disk" "${mount}_usage" "critical" "Mount $mount is ${used_percent} full" "Clean up or expand storage immediately"
            has_disk_issue=true
        elif [ "$used_percent" -gt "$DISK_WARNING" ]; then
            echo "    WARNING: Disk usage above ${DISK_WARNING}%"
            add_finding "disk" "${mount}_usage" "warning" "Mount $mount is ${used_percent} full" "Monitor disk usage"
            has_disk_issue=true
        else
            add_finding "disk" "${mount}_usage" "pass" "Mount $mount: ${used_percent} used" ""
        fi
    done

    # Check disk I/O
    if command -v iostat &>/dev/null; then
        echo "  Disk I/O stats:"
        iostat -x 1 2 2>/dev/null | grep -E "Device|sd" | tail -5 | while read -r line; do
            echo "    $line"
        done
    fi

    # Check inode usage
    echo "  Inode usage:"
    df -i | grep -E '^/dev/' | while read -r filesystem inodes used avail percent mount; do
        local used_percent=${percent%\%}
        if [ "$used_percent" -gt 90 ]; then
            echo "    WARNING: $mount: ${used_percent}% inodes used"
            add_finding "disk" "${mount}_inodes" "warning" "Inode usage: ${used_percent}%" "Clean up small files"
        fi
    done
}

################################################################################
# I/O Analysis
################################################################################
check_io() {
    echo "Checking I/O performance..."

    # Get I/O stats
    if command -v vmstat &>/dev/null; then
        echo "  I/O wait:"
        vmstat 1 2 | tail -1 | awk '{print "    CPU I/O wait: " $16 "%"}'
    fi

    # Check for I/O bottlenecks using iostat
    if command -v iostat &>/dev/null; then
        local io_output=$(iostat -x 1 1 2>/dev/null || echo "")

        # Look for high %util
        if [ -n "$io_output" ]; then
            echo "$io_output" | awk 'NR>4 {printf "    Device %s: %s%% utilized\n", $1, $12}' | head -5
        fi
    fi
}

################################################################################
# Network I/O
################################################################################
check_network_io() {
    echo "Checking network I/O..."

    # Get network interface stats
    if command -v ip &>/dev/null; then
        echo "  Network interfaces:"
        ip -s link show | grep -E "^[0-9]+:|RX|TX" | while read -r line; do
            if [[ "$line" =~ ^[0-9]+: ]]; then
                local iface=$(echo "$line" | awk '{print $2}' | tr -d ':')
                echo "    $iface"
            elif [[ "$line" =~ RX: ]]; then
                local rx_bytes=$(echo "$line" | awk '{print $2}')
                echo "      RX: $rx_bytes bytes"
            elif [[ "$line" =~ TX: ]]; then
                local tx_bytes=$(echo "$line" | awk '{print $2}')
                echo "      TX: $tx_bytes bytes"
            fi
        done
    fi

    # Check connection count
    if command -v ss &>/dev/null; then
        local connections=$(ss -s | grep "TCP" | awk '{print $2}')
        echo "  Active TCP connections: $connections"
        add_metric "network" "tcp_connections" "$connections"
    fi
}

################################################################################
# Process Count
################################################################################
check_processes() {
    echo "Checking process count..."

    local total_processes=$(ps aux | wc -l)
    local running_processes=$(ps aux | awk '$8 ~ /R/ {print}' | wc -l)
    local sleeping_processes=$(ps aux | awk '$8 ~ /S/ {print}' | wc -l)
    local zombie_processes=$(ps aux | awk '$8 ~ /Z/ {print}' | wc -l)

    echo "  Total processes: $total_processes"
    echo "  Running: $running_processes"
    echo "  Sleeping: $sleeping_processes"
    echo "  Zombie: $zombie_processes"

    add_metric "processes" "total" "$total_processes"
    add_metric "processes" "running" "$running_processes"
    add_metric "processes" "zombie" "$zombie_processes"

    if [ "$zombie_processes" -gt 0 ]; then
        echo "  WARNING: Zombie processes detected"
        add_finding "processes" "zombies" "warning" "$zombie_processes zombie process(es)" "Check parent processes"
    else
        add_finding "processes" "zombies" "pass" "No zombie processes" ""
    fi
}

################################################################################
# System Load Trend
################################################################################
check_load_trend() {
    echo "Checking load trend over ${DURATION} seconds..."

    if [ "$DURATION" -lt 5 ]; then
        echo "  Skipping load trend (duration too short)"
        return
    fi

    local samples=()
    local count=0
    local end_time=$(($(date +%s) + DURATION))

    while [ $(date +%s) -lt $end_time ] && [ $count -lt 10 ]; do
        local load=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | tr -d ',')
        samples+=("$load")
        sleep $((DURATION / 10))
        count=$((count + 1))
    done

    if [ ${#samples[@]} -gt 0 ]; then
        echo "  Load samples:"
        for i in "${!samples[@]}"; do
            echo "    Sample $((i + 1)): ${samples[$i]}"
        done

        # Calculate average
        local sum=0
        for load in "${samples[@]}"; do
            sum=$(awk "BEGIN {print $sum + $load}")
        done
        local avg=$(awk "BEGIN {printf \"%.2f\", $sum / ${#samples[@]}}")
        echo "  Average load: $avg"
        add_metric "trend" "avg_load" "$avg"
    fi
}

################################################################################
# Main Execution
################################################################################
main() {
    echo "=== Performance Diagnostic Scan ==="
    echo "Timestamp: $TIMESTAMP"
    echo "Duration: ${DURATION}s"
    echo ""

    # Run all checks
    check_cpu
    echo ""
    check_memory
    echo ""
    check_disk
    echo ""
    check_io
    echo ""
    check_network_io
    echo ""
    check_processes
    echo ""
    check_load_trend

    # Generate summary
    local critical=$(echo "$json_output" | jq '[.checks[][] | select(.status == "critical")] | length')
    local warning=$(echo "$json_output" | jq '[.checks[][] | select(.status == "warning")] | length')
    local passed=$(echo "$json_output" | jq '[.checks[][] | select(.status == "pass")] | length')

    json_output=$(echo "$json_output" | jq --argjson critical "$critical" --argjson warning "$warning" --argjson passed "$passed" '
        .summary = {
            "critical": $critical,
            "warning": $warning,
            "passed": $passed,
            "total_issues": ($critical + $warning)
        }
    ')

    echo ""
    echo "=== Summary ==="
    echo "Critical: $critical"
    echo "Warning: $warning"
    echo "Passed: $passed"
    echo ""

    # Output JSON report
    echo "=== JSON Report ==="
    echo "$json_output" | jq '.'

    # Check for critical issues
    if [ "$critical" -gt 0 ]; then
        exit 1
    fi

    exit 0
}

main "$@"
