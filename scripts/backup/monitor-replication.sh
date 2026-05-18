#!/bin/bash
# Offsite Backup Replication Monitoring Script
# Purpose: Monitor backup replication status, generate alerts, and track health
#
# Usage:
#   ./monitor-replication.sh                       # Run health check
#   ./monitor-replication.sh --prometheus          # Output Prometheus metrics
#   ./monitor-replication.sh --json                # Output JSON format
#   ./monitor-replication.sh --email               # Send email report
#   ./monitor-replication.sh --slack               # Send Slack notification
#
# Cron scheduling (recommended):
#   */15 * * * * /path/to/monitor-replication.sh    # Every 15 minutes
#   0 */6 * * * /path/to/monitor-replication.sh --email  # Every 6 hours

set -euo pipefail

# ============================================================================
# CONFIGURATION
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/replication-config.env"
LOG_DIR="/var/log/backup-replication"
METRICS_FILE="${LOG_DIR}/replication-metrics.json"
STATE_FILE="${LOG_DIR}/replication-state.json"
ALERT_LOG="${LOG_DIR}/alerts.log"

# Thresholds
MAX_BACKUP_AGE_HOURS=26  # Maximum backup age (26 hours = daily + grace)
MIN_DISK_SPACE_GB=100     # Minimum disk space required
MAX_REPLICATION_TIME_MINUTES=120  # Maximum replication time
MAX_FAILURE_COUNT=3       # Maximum consecutive failures before alert

# Notification settings
ALERT_EMAIL=""
SLACK_WEBHOOK=""
HEALTH_CHECK_URL=""

# Load configuration
if [[ -f "${CONFIG_FILE}" ]]; then
    # shellcheck source=/dev/null
    source "${CONFIG_FILE}"
fi

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

log_alert() {
    local message="$1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ALERT] ${message}" | tee -a "${ALERT_LOG}"
}

# ============================================================================
# STATE MANAGEMENT
# ============================================================================

load_state() {
    if [[ -f "${STATE_FILE}" ]]; then
        cat "${STATE_FILE}"
    else
        echo '{"consecutive_failures":0,"last_success":null,"last_check":null}'
    fi
}

save_state() {
    local state="$1"
    mkdir -p "${LOG_DIR}"
    echo "${state}" > "${STATE_FILE}"
}

# ============================================================================
# CHECK FUNCTIONS
# ============================================================================

check_backup_age() {
    local backup_path="$1"
    local max_age_hours="$2"

    if [[ ! -d "${backup_path}" ]]; then
        echo '{"status":"error","message":"Directory not found","path":"'${backup_path}'"}'
        return 1
    fi

    local newest_file
    newest_file=$(find "${backup_path}" -type f \( -name "*.sql.gz" -o -name "*.tar.gz" -o -name "*.vma.zst" -o -name "*.zst" \) -printf '%T@ %p\n' 2>/dev/null | sort -rn | head -1 | cut -d' ' -f2-)

    if [[ -z "${newest_file}" ]]; then
        echo '{"status":"error","message":"No backup files found","path":"'${backup_path}'"}'
        return 1
    fi

    local backup_age_seconds
    backup_age_seconds=$(($(date +%s) - $(stat -c %Y "${newest_file}")))
    local backup_age_hours=$((backup_age_seconds / 3600))

    local status="ok"
    local message="Backup age: ${backup_age_hours}h (max: ${max_age_hours}h)"

    if [[ ${backup_age_hours} -gt ${max_age_hours} ]]; then
        status="critical"
        message="Backup too old: ${backup_age_hours}h (max: ${max_age_hours}h)"
    elif [[ ${backup_age_hours} -gt $((max_age_hours - 6)) ]]; then
        status="warning"
        message="Backup aging: ${backup_age_hours}h (max: ${max_age_hours}h)"
    fi

    echo "{\"status\":\"${status}\",\"message\":\"${message}\",\"age_hours\":${backup_age_hours},\"max_age_hours\":${max_age_hours},\"path\":\"${backup_path}\",\"newest_file\":\"${newest_file}\"}"

    [[ "${status}" == "ok" ]]
}

check_disk_space() {
    local mount_point="$1"
    local min_space_gb="$2"

    if [[ ! -d "${mount_point}" ]]; then
        echo '{"status":"error","message":"Mount point not found"}'
        return 1
    fi

    local available_gb
    available_gb=$(df -BG "${mount_point}" | awk 'NR==2 {print $4}' | sed 's/G//')

    local status="ok"
    local message="Disk space: ${available_gb}GB available"

    if [[ ${available_gb} -lt ${min_space_gb} ]]; then
        status="critical"
        message="Low disk space: ${available_gb}GB (min: ${min_space_gb}GB)"
    elif [[ ${available_gb} -lt $((min_space_gb * 2)) ]]; then
        status="warning"
        message="Disk space warning: ${available_gb}GB (min: ${min_space_gb}GB)"
    fi

    echo "{\"status\":\"${status}\",\"message\":\"${message}\",\"available_gb\":${available_gb},\"min_space_gb\":${min_space_gb},\"mount_point\":\"${mount_point}\"}"

    [[ "${status}" == "ok" ]]
}

check_replication_status() {
    local log_dir="$1"
    local max_time_minutes="$2"

    if [[ ! -d "${log_dir}" ]]; then
        echo '{"status":"error","message":"Log directory not found"}'
        return 1
    fi

    local latest_log
    latest_log=$(find "${log_dir}" -name "replication-*.log" -type f -printf '%T@ %p\n' 2>/dev/null | sort -rn | head -1 | cut -d' ' -f2-)

    if [[ -z "${latest_log}" ]]; then
        echo '{"status":"warning","message":"No replication logs found"}'
        return 1
    fi

    local replication_age_seconds
    replication_age_seconds=$(($(date +%s) - $(stat -c %Y "${latest_log}")))
    local replication_age_minutes=$((replication_age_seconds / 60))

    # Check last replication status
    local last_status="unknown"
    if grep -q "SUCCESS" "${latest_log}" 2>/dev/null; then
        last_status="success"
    elif grep -q "FAILED" "${latest_log}" 2>/dev/null; then
        last_status="failed"
    fi

    local status="ok"
    local message="Last replication: ${replication_age_minutes}m ago (${last_status})"

    if [[ "${last_status}" == "failed" ]] || [[ ${replication_age_minutes} -gt ${max_time_minutes} ]]; then
        status="critical"
        message="Replication issue: ${replication_age_minutes}m ago (${last_status})"
    elif [[ ${replication_age_minutes} -gt $((max_time_minutes / 2)) ]]; then
        status="warning"
        message="Replication overdue: ${replication_age_minutes}m ago (${last_status})"
    fi

    echo "{\"status\":\"${status}\",\"message\":\"${message}\",\"age_minutes\":${replication_age_minutes},\"max_age_minutes\":${max_time_minutes},\"last_status\":\"${last_status}\"}"

    [[ "${status}" == "ok" ]]
}

check_offsite_connectivity() {
    local host="$1"
    local port="$2"

    if command -v nc >/dev/null 2>&1; then
        if nc -z -w5 "${host}" "${port}" 2>/dev/null; then
            echo '{"status":"ok","message":"Connection successful","host":"'${host}'","port":'${port}'}'
            return 0
        fi
    fi

    if command -v timeout >/dev/null 2>&1; then
        if timeout 5 bash -c "cat < /dev/null > /dev/tcp/${host}/${port}" 2>/dev/null; then
            echo '{"status":"ok","message":"Connection successful","host":"'${host}'","port":'${port}'}'
            return 0
        fi
    fi

    echo '{"status":"error","message":"Connection failed","host":"'${host}'","port":'${port}'}'
    return 1
}

# ============================================================================
# COMPREHENSIVE HEALTH CHECK
# ============================================================================

run_health_check() {
    local results=()
    local overall_status="ok"

    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}  Replication Health Check${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""

    # Check backup ages
    echo "Checking backup ages..."

    if [[ -d "${BACKUP_SOURCE_LOCAL}" ]]; then
        local result
        result=$(check_backup_age "${BACKUP_SOURCE_LOCAL}/daily" ${MAX_BACKUP_AGE_HOURS})
        results+=("${result}")

        local status
        status=$(echo "${result}" | jq -r '.status')
        local message
        message=$(echo "${result}" | jq -r '.message')

        if [[ "${status}" == "critical" ]]; then
            echo -e "  ${RED}[CRITICAL]${NC} ${message}"
            overall_status="critical"
        elif [[ "${status}" == "warning" ]]; then
            echo -e "  ${YELLOW}[WARNING]${NC} ${message}"
            [[ "${overall_status}" != "critical" ]] && overall_status="warning"
        else
            echo -e "  ${GREEN}[OK]${NC} ${message}"
        fi
    fi

    # Check Proxmox backups
    if [[ -d "${BACKUP_SOURCE_PROXMOX}" ]]; then
        local result
        result=$(check_backup_age "${BACKUP_SOURCE_PROXMOX}" 48)
        results+=("${result}")

        local status
        status=$(echo "${result}" | jq -r '.status')
        local message
        message=$(echo "${result}" | jq -r '.message')

        if [[ "${status}" == "critical" ]]; then
            echo -e "  ${RED}[CRITICAL]${NC} Proxmox: ${message}"
            overall_status="critical"
        elif [[ "${status}" == "warning" ]]; then
            echo -e "  ${YELLOW}[WARNING]${NC} Proxmox: ${message}"
            [[ "${overall_status}" != "critical" ]] && overall_status="warning"
        else
            echo -e "  ${GREEN}[OK]${NC} Proxmox: ${message}"
        fi
    fi

    echo ""

    # Check disk space
    echo "Checking disk space..."

    for mount in /spark /mnt/shares; do
        if [[ -d "${mount}" ]]; then
            local result
            result=$(check_disk_space "${mount}" ${MIN_DISK_SPACE_GB})
            results+=("${result}")

            local status
            status=$(echo "${result}" | jq -r '.status')
            local message
            message=$(echo "${result}" | jq -r '.message')

            if [[ "${status}" == "critical" ]]; then
                echo -e "  ${RED}[CRITICAL]${NC} ${mount}: ${message}"
                overall_status="critical"
            elif [[ "${status}" == "warning" ]]; then
                echo -e "  ${YELLOW}[WARNING]${NC} ${mount}: ${message}"
                [[ "${overall_status}" != "critical" ]] && overall_status="warning"
            else
                echo -e "  ${GREEN}[OK]${NC} ${mount}: ${message}"
            fi
        fi
    done

    echo ""

    # Check replication status
    echo "Checking replication status..."

    local result
    result=$(check_replication_status "${LOG_DIR}" ${MAX_REPLICATION_TIME_MINUTES})
    results+=("${result}")

    local status
    status=$(echo "${result}" | jq -r '.status')
    local message
    message=$(echo "${result}" | jq -r '.message')

    if [[ "${status}" == "critical" ]]; then
        echo -e "  ${RED}[CRITICAL]${NC} ${message}"
        overall_status="critical"
    elif [[ "${status}" == "warning" ]]; then
        echo -e "  ${YELLOW}[WARNING]${NC} ${message}"
        [[ "${overall_status}" != "critical" ]] && overall_status="warning"
    else
        echo -e "  ${GREEN}[OK]${NC} ${message}"
    fi

    echo ""

    # Check offsite connectivity
    echo "Checking offsite connectivity..."

    if [[ -n "${HETZNER_HOST}" ]]; then
        local result
        result=$(check_offsite_connectivity "${HETZNER_HOST}" ${HETZNER_PORT:-23})
        results+=("${result}")

        local status
        status=$(echo "${result}" | jq -r '.status')
        local message
        message=$(echo "${result}" | jq -r '.message')

        if [[ "${status}" == "error" ]]; then
            echo -e "  ${RED}[ERROR]${NC} Hetzner: ${message}"
            [[ "${overall_status}" != "critical" ]] && overall_status="warning"
        else
            echo -e "  ${GREEN}[OK]${NC} Hetzner: ${message}"
        fi
    fi

    # Check rclone connectivity (B2)
    if command -v rclone >/dev/null 2>&1 && [[ -n "${B2_BUCKET}" ]]; then
        if rclone lsd "${B2_BUCKET}:" --config /dev/null 2>&1 | grep -q "config" || \
           timeout 10 rclone lsd "${B2_BUCKET}:" 2>/dev/null >/dev/null; then
            echo -e "  ${GREEN}[OK]${NC} Backblaze B2: Connection successful"
        else
            echo -e "  ${YELLOW}[WARNING]${NC} Backblaze B2: Connection check requires configuration"
        fi
    fi

    echo ""

    # Overall status
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}  Overall Status: ${overall_status^^}${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""

    # Save metrics
    local metrics_json
    metrics_json=$(echo "${results[@]}" | jq -s 'add' 2>/dev/null || echo '[]')
    echo "${metrics_json}" > "${METRICS_FILE}"

    # Update state
    local current_state
    current_state=$(load_state)

    if [[ "${overall_status}" == "ok" ]]; then
        # Reset failure count on success
        current_state=$(echo "${current_state}" | jq '.consecutive_failures = 0 | .last_success = "'$(date -Iseconds)'"')
    else
        # Increment failure count
        local fail_count
        fail_count=$(echo "${current_state}" | jq '.consecutive_failures + 1')
        current_state=$(echo "${current_state}" | jq ".consecutive_failures = ${fail_count}")
    fi

    current_state=$(echo "${current_state}" | jq '.last_check = "'$(date -Iseconds)'"')
    save_state "${current_state}"

    # Trigger alert if needed
    local fail_count
    fail_count=$(echo "${current_state}" | jq '.consecutive_failures')

    if [[ ${fail_count} -ge ${MAX_FAILURE_COUNT} ]] || [[ "${overall_status}" == "critical" ]]; then
        log_alert "Health check failed: ${overall_status} (consecutive failures: ${fail_count})"
        return 1
    fi

    return 0
}

# ============================================================================
# OUTPUT FORMATS
# ============================================================================

output_prometheus() {
    local metrics_json="$1"

    cat << EOF
# HELP backup_replication_status Backup replication health status (0=ok, 1=warning, 2=critical)
# TYPE backup_replication_status gauge
backup_replication_status{overall="$([[ -f "${METRICS_FILE}" ]] && jq -r '.[0].status // "unknown' "${METRICS_FILE}")"} $([[ "${overall_status}" == "ok" ]] && echo 0 || [[ "${overall_status}" == "warning" ]] && echo 1 || echo 2)

# HELP backup_replication_last_success_seconds Unix timestamp of last successful replication
# TYPE backup_replication_last_success_seconds gauge
backup_replication_last_success_seconds $(echo "${current_state}" | jq '.last_success // 0 | fromdateiso8601? // 0')

# HELP backup_replication_consecutive_failures Number of consecutive failed replications
# TYPE backup_replication_consecutive_failures gauge
backup_replication_consecutive_failures ${fail_count:-0}

# HELP backup_replication_check_timestamp_seconds Unix timestamp of last health check
# TYPE backup_replication_check_timestamp_seconds gauge
backup_replication_check_timestamp_seconds $(date +%s)
EOF
}

output_json() {
    local current_state
    current_state=$(load_state)

    cat << EOF
{
  "timestamp": "$(date -Iseconds)",
  "overall_status": "${overall_status}",
  "checks": $(cat "${METRICS_FILE}" 2>/dev/null || echo '[]'),
  "state": ${current_state}
}
EOF
}

# ============================================================================
# NOTIFICATION FUNCTIONS
# ============================================================================

send_email_alert() {
    local status="$1"
    local message="$2"

    if [[ -z "${ALERT_EMAIL}" ]]; then
        return 0
    fi

    if ! command -v mail >/dev/null 2>&1; then
        echo "Email command not found. Install with: apt-get install mailutils"
        return 1
    fi

    local subject="[Backup Replication] ${status^^} Alert"
    local body="Time: $(date)\nStatus: ${status}\n\n${message}\n\nLog file: ${ALERT_LOG}"

    echo -e "${body}" | mail -s "${subject}" "${ALERT_EMAIL}"
}

send_slack_alert() {
    local status="$1"
    local message="$2"

    if [[ -z "${SLACK_WEBHOOK}" ]]; then
        return 0
    fi

    if ! command -v curl >/dev/null 2>&1; then
        echo "curl command not found"
        return 1
    fi

    local color="good"
    [[ "${status}" == "critical" ]] && color="danger"
    [[ "${status}" == "warning" ]] && color="warning"

    curl -X POST "${SLACK_WEBHOOK}" \
        -H 'Content-Type: application/json' \
        -d "{
            \"attachments\": [{
                \"color\": \"${color}\",
                \"title\": \"Backup Replication Alert: ${status^^}\",
                \"text\": \"${message}\",
                \"footer\": \"AGL Backup Replication Monitor\",
                \"ts\": $(date +%s)
            }]
        }" >/dev/null 2>&1
}

send_health_check() {
    local status="$1"

    if [[ -z "${HEALTH_CHECK_URL}" ]]; then
        return 0
    fi

    if ! command -v curl >/dev/null 2>&1; then
        return 1
    fi

    local url="${HEALTH_CHECK_URL}"
    [[ "${status}" != "ok" ]] && url="${url}/fail"

    curl -fsS -m 5 "${url}" >/dev/null 2>&1
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

show_usage() {
    cat << EOF
Offsite Backup Replication Monitoring Script

Usage: $0 [OPTIONS]

Options:
    --prometheus        Output Prometheus metrics format
    --json              Output JSON format
    --email             Send email report
    --slack             Send Slack notification
    --verbose           Show detailed output
    -h, --help          Show this help message

Examples:
    $0                              # Run health check
    $0 --prometheus                 # Output metrics for Prometheus
    $0 --json                       # Output JSON format
    $0 --email                      # Send email report

Cron examples:
    */15 * * * * $0                 # Every 15 minutes
    0 */6 * * * $0 --email          # Every 6 hours with email
EOF
}

main() {
    local output_format="human"
    local send_email=false
    local send_slack=false
    local verbose=false

    while [[ $# -gt 0 ]]; do
        case $1 in
            --prometheus)
                output_format="prometheus"
                shift
                ;;
            --json)
                output_format="json"
                shift
                ;;
            --email)
                send_email=true
                shift
                ;;
            --slack)
                send_slack=true
                shift
                ;;
            --verbose)
                verbose=true
                shift
                ;;
            -h|--help)
                show_usage
                exit 0
                ;;
            *)
                echo "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done

    # Create log directory
    mkdir -p "${LOG_DIR}"

    # Run health check
    local health_result
    health_result=$(run_health_check)
    local exit_code=$?

    # Output in requested format
    case "${output_format}" in
        prometheus)
            output_prometheus "$(cat "${METRICS_FILE}" 2>/dev/null || echo '[]')"
            ;;
        json)
            output_json
            ;;
        human)
            # Already displayed by run_health_check
            ;;
    esac

    # Send notifications
    if [[ ${exit_code} -ne 0 ]] || [[ "${verbose}" == "true" ]]; then
        [[ "${send_email}" == "true" ]] && send_email_alert "${overall_status}" "${health_result}"
        [[ "${send_slack}" == "true" ]] && send_slack_alert "${overall_status}" "${health_result}"
        send_health_check "${overall_status}"
    fi

    exit ${exit_code}
}

main "$@"
