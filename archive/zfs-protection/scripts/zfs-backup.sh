#!/bin/bash
#
# ZFS Backup Manager - Automated backup with send/receive
# Implements 3-2-1 backup strategy with off-site replication
#

set -euo pipefail

CONFIG_FILE="/etc/zfs-protection/backup-config.conf"
LOG_FILE="/var/log/zfs-protection/backup.log"
LOCK_FILE="/var/run/zfs-backup.lock"

# Load configuration
source "$CONFIG_FILE" 2>/dev/null || {
    echo "❌ Configuration file not found: $CONFIG_FILE"
    exit 1
}

# Logging function
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [$$] $1" | tee -a "$LOG_FILE"
}

# Lock management
acquire_lock() {
    if [[ -f "$LOCK_FILE" ]]; then
        local pid
        pid=$(cat "$LOCK_FILE" 2>/dev/null || echo "")
        if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
            log "❌ Another backup process is running (PID: $pid)"
            exit 1
        else
            log "🧹 Removing stale lock file"
            rm -f "$LOCK_FILE"
        fi
    fi
    echo $$ > "$LOCK_FILE"
    trap 'rm -f "$LOCK_FILE"' EXIT
}

# Create snapshot with retention policy
create_snapshot() {
    local dataset="$1"
    local snap_prefix="$2"
    local retention_count="$3"

    local timestamp
    timestamp=$(date +%Y%m%d_%H%M%S)
    local snapshot_name="${dataset}@${snap_prefix}_${timestamp}"

    log "📸 Creating snapshot: $snapshot_name"

    if zfs snapshot "$snapshot_name"; then
        log "✅ Snapshot created successfully: $snapshot_name"
    else
        log "❌ Failed to create snapshot: $snapshot_name"
        return 1
    fi

    # Apply retention policy
    apply_retention_policy "$dataset" "$snap_prefix" "$retention_count"

    echo "$snapshot_name"
}

# Apply retention policy for snapshots
apply_retention_policy() {
    local dataset="$1"
    local snap_prefix="$2"
    local retention_count="$3"

    log "🧹 Applying retention policy for $dataset ($snap_prefix: keep $retention_count)"

    # Get snapshots sorted by creation time (oldest first)
    local snapshots_to_delete
    snapshots_to_delete=$(zfs list -H -t snapshot -o name -s creation | \
                         grep "^${dataset}@${snap_prefix}_" | \
                         head -n -"$retention_count")

    if [[ -n "$snapshots_to_delete" ]]; then
        while IFS= read -r snapshot; do
            log "🗑️ Removing old snapshot: $snapshot"
            if zfs destroy "$snapshot"; then
                log "✅ Snapshot destroyed: $snapshot"
            else
                log "❌ Failed to destroy snapshot: $snapshot"
            fi
        done <<< "$snapshots_to_delete"
    else
        log "✅ No snapshots to clean up for $dataset ($snap_prefix)"
    fi
}

# Send snapshot to local backup pool
send_to_local_backup() {
    local source_snapshot="$1"
    local backup_pool="$2"

    local dataset_name
    dataset_name=$(echo "$source_snapshot" | cut -d'@' -f1 | sed "s|^[^/]*/||")
    local backup_dataset="${backup_pool}/${dataset_name}"

    log "💾 Sending to local backup: $source_snapshot -> $backup_dataset"

    # Check if backup dataset exists
    if ! zfs list "$backup_dataset" >/dev/null 2>&1; then
        log "📁 Creating backup dataset: $backup_dataset"

        # Get the latest snapshot for initial send
        if zfs send "$source_snapshot" | zfs receive -F "$backup_dataset"; then
            log "✅ Initial backup completed: $backup_dataset"
        else
            log "❌ Initial backup failed: $backup_dataset"
            return 1
        fi
    else
        # Incremental send
        local last_common_snapshot
        last_common_snapshot=$(zfs list -H -t snapshot -o name | \
                              grep "^${backup_dataset}@" | \
                              grep -F "$(echo "$source_snapshot" | cut -d'@' -f2 | cut -d'_' -f1)" | \
                              tail -1 | \
                              sed "s|^${backup_dataset}@|$(echo "$source_snapshot" | cut -d'@' -f1)@|")

        if [[ -n "$last_common_snapshot" ]] && zfs list "$last_common_snapshot" >/dev/null 2>&1; then
            log "🔄 Incremental send from: $last_common_snapshot"
            if zfs send -i "$last_common_snapshot" "$source_snapshot" | zfs receive -F "$backup_dataset"; then
                log "✅ Incremental backup completed: $backup_dataset"
            else
                log "❌ Incremental backup failed: $backup_dataset"
                return 1
            fi
        else
            log "🔄 Full send (no common snapshot found)"
            if zfs send "$source_snapshot" | zfs receive -F "$backup_dataset"; then
                log "✅ Full backup completed: $backup_dataset"
            else
                log "❌ Full backup failed: $backup_dataset"
                return 1
            fi
        fi
    fi
}

# Send snapshot to remote location
send_to_remote() {
    local source_snapshot="$1"
    local remote_host="$2"
    local remote_dataset="$3"

    log "🌐 Sending to remote: $source_snapshot -> $remote_host:$remote_dataset"

    # Check remote connectivity
    if ! ssh -o ConnectTimeout=10 "$remote_host" "zfs list $remote_dataset" >/dev/null 2>&1; then
        if ! ssh -o ConnectTimeout=10 "$remote_host" "zfs create -p $remote_dataset" >/dev/null 2>&1; then
            log "❌ Cannot access or create remote dataset: $remote_host:$remote_dataset"
            return 1
        fi
    fi

    # Perform remote send
    local last_remote_snapshot
    last_remote_snapshot=$(ssh "$remote_host" "zfs list -H -t snapshot -o name | grep '^${remote_dataset}@' | tail -1" || echo "")

    if [[ -n "$last_remote_snapshot" ]]; then
        local local_equivalent
        local_equivalent=$(echo "$source_snapshot" | cut -d'@' -f1)@$(echo "$last_remote_snapshot" | cut -d'@' -f2)

        if zfs list "$local_equivalent" >/dev/null 2>&1; then
            log "🔄 Incremental remote send from: $local_equivalent"
            if zfs send -i "$local_equivalent" "$source_snapshot" | ssh "$remote_host" "zfs receive -F $remote_dataset"; then
                log "✅ Incremental remote backup completed"
            else
                log "❌ Incremental remote backup failed"
                return 1
            fi
        else
            log "🔄 Full remote send (no common snapshot)"
            if zfs send "$source_snapshot" | ssh "$remote_host" "zfs receive -F $remote_dataset"; then
                log "✅ Full remote backup completed"
            else
                log "❌ Full remote backup failed"
                return 1
            fi
        fi
    else
        log "🔄 Initial remote send"
        if zfs send "$source_snapshot" | ssh "$remote_host" "zfs receive -F $remote_dataset"; then
            log "✅ Initial remote backup completed"
        else
            log "❌ Initial remote backup failed"
            return 1
        fi
    fi
}

# Verify backup integrity
verify_backup() {
    local backup_dataset="$1"
    local verification_type="${2:-checksum}"

    log "🔍 Verifying backup integrity: $backup_dataset"

    case "$verification_type" in
        "checksum")
            # Verify using ZFS checksums
            local checksum_errors
            checksum_errors=$(zpool status | grep -A5 "$backup_dataset" | grep "cksum" | awk '{print $4}' || echo "0")

            if [[ "$checksum_errors" == "0" ]]; then
                log "✅ Backup checksum verification passed: $backup_dataset"
                return 0
            else
                log "❌ Backup checksum verification failed: $backup_dataset ($checksum_errors errors)"
                return 1
            fi
            ;;
        "mount")
            # Verify by attempting to mount
            local mount_point="/tmp/verify_$(basename "$backup_dataset")_$$"
            mkdir -p "$mount_point"

            if zfs set mountpoint="$mount_point" "$backup_dataset" && \
               zfs mount "$backup_dataset" && \
               [[ -d "$mount_point" ]] && \
               ls "$mount_point" >/dev/null 2>&1; then
                log "✅ Backup mount verification passed: $backup_dataset"
                zfs umount "$backup_dataset" 2>/dev/null || true
                zfs set mountpoint=none "$backup_dataset" 2>/dev/null || true
                rmdir "$mount_point" 2>/dev/null || true
                return 0
            else
                log "❌ Backup mount verification failed: $backup_dataset"
                zfs umount "$backup_dataset" 2>/dev/null || true
                zfs set mountpoint=none "$backup_dataset" 2>/dev/null || true
                rmdir "$mount_point" 2>/dev/null || true
                return 1
            fi
            ;;
        *)
            log "⚠️ Unknown verification type: $verification_type"
            return 1
            ;;
    esac
}

# Generate backup report
generate_backup_report() {
    local backup_type="$1"
    local start_time="$2"
    local end_time="$3"
    local success_count="$4"
    local total_count="$5"

    local duration=$((end_time - start_time))
    local success_rate=$((success_count * 100 / total_count))

    {
        echo "📊 ZFS Backup Report - $(date)"
        echo "=================================="
        echo "Backup Type: $backup_type"
        echo "Start Time: $(date -d "@$start_time")"
        echo "End Time: $(date -d "@$end_time")"
        echo "Duration: ${duration}s"
        echo "Success Rate: ${success_rate}% (${success_count}/${total_count})"
        echo ""
        echo "Pool Status:"
        zpool status
        echo ""
        echo "Dataset Summary:"
        zfs list -t filesystem
        echo ""
        echo "Recent Snapshots:"
        zfs list -t snapshot | tail -10
    } > "/var/log/zfs-protection/backup-report-$(date +%Y%m%d).txt"

    log "📄 Backup report generated: /var/log/zfs-protection/backup-report-$(date +%Y%m%d).txt"
}

# Backup single dataset
backup_dataset() {
    local dataset="$1"
    local backup_type="$2"

    log "🎯 Starting backup for dataset: $dataset (type: $backup_type)"

    local snapshot
    case "$backup_type" in
        "hourly")
            snapshot=$(create_snapshot "$dataset" "hourly" "${HOURLY_RETENTION:-24}")
            ;;
        "daily")
            snapshot=$(create_snapshot "$dataset" "daily" "${DAILY_RETENTION:-30}")
            ;;
        "weekly")
            snapshot=$(create_snapshot "$dataset" "weekly" "${WEEKLY_RETENTION:-12}")
            ;;
        "monthly")
            snapshot=$(create_snapshot "$dataset" "monthly" "${MONTHLY_RETENTION:-12}")
            ;;
        *)
            log "❌ Unknown backup type: $backup_type"
            return 1
            ;;
    esac

    if [[ -z "$snapshot" ]]; then
        log "❌ Failed to create snapshot for $dataset"
        return 1
    fi

    local success=true

    # Local backup (if configured)
    if [[ "${LOCAL_BACKUP_ENABLED:-false}" == "true" ]] && [[ -n "${LOCAL_BACKUP_POOL:-}" ]]; then
        if ! send_to_local_backup "$snapshot" "$LOCAL_BACKUP_POOL"; then
            success=false
        fi
    fi

    # Remote backup (if configured)
    if [[ "${REMOTE_BACKUP_ENABLED:-false}" == "true" ]] && [[ -n "${REMOTE_HOST:-}" ]] && [[ -n "${REMOTE_DATASET:-}" ]]; then
        local remote_dataset_full="${REMOTE_DATASET}/$(echo "$dataset" | sed 's|^[^/]*/||')"
        if ! send_to_remote "$snapshot" "$REMOTE_HOST" "$remote_dataset_full"; then
            success=false
        fi
    fi

    if [[ "$success" == "true" ]]; then
        log "✅ Backup completed successfully for: $dataset"
        return 0
    else
        log "❌ Backup had errors for: $dataset"
        return 1
    fi
}

# Main backup function
main() {
    local backup_type="${1:-daily}"
    local specific_dataset="${2:-}"

    acquire_lock

    log "🚀 Starting ZFS backup process (type: $backup_type)"
    local start_time
    start_time=$(date +%s)

    local datasets_to_backup
    if [[ -n "$specific_dataset" ]]; then
        datasets_to_backup="$specific_dataset"
    else
        # Get all datasets to backup from config
        datasets_to_backup="${BACKUP_DATASETS:-$(zfs list -H -o name -t filesystem | grep -v "^backup")}"
    fi

    local total_count=0
    local success_count=0

    for dataset in $datasets_to_backup; do
        if zfs list "$dataset" >/dev/null 2>&1; then
            total_count=$((total_count + 1))
            if backup_dataset "$dataset" "$backup_type"; then
                success_count=$((success_count + 1))
            fi
        else
            log "⚠️ Dataset not found: $dataset"
        fi
    done

    local end_time
    end_time=$(date +%s)

    generate_backup_report "$backup_type" "$start_time" "$end_time" "$success_count" "$total_count"

    if [[ "$success_count" -eq "$total_count" ]]; then
        log "✅ All backups completed successfully ($success_count/$total_count)"
        exit 0
    else
        log "⚠️ Some backups failed ($success_count/$total_count)"
        exit 1
    fi
}

# Handle different command line options
case "${1:-}" in
    "--hourly")
        main "hourly" "${2:-}"
        ;;
    "--daily")
        main "daily" "${2:-}"
        ;;
    "--weekly")
        main "weekly" "${2:-}"
        ;;
    "--monthly")
        main "monthly" "${2:-}"
        ;;
    "--initial")
        log "🎯 Running initial backup setup"
        main "daily"
        ;;
    "--verify")
        if [[ -n "${2:-}" ]]; then
            verify_backup "$2"
        else
            log "❌ Please specify dataset to verify"
            exit 1
        fi
        ;;
    *)
        echo "Usage: $0 [--hourly|--daily|--weekly|--monthly|--initial|--verify <dataset>] [specific_dataset]"
        echo ""
        echo "Options:"
        echo "  --hourly    Create hourly snapshots and backup"
        echo "  --daily     Create daily snapshots and backup"
        echo "  --weekly    Create weekly snapshots and backup"
        echo "  --monthly   Create monthly snapshots and backup"
        echo "  --initial   Run initial backup setup"
        echo "  --verify    Verify backup integrity"
        echo ""
        echo "Examples:"
        echo "  $0 --daily                    # Backup all configured datasets"
        echo "  $0 --hourly tank/vm-data     # Hourly backup of specific dataset"
        echo "  $0 --verify backup/tank/data # Verify backup integrity"
        exit 1
        ;;
esac