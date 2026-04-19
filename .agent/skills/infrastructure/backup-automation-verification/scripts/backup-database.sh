#!/bin/bash
################################################################################
# Automated Database Backup Script with Compression
# Supports: MySQL, PostgreSQL, SQLite
# Usage: ./backup-database.sh [mysql|postgres|sqlite] [--compress] [--encrypt]
################################################################################

set -euo pipefail

# Configuration from environment or defaults
DB_TYPE="${1:-${DB_CONNECTION:-mysql}}"
BACKUP_DIR="${BACKUP_DIR:-/var/backups/database}"
COMPRESS="${COMPRESS:-true}"
ENCRYPT="${ENCRYPT:-false}"
ENCRYPT_KEY="${ENCRYPT_KEY:-}"
UPLOAD_S3="${UPLOAD_S3:-false}"
S3_BUCKET="${S3_BUCKET:-}"
RETENTION_DAYS="${RETENTION_DAYS:-30}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging functions
log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Create backup directory
mkdir -p "$BACKUP_DIR"

# Generate timestamp
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_FILE="backup_${DB_TYPE}_${TIMESTAMP}.sql"
BACKUP_PATH="${BACKUP_DIR}/${BACKUP_FILE}"

# Check dependencies
check_dependencies() {
    local deps=(tar gzip)
    if [[ "$COMPRESS" == "true" ]]; then
        deps+=(gzip)
    fi
    if [[ "$ENCRYPT" == "true" ]]; then
        deps+=(openssl)
    fi
    if [[ "$UPLOAD_S3" == "true" ]]; then
        deps+=(aws)
    fi

    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            log_error "Required dependency not found: $dep"
            exit 1
        fi
    done
}

# MySQL backup function
backup_mysql() {
    local host="${DB_HOST:-127.0.0.1}"
    local port="${DB_PORT:-3306}"
    local user="${DB_USERNAME:-root}"
    local password="${DB_PASSWORD:-}"
    local database="${DB_DATABASE:-laravel}"

    log_info "Starting MySQL backup for database: $database"

    # Build mysqldump command
    local dump_cmd=(
        "mysqldump"
        "--host=$host"
        "--port=$port"
        "--user=$user"
        "--password=$password"
        "--single-transaction"
        "--quick"
        "--lock-tables=false"
        "--routines"
        "--triggers"
        "--events"
        "$database"
    )

    # Execute backup
    if [[ "$COMPRESS" == "true" ]]; then
        "${dump_cmd[@]}" 2>/dev/null | gzip > "${BACKUP_PATH}.gz"
        BACKUP_PATH="${BACKUP_PATH}.gz"
    else
        "${dump_cmd[@]}" 2>/dev/null > "$BACKUP_PATH"
    fi

    if [[ ${PIPESTATUS[0]} -eq 0 ]]; then
        log_info "MySQL backup completed successfully"
        return 0
    else
        log_error "MySQL backup failed"
        return 1
    fi
}

# PostgreSQL backup function
backup_postgres() {
    local host="${DB_HOST:-127.0.0.1}"
    local port="${DB_PORT:-5432}"
    local user="${DB_USERNAME:-postgres}"
    local database="${DB_DATABASE:-laravel}"

    log_info "Starting PostgreSQL backup for database: $database"

    # Set password for pg_dump
    export PGPASSWORD="$DB_PASSWORD"

    # Build pg_dump command
    local dump_cmd=(
        "pg_dump"
        "--host=$host"
        "--port=$port"
        "--username=$user"
        "--no-owner"
        "--no-acl"
        "--format=plain"
        "$database"
    )

    # Execute backup
    if [[ "$COMPRESS" == "true" ]]; then
        "${dump_cmd[@]}" 2>/dev/null | gzip > "${BACKUP_PATH}.gz"
        BACKUP_PATH="${BACKUP_PATH}.gz"
    else
        "${dump_cmd[@]}" 2>/dev/null > "$BACKUP_PATH"
    fi

    if [[ ${PIPESTATUS[0]} -eq 0 ]]; then
        log_info "PostgreSQL backup completed successfully"
        return 0
    else
        log_error "PostgreSQL backup failed"
        return 1
    fi
}

# SQLite backup function
backup_sqlite() {
    local database="${DB_DATABASE:-database.sqlite}"
    local db_path="${DB_PATH:-${database}}"

    log_info "Starting SQLite backup for database: $db_path"

    if [[ ! -f "$db_path" ]]; then
        log_error "Database file not found: $db_path"
        return 1
    fi

    # Use SQLite's online backup API
    if [[ "$COMPRESS" == "true" ]]; then
        sqlite3 "$db_path" ".backup '${BACKUP_PATH}'"
        gzip "$BACKUP_PATH"
        BACKUP_PATH="${BACKUP_PATH}.gz"
    else
        sqlite3 "$db_path" ".backup '$BACKUP_PATH'"
    fi

    if [[ -f "$BACKUP_PATH" ]]; then
        log_info "SQLite backup completed successfully"
        return 0
    else
        log_error "SQLite backup failed"
        return 1
    fi
}

# Encrypt backup
encrypt_backup() {
    if [[ "$ENCRYPT" != "true" ]]; then
        return 0
    fi

    if [[ -z "$ENCRYPT_KEY" ]]; then
        log_warn "Encryption enabled but ENCRYPT_KEY not set, skipping encryption"
        return 0
    fi

    log_info "Encrypting backup..."

    local encrypted_path="${BACKUP_PATH}.enc"
    openssl enc -aes-256-cbc -salt -in "$BACKUP_PATH" \
        -out "$encrypted_path" -k "$ENCRYPT_KEY"

    if [[ -f "$encrypted_path" ]]; then
        rm "$BACKUP_PATH"
        BACKUP_PATH="$encrypted_path"
        log_info "Backup encrypted successfully"
        return 0
    else
        log_error "Backup encryption failed"
        return 1
    fi
}

# Upload to S3
upload_to_s3() {
    if [[ "$UPLOAD_S3" != "true" ]]; then
        return 0
    fi

    if [[ -z "$S3_BUCKET" ]]; then
        log_warn "S3 upload enabled but S3_BUCKET not set, skipping upload"
        return 0
    fi

    log_info "Uploading backup to S3..."

    local s3_path="s3://${S3_BUCKET}/database/$(basename "$BACKUP_PATH")"

    if aws s3 cp "$BACKUP_PATH" "$s3_path"; then
        log_info "Backup uploaded to S3: $s3_path"

        # Optionally delete local copy after successful upload
        if [[ "${DELETE_LOCAL_AFTER_UPLOAD:-false}" == "true" ]]; then
            rm "$BACKUP_PATH"
            log_info "Local copy removed"
        fi
        return 0
    else
        log_error "S3 upload failed"
        return 1
    fi
}

# Generate checksum
generate_checksum() {
    log_info "Generating checksum..."

    local checksum_file="${BACKUP_PATH}.sha256"
    sha256sum "$BACKUP_PATH" > "$checksum_file"

    log_info "Checksum saved to: $checksum_file"
}

# Display backup info
display_info() {
    local file_size=$(du -h "$BACKUP_PATH" | cut -f1)
    local file_name=$(basename "$BACKUP_PATH")

    log_info "Backup Details:"
    echo "  File: $file_name"
    echo "  Size: $file_size"
    echo "  Path: $BACKUP_PATH"
    echo "  Timestamp: $TIMESTAMP"
}

# Main execution
main() {
    log_info "=== Database Backup Started ==="
    log_info "Database Type: $DB_TYPE"
    log_info "Timestamp: $TIMESTAMP"

    # Check dependencies
    check_dependencies

    # Execute backup based on type
    case "$DB_TYPE" in
        mysql|mariadb)
            backup_mysql
            ;;
        postgres|postgresql|pgsql)
            backup_postgres
            ;;
        sqlite)
            backup_sqlite
            ;;
        *)
            log_error "Unsupported database type: $DB_TYPE"
            log_error "Supported types: mysql, postgres, sqlite"
            exit 1
            ;;
    esac

    # Check if backup was created
    if [[ ! -f "$BACKUP_PATH" ]]; then
        log_error "Backup file was not created"
        exit 1
    fi

    # Encrypt backup
    encrypt_backup

    # Generate checksum
    generate_checksum

    # Upload to S3
    upload_to_s3

    # Display info
    display_info

    log_info "=== Database Backup Completed Successfully ==="

    # Exit with success
    exit 0
}

# Run main function
main "$@"
