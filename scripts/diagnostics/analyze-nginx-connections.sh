#!/bin/bash
################################################################################
# Nginx Connection Tracker Script
# Purpose: Monitor nginx connections, requests, and performance metrics
# Author: Hive Mind Coder Agent
# Version: 1.0.0
################################################################################

set -euo pipefail

# Configuration
readonly SCRIPT_NAME="$(basename "$0")"
readonly LOG_DIR="/var/log/diagnostics"
readonly TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
readonly LOG_FILE="${LOG_DIR}/nginx-connections-${TIMESTAMP}.log"
readonly SAMPLE_INTERVAL=5
readonly SAMPLE_COUNT=12
readonly ALERT_CONN_THRESHOLD=1000

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

    if ! command -v nginx &> /dev/null; then
        log_warning "nginx command not found"
    fi

    log_success "Requirements check completed"
}

detect_nginx() {
    print_header "Nginx Service Detection"

    log_info "Detecting nginx processes..."

    if pgrep -f nginx > /dev/null; then
        log_success "Nginx is running"

        # Count master and worker processes
        local master_count=$(pgrep -f "nginx: master" | wc -l)
        local worker_count=$(pgrep -f "nginx: worker" | wc -l)

        echo "  Master processes: ${master_count}" | tee -a "${LOG_FILE}"
        echo "  Worker processes: ${worker_count}" | tee -a "${LOG_FILE}"

        # Get nginx version
        local nginx_version=$(nginx -v 2>&1 | awk -F/ '{print $2}')
        echo "  Nginx version: ${nginx_version}" | tee -a "${LOG_FILE}"
    else
        log_warning "Nginx does not appear to be running"
        return 1
    fi
}

get_nginx_config() {
    print_header "Nginx Configuration Analysis"

    if ! command -v nginx &> /dev/null; then
        log_warning "nginx command not available"
        return
    fi

    log_info "Analyzing nginx configuration..."

    # Get config file location
    local config_file=$(nginx -V 2>&1 | grep -o 'conf-path=[^ ]*' | cut -d= -f2)
    echo "  Config file: ${config_file}" | tee -a "${LOG_FILE}"

    # Check worker configuration
    if [[ -f "$config_file" ]]; then
        echo "" | tee -a "${LOG_FILE}"
        echo "  Worker configuration:" | tee -a "${LOG_FILE}"
        grep -E "worker_processes|worker_connections" "$config_file" | sed 's/^/    /' | tee -a "${LOG_FILE}"
    fi

    # Check for status page
    log_info "Checking for nginx status page..."

    local status_enabled=false

    if nginx -V 2>&1 | grep -q "http_stub_status_module"; then
        log_success "Status module is enabled"
        status_enabled=true

        # Try to access status page
        if command -v curl &> /dev/null; then
            for url in "http://localhost/nginx_status" "http://localhost/status" "http://127.0.0.1/nginx_status"; do
                if curl -s "$url" > /dev/null 2>&1; then
                    log_success "Status page accessible at: ${url}"
                    break
                fi
            done
        fi
    else
        log_warning "Status module not enabled (compile with --with-http_stub_status_module)"
    fi
}

analyze_nginx_processes() {
    print_header "Nginx Process Analysis"

    log_info "Analyzing nginx processes..."

    if ! pgrep -f nginx > /dev/null; then
        log_warning "No nginx processes found"
        return
    fi

    echo "  Process Details:" | tee -a "${LOG_FILE}"
    echo "" | tee -a "${LOG_FILE}"

    ps aux --sort=-%cpu | grep nginx | grep -v grep | while IFS= read -r line; do
        echo "    ${line}" | tee -a "${LOG_FILE}"
    done

    echo "" | tee -a "${LOG_FILE}"

    # Calculate totals
    local total_cpu=$(ps aux | grep nginx | grep -v grep | awk '{sum += $3} END {print sum}')
    local total_mem=$(ps aux | grep nginx | grep -v grep | awk '{sum += $4} END {print sum}')
    local process_count=$(pgrep -f nginx | wc -l)

    echo "  Resource Summary:" | tee -a "${LOG_FILE}"
    echo "    Total processes: ${process_count}" | tee -a "${LOG_FILE}"
    echo "    Total CPU usage: ${total_cpu}%" | tee -a "${LOG_FILE}"
    echo "    Total Memory usage: ${total_mem}%" | tee -a "${LOG_FILE}"
}

get_connection_stats() {
    print_header "Connection Statistics"

    log_info "Gathering connection statistics..."

    # Check if status page is accessible
    local status_url=""

    if command -v curl &> /dev/null; then
        for url in "http://localhost/nginx_status" "http://localhost/status" "http://127.0.0.1/nginx_status"; do
            if curl -s "$url" > /dev/null 2>&1; then
                status_url="$url"
                break
            fi
        done
    fi

    if [[ -n "$status_url" ]]; then
        log_success "Reading from nginx status page..."
        echo "" | tee -a "${LOG_FILE}"
        curl -s "$status_url" | tee -a "${LOG_FILE}"
        echo "" | tee -a "${LOG_FILE}"
    else
        log_warning "Status page not accessible, using netstat..."

        # Count connections via netstat
        if command -v netstat &> /dev/null; then
            local established=$(netstat -an | grep :80 | grep ESTABLISHED | wc -l)
            local time_wait=$(netstat -an | grep :80 | grep TIME_WAIT | wc -l)
            local listening=$(netstat -an | grep :80 | grep LISTEN | wc -l)

            echo "  Connection states:" | tee -a "${LOG_FILE}"
            echo "    ESTABLISHED: ${established}" | tee -a "${LOG_FILE}"
            echo "    TIME_WAIT: ${time_wait}" | tee -a "${LOG_FILE}"
            echo "    LISTENING: ${listening}" | tee -a "${LOG_FILE}"

            if [[ $established -gt $ALERT_CONN_THRESHOLD ]]; then
                log_error "⚠️  HIGH CONNECTION COUNT DETECTED!"
            fi
        elif command -v ss &> /dev/null; then
            local established=$(ss -tan | grep :80 | grep ESTAB | wc -l)
            local time_wait=$(ss -tan | grep :80 | grep TIME-WAIT | wc -l)

            echo "  Connection states:" | tee -a "${LOG_FILE}"
            echo "    ESTABLISHED: ${established}" | tee -a "${LOG_FILE}"
            echo "    TIME_WAIT: ${time_wait}" | tee -a "${LOG_FILE}"

            if [[ $established -gt $ALERT_CONN_THRESHOLD ]]; then
                log_error "⚠️  HIGH CONNECTION COUNT DETECTED!"
            fi
        else
            log_warning "Neither netstat nor ss available for connection tracking"
        fi
    fi
}

monitor_realtime() {
    print_header "Real-Time Connection Monitoring (${SAMPLE_COUNT} samples @ ${SAMPLE_INTERVAL}s)"

    log_info "Starting real-time monitoring..."

    echo "" | tee -a "${LOG_FILE}"
    printf "%-10s %-15s %-15s %-15s %-15s\n" "Time" "Active" "Reading" "Writing" "Waiting" | tee -a "${LOG_FILE}"
    printf "%-10s %-15s %-15s %-15s %-15s\n" "----------" "-------------" "-------------" "-------------" "-------------" | tee -a "${LOG_FILE}"

    local sample=1
    local max_active=0
    local max_reading=0
    local max_writing=0
    local max_waiting=0

    # Check if we can use status page
    local status_url=""
    if command -v curl &> /dev/null; then
        for url in "http://localhost/nginx_status" "http://localhost/status"; do
            if curl -s "$url" > /dev/null 2>&1; then
                status_url="$url"
                break
            fi
        done
    fi

    while [[ $sample -le $SAMPLE_COUNT ]]; do
        local timestamp=$(date +%H:%M:%S)

        if [[ -n "$status_url" ]]; then
            # Parse status page
            local stats=$(curl -s "$status_url")
            local active=$(echo "$stats" | grep "Active connections" | awk '{print $3}')
            local reading=$(echo "$stats" | grep "Reading" | awk '{print $2}')
            local writing=$(echo "$stats" | grep "Reading" | awk '{print $4}')
            local waiting=$(echo "$stats" | grep "Reading" | awk '{print $6}')
        else
            # Use netstat/ss fallback
            if command -v netstat &> /dev/null; then
                local active=$(netstat -an | grep :80 | grep ESTABLISHED | wc -l)
            elif command -v ss &> /dev/null; then
                local active=$(ss -tan | grep :80 | grep ESTAB | wc -l)
            else
                local active=0
            fi
            local reading=0
            local writing=0
            local waiting=0
        fi

        # Update maximums
        [[ ${active:-0} -gt $max_active ]] && max_active=${active:-0}
        [[ ${reading:-0} -gt $max_reading ]] && max_reading=${reading:-0}
        [[ ${writing:-0} -gt $max_writing ]] && max_writing=${writing:-0}
        [[ ${waiting:-0} -gt $max_waiting ]] && max_waiting=${waiting:-0}

        printf "%-10s %-15s %-15s %-15s %-15s\n" "$timestamp" "${active:-N/A}" "${reading:-N/A}" "${writing:-N/A}" "${waiting:-N/A}" | tee -a "${LOG_FILE}"

        ((sample++))
        [[ $sample -le $SAMPLE_COUNT ]] && sleep "$SAMPLE_INTERVAL"
    done

    echo "" | tee -a "${LOG_FILE}"
    echo "  Peak Statistics:" | tee -a "${LOG_FILE}"
    echo "    Max active connections: ${max_active}" | tee -a "${LOG_FILE}"
    echo "    Max reading: ${max_reading}" | tee -a "${LOG_FILE}"
    echo "    Max writing: ${max_writing}" | tee -a "${LOG_FILE}"
    echo "    Max waiting: ${max_waiting}" | tee -a "${LOG_FILE}"
}

analyze_access_logs() {
    print_header "Access Log Analysis"

    log_info "Analyzing nginx access logs..."

    local access_log_paths=(
        "/var/log/nginx/access.log"
        "/var/log/nginx/*.access.log"
    )

    local today=$(date +%d/%b/%Y)

    for pattern in "${access_log_paths[@]}"; do
        for log_file in $pattern; do
            if [[ -f "$log_file" ]]; then
                log_info "Analyzing ${log_file}..."

                # Count requests from today
                local total_requests=$(grep "$today" "$log_file" 2>/dev/null | wc -l)
                echo "  Total requests today: ${total_requests}" | tee -a "${LOG_FILE}"

                # Top 10 requested URLs
                echo "  Top 10 requested URLs:" | tee -a "${LOG_FILE}"
                grep "$today" "$log_file" 2>/dev/null | awk '{print $7}' | sort | uniq -c | sort -rn | head -10 | sed 's/^/    /' | tee -a "${LOG_FILE}"

                # Top 10 client IPs
                echo "  Top 10 client IPs:" | tee -a "${LOG_FILE}"
                grep "$today" "$log_file" 2>/dev/null | awk '{print $1}' | sort | uniq -c | sort -rn | head -10 | sed 's/^/    /' | tee -a "${LOG_FILE}"

                # HTTP status codes
                echo "  Status code distribution:" | tee -a "${LOG_FILE}"
                grep "$today" "$log_file" 2>/dev/null | awk '{print $9}' | sort | uniq -c | sort -rn | sed 's/^/    /' | tee -a "${LOG_FILE}"

                echo "" | tee -a "${LOG_FILE}"
                break
            fi
        done
    done
}

check_error_logs() {
    print_header "Error Log Analysis"

    log_info "Checking nginx error logs..."

    local error_log_paths=(
        "/var/log/nginx/error.log"
        "/var/log/nginx/*.error.log"
    )

    for pattern in "${error_log_paths[@]}"; do
        for log_file in $pattern; do
            if [[ -f "$log_file" ]]; then
                log_info "Checking ${log_file}..."

                echo "  Recent errors:" | tee -a "${LOG_FILE}"
                tail -50 "$log_file" | grep -E "error|warn|crit" | tail -20 | sed 's/^/    /' | tee -a "${LOG_FILE}"

                echo "" | tee -a "${LOG_FILE}"
                break
            fi
        done
    done
}

generate_summary() {
    print_header "Summary Report"

    log_info "Analysis completed at: $(date '+%Y-%m-%d %H:%M:%S')"
    log_info "Log file saved to: ${LOG_FILE}"

    echo "" | tee -a "${LOG_FILE}"
    log_success "Nginx connection analysis complete!"

    cat << EOF | tee -a "${LOG_FILE}"

RECOMMENDATIONS:
1. Enable nginx stub_status module for better monitoring
2. Configure keepalive timeout for connection reuse
3. Adjust worker_processes and worker_connections based on load
4. Implement connection rate limiting for DoS protection
5. Monitor error logs for connection-related issues

OPTIMIZATION TIPS:
- worker_processes: Usually set to number of CPU cores
- worker_connections: 1024-4096 depending on RAM
- keepalive_timeout: 60-75 seconds recommended
- client_max_body_size: Set based on upload requirements

NEXT STEPS:
- Run: monitor-php-fpm.sh to correlate with PHP processing
- Run: log-resource-usage.sh to track system resources
- Run: morning-monitor.sh for comprehensive peak-time analysis
EOF
}

################################################################################
# Main Execution
################################################################################

main() {
    log_info "Starting Nginx Connection Tracker (${SCRIPT_NAME})"

    check_requirements || exit 1

    detect_nginx || exit 1
    get_nginx_config
    analyze_nginx_processes
    get_connection_stats
    monitor_realtime
    analyze_access_logs
    check_error_logs
    generate_summary

    exit 0
}

# Run main function
main "$@"

################################################################################
# USAGE EXAMPLES
################################################################################
# Basic usage:
#   sudo ./analyze-nginx-connections.sh
#
# Run during peak hours:
#   ./analyze-nginx-connections.sh
#
# Schedule to run at 9am daily:
#   0 9 * * * /path/to/analyze-nginx-connections.sh
#
# Monitor continuously every 5 minutes:
#   */5 9-10 * * * /path/to/analyze-nginx-connections.sh
################################################################################
