#!/bin/bash
# =============================================================================
# AGL-22: Backup SLA Monitoring Script
# =============================================================================
# Purpose: Monitor RTO/RPO compliance and generate SLA metrics for Prometheus
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
STATE_DIR="/var/lib/agl-backup"
METRICS_DIR="${STATE_DIR}/metrics"
METRICS_FILE="${METRICS_DIR}/backup-sla.prom"
LOG_DIR="/var/log/agl-backup"
TIMESTAMP=$(date +%s)

# Storage Configuration
LOCAL_BACKUP_DIR="/mnt/pve/bb/dump"
USB4TB_MOUNT="/mnt/pve/usb4tb"

# SLA Thresholds
RTO_CRITICAL_SECONDS=14400   # 4 hours
RTO_WARNING_SECONDS=10800     # 3 hours
RPO_CRITICAL_SECONDS=3600     # 1 hour
RPO_WARNING_SECONDS=21600     # 6 hours

# VM Categories
CRITICAL_VMS="183 184"
HIGH_PRIORITY_VMS="180 182"
STANDARD_VMS="173"

# Alerting
ALERT_EMAIL="${ALERT_EMAIL:-admin@agl.local}"
SLACK_WEBHOOK="${SLACK_WEBHOOK:-}"
WEBHOOK_URL="${WEBHOOK_URL:-}"

# State file for tracking
STATE_FILE="${STATE_DIR}/sla-state.json"

# =============================================================================
# LOGGING FUNCTIONS
# =============================================================================

setup_logging() {
    mkdir -p "$LOG_DIR" "$STATE_DIR" "$METRICS_DIR"
    exec 1> >(tee -a "${LOG_DIR}/sla-monitor.log")
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

# =============================================================================
# METRICS FUNCTIONS
# =============================================================================

write_metric() {
    local metric_name=$1
    local metric_value=$2
    local metric_type=$3  # gauge, counter, histogram
    local labels=$4

    local metric_line=""
    if [[ -n "$labels" ]]; then
        metric_line="${metric_name}{${labels}} ${metric_value} ${TIMESTAMP}"
    else
        metric_line="${metric_name} ${metric_value} ${TIMESTAMP}"
    fi

    # Write to temp file, then move
    echo "${metric_line}" >> "${METRICS_FILE}.tmp"
    mv "${METRICS_FILE}.tmp" "$METRICS_FILE"

    log_debug "Metric: ${metric_line}"
}

write_metric_help() {
    local metric_name=$1
    local help_text=$2
    local metric_type=$3

    echo "# HELP ${metric_name} ${help_text}" >> "${METRICS_FILE}.tmp"
    echo "# TYPE ${metric_name} ${metric_type}" >> "${METRICS_FILE}.tmp"
}

init_metrics_file() {
    cat > "${METRICS_FILE}.tmp" << EOF
# AGL Backup SLA Metrics
# Generated: $(date -Iseconds)
# SLA Targets: RTO < 4h, RPO < 1h

EOF

    # Define metrics with help text
    write_metric_help "agl_sla_rpo_compliance" "RPO compliance status (1=compliant, 0=violation)" "gauge"
    write_metric_help "agl_sla_rto_compliance" "RTO compliance status (1=compliant, 0=violation)" "gauge"
    write_metric_help "agl_sla_backup_age_seconds" "Age of last successful backup in seconds" "gauge"
    write_metric_help "agl_sla_last_backup_timestamp" "Unix timestamp of last backup" "gauge"
    write_metric_help "agl_sla_restore_duration_seconds" "Duration of last restore operation" "gauge"
    write_metric_help "agl_sla_offsite_replication_lag_seconds" "Lag in offsite replication" "gauge"
    write_metric_help "agl_sla_backup_success_rate" "Backup success rate over 24h" "gauge"
    write_metric_help "agl_sla_storage_health" "Storage health status (2=healthy, 1=warning, 0=critical)" "gauge"
    write_metric_help "agl_sla_pct_available" "System availability percentage" "gauge"

    mv "${METRICS_FILE}.tmp" "$METRICS_FILE"
}

update_state() {
    local key=$1
    local value=$2

    local tmp_file="${STATE_FILE}.tmp"
    if [[ -f "$STATE_FILE" ]]; then
        jq ".${key} = ${value}" "$STATE_FILE" > "$tmp_file" 2>/dev/null || echo "{}" > "$tmp_file"
    else
        echo "{}" | jq ".${key} = ${value}" > "$tmp_file"
    fi
    mv "$tmp_file" "$STATE_FILE"
}

# =============================================================================
# ALERT FUNCTIONS
# =============================================================================

send_alert() {
    local severity=$1  # critical, warning, info
    local subject=$2
    local message=$3

    log_warn "Sending ${severity} alert: ${subject}"

    if command -v mail &>/dev/null && [[ -n "$ALERT_EMAIL" ]]; then
        echo "$message" | mail -s "[${severity^^}] AGL SLA Monitor: ${subject}" "$ALERT_EMAIL"
    fi

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
                    \"footer\": \"AGL SLA Monitor\",
                    \"ts\": ${TIMESTAMP}
                }]
            }" 2>/dev/null || true
    fi
}

# =============================================================================
# RPO MONITORING
# =============================================================================

monitor_rpo() {
    log_info "Monitoring RPO compliance..."

    local overall_compliant=true

    for vmid in $CRITICAL_VMS; do
        local backup_file=$(find "$LOCAL_BACKUP_DIR" -name "vzdump-lxc-${vmid}-*.tar.zst" -printf '%T@ %p\n' 2>/dev/null | sort -n | tail -1 | cut -d' ' -f2-)

        if [[ -z "$backup_file" ]]; then
            log_error "No backup found for CT${vmid}"
            write_metric "agl_sla_rpo_compliance" "0" "gauge" "vmid=\"${vmid}\",priority=\"critical\""
            write_metric "agl_sla_backup_age_seconds" "-1" "gauge" "vmid=\"${vmid}\""
            overall_compliant=false
            continue
        fi

        local backup_timestamp=$(stat -c%Y "$backup_file" 2>/dev/null || stat -f%m "$backup_file")
        local age_seconds=$((TIMESTAMP - backup_timestamp))
        local age_minutes=$((age_seconds / 60))

        log_debug "CT${vmid} backup age: ${age_minutes}m (${age_seconds}s)"

        # Write metrics
        write_metric "agl_sla_backup_age_seconds" "$age_seconds" "gauge" "vmid=\"${vmid}\",priority=\"critical\""
        write_metric "agl_sla_last_backup_timestamp" "$backup_timestamp" "gauge" "vmid=\"${vmid}\""

        # Check RPO compliance
        if [[ $age_seconds -gt $RPO_CRITICAL_SECONDS ]]; then
            log_error "RPO VIOLATION: CT${vmid} is ${age_minutes}m old (max: 60m)"
            write_metric "agl_sla_rpo_compliance" "0" "gauge" "vmid=\"${vmid}\",priority=\"critical\""
            update_state "rpo.${vmid}.compliant" "false"
            overall_compliant=false
        elif [[ $age_seconds -gt $RPO_WARNING_SECONDS ]]; then
            log_warn "RPO WARNING: CT${vmid} is ${age_minutes}m old (warning: 360m)"
            write_metric "agl_sla_rpo_compliance" "1" "gauge" "vmid=\"${vmid}\",priority=\"critical\""
            update_state "rpo.${vmid}.compliant" "true"
        else
            log_info "RPO OK: CT${vmid} (${age_minutes}m old)"
            write_metric "agl_sla_rpo_compliance" "1" "gauge" "vmid=\"${vmid}\",priority=\"critical\""
            update_state "rpo.${vmid}.compliant" "true"
        fi
    done

    # Overall RPO compliance metric
    if [[ "$overall_compliant" == true ]]; then
        write_metric "agl_sla_rpo_compliance" "1" "gauge" "vmid=\"overall\",priority=\"critical\""
    else
        write_metric "agl_sla_rpo_compliance" "0" "gauge" "vmid=\"overall\",priority=\"critical\""
    fi

    return 0
}

# =============================================================================
# RTO MONITORING
# =============================================================================

monitor_rto() {
    log_info "Monitoring RTO compliance..."

    # Check for recent restore operations in logs
    local last_restore_log=$(find "$LOG_DIR" -name "restore-*.log" -printf '%T@ %p\n' 2>/dev/null | sort -n | tail -1 | cut -d' ' -f2-)

    if [[ -n "$last_restore_log" ]]; then
        # Extract restore duration from log
        local restore_duration=$(grep -oP "Duration: \K[0-9]+s" "$last_restore_log" 2>/dev/null || echo "0")

        if [[ "$restore_duration" =~ ^([0-9]+)s$ ]]; then
            local duration_seconds="${BASH_REMATCH[1]}"

            write_metric "agl_sla_restore_duration_seconds" "$duration_seconds" "gauge" ""

            if [[ $duration_seconds -le $RTO_CRITICAL_SECONDS ]]; then
                log_info "RTO COMPLIANT: Last restore took ${duration_seconds}s"
                write_metric "agl_sla_rto_compliance" "1" "gauge" ""
            else
                log_warn "RTO EXCEEDED: Last restore took ${duration_seconds}s (max: ${RTO_CRITICAL_SECONDS}s)"
                write_metric "agl_sla_rto_compliance" "0" "gauge" ""
            fi
        fi
    else
        # No restore operations found - check restore capability
        local restore_script="${SCRIPT_DIR}/restore-from-backup.sh"
        if [[ -f "$restore_script" && -x "$restore_script" ]]; then
            log_info "RTO READY: Restore script available"
            write_metric "agl_sla_rto_compliance" "1" "gauge" "reason=\"restore_script_available\""
        else
            log_warn "RTO RISK: Restore script not available"
            write_metric "agl_sla_rto_compliance" "0" "gauge" "reason=\"restore_script_missing\""
        fi
    fi

    return 0
}

# =============================================================================
# OFFSITE REPLICATION MONITORING
# =============================================================================

monitor_offsite_replication() {
    log_info "Monitoring offsite replication..."

    if ! mount | grep -q "$USB4TB_MOUNT"; then
        log_warn "Offsite storage not mounted"
        write_metric "agl_sla_offsite_replication_lag_seconds" "-1" "gauge" "target=\"usb4tb\""
        write_metric "agl_sla_offsite_available" "0" "gauge" "target=\"usb4tb\""
        return 1
    fi

    write_metric "agl_sla_offsite_available" "1" "gauge" "target=\"usb4tb\""

    local max_lag=0

    for vmid in $CRITICAL_VMS; do
        local local_backup=$(find "$LOCAL_BACKUP_DIR" -name "vzdump-lxc-${vmid}-*.tar.zst" -printf '%T@ %p\n' 2>/dev/null | sort -n | tail -1 | cut -d' ' -f2-)
        local offsite_backup=$(find "${USB4TB_MOUNT}/dump" -name "vzdump-lxc-${vmid}-*.tar.zst" -printf '%T@ %p\n' 2>/dev/null | sort -n | tail -1 | cut -d' ' -f2-)

        if [[ -n "$local_backup" && -n "$offsite_backup" ]]; then
            local local_timestamp=$(stat -c%Y "$local_backup" 2>/dev/null || stat -f%m "$local_backup")
            local offsite_timestamp=$(stat -c%Y "$offsite_backup" 2>/dev/null || stat -f%m "$offsite_backup")

            if [[ $offsite_timestamp -ge $local_timestamp ]]; then
                local lag=0
            else
                local lag=$((local_timestamp - offsite_timestamp))
            fi

            if [[ $lag -gt $max_lag ]]; then
                max_lag=$lag
            fi

            write_metric "agl_sla_offsite_replication_lag_seconds" "$lag" "gauge" "vmid=\"${vmid}\",target=\"usb4tb\""

            local lag_minutes=$((lag / 60))
            if [[ $lag -gt 3600 ]]; then
                log_warn "Replication lag for CT${vmid}: ${lag_minutes}m"
            else
                log_info "Replication OK for CT${vmid}: ${lag_minutes}m lag"
            fi
        fi
    done

    write_metric "agl_sla_offsite_replication_lag_seconds" "$max_lag" "gauge" "target=\"usb4tb\",vmid=\"max\""

    return 0
}

# =============================================================================
# BACKUP SUCCESS RATE MONITORING
# =============================================================================

monitor_backup_success_rate() {
    log_info "Monitoring backup success rate..."

    local backup_logs=$(find "$LOG_DIR" -name "backup-*.log" -mtime -1 2>/dev/null)
    local total_backups=0
    local successful_backups=0

    while IFS= read -r log_file; do
        ((total_backups++))
        if grep -q "Backup completed successfully" "$log_file" 2>/dev/null; then
            ((successful_backups++))
        fi
    done <<< "$backup_logs"

    if [[ $total_backups -gt 0 ]]; then
        local success_rate=$(awk "BEGIN {printf \"%.2f\", ${successful_backups}/${total_backups} * 100}")
        log_info "Backup success rate (24h): ${success_rate}%"
        write_metric "agl_sla_backup_success_rate" "$success_rate" "gauge" "period=\"24h\""

        if [[ $(echo "$success_rate < 95" | bc -l) -eq 1 ]]; then
            log_warn "Backup success rate below 95%"
            send_alert "warning" "Low Backup Success Rate" \
                "Backup success rate is ${success_rate}% over the last 24 hours."
        fi
    else
        log_debug "No backup logs found in last 24 hours"
        write_metric "agl_sla_backup_success_rate" "100" "gauge" "period=\"24h\""
    fi

    return 0
}

# =============================================================================
# STORAGE HEALTH MONITORING
# =============================================================================

monitor_storage_health() {
    log_info "Monitoring storage health..."

    local storage_usage=$(df -h "$LOCAL_BACKUP_DIR" 2>/dev/null | awk 'NR==2 {print $5}' | tr -d '%')
    local storage_available=$(df -h "$LOCAL_BACKUP_DIR" 2>/dev/null | awk 'NR==2 {print $4}')

    log_info "Storage usage: ${storage_usage}% (${storage_available} free)"

    local health_status=2  # 2 = healthy

    if [[ $storage_usage -gt 90 ]]; then
        log_error "Storage CRITICAL: ${storage_usage}%"
        health_status=0
        write_metric "agl_sla_storage_health" "0" "gauge" "mount=\"${LOCAL_BACKUP_DIR}\""
        send_alert "critical" "Storage Critical" \
            "Backup storage is at ${storage_usage}% capacity. Immediate action required."
    elif [[ $storage_usage -gt 80 ]]; then
        log_warn "Storage WARNING: ${storage_usage}%"
        health_status=1
        write_metric "agl_sla_storage_health" "1" "gauge" "mount=\"${LOCAL_BACKUP_DIR}\""
    else
        log_info "Storage HEALTHY: ${storage_usage}%"
        write_metric "agl_sla_storage_health" "2" "gauge" "mount=\"${LOCAL_BACKUP_DIR}\""
    fi

    return 0
}

# =============================================================================
# SYSTEM AVAILABILITY MONITORING
# =============================================================================

monitor_system_availability() {
    log_info "Monitoring system availability..."

    # Check uptime of critical containers
    local available_ct=0
    local total_ct=0

    for vmid in $CRITICAL_VMS; do
        ((total_ct++))
        if pct status "$vmid" &>/dev/null; then
            local status=$(pct status "$vmid" 2>/dev/null | grep -oP 'Status: \K\w+' || echo "")
            if [[ "$status" == "running" ]]; then
                ((available_ct++))
            fi
        fi
    done

    if [[ $total_ct -gt 0 ]]; then
        local availability=$(awk "BEGIN {printf \"%.2f\", ${available_ct}/${total_ct} * 100}")
        log_info "System availability: ${availability}%"
        write_metric "agl_sla_pct_available" "$availability" "gauge" "category=\"critical\""
    fi

    return 0
}

# =============================================================================
# SLA REPORT GENERATION
# =============================================================================

generate_sla_report() {
    local report_file="${LOG_DIR}/sla-report-$(date +%Y%m%d).txt"

    cat > "$report_file" << EOF
=============================================================================
AGL SLA COMPLIANCE REPORT - AGL-22
=============================================================================
Generated: $(date -Iseconds)
SLA Targets: RTO < 4h, RPO < 1h

=============================================================================
RPO COMPLIANCE (Recovery Point Objective)
=============================================================================
Target: < 1 hour for critical systems
Target: < 6 hours for high priority systems

Critical Systems (CT ${CRITICAL_VMS}):
$(for vmid in $CRITICAL_VMS; do
    local backup_file=$(find "$LOCAL_BACKUP_DIR" -name "vzdump-lxc-${vmid}-*.tar.zst" -printf '%T@ %p\n' 2>/dev/null | sort -n | tail -1 | cut -d' ' -f2-)
    if [[ -n "$backup_file" ]]; then
        local age_minutes=$(( ($(date +%s) - $(stat -c%Y "$backup_file" 2>/dev/null || stat -f%m "$backup_file")) / 60 ))
        local status="COMPLIANT"
        [[ $age_minutes -gt 60 ]] && status="VIOLATION"
        echo "  CT${vmid}: ${age_minutes}m old - ${status}"
    else
        echo "  CT${vmid}: NO BACKUP - VIOLATION"
    fi
done)

=============================================================================
RTO COMPLIANCE (Recovery Time Objective)
=============================================================================
Target: < 4 hours for critical systems

Restore Capability: $([[ -f "${SCRIPT_DIR}/restore-from-backup.sh" ]] && echo "READY" || echo "NOT READY")
Restore Script: ${SCRIPT_DIR}/restore-from-backup.sh

=============================================================================
STORAGE HEALTH
=============================================================================
Storage Location: ${LOCAL_BACKUP_DIR}
Usage: $(df -h "$LOCAL_BACKUP_DIR" 2>/dev/null | awk 'NR==2 {print $5}')
Available: $(df -h "$LOCAL_BACKUP_DIR" 2>/dev/null | awk 'NR==2 {print $4'})

=============================================================================
OFFSITE REPLICATION
=============================================================================
USB4TB Status: $(mount | grep -q "$USB4TB_MOUNT" && echo "CONNECTED" || echo "DISCONNECTED")
Replication Lag: $(grep "agl_sla_offsite_replication_lag_seconds" "$METRICS_FILE" 2>/dev/null | tail -1 | awk '{print $2}' || echo "N/A")

=============================================================================
OVERALL SLA STATUS
=============================================================================
RPO Status: $(grep 'agl_sla_rpo_compliance{vmid="overall"' "$METRICS_FILE" 2>/dev/null | awk '{print $2}' | grep -q "^1$" && echo "COMPLIANT" || echo "VIOLATION")
RTO Status: $(grep 'agl_sla_rto_compliance' "$METRICS_FILE" 2>/dev/null | tail -1 | awk '{print $2}' | grep -q "^1$" && echo "COMPLIANT" || echo "NOT TESTED")

=============================================================================
RECOMMENDATIONS
=============================================================================
$(if [[ $storage_usage -gt 80 ]]; then echo "- Plan storage expansion"; fi)
$(if ! mount | grep -q "$USB4TB_MOUNT"; then echo "- Investigate offsite storage mount failure"; fi)
$(echo "- Review restore procedures quarterly")
$(echo "- Monitor backup logs daily")

=============================================================================
EOF

    cat "$report_file"
    log_info "SLA report generated: ${report_file}"
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================

main() {
    # Setup logging
    setup_logging

    log_info "=========================================="
    log_info "AGL-22 SLA Monitor Starting"
    log_info "=========================================="

    # Initialize metrics file
    init_metrics_file

    # Run monitoring checks
    monitor_rpo
    monitor_rto
    monitor_offsite_replication || true
    monitor_backup_success_rate
    monitor_storage_health
    monitor_system_availability

    # Generate report
    generate_sla_report

    # Update last check timestamp
    update_state "last_sla_check" "\"$(date -Iseconds)\""

    log_success "=========================================="
    log_success "SLA Monitor Completed"
    log_success "Metrics: ${METRICS_FILE}"
    log_success "=========================================="

    return 0
}

# Run main
main "$@"
