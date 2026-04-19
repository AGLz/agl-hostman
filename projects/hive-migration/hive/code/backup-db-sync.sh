#!/bin/bash
################################################################################
# Database Backup Script: falgimoveis11 → fgdev
# Schedule: 4x daily (00:00, 06:00, 12:00, 18:00 BRT)
# Retention: 7 days
# Location: /var/backups/mysql/fgdev/
################################################################################

set -euo pipefail

# Configuration
SOURCE_DB="falgimoveis11"
TARGET_DB="fgdev"
BACKUP_DIR="/var/backups/mysql/fgdev"
RETENTION_DAYS=7
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="${BACKUP_DIR}/${SOURCE_DB}_to_${TARGET_DB}_${TIMESTAMP}.sql.gz"
LOG_FILE="${BACKUP_DIR}/backup.log"
LOCK_FILE="${BACKUP_DIR}/.backup.lock"

# MySQL credentials (should be in ~/.my.cnf for security)
MYSQL_USER="${MYSQL_USER:-root}"
MYSQL_PASSWORD="${MYSQL_PASSWORD:-}"

# Functions
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

error_exit() {
    log "ERROR: $1"
    rm -f "$LOCK_FILE"
    exit 1
}

check_lock() {
    if [ -f "$LOCK_FILE" ]; then
        local lock_age=$(($(date +%s) - $(stat -c %Y "$LOCK_FILE")))
        if [ $lock_age -gt 3600 ]; then
            log "WARNING: Stale lock file detected (${lock_age}s old), removing"
            rm -f "$LOCK_FILE"
        else
            error_exit "Another backup is running (lock age: ${lock_age}s)"
        fi
    fi
    touch "$LOCK_FILE"
}

verify_mysql_connection() {
    if [ -n "$MYSQL_PASSWORD" ]; then
        mysql -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" -e "SELECT 1" > /dev/null 2>&1 || \
            error_exit "MySQL connection failed"
    else
        mysql -u"$MYSQL_USER" -e "SELECT 1" > /dev/null 2>&1 || \
            error_exit "MySQL connection failed (check ~/.my.cnf)"
    fi
}

check_database_exists() {
    local db=$1
    if [ -n "$MYSQL_PASSWORD" ]; then
        mysql -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" -e "USE $db" 2>/dev/null || \
            error_exit "Database '$db' does not exist"
    else
        mysql -u"$MYSQL_USER" -e "USE $db" 2>/dev/null || \
            error_exit "Database '$db' does not exist"
    fi
}

perform_backup() {
    log "Starting backup: $SOURCE_DB → $BACKUP_FILE"

    local dump_opts=(
        --single-transaction
        --quick
        --lock-tables=false
        --routines
        --triggers
        --events
        --add-drop-database
        --databases "$SOURCE_DB"
    )

    if [ -n "$MYSQL_PASSWORD" ]; then
        mysqldump -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" "${dump_opts[@]}" | \
            gzip -9 > "$BACKUP_FILE" || error_exit "Backup dump failed"
    else
        mysqldump -u"$MYSQL_USER" "${dump_opts[@]}" | \
            gzip -9 > "$BACKUP_FILE" || error_exit "Backup dump failed"
    fi

    log "Backup completed: $(du -h "$BACKUP_FILE" | cut -f1)"
}

verify_backup_integrity() {
    log "Verifying backup integrity"

    # Check if file is valid gzip
    if ! gzip -t "$BACKUP_FILE" 2>/dev/null; then
        error_exit "Backup file is corrupted (gzip test failed)"
    fi

    # Check if SQL dump is valid (contains expected patterns)
    if ! zcat "$BACKUP_FILE" | head -n 50 | grep -q "CREATE DATABASE"; then
        error_exit "Backup file appears invalid (no CREATE DATABASE found)"
    fi

    log "Backup integrity verified"
}

restore_to_target() {
    log "Restoring backup to target database: $TARGET_DB"

    # Create target database if it doesn't exist
    if [ -n "$MYSQL_PASSWORD" ]; then
        mysql -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" -e "CREATE DATABASE IF NOT EXISTS $TARGET_DB" || \
            error_exit "Failed to create target database"
    else
        mysql -u"$MYSQL_USER" -e "CREATE DATABASE IF NOT EXISTS $TARGET_DB" || \
            error_exit "Failed to create target database"
    fi

    # Restore (replace SOURCE_DB with TARGET_DB in dump)
    if [ -n "$MYSQL_PASSWORD" ]; then
        zcat "$BACKUP_FILE" | sed "s/\`${SOURCE_DB}\`/\`${TARGET_DB}\`/g" | \
            mysql -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" || \
            error_exit "Restore to target database failed"
    else
        zcat "$BACKUP_FILE" | sed "s/\`${SOURCE_DB}\`/\`${TARGET_DB}\`/g" | \
            mysql -u"$MYSQL_USER" || \
            error_exit "Restore to target database failed"
    fi

    log "Restore to $TARGET_DB completed successfully"
}

cleanup_old_backups() {
    log "Cleaning up backups older than $RETENTION_DAYS days"

    find "$BACKUP_DIR" -name "${SOURCE_DB}_to_${TARGET_DB}_*.sql.gz" \
        -type f -mtime +$RETENTION_DAYS -delete

    local remaining_count=$(find "$BACKUP_DIR" -name "${SOURCE_DB}_to_${TARGET_DB}_*.sql.gz" | wc -l)
    log "Backup files remaining: $remaining_count"
}

send_notification() {
    local status=$1
    local message=$2

    # Log to syslog for monitoring
    logger -t "db-backup" -p user.info "$status: $message"

    # Optional: Send email notification (requires mailutils)
    # echo "$message" | mail -s "DB Backup $status" admin@example.com
}

# Main execution
main() {
    log "=========================================="
    log "Database Backup Started"
    log "Source: $SOURCE_DB → Target: $TARGET_DB"

    # Create backup directory
    mkdir -p "$BACKUP_DIR"

    # Pre-flight checks
    check_lock
    verify_mysql_connection
    check_database_exists "$SOURCE_DB"

    # Perform backup
    perform_backup
    verify_backup_integrity

    # Restore to target
    restore_to_target

    # Cleanup
    cleanup_old_backups
    rm -f "$LOCK_FILE"

    log "Database Backup Completed Successfully"
    log "=========================================="

    send_notification "SUCCESS" "Backup completed: $BACKUP_FILE"
}

# Error handling
trap 'error_exit "Script interrupted or failed"' ERR INT TERM

# Run main function
main "$@"

exit 0
