#!/bin/bash
#
# AGL-23 Database Optimization Script
#
# Automated PostgreSQL maintenance and optimization for < 50ms p95 target
#
# Usage:
#   ./scripts/database/optimize.sh [analyze|vacuum|reindex|statistics|all]
#
# Example:
#   ./scripts/database/optimize.sh analyze
#   ./scripts/database/optimize.sh all

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration from environment
DB_HOST="${DB_HOST:-127.0.0.1}"
DB_PORT="${DB_PORT:-5432}"
DB_NAME="${DB_DATABASE:-agl_hostman}"
DB_USER="${DB_USERNAME:-agl_user}"
DB_PASSWORD="${DB_PASSWORD:-secret}"

# Log file
LOG_FILE="./logs/database-optimization-$(date +%Y%m%d).log"
mkdir -p "$(dirname "$LOG_FILE")"

# Logging function
log() {
    local level=$1
    shift
    local message="$@"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" | tee -a "$LOG_FILE"
}

log_info() {
    log "INFO" "${GREEN}$@${NC}"
}

log_warn() {
    log "WARN" "${YELLOW}$@${NC}"
}

log_error() {
    log "ERROR" "${RED}$@${NC}"
}

# Check if PostgreSQL is accessible
check_db_connection() {
    log_info "Checking database connection..."
    if PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -c '\conn' >/dev/null 2>&1; then
        log_info "Database connection OK"
        return 0
    else
        log_error "Cannot connect to database"
        return 1
    fi
}

# Analyze tables for query optimization
analyze_tables() {
    log_info "Starting ANALYZE on all tables..."
    log_warn "This may take several minutes on large tables..."

    local start_time=$(date +%s)

    PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" <<'EOSQL' | tee -a "$LOG_FILE"
-- Analyze all tables to update statistics
ANALYZE VERBOSE;

-- Report table statistics
SELECT
    schemaname,
    tablename,
    n_live_tup as live_rows,
    n_dead_tup as dead_rows,
    last_autovacuum,
    last_autoanalyze,
    pg_size_pretty(table_size) as table_size
FROM pg_stat_user_tables
WHERE schemaname = 'public'
ORDER BY table_size DESC
LIMIT 20;
EOSQL

    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    log_info "ANALYZE completed in ${duration} seconds"
}

# Vacuum and analyze tables
vacuum_tables() {
    log_info "Starting VACUUM ANALYZE..."
    log_warn "This may take significant time on large tables..."

    local start_time=$(date +%s)

    PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" <<'EOSQL' | tee -a "$LOG_FILE"
-- Vacuum with analyze to reclaim space and update statistics
VACUUM (ANALYZE, VERBOSE, INDEX_CLEANUP);

-- Report vacuum results
SELECT
    schemaname,
    tablename,
    pg_size_pretty(pg_total_relation_size) as total_size,
    pg_size_pretty(pg_relation_size) as table_size,
    pg_size_pretty(pg_total_relation_size - pg_relation_size) as indexes_size,
    n_live_tup as live_rows,
    n_dead_tup as dead_rows
FROM pg_stat_user_tables
WHERE schemaname = 'public'
ORDER BY pg_total_relation_size DESC
LIMIT 20;
EOSQL

    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    log_info "VACUUM ANALYZE completed in ${duration} seconds"
}

# Reindex bloated indexes
reindex_tables() {
    log_info "Checking for bloated indexes..."

    local start_time=$(date +%s)

    PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" <<'EOSQL' | tee -a "$LOG_FILE"
-- Find bloated indexes (> 50% wasted space)
WITH bloat_info AS (
    SELECT
        schemaname,
        tablename,
        indexname,
        pg_size_pretty(pg_relation_size(idx.oid)) as index_size,
        CASE
            WHEN pg_relation_size(idx.oid) > 0
            THEN 100 * (idx.indrelpages::float - idx.indpages::float) / idx.indrelpages::float
            ELSE 0
        END as bloat_ratio,
        pg_size_pretty((idx.indrelpages::float - idx.indpages::float) * 8192) as wasted_space
    FROM pg_stat_user_indexes idx
    JOIN pg_class t ON t.oid = idx.indrelid
    JOIN pg_namespace n ON n.oid = t.relnamespace
    WHERE idx.indrelpages > 0
)
SELECT
    schemaname,
    tablename,
    indexname,
    index_size,
    bloat_ratio::int as bloat_percent,
    wasted_space
FROM bloat_info
WHERE bloat_ratio > 50
ORDER BY bloat_ratio DESC
LIMIT 20;
EOSQL

    log_warn "Consider running REINDEX CONCURRENTLY on bloated indexes"

    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    log_info "Index bloat check completed in ${duration} seconds"
}

# Update table statistics
update_statistics() {
    log_info "Updating table statistics..."

    local start_time=$(date +%s)

    PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" <<'EOSQL' | tee -a "$LOG_FILE"
-- Reset statistics and rebuild
ALTER DATABASE ${DB_NAME} SET default_statistics_target = 100;

-- Update statistics for all tables
SELECT
    'ANALYZE ' || quote_ident(schemaname) || '.' || quote_ident(tablename) || ';' as analyze_command
FROM pg_tables
WHERE schemaname = 'public'
ORDER BY pg_total_relation_size DESC;
EOSQL

    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    log_info "Statistics update completed in ${duration} seconds"
}

# Clean up old data from slow query log
cleanup_slow_query_log() {
    log_info "Cleaning up old slow query logs..."

    PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" <<'EOSQL'
-- Delete samples older than 30 days
DELETE FROM query_execution_samples
WHERE executed_at < NOW() - INTERVAL '30 days';

-- Update slow queries aggregation
REFRESH MATERIALIZED VIEW mv_slow_queries_top;

-- Get log size
SELECT
    pg_size_pretty(pg_total_relation_size('query_execution_samples')) as samples_size,
    pg_size_pretty(pg_total_relation_size('slow_queries_log')) as log_size,
    (SELECT COUNT(*) FROM query_execution_samples) as sample_count,
    (SELECT COUNT(*) FROM slow_queries_log) as query_count;
EOSQL

    log_info "Slow query log cleanup completed"
}

# Generate performance report
generate_report() {
    log_info "Generating performance report..."

    PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" <<'EOSQL' | tee -a "$LOG_FILE"
-- ================================================================================
-- AGL-23 Database Performance Report
-- Generated: $(date)
-- ================================================================================

-- Overall Database Size
SELECT
    'Database Size' as metric,
    pg_size_pretty(pg_database_size('$(current_database())') as value
UNION ALL
SELECT
    'Total Tables' as metric,
    COUNT(*)::text as value
FROM pg_tables
WHERE schemaname = 'public'
UNION ALL
SELECT
    'Total Indexes' as metric,
    COUNT(*)::text as value
FROM pg_indexes
WHERE schemaname = 'public';

-- Top Tables by Size
SELECT
    'Top Tables by Size' as section,
    tablename as metric,
    pg_size_pretty(pg_total_relation_size(oid)) as value
FROM pg_class
JOIN pg_namespace ON pg_namespace.oid = relnamespace
WHERE pg_namespace.nspname = 'public'
    AND relkind = 'r'
ORDER BY pg_total_relation_size(oid) DESC
LIMIT 10;

-- Query Performance Summary
SELECT
    'Slow Queries (p95 > 50ms)' as metric,
    COUNT(*)::text as value
FROM slow_queries_log
WHERE mean_exec_time_ms > 50;

-- N+1 Query Patterns
SELECT
    query_pattern,
    calls as execution_count,
    ROUND(mean_exec_time_ms, 2) as avg_time_ms,
    ROUND(max_exec_time_ms, 2) as max_time_ms
FROM mv_slow_queries_top
ORDER BY calls DESC
LIMIT 10;

-- Index Usage Statistics
SELECT
    'Index Hit Ratio' as metric,
    ROUND(SUM(blks_hit)::numeric / NULLIF(SUM(blks_hit + blks_read), 0) * 100, 2) || '%' as value
FROM pg_stat_database
WHERE datname = '$(current_database())';

-- Table Bloat Summary
WITH bloat_summary AS (
    SELECT
        pg_size_pretty SUM(pg_relation_size(oid)) as total_size,
        pg_size_pretty SUM((pg_relpages(oid) - pg_relation_size(oid)) * 8192) as wasted_size
    FROM pg_class
    JOIN pg_namespace ON pg_namespace.oid = relnamespace
    WHERE pg_namespace.nspname = 'public'
        AND relkind = 'r'
)
SELECT
    'Total Table Size' as metric,
    total_size as value
FROM bloat_summary
UNION ALL
SELECT
    'Total Wasted Space' as metric,
    wasted_size as value
FROM bloat_summary;

-- Missing Indexes Summary
SELECT
    'Missing Indexes' as metric,
    COUNT(*) FILTER (WHERE is_created = false)::text as value
FROM missing_indexes_log;
EOSQL
}

# Run all optimization tasks
run_all() {
    log_info "Running full optimization sequence..."
    log_warn "This will perform: analyze, vacuum, reindex, statistics"

    check_db_connection || exit 1

    # Run in optimal order
    vacuum_tables
    update_statistics
    analyze_tables
    reindex_tables
    cleanup_slow_query_log
    generate_report

    log_info "Full optimization sequence completed!"
}

# Main script logic
main() {
    local command="${1:-all}"

    log_info "AGL-23 Database Optimization Script"
    log_info "Database: ${DB_NAME} @ ${DB_HOST}:${DB_PORT}"
    log_info "Command: ${command}"
    echo ""

    case "$command" in
        analyze)
            check_db_connection || exit 1
            analyze_tables
            ;;
        vacuum)
            check_db_connection || exit 1
            vacuum_tables
            ;;
        reindex)
            check_db_connection || exit 1
            reindex_tables
            ;;
        statistics)
            check_db_connection || exit 1
            update_statistics
            ;;
        cleanup)
            check_db_connection || exit 1
            cleanup_slow_query_log
            ;;
        report)
            check_db_connection || exit 1
            generate_report
            ;;
        all)
            run_all
            ;;
        *)
            echo "Usage: $0 [analyze|vacuum|reindex|statistics|cleanup|report|all]"
            echo ""
            echo "Commands:"
            echo "  analyze    - Run ANALYZE to update table statistics"
            echo "  vacuum     - Run VACUUM ANALYZE to reclaim space and update stats"
            echo "  reindex    - Check for bloated indexes"
            echo "  statistics  - Update table statistics for better query plans"
            echo "  cleanup     - Clean up old slow query logs"
            echo "  report      - Generate performance report"
            echo "  all         - Run all optimization tasks"
            exit 1
            ;;
    esac

    log_info "Done! Check log at: $LOG_FILE"
}

main "$@"
