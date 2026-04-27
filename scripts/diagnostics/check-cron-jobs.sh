#!/bin/bash
################################################################################
# Cron Job Analyzer Script
# Purpose: Analyze cron jobs and detect jobs running during specified time window
# Author: Hive Mind Coder Agent
# Version: 1.0.0
################################################################################

set -euo pipefail

# Configuration
readonly SCRIPT_NAME="$(basename "$0")"
readonly LOG_DIR="/var/log/diagnostics"
readonly TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
readonly LOG_FILE="${LOG_DIR}/cron-analysis-${TIMESTAMP}.log"
readonly TIME_WINDOW_START="09:00"
readonly TIME_WINDOW_END="10:00"

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

################################################################################
# Functions
################################################################################

log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    echo "[${timestamp}] [${level}] ${message}" | tee -a "${LOG_FILE}"
}

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

    if [[ $EUID -ne 0 ]]; then
        log_warning "This script should be run as root for complete cron job visibility"
    fi

    if ! command -v crontab &> /dev/null; then
        log_error "crontab command not found"
        return 1
    fi

    if [[ ! -d "${LOG_DIR}" ]]; then
        mkdir -p "${LOG_DIR}"
        log_info "Created log directory: ${LOG_DIR}"
    fi

    log_success "Requirements check completed"
}

analyze_user_crontabs() {
    print_header "User Crontab Analysis"

    local users=()
    if [[ $EUID -eq 0 ]]; then
        # Running as root - check all users
        users=($(cut -f1 -d: /etc/passwd))
    else
        # Running as regular user - check only current user
        users=("$(whoami)")
    fi

    local total_jobs=0
    local morning_jobs=0

    for user in "${users[@]}"; do
        local crontab_content
        if crontab_content=$(crontab -u "$user" -l 2>/dev/null); then
            log_info "Analyzing crontab for user: ${user}"

            # Count non-comment, non-empty lines
            local job_count=$(echo "$crontab_content" | grep -v '^#' | grep -v '^$' | wc -l)

            if [[ $job_count -gt 0 ]]; then
                echo "  User: ${user}" | tee -a "${LOG_FILE}"
                echo "  Jobs: ${job_count}" | tee -a "${LOG_FILE}"
                echo "" | tee -a "${LOG_FILE}"

                # Analyze each job
                while IFS= read -r line; do
                    # Skip comments and empty lines
                    [[ "$line" =~ ^#.*$ ]] && continue
                    [[ -z "$line" ]] && continue

                    ((total_jobs++))

                    echo "    ${line}" | tee -a "${LOG_FILE}"

                    # Check if job runs during morning window (9-10am)
                    local hour_field=$(echo "$line" | awk '{print $2}')
                    if [[ "$hour_field" == "9" ]] || [[ "$hour_field" == "09" ]] || [[ "$hour_field" == "*/1" ]] || [[ "$hour_field" == "*" ]]; then
                        ((morning_jobs++))
                        log_warning "    ⚠️  This job may run during 9-10am window"
                    fi
                done <<< "$crontab_content"

                echo "" | tee -a "${LOG_FILE}"
            fi
        fi
    done

    log_info "Total cron jobs found: ${total_jobs}"
    log_info "Jobs potentially running 9-10am: ${morning_jobs}"
}

analyze_system_crontabs() {
    print_header "System Crontab Analysis"

    local system_cron_dirs=(
        "/etc/crontab"
        "/etc/cron.d"
        "/etc/cron.hourly"
        "/etc/cron.daily"
        "/etc/cron.weekly"
        "/etc/cron.monthly"
    )

    for cron_path in "${system_cron_dirs[@]}"; do
        if [[ -e "$cron_path" ]]; then
            log_info "Analyzing: ${cron_path}"

            if [[ -f "$cron_path" ]]; then
                # Single file
                local job_count=$(grep -v '^#' "$cron_path" | grep -v '^$' | wc -l)
                echo "  Jobs: ${job_count}" | tee -a "${LOG_FILE}"

                if [[ $job_count -gt 0 ]]; then
                    grep -v '^#' "$cron_path" | grep -v '^$' | while IFS= read -r line; do
                        echo "    ${line}" | tee -a "${LOG_FILE}"
                    done
                fi
            elif [[ -d "$cron_path" ]]; then
                # Directory
                local file_count=$(find "$cron_path" -type f | wc -l)
                echo "  Files: ${file_count}" | tee -a "${LOG_FILE}"

                find "$cron_path" -type f | while IFS= read -r file; do
                    echo "    File: $(basename "$file")" | tee -a "${LOG_FILE}"

                    # Show schedule for cron.d files
                    if [[ "$cron_path" == "/etc/cron.d" ]]; then
                        grep -v '^#' "$file" | grep -v '^$' | while IFS= read -r line; do
                            echo "      ${line}" | tee -a "${LOG_FILE}"
                        done
                    fi
                done
            fi
            echo "" | tee -a "${LOG_FILE}"
        fi
    done
}

analyze_running_cron_processes() {
    print_header "Running Cron Processes"

    log_info "Current cron daemon processes:"
    ps aux | grep -i cron | grep -v grep | tee -a "${LOG_FILE}"

    echo "" | tee -a "${LOG_FILE}"

    if command -v systemctl &> /dev/null; then
        log_info "Cron service status:"
        systemctl status cron 2>/dev/null || systemctl status crond 2>/dev/null || log_warning "Could not get cron service status"
    fi
}

check_cron_logs() {
    print_header "Recent Cron Activity"

    local cron_log_paths=(
        "/var/log/cron"
        "/var/log/cron.log"
        "/var/log/syslog"
    )

    for log_path in "${cron_log_paths[@]}"; do
        if [[ -f "$log_path" ]]; then
            log_info "Checking ${log_path} for morning activity (9-10am)..."

            # Get today's date in log format
            local today=$(date '+%b %d')

            # Search for 9am hour entries
            if grep -i "cron" "$log_path" | grep "$today 09:" | tail -20; then
                echo "" | tee -a "${LOG_FILE}"
            fi >> "${LOG_FILE}" 2>&1

            break
        fi
    done
}

generate_summary() {
    print_header "Summary Report"

    log_info "Analysis completed at: $(date '+%Y-%m-%d %H:%M:%S')"
    log_info "Log file saved to: ${LOG_FILE}"

    echo "" | tee -a "${LOG_FILE}"
    log_success "Cron job analysis complete!"

    cat << EOF | tee -a "${LOG_FILE}"

RECOMMENDATIONS:
1. Review jobs scheduled between 9-10am for high resource usage
2. Check /var/log/cron for execution history during peak times
3. Consider spreading resource-intensive jobs throughout the day
4. Monitor backup jobs that may coincide with business hours

NEXT STEPS:
- Run: detect-mysql-backups.sh to check for database backup jobs
- Run: monitor-php-fpm.sh to analyze PHP processing during peak times
- Run: log-resource-usage.sh to track actual resource consumption
EOF
}

################################################################################
# Main Execution
################################################################################

main() {
    log_info "Starting Cron Job Analyzer (${SCRIPT_NAME})"
    log_info "Target time window: ${TIME_WINDOW_START} - ${TIME_WINDOW_END}"

    check_requirements || exit 1

    analyze_user_crontabs
    analyze_system_crontabs
    analyze_running_cron_processes
    check_cron_logs
    generate_summary

    exit 0
}

# Run main function
main "$@"

################################################################################
# USAGE EXAMPLES
################################################################################
# Basic usage:
#   sudo ./check-cron-jobs.sh
#
# Run as regular user (limited visibility):
#   ./check-cron-jobs.sh
#
# Schedule to run daily at 10am:
#   echo "0 10 * * * /path/to/check-cron-jobs.sh" | crontab -
#
# Run and save output:
#   ./check-cron-jobs.sh > cron-analysis.txt 2>&1
################################################################################
