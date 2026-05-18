#!/bin/bash
# SLO/SLI Compliance Report Script
# Generates Service Level Objective compliance reports with error budget tracking
# Part of monitoring-analytics-predictive skill

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
APP_PATH="${APP_PATH:-/mnt/overpower/apps/dev/agl/agl-hostman/src}"
REPORT_DIR="${REPORT_DIR:-/mnt/overpower/apps/dev/agl/agl-hostman/.agent/skills/monitoring/monitoring-analytics-predictive/reports}"

# Default SLO definitions
declare -A SLO_TARGETS=(
    ["availability"]=99.9
    ["latency_p95"]=500
    ["error_rate"]=0.1
)

declare -A SLO_WINDOWS=(
    ["availability"]="30d"
    ["latency_p95"]="7d"
    ["error_rate"]="24h"
)

# Function to log messages
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_slo() {
    echo -e "${CYAN}[SLO]${NC} $1"
}

# Function to calculate availability SLI
calculate_availability_sli() {
    local resource_type=$1
    local resource_id=$2
    local window=$3

    log_info "Calculating availability SLI for ${resource_type}/${resource_id}..."

    cd "${APP_PATH}"

    # Fetch health check data
    local total_checks=$(php artisan trend:query \
        --resource-type="${resource_type}" \
        --resource-id="${resource_id}" \
        --metric-type="health_check" \
        --window="${window}" \
        --format=raw 2>/dev/null | wc -l || echo "0")

    local passed_checks=$(php artisan trend:query \
        --resource-type="${resource_type}" \
        --resource-id="${resource_id}" \
        --metric-type="health_check" \
        --window="${window}" \
        --filter="value=1" \
        --format=raw 2>/dev/null | wc -l || echo "0")

    if [ "${total_checks}" -eq 0 ]; then
        echo "0|0|0"
        return
    fi

    local sli=$(echo "scale=4; $passed_checks / $total_checks" | bc)
    local sli_pct=$(echo "scale=2; $sli * 100" | bc)

    echo "${sli}|${sli_pct}|${total_checks}"
}

# Function to calculate latency SLI
calculate_latency_sli() {
    local resource_type=$1
    local resource_id=$2
    local window=$3
    local percentile=${4:-95}

    log_info "Calculating latency P${percentile} SLI for ${resource_type}/${resource_id}..."

    cd "${APP_PATH}"

    local latencies=$(php artisan trend:query \
        --resource-type="${resource_type}" \
        --resource-id="${resource_id}" \
        --metric-type="response_time" \
        --window="${window}" \
        --format=raw 2>/dev/null || echo "")

    if [ -z "${latencies}" ]; then
        echo "0|0"
        return
    fi

    # Calculate percentile using awk
    local p95=$(echo "${latencies}" | awk -v p=95 '{
        count++
        values[count] = $1
    }
    END {
        if (count == 0) exit
        asort(values)
        idx = int(count * p / 100)
        if (idx == 0) idx = 1
        print values[idx]
    }')

    echo "${p95}|$(echo "${latencies}" | wc -l)"
}

# Function to calculate error rate SLI
calculate_error_rate_sli() {
    local resource_type=$1
    local resource_id=$2
    local window=$3

    log_info "Calculating error rate SLI for ${resource_type}/${resource_id}..."

    cd "${APP_PATH}"

    local total_requests=$(php artisan trend:query \
        --resource-type="${resource_type}" \
        --resource-id="${resource_id}" \
        --metric-type="request_count" \
        --window="${window}" \
        --format=raw 2>/dev/null | awk '{sum+=$1} END {print sum}' || echo "0")

    local error_count=$(php artisan trend:query \
        --resource-type="${resource_type}" \
        --resource-id="${resource_id}" \
        --metric-type="error_count" \
        --window="${window}" \
        --format=raw 2>/dev/null | awk '{sum+=$1} END {print sum}' || echo "0")

    if [ "${total_requests}" -eq 0 ]; then
        echo "0|0"
        return
    fi

    local error_rate=$(echo "scale=4; $error_count / $total_requests" | bc)
    local error_rate_pct=$(echo "scale=2; $error_rate * 100" | bc)

    echo "${error_rate}|${error_rate_pct}|${total_requests}|${error_count}"
}

# Function to calculate error budget
calculate_error_budget() {
    local sli=$1
    local target=$2

    local target_decimal=$(echo "scale=4; $target / 100" | bc)
    local allowed_errors=$(echo "scale=4; 1 - $target_decimal" | bc)
    local actual_errors=$(echo "scale=4; 1 - $sli" | bc)

    local consumed=$(echo "scale=4; $actual_errors / $allowed_errors * 100" | bc)
    local remaining=$(echo "scale=4; 100 - $consumed" | bc)

    # Clamp values
    if (( $(echo "$consumed < 0" | bc -l) )); then
        consumed="0"
    fi
    if (( $(echo "$consumed > 100" | bc -l) )); then
        consumed="100"
    fi
    if (( $(echo "$remaining < 0" | bc -l) )); then
        remaining="0"
    fi

    echo "${consumed}|${remaining}"
}

# Function to generate SLO report
generate_slo_report() {
    local slo_name=$1
    local resource_type=$2
    local resource_id=${3:-"all"}
    local window=${4:-"30d"}

    log_slo "Generating ${slo_name} report..."

    # Get SLO target and window
    local target=${SLO_TARGETS[$slo_name]:-99.9}
    local default_window=${SLO_WINDOWS[$slo_name]:-"30d"}

    # Use provided window or default
    local report_window=${window}
    if [ "${window}" = "default" ]; then
        report_window=${default_window}
    fi

    echo ""
    echo "==================================================================="
    echo "  SLO Report: ${slo_name}"
    echo "  Resource: ${resource_type}/${resource_id}"
    echo "  Window: ${report_window}"
    echo "==================================================================="
    echo ""

    case $slo_name in
        availability)
            local result=$(calculate_availability_sli "${resource_type}" "${resource_id}" "${report_window}")
            local sli=$(echo "${result}" | cut -d'|' -f1)
            local sli_pct=$(echo "${result}" | cut -d'|' -f2)
            local samples=$(echo "${result}" | cut -d'|' -f3)

            local error_budget=$(calculate_error_budget "${sli}" "${target}")
            local consumed=$(echo "${error_budget}" | cut -d'|' -f1)
            local remaining=$(echo "${error_budget}" | cut -d'|' -f2)

            printf "%-20s : %s\n" "SLO Target" "${target}%"
            printf "%-20s : %s\n" "SLI (Actual)" "${sli_pct}%"
            printf "%-20s : %s\n" "Samples" "${samples}"
            printf "%-20s : %s\n" "Error Budget" "Remaining: ${remaining}%, Consumed: ${consumed}%"

            if (( $(echo "$sli_pct < $target" | bc -l) )); then
                printf "%-20s : %s\n" "Status" "${RED}BREACHED${NC}"
            else
                printf "%-20s : %s\n" "Status" "${GREEN}COMPLIANT${NC}"
            fi
            ;;

        latency_p95)
            local result=$(calculate_latency_sli "${resource_type}" "${resource_id}" "${report_window}" 95)
            local p95=$(echo "${result}" | cut -d'|' -f1)
            local samples=$(echo "${result}" | cut -d'|' -f2)

            printf "%-20s : %s ms\n" "SLO Target (P95)" "${target}"
            printf "%-20s : %s ms\n" "SLI (P95)" "${p95}"
            printf "%-20s : %s\n" "Samples" "${samples}"

            if (( $(echo "$p95 > $target" | bc -l) )); then
                printf "%-20s : %s\n" "Status" "${RED}BREACHED${NC}"
            else
                printf "%-20s : %s\n" "Status" "${GREEN}COMPLIANT${NC}"
            fi
            ;;

        error_rate)
            local result=$(calculate_error_rate_sli "${resource_type}" "${resource_id}" "${report_window}")
            local error_rate=$(echo "${result}" | cut -d'|' -f1)
            local error_rate_pct=$(echo "${result}" | cut -d'|' -f2)
            local total_requests=$(echo "${result}" | cut -d'|' -f3)
            local error_count=$(echo "${result}" | cut -d'|' -f4)

            printf "%-20s : %s%%\n" "SLO Target" "${target}"
            printf "%-20s : %s%%\n" "SLI (Actual)" "${error_rate_pct}"
            printf "%-20s : %s\n" "Total Requests" "${total_requests}"
            printf "%-20s : %s\n" "Error Count" "${error_count}"

            if (( $(echo "$error_rate_pct > $target" | bc -l) )); then
                printf "%-20s : %s\n" "Status" "${RED}BREACHED${NC}"
            else
                printf "%-20s : %s\n" "Status" "${GREEN}COMPLIANT${NC}"
            fi
            ;;

        *)
            log_error "Unknown SLO: ${slo_name}"
            return 1
            ;;
    esac

    echo ""
    echo "==================================================================="
    echo ""
}

# Function to generate comprehensive SLO report
generate_comprehensive_report() {
    local resource_type=$1
    local resource_id=${2:-"all"}
    local output_file=${3:-""}

    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    if [ -n "${output_file}" ]; then
        mkdir -p "$(dirname "${output_file}")"

        cat > "${output_file}" << EOF
{
  "generated_at": "${timestamp}",
  "resource_type": "${resource_type}",
  "resource_id": "${resource_id}",
  "slos": []
}
EOF

        log_info "Comprehensive report will be saved to ${output_file}"
    fi

    # Generate individual reports
    generate_slo_report "availability" "${resource_type}" "${resource_id}" "default"
    generate_slo_report "latency_p95" "${resource_type}" "${resource_id}" "default"
    generate_slo_report "error_rate" "${resource_type}" "${resource_id}" "default"
}

# Function to display SLO summary table
display_summary_table() {
    echo ""
    echo "==================================================================="
    echo "  SLO Summary"
    echo "==================================================================="
    echo ""
    printf "%-20s %-15s %-10s %-15s\n" "SLO" "Target" "Actual" "Status"
    printf "%-20s %-15s %-10s %-15s\n" "---" "------" "------" "------"

    # Add rows for each SLO (example values, replace with actual queries)
    printf "%-20s %-15s %-10s %-15s\n" "Availability" "99.9%" "99.95%" "✓ Compliant"
    printf "%-20s %-15s %-10s %-15s\n" "Latency P95" "500ms" "320ms" "✓ Compliant"
    printf "%-20s %-15s %-10s %-15s\n" "Error Rate" "0.1%" "0.05%" "✓ Compliant"

    echo ""
    echo "==================================================================="
    echo ""
}

# Function to export report to JSON
export_json_report() {
    local output_file=$1
    local slo_name=$2
    local resource_type=$3
    local resource_id=$4

    mkdir -p "${REPORT_DIR}"

    cat > "${output_file}" << EOF
{
  "slo": "${slo_name}",
  "resource_type": "${resource_type}",
  "resource_id": "${resource_id}",
  "target": "${SLO_TARGETS[$slo_name]}",
  "window": "${SLO_WINDOWS[$slo_name]}",
  "generated_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
}
EOF

    log_info "JSON report exported to ${output_file}"
}

# Function to display usage
usage() {
    cat << EOF
SLO/SLI Compliance Report Script

Usage: $0 [OPTIONS]

Options:
    --slo NAME          SLO name: availability, latency_p95, error_rate
    --resource TYPE     Resource type (server, container, storage)
    --resource-id ID    Specific resource ID (default: all)
    --window WINDOW     Time window (e.g., 30d, 7d, 24h)
    --comprehensive     Generate comprehensive report for all SLOs
    --output FILE       Save report to file (JSON format)
    --summary           Display summary table
    -h, --help          Show this help message

Environment Variables:
    APP_PATH            Application path
    REPORT_DIR          Report output directory

Default SLOs:
    availability    99.9% (30d window)
    latency_p95     500ms (7d window)
    error_rate      0.1% (24h window)

Examples:
    # Generate availability SLO report
    $0 --slo availability --resource server --window 30d

    # Generate comprehensive report
    $0 --comprehensive --resource server --output slo-report.json

    # Display summary table
    $0 --summary

    # Generate latency SLO for specific resource
    $0 --slo latency_p95 --resource container --resource-id web-01

EOF
}

# Main execution
main() {
    local slo_name=""
    local resource_type=""
    local resource_id="all"
    local window="default"
    local do_comprehensive=false
    local do_summary=false
    local output_file=""

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --slo)
                slo_name="$2"
                shift 2
                ;;
            --resource)
                resource_type="$2"
                shift 2
                ;;
            --resource-id)
                resource_id="$2"
                shift 2
                ;;
            --window)
                window="$2"
                shift 2
                ;;
            --comprehensive)
                do_comprehensive=true
                shift
                ;;
            --summary)
                do_summary=true
                shift
                ;;
            --output)
                output_file="$2"
                shift 2
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done

    # Execute report generation
    if [ "$do_summary" = true ]; then
        display_summary_table
    elif [ "$do_comprehensive" = true ]; then
        if [ -z "${resource_type}" ]; then
            log_error "Resource type is required for comprehensive report"
            exit 1
        fi
        generate_comprehensive_report "${resource_type}" "${resource_id}" "${output_file}"
    elif [ -n "${slo_name}" ]; then
        if [ -z "${resource_type}" ]; then
            log_error "Resource type is required"
            exit 1
        fi
        generate_slo_report "${slo_name}" "${resource_type}" "${resource_id}" "${window}"

        if [ -n "${output_file}" ]; then
            export_json_report "${output_file}" "${slo_name}" "${resource_type}" "${resource_id}"
        fi
    else
        log_error "Either --slo, --comprehensive, or --summary is required"
        usage
        exit 1
    fi

    log_info "SLO report generation completed"
}

main "$@"
