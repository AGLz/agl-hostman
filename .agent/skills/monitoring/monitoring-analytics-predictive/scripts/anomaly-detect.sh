#!/bin/bash
# Anomaly Detection Script
# Detects anomalies in metrics using statistical methods (z-score, IQR)
# Part of monitoring-analytics-predictive skill

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
APP_PATH="${APP_PATH:-/mnt/overpower/apps/dev/agl/agl-hostman/src}"
ZSCORE_THRESHOLD="${ANOMALY_ZSCORE_THRESHOLD:-3.0}"
IQR_MULTIPLIER="${ANOMALY_IQR_MULTIPLIER:-1.5}"
MIN_SAMPLES="${ANOMALY_MIN_SAMPLES:-30}"

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

log_anomaly() {
    echo -e "${RED}[ANOMALY]${NC} $1"
}

# Function to calculate mean
calculate_mean() {
    local sum=0
    local count=0

    for value in "$@"; do
        sum=$(echo "$sum + $value" | bc)
        ((count++))
    done

    echo "scale=4; $sum / $count" | bc
}

# Function to calculate standard deviation
calculate_stddev() {
    local mean=$1
    shift
    local sum_squared_diff=0
    local count=0

    for value in "$@"; do
        local diff=$(echo "$value - $mean" | bc)
        local squared=$(echo "$diff * $diff" | bc)
        sum_squared_diff=$(echo "$sum_squared_diff + $squared" | bc)
        ((count++))
    done

    local variance=$(echo "scale=4; $sum_squared_diff / $count" | bc)
    echo "scale=4; sqrt($variance)" | bc
}

# Function to detect anomalies using z-score method
detect_zscore() {
    local metric_name=$1
    shift
    local values=("$@")
    local threshold=${ZSCORE_THRESHOLD}

    log_info "Detecting anomalies using z-score method (threshold: ${threshold})..."

    local mean=$(calculate_mean "${values[@]}")
    local stddev=$(calculate_stddev "$mean" "${values[@]}")

    log_info "Mean: ${mean}, Std Dev: ${stddev}"

    local anomalies=0
    for i in "${!values[@]}"; do
        local value=${values[$i]}
        local zscore=$(echo "scale=4; ($value - $mean) / $stddev" | bc)
        local abs_zscore=$(echo "$zscore" | tr -d '-')
        local severity=$(echo "$abs_zscore > 5" | bc)

        if (( $(echo "$abs_zscore > $threshold" | bc -l) )); then
            local severity_label="low"
            if [ "$severity" -eq 1 ]; then
                severity_label="critical"
            elif (( $(echo "$abs_zscore > 4" | bc -l) )); then
                severity_label="high"
            elif (( $(echo "$abs_zscore > 3" | bc -l) )); then
                severity_label="medium"
            fi

            log_anomaly "${metric_name}[${i}]: value=${value}, z-score=${zscore}, severity=${severity_label}"
            ((anomalies++))
        fi
    done

    echo "${anomalies}"
}

# Function to calculate percentile
calculate_percentile() {
    local percentile=$1
    shift
    local sorted_values=($(printf '%s\n' "$@" | sort -n))

    local n=${#sorted_values[@]}
    local index=$(echo "($n - 1) * $percentile / 100" | bc)
    local lower=$(echo "$index" | cut -d'.' -f1)
    local upper=$(($lower + 1))

    if [ $lower -eq $upper ]; then
        echo "${sorted_values[$lower]}"
    else
        local fraction=$(echo "$index - $lower" | bc)
        local lower_val=${sorted_values[$lower]}
        local upper_val=${sorted_values[$upper]}
        echo "scale=4; $lower_val + ($upper_val - $lower_val) * $fraction" | bc
    fi
}

# Function to detect anomalies using IQR method
detect_iqr() {
    local metric_name=$1
    shift
    local values=("$@")
    local multiplier=${IQR_MULTIPLIER}

    log_info "Detecting anomalies using IQR method (multiplier: ${multiplier})..."

    local q1=$(calculate_percentile 25 "${values[@]}")
    local q3=$(calculate_percentile 75 "${values[@]}")
    local iqr=$(echo "scale=4; $q3 - $q1" | bc)

    local lower_bound=$(echo "scale=4; $q1 - $multiplier * $iqr" | bc)
    local upper_bound=$(echo "scale=4; $q3 + $multiplier * $iqr" | bc)

    log_info "Q1: ${q1}, Q3: ${q3}, IQR: ${iqr}"
    log_info "Bounds: [${lower_bound}, ${upper_bound}]"

    local anomalies=0
    for i in "${!values[@]}"; do
        local value=${values[$i]}

        if (( $(echo "$value < $lower_bound" | bc -l) )) || (( $(echo "$value > $upper_bound" | bc -l) )); then
            local anomaly_type="high"
            if (( $(echo "$value < $lower_bound" | bc -l) )); then
                anomaly_type="low"
            fi

            log_anomaly "${metric_name}[${i}]: value=${value}, type=${anomaly_type}"
            ((anomalies++))
        fi
    done

    echo "${anomalies}"
}

# Function to fetch metric values from database
fetch_metric_values() {
    local resource_type=$1
    local metric_type=$2
    local hours=${3:-24}

    cd "${APP_PATH}"

    php artisan trend:export \
        --resource-type="${resource_type}" \
        --metric-type="${metric_type}" \
        --hours="${hours}" \
        --format=raw 2>/dev/null || echo ""
}

# Function to run detection on database metrics
detect_from_database() {
    local resource_type=$1
    local metric_type=$2
    local hours=${3:-24}
    local method=${4:-"zscore"}

    log_info "Fetching ${metric_type} metrics for ${resource_type} (last ${hours}h)..."

    local raw_data=$(fetch_metric_values "${resource_type}" "${metric_type}" "${hours}")

    if [ -z "${raw_data}" ]; then
        log_warning "No data found for ${resource_type}/${metric_type}"
        return
    fi

    # Parse values from raw data (assuming CSV format)
    local values=($(echo "${raw_data}" | grep -oE '[0-9]+\.[0-9]+|[0-9]+' || true))

    if [ ${#values[@]} -lt ${MIN_SAMPLES} ]; then
        log_warning "Insufficient data points (${#values[@]} < ${MIN_SAMPLES})"
        return
    fi

    log_info "Analyzing ${#values[@]} data points..."

    case $method in
        zscore)
            detect_zscore "${metric_type}" "${values[@]}"
            ;;
        iqr)
            detect_iqr "${metric_type}" "${values[@]}"
            ;;
        both)
            local zscore_count=$(detect_zscore "${metric_type}" "${values[@]}")
            local iqr_count=$(detect_iqr "${metric_type}" "${values[@]}")
            log_info "Total anomalies: z-score=${zscore_count}, IQR=${iqr_count}"
            ;;
        *)
            log_error "Unknown detection method: ${method}"
            return 1
            ;;
    esac
}

# Function to detect anomalies in system metrics
detect_system_anomalies() {
    local hours=${1:-24}

    log_info "Detecting anomalies in system metrics..."

    # CPU usage
    detect_from_database "server" "cpu_usage" "${hours}" "zscore"

    # Memory usage
    detect_from_database "server" "memory_usage" "${hours}" "zscore"

    # Disk usage
    detect_from_database "server" "disk_usage" "${hours}" "zscore"

    # Network latency
    detect_from_database "server" "network_latency" "${hours}" "zscore"
}

# Function to generate anomaly report
generate_report() {
    local output_file=${1:-"anomaly-report.json"}
    local hours=${2:-24}

    log_info "Generating anomaly report..."

    cd "${APP_PATH}"

    php artisan anomalies:report \
        --hours="${hours}" \
        --output="${output_file}" \
        --format=json 2>/dev/null || log_warning "Report generation failed"

    if [ -f "${output_file}" ]; then
        log_info "Report saved to ${output_file}"
    fi
}

# Function to display usage
usage() {
    cat << EOF
Anomaly Detection Script

Usage: $0 [OPTIONS]

Options:
    --metric TYPE       Metric type to analyze (cpu_usage, memory_usage, etc.)
    --resource TYPE     Resource type (server, container, storage)
    --hours HOURS       Time window in hours (default: 24)
    --method METHOD     Detection method: zscore, iqr, both (default: zscore)
    --system            Run detection on all system metrics
    --report FILE       Generate anomaly report (JSON format)
    --threshold FLOAT   Z-score threshold (default: 3.0)
    -h, --help          Show this help message

Environment Variables:
    ANOMALY_ZSCORE_THRESHOLD    Z-score threshold (default: 3.0)
    ANOMALY_IQR_MULTIPLIER      IQR multiplier (default: 1.5)
    ANOMALY_MIN_SAMPLES         Minimum samples required (default: 30)
    APP_PATH                    Application path

Examples:
    # Detect CPU usage anomalies
    $0 --metric cpu_usage --resource server --hours 24

    # Detect using IQR method
    $0 --metric memory_usage --resource server --method iqr

    # Detect system-wide anomalies
    $0 --system --hours 24

    # Generate anomaly report
    $0 --system --report /tmp/anomaly-report.json

EOF
}

# Main execution
main() {
    local metric=""
    local resource=""
    local hours=24
    local method="zscore"
    local do_system=false
    local report_file=""

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --metric)
                metric="$2"
                shift 2
                ;;
            --resource)
                resource="$2"
                shift 2
                ;;
            --hours)
                hours="$2"
                shift 2
                ;;
            --method)
                method="$2"
                shift 2
                ;;
            --threshold)
                ZSCORE_THRESHOLD="$2"
                shift 2
                ;;
            --system)
                do_system=true
                shift
                ;;
            --report)
                report_file="$2"
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

    # Execute detection
    if [ "$do_system" = true ]; then
        detect_system_anomalies "${hours}"
    elif [ -n "${metric}" ] && [ -n "${resource}" ]; then
        detect_from_database "${resource}" "${metric}" "${hours}" "${method}"
    else
        log_error "Either --system or both --metric and --resource are required"
        usage
        exit 1
    fi

    # Generate report if requested
    if [ -n "${report_file}" ]; then
        generate_report "${report_file}" "${hours}"
    fi

    log_info "Anomaly detection completed"
}

main "$@"
