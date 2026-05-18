#!/bin/bash

################################################################################
# N8N Diagnostic Data Collection Script
# Purpose: Comprehensive diagnostics for troubleshooting n8n issues
# Collects: logs, metrics, configuration, system state
# Compatible: Proxmox LXC, Docker, Docker Compose
# Author: Hive Mind Coder Agent
################################################################################

set -euo pipefail

# Configuration
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly DIAG_DIR="/var/log/n8n-monitoring/diagnostics"
readonly CONTAINER_NAME="${N8N_CONTAINER_NAME:-n8n}"
readonly COLLECT_LOGS_LINES="${N8N_DIAG_LOG_LINES:-1000}"
readonly KEEP_DIAGNOSTICS_DAYS="${N8N_DIAG_RETENTION:-7}"

# Color codes
readonly RED='\033[0;31m'
readonly YELLOW='\033[1;33m'
readonly GREEN='\033[0;32m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m'

################################################################################
# Utility Functions
################################################################################

print_header() {
    local title="$1"
    echo
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}   ${title}${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo
}

print_section() {
    local section="$1"
    echo -e "${CYAN}▶ ${section}${NC}"
}

print_success() {
    echo -e "${GREEN}✓${NC} $*"
}

print_error() {
    echo -e "${RED}✗${NC} $*"
}

print_info() {
    echo -e "${BLUE}ℹ${NC} $*"
}

################################################################################
# Container Detection
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

################################################################################
# Data Collection Functions
################################################################################

collect_container_info() {
    local container_id="$1"
    local output_dir="$2"

    print_section "Collecting container information"

    {
        echo "=== Container Inspection ==="
        docker inspect "${container_id}" 2>/dev/null || echo "Failed to inspect container"
        echo
        echo "=== Container Stats ==="
        docker stats --no-stream "${container_id}" 2>/dev/null || echo "Failed to get stats"
        echo
        echo "=== Container Processes ==="
        docker top "${container_id}" 2>/dev/null || echo "Failed to get processes"
        echo
    } > "${output_dir}/container_info.txt"

    print_success "Container information collected"
}

collect_container_logs() {
    local container_id="$1"
    local output_dir="$2"

    print_section "Collecting container logs"

    # Collect stdout/stderr logs
    docker logs --tail "${COLLECT_LOGS_LINES}" "${container_id}" > "${output_dir}/container_stdout.log" 2>&1 || \
        echo "Failed to collect stdout logs" > "${output_dir}/container_stdout.log"

    # Collect full logs with timestamps
    docker logs --tail "${COLLECT_LOGS_LINES}" --timestamps "${container_id}" > "${output_dir}/container_logs_timestamped.log" 2>&1 || \
        echo "Failed to collect timestamped logs" > "${output_dir}/container_logs_timestamped.log"

    print_success "Container logs collected (last ${COLLECT_LOGS_LINES} lines)"
}

collect_network_info() {
    local container_id="$1"
    local output_dir="$2"

    print_section "Collecting network information"

    {
        echo "=== Container Networks ==="
        docker inspect --format='{{range $net,$v := .NetworkSettings.Networks}}{{printf "%s: %s\n" $net $v.IPAddress}}{{end}}' "${container_id}" 2>/dev/null
        echo
        echo "=== Container Ports ==="
        docker port "${container_id}" 2>/dev/null || echo "No port mappings"
        echo
        echo "=== Network Connectivity Test ==="
        local container_ip
        container_ip=$(docker inspect --format='{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "${container_id}" | head -1)
        if [[ -n "${container_ip}" ]]; then
            echo "Container IP: ${container_ip}"
            if command -v curl &>/dev/null; then
                echo "Testing HTTP endpoint..."
                curl -v -m 5 "http://${container_ip}:5678/" 2>&1 || echo "HTTP test failed"
            fi
        fi
        echo
    } > "${output_dir}/network_info.txt"

    print_success "Network information collected"
}

collect_resource_usage() {
    local container_id="$1"
    local output_dir="$2"

    print_section "Collecting resource usage metrics"

    {
        echo "=== Docker Stats (5 samples) ==="
        for i in {1..5}; do
            echo "Sample ${i}:"
            docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}\t{{.NetIO}}\t{{.BlockIO}}" "${container_id}" 2>/dev/null
            sleep 2
        done
        echo
    } > "${output_dir}/resource_metrics.txt"

    print_success "Resource metrics collected"
}

collect_docker_environment() {
    local output_dir="$1"

    print_section "Collecting Docker environment"

    {
        echo "=== Docker Version ==="
        docker version 2>/dev/null || echo "Failed to get Docker version"
        echo
        echo "=== Docker Info ==="
        docker info 2>/dev/null || echo "Failed to get Docker info"
        echo
        echo "=== Docker Compose Version ==="
        docker-compose version 2>/dev/null || docker compose version 2>/dev/null || echo "Docker Compose not available"
        echo
    } > "${output_dir}/docker_environment.txt"

    print_success "Docker environment collected"
}

collect_system_info() {
    local output_dir="$1"

    print_section "Collecting system information"

    {
        echo "=== System Information ==="
        echo "Hostname: $(hostname)"
        echo "Kernel: $(uname -r)"
        echo "OS: $(cat /etc/os-release 2>/dev/null | grep PRETTY_NAME | cut -d'"' -f2)"
        echo
        echo "=== System Resources ==="
        echo "--- CPU ---"
        if command -v lscpu &>/dev/null; then
            lscpu | grep -E "^CPU\(s\)|^Model name|^Thread"
        fi
        echo
        echo "--- Memory ---"
        free -h
        echo
        echo "--- Disk Space ---"
        df -h | grep -E "Filesystem|/dev/"
        echo
        echo "=== System Load ==="
        uptime
        echo
        echo "=== Top Processes ==="
        ps aux --sort=-%mem | head -20
        echo
    } > "${output_dir}/system_info.txt"

    print_success "System information collected"
}

collect_monitoring_logs() {
    local output_dir="$1"

    print_section "Collecting monitoring logs"

    local monitoring_log_dir="/var/log/n8n-monitoring"

    if [[ -d "${monitoring_log_dir}" ]]; then
        # Copy health check logs
        if [[ -f "${monitoring_log_dir}/health_check.log" ]]; then
            tail -1000 "${monitoring_log_dir}/health_check.log" > "${output_dir}/health_check.log" || true
        fi

        # Copy recovery logs
        if [[ -f "${monitoring_log_dir}/auto_recovery.log" ]]; then
            tail -1000 "${monitoring_log_dir}/auto_recovery.log" > "${output_dir}/auto_recovery.log" || true
        fi

        # Copy incident log
        if [[ -f "${monitoring_log_dir}/incidents.log" ]]; then
            tail -500 "${monitoring_log_dir}/incidents.log" > "${output_dir}/incidents.log" || true
        fi

        # Copy state files
        if [[ -d "${monitoring_log_dir}/recovery_state" ]]; then
            cp -r "${monitoring_log_dir}/recovery_state" "${output_dir}/" 2>/dev/null || true
        fi

        print_success "Monitoring logs collected"
    else
        print_info "No monitoring logs found"
    fi
}

analyze_issues() {
    local container_id="$1"
    local output_dir="$2"

    print_section "Analyzing potential issues"

    {
        echo "=== Automated Issue Analysis ==="
        echo "Generated: $(date -Iseconds)"
        echo

        # Check container status
        local status
        status=$(docker inspect --format='{{.State.Status}}' "${container_id}" 2>/dev/null || echo "unknown")
        echo "Container Status: ${status}"

        if [[ "${status}" != "running" ]]; then
            echo "⚠ WARNING: Container is not running"
            echo
            echo "Exit Code: $(docker inspect --format='{{.State.ExitCode}}' "${container_id}" 2>/dev/null)"
            echo "Error: $(docker inspect --format='{{.State.Error}}' "${container_id}" 2>/dev/null)"
        fi
        echo

        # Check restart count
        local restarts
        restarts=$(docker inspect --format='{{.RestartCount}}' "${container_id}" 2>/dev/null || echo "0")
        echo "Restart Count: ${restarts}"
        if [[ ${restarts} -gt 5 ]]; then
            echo "⚠ WARNING: High restart count detected"
        fi
        echo

        # Analyze logs for errors
        echo "=== Error Analysis from Logs ==="
        if docker logs --tail 100 "${container_id}" 2>&1 | grep -i "error\|exception\|fatal\|panic" | head -20; then
            echo
            echo "⚠ Errors found in recent logs (showing first 20)"
        else
            echo "✓ No obvious errors in recent logs"
        fi
        echo

        # Check resource usage
        echo "=== Resource Analysis ==="
        local stats
        stats=$(docker stats --no-stream --format "{{.CPUPerc}}|{{.MemPerc}}" "${container_id}" 2>/dev/null)
        if [[ -n "${stats}" ]]; then
            IFS='|' read -r cpu mem <<< "${stats}"
            echo "CPU Usage: ${cpu}"
            echo "Memory Usage: ${mem}"

            cpu_num=${cpu%\%}
            mem_num=${mem%\%}
            cpu_num=${cpu_num%.*}
            mem_num=${mem_num%.*}

            if [[ ${cpu_num} -gt 90 ]]; then
                echo "⚠ WARNING: High CPU usage"
            fi
            if [[ ${mem_num} -gt 90 ]]; then
                echo "⚠ WARNING: High memory usage"
            fi
        fi
        echo

        # Check disk space
        echo "=== Disk Space Analysis ==="
        df -h / | tail -1 | awk '{
            usage=$5; gsub(/%/, "", usage);
            if (usage > 90) print "⚠ WARNING: Low disk space - " usage "%";
            else if (usage > 80) print "⚠ CAUTION: Disk space at " usage "%";
            else print "✓ Disk space OK - " usage "%";
        }'
        echo

        # Check Docker daemon
        echo "=== Docker Health ==="
        if docker info >/dev/null 2>&1; then
            echo "✓ Docker daemon is healthy"
        else
            echo "⚠ WARNING: Docker daemon may have issues"
        fi
        echo

    } > "${output_dir}/issue_analysis.txt"

    print_success "Issue analysis completed"
}

generate_summary() {
    local container_id="$1"
    local output_dir="$2"

    print_section "Generating diagnostic summary"

    {
        echo "╔══════════════════════════════════════════════════════════╗"
        echo "║         N8N Diagnostic Summary                           ║"
        echo "╚══════════════════════════════════════════════════════════╝"
        echo
        echo "Collection Time: $(date -Iseconds)"
        echo "Container ID: ${container_id:0:12}"
        echo "Container Name: ${CONTAINER_NAME}"
        echo
        echo "--- Quick Status ---"
        docker inspect --format='Status: {{.State.Status}}
Health: {{.State.Health.Status}}
Started: {{.State.StartedAt}}
Restarts: {{.RestartCount}}' "${container_id}" 2>/dev/null || echo "Status information unavailable"
        echo
        echo "--- Files Collected ---"
        ls -lh "${output_dir}" | tail -n +2
        echo
        echo "--- Diagnostic Location ---"
        echo "${output_dir}"
        echo
        echo "--- Next Steps ---"
        echo "1. Review issue_analysis.txt for automated findings"
        echo "2. Check container_logs_timestamped.log for detailed logs"
        echo "3. Examine resource_metrics.txt for performance issues"
        echo "4. Review monitoring logs for pattern analysis"
        echo
    } > "${output_dir}/SUMMARY.txt"

    # Display summary to terminal
    cat "${output_dir}/SUMMARY.txt"

    print_success "Summary generated"
}

create_archive() {
    local output_dir="$1"
    local timestamp
    timestamp=$(date +%Y%m%d_%H%M%S)
    local archive_name="n8n_diagnostics_${timestamp}.tar.gz"
    local archive_path="${DIAG_DIR}/${archive_name}"

    print_section "Creating diagnostic archive"

    tar -czf "${archive_path}" -C "$(dirname "${output_dir}")" "$(basename "${output_dir}")" 2>/dev/null

    if [[ -f "${archive_path}" ]]; then
        local size
        size=$(du -h "${archive_path}" | cut -f1)
        print_success "Archive created: ${archive_path} (${size})"
        echo
        print_info "To extract: tar -xzf ${archive_path}"
        echo "${archive_path}"
    else
        print_error "Failed to create archive"
        return 1
    fi
}

cleanup_old_diagnostics() {
    print_section "Cleaning up old diagnostics"

    local deleted_count=0

    # Remove old directories
    find "${DIAG_DIR}" -maxdepth 1 -type d -name "diag_*" -mtime "+${KEEP_DIAGNOSTICS_DAYS}" -exec rm -rf {} \; 2>/dev/null || true

    # Remove old archives
    while IFS= read -r old_archive; do
        rm -f "${old_archive}"
        ((deleted_count++))
    done < <(find "${DIAG_DIR}" -maxdepth 1 -type f -name "n8n_diagnostics_*.tar.gz" -mtime "+${KEEP_DIAGNOSTICS_DAYS}" 2>/dev/null)

    if [[ ${deleted_count} -gt 0 ]]; then
        print_success "Cleaned up ${deleted_count} old diagnostic(s)"
    else
        print_info "No old diagnostics to clean up"
    fi
}

################################################################################
# Main Collection Function
################################################################################

collect_diagnostics() {
    local timestamp
    timestamp=$(date +%Y%m%d_%H%M%S)
    local output_dir="${DIAG_DIR}/diag_${timestamp}"

    # Create output directory
    mkdir -p "${output_dir}"

    print_header "N8N Diagnostic Data Collection"

    # Detect container
    print_section "Detecting n8n container"
    local container_id
    container_id=$(detect_container)

    if [[ -z "${container_id}" ]]; then
        print_error "N8N container not found"
        echo
        print_info "Available containers:"
        docker ps -a --format "table {{.Names}}\t{{.Status}}\t{{.Image}}"
        exit 1
    fi

    print_success "Container found: ${container_id:0:12}"
    echo

    # Collect all diagnostics
    collect_container_info "${container_id}" "${output_dir}"
    collect_container_logs "${container_id}" "${output_dir}"
    collect_network_info "${container_id}" "${output_dir}"
    collect_resource_usage "${container_id}" "${output_dir}"
    collect_docker_environment "${output_dir}"
    collect_system_info "${output_dir}"
    collect_monitoring_logs "${output_dir}"
    analyze_issues "${container_id}" "${output_dir}"
    generate_summary "${container_id}" "${output_dir}"

    echo
    print_header "Collection Complete"

    # Create archive
    local archive_path
    if archive_path=$(create_archive "${output_dir}"); then
        echo
        print_success "Diagnostics package ready: ${archive_path}"
    fi

    echo
    cleanup_old_diagnostics

    echo
    print_header "Diagnostic Session Complete"
}

################################################################################
# Main Entry Point
################################################################################

main() {
    # Parse arguments
    case "${1:-}" in
        --help|-h)
            echo "N8N Diagnostic Collection Tool"
            echo
            echo "Usage: $0 [OPTIONS]"
            echo
            echo "Options:"
            echo "  --help, -h          Show this help message"
            echo "  --quick             Quick collection (skip resource sampling)"
            echo "  --logs-only         Collect only logs"
            echo
            echo "Environment Variables:"
            echo "  N8N_CONTAINER_NAME         Container name (default: n8n)"
            echo "  N8N_DIAG_LOG_LINES        Log lines to collect (default: 1000)"
            echo "  N8N_DIAG_RETENTION        Days to keep diagnostics (default: 7)"
            exit 0
            ;;
        --quick)
            COLLECT_LOGS_LINES=500
            ;;
        --logs-only)
            # Simplified collection
            local container_id
            container_id=$(detect_container)
            if [[ -z "${container_id}" ]]; then
                echo "Container not found"
                exit 1
            fi
            mkdir -p "${DIAG_DIR}"
            local timestamp
            timestamp=$(date +%Y%m%d_%H%M%S)
            docker logs --tail "${COLLECT_LOGS_LINES}" "${container_id}" > "${DIAG_DIR}/logs_${timestamp}.txt" 2>&1
            echo "Logs saved to: ${DIAG_DIR}/logs_${timestamp}.txt"
            exit 0
            ;;
    esac

    collect_diagnostics
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
