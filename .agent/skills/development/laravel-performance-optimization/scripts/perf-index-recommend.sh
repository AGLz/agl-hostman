#!/bin/bash

###############################################################################
# Laravel Index Recommendation Script
#
# Analyzes database queries and recommends indexes for optimization.
# Uses EXPLAIN ANALYZE to identify slow queries and missing indexes.
#
# Usage:
#   ./perf-index-recommend.sh [table] [analyze]
#
# Examples:
#   ./perf-index-recommend.sh                    # Analyze all tables
#   ./perf-index-recommend.sh lxc_containers    # Analyze specific table
#   ./perf-index-recommend.sh lxc_containers analyze  # Run EXPLAIN ANALYZE
###############################################################################

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
TARGET_TABLE="${1:-}"
RUN_ANALYZE="${2:-}"
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
OUTPUT_DIR="${PROJECT_ROOT}/storage/app/index-recommendations"

# Create output directory
mkdir -p "${OUTPUT_DIR}"

echo -e "${BLUE}=== Laravel Index Recommendation Tool ===${NC}"
echo "Project: ${PROJECT_ROOT}"
if [ -n "${TARGET_TABLE}" ]; then
    echo "Table: ${TARGET_TABLE}"
else
    echo "Table: all"
fi
echo ""

###############################################################################
# Get database configuration
###############################################################################

get_db_config() {
    source "${PROJECT_ROOT}/.env"

    DB_HOST="${DB_HOST:-127.0.0.1}"
    DB_PORT="${DB_PORT:-3306}"
    DB_DATABASE="${DB_DATABASE:-laravel}"
    DB_USERNAME="${DB_USERNAME:-root}"
    DB_PASSWORD="${DB_PASSWORD:-}"

    export MYSQL_PWD="${DB_PASSWORD}"
}

###############################################################################
# Analyze specific table
###############################################################################

analyze_table() {
    local table=$1

    echo -e "${BLUE}Analyzing table: ${table}${NC}"

    local output_file="${OUTPUT_DIR}/${table}_${TIMESTAMP}.txt"

    {
        echo "Table Analysis: ${table}"
        echo "=================================="
        echo "Generated: ${TIMESTAMP}"
        echo ""

        # Get table structure
        echo "-- Current Structure --"
        mysql -h "${DB_HOST}" -P "${DB_PORT}" -u "${DB_USERNAME}" "${DB_DATABASE}" \
            -e "DESCRIBE ${table};" 2>/dev/null || echo "Could not describe table"

        echo ""
        echo "-- Current Indexes --"
        mysql -h "${DB_HOST}" -P "${DB_PORT}" -u "${DB_USERNAME}" "${DB_DATABASE}" \
            -e "SHOW INDEX FROM ${table};" 2>/dev/null || echo "Could not show indexes"

        echo ""
        echo "-- Table Row Count --"
        local row_count=$(mysql -h "${DB_HOST}" -P "${DB_PORT}" -u "${DB_USERNAME}" "${DB_DATABASE}" \
            -N -e "SELECT COUNT(*) FROM ${table};" 2>/dev/null || echo "0")
        echo "Rows: ${row_count}"

        echo ""
        echo "-- Index Recommendations --"

        # Get columns that are frequently used in WHERE clauses
        # This is based on common patterns

        case "${table}" in
            *users*)
                echo "Recommended indexes for users table:"
                echo "  ALTER TABLE ${table} ADD INDEX idx_email_active (email, deleted_at);"
                echo "  ALTER TABLE ${table} ADD INDEX idx_created_at (created_at);"
                echo "  ALTER TABLE ${table} ADD INDEX idx_last_login (last_login_at);"
                ;;
            *containers*|*lxc*)
                echo "Recommended indexes for containers table:"
                echo "  ALTER TABLE ${table} ADD INDEX idx_status (status);"
                echo "  ALTER TABLE ${table} ADD INDEX idx_server_status (proxmox_server_id, status);"
                echo "  ALTER TABLE ${table} ADD INDEX idx_created_at (created_at);"
                echo "  ALTER TABLE ${table} ADD INDEX idx_vmid (vmid);"
                ;;
            *deployments*)
                echo "Recommended indexes for deployments table:"
                echo "  ALTER TABLE ${table} ADD INDEX idx_app_status (application_id, status);"
                echo "  ALTER TABLE ${table} ADD INDEX idx_branch (branch);"
                echo "  ALTER TABLE ${table} ADD INDEX idx_created_at (created_at);"
                echo "  ALTER TABLE ${table} ADD INDEX idx_status_created (status, created_at);"
                ;;
            *applications*)
                echo "Recommended indexes for applications table:"
                echo "  ALTER TABLE ${table} ADD INDEX idx_user_project (user_id, project_id);"
                echo "  ALTER TABLE ${table} ADD INDEX idx_type (type);"
                echo "  ALTER TABLE ${table} ADD INDEX idx_created_at (created_at);"
                ;;
            *alerts*)
                echo "Recommended indexes for alerts table:"
                echo "  ALTER TABLE ${table} ADD INDEX idx_severity_resolved (severity, is_resolved);"
                echo "  ALTER TABLE ${table} ADD INDEX idx_resource (resource_type, resource_id);"
                echo "  ALTER TABLE ${table} ADD INDEX idx_created_at (created_at);"
                echo "  ALTER TABLE ${table} ADD INDEX idx_resolved_created (is_resolved, created_at);"
                ;;
            *metrics*|*trends*|*performance*)
                echo "Recommended indexes for metrics/trends table:"
                echo "  ALTER TABLE ${table} ADD INDEX idx_resource_metric (resource_type, resource_id, metric_type);"
                echo "  ALTER TABLE ${table} ADD INDEX idx_recorded_at (recorded_at);"
                echo "  ALTER TABLE ${table} ADD INDEX idx_metric_time (metric_type, recorded_at);"
                ;;
            *)
                echo "Generic recommendations:"
                echo "  - Add indexes on frequently filtered columns"
                echo "  - Add indexes on foreign key columns"
                echo "  - Add composite indexes for common multi-column queries"
                ;;
        esac

        echo ""
        echo "-- EXPLAIN Analysis --"

        # Run EXPLAIN on common queries
        if [ "${RUN_ANALYZE}" = "analyze" ]; then
            echo "Running EXPLAIN ANALYZE..."

            # Simple SELECT query
            echo "Query: SELECT * FROM ${table} LIMIT 10;"
            mysql -h "${DB_HOST}" -P "${DB_PORT}" -u "${DB_USERNAME}" "${DB_DATABASE}" \
                -e "EXPLAIN SELECT * FROM ${table} LIMIT 10;" 2>/dev/null || true

            echo ""
            echo "Look for:"
            echo "  - type: 'ALL' (indicates full table scan - needs index)"
            echo "  - type: 'index' (indicates index scan - better)"
            echo "  - type: 'range' (indicates range scan - good)"
            echo "  - type: 'ref' or 'eq_ref' (indicates index lookup - optimal)"
            echo "  - key: NULL (indicates no index used)"
            echo "  - Extra: 'Using filesort' (indicates filesort - consider index)"
            echo "  - Extra: 'Using temporary' (indicates temp table - consider index)"
        fi

    } | tee "${output_file}"

    echo -e "${GREEN}Analysis saved to: ${output_file}${NC}"
    echo ""
}

###############################################################################
# Analyze slow query log
###############################################################################

analyze_slow_queries() {
    echo -e "${BLUE}Analyzing slow query log...${NC}"

    local slow_log_file="${PROJECT_ROOT}/storage/logs/slow-query.log"

    if [ -f "${slow_log_file}" ]; then
        echo "Found slow query log: ${slow_log_file}"

        # Extract unique tables from slow queries
        local tables=$(grep -oP "FROM \K\w+" "${slow_log_file}" 2>/dev/null | sort -u || true)

        if [ -n "${tables}" ]; then
            echo "Tables found in slow queries:"
            echo "${tables}"
            echo ""
            echo "Analyzing these tables..."
            for table in ${tables}; do
                if mysql -h "${DB_HOST}" -P "${DB_PORT}" -u "${DB_USERNAME}" "${DB_DATABASE}" \
                    -e "DESCRIBE ${table};" &>/dev/null; then
                    analyze_table "${table}"
                fi
            done
        else
            echo "No tables found in slow query log"
        fi
    else
        echo "No slow query log found at: ${slow_log_file}"
        echo "To enable slow query logging, set in your database config:"
        echo "  slow_query_log = 1"
        echo "  long_query_time = 1"
        echo "  slow_query_log_file = /path/to/slow-query.log"
    fi

    echo ""
}

###############################################################################
# Generate migration file
###############################################################################

generate_migration() {
    echo -e "${BLUE}Generating index migration...${NC}"

    local migration_file="${OUTPUT_DIR}/add_indexes_${TIMESTAMP}.php"

    cat > "${migration_file}" <<'EOF'
<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        // Users table indexes
        if (Schema::hasTable('users')) {
            Schema::table('users', function (Blueprint $table) {
                $table->index(['email', 'deleted_at'], 'idx_email_active');
                $table->index('created_at', 'idx_created_at');
                $table->index('last_login_at', 'idx_last_login');
            });
        }

        // LXC containers indexes
        if (Schema::hasTable('lxc_containers')) {
            Schema::table('lxc_containers', function (Blueprint $table) {
                $table->index('status', 'idx_status');
                $table->index(['proxmox_server_id', 'status'], 'idx_server_status');
                $table->index('created_at', 'idx_created_at');
                $table->index('vmid', 'idx_vmid');
            });
        }

        // Deployments indexes
        if (Schema::hasTable('dokploy_deployments')) {
            Schema::table('dokploy_deployments', function (Blueprint $table) {
                $table->index(['application_id', 'status'], 'idx_app_status');
                $table->index('branch', 'idx_branch');
                $table->index('created_at', 'idx_created_at');
                $table->index(['status', 'created_at'], 'idx_status_created');
            });
        }

        // Applications indexes
        if (Schema::hasTable('dokploy_applications')) {
            Schema::table('dokploy_applications', function (Blueprint $table) {
                $table->index(['user_id', 'project_id'], 'idx_user_project');
                $table->index('type', 'idx_type');
                $table->index('created_at', 'idx_created_at');
            });
        }

        // Alerts indexes
        if (Schema::hasTable('alerts')) {
            Schema::table('alerts', function (Blueprint $table) {
                $table->index(['severity', 'is_resolved'], 'idx_severity_resolved');
                $table->index(['resource_type', 'resource_id'], 'idx_resource');
                $table->index('created_at', 'idx_created_at');
                $table->index(['is_resolved', 'created_at'], 'idx_resolved_created');
            });
        }

        // Performance trends indexes
        if (Schema::hasTable('performance_trends')) {
            Schema::table('performance_trends', function (Blueprint $table) {
                $table->index(['resource_type', 'resource_id', 'metric_type'], 'idx_resource_metric');
                $table->index('recorded_at', 'idx_recorded_at');
                $table->index(['metric_type', 'recorded_at'], 'idx_metric_time');
            });
        }
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        // Users table indexes
        if (Schema::hasTable('users')) {
            Schema::table('users', function (Blueprint $table) {
                $table->dropIndex('idx_email_active');
                $table->dropIndex('idx_created_at');
                $table->dropIndex('idx_last_login');
            });
        }

        // LXC containers indexes
        if (Schema::hasTable('lxc_containers')) {
            Schema::table('lxc_containers', function (Blueprint $table) {
                $table->dropIndex('idx_status');
                $table->dropIndex('idx_server_status');
                $table->dropIndex('idx_created_at');
                $table->dropIndex('idx_vmid');
            });
        }

        // Deployments indexes
        if (Schema::hasTable('dokploy_deployments')) {
            Schema::table('dokploy_deployments', function (Blueprint $table) {
                $table->dropIndex('idx_app_status');
                $table->dropIndex('idx_branch');
                $table->dropIndex('idx_created_at');
                $table->dropIndex('idx_status_created');
            });
        }

        // Applications indexes
        if (Schema::hasTable('dokploy_applications')) {
            Schema::table('dokploy_applications', function (Blueprint $table) {
                $table->dropIndex('idx_user_project');
                $table->dropIndex('idx_type');
                $table->dropIndex('idx_created_at');
            });
        }

        // Alerts indexes
        if (Schema::hasTable('alerts')) {
            Schema::table('alerts', function (Blueprint $table) {
                $table->dropIndex('idx_severity_resolved');
                $table->dropIndex('idx_resource');
                $table->dropIndex('idx_created_at');
                $table->dropIndex('idx_resolved_created');
            });
        }

        // Performance trends indexes
        if (Schema::hasTable('performance_trends')) {
            Schema::table('performance_trends', function (Blueprint $table) {
                $table->dropIndex('idx_resource_metric');
                $table->dropIndex('idx_recorded_at');
                $table->dropIndex('idx_metric_time');
            });
        }
    }
};
EOF

    echo -e "${GREEN}Migration file created: ${migration_file}${NC}"
    echo ""
    echo "To use this migration:"
    echo "  1. Copy the file to your migrations directory:"
    echo "     cp ${migration_file} ${PROJECT_ROOT}/database/migrations/$(date +%Y_%m_%d)_000000_add_indexes.php"
    echo "  2. Review and customize the indexes for your needs"
    echo "  3. Run: php artisan migrate"
    echo ""
}

###############################################################################
# Generate summary report
###############################################################################

generate_summary() {
    echo -e "${BLUE}Generating summary report...${NC}"

    local summary_file="${OUTPUT_DIR}/summary_${TIMESTAMP}.txt"

    {
        echo "Index Recommendation Summary"
        echo "============================"
        echo ""
        echo "Generated: ${TIMESTAMP}"
        echo ""

        echo "Tables Analyzed"
        echo "---------------"
        ls "${OUTPUT_DIR}" | grep -E ".*_${TIMESTAMP}.txt$" | sed 's/_'"${TIMESTAMP}"'.txt$//' || true
        echo ""

        echo "Common Index Patterns"
        echo "--------------------"
        echo "1. Foreign Key Indexes"
        echo "   - Always index foreign key columns"
        echo "   - Example: user_id, server_id, application_id"
        echo ""
        echo "2. Composite Indexes"
        echo "   - For multi-column WHERE/ORDER BY clauses"
        echo "   - Column order matters (most selective first)"
        echo "   - Example: (status, created_at)"
        echo ""
        echo "3. Covering Indexes"
        echo "   - Include all columns used in SELECT, WHERE, ORDER BY"
        echo "   - Eliminates table lookups"
        echo "   - Example: (user_id, status, created_at)"
        echo ""

        echo "Index Guidelines"
        echo "----------------"
        echo "DO:"
        echo "  - Index columns used in WHERE clauses"
        echo "  - Index columns used in JOIN conditions"
        echo "  - Index columns used in ORDER BY"
        echo "  - Use composite indexes for multi-column queries"
        echo "  - Consider covering indexes for frequent queries"
        echo ""
        echo "DON'T:"
        echo "  - Over-index (writes become slower)"
        echo "  - Index low-cardinality columns (e.g., boolean alone)"
        echo "  - Index columns that change frequently"
        echo "  - Create redundant indexes"
        echo ""

        echo "Expected Performance Improvements"
        echo "----------------------------------"
        echo "With proper indexing:"
        echo "  - 10-100x faster queries on indexed columns"
        echo "  - Elimination of full table scans"
        echo "  - Faster JOIN operations"
        echo "  - Improved sorting and grouping"
        echo ""

        echo "Next Steps"
        echo "----------"
        echo "1. Review the generated migration file"
        echo "2. Test indexes on staging environment first"
        echo "3. Monitor query performance after adding indexes"
        echo "4. Remove unused indexes (they slow down writes)"
        echo "5. Re-run this analysis periodically"

    } | tee "${summary_file}"

    echo -e "${GREEN}Summary saved to: ${summary_file}${NC}"
    echo ""
}

###############################################################################
# Main execution
###############################################################################

main() {
    get_db_config

    # Test database connection
    echo -n "Testing database connection... "
    if mysql -h "${DB_HOST}" -P "${DB_PORT}" -u "${DB_USERNAME}" "${DB_DATABASE}" \
        -e "SELECT 1;" &>/dev/null; then
        echo -e "${GREEN}OK${NC}"
    else
        echo -e "${RED}FAILED${NC}"
        echo "Could not connect to database"
        echo "  Host: ${DB_HOST}:${DB_PORT}"
        echo "  Database: ${DB_DATABASE}"
        echo "  User: ${DB_USERNAME}"
        exit 1
    fi
    echo ""

    # Analyze specific table or all tables
    if [ -n "${TARGET_TABLE}" ]; then
        if mysql -h "${DB_HOST}" -P "${DB_PORT}" -u "${DB_USERNAME}" "${DB_DATABASE}" \
            -e "DESCRIBE ${TARGET_TABLE};" &>/dev/null; then
            analyze_table "${TARGET_TABLE}"
        else
            echo -e "${RED}Table not found: ${TARGET_TABLE}${NC}"
            exit 1
        fi
    else
        # Get all tables
        TABLES=$(mysql -h "${DB_HOST}" -P "${DB_PORT}" -u "${DB_USERNAME}" "${DB_DATABASE}" \
            -N -e "SHOW TABLES;" 2>/dev/null || true)

        if [ -z "${TABLES}" ]; then
            echo -e "${RED}No tables found${NC}"
            exit 1
        fi

        echo -e "${BLUE}Found $(echo "${TABLES}" | wc -l) tables${NC}"
        echo ""

        for table in ${TABLES}; do
            analyze_table "${table}"
        done

        # Also check slow query log
        analyze_slow_queries
    fi

    # Generate migration and summary
    generate_migration
    generate_summary

    echo -e "${GREEN}=== Analysis Complete ===${NC}"
    echo ""
    echo "Results saved to: ${OUTPUT_DIR}"
    echo ""
    echo "Files generated:"
    ls -la "${OUTPUT_DIR}" | grep "${TIMESTAMP}"
    echo ""
    echo "Next steps:"
    echo "  1. Review table analysis files"
    echo "  2. Check the generated migration file"
    echo "  3. Test indexes on staging"
    echo "  4. Run: php artisan migrate"
    echo ""
}

main "$@"
