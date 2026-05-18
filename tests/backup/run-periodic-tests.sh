#!/bin/bash
# =============================================================================
# Periodic Backup Restoration Testing
# =============================================================================
# Scheduled automated restoration tests to verify backup integrity
# Runs periodically (configured via cron/systemd timer)
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$(dirname "$SCRIPT_DIR")")")"
BACKUP_ROOT="${BACKUP_ROOT:-/mnt/shares/agl-hostman-backups}"
LOG_DIR="${BACKUP_ROOT}/logs"
REPORT_DIR="${BACKUP_ROOT}/test-restorations"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_FILE="${LOG_DIR}/periodic-test-${TIMESTAMP}.log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Ensure directories exist
mkdir -p "${LOG_DIR}"
mkdir -p "${REPORT_DIR}"

# Logging function
log() {
    local level=$1
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${timestamp} [${level}] ${message}" | tee -a "${LOG_FILE}"
}

log_info() {
    log "INFO" "${BLUE}$*${NC}"
}

log_success() {
    log "SUCCESS" "${GREEN}$*${NC}"
}

log_error() {
    log "ERROR" "${RED}$*${NC}"
}

log_warning() {
    log "WARNING" "${YELLOW}$*${NC}"
}

# Send alert on failure
send_alert() {
    local subject=$1
    local message=$2
    local alert_file="${REPORT_DIR}/alert-${TIMESTAMP}.txt"

    echo "SUBJECT: ${subject}" > "${alert_file}"
    echo "DATE: $(date)" >> "${alert_file}"
    echo "" >> "${alert_file}"
    echo "${message}" >> "${alert_file}"

    # Email alert if configured
    if command -v mail &> /dev/null && [[ -n "${ALERT_EMAIL:-}" ]]; then
        mail -s "[BACKUP TEST ALERT] ${subject}" "${ALERT_EMAIL}" < "${alert_file}" 2>/dev/null || true
    fi

    # Slack alert if configured
    if [[ -n "${SLACK_WEBHOOK:-}" ]]; then
        curl -X POST -H 'Content-type: application/json' \
            --data "{\"text\":\"[${subject}] ${message}\"}" \
            "${SLACK_WEBHOOK}" 2>/dev/null || true
    fi
}

# Main execution
main() {
    local start_time=$(date +%s)

    log_info "=========================================="
    log_info "Periodic Backup Restoration Test"
    log_info "=========================================="
    log_info "Timestamp: ${TIMESTAMP}"
    log_info "Log file: ${LOG_FILE}"

    cd "${SCRIPT_DIR}"

    # Run Python verification
    log_info "Running Python restoration tests..."
    if python3 verify_restoration.py >> "${LOG_FILE}" 2>&1; then
        log_success "Python tests passed"
        python_status=0
    else
        log_error "Python tests failed"
        python_status=1
    fi

    # Run Bash tests
    log_info "Running Bash restoration tests..."
    if bash test_restoration.sh >> "${LOG_FILE}" 2>&1; then
        log_success "Bash tests passed"
        bash_status=0
    else
        log_error "Bash tests failed"
        bash_status=1
    fi

    # Calculate duration
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    local minutes=$((duration / 60))
    local seconds=$((duration % 60))

    log_info "=========================================="
    log_info "Test completed in ${minutes}m ${seconds}s"
    log_info "=========================================="

    # Check overall status
    if [[ $python_status -eq 0 && $bash_status -eq 0 ]]; then
        log_success "All periodic tests PASSED"
        exit 0
    else
        log_error "Some periodic tests FAILED"

        # Send alert
        local alert_message="Periodic backup restoration test failed at $(date).\n\n"
        alert_message+="Python tests: $([ $python_status -eq 0 ] && echo 'PASSED' || echo 'FAILED')\n"
        alert_message+="Bash tests: $([ $bash_status -eq 0 ] && echo 'PASSED' || echo 'FAILED')\n\n"
        alert_message+="Log file: ${LOG_FILE}"

        send_alert "Backup Test Failed" "${alert_message}"

        exit 1
    fi
}

# Run main
main "$@"
