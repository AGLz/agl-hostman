#!/bin/bash
# =============================================================================
# AGL Hostman - Backup Health Monitoring
# =============================================================================
# Purpose: Monitor backup health, check for failures, send alerts
# =============================================================================
# Author: DevOps Team
# Created: 2025-02-08
# =============================================================================

set -euo pipefail

# =============================================================================
# CONFIGURATION
# =============================================================================

BACKUP_ROOT="/mnt/shares/agl-hostman-backups"
LOG_DIR="${BACKUP_ROOT}/logs"
ALERT_EMAIL=${ALERT_EMAIL:-"admin@agl.local"}
SLACK_WEBHOOK=${SLACK_WEBHOOK:-""}
MAX_BACKUP_AGE_HOURS=${MAX_BACKUP_AGE_HOURS:-26}  # Slightly more than daily interval

# =============================================================================
# FUNCTIONS
# =============================================================================

log() {
    local level=$1
    shift
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [${level}] $*"
}

send_alert() {
    local severity=$1
    local message=$2

    # Email
    if command -v mail &> /dev/null && [[ -n "$ALERT_EMAIL" ]]; then
        echo "$message" | mail -s "[${severity}] AGL Hostman Backup Alert" "$ALERT_EMAIL"
    fi

    # Slack
    if [[ -n "$SLACK_WEBHOOK" ]]; then
        local emoji="⚠️"
        [[ "$severity" == "CRITICAL" ]] && emoji="🚨"
        [[ "$severity" == "OK" ]] && emoji="✅"

        curl -X POST -H 'Content-type: application/json' \
            --data "{\"text\":\"${emoji} [${severity}] ${message}\"}" \
            "$SLACK_WEBHOOK" 2>/dev/null || true
    fi
}

check_latest_backup() {
    local backup_type=$1
    local max_age_hours=$2

    local latest_file=$(find "${BACKUP_ROOT}/${backup_type}" -type f \( -name "*.sql.gz" -o -name "*.rdb.gz" -o -name "*.tar.gz" \) -printf '%T@ %p\n' 2>/dev/null | sort -n | tail -1 | cut -d' ' -f2-)

    if [[ -z "$latest_file" ]]; then
        log "ERROR: No backups found in ${backup_type}"
        return 1
    fi

    local latest_age_seconds=$(($(date +%s) - $(stat -c %Y "$latest_file")))
    local latest_age_hours=$((latest_age_seconds / 3600))

    if [[ $latest_age_hours -gt $max_age_hours ]]; then
        log "WARNING: Latest ${backup_type} backup is ${latest_age_hours}h old (max: ${max_age_hours}h)"
        return 1
    fi

    log "OK: Latest ${backup_type} backup is ${latest_age_hours}h old"
    return 0
}

check_backup_size() {
    local backup_type=$1
    local min_size_mb=$2

    local total_size=$(du -sm "${BACKUP_ROOT}/${backup_type}" 2>/dev/null | cut -f1)

    if [[ -z "$total_size" ]]; then
        log "ERROR: Cannot determine ${backup_type} backup size"
        return 1
    fi

    if [[ $total_size -lt $min_size_mb ]]; then
        log "WARNING: ${backup_type} backup size is ${total_size}MB (expected >${min_size_mb}MB)"
        return 1
    fi

    log "OK: ${backup_type} backup size is ${total_size}MB"
    return 0
}

check_backup_integrity() {
    local backup_type=$1

    local corrupt_count=0

    while IFS= read -r file; do
        if ! gzip -t "$file" 2>/dev/null; then
            log "ERROR: Corrupt backup file: $(basename "$file")"
            ((corrupt_count++))
        fi
    done < <(find "${BACKUP_ROOT}/${backup_type}" -type f -name "*.gz" 2>/dev/null)

    if [[ $corrupt_count -gt 0 ]]; then
        log "ERROR: Found ${corrupt_count} corrupt backup(s) in ${backup_type}"
        return 1
    fi

    log "OK: All ${backup_type} backup files are valid"
    return 0
}

check_disk_space() {
    local available_gb=$(df -BG "$BACKUP_ROOT" 2>/dev/null | awk 'NR==2 {print $4}' | sed 's/G//')
    local threshold_gb=50

    if [[ $available_gb -lt $threshold_gb ]]; then
        log "WARNING: Low disk space: ${available_gb}GB available (threshold: ${threshold_gb}GB)"
        return 1
    fi

    log "OK: Disk space is ${available_gb}GB"
    return 0
}

check_offsite_replication() {
    if [[ "${OFFSITE_ENABLED:-false}" != "true" ]]; then
        log "INFO: Offsite replication disabled"
        return 0
    fi

    local local_count=$(find "${BACKUP_ROOT}/daily" -type f -mtime -1 2>/dev/null | wc -l)
    local remote_count=0

    if [[ -n "${OFFSITE_TARGET:-}" ]] && [[ -d "$OFFSITE_TARGET/daily" ]]; then
        remote_count=$(find "$OFFSITE_TARGET/daily" -type f -mtime -1 2>/dev/null | wc -l)
    fi

    if [[ $local_count -gt 0 ]] && [[ $remote_count -eq 0 ]]; then
        log "WARNING: Offsite replication may be lagging (local: ${local_count}, remote: ${remote_count})"
        return 1
    fi

    log "OK: Offsite replication is current"
    return 0
}

generate_health_report() {
    local status=$1
    local report_file="${LOG_DIR}/health-report-$(date +%Y%m%d_%H%M%S).txt"

    cat > "$report_file" << EOF
=============================================================================
AGL HOSTMAN BACKUP HEALTH REPORT
=============================================================================
Date: $(date '+%Y-%m-%d %H:%M:%S')
Status: $status

=============================================================================
BACKUP STATUS SUMMARY
=============================================================================
Daily Backups: $(ls -1 ${BACKUP_ROOT}/daily/*.sql.gz 2>/dev/null | wc -l) files
Weekly Backups: $(ls -1 ${BACKUP_ROOT}/weekly/*.sql.gz 2>/dev/null | wc -l) files
Monthly Backups: $(ls -1 ${BACKUP_ROOT}/monthly/*.sql.gz 2>/dev/null | wc -l) files

Latest Daily: $(find ${BACKUP_ROOT}/daily -type f -printf '%T@\n' 2>/dev/null | sort -n | tail -1 | xargs -I{} date -d @{} '+%Y-%m-%d %H:%M:%S' || echo "N/A")

=============================================================================
DISK USAGE
=============================================================================
Backup Directory: $(du -sh ${BACKUP_ROOT} 2>/dev/null | cut -f1)
Available Space: $(df -h ${BACKUP_ROOT} 2>/dev/null | awk 'NR==2 {print $4}')

=============================================================================
RECENT BACKUP LOGS (last 5)
=============================================================================
$(ls -t ${LOG_DIR}/backup-*.log 2>/dev/null | head -5 | xargs -I{} tail -20 {} 2>/dev/null || echo "No logs found")

=============================================================================
EOF

    echo ""
    cat "$report_file"
}

# =============================================================================
# MAIN
# =============================================================================

main() {
    log "=========================================="
    log "AGL Hostman Backup Health Check"
    log "=========================================="

    local checks_failed=0

    # Check latest backup age
    check_latest_backup "daily" $MAX_BACKUP_AGE_HOURS || ((checks_failed++))

    # Check backup size (minimum 10MB for daily backups)
    check_backup_size "daily" 10 || ((checks_failed++))

    # Check backup integrity
    check_backup_integrity "daily" || ((checks_failed++))

    # Check disk space
    check_disk_space || ((checks_failed++))

    # Check offsite replication
    check_offsite_replication || ((checks_failed++))

    # Generate report
    echo ""
    if [[ $checks_failed -eq 0 ]]; then
        generate_health_report "HEALTHY"
        send_alert "OK" "All backup health checks passed"
        exit 0
    else
        generate_health_report "ISSUES DETECTED"
        send_alert "WARNING" "${checks_failed} backup health check(s) failed"
        exit 1
    fi
}

main "$@"
