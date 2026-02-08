#!/bin/bash
##############################################################################
# Migration Backup Script
#
# Creates comprehensive backup before migration operations
#
# Usage:
#   ./scripts/migration-backup.sh [environment]
#
# Example:
#   ./scripts/migration-backup.sh staging
#   ./scripts/migration-backup.sh production
##############################################################################

set -e

# Configuration
ENVIRONMENT=${1:-staging}
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BACKUP_DIR="${PROJECT_ROOT}/storage/backups"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
BACKUP_NAME="backup-${ENVIRONMENT}-${TIMESTAMP}"
STORAGE_DIR="${PROJECT_ROOT}/storage"

# Colors for output
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Create backup directory
mkdir -p "${BACKUP_DIR}"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Database Backup - ${ENVIRONMENT}${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

##############################################################################
# Function: Get database credentials
##############################################################################
get_db_credentials() {
    cd "${PROJECT_ROOT}"

    DB_CONNECTION=$(php artisan tinker --execute="echo config('database.default');" 2>/dev/null || echo "mysql")
    DB_HOST=$(php artisan tinker --execute="echo config('database.connections.${DB_CONNECTION}.host');" 2>/dev/null || echo "localhost")
    DB_PORT=$(php artisan tinker --execute="echo config('database.connections.${DB_CONNECTION}.port');" 2>/dev/null || echo "3306")
    DB_DATABASE=$(php artisan tinker --execute="echo config('database.connections.${DB_CONNECTION}.database');" 2>/dev/null || echo "")
    DB_USERNAME=$(php artisan tinker --execute="echo config('database.connections.${DB_CONNECTION}.username');" 2>/dev/null || echo "root")

    echo -e "${BLUE}Database: ${DB_DATABASE} @ ${DB_HOST}:${DB_PORT}${NC}"
    echo ""
}

##############################################################################
# Function: Backup MySQL database
##############################################################################
backup_mysql() {
    echo -e "${BLUE}Creating MySQL backup...${NC}"

    local backup_file="${BACKUP_DIR}/${BACKUP_NAME}.sql"

    if command -v mysqldump &> /dev/null; then
        # Create full backup with routines and triggers
        if mysqldump -h "${DB_HOST}" -P "${DB_PORT}" -u "${DB_USERNAME}" -p"${DB_PASSWORD}" \
            --single-transaction \
            --routines \
            --triggers \
            --events \
            --quick \
            --lock-tables=false \
            "${DB_DATABASE}" > "${backup_file}" 2>/dev/null; then

            # Compress the backup
            gzip "${backup_file}"
            backup_file="${backup_file}.gz"

            local size=$(du -h "${backup_file}" | cut -f1)
            echo -e "${GREEN}Backup created: ${backup_file}${NC}"
            echo -e "${GREEN}Size: ${size}${NC}"
        else
            echo -e "${RED}MySQL backup failed${NC}"
            return 1
        fi
    else
        echo -e "${YELLOW}mysqldump not found, trying Laravel db:show...${NC}"

        # Use Laravel's schema dump as fallback
        if php artisan schema:dump --database="${DB_CONNECTION}" "${backup_file}" &>/dev/null; then
            echo -e "${GREEN}Schema backup created: ${backup_file}${NC}"
            echo -e "${YELLOW}Note: This is a schema-only backup. Data backup requires mysqldump.${NC}"
        else
            echo -e "${RED}Laravel schema dump failed${NC}"
            return 1
        fi
    fi

    echo ""
    return 0
}

##############################################################################
# Function: Backup PostgreSQL database
##############################################################################
backup_postgresql() {
    echo -e "${BLUE}Creating PostgreSQL backup...${NC}"

    local backup_file="${BACKUP_DIR}/${BACKUP_NAME}.sql"

    if command -v pg_dump &> /dev/null; then
        # Set PGPASSWORD environment variable for pg_dump
        export PGPASSWORD="${DB_PASSWORD}"

        if pg_dump -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USERNAME}" \
            --format=plain \
            --no-owner \
            --no-acl \
            --verbose \
            "${DB_DATABASE}" > "${backup_file}" 2>/dev/null; then

            # Compress the backup
            gzip "${backup_file}"
            backup_file="${backup_file}.gz"

            local size=$(du -h "${backup_file}" | cut -f1)
            echo -e "${GREEN}Backup created: ${backup_file}${NC}"
            echo -e "${GREEN}Size: ${size}${NC}"
        else
            echo -e "${RED}PostgreSQL backup failed${NC}"
            return 1
        fi

        unset PGPASSWORD
    else
        echo -e "${RED}pg_dump not found${NC}"
        return 1
    fi

    echo ""
    return 0
}

##############################################################################
# Function: Backup SQLite database
##############################################################################
backup_sqlite() {
    echo -e "${BLUE}Creating SQLite backup...${NC}"

    local db_path="${PROJECT_ROOT}/database/database.sqlite"
    local backup_file="${BACKUP_DIR}/${BACKUP_NAME}.sqlite"

    if [ -f "${db_path}" ]; then
        if cp "${db_path}" "${backup_file}"; then
            # Compress the backup
            gzip "${backup_file}"
            backup_file="${backup_file}.gz"

            local size=$(du -h "${backup_file}" | cut -f1)
            echo -e "${GREEN}Backup created: ${backup_file}${NC}"
            echo -e "${GREEN}Size: ${size}${NC}"
        else
            echo -e "${RED}SQLite backup failed${NC}"
            return 1
        fi
    else
        echo -e "${YELLOW}SQLite database not found at ${db_path}${NC}"
        return 1
    fi

    echo ""
    return 0
}

##############################################################################
# Function: Backup migration state
##############################################################################
backup_migration_state() {
    echo -e "${BLUE}Backing up migration state...${NC}"

    cd "${PROJECT_ROOT}"

    # Save current migration status
    php artisan migrate:status > "${BACKUP_DIR}/${BACKUP_NAME}-migrate-status.txt" 2>&1

    # Copy migrations directory
    cp -r "${PROJECT_ROOT}/src/database/migrations" "${BACKUP_DIR}/${BACKUP_NAME}-migrations/"

    echo -e "${GREEN}Migration state backed up${NC}"
    echo ""
}

##############################################################################
# Function: Create checksum
##############################################################################
create_checksum() {
    echo -e "${BLUE}Creating backup checksum...${NC}"

    local backup_file=$(ls -t "${BACKUP_DIR}/${BACKUP_NAME}".* 2>/dev/null | head -n1)

    if [ -n "${backup_file}" ]; then
        sha256sum "${backup_file}" > "${backup_file}.sha256"
        echo -e "${GREEN}Checksum created: ${backup_file}.sha256${NC}"
    else
        echo -e "${YELLOW}No backup file to checksum${NC}"
    fi

    echo ""
}

##############################################################################
# Function: Verify backup
##############################################################################
verify_backup() {
    echo -e "${BLUE}Verifying backup...${NC}"

    local backup_file=$(ls -t "${BACKUP_DIR}/${BACKUP_NAME}".* 2>/dev/null | grep -v "\.sha256" | head -n1)

    if [ -n "${backup_file}" ]; then
        # For compressed files, test integrity
        if [[ "${backup_file}" == *.gz ]]; then
            if gzip -t "${backup_file}" 2>/dev/null; then
                echo -e "${GREEN}Backup file integrity verified${NC}"
            else
                echo -e "${RED}Backup file is corrupted${NC}"
                return 1
            fi
        fi

        # Verify checksum if exists
        if [ -f "${backup_file}.sha256" ]; then
            if sha256sum -c "${backup_file}.sha256}" &>/dev/null; then
                echo -e "${GREEN}Checksum verified${NC}"
            else
                echo -e "${RED}Checksum verification failed${NC}"
                return 1
            fi
        fi
    else
        echo -e "${RED}No backup file found to verify${NC}"
        return 1
    fi

    echo ""
    return 0
}

##############################################################################
# Function: Create backup metadata
##############################################################################
create_metadata() {
    echo -e "${BLUE}Creating backup metadata...${NC}"

    local metadata_file="${BACKUP_DIR}/${BACKUP_NAME}-metadata.json"

    cat > "${metadata_file}" << EOF
{
  "name": "${BACKUP_NAME}",
  "environment": "${ENVIRONMENT}",
  "database": "${DB_DATABASE}",
  "host": "${DB_HOST}",
  "port": "${DB_PORT}",
  "created_at": "$(date -Iseconds)",
  "created_by": "$(whoami)",
  "hostname": "$(hostname)",
  "git_branch": "$(git branch --show-current 2>/dev/null || echo 'unknown')",
  "git_commit": "$(git rev-parse HEAD 2>/dev/null || echo 'unknown')",
  "laravel_version": "$(php artisan --version 2>/dev/null | awk '{print $3}' || echo 'unknown')"
}
EOF

    echo -e "${GREEN}Metadata created: ${metadata_file}${NC}"
    echo ""
}

##############################################################################
# Function: Cleanup old backups
##############################################################################
cleanup_old_backups() {
    echo -e "${BLUE}Cleaning up old backups...${NC}"

    local keep_days=${BACKUP_RETENTION_DAYS:-7}
    local old_backups=$(find "${BACKUP_DIR}" -name "backup-${ENVIRONMENT}-*.sql.gz" -mtime +${keep_days})

    if [ -n "${old_backups}" ]; then
        echo "Removing backups older than ${keep_days} days:"
        echo "${old_backups}" | while read -r backup; do
            echo "  - $(basename ${backup})"
            rm "${backup}"
            # Also remove associated files
            rm -f "${backup}.sha256"
            rm -f "${backup%.sql.gz}"-*
        done
        echo -e "${GREEN}Old backups removed${NC}"
    else
        echo -e "${GREEN}No old backups to remove${NC}"
    fi

    echo ""
}

##############################################################################
# Function: List backups
##############################################################################
list_backups() {
    echo -e "${BLUE}Available backups for ${ENVIRONMENT}:${NC}"
    echo ""

    local backups=$(ls -t "${BACKUP_DIR}/backup-${ENVIRONMENT}-"*metadata.json 2>/dev/null || echo "")

    if [ -n "${backups}" ]; then
        echo "${backups}" | while read -r metadata; do
            local name=$(jq -r '.name' "${metadata}" 2>/dev/null || echo "unknown")
            local created=$(jq -r '.created_at' "${metadata}" 2>/dev/null || echo "unknown")
            local size=$(du -h "${BACKUP_DIR}/${name}.sql.gz" 2>/dev/null | cut -f1 || echo "unknown")

            echo "  - ${name}"
            echo "    Created: ${created}"
            echo "    Size: ${size}"
            echo ""
        done
    else
        echo "  No backups found"
        echo ""
    fi
}

##############################################################################
# Main execution
##############################################################################
main() {
    get_db_credentials

    # Create backup based on database type
    case "${DB_CONNECTION}" in
        mysql)
            backup_mysql || exit 1
            ;;
        pgsql|postgresql)
            backup_postgresql || exit 1
            ;;
        sqlite)
            backup_sqlite || exit 1
            ;;
        *)
            echo -e "${RED}Unknown database connection: ${DB_CONNECTION}${NC}"
            exit 1
            ;;
    esac

    backup_migration_state
    create_checksum
    verify_backup || exit 1
    create_metadata

    # Cleanup old backups if not disabled
    if [ "${SKIP_CLEANUP}" != "true" ]; then
        cleanup_old_backups
    fi

    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}Backup completed successfully!${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""

    list_backups
}

main "$@"
