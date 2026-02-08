#!/bin/bash
##############################################################################
# Migration Planning Script
#
# Analyzes migrations and generates execution plan with risk assessment
#
# Usage:
#   ./scripts/migration-plan.sh [environment]
#
# Example:
#   ./scripts/migration-plan.sh staging
#   ./scripts/migration-plan.sh production
##############################################################################

set -e

# Configuration
ENVIRONMENT=${1:-staging}
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
MIGRATIONS_DIR="${PROJECT_ROOT}/src/database/migrations"
REPORT_FILE="${PROJECT_ROOT}/storage/migration-plan-${ENVIRONMENT}-$(date +%Y%m%d-%H%M%S).txt"
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
echo -e "${BLUE}Migration Planning for ${ENVIRONMENT}${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Initialize report
{
    echo "Migration Execution Plan"
    echo "Environment: ${ENVIRONMENT}"
    echo "Generated: $(date)"
    echo "=========================================="
    echo ""
} > "${REPORT_FILE}"

##############################################################################
# Function: Get database connection info
##############################################################################
get_db_connection() {
    case "${ENVIRONMENT}" in
        staging)
            DB_HOST=${DB_STAGING_HOST:-localhost}
            DB_NAME=${DB_STAGING_DATABASE:-agl_staging}
            DB_USER=${DB_STAGING_USERNAME:-root}
            ;;
        production)
            DB_HOST=${DB_PRODUCTION_HOST:-localhost}
            DB_NAME=${DB_PRODUCTION_DATABASE:-agl_production}
            DB_USER=${DB_PRODUCTION_USERNAME:-root}
            ;;
        *)
            DB_HOST=${DB_HOST:-localhost}
            DB_NAME=${DB_DATABASE:-agl}
            DB_USER=${DB_USERNAME:-root}
            ;;
    esac
}

##############################################################################
# Function: Check table size
##############################################################################
check_table_size() {
    local table=$1

    if command -v mysql &> /dev/null; then
        mysql -h "${DB_HOST}" -u "${DB_USER}" -p"${DB_PASSWORD}" "${DB_NAME}" -e "
            SELECT
                table_name AS 'Table',
                table_rows AS 'Rows',
                ROUND((data_length + index_length) / 1024 / 1024, 2) AS 'Size (MB)',
                ROUND(index_length / 1024 / 1024, 2) AS 'Index (MB)'
            FROM information_schema.tables
            WHERE table_schema = '${DB_NAME}' AND table_name = '${table}';
        " 2>/dev/null || echo "Unable to check table size"
    elif command -v psql &> /dev/null; then
        psql -h "${DB_HOST}" -U "${DB_USER}" -d "${DB_NAME}" -c "
            SELECT
                '${table}' AS \"Table\",
                pg_size_pretty(pg_total_relation_size('${table}')) AS \"Size\",
                (SELECT reltuples::bigint FROM pg_class WHERE relname = '${table}') AS \"Rows\";
        " 2>/dev/null || echo "Unable to check table size"
    else
        echo "No database client found"
    fi
}

##############################################################################
# Function: Analyze migration file for risks
##############################################################################
analyze_migration_risks() {
    local migration_file=$1
    local filename=$(basename "${migration_file}")
    local risks=()
    local risk_level="LOW"
    local operations=()

    # Check for risky operations
    if grep -q "\->nullable(false)" "${migration_file}"; then
        risks+=("Adding non-nullable column (may lock table)")
        risk_level="HIGH"
    fi

    if grep -q "\->change()" "${migration_file}"; then
        risks+=("Changing column type (may rewrite table)")
        risk_level="HIGH"
    fi

    if grep -q "\->renameColumn(" "${migration_file}"; then
        risks+=("Renaming column (requires downtime)")
        risk_level="HIGH"
    fi

    if grep -q "\->rename(" "${migration_file}"; then
        risks+=("Renaming table (requires downtime)")
        risk_level="HIGH"
    fi

    if grep -q "\->foreign(" "${migration_file}"; then
        risks+=("Adding foreign key (may lock table)")
        risk_level="MEDIUM"
    fi

    if grep -q "dropIndex\|dropColumn\|dropForeign" "${migration_file}"; then
        operations+=("Dropping index/column/constraint")
    fi

    if grep -q "\->index(" "${migration_file}"; then
        operations+=("Adding index")
        # Check if it's on a potentially large table
        local tables=$(grep -oP "table\('\K[^']+" "${migration_file}" || true)
        for table in ${tables}; do
            local size=$(check_table_size "${table}")
            if echo "${size}" | grep -qE "[0-9]{3,}(\.[0-9]+)?\s*MB"; then
                risks+=("Adding index on large table ${table} (>100MB)")
                risk_level="MEDIUM"
            fi
        done
    fi

    # Output risk assessment
    echo -e "  File: ${filename}"
    echo -e "  Risk Level: \033[${risk_level == "HIGH" ? "0;31" : risk_level == "MEDIUM" ? "1;33" : "0;32"}m${risk_level}\033[0m"

    if [ ${#risks[@]} -gt 0 ]; then
        echo -e "  ${YELLOW}Risks:${NC}"
        for risk in "${risks[@]}"; do
            echo -e "    - ${risk}"
        done
    fi

    if [ ${#operations[@]} -gt 0 ]; then
        echo -e "  Operations:"
        for op in "${operations[@]}"; do
            echo -e "    - ${op}"
        done
    fi

    # Add to report
    {
        echo "Migration: ${filename}"
        echo "Risk Level: ${risk_level}"
        [ ${#risks[@]} -gt 0 ] && echo "Risks:" && printf "  - %s\n" "${risks[@]}"
        [ ${#operations[@]} -gt 0 ] && echo "Operations:" && printf "  - %s\n" "${operations[@]}"
        echo ""
    } >> "${REPORT_FILE}"
}

##############################################################################
# Function: Check for pending migrations
##############################################################################
check_pending_migrations() {
    echo -e "${BLUE}Checking for pending migrations...${NC}"

    cd "${PROJECT_ROOT}"

    if php artisan migrate:status 2>/dev/null | grep -q "Pending"; then
        echo -e "${YELLOW}Pending migrations found:${NC}"
        php artisan migrate:status | grep "Pending" || true

        {
            echo "Pending Migrations:"
            php artisan migrate:status | grep "Pending" || true
            echo ""
        } >> "${REPORT_FILE}"
    else
        echo -e "${GREEN}No pending migrations${NC}"
        {
            echo "No pending migrations"
            echo ""
        } >> "${REPORT_FILE}"
    fi
    echo ""
}

##############################################################################
# Function: Analyze all migration files
##############################################################################
analyze_migrations() {
    echo -e "${BLUE}Analyzing migration files...${NC}"
    echo ""

    local migration_files=$(find "${MIGRATIONS_DIR}" -name "*.php" -type f | sort)
    local file_count=$(echo "${migration_files}" | wc -l)

    {
        echo "Migration File Analysis"
        "Total files: ${file_count}"
        echo ""
    } >> "${REPORT_FILE}"

    for migration_file in ${migration_files}; do
        analyze_migration_risks "${migration_file}"
        echo ""
    done
}

##############################################################################
# Function: Check database health
##############################################################################
check_database_health() {
    echo -e "${BLUE}Checking database health...${NC}"
    echo ""

    get_db_connection

    # Check connection
    if command -v mysql &> /dev/null; then
        if mysql -h "${DB_HOST}" -u "${DB_USER}" -p"${DB_PASSWORD}" -e "USE ${DB_NAME};" 2>/dev/null; then
            echo -e "${GREEN}Database connection: OK${NC}"

            # Check for long-running queries
            local long_queries=$(mysql -h "${DB_HOST}" -u "${DB_USER}" -p"${DB_PASSWORD}" "${DB_NAME}" -e "SHOW PROCESSLIST;" 2>/dev/null | awk 'NR>1 && $6 > 10 {print}' || echo "")
            if [ -n "${long_queries}" ]; then
                echo -e "${YELLOW}Warning: Long-running queries detected:${NC}"
                echo "${long_queries}"
            fi

            # Check table locks
            local locks=$(mysql -h "${DB_HOST}" -u "${DB_USER}" -p"${DB_PASSWORD}" "${DB_NAME}" -e "SHOW OPEN TABLES WHERE In_use > 0;" 2>/dev/null || echo "")
            if [ -n "${locks}" ]; then
                echo -e "${YELLOW}Warning: Table locks detected:${NC}"
                echo "${locks}"
            fi

        else
            echo -e "${RED}Database connection: FAILED${NC}"
        fi
    elif command -v psql &> /dev/null; then
        if psql -h "${DB_HOST}" -U "${DB_USER}" -d "${DB_NAME}" -c "SELECT 1;" &>/dev/null; then
            echo -e "${GREEN}Database connection: OK${NC}"

            # Check replication lag
            local lag=$(psql -h "${DB_HOST}" -U "${DB_USER}" -d "${DB_NAME}" -t -c "SELECT EXTRACT(EPOCH FROM (now() - pg_last_xact_replay_timestamp()));" 2>/dev/null || echo "")
            if [ -n "${lag}" ] && [ "${lag}" != "" ]; then
                if (( $(echo "${lag} > 5" | bc -l) )); then
                    echo -e "${YELLOW}Warning: Replication lag: ${lag}s${NC}"
                fi
            fi
        else
            echo -e "${RED}Database connection: FAILED${NC}"
        fi
    else
        echo -e "${YELLOW}No database client available for health check${NC}"
    fi

    echo ""

    {
        echo "Database Health Check"
        echo "Host: ${DB_HOST}"
        echo "Database: ${DB_NAME}"
        echo ""
    } >> "${REPORT_FILE}"
}

##############################################################################
# Function: Generate execution plan
##############################################################################
generate_execution_plan() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}Execution Plan Summary${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""

    local backup_cmd="./scripts/migration-backup.sh ${ENVIRONMENT}"
    local test_cmd="./scripts/migration-test.sh ${ENVIRONMENT}"
    local migrate_cmd="php artisan migrate --force"

    echo "Recommended execution order:"
    echo ""
    echo "1. Pre-migration backup:"
    echo "   ${backup_cmd}"
    echo ""
    echo "2. Test on staging:"
    echo "   ${test_cmd}"
    echo ""
    echo "3. Run migration:"
    echo "   ${migrate_cmd}"
    echo ""
    echo "4. Verify migration:"
    echo "   php artisan migrate:status"
    echo ""
    echo "5. Run tests:"
    echo "   php artisan test"
    echo ""
    echo "6. Monitor for issues:"
    echo "   tail -f storage/logs/laravel.log"
    echo ""
    echo "If rollback needed:"
    echo "   ./scripts/migration-rollback.sh ${ENVIRONMENT}"

    {
        echo "Execution Plan"
        echo "==============="
        echo ""
        echo "1. Pre-migration backup:"
        echo "   ${backup_cmd}"
        echo ""
        echo "2. Test on staging:"
        echo "   ${test_cmd}"
        echo ""
        echo "3. Run migration:"
        echo "   ${migrate_cmd}"
        echo ""
        echo "4. Verify migration:"
        echo "   php artisan migrate:status"
        echo ""
        echo "5. Run tests:"
        echo "   php artisan test"
        echo ""
        echo "6. If rollback needed:"
        echo "   ./scripts/migration-rollback.sh ${ENVIRONMENT}"
        echo ""
    } >> "${REPORT_FILE}"
}

##############################################################################
# Function: Display report location
##############################################################################
display_report() {
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}Report saved to:${NC}"
    echo -e "${BLUE}${REPORT_FILE}${NC}"
    echo -e "${GREEN}========================================${NC}"
}

##############################################################################
# Main execution
##############################################################################
main() {
    check_pending_migrations
    check_database_health
    analyze_migrations
    generate_execution_plan
    display_report
}

main "$@"
