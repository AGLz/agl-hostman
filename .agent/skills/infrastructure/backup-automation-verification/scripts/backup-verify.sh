#!/bin/bash
################################################################################
# Backup Verification Script
# Verifies backup integrity with checksums and restore testing
# Usage: ./backup-verify.sh [--type database|files] [--path /path/to/backup]
################################################################################

set -euo pipefail

# Configuration
BACKUP_TYPE="${VERIFY_TYPE:-auto}"
BACKUP_PATH="${VERIFY_PATH:-}"
BACKUP_DIR="${BACKUP_DIR:-/var/backups}"
VERBOSE="${VERBOSE:-false}"
TEST_RESTORE="${TEST_RESTORE:-false}"
TEST_RESTORE_DB="${TEST_RESTORE_DB:-test_restore}"
ALERT_ON_FAILURE="${ALERT_ON_FAILURE:-true}"
ALERT_EMAIL="${ALERT_EMAIL:-ops@example.com}"

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

# Statistics
VERIFIED_COUNT=0
FAILED_COUNT=0
TOTAL_SIZE=0

# Send alert on failure
send_alert() {
    local message="$1"

    if [[ "$ALERT_ON_FAILURE" != "true" ]]; then
        return 0
    fi

    log_warn "Sending alert..."

    # Send email alert
    if command -v mail &> /dev/null && [[ -n "$ALERT_EMAIL" ]]; then
        echo "$message" | mail -s "Backup Verification Alert" "$ALERT_EMAIL"
    fi

    # Could add Slack, Discord, PagerDuty, etc.
}

# Verify file exists and is readable
verify_file_exists() {
    local file="$1"

    if [[ ! -f "$file" ]]; then
        log_error "File not found: $file"
        return 1
    fi

    if [[ ! -r "$file" ]]; then
        log_error "File not readable: $file"
        return 1
    fi

    log_debug "File exists and is readable: $file"
    return 0
}

# Verify checksum
verify_checksum() {
    local backup_file="$1"
    local checksum_file="${backup_file}.sha256"

    if [[ ! -f "$checksum_file" ]]; then
        log_warn "Checksum file not found: $checksum_file"
        return 0
    fi

    log_info "Verifying checksum..."

    if sha256sum -c "$checksum_file" &> /dev/null; then
        log_info "Checksum verification passed"
        return 0
    else
        log_error "Checksum verification failed"
        return 1
    fi
}

# Verify gzip integrity
verify_gzip() {
    local file="$1"

    if [[ ! "$file" =~ \.gz$ ]]; then
        log_debug "Not a gzip file, skipping gzip verification"
        return 0
    fi

    log_info "Verifying gzip integrity..."

    if gzip -t "$file" 2>/dev/null; then
        log_info "Gzip integrity verified"
        return 0
    else
        log_error "Gzip integrity check failed"
        return 1
    fi
}

# Verify tar archive
verify_tar() {
    local file="$1"

    if [[ ! "$file" =~ \.tar\.gz$ ]]; then
        log_debug "Not a tar.gz file, skipping tar verification"
        return 0
    fi

    log_info "Verifying tar archive..."

    if tar -tzf "$file" &> /dev/null; then
        log_info "Tar archive verified"
        return 0
    else
        log_error "Tar archive verification failed"
        return 1
    fi
}

# Verify SQL dump
verify_sql() {
    local file="$1"

    if [[ ! "$file" =~ \.sql(\.gz)?$ ]]; then
        log_debug "Not a SQL file, skipping SQL verification"
        return 0
    fi

    log_info "Verifying SQL dump..."

    # Get first 100 lines to check
    local content=""
    if [[ "$file" =~ \.gz$ ]]; then
        content=$(zcat "$file" 2>/dev/null | head -n 100)
    else
        content=$(head -n 100 "$file" 2>/dev/null)
    fi

    # Check for common SQL dump markers
    if echo "$content" | grep -qiE "(mysqldump|pg_dump|sqlite|dump completed|CREATE TABLE|INSERT INTO)"; then
        log_info "SQL dump appears valid"
        return 0
    else
        log_error "SQL dump appears invalid"
        return 1
    fi
}

# Get file size
get_file_size() {
    local file="$1"
    du -b "$file" | cut -f1
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

# Verify database backup
verify_database_backup() {
    local backup_file="$1"

    log_info "Verifying database backup: $backup_file"

    # Check file exists
    verify_file_exists "$backup_file" || return 1

    # Get file size
    local size=$(get_file_size "$backup_file")

    # Check minimum size (1KB)
    if [[ $size -lt 1024 ]]; then
        log_error "Backup file too small: $size bytes"
        return 1
    fi

    # Verify gzip
    verify_gzip "$backup_file" || return 1

    # Verify SQL content
    verify_sql "$backup_file" || return 1

    # Verify checksum
    verify_checksum "$backup_file" || return 1

    # Update statistics
    ((VERIFIED_COUNT++))
    ((TOTAL_SIZE += size))

    log_info "Database backup verified successfully"

    # Optional: Test restore
    if [[ "$TEST_RESTORE" == "true" ]]; then
        test_restore_database "$backup_file"
    fi

    return 0
}

# Verify file backup
verify_file_backup() {
    local backup_file="$1"

    log_info "Verifying file backup: $backup_file"

    # Check file exists
    verify_file_exists "$backup_file" || return 1

    # Get file size
    local size=$(get_file_size "$backup_file")

    # Check minimum size (1KB)
    if [[ $size -lt 1024 ]]; then
        log_error "Backup file too small: $size bytes"
        return 1
    fi

    # Verify gzip
    verify_gzip "$backup_file" || return 1

    # Verify tar
    verify_tar "$backup_file" || return 1

    # Verify checksum
    verify_checksum "$backup_file" || return 1

    # Update statistics
    ((VERIFIED_COUNT++))
    ((TOTAL_SIZE += size))

    log_info "File backup verified successfully"

    # Optional: Test restore
    if [[ "$TEST_RESTORE" == "true" ]]; then
        test_restore_files "$backup_file"
    fi

    return 0
}

# Test database restore
test_restore_database() {
    local backup_file="$1"
    local test_db="${TEST_RESTORE_DB}_$(date +%s)"

    log_info "Testing database restore to: $test_db"

    # Create test database
    local db_type="${DB_CONNECTION:-mysql}"

    case "$db_type" in
        mysql|mariadb)
            mysql -h "${DB_HOST:-localhost}" \
                  -u "${DB_USERNAME:-root}" \
                  -p"${DB_PASSWORD:-}" \
                  -e "CREATE DATABASE \`$test_db\`;"

            # Restore to test database
            if [[ "$backup_file" =~ \.gz$ ]]; then
                gunzip < "$backup_file" | \
                mysql -h "${DB_HOST:-localhost}" \
                      -u "${DB_USERNAME:-root}" \
                      -p"${DB_PASSWORD:-}" \
                      "$test_db"
            else
                mysql -h "${DB_HOST:-localhost}" \
                      -u "${DB_USERNAME:-root}" \
                      -p"${DB_PASSWORD:-}" \
                      "$test_db" < "$backup_file"
            fi

            # Clean up test database
            mysql -h "${DB_HOST:-localhost}" \
                  -u "${DB_USERNAME:-root}" \
                  -p"${DB_PASSWORD:-}" \
                  -e "DROP DATABASE \`$test_db\`;"
            ;;
        postgres|postgresql)
            # Similar for PostgreSQL
            createdb -h "${DB_HOST:-localhost}" \
                     -U "${DB_USERNAME:-postgres}" \
                     "$test_db"

            gunzip < "$backup_file" | \
            psql -h "${DB_HOST:-localhost}" \
                 -U "${DB_USERNAME:-postgres}" \
                 "$test_db"

            dropdb -h "${DB_HOST:-localhost}" \
                   -U "${DB_USERNAME:-postgres}" \
                   "$test_db"
            ;;
    esac

    log_info "Database restore test completed"
}

# Test file restore
test_restore_files() {
    local backup_file="$1"
    local test_dir="/tmp/restore_test_$(date +%s)"

    log_info "Testing file restore to: $test_dir"

    # Create test directory
    mkdir -p "$test_dir"

    # Extract archive
    tar -xzf "$backup_file" -C "$test_dir"

    # Check if files were extracted
    if [[ -n "$(ls -A $test_dir)" ]]; then
        log_info "File restore test completed successfully"
    else
        log_error "File restore test failed - no files extracted"
    fi

    # Clean up
    rm -rf "$test_dir"
}

# Auto-detect backup type
auto_detect_type() {
    local file="$1"

    if [[ "$file" =~ \.sql(\.gz)?$ ]]; then
        echo "database"
    elif [[ "$file" =~ \.tar(\.gz)?$ ]]; then
        echo "files"
    else
        echo "unknown"
    fi
}

# Scan backup directory
scan_backup_directory() {
    local dir="$1"

    log_info "Scanning backup directory: $dir"

    local backups=()

    # Find database backups
    while IFS= read -r -d '' file; do
        backups+=("$file")
    done < <(find "$dir" -type f \( -name "*.sql" -o -name "*.sql.gz" \) -print0)

    # Find file backups
    while IFS= read -r -d '' file; do
        backups+=("$file")
    done < <(find "$dir" -type f -name "*.tar.gz" -print0)

    echo "${backups[@]}"
}

# Generate verification report
generate_report() {
    log_info "=== Verification Report ==="
    echo "  Verified: $VERIFIED_COUNT"
    echo "  Failed: $FAILED_COUNT"
    echo "  Total Size: $(format_bytes $TOTAL_SIZE)"
    echo "=========================="
}

# Main execution
main() {
    log_info "=== Backup Verification Started ==="

    local backups=()

    # Determine what to verify
    if [[ -n "$BACKUP_PATH" ]]; then
        # Verify specific file
        backups=("$BACKUP_PATH")
    elif [[ -d "$BACKUP_DIR" ]]; then
        # Scan backup directory
        backups=($(scan_backup_directory "$BACKUP_DIR"))
    else
        log_error "No backup path or directory specified"
        exit 1
    fi

    # Verify each backup
    for backup in "${backups[@]}"; do
        # Determine type
        local type="$BACKUP_TYPE"
        if [[ "$type" == "auto" ]]; then
            type=$(auto_detect_type "$backup")
        fi

        # Verify based on type
        case "$type" in
            database)
                if ! verify_database_backup "$backup"; then
                    ((FAILED_COUNT++))
                    send_alert "Database backup verification failed: $backup"
                fi
                ;;
            files)
                if ! verify_file_backup "$backup"; then
                    ((FAILED_COUNT++))
                    send_alert "File backup verification failed: $backup"
                fi
                ;;
            *)
                log_warn "Unknown backup type for: $backup"
                ((FAILED_COUNT++))
                ;;
        esac
    done

    # Generate report
    generate_report

    # Exit with appropriate code
    if [[ $FAILED_COUNT -gt 0 ]]; then
        log_error "Verification completed with failures"
        exit 1
    else
        log_info "All backups verified successfully"
        exit 0
    fi
}

# Run main function
main "$@"
