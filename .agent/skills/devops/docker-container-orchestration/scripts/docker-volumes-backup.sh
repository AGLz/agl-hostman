#!/bin/bash
# Docker Volumes Backup Script
# Backup and restore Docker volumes with compression and scheduling
#
# Usage:
#   ./docker-volumes-backup.sh backup [volume-name]
#   ./docker-volumes-backup.sh backup-all
#   ./docker-volumes-backup.sh restore [volume-name] [backup-file]
#   ./docker-volumes-backup.sh list
#   ./docker-volumes-backup.sh schedule [cron-expression]

set -euo pipefail

# Configuration
readonly BACKUP_DIR="${BACKUP_DIR:-./docker-backups}"
readonly RETENTION_DAYS="${RETENTION_DAYS:-7}"
readonly COMPRESSION="${COMPRESSION:-gzip}"  # gzip, bzip2, xz, none
readonly TIMESTAMP_FORMAT="%Y%m%d_%H%M%S"
readonly LOG_FILE="/var/log/docker-volume-backup.log"

# Colors for output
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly RED='\033[0;31m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

log_info() {
    echo -e "${BLUE}[INFO]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# Create backup directory
ensure_backup_dir() {
    if [[ ! -d "$BACKUP_DIR" ]]; then
        mkdir -p "$BACKUP_DIR"
        log_info "Created backup directory: $BACKUP_DIR"
    fi
}

# Get compression extension
get_extension() {
    case "$COMPRESSION" in
        gzip) echo ".tar.gz" ;;
        bzip2) echo ".tar.bz2" ;;
        xz) echo ".tar.xz" ;;
        none) echo ".tar" ;;
        *) echo ".tar.gz" ;;
    esac
}

# Get compression command
get_compress_cmd() {
    case "$COMPRESSION" in
        gzip) echo "gzip" ;;
        bzip2) echo "bzip2" ;;
        xz) echo "xz" ;;
        none) echo "cat" ;;
        *) echo "gzip" ;;
    esac
}

# Backup single volume
backup_volume() {
    local volume_name="$1"
    local timestamp
    timestamp=$(date +"$TIMESTAMP_FORMAT")
    local backup_file="${BACKUP_DIR}/${volume_name}_${timestamp}$(get_extension)"
    local temp_container="backup-$(openssl rand -hex 8)"

    log_info "Starting backup of volume: $volume_name"

    # Check if volume exists
    if ! docker volume inspect "$volume_name" &> /dev/null; then
        log_error "Volume $volume_name does not exist"
        return 1
    fi

    # Get volume size before backup
    local volume_size
    volume_size=$(docker volume inspect "$volume_name" --format '{{.UsageData.Size}}' 2>/dev/null || echo "unknown")

    log_info "Volume size: $volume_size"

    # Create temporary container for backup
    local compress_cmd
    compress_cmd=$(get_compress_cmd)

    docker run --rm \
        --name "$temp_container" \
        -v "$volume_name:/data:ro" \
        -v "$BACKUP_DIR:/backup" \
        alpine tar cf - /data | $compress_cmd > "/backup/${volume_name}_${timestamp}$(get_extension)"

    if [[ $? -eq 0 ]]; then
        local backup_size
        backup_size=$(du -h "$backup_file" | cut -f1)
        log_success "Backup created: $backup_file ($backup_size)"
        echo "$backup_file"
    else
        log_error "Backup failed for volume: $volume_name"
        return 1
    fi
}

# Backup all volumes
backup_all_volumes() {
    log_info "Starting backup of all volumes..."

    ensure_backup_dir

    local volumes
    volumes=$(docker volume ls --format "{{.Name}}" | grep -v '^$')

    local backup_count=0
    local failed_count=0

    for volume in $volumes; do
        if backup_volume "$volume"; then
            ((backup_count++))
        else
            ((failed_count++))
        fi
    done

    log_success "Backup complete: $backup_count succeeded, $failed_count failed"

    # Clean old backups
    clean_old_backups
}

# Restore volume from backup
restore_volume() {
    local volume_name="$1"
    local backup_file="$2"
    local temp_container="restore-$(openssl rand -hex 8)"

    log_info "Restoring volume: $volume_name from $backup_file"

    # Check if backup file exists
    if [[ ! -f "$backup_file" ]]; then
        log_error "Backup file not found: $backup_file"
        return 1
    fi

    # Check if volume exists, create if not
    if ! docker volume inspect "$volume_name" &> /dev/null; then
        log_warning "Volume $volume_name does not exist, creating..."
        docker volume create "$volume_name"
    fi

    # Determine decompression command
    local decompress_cmd="cat"
    case "$backup_file" in
        *.gz) decompress_cmd="gunzip" ;;
        *.bz2) decompress_cmd="bunzip2" ;;
        *.xz) decompress_cmd="unxz" ;;
    esac

    # Restore using temporary container
    docker run --rm \
        --name "$temp_container" \
        -v "$volume_name:/data" \
        -v "$(dirname "$backup_file"):/backup" \
        alpine sh -c "cd /data && $decompress_cmd -c /backup/$(basename "$backup_file") | tar xf -"

    if [[ $? -eq 0 ]]; then
        log_success "Volume restored successfully: $volume_name"
    else
        log_error "Restore failed for volume: $volume_name"
        return 1
    fi
}

# List all backups
list_backups() {
    ensure_backup_dir

    log_info "Available backups in: $BACKUP_DIR"
    echo ""

    if [[ ! -d "$BACKUP_DIR" ]] || [[ -z "$(ls -A "$BACKUP_DIR" 2>/dev/null)" ]]; then
        log_warning "No backups found"
        return 0
    fi

    # Group backups by volume
    for backup_file in "$BACKUP_DIR"/*.{tar,tar.gz,tar.bz2,tar.xz}; do
        if [[ -f "$backup_file" ]]; then
            local filename
            filename=$(basename "$backup_file")
            local volume_name
            volume_name=$(echo "$filename" | sed -E 's/_[0-9]{8}_[0-9]{6}\.(tar(\.(gz|bz2|xz))?)$//')
            local backup_date
            backup_date=$(echo "$filename" | grep -oP '\d{8}_\d{6}' | sed 's/_/ /')
            local backup_size
            backup_size=$(du -h "$backup_file" | cut -f1)

            echo "Volume: $volume_name"
            echo "  File: $filename"
            echo "  Date: $backup_date"
            echo "  Size: $backup_size"
            echo "  Path: $backup_file"
            echo ""
        fi
    done
}

# Clean old backups
clean_old_backups() {
    log_info "Cleaning backups older than $RETENTION_DAYS days..."

    if [[ ! -d "$BACKUP_DIR" ]]; then
        return 0
    fi

    local deleted_count=0
    local kept_count=0

    while IFS= read -r -d '' backup_file; do
        local file_age
        file_age=$(($(date +%s) - $(stat -c %Y "$backup_file")))
        local file_age_days=$((file_age / 86400))

        if [[ $file_age_days -gt $RETENTION_DAYS ]]; then
            rm "$backup_file"
            ((deleted_count++))
            log_info "Deleted old backup: $(basename "$backup_file") ($file_age_days days old)"
        else
            ((kept_count++))
        fi
    done < <(find "$BACKUP_DIR" -type f \( -name "*.tar" -o -name "*.tar.gz" -o -name "*.tar.bz2" -o -name "*.tar.xz" \) -print0)

    log_success "Cleanup complete: $kept_count kept, $deleted_count deleted"
}

# Verify backup integrity
verify_backup() {
    local backup_file="$1"

    log_info "Verifying backup: $backup_file"

    if [[ ! -f "$backup_file" ]]; then
        log_error "Backup file not found: $backup_file"
        return 1
    fi

    # Test archive integrity
    local test_cmd
    case "$backup_file" in
        *.tar.gz) test_cmd="gunzip -t" ;;
        *.tar.bz2) test_cmd="bunzip2 -t" ;;
        *.tar.xz) test_cmd="unxz -t" ;;
        *.tar) test_cmd="tar tf" ;;
    esac

    if $test_cmd "$backup_file" &> /dev/null; then
        log_success "Backup integrity verified: $backup_file"

        # Show archive contents
        log_info "Archive contents:"
        case "$backup_file" in
            *.tar.gz) tar tzf "$backup_file" | head -20 ;;
            *.tar.bz2) tar tjf "$backup_file" | head -20 ;;
            *.tar.xz) tar tJf "$backup_file" | head -20 ;;
            *.tar) tar tf "$backup_file" | head -20 ;;
        esac

        if [[ $(tar t* "$backup_file" 2>/dev/null | wc -l) -gt 20 ]]; then
            echo "... and more"
        fi

        return 0
    else
        log_error "Backup integrity check failed: $backup_file"
        return 1
    fi
}

# Schedule automatic backups
schedule_backups() {
    local cron_expr="${1:-0 2 * * *}"  # Default: Daily at 2 AM

    log_info "Scheduling automatic backups with cron: $cron_expr"

    # Create cron job
    local script_path
    script_path="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"
    local cron_cmd="$cron_expr $script_path backup-all >> $LOG_FILE 2>&1"

    # Add to crontab
    (crontab -l 2>/dev/null | grep -v "$script_path"; echo "$cron_cmd") | crontab -

    log_success "Cron job added. Current crontab:"
    crontab -l
}

# Display backup statistics
show_stats() {
    log_info "Backup statistics:"

    ensure_backup_dir

    local total_size=0
    local total_count=0

    while IFS= read -r -d '' backup_file; do
        local file_size
        file_size=$(stat -c %s "$backup_file")
        total_size=$((total_size + file_size))
        ((total_count++))
    done < <(find "$BACKUP_DIR" -type f \( -name "*.tar" -o -name "*.tar.gz" -o -name "*.tar.bz2" -o -name "*.tar.xz" \) -print0)

    local total_size_human
    total_size_human=$(numfmt --to=iec-i --suffix=B "$total_size" 2>/dev/null || echo "$total_size bytes")

    echo "Total backups: $total_count"
    echo "Total size: $total_size_human"
    echo "Backup directory: $BACKUP_DIR"
    echo "Retention period: $RETENTION_DAYS days"
    echo "Compression: $COMPRESSION"
}

# Display usage
usage() {
    cat << EOF
Docker Volumes Backup Script

Usage:
  $0 backup <volume-name>              Backup a single volume
  $0 backup-all                         Backup all volumes
  $0 restore <volume-name> <backup-file> Restore volume from backup
  $0 list                               List all backups
  $0 verify <backup-file>               Verify backup integrity
  $0 clean                              Clean old backups
  $0 schedule [cron-expression]         Schedule automatic backups
  $0 stats                              Show backup statistics

Examples:
  $0 backup myapp-db-data
  $0 backup-all
  $0 restore myapp-db-data ./docker-backups/myapp-db-data_20240101_020000.tar.gz
  $0 list
  $0 verify ./docker-backups/myapp-db-data_20240101_020000.tar.gz
  $0 schedule "0 2 * * *"              # Daily at 2 AM
  $0 schedule "0 */6 * * *"            # Every 6 hours

Environment Variables:
  BACKUP_DIR         Backup directory (default: ./docker-backups)
  RETENTION_DAYS     Days to keep backups (default: 7)
  COMPRESSION        Compression type: gzip, bzip2, xz, none (default: gzip)
  LOG_FILE           Log file path (default: /var/log/docker-volume-backup.log)
EOF
}

# Main
case "${1:-}" in
    backup)
        ensure_backup_dir
        backup_volume "$2"
        ;;
    backup-all)
        backup_all_volumes
        ;;
    restore)
        restore_volume "$2" "$3"
        ;;
    list|"")
        list_backups
        ;;
    verify)
        verify_backup "$2"
        ;;
    clean)
        ensure_backup_dir
        clean_old_backups
        ;;
    schedule)
        schedule_backups "${2:-0 2 * * *}"
        ;;
    stats)
        show_stats
        ;;
    *)
        usage
        exit 1
        ;;
esac
