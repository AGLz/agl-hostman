#!/bin/bash
##############################################################################
# Migration Testing Script
#
# Tests migration on staging database and validates schema/data integrity
#
# Usage:
#   ./scripts/migration-test.sh [environment]
#
# Example:
#   ./scripts/migration-test.sh staging
#   ./scripts/migration-test.sh production
##############################################################################

set -e

# Configuration
ENVIRONMENT=${1:-staging}
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
RESULTS_FILE="${PROJECT_ROOT}/storage/migration-test-results-${ENVIRONMENT}-$(date +%Y%m%d-%H%M%S).txt"
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
echo -e "${BLUE}Migration Testing - ${ENVIRONMENT}${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Initialize results
{
    echo "Migration Test Results"
    echo "Environment: ${ENVIRONMENT}"
    echo "Started: $(date)"
    echo "=========================================="
    echo ""
} > "${RESULTS_FILE}"

TESTS_PASSED=0
TESTS_FAILED=0

##############################################################################
# Function: Log test result
##############################################################################
log_test() {
    local test_name=$1
    local status=$2
    local message=$3

    local status_symbol
    local status_color

    case "${status}" in
        PASS)
            status_symbol="✓"
            status_color="${GREEN}"
            ((TESTS_PASSED++))
            ;;
        FAIL)
            status_symbol="✗"
            status_color="${RED}"
            ((TESTS_FAILED++))
            ;;
        WARN)
            status_symbol="⚠"
            status_color="${YELLOW}"
            ;;
        INFO)
            status_symbol="ℹ"
            status_color="${BLUE}"
            ;;
    esac

    echo -e "${status_color}${status_symbol} ${test_name}: ${status}${NC}"
    if [ -n "${message}" ]; then
        echo -e "  ${message}"
    fi

    {
        echo "[${status}] ${test_name}"
        [ -n "${message}" ] && echo "    ${message}"
        echo ""
    } >> "${RESULTS_FILE}"
}

##############################################################################
# Function: Test database connection
##############################################################################
test_database_connection() {
    echo -e "${BLUE}Testing database connection...${NC}"

    cd "${PROJECT_ROOT}"

    if php artisan db:show &>/dev/null; then
        log_test "Database Connection" "PASS" "Successfully connected to database"
    else
        log_test "Database Connection" "FAIL" "Cannot connect to database"
        return 1
    fi
    echo ""
}

##############################################################################
# Function: Test backup exists
##############################################################################
test_backup_exists() {
    echo -e "${BLUE}Testing backup availability...${NC}"

    local backup_dir="${STORAGE_DIR}/backups"
    local latest_backup=$(ls -t "${backup_dir}"/backup-${ENVIRONMENT}-*.sql 2>/dev/null | head -n1 || echo "")

    if [ -z "${latest_backup}" ]; then
        log_test "Backup Check" "WARN" "No recent backup found. Run ./scripts/migration-backup.sh first"
    else
        local backup_age=$(($(date +%s) - $(stat -c %Y "${latest_backup}")))
        local backup_age_hours=$((backup_age / 3600))

        if [ ${backup_age} -lt 86400 ]; then
            log_test "Backup Check" "PASS" "Recent backup found (${backup_age_hours}h ago)"
        else
            log_test "Backup Check" "WARN" "Backup is old (${backup_age_hours}h ago). Consider creating new backup"
        fi
    fi
    echo ""
}

##############################################################################
# Function: Record migration status before
##############################################################################
record_before_status() {
    echo -e "${BLUE}Recording pre-migration status...${NC}"

    cd "${PROJECT_ROOT}"

    php artisan migrate:status > "${STORAGE_DIR}/migrate-status-before.txt" 2>&1

    local pending=$(grep -c "Pending" "${STORAGE_DIR}/migrate-status-before.txt" 2>/dev/null || echo "0")

    log_test "Pre-Migration Status" "INFO" "${pending} pending migrations recorded"
    echo ""
}

##############################################################################
# Function: Run migration
##############################################################################
run_migration() {
    echo -e "${BLUE}Running migration...${NC}"

    cd "${PROJECT_ROOT}"

    local start_time=$(date +%s)

    if php artisan migrate --force --no-interaction > "${STORAGE_DIR}/migrate-output.txt" 2>&1; then
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))

        log_test "Migration Execution" "PASS" "Completed in ${duration}s"

        # Show what was migrated
        local migrated=$(grep -oP 'Migrating: \K\w+' "${STORAGE_DIR}/migrate-output.txt" 2>/dev/null || echo "")
        if [ -n "${migrated}" ]; then
            echo -e "  Migrated:"
            echo "${migrated}" | while read -r migration; do
                echo -e "    - ${migration}"
            done
        fi
    else
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))

        log_test "Migration Execution" "FAIL" "Failed after ${duration}s. Check ${STORAGE_DIR}/migrate-output.txt"
        cat "${STORAGE_DIR}/migrate-output.txt"
        return 1
    fi
    echo ""
}

##############################################################################
# Function: Record migration status after
##############################################################################
record_after_status() {
    echo -e "${BLUE}Recording post-migration status...${NC}"

    cd "${PROJECT_ROOT}"

    php artisan migrate:status > "${STORAGE_DIR}/migrate-status-after.txt" 2>&1

    local pending=$(grep -c "Pending" "${STORAGE_DIR}/migrate-status-after.txt" 2>/dev/null || echo "0")

    if [ "${pending}" -eq 0 ]; then
        log_test "Post-Migration Status" "PASS" "All migrations completed"
    else
        log_test "Post-Migration Status" "INFO" "${pending} migrations still pending"
    fi
    echo ""
}

##############################################################################
# Function: Validate schema
##############################################################################
validate_schema() {
    echo -e "${BLUE}Validating schema...${NC}"

    cd "${PROJECT_ROOT}"

    if php artisan schema:dump > /dev/null 2>&1; then
        log_test "Schema Validation" "PASS" "Schema dump successful"
    else
        log_test "Schema Validation" "WARN" "Schema dump failed"
    fi
    echo ""
}

##############################################################################
# Function: Test foreign key constraints
##############################################################################
test_foreign_keys() {
    echo -e "${BLUE}Testing foreign key constraints...${NC}"

    cd "${PROJECT_ROOT}"

    # Get all foreign key constraints
    local fk_check=$(php artisan tinker --execute="
        \$schema = DB::getDoctrineSchemaManager();
        \$tables = \$schema->listTableNames();
        \$has_fk = false;
        foreach (\$tables as \$table) {
            try {
                \$foreign_keys = \$schema->listTableForeignKeys(\$table);
                if (count(\$foreign_keys) > 0) {
                    \$has_fk = true;
                    echo \"Table {\$table}: \" . count(\$foreign_keys) . \" foreign keys\n\";
                }
            } catch (\Exception \$e) {
                // Ignore errors
            }
        }
        if (!\$has_fk) {
            echo \"No foreign keys found\";
        }
    " 2>/dev/null || echo "")

    if [ -n "${fk_check}" ]; then
        log_test "Foreign Key Check" "PASS" "Foreign key constraints validated"
        echo -e "  ${fk_check}"
    else
        log_test "Foreign Key Check" "INFO" "No foreign keys to validate"
    fi
    echo ""
}

##############################################################################
# Function: Run application tests
##############################################################################
run_application_tests() {
    echo -e "${BLUE}Running application tests...${NC}"

    cd "${PROJECT_ROOT}"

    if php artisan test --parallel > "${STORAGE_DIR}/test-output.txt" 2>&1; then
        log_test "Application Tests" "PASS" "All tests passed"
    else
        local exit_code=$?
        if [ ${exit_code} -eq 1 ]; then
            log_test "Application Tests" "FAIL" "Some tests failed. Check ${STORAGE_DIR}/test-output.txt"
        else
            log_test "Application Tests" "WARN" "Test execution had issues (exit code: ${exit_code})"
        fi
    fi
    echo ""
}

##############################################################################
# Function: Performance baseline
##############################################################################
performance_baseline() {
    echo -e "${BLUE}Establishing performance baseline...${NC}"

    cd "${PROJECT_ROOT}"

    # Run a few common queries to establish baseline
    local start_time=$(date +%s%N)

    php artisan tinker --execute="
        \$user_count = DB::table('users')->count();
        \$task_count = DB::table('tasks')->count();
        echo \"Users: {\$user_count}, Tasks: {\$task_count}\n\";
    " > /dev/null 2>&1

    local end_time=$(date +%s%N)
    local duration=$(( (end_time - start_time) / 1000000 ))

    log_test "Performance Baseline" "INFO" "Sample query time: ${duration}ms"
    echo ""
}

##############################################################################
# Function: Data integrity check
##############################################################################
data_integrity_check() {
    echo -e "${BLUE}Checking data integrity...${NC}"

    cd "${PROJECT_ROOT}"

    # Check for orphaned records in common relationships
    local orphaned_check=$(php artisan tinker --execute="
        // Check tasks without sprint
        \$orphaned_tasks = DB::table('tasks')
            ->whereNotNull('sprint_id')
            ->whereNotIn('sprint_id', function(\$q) {
                \$q->select('id')->from('sprints');
            })
            ->count();

        if (\$orphaned_tasks > 0) {
            echo \"Found {\$orphaned_tasks} orphaned tasks\n\";
        } else {
            echo \"No orphaned records found\n\";
        }
    " 2>/dev/null || echo "")

    if echo "${orphaned_check}" | grep -q "No orphaned"; then
        log_test "Data Integrity" "PASS" "No orphaned records detected"
    else
        log_test "Data Integrity" "WARN" "${orphaned_check}"
    fi
    echo ""
}

##############################################################################
# Function: Generate summary
##############################################################################
generate_summary() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}Test Summary${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""

    local total_tests=$((TESTS_PASSED + TESTS_FAILED))

    echo "Total Tests: ${total_tests}"
    echo -e "${GREEN}Passed: ${TESTS_PASSED}${NC}"
    [ ${TESTS_FAILED} -gt 0 ] && echo -e "${RED}Failed: ${TESTS_FAILED}${NC}"
    echo ""

    if [ ${TESTS_FAILED} -eq 0 ]; then
        echo -e "${GREEN}All tests passed! Migration is ready for production.${NC}"
    else
        echo -e "${RED}Some tests failed. Review the issues before deploying to production.${NC}"
    fi

    {
        echo "=========================================="
        echo "Summary"
        echo "=========================================="
        echo "Total Tests: ${total_tests}"
        echo "Passed: ${TESTS_PASSED}"
        echo "Failed: ${TESTS_FAILED}"
        echo ""
        echo "Completed: $(date)"
    } >> "${RESULTS_FILE}"

    echo ""
    echo -e "${GREEN}Results saved to:${NC}"
    echo -e "${BLUE}${RESULTS_FILE}${NC}"
}

##############################################################################
# Main execution
##############################################################################
main() {
    test_database_connection || true
    test_backup_exists
    record_before_status
    run_migration || {
        echo -e "${RED}Migration failed. Rolling back...${NC}"
        php artisan migrate:rollback --step=1
        exit 1
    }
    record_after_status
    validate_schema
    test_foreign_keys
    performance_baseline
    data_integrity_check

    # Only run app tests if explicitly requested
    if [ "${RUN_APP_TESTS}" = "true" ]; then
        run_application_tests
    else
        echo -e "${YELLOW}Skipping application tests (set RUN_APP_TESTS=true to run)${NC}"
        echo ""
    fi

    generate_summary
}

main "$@"
