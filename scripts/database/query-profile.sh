#!/bin/bash
#
# PostgreSQL Query Profiling Script
#
# Profile specific queries to identify performance bottlenecks
# Usage: ./scripts/database/query-profile.sh "SELECT * FROM users WHERE id = ?"
#
# For EXPLAIN ANALYZE output with better formatting

set -e

# Configuration
DB_HOST="${DB_HOST:-127.0.0.1}"
DB_PORT="${DB_PORT:-5432}"
DB_NAME="${DB_DATABASE:-agl_hostman}"
DB_USER="${DB_USERNAME:-agl_user}"
DB_PASSWORD="${DB_PASSWORD:-secret}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Check arguments
if [ $# -lt 1 ]; then
    echo "Usage: $0 \"SQL_QUERY\" [explain|analyze|buffers]"
    echo ""
    echo "Examples:"
    echo "  $0 \"SELECT * FROM users WHERE id = ?\""
    echo "  $0 \"SELECT * FROM containers WHERE status = 'running'\" explain"
    echo "  $0 \"SELECT * FROM deployments ORDER BY created_at DESC LIMIT 10\" analyze"
    exit 1
fi

QUERY="$1"
MODE="${2:-analyze}"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}PostgreSQL Query Profiler${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo -e "${GREEN}Mode: ${MODE}${NC}"
echo -e "${GREEN}Query:${NC}"
echo "$QUERY"
echo ""
echo -e "${BLUE}----------------------------------------${NC}"

case "$MODE" in
    explain)
        # EXPLAIN only (no execution)
        echo -e "${YELLOW}EXPLAIN Output:${NC}"
        echo ""
        PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -c "EXPLAIN (FORMAT JSON, VERBOSE) $QUERY" | jq '.' 2>/dev/null || PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -c "EXPLAIN (VERBOSE) $QUERY"
        ;;

    analyze)
        # EXPLAIN ANALYZE (execute and measure)
        echo -e "${YELLOW}EXPLAIN ANALYZE Output:${NC}"
        echo ""
        PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -c "EXPLAIN (ANALYZE, FORMAT JSON, BUFFERS, VERBOSE) $QUERY" | jq '.' 2>/dev/null || PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -c "EXPLAIN (ANALYZE, BUFFERS, VERBOSE) $QUERY"
        ;;

    buffers)
        # Include buffer information
        echo -e "${YELLOW}EXPLAIN (ANALYZE, BUFFERS) Output:${NC}"
        echo ""
        PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -c "EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON, VERBOSE) $QUERY" | jq '.[] | {
            plan: .Plan["Node Type"],
            total_cost: .Plan["Total Cost"],
            rows: .Plan.Plan Rows,
            width: .Plan.Plan Width,
            actual_loops: .Plan.Actual Loops,
            actual_rows: .Plan.Actual Rows,
            buffers: {
                shared_hit: .Plan["Shared Hit Blocks"],
                shared_read: .Plan["Shared Read Blocks"],
                local_hit: .Plan["Local Hit Blocks"],
                local_read: .Plan["Local Read Blocks"],
                temp_read: .Plan["Temp Read Blocks"]
            }
        }' 2>/dev/null || PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -c "EXPLAIN (ANALYZE, BUFFERS, VERBOSE) $QUERY"
        ;;

    *)
        echo -e "${YELLOW}Available modes:${NC}"
        echo "  explain  - Show query plan without execution"
        echo "  analyze  - Execute query and show actual metrics"
        echo "  buffers  - Include buffer hit/miss statistics"
        exit 1
        ;;
esac

echo ""
echo -e "${BLUE}----------------------------------------${NC}"
echo ""
echo -e "${GREEN}Query Performance Tips:${NC}"
echo "  - Look for 'Seq Scan' (slow, full table scan)"
echo "  - Look for high 'cost' values"
echo "  - Check if indexes are being used (Index Scan vs Seq Scan)"
echo "  - Low buffer hit ratio indicates need for more cache"
echo ""
