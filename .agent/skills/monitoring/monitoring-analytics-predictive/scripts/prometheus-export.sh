#!/bin/bash
# Prometheus Metrics Export Configuration Script
# Configures application metrics export to Prometheus Pushgateway
# Part of monitoring-analytics-predictive skill

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
PROMETHEUS_PUSHGATEWAY_URL="${PROMETHEUS_PUSHGATEWAY_URL:-http://localhost:9091}"
JOB_NAME="${PROMETHEUS_JOB_NAME:-agl-hostman}"
PROMETHEUS_RETENTION="${PROMETHEUS_RETENTION:-24h}"

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

# Function to check if Pushgateway is accessible
check_pushgateway() {
    log_info "Checking Pushgateway connectivity..."

    if curl -sf "${PROMETHEUS_PUSHGATEWAY_URL}/-/healthy" > /dev/null 2>&1; then
        log_info "Pushgateway is accessible at ${PROMETHEUS_PUSHGATEWAY_URL}"
        return 0
    else
        log_error "Cannot reach Pushgateway at ${PROMETHEUS_PUSHGATEWAY_URL}"
        log_info "Install Pushgateway with: docker run -d -p 9091:9091 prom/pushgateway"
        return 1
    fi
}

# Function to configure Laravel Prometheus exporter
configure_laravel_exporter() {
    log_info "Configuring Laravel Prometheus exporter..."

    # Check if composer needs prometheus package
    if ! grep -q "promphp/prometheus_client_php" /mnt/overpower/apps/dev/agl/agl-hostman/src/composer.json 2>/dev/null; then
        log_info "Installing prometheus/prometheus_client_php package..."
        cd /mnt/overpower/apps/dev/agl/agl-hostman/src
        composer require promphp/prometheus_client_php
    fi

    # Create Prometheus storage directory
    local storage_dir="/mnt/overpower/apps/dev/agl/agl-hostman/src/storage/prometheus"
    mkdir -p "${storage_dir}"
    chmod -R 777 "${storage_dir}"

    log_info "Prometheus storage directory created at ${storage_dir}"
}

# Function to export system metrics
export_system_metrics() {
    log_info "Exporting system metrics to Pushgateway..."

    # Collect system metrics
    local cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)
    local memory_usage=$(free | grep Mem | awk '{printf("%.2f", ($3/$2) * 100)}')
    local disk_usage=$(df -h / | awk 'NR==2 {print $5}' | sed 's/%//')
    local load_avg=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | sed 's/,//')

    # Build metrics payload
    local metrics="# HELP app_cpu_usage_percent CPU usage percentage
# TYPE app_cpu_usage_percent gauge
app_cpu_usage_percent{host=\"$(hostname)\",instance=\"${JOB_NAME}\"} ${cpu_usage}

# HELP app_memory_usage_percent Memory usage percentage
# TYPE app_memory_usage_percent gauge
app_memory_usage_percent{host=\"$(hostname)\",instance=\"${JOB_NAME}\"} ${memory_usage}

# HELP app_disk_usage_percent Disk usage percentage
# TYPE app_disk_usage_percent gauge
app_disk_usage_percent{host=\"$(hostname)\",instance=\"${JOB_NAME}\"} ${disk_usage}

# HELP app_load_average Load average (1min)
# TYPE app_load_average gauge
app_load_average{host=\"$(hostname)\",instance=\"${JOB_NAME}\"} ${load_avg}

# HELP app_up Application uptime indicator
# TYPE app_up gauge
app_up{host=\"$(hostname)\",instance=\"${JOB_NAME}\"} 1"

    # Push to Pushgateway
    echo "${metrics}" | curl --data-binary @- "${PROMETHEUS_PUSHGATEWAY_URL}/metrics/job/${JOB_NAME}"

    log_info "System metrics exported successfully"
}

# Function to export Laravel metrics
export_laravel_metrics() {
    log_info "Exporting Laravel application metrics..."

    local metrics_file="/mnt/overpower/apps/dev/agl/agl-hostman/src/storage/prometheus/metrics.txt"

    if [ -f "${metrics_file}" ]; then
        cat "${metrics_file}" | curl --data-binary @- "${PROMETHEUS_PUSHGATEWAY_URL}/metrics/job/${JOB_NAME}/instance/$(hostname)"
        log_info "Laravel metrics exported successfully"
    else
        log_warning "No Laravel metrics file found at ${metrics_file}"
    fi
}

# Function to export performance trends
export_performance_trends() {
    log_info "Exporting performance trend metrics..."

    # Use PHP artisan command to get trends
    cd /mnt/overpower/apps/dev/agl/agl-hostman/src

    local trends=$(php artisan trend:export --format prometheus 2>/dev/null || echo "")

    if [ -n "${trends}" ]; then
        echo "${trends}" | curl --data-binary @- "${PROMETHEUS_PUSHGATEWAY_URL}/metrics/job/${JOB_NAME}/type/trends"
        log_info "Performance trends exported successfully"
    else
        log_warning "No performance trends to export"
    fi
}

# Function to setup scheduled export
setup_scheduled_export() {
    log_info "Setting up scheduled metrics export..."

    local cron_entry="*/1 * * * * /mnt/overpower/apps/dev/agl/agl-hostman/.agent/skills/monitoring/monitoring-analytics-predictive/scripts/prometheus-export.sh --system > /dev/null 2>&1"

    # Check if cron entry already exists
    if ! crontab -l 2>/dev/null | grep -q "prometheus-export.sh"; then
        (crontab -l 2>/dev/null; echo "${cron_entry}") | crontab -
        log_info "Cron job added for metrics export (every minute)"
    else
        log_info "Cron job already exists"
    fi
}

# Function to cleanup old metrics from Pushgateway
cleanup_old_metrics() {
    log_info "Cleaning up old metrics from Pushgateway..."

    # Pushgateway doesn't natively support cleanup, but we can delete old jobs
    # This is a workaround - in production, use proper Prometheus retention

    local jobs=$(curl -s "${PROMETHEUS_PUSHGATEWAY_URL}/api/v1/jobs" | jq -r '.data[]' | grep "${JOB_NAME}" || true)

    for job in ${jobs}; do
        log_info "Keeping job: ${job}"
        # In production, you might want to delete old instances
    done
}

# Function to display usage
usage() {
    cat << EOF
Prometheus Metrics Export Configuration Script

Usage: $0 [OPTIONS]

Options:
    --system           Export system metrics (CPU, memory, disk)
    --laravel          Export Laravel application metrics
    --trends           Export performance trend metrics
    --setup            Configure Laravel Prometheus exporter
    --schedule         Setup scheduled cron job
    --cleanup          Cleanup old metrics
    --all              Run all export operations
    -h, --help         Show this help message

Environment Variables:
    PROMETHEUS_PUSHGATEWAY_URL    Pushgateway URL (default: http://localhost:9091)
    PROMETHEUS_JOB_NAME           Job name (default: agl-hostman)
    PROMETHEUS_RETENTION          Data retention period (default: 24h)

Examples:
    # Export system metrics
    $0 --system

    # Export all metrics
    $0 --all

    # Setup and schedule
    $0 --setup --schedule

EOF
}

# Main execution
main() {
    local do_system=false
    local do_laravel=false
    local do_trends=false
    local do_setup=false
    local do_schedule=false
    local do_cleanup=false

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --system)
                do_system=true
                shift
                ;;
            --laravel)
                do_laravel=true
                shift
                ;;
            --trends)
                do_trends=true
                shift
                ;;
            --setup)
                do_setup=true
                shift
                ;;
            --schedule)
                do_schedule=true
                shift
                ;;
            --cleanup)
                do_cleanup=true
                shift
                ;;
            --all)
                do_system=true
                do_laravel=true
                do_trends=true
                shift
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

    # If no options provided, show usage
    if [ "$do_system" = false ] && [ "$do_laravel" = false ] && [ "$do_trends" = false ] && [ "$do_setup" = false ] && [ "$do_schedule" = false ] && [ "$do_cleanup" = false ]; then
        usage
        exit 0
    fi

    # Check Pushgateway connectivity if exporting
    if [ "$do_system" = true ] || [ "$do_laravel" = true ] || [ "$do_trends" = true ]; then
        check_pushgateway || exit 1
    fi

    # Execute requested operations
    if [ "$do_setup" = true ]; then
        configure_laravel_exporter
    fi

    if [ "$do_system" = true ]; then
        export_system_metrics
    fi

    if [ "$do_laravel" = true ]; then
        export_laravel_metrics
    fi

    if [ "$do_trends" = true ]; then
        export_performance_trends
    fi

    if [ "$do_schedule" = true ]; then
        setup_scheduled_export
    fi

    if [ "$do_cleanup" = true ]; then
        cleanup_old_metrics
    fi

    log_info "Prometheus export configuration completed successfully"
}

main "$@"
