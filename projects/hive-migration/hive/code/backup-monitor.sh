#!/bin/bash
################################################################################
# Database Backup Monitoring Script
# Checks backup health and sends alerts if issues detected
################################################################################

set -euo pipefail

# Configuration
BACKUP_DIR="/var/backups/mysql/fgdev"
LOG_FILE="${BACKUP_DIR}/monitor.log"
ALERT_THRESHOLD_HOURS=8  # Alert if no backup in X hours
MIN_BACKUP_SIZE_MB=1     # Minimum expected backup size
DISK_SPACE_WARNING=80    # Alert if disk usage exceeds X%

# Alert methods
ENABLE_EMAIL_ALERTS=false
ALERT_EMAIL="admin@example.com"
ENABLE_SYSLOG=true

# Functions
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

send_alert() {
    local severity=$1
    local message=$2

    log "$severity: $message"

    if [ "$ENABLE_SYSLOG" = true ]; then
        logger -t "db-backup-monitor" -p "user.$severity" "$message"
    fi

    if [ "$ENABLE_EMAIL_ALERTS" = true ]; then
        echo "$message" | mail -s "DB Backup Alert [$severity]" "$ALERT_EMAIL"
    fi
}

check_backup_freshness() {
    log "Checking backup freshness..."

    local latest_backup=$(find "$BACKUP_DIR" -name "falgimoveis11_to_fgdev_*.sql.gz" \
        -type f -printf '%T@ %p\n' 2>/dev/null | sort -rn | head -1 | cut -d' ' -f2-)

    if [ -z "$latest_backup" ]; then
        send_alert "error" "No backup files found in $BACKUP_DIR"
        return 1
    fi

    local backup_age_seconds=$(( $(date +%s) - $(stat -c %Y "$latest_backup") ))
    local backup_age_hours=$(( backup_age_seconds / 3600 ))

    log "Latest backup: $(basename "$latest_backup")"
    log "Backup age: ${backup_age_hours} hours"

    if [ $backup_age_hours -gt $ALERT_THRESHOLD_HOURS ]; then
        send_alert "warning" "Latest backup is ${backup_age_hours} hours old (threshold: ${ALERT_THRESHOLD_HOURS}h)"
        return 1
    fi

    log "Backup freshness: OK"
    return 0
}

check_backup_size() {
    log "Checking backup size..."

    local latest_backup=$(find "$BACKUP_DIR" -name "falgimoveis11_to_fgdev_*.sql.gz" \
        -type f -printf '%T@ %p\n' 2>/dev/null | sort -rn | head -1 | cut -d' ' -f2-)

    if [ -z "$latest_backup" ]; then
        return 1
    fi

    local size_bytes=$(stat -c %s "$latest_backup")
    local size_mb=$(( size_bytes / 1024 / 1024 ))

    log "Backup size: ${size_mb} MB"

    if [ $size_mb -lt $MIN_BACKUP_SIZE_MB ]; then
        send_alert "error" "Backup size too small: ${size_mb} MB (minimum: ${MIN_BACKUP_SIZE_MB} MB)"
        return 1
    fi

    log "Backup size: OK"
    return 0
}

check_backup_integrity() {
    log "Checking backup integrity..."

    local latest_backup=$(find "$BACKUP_DIR" -name "falgimoveis11_to_fgdev_*.sql.gz" \
        -type f -printf '%T@ %p\n' 2>/dev/null | sort -rn | head -1 | cut -d' ' -f2-)

    if [ -z "$latest_backup" ]; then
        return 1
    fi

    # Test gzip integrity
    if ! gzip -t "$latest_backup" 2>/dev/null; then
        send_alert "error" "Backup file is corrupted: $(basename "$latest_backup")"
        return 1
    fi

    # Check SQL content
    if ! zcat "$latest_backup" | head -n 50 | grep -q "CREATE DATABASE"; then
        send_alert "error" "Backup file appears invalid (no CREATE DATABASE): $(basename "$latest_backup")"
        return 1
    fi

    log "Backup integrity: OK"
    return 0
}

check_disk_space() {
    log "Checking disk space..."

    local disk_usage=$(df "$BACKUP_DIR" | awk 'NR==2 {print $5}' | sed 's/%//')

    log "Disk usage: ${disk_usage}%"

    if [ "$disk_usage" -gt $DISK_SPACE_WARNING ]; then
        send_alert "warning" "Disk space critical: ${disk_usage}% used (threshold: ${DISK_SPACE_WARNING}%)"
        return 1
    fi

    log "Disk space: OK"
    return 0
}

check_backup_count() {
    log "Checking backup retention..."

    local backup_count=$(find "$BACKUP_DIR" -name "falgimoveis11_to_fgdev_*.sql.gz" -type f | wc -l)

    log "Total backup files: $backup_count"

    if [ $backup_count -lt 4 ]; then
        send_alert "warning" "Low backup count: $backup_count (expected: 4-28 for 7 days of 4x daily backups)"
    fi

    if [ $backup_count -gt 35 ]; then
        send_alert "info" "High backup count: $backup_count (retention policy may not be working)"
    fi

    log "Backup count: OK"
    return 0
}

check_log_errors() {
    log "Checking backup logs for errors..."

    local backup_log="${BACKUP_DIR}/backup.log"

    if [ ! -f "$backup_log" ]; then
        send_alert "warning" "Backup log file not found: $backup_log"
        return 1
    fi

    # Check for recent errors (last 24 hours)
    local recent_errors=$(find "$backup_log" -type f -mtime -1 -exec grep -c "ERROR:" {} \; 2>/dev/null || echo 0)

    if [ "$recent_errors" -gt 0 ]; then
        send_alert "error" "Found $recent_errors error(s) in backup log (last 24h)"
        # Show last 5 errors
        grep "ERROR:" "$backup_log" | tail -5 | while read -r line; do
            log "Recent error: $line"
        done
        return 1
    fi

    log "Log errors: OK"
    return 0
}

generate_report() {
    log "=========================================="
    log "Backup Health Report"
    log "=========================================="

    local total_checks=0
    local passed_checks=0

    # Run all checks
    checks=(
        "check_backup_freshness"
        "check_backup_size"
        "check_backup_integrity"
        "check_disk_space"
        "check_backup_count"
        "check_log_errors"
    )

    for check in "${checks[@]}"; do
        total_checks=$((total_checks + 1))
        if $check; then
            passed_checks=$((passed_checks + 1))
        fi
    done

    log "=========================================="
    log "Health Check Results: $passed_checks/$total_checks passed"
    log "=========================================="

    if [ $passed_checks -eq $total_checks ]; then
        log "All checks passed - Backup system is healthy"
        return 0
    else
        send_alert "warning" "Backup health check: $passed_checks/$total_checks checks passed"
        return 1
    fi
}

# Main execution
main() {
    mkdir -p "$BACKUP_DIR"

    log "Starting backup monitoring"
    generate_report
    log "Monitoring completed"
}

# Run main function
main "$@"

exit 0
