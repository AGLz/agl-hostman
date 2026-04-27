#!/bin/bash
# =============================================================================
# MySQL Backup Scheduler with Percona XtraBackup
# AGL Hostman - Automated MySQL Backup Automation
# =============================================================================
#
# Features:
#   - Full backups with Percona XtraBackup
#   - Incremental backups
#   - Compression with pigz
#   - S3 upload support
#   - Retention policy management
#   - Backup verification
#   - Slack/email notifications
#
# Usage:
#   ./backup-scheduler.sh          # Run scheduled backups
#   ./backup-scheduler.sh full     # Run full backup now
#   ./backup-scheduler.sh inc      # Run incremental backup now
#   ./backup-scheduler.sh verify   # Verify last backup
#   ./backup-scheduler.sh restore  # List available backups
# =============================================================================
set -euo pipefail

# =============================================================================
# Configuration
# =============================================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_ROOT="${BACKUP_ROOT:-/backups}"
BACKUP_DATE=$(date +%Y%m%d)
BACKUP_TIME=$(date +%H%M%S)
BACKUP_HOSTNAME="${BACKUP_HOSTNAME:-$(hostname)}"

# Directories
FULL_BACKUP_DIR="$BACKUP_ROOT/full"
INC_BACKUP_DIR="$BACKUP_ROOT/incremental"
LOG_DIR="${LOG_DIR:-/var/log/backup}"
STATE_DIR="$BACKUP_ROOT/state"

# MySQL settings
MYSQL_HOST="${MYSQL_HOST:-mysql-master}"
MYSQL_PORT="${MYSQL_PORT:-3306}"
MYSQL_USER="${MYSQL_USER:-root}"
MYSQL_PASSWORD="${MYSQL_ROOT_PASSWORD:-}"

# Backup settings
BACKUP_TYPE="${BACKUP_TYPE:-full}"
COMPRESS_BACKUPS="${COMPRESS_BACKUPS:-true}"
BACKUP_RETENTION_DAYS="${BACKUP_RETENTION_DAYS:-7}"
FULL_BACKUP_INTERVAL="${FULL_BACKUP_INTERVAL:-86400}"  # 24 hours in seconds

# S3 settings
S3_UPLOAD="${S3_UPLOAD:-false}"
S3_BUCKET="${S3_BUCKET:-}"
S3_PREFIX="${S3_PREFIX:-mysql-backups}"
AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID:-}"
AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY:-}"
AWS_REGION="${AWS_REGION:-us-east-1}"

# Alert settings
ALERT_WEBHOOK="${ALERT_WEBHOOK:-}"
SLACK_WEBHOOK="${SLACK_WEBHOOK:-}"

# State file for tracking last full backup
STATE_FILE="$STATE_DIR/backup-state.json"

# =============================================================================
# Logging Functions
# =============================================================================
setup_logging() {
    mkdir -p "$LOG_DIR" "$STATE_DIR"
    exec > >(tee -a "$LOG_DIR/backup-$(date +%Y%m%d).log")
    exec 2>&1
}

log() {
    local level=$1
    shift
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $@"
}

log_info() { log "INFO" "$@"; }
log_success() { log "SUCCESS" "$@"; }
log_warning() { log "WARNING" "$@"; }
log_error() { log "ERROR" "$@"; }

# =============================================================================
# Alert Functions
# =============================================================================
send_alert() {
    local severity=$1
    local message=$2

    log "ALERT" "[$severity] $message"

    # Send webhook notification
    if [[ -n "$ALERT_WEBHOOK" ]]; then
        curl -s -X POST "$ALERT_WEBHOOK" \
            -H "Content-Type: application/json" \
            -d "{
                \"severity\": \"$severity\",
                \"hostname\": \"$BACKUP_HOSTNAME\",
                \"message\": \"$message\",
                \"timestamp\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"
            }" || true
    fi

    # Send Slack notification
    if [[ -n "$SLACK_WEBHOOK" ]]; then
        local color="#36a64f"
        [[ "$severity" == "CRITICAL" ]] && color="#dc3545"
        [[ "$severity" == "WARNING" ]] && color="#ffc107"

        curl -s -X POST "$SLACK_WEBHOOK" \
            -H "Content-Type: application/json" \
            -d "{
                \"attachments\": [{
                    \"color\": \"$color\",
                    \"title\": \"[$severity] MySQL Backup\",
                    \"text\": \"$message\",
                    \"fields\": [{
                        \"title\": \"Hostname\",
                        \"value\": \"$BACKUP_HOSTNAME\",
                        \"short\": true
                    }, {
                        \"title\": \"Timestamp\",
                        \"value\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",
                        \"short\": true
                    }]
                }]
            }" || true
    fi
}

# =============================================================================
# State Management
# =============================================================================
load_state() {
    if [[ -f "$STATE_FILE" ]]; then
        cat "$STATE_FILE"
    else
        echo '{"last_full_backup":null,"last_incremental":null}'
    fi
}

save_state() {
    local backup_type=$1
    local backup_path=$2

    local state
    state=$(load_state)

    if [[ "$backup_type" == "full" ]]; then
        state=$(echo "$state" | jq --arg path "$backup_path" --arg time "$(date +%s)" '
            .last_full_backup = {path: $path, time: ($time | tonumber)} |
            .last_incremental = {path: $path, time: ($time | tonumber)}
        ')
    else
        state=$(echo "$state" | jq --arg path "$backup_path" --arg time "$(date +%s)" '
            .last_incremental = {path: $path, time: ($time | tonumber)}
        ')
    fi

    echo "$state" > "$STATE_FILE"
}

should_run_full_backup() {
    local state
    state=$(load_state)

    local last_full_time
    last_full_time=$(echo "$state" | jq -r '.last_full_backup.time // 0')

    if [[ "$last_full_time" == "0" || "$last_full_time" == "null" ]]; then
        return 0
    fi

    local current_time
    current_time=$(date +%s)
    local elapsed=$((current_time - last_full_time))

    log_info "Last full backup: $(date -d "@$last_full_time" '+%Y-%m-%d %H:%M:%S')"
    log_info "Time elapsed: $((elapsed / 3600)) hours"

    if [[ $elapsed -ge $FULL_BACKUP_INTERVAL ]]; then
        return 0
    else
        return 1
    fi
}

# =============================================================================
# Backup Functions
# =============================================================================
run_full_backup() {
    local backup_dir="$FULL_BACKUP_DIR/$BACKUP_DATE-$BACKUP_TIME"
    mkdir -p "$backup_dir"

    log_info "Starting full backup to: $backup_dir"

    local start_time
    start_time=$(date +%s)

    # Prepare backup command
    local xtrabackup_cmd=(
        xtrabackup
        --backup
        --target-dir="$backup_dir"
        --host="$MYSQL_HOST"
        --port="$MYSQL_PORT"
        --user="$MYSQL_USER"
        --password="$MYSQL_PASSWORD"
        --parallel=4
        --compress
        --compress-threads=4
    )

    log_info "Running: ${xtrabackup_cmd[@]//?assword=*/?assword=***}"

    # Run backup
    if "${xtrabackup_cmd[@]}" 2>&1 | tee -a "$LOG_DIR/xtrabackup-$BACKUP_DATE.log"; then
        local end_time
        end_time=$(date +%s)
        local duration=$((end_time - start_time))

        log_success "Full backup completed in ${duration}s"

        # Prepare backup
        log_info "Preparing backup..."
        xtrabackup --prepare --target-dir="$backup_dir" 2>&1 | tee -a "$LOG_DIR/xtrabackup-$BACKUP_DATE.log"

        # Get backup size
        local backup_size
        backup_size=$(du -sb "$backup_dir" | cut -f1)
        backup_size=$(numfmt --to=iec $backup_size)

        log_success "Backup size: $backup_size"

        # Save state
        save_state "full" "$backup_dir"

        # Compress if enabled
        if [[ "$COMPRESS_BACKUPS" == "true" ]]; then
            compress_backup "$backup_dir"
        fi

        # Upload to S3
        if [[ "$S3_UPLOAD" == "true" && -n "$S3_BUCKET" ]]; then
            upload_to_s3 "$backup_dir" "full"
        fi

        # Verify backup
        verify_backup "$backup_dir"

        send_alert "INFO" "Full backup completed successfully ($backup_size)"

        return 0
    else
        log_error "Full backup failed"
        send_alert "CRITICAL" "Full backup failed on $BACKUP_HOSTNAME"
        return 1
    fi
}

run_incremental_backup() {
    local state
    state=$(load_state)
    local base_dir
    base_dir=$(echo "$state" | jq -r '.last_full_backup.path // empty')

    if [[ -z "$base_dir" || ! -d "$base_dir" ]]; then
        log_warning "No full backup found, running full backup instead"
        run_full_backup
        return $?
    fi

    local backup_dir="$INC_BACKUP_DIR/$BACKUP_DATE-$BACKUP_TIME"
    mkdir -p "$backup_dir"

    log_info "Starting incremental backup to: $backup_dir"
    log_info "Base directory: $base_dir"

    local start_time
    start_time=$(date +%s)

    # Prepare incremental backup command
    local xtrabackup_cmd=(
        xtrabackup
        --backup
        --target-dir="$backup_dir"
        --incremental-basedir="$base_dir"
        --host="$MYSQL_HOST"
        --port="$MYSQL_PORT"
        --user="$MYSQL_USER"
        --password="$MYSQL_PASSWORD"
        --parallel=4
        --compress
        --compress-threads=4
    )

    # Run backup
    if "${xtrabackup_cmd[@]}" 2>&1 | tee -a "$LOG_DIR/xtrabackup-inc-$BACKUP_DATE.log"; then
        local end_time
        end_time=$(date +%s)
        local duration=$((end_time - start_time))

        log_success "Incremental backup completed in ${duration}s"

        # Get backup size
        local backup_size
        backup_size=$(du -sb "$backup_dir" | cut -f1)
        backup_size=$(numfmt --to=iec $backup_size)

        log_success "Incremental backup size: $backup_size"

        # Save state
        save_state "incremental" "$backup_dir"

        # Compress if enabled
        if [[ "$COMPRESS_BACKUPS" == "true" ]]; then
            compress_backup "$backup_dir"
        fi

        # Upload to S3
        if [[ "$S3_UPLOAD" == "true" && -n "$S3_BUCKET" ]]; then
            upload_to_s3 "$backup_dir" "incremental"
        fi

        send_alert "INFO" "Incremental backup completed ($backup_size)"

        return 0
    else
        log_error "Incremental backup failed"
        send_alert "WARNING" "Incremental backup failed, will retry with full backup"
        return 1
    fi
}

compress_backup() {
    local backup_dir=$1
    local archive_file="${backup_dir}.tar.gz"

    log_info "Compressing backup to: $archive_file"

    if pigz -c "$backup_dir" > "$archive_file"; then
        local archive_size
        archive_size=$(stat -f%z "$archive_file" 2>/dev/null || stat -c%s "$archive_file")
        archive_size=$(numfmt --to=iec $archive_size)

        log_success "Archive created: $archive_file ($archive_size)"

        # Remove uncompressed backup after successful compression
        rm -rf "$backup_dir"

        # Update state with archive path
        sed -i "s|${backup_dir}|${archive_file}|g" "$STATE_FILE"

        return 0
    else
        log_error "Compression failed"
        return 1
    fi
}

upload_to_s3() {
    local backup_path=$1
    local backup_type=$2

    if [[ "$S3_UPLOAD" != "true" || -z "$S3_BUCKET" ]]; then
        return 0
    fi

    log_info "Uploading to S3: s3://$S3_BUCKET/$S3_PREFIX/$backup_type/"

    local s3_path="s3://$S3_BUCKET/$S3_PREFIX/$backup_type/$(basename "$backup_path")"

    if aws s3 cp "$backup_path" "$s3_path" \
        --region "$AWS_REGION" \
        --storage-class STANDARD_IA \
        --only-show-errors; then
        log_success "Upload to S3 completed"

        # Set lifecycle policy for old backups
        aws s3api put-object-lifecycle-configuration \
            --bucket "$S3_BUCKET" \
            --lifecycle-configuration "{
                \"Rules\": [{
                    \"Id\": \"DeleteOldBackups\",
                    \"Status\": \"Enabled\",
                    \"Prefix\": \"$S3_PREFIX/$backup_type/\",
                    \"Expiration\": {\"Days\": $BACKUP_RETENTION_DAYS},
                    \"NoncurrentVersionExpiration\": {\"NoncurrentDays\": 1}
                }]
            }" \
            --region "$AWS_REGION" 2>/dev/null || true

        return 0
    else
        log_error "S3 upload failed"
        return 1
    fi
}

# =============================================================================
# Verification Functions
# =============================================================================
verify_backup() {
    local backup_dir=$1

    log_info "Verifying backup: $backup_dir"

    # Check if backup directory exists
    if [[ ! -d "$backup_dir" ]]; then
        log_error "Backup directory not found: $backup_dir"
        return 1
    fi

    # Check for essential files
    local required_files=("xtrabackup_checkpoints" "ibdata1")
    local missing_files=()

    for file in "${required_files[@]}"; do
        if [[ ! -f "$backup_dir/$file" ]]; then
            missing_files+=("$file")
        fi
    done

    if [[ ${#missing_files[@]} -gt 0 ]]; then
        log_error "Backup verification failed - missing files: ${missing_files[*]}"
        return 1
    fi

    # Validate checkpoint file
    local checkpoint_type
    checkpoint_type=$(grep -oP 'backup_type = \K\w+' "$backup_dir/xtrabackup_checkpoints" || echo "")

    if [[ "$checkpoint_type" != "full-backuped" && "$checkpoint_type" != "full-prepared" ]]; then
        log_warning "Unexpected checkpoint type: $checkpoint_type"
    fi

    log_success "Backup verification passed"

    # Test restore (dry-run)
    log_info "Testing backup restore (dry-run)..."
    local test_dir="$backup_dir-test-restore"

    if xtrabackup --prepare --export --target-dir="$test_dir" \
        --datadir="$backup_dir" 2>&1 | grep -q "completed OK!"; then
        log_success "Backup restore test passed"
        rm -rf "$test_dir"
        return 0
    else
        log_error "Backup restore test failed"
        rm -rf "$test_dir"
        return 1
    fi
}

# =============================================================================
# Cleanup Functions
# %%
cleanup_old_backups() {
    log_info "Cleaning up old backups (retention: $BACKUP_RETENTION_DAYS days)"

    local deleted_count=0

    # Clean full backups
    find "$FULL_BACKUP_DIR" -type d -mtime +"$BACKUP_RETENTION_DAYS" -print -exec rm -rf {} \; 2>/dev/null || true

    # Clean incremental backups
    find "$INC_BACKUP_DIR" -type d -mtime +"$BACKUP_RETENTION_DAYS" -print -exec rm -rf {} \; 2>/dev/null || true

    # Clean archived backups
    find "$FULL_BACKUP_DIR" -type f -name "*.tar.gz" -mtime +"$BACKUP_RETENTION_DAYS" -print -delete 2>/dev/null || true
    find "$INC_BACKUP_DIR" -type f -name "*.tar.gz" -mtime +"$BACKUP_RETENTION_DAYS" -print -delete 2>/dev/null || true

    log_success "Cleanup completed"
}

# =============================================================================
# List/Restore Functions
# %%
list_backups() {
    echo "=== Available Backups ==="
    echo

    echo "Full Backups:"
    ls -lh "$FULL_BACKUP_DIR" 2>/dev/null | tail -n +2 || echo "  No full backups found"

    echo
    echo "Incremental Backups:"
    ls -lh "$INC_BACKUP_DIR" 2>/dev/null | tail -n +2 || echo "  No incremental backups found"
}

# =============================================================================
# Scheduler
# %%
run_scheduled_backups() {
    log_info "Starting backup scheduler..."
    log_info "Schedule: $BACKUP_SCHEDULE"
    log_info "Retention: $BACKUP_RETENTION_DAYS days"

    # Create backup directories
    mkdir -p "$FULL_BACKUP_DIR" "$INC_BACKUP_DIR" "$LOG_DIR" "$STATE_DIR"

    # Run cleanup first
    cleanup_old_backups

    # Check if full backup is needed
    if should_run_full_backup; then
        log_info "Running scheduled full backup"
        run_full_backup
    else
        log_info "Running scheduled incremental backup"
        run_incremental_backup
    fi
}

# =============================================================================
# Main
# %%
main() {
    setup_logging

    local command=${1:-scheduled}

    case "$command" in
        full)
            run_full_backup
            ;;

        inc|incremental)
            run_incremental_backup
            ;;

        scheduled)
            run_scheduled_backups
            ;;

        verify)
            local backup_path=${2:-$(load_state | jq -r '.last_full_backup.path // empty')}
            if [[ -n "$backup_path" ]]; then
                verify_backup "$backup_path"
            else
                log_error "No backup to verify"
                exit 1
            fi
            ;;

        list|ls)
            list_backups
            ;;

        cleanup)
            cleanup_old_backups
            ;;

        *)
            cat <<EOF
MySQL Backup Scheduler

Usage: $0 [command] [options]

Commands:
  scheduled          Run scheduled backup (default)
  full              Run full backup now
  inc|incremental    Run incremental backup now
  verify [path]     Verify backup integrity
  list|ls           List available backups
  cleanup           Clean old backups

Environment Variables:
  MYSQL_HOST              MySQL master host (default: mysql-master)
  MYSQL_ROOT_PASSWORD     MySQL root password
  BACKUP_ROOT            Backup directory (default: /backups)
  BACKUP_RETENTION_DAYS    Retention period (default: 7)
  COMPRESS_BACKUPS        Enable compression (default: true)
  S3_UPLOAD              Upload to S3 (default: false)
  S3_BUCKET              S3 bucket name
  AWS_ACCESS_KEY_ID       AWS access key
  AWS_SECRET_ACCESS_KEY   AWS secret key
  AWS_REGION             AWS region (default: us-east-1)

Examples:
  $0 full
  $0 verify /backups/full/20240201-120000
  $0 list
EOF
            exit 1
            ;;
    esac
}

main "$@"
