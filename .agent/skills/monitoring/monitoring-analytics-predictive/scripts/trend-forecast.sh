#!/bin/bash
# Trend Forecasting Script
# Forecasts trends for capacity planning using linear regression and growth rates
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
FORECAST_PERIODS="${FORECAST_PERIODS:-30}"
MIN_DATA_POINTS="${MIN_DATA_POINTS:-10}"
CONFIDENCE_THRESHOLD="${CONFIDENCE_THRESHOLD:-0.7}"

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

log_forecast() {
    echo -e "${BLUE}[FORECAST]${NC} $1"
}

# Function to perform linear regression
linear_regression() {
    local values=("$@")

    local n=${#values[@]}

    # Calculate sums
    local sum_x=0
    local sum_y=0
    local sum_xy=0
    local sum_x2=0

    for i in "${!values[@]}"; do
        local x=$((i + 1))
        local y=${values[$i]}

        sum_x=$((sum_x + x))
        sum_y=$(echo "scale=4; $sum_y + $y" | bc)
        sum_xy=$(echo "scale=4; $sum_xy + ($x * $y)" | bc)
        sum_x2=$((sum_x2 + x * x))
    done

    # Calculate slope and intercept
    local slope=$(echo "scale=4; ($n * $sum_xy - $sum_x * $sum_y) / ($n * $sum_x2 - $sum_x * $sum_x)" | bc)
    local intercept=$(echo "scale=4; ($sum_y - $slope * $sum_x) / $n" | bc)

    echo "${slope}|${intercept}"
}

# Function to calculate R-squared
calculate_r_squared() {
    local slope=$1
    local intercept=$2
    shift 2
    local values=("$@")

    local n=${#values[@]}
    local y_mean=$(echo "scale=4; $(printf '%s\n' "${values[@]}" | awk '{sum+=$1} END {print sum}') / $n" | bc)

    local ss_total=0
    local ss_residual=0

    for i in "${!values[@]}"; do
        local x=$((i + 1))
        local y=${values[$i]}
        local y_pred=$(echo "scale=4; $slope * $x + $intercept" | bc)

        ss_total=$(echo "scale=4; $ss_total + ($y - $y_mean)^2" | bc)
        ss_residual=$(echo "scale=4; $ss_residual + ($y - $y_pred)^2" | bc)
    done

    local r_squared=$(echo "scale=4; 1 - ($ss_residual / $ss_total)" | bc)

    # Ensure R² is between 0 and 1
    if (( $(echo "$r_squared < 0" | bc -l) )); then
        r_squared="0"
    elif (( $(echo "$r_squared > 1" | bc -l) )); then
        r_squared="1"
    fi

    echo "${r_squared}"
}

# Function to generate forecast
generate_forecast() {
    local metric_name=$1
    local values=("$@")
    local periods=${FORECAST_PERIODS}

    log_info "Generating forecast for ${metric_name}..."

    if [ ${#values[@]} -lt ${MIN_DATA_POINTS} ]; then
        log_warning "Insufficient data points (${#values[@]} < ${MIN_DATA_POINTS})"
        return
    fi

    # Perform linear regression
    local regression=$(linear_regression "${values[@]}")
    local slope=$(echo "${regression}" | cut -d'|' -f1)
    local intercept=$(echo "${regression}" | cut -d'|' -f2)

    # Calculate R-squared
    local r_squared=$(calculate_r_squared "${slope}" "${intercept}" "${values[@]}")

    log_info "Regression: y = ${slope}x + ${intercept}"
    log_info "R² = ${r_squared}"

    # Check confidence
    if (( $(echo "$r_squared < $CONFIDENCE_THRESHOLD" | bc -l) )); then
        log_warning "Low confidence (R² = ${r_squared} < ${CONFIDENCE_THRESHOLD})"
    fi

    # Generate forecasts
    local last_x=${#values[@]}
    log_forecast "${metric_name} forecasts:"
    echo ""
    printf "%-10s %-20s %-15s\n" "Period" "Predicted Value" "Confidence"
    printf "%-10s %-20s %-15s\n" "------" "---------------" "----------"

    for ((p=1; p<=periods; p++)); do
        local x=$((last_x + p))
        local prediction=$(echo "scale=2; $slope * $x + $intercept" | bc)
        local confidence=$r_squared

        # Format confidence as percentage
        local confidence_pct=$(echo "scale=1; $confidence * 100" | bc)

        printf "%-10s %-20s %-15s\n" "${p}" "${prediction}" "${confidence_pct}%"
    done
    echo ""

    # Determine trend direction
    if (( $(echo "$slope > 0.1" | bc -l) )); then
        log_forecast "Trend: INCREASING (+$(echo "scale=2; $slope * 100" | bc)% per period)"
    elif (( $(echo "$slope < -0.1" | bc -l) )); then
        log_forecast "Trend: DECREASING ($(echo "scale=2; $slope * 100" | bc)% per period)"
    else
        log_forecast "Trend: STABLE"
    fi
}

# Function to calculate moving average
calculate_moving_average() {
    local window=$1
    shift
    local values=("$@")

    local moving_averages=()

    for ((i=$((window - 1)); i<${#values[@]}; i++)); do
        local sum=0
        for ((j=$((i - window + 1)); j<=$i; j++)); do
            sum=$(echo "scale=4; $sum + ${values[$j]}" | bc)
        done
        local avg=$(echo "scale=4; $sum / $window" | bc)
        moving_averages+=("${avg}")
    done

    echo "${moving_averages[@]}"
}

# Function to forecast using moving average
forecast_moving_average() {
    local metric_name=$1
    local window=$2
    local periods=$3
    shift 3
    local values=("$@")

    log_info "Generating moving average forecast (window: ${window})..."

    local moving_averages=($(calculate_moving_average "${window}" "${values[@]}"))

    if [ ${#moving_averages[@]} -lt 2 ]; then
        log_warning "Insufficient data for moving average forecast"
        return
    fi

    local last_avg=${moving_averages[-1]}
    local first_avg=${moving_averages[0]}
    local trend=$(echo "scale=4; ($last_avg - $first_avg) / ${#moving_averages[@]}" | bc)

    log_forecast "${metric_name} moving average forecasts:"
    echo ""
    printf "%-10s %-20s\n" "Period" "Predicted Value"
    printf "%-10s %-20s\n" "------" "---------------"

    for ((p=1; p<=periods; p++)); do
        local prediction=$(echo "scale=2; $last_avg + ($trend * $p)" | bc)
        printf "%-10s %-20s\n" "${p}" "${prediction}"
    done
    echo ""
}

# Function to fetch metric values from database
fetch_metric_values() {
    local resource_type=$1
    local metric_type=$2
    local days=${3:-30}

    cd "${APP_PATH}"

    php artisan trend:export \
        --resource-type="${resource_type}" \
        --metric-type="${metric_type}" \
        --days="${days}" \
        --format=raw 2>/dev/null || echo ""
}

# Function to forecast database metrics
forecast_from_database() {
    local resource_type=$1
    local metric_type=$2
    local days=${3:-30}
    local periods=${4:-${FORECAST_PERIODS}}

    log_info "Fetching ${metric_type} metrics for ${resource_type} (last ${days} days)..."

    local raw_data=$(fetch_metric_values "${resource_type}" "${metric_type}" "${days}")

    if [ -z "${raw_data}" ]; then
        log_warning "No data found for ${resource_type}/${metric_type}"
        return
    fi

    # Parse values from raw data
    local values=($(echo "${raw_data}" | grep -oE '[0-9]+\.[0-9]+|[0-9]+' || true))

    if [ ${#values[@]} -lt ${MIN_DATA_POINTS} ]; then
        log_warning "Insufficient data points (${#values[@]} < ${MIN_DATA_POINTS})"
        return
    fi

    log_info "Analyzing ${#values[@]} data points..."

    # Generate forecasts
    generate_forecast "${metric_type}" "${values[@]}"

    # Also generate moving average forecast
    local window=7
    if [ ${#values[@]} -ge $((window * 2)) ]; then
        forecast_moving_average "${metric_type}" "${window}" "${periods}" "${values[@]}"
    fi
}

# Function to forecast system metrics
forecast_system_metrics() {
    local days=${1:-30}
    local periods=${2:-${FORECAST_PERIODS}}

    log_info "Forecasting system metrics..."

    # CPU usage
    forecast_from_database "server" "cpu_usage" "${days}" "${periods}"

    # Memory usage
    forecast_from_database "server" "memory_usage" "${days}" "${periods}"

    # Disk usage
    forecast_from_database "server" "disk_usage" "${days}" "${periods}"
}

# Function to estimate capacity needs
estimate_capacity() {
    local metric_type=$1
    local threshold=$2
    local days=${3:-30}
    local periods=${4:-${FORECAST_PERIODS}}

    log_info "Estimating capacity needs for ${metric_type} (threshold: ${threshold})..."

    local raw_data=$(fetch_metric_values "server" "${metric_type}" "${days}")

    if [ -z "${raw_data}" ]; then
        log_warning "No data found for ${metric_type}"
        return
    fi

    local values=($(echo "${raw_data}" | grep -oE '[0-9]+\.[0-9]+|[0-9]+' || true))

    if [ ${#values[@]} -lt ${MIN_DATA_POINTS} ]; then
        log_warning "Insufficient data points"
        return
    fi

    # Perform regression
    local regression=$(linear_regression "${values[@]}")
    local slope=$(echo "${regression}" | cut -d'|' -f1)
    local intercept=$(echo "${regression}" | cut -d'|' -f2)

    # Calculate when threshold will be reached
    local last_x=${#values[@]}
    local last_value=${values[-1]}

    if (( $(echo "$slope <= 0" | bc -l) )); then
        log_info "${metric_type} is not trending upward"
        return
    fi

    # Solve for x when y = threshold
    local periods_until_threshold=$(echo "scale=0; ($threshold - $intercept) / $slope - $last_x" | bc)

    if [ "${periods_until_threshold}" -gt 0 ]; then
        log_forecast "${metric_type} will reach ${threshold}% in approximately ${periods_until_threshold} periods"
    else
        log_warning "${metric_type} has already exceeded threshold"
    fi
}

# Function to generate forecast report
generate_report() {
    local output_file=${1:-"forecast-report.json"}
    local days=${2:-30}

    log_info "Generating forecast report..."

    cd "${APP_PATH}"

    php artisan forecast:report \
        --days="${days}" \
        --output="${output_file}" \
        --format=json 2>/dev/null || log_warning "Report generation failed"

    if [ -f "${output_file}" ]; then
        log_info "Report saved to ${output_file}"
    fi
}

# Function to display usage
usage() {
    cat << EOF
Trend Forecasting Script

Usage: $0 [OPTIONS]

Options:
    --metric TYPE       Metric type to forecast (cpu_usage, memory_usage, etc.)
    --resource TYPE     Resource type (server, container, storage)
    --days DAYS         Historical data period in days (default: 30)
    --periods N         Number of periods to forecast (default: 30)
    --threshold VALUE   Capacity threshold percentage (default: 90)
    --system            Forecast all system metrics
    --capacity          Estimate capacity needs
    --report FILE       Generate forecast report (JSON format)
    -h, --help          Show this help message

Environment Variables:
    FORECAST_PERIODS           Number of periods to forecast (default: 30)
    MIN_DATA_POINTS            Minimum data points required (default: 10)
    CONFIDENCE_THRESHOLD       Minimum R² confidence (default: 0.7)
    APP_PATH                   Application path

Examples:
    # Forecast CPU usage for next 30 days
    $0 --metric cpu_usage --resource server --days 30 --periods 30

    # Forecast all system metrics
    $0 --system --days 30

    # Estimate when disk will reach 90% capacity
    $0 --metric disk_usage --capacity --threshold 90

    # Generate forecast report
    $0 --system --report /tmp/forecast-report.json

EOF
}

# Main execution
main() {
    local metric=""
    local resource=""
    local days=30
    local periods=${FORECAST_PERIODS}
    local threshold=90
    local do_system=false
    local do_capacity=false
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
            --days)
                days="$2"
                shift 2
                ;;
            --periods)
                periods="$2"
                shift 2
                ;;
            --threshold)
                threshold="$2"
                shift 2
                ;;
            --system)
                do_system=true
                shift
                ;;
            --capacity)
                do_capacity=true
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

    # Execute forecast
    if [ "$do_system" = true ]; then
        forecast_system_metrics "${days}" "${periods}"
    elif [ -n "${metric}" ] && [ -n "${resource}" ]; then
        if [ "$do_capacity" = true ]; then
            estimate_capacity "${metric}" "${threshold}" "${days}" "${periods}"
        else
            forecast_from_database "${resource}" "${metric}" "${days}" "${periods}"
        fi
    else
        log_error "Either --system or both --metric and --resource are required"
        usage
        exit 1
    fi

    # Generate report if requested
    if [ -n "${report_file}" ]; then
        generate_report "${report_file}" "${days}"
    fi

    log_info "Trend forecasting completed"
}

main "$@"
