#!/bin/bash

################################################################################
# N8N Log Aggregation and Analysis Script
# Purpose: Centralized log collection, parsing, and reporting
# Features: Multi-source aggregation, error detection, trend analysis
# Compatible: Proxmox LXC, Docker, Docker Compose
# Author: Hive Mind Coder Agent
################################################################################

set -euo pipefail

# Configuration
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly LOG_DIR="/var/log/n8n-monitoring"
readonly AGGREGATED_LOG="${LOG_DIR}/aggregated.log"
readonly REPORT_DIR="${LOG_DIR}/reports"
readonly CONTAINER_NAME="${N8N_CONTAINER_NAME:-n8n}"

# Analysis configuration
readonly ERROR_PATTERNS="error|exception|fatal|panic|critical|emergency"
readonly WARNING_PATTERNS="warning|warn|deprecated"
readonly PERFORMANCE_PATTERNS="slow|timeout|delay|latency"

# Report settings
readonly REPORT_LINES="${N8N_REPORT_LINES:-5000}"
readonly KEEP_REPORTS_DAYS="${N8N_REPORT_RETENTION:-14}"

# Color codes
readonly RED='\033[0;31m'
readonly YELLOW='\033[1;33m'
readonly GREEN='\033[0;32m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly MAGENTA='\033[0;35m'
readonly NC='\033[0m'

################################################################################
# Utility Functions
################################################################################

print_header() {
    local title="$1"
    echo
    echo -e "${BLUE}╔══════════════════════════════════════════════════════════╗${NC}"
    printf "${BLUE}║%-58s║${NC}\n" "  ${title}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════════╝${NC}"
    echo
}

print_section() {
    echo -e "${CYAN}▶ ${1}${NC}"
}

log_message() {
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[${timestamp}] [AGGREGATOR] $*" | tee -a "${AGGREGATED_LOG}"
}

################################################################################
# Log Collection
################################################################################

detect_container() {
    local container_id

    container_id=$(docker ps -aq --filter "name=^${CONTAINER_NAME}$" 2>/dev/null | head -1)

    if [[ -z "${container_id}" ]]; then
        container_id=$(docker ps -aq --filter "name=${CONTAINER_NAME}" 2>/dev/null | head -1)
    fi

    if [[ -z "${container_id}" ]]; then
        container_id=$(docker ps -aq --filter "ancestor=n8nio/n8n" 2>/dev/null | head -1)
    fi

    echo "${container_id}"
}

collect_container_logs() {
    local container_id="$1"
    local output_file="$2"
    local lines="${3:-${REPORT_LINES}}"

    print_section "Collecting container logs (${lines} lines)"

    if docker logs --tail "${lines}" --timestamps "${container_id}" >> "${output_file}" 2>&1; then
        local line_count
        line_count=$(grep -c "^" "${output_file}" 2>/dev/null || echo "0")
        echo -e "${GREEN}✓${NC} Collected ${line_count} lines from container"
    else
        echo -e "${RED}✗${NC} Failed to collect container logs"
        return 1
    fi
}

collect_health_logs() {
    local output_file="$1"
    local health_log="${LOG_DIR}/health_check.log"

    if [[ -f "${health_log}" ]]; then
        print_section "Collecting health check logs"

        tail -500 "${health_log}" >> "${output_file}"
        echo -e "${GREEN}✓${NC} Health check logs collected"
    fi
}

collect_recovery_logs() {
    local output_file="$1"
    local recovery_log="${LOG_DIR}/auto_recovery.log"

    if [[ -f "${recovery_log}" ]]; then
        print_section "Collecting recovery logs"

        tail -500 "${recovery_log}" >> "${output_file}"
        echo -e "${GREEN}✓${NC} Recovery logs collected"
    fi
}

collect_incident_logs() {
    local output_file="$1"
    local incident_log="${LOG_DIR}/incidents.log"

    if [[ -f "${incident_log}" ]]; then
        print_section "Collecting incident logs"

        tail -200 "${incident_log}" >> "${output_file}"
        echo -e "${GREEN}✓${NC} Incident logs collected"
    fi
}

################################################################################
# Log Analysis
################################################################################

analyze_error_frequency() {
    local log_file="$1"
    local report_file="$2"

    {
        echo "═══════════════════════════════════════════════════════════"
        echo "  ERROR FREQUENCY ANALYSIS"
        echo "═══════════════════════════════════════════════════════════"
        echo

        local total_errors
        total_errors=$(grep -ciE "${ERROR_PATTERNS}" "${log_file}" 2>/dev/null || echo "0")

        echo "Total Errors: ${total_errors}"
        echo

        if [[ ${total_errors} -gt 0 ]]; then
            echo "Top Error Types:"
            grep -iE "${ERROR_PATTERNS}" "${log_file}" 2>/dev/null | \
                grep -oE "error|exception|fatal|panic|critical" | \
                tr '[:upper:]' '[:lower:]' | \
                sort | uniq -c | sort -rn | head -10 | \
                awk '{printf "  %5d  %s\n", $1, $2}'
            echo

            echo "Recent Errors (last 10):"
            grep -iE "${ERROR_PATTERNS}" "${log_file}" 2>/dev/null | tail -10 | \
                sed 's/^/  /'
            echo
        else
            echo "✓ No errors detected"
            echo
        fi

    } >> "${report_file}"
}

analyze_warning_frequency() {
    local log_file="$1"
    local report_file="$2"

    {
        echo "═══════════════════════════════════════════════════════════"
        echo "  WARNING FREQUENCY ANALYSIS"
        echo "═══════════════════════════════════════════════════════════"
        echo

        local total_warnings
        total_warnings=$(grep -ciE "${WARNING_PATTERNS}" "${log_file}" 2>/dev/null || echo "0")

        echo "Total Warnings: ${total_warnings}"
        echo

        if [[ ${total_warnings} -gt 0 ]]; then
            echo "Warning Distribution:"
            grep -iE "${WARNING_PATTERNS}" "${log_file}" 2>/dev/null | \
                grep -oE "warning|warn|deprecated" | \
                tr '[:upper:]' '[:lower:]' | \
                sort | uniq -c | sort -rn | \
                awk '{printf "  %5d  %s\n", $1, $2}'
            echo
        else
            echo "✓ No warnings detected"
            echo
        fi

    } >> "${report_file}"
}

analyze_performance_issues() {
    local log_file="$1"
    local report_file="$2"

    {
        echo "═══════════════════════════════════════════════════════════"
        echo "  PERFORMANCE ISSUE ANALYSIS"
        echo "═══════════════════════════════════════════════════════════"
        echo

        local perf_issues
        perf_issues=$(grep -ciE "${PERFORMANCE_PATTERNS}" "${log_file}" 2>/dev/null || echo "0")

        echo "Performance Issues Detected: ${perf_issues}"
        echo

        if [[ ${perf_issues} -gt 0 ]]; then
            echo "Issue Types:"
            grep -iE "${PERFORMANCE_PATTERNS}" "${log_file}" 2>/dev/null | \
                grep -oE "slow|timeout|delay|latency" | \
                tr '[:upper:]' '[:lower:]' | \
                sort | uniq -c | sort -rn | \
                awk '{printf "  %5d  %s\n", $1, $2}'
            echo

            echo "Recent Performance Issues (last 5):"
            grep -iE "${PERFORMANCE_PATTERNS}" "${log_file}" 2>/dev/null | tail -5 | \
                sed 's/^/  /'
            echo
        else
            echo "✓ No performance issues detected"
            echo
        fi

    } >> "${report_file}"
}

analyze_restart_events() {
    local log_file="$1"
    local report_file="$2"

    {
        echo "═══════════════════════════════════════════════════════════"
        echo "  RESTART EVENT ANALYSIS"
        echo "═══════════════════════════════════════════════════════════"
        echo

        # Look for restart indicators
        local restart_count=0
        restart_count=$(grep -c "Container start\|Starting n8n\|Restart attempt" "${log_file}" 2>/dev/null || echo "0")

        echo "Restart Events: ${restart_count}"
        echo

        if [[ ${restart_count} -gt 0 ]]; then
            echo "Recent Restart Events:"
            grep "Container start\|Starting n8n\|Restart attempt" "${log_file}" 2>/dev/null | tail -10 | \
                sed 's/^/  /'
            echo
        else
            echo "✓ No restart events in collected logs"
            echo
        fi

    } >> "${report_file}"
}

analyze_incident_patterns() {
    local log_file="$1"
    local report_file="$2"

    {
        echo "═══════════════════════════════════════════════════════════"
        echo "  INCIDENT PATTERN ANALYSIS"
        echo "═══════════════════════════════════════════════════════════"
        echo

        local incident_log="${LOG_DIR}/incidents.log"

        if [[ -f "${incident_log}" ]]; then
            local total_incidents
            total_incidents=$(wc -l < "${incident_log}" 2>/dev/null || echo "0")

            echo "Total Incidents Recorded: ${total_incidents}"
            echo

            if [[ ${total_incidents} -gt 0 ]]; then
                echo "Incident Type Distribution:"
                awk -F'|' '{print $2}' "${incident_log}" 2>/dev/null | \
                    sort | uniq -c | sort -rn | \
                    awk '{printf "  %5d  %s\n", $1, $2}'
                echo

                echo "Recent Incidents (last 10):"
                tail -10 "${incident_log}" | \
                    awk -F'|' '{printf "  %s  %-20s  %s\n", $1, $2, $3}'
                echo
            fi
        else
            echo "No incident log found"
            echo
        fi

    } >> "${report_file}"
}

analyze_time_distribution() {
    local log_file="$1"
    local report_file="$2"

    {
        echo "═══════════════════════════════════════════════════════════"
        echo "  TIME DISTRIBUTION ANALYSIS"
        echo "═══════════════════════════════════════════════════════════"
        echo

        echo "Error Distribution by Hour (last 24h):"

        # Extract timestamps and count errors per hour
        grep -iE "${ERROR_PATTERNS}" "${log_file}" 2>/dev/null | \
            grep -oE "[0-9]{4}-[0-9]{2}-[0-9]{2}[T ][0-9]{2}:" | \
            cut -d':' -f1 | \
            sort | uniq -c | sort -k2 | tail -24 | \
            awk '{printf "  %s  ", $2; for(i=0;i<$1;i++) printf "█"; printf " (%d)\n", $1}' || \
            echo "  No time data available"

        echo

    } >> "${report_file}"
}

generate_summary() {
    local log_file="$1"
    local report_file="$2"

    {
        echo "═══════════════════════════════════════════════════════════"
        echo "  LOG SUMMARY"
        echo "═══════════════════════════════════════════════════════════"
        echo

        local total_lines
        total_lines=$(wc -l < "${log_file}" 2>/dev/null || echo "0")

        local error_count
        error_count=$(grep -ciE "${ERROR_PATTERNS}" "${log_file}" 2>/dev/null || echo "0")

        local warning_count
        warning_count=$(grep -ciE "${WARNING_PATTERNS}" "${log_file}" 2>/dev/null || echo "0")

        local perf_count
        perf_count=$(grep -ciE "${PERFORMANCE_PATTERNS}" "${log_file}" 2>/dev/null || echo "0")

        echo "Total Log Lines: ${total_lines}"
        echo "Errors: ${error_count}"
        echo "Warnings: ${warning_count}"
        echo "Performance Issues: ${perf_count}"
        echo

        # Health score calculation
        local health_score=100

        if [[ ${error_count} -gt 0 ]]; then
            ((health_score -= error_count > 50 ? 50 : error_count))
        fi

        if [[ ${warning_count} -gt 0 ]]; then
            ((health_score -= warning_count > 20 ? 20 : warning_count / 2))
        fi

        if [[ ${perf_count} -gt 0 ]]; then
            ((health_score -= perf_count > 20 ? 20 : perf_count))
        fi

        [[ ${health_score} -lt 0 ]] && health_score=0

        echo -n "Overall Health Score: ${health_score}/100 "

        if [[ ${health_score} -ge 80 ]]; then
            echo "(GOOD)"
        elif [[ ${health_score} -ge 60 ]]; then
            echo "(FAIR)"
        elif [[ ${health_score} -ge 40 ]]; then
            echo "(POOR)"
        else
            echo "(CRITICAL)"
        fi

        echo

    } >> "${report_file}"
}

################################################################################
# Report Generation
################################################################################

generate_report() {
    local log_file="$1"
    local timestamp
    timestamp=$(date +%Y%m%d_%H%M%S)
    local report_file="${REPORT_DIR}/report_${timestamp}.txt"

    mkdir -p "${REPORT_DIR}"

    print_header "Log Analysis Report"

    {
        echo "╔══════════════════════════════════════════════════════════╗"
        echo "║         N8N LOG ANALYSIS REPORT                          ║"
        echo "╚══════════════════════════════════════════════════════════╝"
        echo
        echo "Generated: $(date -Iseconds)"
        echo "Log File: ${log_file}"
        echo
    } > "${report_file}"

    print_section "Analyzing log patterns..."

    generate_summary "${log_file}" "${report_file}"
    analyze_error_frequency "${log_file}" "${report_file}"
    analyze_warning_frequency "${log_file}" "${report_file}"
    analyze_performance_issues "${log_file}" "${report_file}"
    analyze_restart_events "${log_file}" "${report_file}"
    analyze_incident_patterns "${log_file}" "${report_file}"
    analyze_time_distribution "${log_file}" "${report_file}"

    {
        echo "═══════════════════════════════════════════════════════════"
        echo "  END OF REPORT"
        echo "═══════════════════════════════════════════════════════════"
    } >> "${report_file}"

    echo -e "${GREEN}✓${NC} Report generated: ${report_file}"
    echo

    # Display summary
    print_section "Report Summary"
    grep -A 15 "LOG SUMMARY" "${report_file}" | sed 's/^/  /'
    echo

    echo "${report_file}"
}

cleanup_old_reports() {
    print_section "Cleaning up old reports"

    local deleted_count=0

    while IFS= read -r old_report; do
        rm -f "${old_report}"
        ((deleted_count++))
    done < <(find "${REPORT_DIR}" -type f -name "report_*.txt" -mtime "+${KEEP_REPORTS_DAYS}" 2>/dev/null)

    if [[ ${deleted_count} -gt 0 ]]; then
        echo -e "${GREEN}✓${NC} Cleaned up ${deleted_count} old report(s)"
    else
        echo -e "${BLUE}ℹ${NC} No old reports to clean up"
    fi
}

################################################################################
# Main Execution
################################################################################

main() {
    local timestamp
    timestamp=$(date +%Y%m%d_%H%M%S)
    local temp_log="${LOG_DIR}/temp_aggregate_${timestamp}.log"

    mkdir -p "${LOG_DIR}" "${REPORT_DIR}"

    print_header "N8N Log Aggregation & Analysis"

    # Parse command line options
    local quick_mode=false
    local report_only=false

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --quick)
                quick_mode=true
                REPORT_LINES=1000
                shift
                ;;
            --report-only)
                report_only=true
                shift
                ;;
            --help|-h)
                echo "N8N Log Aggregation Tool"
                echo
                echo "Usage: $0 [OPTIONS]"
                echo
                echo "Options:"
                echo "  --quick           Quick analysis (1000 lines)"
                echo "  --report-only     Generate report from existing aggregated log"
                echo "  --help, -h        Show this help message"
                exit 0
                ;;
            *)
                echo "Unknown option: $1"
                exit 1
                ;;
        esac
    done

    # If report-only, use existing aggregated log
    if [[ "${report_only}" == "true" ]]; then
        if [[ -f "${AGGREGATED_LOG}" ]]; then
            generate_report "${AGGREGATED_LOG}"
        else
            echo -e "${RED}✗${NC} No aggregated log found at: ${AGGREGATED_LOG}"
            exit 1
        fi
        exit 0
    fi

    # Detect container
    local container_id
    container_id=$(detect_container)

    if [[ -z "${container_id}" ]]; then
        echo -e "${RED}✗${NC} N8N container not found"
        exit 1
    fi

    echo -e "${GREEN}✓${NC} Container found: ${container_id:0:12}"
    echo

    # Collect logs
    print_header "Log Collection"

    : > "${temp_log}"  # Create empty file

    collect_container_logs "${container_id}" "${temp_log}"
    collect_health_logs "${temp_log}"
    collect_recovery_logs "${temp_log}"
    collect_incident_logs "${temp_log}"

    # Update main aggregated log
    cat "${temp_log}" >> "${AGGREGATED_LOG}"

    # Rotate aggregated log if too large (>50MB)
    if [[ -f "${AGGREGATED_LOG}" ]]; then
        local log_size
        log_size=$(stat -f%z "${AGGREGATED_LOG}" 2>/dev/null || stat -c%s "${AGGREGATED_LOG}")
        if [[ ${log_size} -gt 52428800 ]]; then
            print_section "Rotating aggregated log"
            mv "${AGGREGATED_LOG}" "${AGGREGATED_LOG}.$(date +%Y%m%d_%H%M%S)"
            gzip "${AGGREGATED_LOG}.$(date +%Y%m%d_%H%M%S)" &
            echo -e "${GREEN}✓${NC} Log rotated and compressed"
        fi
    fi

    echo

    # Generate report
    local report_path
    report_path=$(generate_report "${temp_log}")

    # Cleanup
    rm -f "${temp_log}"
    cleanup_old_reports

    echo
    print_header "Aggregation Complete"
    echo -e "${GREEN}✓${NC} Report available at: ${report_path}"
    echo
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
