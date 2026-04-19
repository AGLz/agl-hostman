#!/bin/bash
################################################################################
# Backup Cleanup Script
# Removes old backups per retention policy
# Usage: ./backup-cleanup.sh [--dry-run] [--backup-dir /path/to/backups]
################################################################################

set -euo pipefail

# Configuration
BACKUP_DIR="${BACKUP_DIR:-/var/backups}"
DRY_RUN="${DRY_RUN:-false}"
RETENTION_POLICY="${RETENTION_POLICY:-standard}"
VERBOSE="${VERBOSE:-false}"

# Standard retention policy (keep: daily=7, weekly=4, monthly=12)
declare -A RETENTION_DAYS=(
    [hourly]=24
    [daily]=7
    [weekly]=28
    [monthly]=365
)

# Aggressive retention policy (keep: daily=3, weekly=2, monthly=6)
declare -A RETENTION_DAYS_AGGRESSIVE=(
    [hourly]=12
    [daily]=3
    [weekly]=14
    [monthly]=180
)

# Long-term retention policy (keep: daily=30, weekly=12, monthly=36)
declare -A RETENTION_DAYS_LONGTERM=(
    [hourly]=48
    [daily]=30
    [weekly]=84
    [monthly]=1095
)

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Logging functions
log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_debug() { [[ "$VERBOSE" == "true" ]] && echo -e "${BLUE}[DEBUG]${NC} $1"; }
log_dry() { echo -e "${BLUE}[DRY RUN]${NC} $1"; }

# Statistics
DELETED_COUNT=0
DELETED_SIZE=0
KEPT_COUNT=0
KEPT_SIZE=0

# Load retention policy
load_retention_policy() {
    case "$RETENTION_POLICY" in
        aggressive)
            for key in "${!RETENTION_DAYS_AGGRESSIVE[@]}"; do
                RETENTION_DAYS[$key]=${RETENTION_DAYS_AGGRESSIVE[$key]}
            done
            ;;
        longterm)
            for key in "${!RETENTION_DAYS_LONGTERM[@]}"; do
                RETENTION_DAYS[$key]=${RETENTION_DAYS_LONGTERM[$key]}
            done
            ;;
        standard|*)
            # Use default RETENTION_DAYS
            ;;
    esac

    log_info "Using retention policy: $RETENTION_POLICY"
}

# Get file age in days
get_file_age_days() {
    local file="$1"
    local now=$(date +%s)
    local mtime=$(stat -c %Y "$file" 2>/dev/null || stat -f %m "$file")
    echo $(( (now - mtime) / 86400 ))
}

# Get file size
get_file_size() {
    local file="$1"
    stat -c %s "$file" 2>/dev/null || stat -f %z "$file"
}

# Format bytes for display
format_bytes() {
    local bytes=$1
    local units=('B' 'KB' 'MB' 'GB' 'TB')
    local unit=0

    while (( bytes > 1024 && unit < 4 )); do
        bytes=$((bytes / 1024))
        ((unit++))
    done

    echo "${bytes} ${units[$unit]}"
}

# Determine backup type from filename
determine_backup_type() {
    local filename="$1"

    if [[ "$filename" =~ hourly ]] || echo "$filename" | grep -q "hour"; then
        echo "hourly"
    elif [[ "$filename" =~ weekly ]] || echo "$filename" | grep -q "week"; then
        echo "weekly"
    elif [[ "$filename" =~ monthly ]] || echo "$filename" | grep -q "month"; then
        echo "monthly"
    else
        echo "daily"
    fi
}

# Determine backup category from path
determine_backup_category() {
    local path="$1"

    if [[ "$path" =~ /hourly/ ]] || [[ "$path" =~ /database/hourly ]]; then
        echo "hourly"
    elif [[ "$path" =~ /weekly/ ]] || [[ "$path" =~ /database/weekly ]]; then
        echo "weekly"
    elif [[ "$path" =~ /monthly/ ]] || [[ "$path" =~ /database/monthly ]]; then
        echo "monthly"
    else
        echo "daily"
    fi
}

# Check if file should be deleted
should_delete_file() {
    local file="$1"
    local age_days=$(get_file_age_days "$file")
    local backup_type=$(determine_backup_category "$file")
    local retention_days=${RETENTION_DAYS[$backup_type]:-${RETENTION_DAYS[daily]}}

    log_debug "File: $file, Age: $age_days days, Type: $backup_type, Retention: $retention_days days"

    if [[ $age_days -gt $retention_days ]]; then
        return 0
    else
        return 1
    fi
}

# Delete file
delete_file() {
    local file="$1"

    local size=$(get_file_size "$file")

    if [[ "$DRY_RUN" == "true" ]]; then
        log_dry "Would delete: $file ($(format_bytes $size))"
        ((DELETED_COUNT++))
        ((DELETED_SIZE += size))
    else
        if rm -f "$file"; then
            log_info "Deleted: $file ($(format_bytes $size))"
            ((DELETED_COUNT++))
            ((DELETED_SIZE += size))
        else
            log_error "Failed to delete: $file"
            return 1
        fi
    fi

    return 0
}

# Keep file
keep_file() {
    local file="$1"
    local size=$(get_file_size "$file")

    ((KEPT_COUNT++))
    ((KEPT_SIZE += size))

    log_debug "Keeping: $file ($(format_bytes $size), $(get_file_age_days "$file") days old)"
}

# Clean directory
clean_directory() {
    local dir="$1"
    local pattern="${2:-*}"

    log_info "Cleaning directory: $dir (pattern: $pattern)"

    if [[ ! -d "$dir" ]]; then
        log_warn "Directory not found: $dir"
        return 0
    fi

    while IFS= read -r -d '' file; do
        if should_delete_file "$file"; then
            delete_file "$file"
        else
            keep_file "$file"
        fi
    done < <(find "$dir" -type f -name "$pattern" -print0)
}

# Clean database backups
clean_database_backups() {
    log_info "=== Cleaning Database Backups ==="

    local db_backup_dir="${BACKUP_DIR}/database"

    # Clean different backup types
    clean_directory "$db_backup_dir/hourly" "*.sql.gz"
    clean_directory "$db_backup_dir/daily" "*.sql.gz"
    clean_directory "$db_backup_dir/weekly" "*.sql.gz"
    clean_directory "$db_backup_dir/monthly" "*.sql.gz"
}

# Clean file backups
clean_file_backups() {
    log_info "=== Cleaning File Backups ==="

    local file_backup_dir="${BACKUP_DIR}/files"

    clean_directory "$file_backup_dir" "*.tar.gz"
}

# Clean S3 backups
clean_s3_backups() {
    log_info "=== Cleaning S3 Backups ==="

    local s3_bucket="${S3_BUCKET:-}"
    local s3_prefix="${S3_PREFIX:-backups/}"

    if [[ -z "$s3_bucket" ]]; then
        log_warn "S3_BUCKET not set, skipping S3 cleanup"
        return 0
    fi

    if ! command -v aws &> /dev/null; then
        log_warn "AWS CLI not found, skipping S3 cleanup"
        return 0
    fi

    # List files in S3
    local s3_files=$(aws s3 ls "s3://${s3_bucket}/${s3_prefix}" --recursive | awk '{print $4}')

    while IFS= read -r file; do
        [[ -z "$file" ]] && continue

        local filename=$(basename "$file")
        local age_days=$(aws_s3_file_age "$file")

        if [[ $age_days -gt ${RETENTION_DAYS[daily]} ]]; then
            if [[ "$DRY_RUN" == "true" ]]; then
                log_dry "Would delete S3: $file"
            else
                log_info "Deleting S3: $file"
                aws s3 rm "s3://${s3_bucket}/${file}"
            fi
            ((DELETED_COUNT++))
        fi
    done <<< "$s3_files"
}

# Get S3 file age
aws_s3_file_age() {
    local s3_path="$1"
    local bucket="${S3_BUCKET:-}"
    local file_date=$(aws s3api head-object --bucket "$bucket" --key "$s3_path" --query 'LastModified' --output text 2>/dev/null)

    if [[ -z "$file_date" ]]; then
        echo 9999
        return
    fi

    local file_ts=$(date -d "$file_date" +%s 2>/dev/null || date -j -f "%Y-%m-%dT%H:%M:%S" "$file_date" +%s)
    local now=$(date +%s)

    echo $(( (now - file_ts) / 86400 ))
}

# Clean checksum files
clean_checksum_files() {
    log_info "=== Cleaning Checksum Files ==="

    # Remove checksum files for deleted backups
    find "$BACKUP_DIR" -type f -name "*.sha256" | while read -r checksum_file; do
        local backup_file="${checksum_file%.sha256}"

        if [[ ! -f "$backup_file" ]]; then
            if [[ "$DRY_RUN" == "true" ]]; then
                log_dry "Would delete orphaned checksum: $checksum_file"
            else
                log_info "Deleting orphaned checksum: $checksum_file"
                rm -f "$checksum_file"
            fi
        fi
    done
}

# Generate cleanup report
generate_report() {
    log_info "=== Cleanup Report ==="
    echo "  Dry Run: $DRY_RUN"
    echo "  Retention Policy: $RETENTION_POLICY"
    echo "  -------------------"
    echo "  Deleted: $DELETED_COUNT files ($(format_bytes $DELETED_SIZE))"
    echo "  Kept: $KEPT_COUNT files ($(format_bytes $KEPT_SIZE))"
    echo "  -------------------"

    local total=$((DELETED_COUNT + KEPT_COUNT))
    local total_size=$((DELETED_SIZE + KEPT_SIZE))
    echo "  Total: $total files ($(format_bytes $total_size))"
    echo "  ==================="
}

# Main execution
main() {
    log_info "=== Backup Cleanup Started ==="

    # Load retention policy
    load_retention_policy

    # Clean database backups
    clean_database_backups

    # Clean file backups
    clean_file_backups

    # Clean S3 backups (if configured)
    clean_s3_backups

    # Clean orphaned checksum files
    clean_checksum_files

    # Generate report
    generate_report

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "Dry run completed. No files were actually deleted."
    else
        log_info "Cleanup completed successfully"
    fi

    exit 0
}

# Run main function
main "$@"
