#!/bin/bash
################################################################################
# Resource Usage Logger Script
# Purpose: Log comprehensive system resource usage over time
# Author: Hive Mind Coder Agent
# Version: 1.0.0
################################################################################

set -euo pipefail

# Configuration
readonly SCRIPT_NAME="$(basename "$0")"
readonly LOG_DIR="/var/log/diagnostics"
readonly TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
readonly LOG_FILE="${LOG_DIR}/resource-usage-${TIMESTAMP}.log"
readonly CSV_FILE="${LOG_DIR}/resource-usage-${TIMESTAMP}.csv"
readonly SAMPLE_INTERVAL=10  # seconds
readonly SAMPLE_COUNT=360    # 360 samples @ 10s = 1 hour
readonly ALERT_CPU_THRESHOLD=80
readonly ALERT_MEMORY_THRESHOLD=85
readonly ALERT_DISK_THRESHOLD=90

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

################################################################################
# Global Variables
################################################################################
declare -A PEAK_VALUES

################################################################################
# Functions
################################################################################

log_info() {
    echo -e "${BLUE}[INFO]${NC} $*" | tee -a "${LOG_FILE}"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*" | tee -a "${LOG_FILE}"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $*" | tee -a "${LOG_FILE}"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*" | tee -a "${LOG_FILE}"
}

print_header() {
    local title="$1"
    echo "" | tee -a "${LOG_FILE}"
    echo "================================================================" | tee -a "${LOG_FILE}"
    echo "  ${title}" | tee -a "${LOG_FILE}"
    echo "================================================================" | tee -a "${LOG_FILE}"
}

check_requirements() {
    log_info "Checking requirements..."

    if [[ ! -d "${LOG_DIR}" ]]; then
        mkdir -p "${LOG_DIR}"
        log_info "Created log directory: ${LOG_DIR}"
    fi

    # Check for required commands
    local missing_tools=()

    for tool in vmstat iostat free df; do
        if ! command -v "$tool" &> /dev/null; then
            missing_tools+=("$tool")
        fi
    done

    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        log_warning "Missing tools: ${missing_tools[*]}"
        log_warning "Install with: apt-get install sysstat procps"
    fi

    log_success "Requirements check completed"
}

get_system_info() {
    print_header "System Information"

    log_info "Gathering system information..."

    echo "  Hostname: $(hostname)" | tee -a "${LOG_FILE}"
    echo "  Kernel: $(uname -r)" | tee -a "${LOG_FILE}"
    echo "  OS: $(cat /etc/os-release 2>/dev/null | grep PRETTY_NAME | cut -d= -f2 | tr -d '"')" | tee -a "${LOG_FILE}"
    echo "  Uptime: $(uptime -p 2>/dev/null || uptime)" | tee -a "${LOG_FILE}"

    # CPU info
    local cpu_model=$(grep "model name" /proc/cpuinfo | head -1 | cut -d: -f2 | xargs)
    local cpu_cores=$(grep -c processor /proc/cpuinfo)
    echo "  CPU: ${cpu_model} (${cpu_cores} cores)" | tee -a "${LOG_FILE}"

    # Memory info
    local total_mem=$(free -h | grep Mem: | awk '{print $2}')
    echo "  Total Memory: ${total_mem}" | tee -a "${LOG_FILE}"

    # Disk info
    echo "  Disk Usage:" | tee -a "${LOG_FILE}"
    df -h / | tail -1 | awk '{printf "    Root: %s / %s (%s used)\n", $3, $2, $5}' | tee -a "${LOG_FILE}"
}

initialize_csv() {
    log_info "Initializing CSV log: ${CSV_FILE}"

    # CSV header
    cat > "${CSV_FILE}" << EOF
Timestamp,CPU_User%,CPU_System%,CPU_Idle%,CPU_Wait%,Memory_Used%,Memory_Free_MB,Swap_Used%,Disk_Read_KB/s,Disk_Write_KB/s,Network_RX_KB/s,Network_TX_KB/s,Load_1min,Load_5min,Load_15min,Processes,Alert_Level
EOF

    log_success "CSV initialized"
}

get_cpu_stats() {
    # Returns: user system idle wait
    if command -v vmstat &> /dev/null; then
        vmstat 1 2 | tail -1 | awk '{print $13,$14,$15,$16}'
    else
        echo "0 0 100 0"
    fi
}

get_memory_stats() {
    # Returns: used_percent free_mb swap_used_percent
    local mem_total=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    local mem_available=$(grep MemAvailable /proc/meminfo | awk '{print $2}')
    local mem_used=$((mem_total - mem_available))
    local mem_used_percent=$((mem_used * 100 / mem_total))
    local mem_free_mb=$((mem_available / 1024))

    local swap_total=$(grep SwapTotal /proc/meminfo | awk '{print $2}')
    local swap_free=$(grep SwapFree /proc/meminfo | awk '{print $2}')
    local swap_used_percent=0

    if [[ $swap_total -gt 0 ]]; then
        swap_used_percent=$(( (swap_total - swap_free) * 100 / swap_total ))
    fi

    echo "${mem_used_percent} ${mem_free_mb} ${swap_used_percent}"
}

get_disk_io_stats() {
    # Returns: read_kb_per_sec write_kb_per_sec
    if command -v iostat &> /dev/null; then
        iostat -d -k 1 2 | grep -v "^$" | tail -1 | awk '{print $3,$4}'
    else
        echo "0 0"
    fi
}

get_network_stats() {
    # Returns: rx_kb_per_sec tx_kb_per_sec
    local interface=$(ip route | grep default | awk '{print $5}' | head -1)

    if [[ -z "$interface" ]]; then
        echo "0 0"
        return
    fi

    local rx1=$(cat /sys/class/net/"$interface"/statistics/rx_bytes 2>/dev/null || echo 0)
    local tx1=$(cat /sys/class/net/"$interface"/statistics/tx_bytes 2>/dev/null || echo 0)

    sleep 1

    local rx2=$(cat /sys/class/net/"$interface"/statistics/rx_bytes 2>/dev/null || echo 0)
    local tx2=$(cat /sys/class/net/"$interface"/statistics/tx_bytes 2>/dev/null || echo 0)

    local rx_kb_per_sec=$(( (rx2 - rx1) / 1024 ))
    local tx_kb_per_sec=$(( (tx2 - tx1) / 1024 ))

    echo "${rx_kb_per_sec} ${tx_kb_per_sec}"
}

get_load_average() {
    # Returns: load_1min load_5min load_15min
    uptime | awk -F'load average:' '{print $2}' | sed 's/,//g'
}

get_process_count() {
    ps aux | wc -l
}

determine_alert_level() {
    local cpu=$1
    local memory=$2
    local disk=$3

    if [[ $cpu -ge $ALERT_CPU_THRESHOLD ]] || [[ $memory -ge $ALERT_MEMORY_THRESHOLD ]] || [[ $disk -ge $ALERT_DISK_THRESHOLD ]]; then
        echo "CRITICAL"
    elif [[ $cpu -ge 60 ]] || [[ $memory -ge 70 ]] || [[ $disk -ge 80 ]]; then
        echo "WARNING"
    else
        echo "OK"
    fi
}

update_peak_values() {
    local metric=$1
    local value=$2

    if [[ -z "${PEAK_VALUES[$metric]}" ]] || (( $(echo "$value > ${PEAK_VALUES[$metric]}" | bc -l 2>/dev/null || echo 0) )); then
        PEAK_VALUES[$metric]=$value
    fi
}

log_sample() {
    local sample_num=$1
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    # Gather all metrics
    local cpu_stats=($(get_cpu_stats))
    local cpu_user=${cpu_stats[0]:-0}
    local cpu_system=${cpu_stats[1]:-0}
    local cpu_idle=${cpu_stats[2]:-100}
    local cpu_wait=${cpu_stats[3]:-0}

    local mem_stats=($(get_memory_stats))
    local mem_used_pct=${mem_stats[0]:-0}
    local mem_free_mb=${mem_stats[1]:-0}
    local swap_used_pct=${mem_stats[2]:-0}

    local disk_io=($(get_disk_io_stats))
    local disk_read=${disk_io[0]:-0}
    local disk_write=${disk_io[1]:-0}

    local net_stats=($(get_network_stats))
    local net_rx=${net_stats[0]:-0}
    local net_tx=${net_stats[1]:-0}

    local load_avg=($(get_load_average))
    local load_1min=${load_avg[0]:-0}
    local load_5min=${load_avg[1]:-0}
    local load_15min=${load_avg[2]:-0}

    local processes=$(get_process_count)

    # Get disk usage
    local disk_used_pct=$(df / | tail -1 | awk '{print $5}' | tr -d '%')

    # Determine alert level
    local alert_level=$(determine_alert_level $((100 - cpu_idle)) $mem_used_pct $disk_used_pct)

    # Update peak values
    update_peak_values "cpu" $((100 - cpu_idle))
    update_peak_values "memory" "$mem_used_pct"
    update_peak_values "disk_io" "$((disk_read + disk_write))"
    update_peak_values "network" "$((net_rx + net_tx))"

    # Write to CSV
    echo "${timestamp},${cpu_user},${cpu_system},${cpu_idle},${cpu_wait},${mem_used_pct},${mem_free_mb},${swap_used_pct},${disk_read},${disk_write},${net_rx},${net_tx},${load_1min},${load_5min},${load_15min},${processes},${alert_level}" >> "${CSV_FILE}"

    # Display progress
    if [[ $((sample_num % 6)) -eq 1 ]]; then
        printf "%-20s %-10s %-10s %-10s %-15s %-10s\n" "Timestamp" "CPU%" "Memory%" "Disk I/O" "Network" "Alert"
        printf "%-20s %-10s %-10s %-10s %-15s %-10s\n" "--------------------" "--------" "--------" "----------" "--------------" "--------"
    fi

    printf "%-20s %-10s %-10s %-10s %-15s %-10s\n" \
        "$(date '+%H:%M:%S')" \
        "$((100 - cpu_idle))%" \
        "${mem_used_pct}%" \
        "${disk_read}/${disk_write}" \
        "${net_rx}/${net_tx}" \
        "${alert_level}"
}

monitor_resources() {
    print_header "Resource Monitoring (${SAMPLE_COUNT} samples @ ${SAMPLE_INTERVAL}s)"

    log_info "Starting resource monitoring..."
    log_info "Duration: $((SAMPLE_COUNT * SAMPLE_INTERVAL / 60)) minutes"
    log_info "Press Ctrl+C to stop early"

    echo "" | tee -a "${LOG_FILE}"

    local sample=1

    # Set up trap for clean exit
    trap 'log_warning "Monitoring interrupted by user"; generate_summary; exit 0' INT

    while [[ $sample -le $SAMPLE_COUNT ]]; do
        log_sample "$sample"

        ((sample++))
        [[ $sample -le $SAMPLE_COUNT ]] && sleep "$SAMPLE_INTERVAL"
    done

    trap - INT
}

generate_statistics() {
    print_header "Statistical Summary"

    log_info "Calculating statistics from ${CSV_FILE}..."

    if [[ ! -f "${CSV_FILE}" ]]; then
        log_error "CSV file not found"
        return
    fi

    # Use awk to calculate statistics
    awk -F, 'NR>1 {
        cpu_sum += (100 - $4)
        mem_sum += $6
        disk_read_sum += $9
        disk_write_sum += $10
        net_rx_sum += $11
        net_tx_sum += $12
        count++
    }
    END {
        if (count > 0) {
            printf "  Average CPU usage: %.2f%%\n", cpu_sum/count
            printf "  Average Memory usage: %.2f%%\n", mem_sum/count
            printf "  Average Disk read: %.2f KB/s\n", disk_read_sum/count
            printf "  Average Disk write: %.2f KB/s\n", disk_write_sum/count
            printf "  Average Network RX: %.2f KB/s\n", net_rx_sum/count
            printf "  Average Network TX: %.2f KB/s\n", net_tx_sum/count
        }
    }' "${CSV_FILE}" | tee -a "${LOG_FILE}"

    echo "" | tee -a "${LOG_FILE}"
    echo "  Peak Values:" | tee -a "${LOG_FILE}"
    echo "    Peak CPU: ${PEAK_VALUES[cpu]:-0}%" | tee -a "${LOG_FILE}"
    echo "    Peak Memory: ${PEAK_VALUES[memory]:-0}%" | tee -a "${LOG_FILE}"
    echo "    Peak Disk I/O: ${PEAK_VALUES[disk_io]:-0} KB/s" | tee -a "${LOG_FILE}"
    echo "    Peak Network: ${PEAK_VALUES[network]:-0} KB/s" | tee -a "${LOG_FILE}"

    # Count alerts
    local critical_count=$(grep -c "CRITICAL" "${CSV_FILE}" || echo 0)
    local warning_count=$(grep -c "WARNING" "${CSV_FILE}" || echo 0)

    echo "" | tee -a "${LOG_FILE}"
    echo "  Alert Summary:" | tee -a "${LOG_FILE}"
    echo "    Critical alerts: ${critical_count}" | tee -a "${LOG_FILE}"
    echo "    Warning alerts: ${warning_count}" | tee -a "${LOG_FILE}"

    if [[ $critical_count -gt 0 ]]; then
        log_error "Critical resource thresholds exceeded ${critical_count} times!"
    fi
}

generate_summary() {
    print_header "Summary Report"

    log_info "Monitoring completed at: $(date '+%Y-%m-%d %H:%M:%S')"
    log_info "Log file saved to: ${LOG_FILE}"
    log_info "CSV data saved to: ${CSV_FILE}"

    generate_statistics

    echo "" | tee -a "${LOG_FILE}"
    log_success "Resource usage logging complete!"

    cat << EOF | tee -a "${LOG_FILE}"

DATA FILES:
- Text log: ${LOG_FILE}
- CSV data: ${CSV_FILE}

ANALYSIS TOOLS:
- View CSV in spreadsheet application for graphing
- Use: grep CRITICAL ${CSV_FILE} to find peak usage times
- Use: awk -F, '{print \$1,\$6}' ${CSV_FILE} for memory timeline

RECOMMENDATIONS:
1. Review peak usage times for capacity planning
2. Investigate critical alerts for bottlenecks
3. Correlate with application logs for root cause analysis
4. Schedule resource-intensive tasks during low-usage periods

NEXT STEPS:
- Run: morning-monitor.sh during 9-10am peak to capture full picture
- Compare with baseline metrics from different times of day
- Set up continuous monitoring with tools like Prometheus/Grafana
EOF
}

################################################################################
# Main Execution
################################################################################

main() {
    log_info "Starting Resource Usage Logger (${SCRIPT_NAME})"

    check_requirements || exit 1

    get_system_info
    initialize_csv
    monitor_resources
    generate_summary

    exit 0
}

# Run main function
main "$@"

################################################################################
# USAGE EXAMPLES
################################################################################
# Basic usage (1 hour monitoring):
#   sudo ./log-resource-usage.sh
#
# Custom duration (30 minutes, 5s interval):
#   SAMPLE_COUNT=360 SAMPLE_INTERVAL=5 ./log-resource-usage.sh
#
# Schedule to run at 9am:
#   0 9 * * * /path/to/log-resource-usage.sh
#
# Run in background:
#   nohup ./log-resource-usage.sh > /dev/null 2>&1 &
################################################################################
