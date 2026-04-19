#!/bin/bash

################################################################################
# N8N Auto Recovery Script
# Purpose: Automatic restart with exponential backoff and safety limits
# Features: Smart restart logic, cooldown periods, incident tracking
# Compatible: Proxmox LXC, Docker, Docker Compose
# Author: Hive Mind Coder Agent
################################################################################

set -euo pipefail

# Configuration
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly LOG_DIR="/var/log/n8n-monitoring"
readonly LOG_FILE="${LOG_DIR}/auto_recovery.log"
readonly STATE_DIR="${LOG_DIR}/recovery_state"
readonly INCIDENT_LOG="${LOG_DIR}/incidents.log"
readonly CONTAINER_NAME="${N8N_CONTAINER_NAME:-n8n}"

# Safety limits
readonly MAX_RESTARTS_PER_HOUR=5
readonly MAX_RESTARTS_PER_DAY=20
readonly COOLDOWN_AFTER_MAX_RESTARTS=3600  # 1 hour in seconds
readonly CIRCUIT_BREAKER_THRESHOLD=10       # Total failures before stopping
readonly CIRCUIT_BREAKER_RESET_TIME=86400   # 24 hours

# Backoff configuration
readonly INITIAL_BACKOFF=10           # seconds
readonly MAX_BACKOFF=600             # 10 minutes max
readonly BACKOFF_MULTIPLIER=2

# Restart strategy
readonly RESTART_TIMEOUT=30          # Timeout for container stop
readonly HEALTH_CHECK_RETRIES=3
readonly HEALTH_CHECK_INTERVAL=10

# Color codes
readonly RED='\033[0;31m'
readonly YELLOW='\033[1;33m'
readonly GREEN='\033[0;32m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m'

################################################################################
# Logging Functions
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

log_incident() {
    local incident_type="$1"
    local details="$2"
    local timestamp
    timestamp=$(date -Iseconds)

    echo "${timestamp}|${incident_type}|${details}" >> "${INCIDENT_LOG}"
    log_warn "INCIDENT: ${incident_type} - ${details}"
}

init_logging() {
    mkdir -p "${LOG_DIR}" "${STATE_DIR}"
    touch "${LOG_FILE}" "${INCIDENT_LOG}"
}

################################################################################
# State Management
################################################################################

get_restart_count_in_window() {
    local window_seconds="$1"
    local cutoff_time
    cutoff_time=$(($(date +%s) - window_seconds))

    if [[ ! -f "${STATE_DIR}/restart_history.log" ]]; then
        echo "0"
        return
    fi

    local count=0
    while IFS='|' read -r timestamp status; do
        if [[ ${timestamp} -gt ${cutoff_time} ]]; then
            ((count++))
        fi
    done < "${STATE_DIR}/restart_history.log"

    echo "${count}"
}

record_restart_attempt() {
    local status="$1"
    local timestamp
    timestamp=$(date +%s)

    echo "${timestamp}|${status}" >> "${STATE_DIR}/restart_history.log"

    # Keep only last 100 entries
    if [[ $(wc -l < "${STATE_DIR}/restart_history.log") -gt 100 ]]; then
        tail -100 "${STATE_DIR}/restart_history.log" > "${STATE_DIR}/restart_history.log.tmp"
        mv "${STATE_DIR}/restart_history.log.tmp" "${STATE_DIR}/restart_history.log"
    fi
}

get_circuit_breaker_state() {
    local state_file="${STATE_DIR}/circuit_breaker.state"

    if [[ ! -f "${state_file}" ]]; then
        echo "closed|0|0"
        return
    fi

    cat "${state_file}"
}

update_circuit_breaker() {
    local action="$1"  # failure, success, or reset
    local state_file="${STATE_DIR}/circuit_breaker.state"

    IFS='|' read -r state failure_count last_failure <<< "$(get_circuit_breaker_state)"

    local now
    now=$(date +%s)

    case "${action}" in
        failure)
            ((failure_count++))
            last_failure=${now}

            if [[ ${failure_count} -ge ${CIRCUIT_BREAKER_THRESHOLD} ]]; then
                state="open"
                log_critical "Circuit breaker OPENED after ${failure_count} failures"
                log_incident "CIRCUIT_BREAKER_OPEN" "Failures: ${failure_count}"
            fi
            ;;
        success)
            if [[ ${state} == "half-open" ]]; then
                state="closed"
                failure_count=0
                log_info "Circuit breaker CLOSED after successful recovery"
            elif [[ ${failure_count} -gt 0 ]]; then
                ((failure_count--))
            fi
            ;;
        reset)
            state="closed"
            failure_count=0
            last_failure=0
            log_info "Circuit breaker manually RESET"
            ;;
    esac

    # Auto-reset after cooldown
    if [[ ${state} == "open" ]] && [[ $((now - last_failure)) -gt ${CIRCUIT_BREAKER_RESET_TIME} ]]; then
        state="half-open"
        log_info "Circuit breaker moved to HALF-OPEN state after cooldown"
    fi

    echo "${state}|${failure_count}|${last_failure}" > "${state_file}"
    echo "${state}"
}

get_backoff_time() {
    local consecutive_failures="$1"
    local backoff=${INITIAL_BACKOFF}

    for ((i=1; i<consecutive_failures; i++)); do
        backoff=$((backoff * BACKOFF_MULTIPLIER))
        if [[ ${backoff} -gt ${MAX_BACKOFF} ]]; then
            backoff=${MAX_BACKOFF}
            break
        fi
    done

    echo "${backoff}"
}

################################################################################
# Container Operations
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

    if [[ -z "${container_id}" ]]; then
        log_error "N8N container not found"
        return 1
    fi

    echo "${container_id}"
}

get_container_status() {
    local container_id="$1"
    docker inspect --format='{{.State.Status}}' "${container_id}" 2>/dev/null || echo "unknown"
}

stop_container_gracefully() {
    local container_id="$1"
    local status

    log_info "Stopping container gracefully (timeout: ${RESTART_TIMEOUT}s)..."

    if docker stop -t "${RESTART_TIMEOUT}" "${container_id}" 2>/dev/null; then
        log_info "Container stopped successfully"
        return 0
    else
        log_warn "Graceful stop failed, forcing stop..."
        if docker kill "${container_id}" 2>/dev/null; then
            log_warn "Container force-stopped"
            return 0
        else
            log_error "Failed to stop container"
            return 1
        fi
    fi
}

start_container() {
    local container_id="$1"

    log_info "Starting container..."

    if docker start "${container_id}" 2>/dev/null; then
        log_info "Container start command successful"
        return 0
    else
        log_error "Failed to start container"
        return 1
    fi
}

wait_for_healthy_state() {
    local container_id="$1"
    local max_attempts=${HEALTH_CHECK_RETRIES}
    local interval=${HEALTH_CHECK_INTERVAL}

    log_info "Waiting for container to become healthy..."

    for ((attempt=1; attempt<=max_attempts; attempt++)); do
        log_info "Health check attempt ${attempt}/${max_attempts}..."

        sleep "${interval}"

        # Check if container is still running
        local status
        status=$(get_container_status "${container_id}")

        if [[ "${status}" != "running" ]]; then
            log_error "Container stopped unexpectedly (status: ${status})"
            return 1
        fi

        # Run health check script
        if "${SCRIPT_DIR}/check_n8n_health.sh" >/dev/null 2>&1; then
            log_info "Container is healthy!"
            return 0
        else
            log_warn "Health check failed on attempt ${attempt}"
        fi
    done

    log_error "Container failed to become healthy after ${max_attempts} attempts"
    return 1
}

################################################################################
# Restart Logic
################################################################################

check_restart_limits() {
    local restarts_hour
    local restarts_day

    restarts_hour=$(get_restart_count_in_window 3600)
    restarts_day=$(get_restart_count_in_window 86400)

    log_info "Restart counts: ${restarts_hour}/hour, ${restarts_day}/day"

    if [[ ${restarts_hour} -ge ${MAX_RESTARTS_PER_HOUR} ]]; then
        log_critical "Maximum restarts per hour exceeded (${restarts_hour}/${MAX_RESTARTS_PER_HOUR})"
        log_incident "MAX_RESTARTS_HOUR" "Count: ${restarts_hour}"
        return 1
    fi

    if [[ ${restarts_day} -ge ${MAX_RESTARTS_PER_DAY} ]]; then
        log_critical "Maximum restarts per day exceeded (${restarts_day}/${MAX_RESTARTS_PER_DAY})"
        log_incident "MAX_RESTARTS_DAY" "Count: ${restarts_day}"
        return 1
    fi

    return 0
}

perform_restart() {
    local container_id="$1"
    local consecutive_failures="${2:-1}"

    echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}   N8N Auto Recovery - Restart Attempt$(date +'%Y-%m-%d %H:%M:%S')${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"

    # Check circuit breaker
    local cb_state
    cb_state=$(update_circuit_breaker "check")

    if [[ "${cb_state}" == "open" ]]; then
        log_critical "Circuit breaker is OPEN - recovery attempts suspended"
        echo -e "${RED}Circuit breaker OPEN - system in protective mode${NC}"
        echo -e "${YELLOW}Manual intervention required or wait for auto-reset${NC}"
        return 2
    fi

    # Check restart limits
    if ! check_restart_limits; then
        echo -e "${RED}Restart limits exceeded - aborting${NC}"
        return 2
    fi

    # Calculate backoff
    local backoff
    backoff=$(get_backoff_time "${consecutive_failures}")

    if [[ ${consecutive_failures} -gt 1 ]]; then
        log_info "Applying exponential backoff: ${backoff}s (attempt ${consecutive_failures})"
        echo -e "${YELLOW}Waiting ${backoff}s before restart (exponential backoff)...${NC}"
        sleep "${backoff}"
    fi

    # Perform restart
    log_info "Attempting container restart..."
    record_restart_attempt "attempt"

    # Stop container
    if ! stop_container_gracefully "${container_id}"; then
        log_error "Failed to stop container"
        update_circuit_breaker "failure"
        record_restart_attempt "failed_stop"
        return 1
    fi

    # Wait a moment
    sleep 2

    # Start container
    if ! start_container "${container_id}"; then
        log_error "Failed to start container"
        update_circuit_breaker "failure"
        record_restart_attempt "failed_start"
        return 1
    fi

    # Wait for healthy state
    if ! wait_for_healthy_state "${container_id}"; then
        log_error "Container failed health checks after restart"
        update_circuit_breaker "failure"
        record_restart_attempt "failed_health"
        return 1
    fi

    # Success!
    log_info "Container restarted successfully and is healthy"
    update_circuit_breaker "success"
    record_restart_attempt "success"

    echo -e "${GREEN}✓ Recovery successful!${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"

    return 0
}

################################################################################
# Main Recovery Logic
################################################################################

main() {
    init_logging

    log_info "Auto recovery script started"

    # Detect container
    local container_id
    if ! container_id=$(detect_container); then
        log_error "Cannot proceed without container"
        exit 1
    fi

    log_info "Target container: ${container_id:0:12}"

    # Check current status
    local status
    status=$(get_container_status "${container_id}")

    log_info "Current container status: ${status}"

    if [[ "${status}" == "running" ]]; then
        log_info "Container is running, performing health check..."

        if "${SCRIPT_DIR}/check_n8n_health.sh" >/dev/null 2>&1; then
            log_info "Container is healthy, no recovery needed"
            exit 0
        else
            log_warn "Container is running but unhealthy"
            log_incident "UNHEALTHY_STATE" "Container running but failing health checks"
        fi
    else
        log_error "Container is not running (status: ${status})"
        log_incident "CONTAINER_DOWN" "Status: ${status}"
    fi

    # Attempt recovery
    local consecutive_failures=1
    local max_immediate_retries=3

    for ((retry=1; retry<=max_immediate_retries; retry++)); do
        log_info "Recovery attempt ${retry}/${max_immediate_retries}"

        if perform_restart "${container_id}" "${consecutive_failures}"; then
            log_info "Recovery successful on attempt ${retry}"
            exit 0
        else
            local restart_result=$?

            if [[ ${restart_result} -eq 2 ]]; then
                log_critical "Recovery aborted due to safety limits"
                exit 2
            fi

            log_warn "Recovery attempt ${retry} failed"
            ((consecutive_failures++))

            if [[ ${retry} -lt ${max_immediate_retries} ]]; then
                log_info "Will retry recovery..."
            fi
        fi
    done

    log_critical "All recovery attempts failed"
    log_incident "RECOVERY_FAILED" "Failed after ${max_immediate_retries} attempts"

    echo -e "${RED}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${RED}   Recovery Failed - Manual Intervention Required${NC}"
    echo -e "${RED}═══════════════════════════════════════════════════════════${NC}"

    exit 1
}

# Allow manual circuit breaker reset
if [[ "${1:-}" == "--reset-circuit-breaker" ]]; then
    init_logging
    update_circuit_breaker "reset"
    echo "Circuit breaker reset successfully"
    exit 0
fi

# Allow status check
if [[ "${1:-}" == "--status" ]]; then
    init_logging
    echo "=== Recovery System Status ==="
    echo
    echo "Restart counts:"
    echo "  Last hour: $(get_restart_count_in_window 3600)"
    echo "  Last day: $(get_restart_count_in_window 86400)"
    echo
    IFS='|' read -r cb_state cb_failures cb_last_fail <<< "$(get_circuit_breaker_state)"
    echo "Circuit breaker:"
    echo "  State: ${cb_state}"
    echo "  Failures: ${cb_failures}"
    if [[ ${cb_last_fail} -gt 0 ]]; then
        echo "  Last failure: $(date -d "@${cb_last_fail}" 2>/dev/null || date -r "${cb_last_fail}")"
    fi
    exit 0
fi

# Run main recovery
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
