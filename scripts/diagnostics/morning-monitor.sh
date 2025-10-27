#!/bin/bash
################################################################################
# Unified Morning Monitor Script
# Purpose: Comprehensive monitoring during 9-10am peak period
# Author: Hive Mind Coder Agent
# Version: 1.0.0
################################################################################

set -euo pipefail

# Configuration
readonly SCRIPT_NAME="$(basename "$0")"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly LOG_DIR="/var/log/diagnostics"
readonly TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
readonly MAIN_LOG="${LOG_DIR}/morning-monitor-${TIMESTAMP}.log"
readonly MORNING_START_HOUR=9
readonly MORNING_END_HOUR=10

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m'

################################################################################
# Functions
################################################################################

log_info() {
    echo -e "${BLUE}[INFO]${NC} $*" | tee -a "${MAIN_LOG}"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*" | tee -a "${MAIN_LOG}"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $*" | tee -a "${MAIN_LOG}"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*" | tee -a "${MAIN_LOG}"
}

log_section() {
    echo -e "${CYAN}[SECTION]${NC} $*" | tee -a "${MAIN_LOG}"
}

print_header() {
    local title="$1"
    echo "" | tee -a "${MAIN_LOG}"
    echo "================================================================" | tee -a "${MAIN_LOG}"
    echo "  ${title}" | tee -a "${MAIN_LOG}"
    echo "================================================================" | tee -a "${MAIN_LOG}"
}

print_banner() {
    cat << 'EOF' | tee -a "${MAIN_LOG}"
╔══════════════════════════════════════════════════════════════════════╗
║                                                                      ║
║                  MORNING PEAK MONITOR (9-10am)                       ║
║                  Comprehensive VPS Diagnostics                       ║
║                                                                      ║
╚══════════════════════════════════════════════════════════════════════╝
EOF
}

check_time_window() {
    local current_hour=$(date +%H | sed 's/^0//')

    log_info "Current time: $(date '+%Y-%m-%d %H:%M:%S')"
    log_info "Current hour: ${current_hour}"

    if [[ $current_hour -ge $MORNING_START_HOUR && $current_hour -lt $MORNING_END_HOUR ]]; then
        log_success "✓ Running during morning peak window (9-10am)"
        return 0
    else
        log_warning "⚠ NOT running during morning peak window (9-10am)"
        log_warning "Running anyway for baseline comparison..."
        return 1
    fi
}

check_requirements() {
    log_info "Checking requirements..."

    if [[ ! -d "${LOG_DIR}" ]]; then
        mkdir -p "${LOG_DIR}"
        log_info "Created log directory: ${LOG_DIR}"
    fi

    # Check for subscripts
    local subscripts=(
        "check-cron-jobs.sh"
        "detect-mysql-backups.sh"
        "monitor-php-fpm.sh"
        "analyze-nginx-connections.sh"
        "log-resource-usage.sh"
    )

    local missing_scripts=()

    for script in "${subscripts[@]}"; do
        if [[ ! -f "${SCRIPT_DIR}/${script}" ]]; then
            missing_scripts+=("${script}")
        fi
    done

    if [[ ${#missing_scripts[@]} -gt 0 ]]; then
        log_error "Missing diagnostic scripts: ${missing_scripts[*]}"
        log_error "Please ensure all scripts are in: ${SCRIPT_DIR}"
        return 1
    fi

    log_success "All diagnostic scripts found"
}

run_diagnostic_script() {
    local script_name="$1"
    local script_path="${SCRIPT_DIR}/${script_name}"

    log_section "Running: ${script_name}"

    if [[ ! -x "$script_path" ]]; then
        chmod +x "$script_path"
    fi

    if bash "$script_path" >> "${MAIN_LOG}" 2>&1; then
        log_success "✓ ${script_name} completed successfully"
    else
        log_error "✗ ${script_name} failed with exit code $?"
    fi

    echo "" | tee -a "${MAIN_LOG}"
}

capture_system_snapshot() {
    print_header "System Snapshot"

    log_info "Capturing system state..."

    # System info
    echo "  Hostname: $(hostname)" | tee -a "${MAIN_LOG}"
    echo "  Date/Time: $(date '+%Y-%m-%d %H:%M:%S %Z')" | tee -a "${MAIN_LOG}"
    echo "  Uptime: $(uptime -p 2>/dev/null || uptime)" | tee -a "${MAIN_LOG}"

    # Load average
    echo "  Load Average: $(uptime | awk -F'load average:' '{print $2}')" | tee -a "${MAIN_LOG}"

    # CPU
    local cpu_cores=$(grep -c processor /proc/cpuinfo)
    echo "  CPU Cores: ${cpu_cores}" | tee -a "${MAIN_LOG}"

    # Memory
    echo "  Memory:" | tee -a "${MAIN_LOG}"
    free -h | tee -a "${MAIN_LOG}"

    # Disk
    echo "  Disk Usage:" | tee -a "${MAIN_LOG}"
    df -h | grep -v "tmpfs\|devtmpfs" | tee -a "${MAIN_LOG}"

    # Top processes by CPU
    echo "" | tee -a "${MAIN_LOG}"
    echo "  Top 10 Processes by CPU:" | tee -a "${MAIN_LOG}"
    ps aux --sort=-%cpu | head -11 | tee -a "${MAIN_LOG}"

    # Top processes by Memory
    echo "" | tee -a "${MAIN_LOG}"
    echo "  Top 10 Processes by Memory:" | tee -a "${MAIN_LOG}"
    ps aux --sort=-%mem | head -11 | tee -a "${MAIN_LOG}"
}

check_active_services() {
    print_header "Active Services Check"

    log_info "Checking critical services..."

    local services=("nginx" "mysql" "php-fpm" "cron")

    for service in "${services[@]}"; do
        if pgrep -f "$service" > /dev/null; then
            local count=$(pgrep -f "$service" | wc -l)
            log_success "✓ ${service}: ${count} processes"
        else
            log_warning "✗ ${service}: NOT RUNNING"
        fi
    done
}

run_all_diagnostics() {
    print_header "Running Diagnostic Suite"

    log_info "Executing all diagnostic scripts..."
    echo "" | tee -a "${MAIN_LOG}"

    # Run each diagnostic script
    run_diagnostic_script "check-cron-jobs.sh"
    run_diagnostic_script "detect-mysql-backups.sh"
    run_diagnostic_script "monitor-php-fpm.sh"
    run_diagnostic_script "analyze-nginx-connections.sh"

    # Run resource logger for 10 minutes during peak
    log_section "Starting 10-minute resource monitoring..."
    SAMPLE_COUNT=60 SAMPLE_INTERVAL=10 run_diagnostic_script "log-resource-usage.sh"
}

analyze_findings() {
    print_header "Analysis Summary"

    log_info "Analyzing diagnostic results..."

    # Search for critical findings in the log
    local critical_count=$(grep -c "CRITICAL\|ERROR" "${MAIN_LOG}" || echo 0)
    local warning_count=$(grep -c "WARNING" "${MAIN_LOG}" || echo 0)

    echo "" | tee -a "${MAIN_LOG}"
    echo "  Issue Summary:" | tee -a "${MAIN_LOG}"
    echo "    Critical/Errors: ${critical_count}" | tee -a "${MAIN_LOG}"
    echo "    Warnings: ${warning_count}" | tee -a "${MAIN_LOG}"

    if [[ $critical_count -gt 0 ]]; then
        echo "" | tee -a "${MAIN_LOG}"
        log_error "Critical issues detected! Review log for details."
        echo "" | tee -a "${MAIN_LOG}"
        echo "  Critical Issues Found:" | tee -a "${MAIN_LOG}"
        grep "CRITICAL\|ERROR" "${MAIN_LOG}" | tail -20 | sed 's/^/    /' | tee -a "${MAIN_LOG}"
    fi

    # Look for specific patterns
    echo "" | tee -a "${MAIN_LOG}"
    echo "  Pattern Analysis:" | tee -a "${MAIN_LOG}"

    if grep -q "BACKUP RUNNING DURING MORNING PEAK" "${MAIN_LOG}"; then
        log_error "  ⚠️  MySQL backups detected during peak hours!"
    else
        log_success "  ✓  No backup conflicts during peak hours"
    fi

    if grep -q "HIGH CPU USAGE DETECTED" "${MAIN_LOG}"; then
        log_warning "  ⚠️  High CPU usage detected"
    fi

    if grep -q "HIGH MEMORY USAGE DETECTED" "${MAIN_LOG}"; then
        log_warning "  ⚠️  High memory usage detected"
    fi

    if grep -q "HIGH CONNECTION COUNT" "${MAIN_LOG}"; then
        log_warning "  ⚠️  High connection count detected"
    fi
}

generate_report() {
    print_header "Final Report"

    local report_file="${LOG_DIR}/morning-monitor-report-${TIMESTAMP}.txt"

    cat > "$report_file" << EOF
Morning Peak Monitoring Report
Generated: $(date '+%Y-%m-%d %H:%M:%S')
Log File: ${MAIN_LOG}

EXECUTIVE SUMMARY
=================
$(if check_time_window &>/dev/null; then echo "✓ Monitoring performed during peak window (9-10am)"; else echo "⚠ Monitoring performed outside peak window"; fi)

Critical Issues: $(grep -c "CRITICAL\|ERROR" "${MAIN_LOG}" || echo 0)
Warnings: $(grep -c "WARNING" "${MAIN_LOG}" || echo 0)

KEY FINDINGS
============
Cron Jobs:
$(grep -A 5 "Jobs potentially running 9-10am" "${MAIN_LOG}" || echo "  No analysis available")

MySQL Backups:
$(grep -A 3 "Active mysqldump processes" "${MAIN_LOG}" || echo "  No active backups detected")

PHP-FPM:
$(grep -A 5 "Resource Summary" "${MAIN_LOG}" | grep -A 3 "php-fpm" || echo "  No PHP-FPM data available")

Nginx Connections:
$(grep -A 5 "Connection states" "${MAIN_LOG}" || echo "  No connection data available")

Resource Usage:
$(grep -A 5 "Peak Statistics" "${MAIN_LOG}" || echo "  No resource data available")

RECOMMENDATIONS
===============
1. Review and reschedule any cron jobs running between 9-10am
2. Move MySQL backup jobs to off-peak hours (2-4am recommended)
3. Monitor PHP-FPM pool configuration for adequate capacity
4. Check nginx worker configuration if connection limits reached
5. Implement resource usage alerts for proactive monitoring

DETAILED LOGS
=============
Full diagnostic log: ${MAIN_LOG}
Resource usage CSV: ${LOG_DIR}/resource-usage-${TIMESTAMP}.csv

For detailed analysis, review the main log file.
EOF

    log_success "Report generated: ${report_file}"

    # Display report
    cat "$report_file" | tee -a "${MAIN_LOG}"
}

cleanup() {
    log_info "Cleaning up temporary files..."

    # Compress old logs (older than 7 days)
    find "${LOG_DIR}" -name "*.log" -type f -mtime +7 -exec gzip {} \; 2>/dev/null || true

    log_success "Cleanup completed"
}

################################################################################
# Main Execution
################################################################################

main() {
    print_banner

    log_info "Starting Morning Peak Monitor (${SCRIPT_NAME})"
    echo "" | tee -a "${MAIN_LOG}"

    # Check time window (warning only)
    check_time_window || true

    echo "" | tee -a "${MAIN_LOG}"

    # Check requirements
    check_requirements || exit 1

    # Capture initial snapshot
    capture_system_snapshot

    # Check services
    check_active_services

    # Run all diagnostics
    run_all_diagnostics

    # Analyze results
    analyze_findings

    # Generate report
    generate_report

    # Cleanup
    cleanup

    echo "" | tee -a "${MAIN_LOG}"
    log_success "Morning Peak Monitor completed successfully!"
    log_info "Review logs at: ${LOG_DIR}"

    exit 0
}

# Run main function
main "$@"

################################################################################
# USAGE EXAMPLES
################################################################################
# Basic usage:
#   sudo ./morning-monitor.sh
#
# Schedule to run at 9am daily:
#   0 9 * * * /path/to/morning-monitor.sh
#
# Run with email notification:
#   0 9 * * * /path/to/morning-monitor.sh && \
#     mail -s "Morning Monitor Report" admin@example.com < \
#     /var/log/diagnostics/morning-monitor-report-*.txt
#
# Run in background:
#   nohup ./morning-monitor.sh > /dev/null 2>&1 &
################################################################################
