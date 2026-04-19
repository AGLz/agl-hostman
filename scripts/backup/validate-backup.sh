#!/bin/bash
# =============================================================================
# AGL-22: Backup Validation and Integrity Verification Script
# =============================================================================
# Purpose: Validate backup age, integrity, and RPO/RTO compliance
# SLA: RTO < 4 hours, RPO < 1 hour
# =============================================================================
# Author: DevOps Team
# Created: 2026-02-11
# =============================================================================

set -euo pipefail

# =============================================================================
# CONFIGURATION
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$(dirname "$SCRIPT_DIR")")")"
LOG_DIR="/var/log/agl-backup"
STATE_DIR="/var/lib/agl-backup"
STATE_FILE="${STATE_DIR}/validation-state.json"
METRICS_FILE="${STATE_DIR}/validation-metrics.prom"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Proxmox Backup Server Configuration
PBS_SERVER="${PBS_SERVER:-10.6.0.14}"
PBS_PORT="${PBS_PORT:-8007}"
PBS_DATASTORE="${PBS_DATASTORE:-aglsrv6-pbs}"

# Local Storage Configuration
LOCAL_BACKUP_DIR="/mnt/pve/bb/dump"
USB4TB_MOUNT="/mnt/pve/usb4tb"
USB4TB_BACKUP_DIR="${USB4TB_MOUNT}/dump"

# RPO/RPO Thresholds
RPO_CRITICAL_HOURS=1
RPO_WARNING_HOURS=6
RPO_STANDARD_HOURS=24

# Validation Thresholds
CRITICAL_VMS="183 184"
HIGH_PRIORITY_VMS="180 182"
STANDARD_VMS="173"

# Alerting
ALERT_EMAIL="${ALERT_EMAIL:-admin@agl.local}"
SLACK_WEBHOOK="${SLACK_WEBHOOK:-}"
WEBHOOK_URL="${WEBHOOK_URL:-}"

# Options
FULL_VERIFY=false
SEND_EMAIL=false
VERBOSE=false
EXIT_CODE=0

# =============================================================================
# LOGGING FUNCTIONS
# =============================================================================

setup_logging() {
    mkdir -p "$LOG_DIR" "$STATE_DIR"
    exec 1> >(tee -a "${LOG_DIR}/validation-${TIMESTAMP}.log")
    exec 2>&1
}

log() {
    local level=$1
    shift
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[${timestamp}] [${level}] $*"
}

log_info() { log "INFO" "$@"; }
log_warn() { log "WARN" "$@"; }
log_error() { log "ERROR" "$@"; }
log_success() { log "SUCCESS" "$@"; }
log_debug() { [[ "$VERBOSE" == true ]] && log "DEBUG" "$@"; }

# =============================================================================
# METRICS FUNCTIONS
# =============================================================================

write_metric() {
    local metric_name=$1
    local metric_value=$2
    local labels=$3

    local timestamp=$(date +%s)000
    echo "${metric_name}{${labels}} ${metric_value} ${timestamp}" >> "${METRICS_FILE}.tmp"
    mv "${METRICS_FILE}.tmp" "$METRICS_FILE"
}

update_state() {
    local key=$1
    local value=$2

    local tmp_file="${STATE_FILE}.tmp"
    if [[ -f "$STATE_FILE" ]]; then
        jq ".$key = $value" "$STATE_FILE" > "$tmp_file" 2>/dev/null || echo "{}" > "$tmp_file"
    else
        echo "{}" | jq ".$key = $value" > "$tmp_file"
    fi
    mv "$tmp_file" "$STATE_FILE"
}

# =============================================================================
# ALERT FUNCTIONS
# =============================================================================

send_alert() {
    local severity=$1
    local subject=$2
    local message=$3

    log_warn "Sending ${severity} alert: ${subject}"

    # Email alert
    if command -v mail &>/dev/null && [[ -n "$ALERT_EMAIL" ]]; then
        echo "$message" | mail -s "[${severity^^}] AGL Backup Validation: ${subject}" "$ALERT_EMAIL"
    fi

    # Slack alert
    if [[ -n "$SLACK_WEBHOOK" ]]; then
        local color="good"
        [[ "$severity" == "warning" ]] && color="warning"
        [[ "$severity" == "critical" ]] && color="danger"

        curl -X POST "$SLACK_WEBHOOK" \
            -H 'Content-type: application/json' \
            --data "{
                \"attachments\": [{
                    \"color\": \"${color}\",
                    \"title\": \"${subject}\",
                    \"text\": \"${message}\",
                    \"footer\": \"AGL Backup Validation\",
                    \"ts\": $(date +%s)
                }]
            }" 2>/dev/null || true
    fi

    # Webhook alert
    if [[ -n "$WEBHOOK_URL" ]]; then
        curl -X POST "$WEBHOOK_URL" \
            -H "Content-Type: application/json" \
            -d "{
                \"severity\": \"${severity}\",
                \"subject\": \"${subject}\",
                \"message\": \"${message}\",
                \"hostname\": \"$(hostname)\",
                \"timestamp\": \"$(date -Iseconds)\"
            }" 2>/dev/null || true
    fi
}

# =============================================================================
# CONNECTIVITY CHECKS
# =============================================================================

check_pbs_connectivity() {
    log_info "Checking Proxmox Backup Server connectivity..."

    if ! ping -c 1 -W 2 "$PBS_SERVER" >/dev/null 2>&1; then
        log_error "PBS server ${PBS_SERVER} unreachable"
        write_metric "agl_validation_pbs_up" "0" "server=\"${PBS_SERVER}\""
        update_state "connectivity.pbs" "false"
        return 1
    fi

    if ! nc -z -w 2 "$PBS_SERVER" "$PBS_PORT" 2>/dev/null; then
        log_error "PBS port ${PBS_PORT} not accessible"
        write_metric "agl_validation_pbs_up" "0" "server=\"${PBS_SERVER}\""
        update_state "connectivity.pbs" "false"
        return 1
    fi

    log_success "PBS server reachable: ${PBS_SERVER}:${PBS_PORT}"
    write_metric "agl_validation_pbs_up" "1" "server=\"${PBS_SERVER}\""
    update_state "connectivity.pbs" "true"
    return 0
}

check_local_storage() {
    log_info "Checking local backup storage..."

    if [[ ! -d "$LOCAL_BACKUP_DIR" ]]; then
        log_error "Local backup directory not found: ${LOCAL_BACKUP_DIR}"
        write_metric "agl_validation_storage_accessible" "0" "mount=\"${LOCAL_BACKUP_DIR}\""
        return 1
    fi

    local usage=$(df -h "$LOCAL_BACKUP_DIR" 2>/dev/null | awk 'NR==2 {print $5}' | tr -d '%')
    log_info "Storage usage: ${usage}%"
    write_metric "agl_validation_storage_usage_percent" "$usage" "mount=\"${LOCAL_BACKUP_DIR}\""

    if [[ $usage -gt 90 ]]; then
        log_error "Storage critically full: ${usage}%"
        write_metric "agl_validation_storage_status" "2" "mount=\"${LOCAL_BACKUP_DIR}\""  # 2 = critical
        return 1
    elif [[ $usage -gt 80 ]]; then
        log_warn "Storage above warning threshold: ${usage}%"
        write_metric "agl_validation_storage_status" "1" "mount=\"${LOCAL_BACKUP_DIR}\""  # 1 = warning
    else
        write_metric "agl_validation_storage_status" "0" "mount=\"${LOCAL_BACKUP_DIR}\""  # 0 = ok
    fi

    return 0
}

check_offsite_storage() {
    log_info "Checking offsite storage connectivity..."

    local offsite_ok=0
    local offsite_total=0

    # Check USB4TB
    ((offsite_total++))
    if mount | grep -q "$USB4TB_MOUNT"; then
        log_success "USB4TB mounted: ${USB4TB_MOUNT}"
        write_metric "agl_validation_offsite_mounted" "1" "target=\"usb4tb\""
        ((offsite_ok++))
    else
        log_warn "USB4TB not mounted: ${USB4TB_MOUNT}"
        write_metric "agl_validation_offsite_mounted" "0" "target=\"usb4tb\""
    fi

    log_debug "Offsite storage: ${offsite_ok}/${offsite_total} available"
    write_metric "agl_validation_offsite_available" "$offsite_ok" ""

    return 0
}

# =============================================================================
# BACKUP AGE VALIDATION
# =============================================================================

validate_backup_age() {
    local vmid=$1
    local max_age_hours=$2
    local priority=$3

    log_info "Validating backup age for CT${vmid} (max: ${max_age_hours}h, priority: ${priority})"

    local backup_file=$(find "$LOCAL_BACKUP_DIR" -name "vzdump-lxc-${vmid}-*.tar.zst" -printf '%T@ %p\n' 2>/dev/null | sort -n | tail -1 | cut -d' ' -f2-)

    if [[ -z "$backup_file" ]]; then
        log_error "No backup found for CT${vmid}"
        write_metric "agl_validation_backup_age_status" "3" "vmid=\"${vmid}\""  # 3 = missing
        update_state "backup_age.${vmid}" '{"status": "missing"}'
        return 1
    fi

    local backup_timestamp=$(stat -c%Y "$backup_file" 2>/dev/null || stat -f%m "$backup_file")
    local current_timestamp=$(date +%s)
    local age_hours=$(( (current_timestamp - backup_timestamp) / 3600 ))
    local age_minutes=$(( (current_timestamp - backup_timestamp) / 60 ))

    log_debug "CT${vmid} backup age: ${age_hours}h (${age_minutes}m)"

    local status=0  # 0 = ok
    if [[ $age_hours -gt $max_age_hours ]]; then
        log_error "CT${vmid} backup too old: ${age_hours}h (max: ${max_age_hours}h)"
        write_metric "agl_validation_backup_age_hours" "$age_hours" "vmid=\"${vmid}\""
        write_metric "agl_validation_backup_age_status" "2" "vmid=\"${vmid}\""  # 2 = critical
        update_state "backup_age.${vmid}" "{\"status\": \"critical\", \"age_hours\": ${age_hours}}"
        return 1
    elif [[ $age_hours -gt $((max_age_hours / 2)) ]]; then
        log_warn "CT${vmid} backup aging: ${age_hours}h"
        write_metric "agl_validation_backup_age_hours" "$age_hours" "vmid=\"${vmid}\""
        write_metric "agl_validation_backup_age_status" "1" "vmid=\"${vmid}\""  # 1 = warning
        update_state "backup_age.${vmid}" "{\"status\": \"warning\", \"age_hours\": ${age_hours}}"
        status=1
    else
        log_success "CT${vmid} backup OK: ${age_minutes}m old"
        write_metric "agl_validation_backup_age_hours" "$age_hours" "vmid=\"${vmid}\""
        write_metric "agl_validation_backup_age_status" "0" "vmid=\"${vmid}\""  # 0 = ok
        update_state "backup_age.${vmid}" "{\"status\": \"ok\", \"age_hours\": ${age_hours}}"
    fi

    return $status
}

validate_all_backup_ages() {
    log_info "=== VALIDATING BACKUP AGES ==="

    local critical_failures=0

    # Critical VMs (1 hour RPO)
    for vmid in $CRITICAL_VMS; do
        validate_backup_age "$vmid" "$RPO_CRITICAL_HOURS" "critical" || ((critical_failures++))
    done

    # High priority VMs (6 hour RPO)
    for vmid in $HIGH_PRIORITY_VMS; do
        validate_backup_age "$vmid" "$RPO_WARNING_HOURS" "high" || ((critical_failures++))
    done

    # Standard VMs (24 hour RPO)
    for vmid in $STANDARD_VMS; do
        validate_backup_age "$vmid" "$RPO_STANDARD_HOURS" "standard" || true  # Non-critical
    done

    write_metric "agl_validation_age_failures" "$critical_failures" ""

    if [[ $critical_failures -gt 0 ]]; then
        return 1
    fi

    return 0
}

# =============================================================================
# BACKUP INTEGRITY VALIDATION
# =============================================================================

validate_backup_integrity() {
    local vmid=$1

    log_info "Validating backup integrity for CT${vmid}"

    local backup_file=$(find "$LOCAL_BACKUP_DIR" -name "vzdump-lxc-${vmid}-*.tar.zst" -printf '%T@ %p\n' 2>/dev/null | sort -n | tail -1 | cut -d' ' -f2-)

    if [[ -z "$backup_file" ]]; then
        log_warn "No backup file to validate for CT${vmid}"
        return 1
    fi

    # Test zstd integrity
    if command -v zstd &>/dev/null; then
        if zstd -t "$backup_file" 2>/dev/null; then
            log_success "Integrity check passed for CT${vmid}"
            write_metric "agl_validation_integrity_status" "0" "vmid=\"${vmid}\""  # 0 = ok
            update_state "integrity.${vmid}" '{"status": "ok"}'
            return 0
        else
            log_error "Integrity check failed for CT${vmid}"
            write_metric "agl_validation_integrity_status" "2" "vmid=\"${vmid}\""  # 2 = failed
            update_state "integrity.${vmid}" '{"status": "failed"}"
            return 1
        fi
    else
        log_warn "zstd not available, skipping integrity check for CT${vmid}"
        write_metric "agl_validation_integrity_status" "1" "vmid=\"${vmid}\""  # 1 = unknown
        return 0
    fi
}

validate_all_integrity() {
    log_info "=== VALIDATING BACKUP INTEGRITY ==="

    local failures=0

    for vmid in $CRITICAL_VMS $HIGH_PRIORITY_VMS; do
        validate_backup_integrity "$vmid" || ((failures++))
    done

    write_metric "agl_validation_integrity_failures" "$failures" ""

    if [[ $failures -gt 0 ]]; then
        return 1
    fi

    return 0
}

# =============================================================================
# OFFSITE REPLICATION VALIDATION
# =============================================================================

validate_offsite_replication() {
    log_info "=== VALIDATING OFFSITE REPLICATION ==="

    local files_replicated=0
    local files_missing=0

    # Check recent backups on USB4TB
    if mount | grep -q "$USB4TB_MOUNT"; then
        for vmid in $CRITICAL_VMS $HIGH_PRIORITY_VMS; do
            local local_backup=$(find "$LOCAL_BACKUP_DIR" -name "vzdump-lxc-${vmid}-*.tar.zst" -printf '%T@ %p\n' 2>/dev/null | sort -n | tail -1 | cut -d' ' -f2-)
            local offsite_backup=$(find "$USB4TB_BACKUP_DIR" -name "vzdump-lxc-${vmid}-*.tar.zst" -printf '%T@ %p\n' 2>/dev/null | sort -n | tail -1 | cut -d' ' -f2-)

            if [[ -n "$local_backup" ]]; then
                local local_timestamp=$(stat -c%Y "$local_backup" 2>/dev/null || stat -f%m "$local_backup")

                if [[ -n "$offsite_backup" ]]; then
                    local offsite_timestamp=$(stat -c%Y "$offsite_backup" 2>/dev/null || stat -f%m "$offsite_backup")

                    if [[ $offsite_timestamp -ge $local_timestamp ]]; then
                        log_success "CT${vmid} replicated to offsite"
                        ((files_replicated++))
                    else
                        log_warn "CT${vmid} offsite backup is stale"
                        ((files_missing++))
                    fi
                else
                    log_warn "CT${vmid} not found on offsite storage"
                    ((files_missing++))
                fi
            fi
        done

        log_info "Offsite replication: ${files_replicated} OK, ${files_missing} missing"
        write_metric "agl_validation_offsite_replicated" "$files_replicated" ""
        write_metric "agl_validation_offsite_missing" "$files_missing" ""
    else
        log_warn "USB4TB not mounted, skipping offsite validation"
        write_metric "agl_validation_offsite_replicated" "0" ""
        write_metric "agl_validation_offsite_missing" "-1" ""
    fi

    return 0
}

# =============================================================================
# RPO/RTO COMPLIANCE CHECK
# =============================================================================

check_rpo_compliance() {
    log_info "=== CHECKING RPO COMPLIANCE ==="

    local rpo_compliant=true

    # Check critical VMs against 1-hour RPO
    for vmid in $CRITICAL_VMS; do
        local backup_file=$(find "$LOCAL_BACKUP_DIR" -name "vzdump-lxc-${vmid}-*.tar.zst" -printf '%T@ %p\n' 2>/dev/null | sort -n | tail -1 | cut -d' ' -f2-)

        if [[ -n "$backup_file" ]]; then
            local backup_timestamp=$(stat -c%Y "$backup_file" 2>/dev/null || stat -f%m "$backup_file")
            local current_timestamp=$(date +%s)
            local age_minutes=$(( (current_timestamp - backup_timestamp) / 60 ))

            if [[ $age_minutes -gt 60 ]]; then
                log_error "RPO violation: CT${vmid} is ${age_minutes}m old (max: 60m)"
                write_metric "agl_validation_rpo_compliant" "0" "vmid=\"${vmid}\""  # not compliant
                rpo_compliant=false
            else
                log_success "RPO compliant: CT${vmid} (${age_minutes}m old)"
                write_metric "agl_validation_rpo_compliant" "1" "vmid=\"${vmid}\""  # compliant
            fi
        fi
    done

    if [[ "$rpo_compliant" == true ]]; then
        log_success "RPO compliance: ALL CRITICAL SYSTEMS WITHIN 1 HOUR"
        write_metric "agl_validation_rpo_overall" "1" ""
    else
        log_error "RPO compliance: VIOLATIONS DETECTED"
        write_metric "agl_validation_rpo_overall" "0" ""
    fi

    # RTO is about restore capability, measured during restore testing
    # For validation, we check that restore procedures are documented
    local restore_script="${SCRIPT_DIR}/restore-from-backup.sh"
    if [[ -f "$restore_script" && -x "$restore_script" ]]; then
        log_success "RTO compliance: Restore script available"
        write_metric "agl_validation_rto_ready" "1" ""
    else
        log_warn "RTO compliance: Restore script not found or not executable"
        write_metric "agl_validation_rto_ready" "0" ""
    fi

    return 0
}

# =============================================================================
# VALIDATION REPORT
# =============================================================================

generate_validation_report() {
    local exit_code=$1

    local report_file="${LOG_DIR}/validation-report-${TIMESTAMP}.txt"

    # Collect statistics
    local total_backups=$(find "$LOCAL_BACKUP_DIR" -name "vzdump-*.tar.zst" -o -name "vzdump-*.vma.zst" 2>/dev/null | wc -l)
    local recent_backups=$(find "$LOCAL_BACKUP_DIR" -name "vzdump-*.tar.zst" -mtime -1 -o -name "vzdump-*.vma.zst" -mtime -1 2>/dev/null | wc -l)
    local storage_usage=$(df -h "$LOCAL_BACKUP_DIR" 2>/dev/null | awk 'NR==2 {print $5}')

    cat > "$report_file" << EOF
=============================================================================
AGL BACKUP VALIDATION REPORT - AGL-22 COMPLIANCE
=============================================================================
Date: $(date +%Y-%m-%d)
Timestamp: ${TIMESTAMP}
Status: $([ $exit_code -eq 0 ] && echo "PASSED" || echo "FAILED")

=============================================================================
VALIDATION RESULTS
=============================================================================
Total Backups: ${total_backups}
Recent Backups (24h): ${recent_backups}
Storage Usage: ${storage_usage}

=============================================================================
RPO/RTO COMPLIANCE
=============================================================================
RPO Target: < 1 hour (critical), < 6 hours (high), < 24 hours (standard)
RTO Target: < 4 hours

Critical Systems (1h RPO):
$(for vmid in $CRITICAL_VMS; do
    local backup_file=$(find "$LOCAL_BACKUP_DIR" -name "vzdump-lxc-${vmid}-*.tar.zst" -printf '%T@ %p\n' 2>/dev/null | sort -n | tail -1 | cut -d' ' -f2-)
    if [[ -n "$backup_file" ]]; then
        local age_minutes=$(( ($(date +%s) - $(stat -c%Y "$backup_file" 2>/dev/null || stat -f%m "$backup_file")) / 60 ))
        echo "  CT${vmid}: ${age_minutes}m old"
    else
        echo "  CT${vmid}: NO BACKUP"
    fi
done)

=============================================================================
OFFSITE REPLICATION
=============================================================================
USB4TB: $(mount | grep -q "$USB4TB_MOUNT" && echo "CONNECTED" || echo "DISCONNECTED")
Replication Status: $(if mount | grep -q "$USB4TB_MOUNT"; then echo "ACTIVE"; else echo "FAILED"; fi)

=============================================================================
CONNECTIVITY
=============================================================================
PBS Server: ${PBS_SERVER}:${PBS_PORT} $(ping -c 1 -W 2 $PBS_SERVER >/dev/null 2>&1 && echo "ONLINE" || echo "OFFLINE")
Local Storage: ${LOCAL_BACKUP_DIR} $(test -d "$LOCAL_BACKUP_DIR" && echo "OK" || echo "FAILED")

=============================================================================
RECOMMENDATIONS
=============================================================================
$(if [[ $exit_code -ne 0 ]]; then
    echo "- Review failed validations above"
    echo "- Check backup logs in ${LOG_DIR}"
    echo "- Verify PBS connectivity"
    echo "- Ensure offsite replication is working"
else
    echo "- All validations passed"
    echo "- Continue monitoring backup schedules"
    echo "- Schedule monthly restore testing"
fi)

=============================================================================
NEXT ACTIONS
=============================================================================
- Review validation logs: ${LOG_DIR}/validation-${TIMESTAMP}.log
- Update state file: ${STATE_FILE}
- Monitor metrics: ${METRICS_FILE}

=============================================================================
EOF

    cat "$report_file"
    log_success "Validation report generated: ${report_file}"
}

# =============================================================================
# ARGUMENT PARSING
# =============================================================================

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --full)
                FULL_VERIFY=true
                shift
                ;;
            --email)
                SEND_EMAIL=true
                shift
                ;;
            --verbose|-v)
                VERBOSE=true
                shift
                ;;
            --help|-h)
                echo "Usage: $0 [--full] [--email] [--verbose]"
                echo ""
                echo "Options:"
                echo "  --full       Run full integrity verification (slower)"
                echo "  --email      Send email notification"
                echo "  --verbose    Enable verbose output"
                echo "  --help       Show this help message"
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                exit 1
                ;;
        esac
    done
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================

main() {
    # Setup logging
    setup_logging

    # Parse arguments
    parse_arguments "$@"

    log_info "=========================================="
    log_info "AGL-22 Backup Validation Starting"
    log_info "=========================================="

    local checks_failed=0

    # Connectivity checks
    log_info "=== PHASE 1: CONNECTIVITY CHECKS ==="
    check_pbs_connectivity || ((checks_failed++))
    check_local_storage || ((checks_failed++))
    check_offsite_storage || true

    # Backup age validation
    log_info "=== PHASE 2: BACKUP AGE VALIDATION ==="
    validate_all_backup_ages || ((checks_failed++))

    # Integrity validation
    if [[ "$FULL_VERIFY" == true ]]; then
        log_info "=== PHASE 3: INTEGRITY VALIDATION ==="
        validate_all_integrity || ((checks_failed++))
    fi

    # Offsite replication check
    log_info "=== PHASE 4: OFFSITE REPLICATION CHECK ==="
    validate_offsite_replication || true

    # RPO/RTO compliance
    log_info "=== PHASE 5: RPO/RTO COMPLIANCE ==="
    check_rpo_compliance || true

    # Update state
    update_state "last_validation" "\"$(date -Iseconds)\""
    write_metric "agl_validation_last_run" "$(date +%s)" ""

    # Generate report
    generate_validation_report $checks_failed

    if [[ $checks_failed -gt 0 ]]; then
        log_error "=========================================="
        log_error "Validation FAILED with ${checks_failed} failures"
        log_error "=========================================="
        send_alert "critical" "Backup Validation Failed" \
            "Backup validation found ${checks_failed} failures. Review report: ${LOG_DIR}/validation-report-${TIMESTAMP}.txt"
        EXIT_CODE=1
    else
        log_success "=========================================="
        log_success "Validation PASSED"
        log_success "=========================================="
        if [[ "$SEND_EMAIL" == true ]]; then
            send_alert "info" "Backup Validation Passed" \
                "All backup validations passed successfully. Report: ${LOG_DIR}/validation-report-${TIMESTAMP}.txt"
        fi
        EXIT_CODE=0
    fi

    exit $EXIT_CODE
}

# Run main
main "$@"
