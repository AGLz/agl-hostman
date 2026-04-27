#!/bin/bash
################################################################################
# PHP-FPM Process Monitor Script
# Purpose: Monitor PHP-FPM processes, pools, and resource usage
# Author: Hive Mind Coder Agent
# Version: 1.0.0
################################################################################

set -euo pipefail

# Configuration
readonly SCRIPT_NAME="$(basename "$0")"
readonly LOG_DIR="/var/log/diagnostics"
readonly TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
readonly LOG_FILE="${LOG_DIR}/php-fpm-monitor-${TIMESTAMP}.log"
readonly SAMPLE_INTERVAL=5  # seconds
readonly SAMPLE_COUNT=12    # 12 samples = 1 minute
readonly ALERT_CPU_THRESHOLD=80.0
readonly ALERT_MEMORY_THRESHOLD=80.0

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

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

    if ! command -v bc &> /dev/null; then
        log_warning "bc calculator not found - some calculations may be unavailable"
    fi

    log_success "Requirements check completed"
}

detect_php_fpm() {
    print_header "PHP-FPM Service Detection"

    log_info "Detecting PHP-FPM processes..."

    if pgrep -f php-fpm > /dev/null; then
        log_success "PHP-FPM is running"

        # Count master and child processes
        local master_count=$(pgrep -f "php-fpm: master" | wc -l)
        local pool_count=$(pgrep -f "php-fpm: pool" | wc -l)

        echo "  Master processes: ${master_count}" | tee -a "${LOG_FILE}"
        echo "  Pool processes: ${pool_count}" | tee -a "${LOG_FILE}"

        # Get PHP version
        local php_version=$(php -v 2>/dev/null | head -1 | awk '{print $2}')
        echo "  PHP version: ${php_version}" | tee -a "${LOG_FILE}"
    else
        log_warning "PHP-FPM does not appear to be running"
        return 1
    fi
}

get_php_fpm_config() {
    print_header "PHP-FPM Configuration"

    local config_paths=(
        "/etc/php/*/fpm/pool.d/www.conf"
        "/etc/php-fpm.d/www.conf"
        "/etc/php*/fpm/pool.d/www.conf"
    )

    for pattern in "${config_paths[@]}"; do
        for config in $pattern; do
            if [[ -f "$config" ]]; then
                log_info "Found config: ${config}"

                echo "" | tee -a "${LOG_FILE}"
                echo "  Pool configuration:" | tee -a "${LOG_FILE}"

                # Extract key settings
                grep -E "^\[|^pm\s*=|^pm\.max_children|^pm\.start_servers|^pm\.min_spare|^pm\.max_spare|^pm\.max_requests" "$config" 2>/dev/null | sed 's/^/    /' | tee -a "${LOG_FILE}"

                echo "" | tee -a "${LOG_FILE}"
            fi
        done
    done

    # Check for status page configuration
    log_info "Checking for PHP-FPM status page..."

    for pattern in "${config_paths[@]}"; do
        for config in $pattern; do
            if [[ -f "$config" ]]; then
                if grep -q "pm.status_path" "$config" 2>/dev/null; then
                    local status_path=$(grep "pm.status_path" "$config" | awk -F= '{print $2}' | tr -d ' ')
                    log_success "Status page configured: ${status_path}"
                fi
            fi
        done
    done
}

analyze_php_processes() {
    print_header "PHP-FPM Process Analysis"

    log_info "Analyzing PHP-FPM processes..."

    if ! pgrep -f php-fpm > /dev/null; then
        log_warning "No PHP-FPM processes found"
        return
    fi

    # Get detailed process information
    echo "  Process Details:" | tee -a "${LOG_FILE}"
    echo "" | tee -a "${LOG_FILE}"

    ps aux --sort=-%cpu | grep php-fpm | grep -v grep | head -20 | while IFS= read -r line; do
        echo "    ${line}" | tee -a "${LOG_FILE}"
    done

    echo "" | tee -a "${LOG_FILE}"

    # Calculate totals
    local total_cpu=$(ps aux | grep php-fpm | grep -v grep | awk '{sum += $3} END {print sum}')
    local total_mem=$(ps aux | grep php-fpm | grep -v grep | awk '{sum += $4} END {print sum}')
    local process_count=$(pgrep -f php-fpm | wc -l)

    echo "  Resource Summary:" | tee -a "${LOG_FILE}"
    echo "    Total processes: ${process_count}" | tee -a "${LOG_FILE}"
    echo "    Total CPU usage: ${total_cpu}%" | tee -a "${LOG_FILE}"
    echo "    Total Memory usage: ${total_mem}%" | tee -a "${LOG_FILE}"

    # Alert if thresholds exceeded
    if command -v bc &> /dev/null; then
        if (( $(echo "$total_cpu > $ALERT_CPU_THRESHOLD" | bc -l) )); then
            log_error "⚠️  HIGH CPU USAGE DETECTED!"
        fi

        if (( $(echo "$total_mem > $ALERT_MEMORY_THRESHOLD" | bc -l) )); then
            log_error "⚠️  HIGH MEMORY USAGE DETECTED!"
        fi
    fi
}

monitor_realtime() {
    print_header "Real-Time Monitoring (${SAMPLE_COUNT} samples @ ${SAMPLE_INTERVAL}s interval)"

    log_info "Starting real-time monitoring..."

    echo "" | tee -a "${LOG_FILE}"
    printf "%-10s %-12s %-12s %-12s %-12s\n" "Time" "Processes" "CPU%" "Memory%" "Status" | tee -a "${LOG_FILE}"
    printf "%-10s %-12s %-12s %-12s %-12s\n" "----------" "----------" "----------" "----------" "----------" | tee -a "${LOG_FILE}"

    local sample=1
    local max_cpu=0
    local max_mem=0
    local max_processes=0

    while [[ $sample -le $SAMPLE_COUNT ]]; do
        local timestamp=$(date +%H:%M:%S)
        local process_count=$(pgrep -f php-fpm 2>/dev/null | wc -l)
        local cpu_usage=$(ps aux | grep php-fpm | grep -v grep | awk '{sum += $3} END {print sum}' 2>/dev/null || echo "0")
        local mem_usage=$(ps aux | grep php-fpm | grep -v grep | awk '{sum += $4} END {print sum}' 2>/dev/null || echo "0")

        # Update maximums
        if command -v bc &> /dev/null; then
            [[ $(echo "$cpu_usage > $max_cpu" | bc -l) -eq 1 ]] && max_cpu=$cpu_usage
            [[ $(echo "$mem_usage > $max_mem" | bc -l) -eq 1 ]] && max_mem=$mem_usage
        fi
        [[ $process_count -gt $max_processes ]] && max_processes=$process_count

        # Determine status
        local status="OK"
        if command -v bc &> /dev/null; then
            if (( $(echo "$cpu_usage > $ALERT_CPU_THRESHOLD" | bc -l) )) || (( $(echo "$mem_usage > $ALERT_MEMORY_THRESHOLD" | bc -l) )); then
                status="ALERT"
            fi
        fi

        printf "%-10s %-12s %-12.2f %-12.2f %-12s\n" "$timestamp" "$process_count" "$cpu_usage" "$mem_usage" "$status" | tee -a "${LOG_FILE}"

        ((sample++))
        [[ $sample -le $SAMPLE_COUNT ]] && sleep "$SAMPLE_INTERVAL"
    done

    echo "" | tee -a "${LOG_FILE}"
    echo "  Peak Statistics:" | tee -a "${LOG_FILE}"
    echo "    Max processes: ${max_processes}" | tee -a "${LOG_FILE}"
    echo "    Max CPU: ${max_cpu}%" | tee -a "${LOG_FILE}"
    echo "    Max Memory: ${max_mem}%" | tee -a "${LOG_FILE}"
}

check_php_fpm_logs() {
    print_header "PHP-FPM Error Logs"

    local log_paths=(
        "/var/log/php*-fpm.log"
        "/var/log/php*/fpm-php.www.log"
        "/var/log/php-fpm/error.log"
    )

    log_info "Checking PHP-FPM error logs..."

    local found_logs=false

    for pattern in "${log_paths[@]}"; do
        for log_file in $pattern; do
            if [[ -f "$log_file" ]]; then
                found_logs=true
                log_info "Checking ${log_file}..."

                echo "  Recent errors:" | tee -a "${LOG_FILE}"
                tail -50 "$log_file" | grep -i "error\|warning\|failed" | tail -10 | sed 's/^/    /' | tee -a "${LOG_FILE}"
                echo "" | tee -a "${LOG_FILE}"
            fi
        done
    done

    if [[ "$found_logs" == false ]]; then
        log_warning "No PHP-FPM log files found in standard locations"
    fi
}

analyze_slow_requests() {
    print_header "Slow Request Analysis"

    log_info "Checking for slow PHP requests..."

    # Check slow log configuration
    local slow_log_paths=(
        "/var/log/php*-fpm.log.slow"
        "/var/log/php*/slow.log"
    )

    local found_slow_logs=false

    for pattern in "${slow_log_paths[@]}"; do
        for slow_log in $pattern; do
            if [[ -f "$slow_log" ]]; then
                found_slow_logs=true
                log_warning "Found slow log: ${slow_log}"

                local entry_count=$(wc -l < "$slow_log")
                echo "  Total slow requests: ${entry_count}" | tee -a "${LOG_FILE}"

                if [[ $entry_count -gt 0 ]]; then
                    echo "  Recent slow requests:" | tee -a "${LOG_FILE}"
                    tail -20 "$slow_log" | sed 's/^/    /' | tee -a "${LOG_FILE}"
                fi

                echo "" | tee -a "${LOG_FILE}"
            fi
        done
    done

    if [[ "$found_slow_logs" == false ]]; then
        log_info "No slow request logs found (may not be configured)"
    fi
}

generate_summary() {
    print_header "Summary Report"

    log_info "Analysis completed at: $(date '+%Y-%m-%d %H:%M:%S')"
    log_info "Log file saved to: ${LOG_FILE}"

    echo "" | tee -a "${LOG_FILE}"
    log_success "PHP-FPM monitoring complete!"

    cat << EOF | tee -a "${LOG_FILE}"

RECOMMENDATIONS:
1. Review pool configuration (pm.max_children, pm.max_requests)
2. Enable PHP-FPM status page for real-time monitoring
3. Configure slow log to track long-running requests
4. Monitor during peak hours (9-10am) for capacity issues
5. Consider opcache configuration for performance

CONFIGURATION TIPS:
- pm.max_children: Set based on available memory
- pm.max_requests: Restart workers periodically (500-1000)
- request_slowlog_timeout: Track requests >5s
- opcache.memory_consumption: Allocate adequate memory

NEXT STEPS:
- Run: analyze-nginx-connections.sh to check web server load
- Run: log-resource-usage.sh to correlate with system resources
- Run: morning-monitor.sh during 9-10am peak period
EOF
}

################################################################################
# Main Execution
################################################################################

main() {
    log_info "Starting PHP-FPM Process Monitor (${SCRIPT_NAME})"

    check_requirements || exit 1

    detect_php_fpm || exit 1
    get_php_fpm_config
    analyze_php_processes
    monitor_realtime
    check_php_fpm_logs
    analyze_slow_requests
    generate_summary

    exit 0
}

# Run main function
main "$@"

################################################################################
# USAGE EXAMPLES
################################################################################
# Basic usage:
#   sudo ./monitor-php-fpm.sh
#
# Run during peak hours:
#   ./monitor-php-fpm.sh
#
# Schedule to run at 9am daily:
#   0 9 * * * /path/to/monitor-php-fpm.sh
#
# Monitor continuously every 5 minutes:
#   */5 * * * * /path/to/monitor-php-fpm.sh
#
# Custom sampling (via environment):
#   SAMPLE_INTERVAL=10 SAMPLE_COUNT=6 ./monitor-php-fpm.sh
################################################################################
