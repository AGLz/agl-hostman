#!/bin/bash

################################################################################
# N8N Health Check Script
# Purpose: Monitor n8n container health with comprehensive diagnostics
# Compatible: Proxmox LXC, Docker, Docker Compose
# Author: Hive Mind Coder Agent
################################################################################

set -euo pipefail

# Configuration
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly LOG_DIR="/var/log/n8n-monitoring"
readonly LOG_FILE="${LOG_DIR}/health_check.log"
readonly STATE_FILE="${LOG_DIR}/health_state.json"
readonly CONTAINER_NAME="${N8N_CONTAINER_NAME:-n8n}"
readonly HTTP_PORT="${N8N_HTTP_PORT:-5678}"
readonly HTTP_TIMEOUT="${N8N_HTTP_TIMEOUT:-10}"
readonly MAX_MEMORY_PERCENT="${N8N_MAX_MEMORY_PERCENT:-90}"
readonly MAX_CPU_PERCENT="${N8N_MAX_CPU_PERCENT:-95}"
readonly CHECK_INTERVAL="${N8N_CHECK_INTERVAL:-60}"

# Health check thresholds
readonly CRITICAL_RESTARTS=5
readonly WARNING_RESTARTS=3
readonly RESPONSE_TIME_WARNING=3000  # milliseconds
readonly RESPONSE_TIME_CRITICAL=5000

# Exit codes
readonly EXIT_SUCCESS=0
readonly EXIT_WARNING=1
readonly EXIT_CRITICAL=2
readonly EXIT_UNKNOWN=3

# Color codes for output
readonly RED='\033[0;31m'
readonly YELLOW='\033[1;33m'
readonly GREEN='\033[0;32m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

################################################################################
# Utility Functions
################################################################################

log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[${timestamp}] [${level}] ${message}" | tee -a "${LOG_FILE}"
}

log_info() { log "INFO" "$@"; }
log_warn() { log "WARN" "$@"; }
log_error() { log "ERROR" "$@"; }
log_critical() { log "CRITICAL" "$@"; }

init_logging() {
    mkdir -p "${LOG_DIR}"
    touch "${LOG_FILE}"

    # Rotate log if larger than 10MB
    if [[ -f "${LOG_FILE}" ]] && [[ $(stat -f%z "${LOG_FILE}" 2>/dev/null || stat -c%s "${LOG_FILE}") -gt 10485760 ]]; then
        mv "${LOG_FILE}" "${LOG_FILE}.$(date +%Y%m%d_%H%M%S)"
        gzip "${LOG_FILE}.$(date +%Y%m%d_%H%M%S)" &
    fi
}

################################################################################
# Container Detection and Status
################################################################################

detect_container() {
    local container_id

    # Try exact match first
    container_id=$(docker ps -aq --filter "name=^${CONTAINER_NAME}$" 2>/dev/null | head -1)

    # If not found, try fuzzy match
    if [[ -z "${container_id}" ]]; then
        container_id=$(docker ps -aq --filter "name=${CONTAINER_NAME}" 2>/dev/null | head -1)
    fi

    # Try to find any n8n container
    if [[ -z "${container_id}" ]]; then
        container_id=$(docker ps -aq --filter "ancestor=n8nio/n8n" 2>/dev/null | head -1)
    fi

    if [[ -z "${container_id}" ]]; then
        log_error "N8N container not found. Searched for: ${CONTAINER_NAME}"
        return 1
    fi

    echo "${container_id}"
    return 0
}

get_container_status() {
    local container_id="$1"
    docker inspect --format='{{.State.Status}}' "${container_id}" 2>/dev/null || echo "unknown"
}

get_container_health() {
    local container_id="$1"
    local health
    health=$(docker inspect --format='{{.State.Health.Status}}' "${container_id}" 2>/dev/null || echo "none")

    # If no healthcheck defined, return "none"
    if [[ "${health}" == "<no value>" ]] || [[ "${health}" == "" ]]; then
        echo "none"
    else
        echo "${health}"
    fi
}

get_container_restart_count() {
    local container_id="$1"
    docker inspect --format='{{.RestartCount}}' "${container_id}" 2>/dev/null || echo "0"
}

get_container_uptime() {
    local container_id="$1"
    local started_at
    started_at=$(docker inspect --format='{{.State.StartedAt}}' "${container_id}" 2>/dev/null)

    if [[ -n "${started_at}" ]]; then
        local start_epoch
        start_epoch=$(date -d "${started_at}" +%s 2>/dev/null || date -j -f "%Y-%m-%dT%H:%M:%S" "${started_at%.*}" +%s 2>/dev/null)
        local now_epoch
        now_epoch=$(date +%s)
        echo $((now_epoch - start_epoch))
    else
        echo "0"
    fi
}

################################################################################
# Resource Monitoring
################################################################################

get_container_stats() {
    local container_id="$1"
    local stats

    # Get CPU and memory stats in one call
    stats=$(docker stats --no-stream --format "{{.CPUPerc}}|{{.MemPerc}}|{{.MemUsage}}" "${container_id}" 2>/dev/null)

    if [[ -n "${stats}" ]]; then
        echo "${stats}"
        return 0
    else
        echo "0.00%|0.00%|0B / 0B"
        return 1
    fi
}

check_resource_usage() {
    local container_id="$1"
    local stats
    local cpu_percent mem_percent mem_usage
    local status=0

    stats=$(get_container_stats "${container_id}")
    IFS='|' read -r cpu_percent mem_percent mem_usage <<< "${stats}"

    # Remove % symbol and convert to integer
    cpu_percent=${cpu_percent%\%}
    mem_percent=${mem_percent%\%}

    # Convert to integer (remove decimals)
    cpu_percent=${cpu_percent%.*}
    mem_percent=${mem_percent%.*}

    # Check CPU usage
    if [[ ${cpu_percent} -ge ${MAX_CPU_PERCENT} ]]; then
        log_critical "CPU usage critical: ${cpu_percent}%"
        status=2
    elif [[ ${cpu_percent} -ge $((MAX_CPU_PERCENT - 10)) ]]; then
        log_warn "CPU usage high: ${cpu_percent}%"
        status=1
    fi

    # Check memory usage
    if [[ ${mem_percent} -ge ${MAX_MEMORY_PERCENT} ]]; then
        log_critical "Memory usage critical: ${mem_percent}% (${mem_usage})"
        status=2
    elif [[ ${mem_percent} -ge $((MAX_MEMORY_PERCENT - 10)) ]]; then
        log_warn "Memory usage high: ${mem_percent}% (${mem_usage})"
        status=1
    fi

    echo "${cpu_percent}|${mem_percent}|${mem_usage}"
    return ${status}
}

################################################################################
# HTTP Health Checks
################################################################################

check_http_endpoint() {
    local container_id="$1"
    local port="${2:-${HTTP_PORT}}"
    local start_time end_time response_time
    local http_code response_body

    # Get container IP
    local container_ip
    container_ip=$(docker inspect --format='{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "${container_id}" | head -1)

    if [[ -z "${container_ip}" ]]; then
        log_error "Could not determine container IP address"
        return ${EXIT_CRITICAL}
    fi

    # Try health endpoint first
    start_time=$(date +%s%3N)
    http_code=$(curl -s -o /dev/null -w "%{http_code}" --max-time ${HTTP_TIMEOUT} "http://${container_ip}:${port}/healthz" 2>/dev/null || echo "000")
    end_time=$(date +%s%3N)
    response_time=$((end_time - start_time))

    # If healthz fails, try root endpoint
    if [[ "${http_code}" == "000" ]] || [[ "${http_code}" == "404" ]]; then
        start_time=$(date +%s%3N)
        http_code=$(curl -s -o /dev/null -w "%{http_code}" --max-time ${HTTP_TIMEOUT} "http://${container_ip}:${port}/" 2>/dev/null || echo "000")
        end_time=$(date +%s%3N)
        response_time=$((end_time - start_time))
    fi

    # Evaluate response
    if [[ "${http_code}" == "000" ]]; then
        log_error "HTTP endpoint unreachable: http://${container_ip}:${port}"
        return ${EXIT_CRITICAL}
    elif [[ "${http_code}" =~ ^5 ]]; then
        log_error "HTTP endpoint returning server error: ${http_code}"
        return ${EXIT_CRITICAL}
    elif [[ "${http_code}" =~ ^[23] ]]; then
        if [[ ${response_time} -gt ${RESPONSE_TIME_CRITICAL} ]]; then
            log_warn "HTTP endpoint responding but slow: ${response_time}ms (HTTP ${http_code})"
            return ${EXIT_WARNING}
        elif [[ ${response_time} -gt ${RESPONSE_TIME_WARNING} ]]; then
            log_warn "HTTP response time elevated: ${response_time}ms (HTTP ${http_code})"
            return ${EXIT_WARNING}
        else
            log_info "HTTP endpoint healthy: ${response_time}ms (HTTP ${http_code})"
            return ${EXIT_SUCCESS}
        fi
    else
        log_warn "HTTP endpoint returning unexpected code: ${http_code}"
        return ${EXIT_WARNING}
    fi
}

################################################################################
# Container Log Analysis
################################################################################

check_container_logs() {
    local container_id="$1"
    local error_count warning_count

    # Check last 100 lines for errors
    local logs
    logs=$(docker logs --tail 100 "${container_id}" 2>&1)

    # Count error patterns
    error_count=$(echo "${logs}" | grep -ci "error\|exception\|fatal\|panic" || echo "0")
    warning_count=$(echo "${logs}" | grep -ci "warning\|warn" || echo "0")

    if [[ ${error_count} -gt 10 ]]; then
        log_critical "High error count in logs: ${error_count} errors in last 100 lines"
        return ${EXIT_CRITICAL}
    elif [[ ${error_count} -gt 5 ]]; then
        log_warn "Elevated error count in logs: ${error_count} errors"
        return ${EXIT_WARNING}
    elif [[ ${warning_count} -gt 20 ]]; then
        log_warn "High warning count in logs: ${warning_count} warnings"
        return ${EXIT_WARNING}
    fi

    log_info "Log analysis: ${error_count} errors, ${warning_count} warnings"
    return ${EXIT_SUCCESS}
}

################################################################################
# State Management
################################################################################

save_state() {
    local container_id="$1"
    local status="$2"
    local timestamp
    timestamp=$(date -Iseconds)

    cat > "${STATE_FILE}" <<EOF
{
  "timestamp": "${timestamp}",
  "container_id": "${container_id}",
  "status": "${status}",
  "checks_performed": {
    "container_status": true,
    "resource_usage": true,
    "http_endpoint": true,
    "log_analysis": true
  }
}
EOF
}

load_previous_state() {
    if [[ -f "${STATE_FILE}" ]]; then
        cat "${STATE_FILE}"
    else
        echo "{}"
    fi
}

################################################################################
# Main Health Check
################################################################################

perform_health_check() {
    local overall_status=${EXIT_SUCCESS}
    local container_id

    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}   N8N Container Health Check$(date +'%Y-%m-%d %H:%M:%S')${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo

    # Detect container
    echo -n "Detecting n8n container... "
    if ! container_id=$(detect_container); then
        echo -e "${RED}FAILED${NC}"
        return ${EXIT_CRITICAL}
    fi
    echo -e "${GREEN}OK${NC} (${container_id:0:12})"

    # Check container status
    echo -n "Checking container status... "
    local status
    status=$(get_container_status "${container_id}")
    if [[ "${status}" != "running" ]]; then
        echo -e "${RED}CRITICAL${NC} (Status: ${status})"
        log_critical "Container is not running: ${status}"
        return ${EXIT_CRITICAL}
    fi
    echo -e "${GREEN}OK${NC} (${status})"

    # Check container health (if defined)
    echo -n "Checking container health... "
    local health
    health=$(get_container_health "${container_id}")
    if [[ "${health}" == "unhealthy" ]]; then
        echo -e "${RED}CRITICAL${NC} (${health})"
        log_critical "Container health check failed"
        overall_status=${EXIT_CRITICAL}
    elif [[ "${health}" == "none" ]]; then
        echo -e "${YELLOW}SKIPPED${NC} (no healthcheck defined)"
    else
        echo -e "${GREEN}OK${NC} (${health})"
    fi

    # Check restart count
    echo -n "Checking restart count... "
    local restart_count
    restart_count=$(get_container_restart_count "${container_id}")
    if [[ ${restart_count} -ge ${CRITICAL_RESTARTS} ]]; then
        echo -e "${RED}CRITICAL${NC} (${restart_count} restarts)"
        log_critical "Excessive restarts detected: ${restart_count}"
        overall_status=${EXIT_CRITICAL}
    elif [[ ${restart_count} -ge ${WARNING_RESTARTS} ]]; then
        echo -e "${YELLOW}WARNING${NC} (${restart_count} restarts)"
        log_warn "Multiple restarts detected: ${restart_count}"
        [[ ${overall_status} -lt ${EXIT_WARNING} ]] && overall_status=${EXIT_WARNING}
    else
        echo -e "${GREEN}OK${NC} (${restart_count} restarts)"
    fi

    # Check uptime
    echo -n "Checking uptime... "
    local uptime
    uptime=$(get_container_uptime "${container_id}")
    if [[ ${uptime} -lt 60 ]]; then
        echo -e "${YELLOW}WARNING${NC} (just started: ${uptime}s)"
        log_warn "Container recently restarted: ${uptime}s uptime"
        [[ ${overall_status} -lt ${EXIT_WARNING} ]] && overall_status=${EXIT_WARNING}
    else
        local uptime_human
        uptime_human=$(printf '%dd %dh %dm' $((uptime/86400)) $((uptime%86400/3600)) $((uptime%3600/60)))
        echo -e "${GREEN}OK${NC} (${uptime_human})"
    fi

    # Check resource usage
    echo -n "Checking resource usage... "
    local resource_status
    if ! check_resource_usage "${container_id}" >/dev/null; then
        resource_status=$?
        if [[ ${resource_status} -eq ${EXIT_CRITICAL} ]]; then
            echo -e "${RED}CRITICAL${NC}"
            overall_status=${EXIT_CRITICAL}
        else
            echo -e "${YELLOW}WARNING${NC}"
            [[ ${overall_status} -lt ${EXIT_WARNING} ]] && overall_status=${EXIT_WARNING}
        fi
    else
        echo -e "${GREEN}OK${NC}"
    fi

    # Check HTTP endpoint
    echo -n "Checking HTTP endpoint... "
    if ! check_http_endpoint "${container_id}"; then
        http_status=$?
        if [[ ${http_status} -eq ${EXIT_CRITICAL} ]]; then
            echo -e "${RED}CRITICAL${NC}"
            overall_status=${EXIT_CRITICAL}
        else
            echo -e "${YELLOW}WARNING${NC}"
            [[ ${overall_status} -lt ${EXIT_WARNING} ]] && overall_status=${EXIT_WARNING}
        fi
    else
        echo -e "${GREEN}OK${NC}"
    fi

    # Check container logs
    echo -n "Analyzing container logs... "
    if ! check_container_logs "${container_id}"; then
        log_status=$?
        if [[ ${log_status} -eq ${EXIT_CRITICAL} ]]; then
            echo -e "${RED}CRITICAL${NC}"
            overall_status=${EXIT_CRITICAL}
        else
            echo -e "${YELLOW}WARNING${NC}"
            [[ ${overall_status} -lt ${EXIT_WARNING} ]] && overall_status=${EXIT_WARNING}
        fi
    else
        echo -e "${GREEN}OK${NC}"
    fi

    echo
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"

    # Overall status
    case ${overall_status} in
        ${EXIT_SUCCESS})
            echo -e "${GREEN}Overall Status: HEALTHY${NC}"
            save_state "${container_id}" "healthy"
            ;;
        ${EXIT_WARNING})
            echo -e "${YELLOW}Overall Status: WARNING${NC}"
            save_state "${container_id}" "warning"
            ;;
        ${EXIT_CRITICAL})
            echo -e "${RED}Overall Status: CRITICAL${NC}"
            save_state "${container_id}" "critical"
            ;;
        *)
            echo -e "${RED}Overall Status: UNKNOWN${NC}"
            save_state "${container_id}" "unknown"
            ;;
    esac

    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo

    return ${overall_status}
}

################################################################################
# Main Entry Point
################################################################################

main() {
    init_logging

    log_info "Starting health check for container: ${CONTAINER_NAME}"

    if perform_health_check; then
        log_info "Health check completed: HEALTHY"
        exit ${EXIT_SUCCESS}
    else
        local exit_code=$?
        case ${exit_code} in
            ${EXIT_WARNING})
                log_warn "Health check completed: WARNING"
                ;;
            ${EXIT_CRITICAL})
                log_critical "Health check completed: CRITICAL"
                ;;
            *)
                log_error "Health check completed: UNKNOWN"
                ;;
        esac
        exit ${exit_code}
    fi
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
