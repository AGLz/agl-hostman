#!/bin/bash
##############################################################################
# Migration Rollback Script
#
# Safely rolls back migrations with data preservation
#
# Usage:
#   ./scripts/migration-rollback.sh [environment] [steps]
#
# Example:
#   ./scripts/migration-rollback.sh staging       # Rollback last migration
#   ./scripts/migration-rollback.sh staging 5     # Rollback last 5 migrations
#   ./scripts/migration-rollback.sh staging all   # Rollback all migrations
##############################################################################

set -e

# Configuration
ENVIRONMENT=${1:-staging}
STEPS=${2:-1}
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ROLLBACK_LOG="${PROJECT_ROOT}/storage/rollback-${ENVIRONMENT}-$(date +%Y%m%d-%H%M%S).log"
STORAGE_DIR="${PROJECT_ROOT}/storage"

# Colors for output
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Create storage directory if not exists
mkdir -p "${STORAGE_DIR}"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Migration Rollback - ${ENVIRONMENT}${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Initialize log
{
    echo "Migration Rollback Log"
    echo "Environment: ${ENVIRONMENT}"
    echo "Steps: ${STEPS}"
    echo "Started: $(date)"
    echo "=========================================="
    echo ""
} > "${ROLLBACK_LOG}"

##############################################################################
# Function: Log message
##############################################################################
log_message() {
    local level=$1
    shift
    local message="$@"

    local level_color
    case "${level}" in
        ERROR) level_color="${RED}" ;;
        WARN) level_color="${YELLOW}" ;;
        INFO) level_color="${BLUE}" ;;
        SUCCESS) level_color="${GREEN}" ;;
    esac

    echo -e "${level_color}[${level}]${NC} ${message}"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [${level}] ${message}" >> "${ROLLBACK_LOG}"
}

##############################################################################
# Function: Confirm rollback
##############################################################################
confirm_rollback() {
    if [ "${SKIP_CONFIRM}" != "true" ]; then
        echo -e "${YELLOW}WARNING: This will rollback migrations from ${ENVIRONMENT}!${NC}"
        echo -e "${YELLOW}This action may result in data loss or application errors.${NC}"
        echo ""
        read -p "Are you sure you want to continue? (type 'yes' to confirm): " confirmation

        if [ "${confirmation}" != "yes" ]; then
            log_message "INFO" "Rollback cancelled by user"
            exit 0
        fi
        echo ""
    fi
}

##############################################################################
# Function: Get current migration status
##############################################################################
get_migration_status() {
    log_message "INFO" "Getting current migration status..."

    cd "${PROJECT_ROOT}"

    php artisan migrate:status > "${STORAGE_DIR}/migrate-status-before-rollback.txt" 2>&1

    local last_migration=$(grep -oP 'Migrated: \K[0-9]{4}_[0-9]{2}_[0-9]{2}_[0-9]{6}_[^_]+' "${STORAGE_DIR}/migrate-status-before-rollback.txt" | tail -n1 || echo "")

    if [ -z "${last_migration}" ]; then
        log_message "WARN" "No migrations to rollback"
        exit 0
    fi

    log_message "INFO" "Last migration: ${last_migration}"

    # Show what will be rolled back
    if [ "${STEPS}" = "all" ]; then
        local count=$(grep -c "^Migrated:" "${STORAGE_DIR}/migrate-status-before-rollback.txt" || echo "0")
        log_message "INFO" "Will rollback all ${count} migrations"
    else
        log_message "INFO" "Will rollback last ${STEPS} migration(s)"
    fi

    echo ""
}

##############################################################################
# Function: Check for data dependency issues
##############################################################################
check_data_dependencies() {
    log_message "INFO" "Checking for data dependencies..."

    cd "${PROJECT_ROOT}"

    # Check if any tables have data that might be affected
    local tables_to_check=$(php artisan tinker --execute="
        \$migrator = app('migrator');
        \$migrations = \$migrator->getMigrationFiles(database_path('migrations'));
        \$last_migrations = array_slice(array_reverse(\$migrations), 0, ${STEPS});

        foreach (\$last_migrations as \$migration) {
            try {
                \$migration_instance = \$migrator->resolve(\$migration);
                if (method_exists(\$migration_instance, 'getTables')) {
                    \$tables = \$migration_instance->getTables();
                    foreach (\$tables as \$table) {
                        \$count = DB::table(\$table)->count();
                        if (\$count > 0) {
                            echo \"{\$table}: {\$count} rows\n\";
                        }
                    }
                }
            } catch (\Exception \$e) {
                // Ignore
            }
        }
    " 2>/dev/null || echo "")

    if [ -n "${tables_to_check}" ]; then
        log_message "WARN" "Tables with data that may be affected:"
        echo "${tables_to_check}" | while read -r line; do
            echo "  - ${line}"
        done
        echo ""
    fi
}

##############################################################################
# Function: Create pre-rollback backup
##############################################################################
create_pre_rollback_backup() {
    if [ "${CREATE_BACKUP}" != "false" ]; then
        log_message "INFO" "Creating pre-rollback backup..."

        local backup_file="${STORAGE_DIR}/backups/backup-before-rollback-${ENVIRONMENT}-$(date +%Y%m%d-%H%M%S).sql"
        mkdir -p "${STORAGE_DIR}/backups"

        cd "${PROJECT_ROOT}"

        if php artisan db:backup --path="${backup_file}" &>/dev/null; then
            log_message "SUCCESS" "Pre-rollback backup created: ${backup_file}"
        elif command -v mysqldump &> /dev/null; then
            # Use mysqldump if Laravel backup not available
            local db_name=$(php artisan tinker --execute="echo config('database.connections.mysql.database');" 2>/dev/null)
            local db_user=$(php artisan tinker --execute="echo config('database.connections.mysql.username');" 2>/dev/null)
            local db_host=$(php artisan tinker --execute="echo config('database.connections.mysql.host');" 2>/dev/null)

            if mysqldump -h "${db_host}" -u "${db_user}" -p"${DB_PASSWORD}" "${db_name}" > "${backup_file}" 2>/dev/null; then
                log_message "SUCCESS" "Pre-rollback backup created: ${backup_file}"
            else
                log_message "WARN" "Failed to create pre-rollback backup"
            fi
        else
            log_message "WARN" "No backup tool available. Skipping pre-rollback backup."
        fi
        echo ""
    fi
}

##############################################################################
# Function: Perform rollback
##############################################################################
perform_rollback() {
    log_message "INFO" "Performing rollback..."

    cd "${PROJECT_ROOT}"

    local start_time=$(date +%s)

    if [ "${STEPS}" = "all" ]; then
        if php artisan migrate:reset --force >> "${ROLLBACK_LOG}" 2>&1; then
            local end_time=$(date +%s)
            local duration=$((end_time - start_time))
            log_message "SUCCESS" "All migrations rolled back in ${duration}s"
        else
            log_message "ERROR" "Rollback failed. Check log: ${ROLLBACK_LOG}"
            exit 1
        fi
    else
        if php artisan migrate:rollback --step="${STEPS}" --force >> "${ROLLBACK_LOG}" 2>&1; then
            local end_time=$(date +%s)
            local duration=$((end_time - start_time))
            log_message "SUCCESS" "Last ${STEPS} migration(s) rolled back in ${duration}s"
        else
            log_message "ERROR" "Rollback failed. Check log: ${ROLLBACK_LOG}"
            exit 1
        fi
    fi

    echo ""
}

##############################################################################
# Function: Verify rollback
##############################################################################
verify_rollback() {
    log_message "INFO" "Verifying rollback..."

    cd "${PROJECT_ROOT}"

    # Get new migration status
    php artisan migrate:status > "${STORAGE_DIR}/migrate-status-after-rollback.txt" 2>&1

    # Compare before and after
    local before_count=$(grep -c "^Migrated:" "${STORAGE_DIR}/migrate-status-before-rollback.txt" || echo "0")
    local after_count=$(grep -c "^Migrated:" "${STORAGE_DIR}/migrate-status-after-rollback.txt" || echo "0")
    local rolled_back=$((before_count - after_count))

    log_message "INFO" "Migrations before: ${before_count}"
    log_message "INFO" "Migrations after: ${after_count}"
    log_message "INFO" "Migrations rolled back: ${rolled_back}"

    if [ "${STEPS}" = "all" ]; then
        if [ ${after_count} -eq 0 ]; then
            log_message "SUCCESS" "All migrations successfully rolled back"
        else
            log_message "WARN" "Some migrations could not be rolled back"
        fi
    else
        if [ ${rolled_back} -eq ${STEPS} ]; then
            log_message "SUCCESS" "Requested migrations successfully rolled back"
        else
            log_message "WARN" "Expected to rollback ${STEPS} migrations, actually rolled back ${rolled_back}"
        fi
    fi

    echo ""
}

##############################################################################
# Function: Check for orphaned data
##############################################################################
check_orphaned_data() {
    log_message "INFO" "Checking for orphaned data..."

    cd "${PROJECT_ROOT}"

    # Check for common orphaned data patterns
    local orphaned_check=$(php artisan tinker --execute="
        \$orphaned_found = false;

        // Check for tasks without sprints
        \$tasks_without_sprint = DB::table('tasks')
            ->whereNotNull('sprint_id')
            ->whereNotIn('sprint_id', function(\$q) {
                \$q->select('id')->from('sprints');
            })
            ->count();
        if (\$tasks_without_sprint > 0) {
            echo \"Orphaned tasks (no sprint): {\$tasks_without_sprint}\n\";
            \$orphaned_found = true;
        }

        // Check for container health logs without containers
        \$orphaned_health_logs = DB::table('container_health_logs')
            ->whereNotIn('lxc_container_id', function(\$q) {
                \$q->select('id')->from('lxc_containers');
            })
            ->count();
        if (\$orphaned_health_logs > 0) {
            echo \"Orphaned health logs (no container): {\$orphaned_health_logs}\n\";
            \$orphaned_found = true;
        }

        if (!\$orphaned_found) {
            echo \"No orphaned data detected\n\";
        }
    " 2>/dev/null || echo "")

    if echo "${orphaned_check}" | grep -q "No orphaned"; then
        log_message "SUCCESS" "No orphaned data detected"
    elif echo "${orphaned_check}" | grep -q "Orphaned"; then
        log_message "WARN" "Orphaned data detected:"
        echo "${orphaned_check}" | while read -r line; do
            echo "  - ${line}"
        done
    fi

    echo ""
}

##############################################################################
# Function: Test application after rollback
##############################################################################
test_application() {
    if [ "${RUN_TESTS}" = "true" ]; then
        log_message "INFO" "Testing application after rollback..."

        cd "${PROJECT_ROOT}"

        if php artisan test --parallel >> "${ROLLBACK_LOG}" 2>&1; then
            log_message "SUCCESS" "Application tests passed"
        else
            log_message "WARN" "Some application tests failed. Review may be needed."
        fi
        echo ""
    else
        log_message "INFO" "Skipping application tests (set RUN_TESTS=true to run)"
        echo ""
    fi
}

##############################################################################
# Function: Provide rollback summary
##############################################################################
rollback_summary() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}Rollback Summary${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""

    echo "Environment: ${ENVIRONMENT}"
    echo "Steps rolled back: ${STEPS}"
    echo ""
    echo "Next steps:"
    echo "1. Review the rollback log: ${ROLLBACK_LOG}"
    echo "2. Check application functionality"
    echo "3. Verify data integrity"
    echo "4. Plan re-migration if needed"
    echo ""

    {
        echo "=========================================="
        echo "Summary"
        echo "=========================================="
        echo "Environment: ${ENVIRONMENT}"
        echo "Steps: ${STEPS}"
        echo "Completed: $(date)"
    } >> "${ROLLBACK_LOG}"

    log_message "INFO" "Rollback completed. Log: ${ROLLBACK_LOG}"
}

##############################################################################
# Main execution
##############################################################################
main() {
    confirm_rollback
    get_migration_status
    check_data_dependencies
    create_pre_rollback_backup
    perform_rollback
    verify_rollback
    check_orphaned_data
    test_application
    rollback_summary
}

main "$@"
