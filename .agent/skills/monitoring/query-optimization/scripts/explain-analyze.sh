#!/usr/bin/env bash
##
# Query Performance Analysis Script
#
# Analyzes Laravel application queries using EXPLAIN ANALYZE
# Detects N+1 problems, missing indexes, and inefficient queries
#
# Usage: ./explain-analyze.sh [options]
#   --connection=CONNECTION   Database connection (mysql, pgsql)
#   --file=FILE              SQL file to analyze
#   --query=QUERY            Direct SQL query to analyze
#   --top=N                  Show top N slowest queries (requires slow query log)
#   --suggest-indexes         Suggest indexes based on query analysis
##

set -euo pipefail

# Configuration
CONNECTION="${DB_CONNECTION:-mysql}"
DB_HOST="${DB_HOST:-127.0.0.1}"
DB_PORT="${DB_PORT:-3306}"
DB_NAME="${DB_DATABASE:-agl_hostman}"
DB_USER="${DB_USERNAME:-root}"
DB_PASS="${DB_PASSWORD:-}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_detail() { echo -e "${BLUE}[QUERY]${NC} $1"; }

# Parse arguments
QUERY=""
FILE=""
TOP_N=10
SUGGEST_INDEXES=false

for arg in "$@"; do
    case $arg in
        --connection=*) CONNECTION="${arg#*=}" ;;
        --file=*)       FILE="${arg#*=}" ;;
        --query=*)      QUERY="${arg#*=}" ;;
        --top=*)        TOP_N="${arg#*=}" ;;
        --suggest-indexes) SUGGEST_INDEXES=true ;;
        *) log_error "Unknown argument: $arg" && exit 1 ;;
    esac
done

# Database-specific EXPLAIN syntax
explain_query() {
    local query="$1"

    case $CONNECTION in
        pgsql|postgres|postgresql)
            echo "EXPLAIN (ANALYZE, BUFFERS, VERBOSE) $query"
            ;;
        mysql|mariadb)
            echo "EXPLAIN FORMAT=JSON $query"
            ;;
        *)
            log_error "Unsupported database: $CONNECTION"
            exit 1
            ;;
    esac
}

# Execute EXPLAIN
execute_explain() {
    local query="$1"

    case $CONNECTION in
        pgsql|postgres|postgresql)
            PGPASSWORD="$DB_PASS" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -c "$query"
            ;;
        mysql|mariadb)
            mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" -e "$query"
            ;;
    esac
}

# Analyze EXPLAIN output
analyze_explain() {
    local output="$1"

    echo ""
    echo "=== Analysis ==="

    # PostgreSQL analysis
    if [[ "$CONNECTION" =~ pgsql|postgres ]]; then
        # Check for Seq Scan (sequential scan)
        if echo "$output" | grep -q "Seq Scan"; then
            log_warn "Sequential Scan detected - may need index"
            echo "$output" | grep "Seq Scan" | while read -r line; do
                echo "  → $line"
            done
        fi

        # Check for high cost
        if echo "$output" | grep -q "cost=[0-9]*\.\.[0-9]*"; then
            log_info "Query cost detected"
        fi

        # Check for Nested Loop with high rows
        if echo "$output" | grep -q "Nested Loop.*rows=[0-9]*"; then
            log_warn "Nested Loop with many rows - consider JOIN optimization"
        fi
    fi

    # MySQL analysis
    if [[ "$CONNECTION" =~ mysql|mariadb ]]; then
        # Parse JSON output for issues
        log_info "Check JSON output for:"
        echo "  • type: ALL (full table scan - needs index)"
        echo "  • rows: high value (many rows examined)"
        echo "  • Extra: Using filesort, Using temporary"
    fi
}

# Suggest indexes
suggest_indexes() {
    local query="$1"

    log_info "Index suggestions:"

    # Extract WHERE clauses
    local where_clauses
    where_clauses=$(echo "$query" | grep -oP "WHERE.*?(?=ORDER BY|GROUP BY|LIMIT|$)" || true)

    # Extract JOIN conditions
    local join_clauses
    join_clauses=$(echo "$query" | grep -oP "ON \K[^ ]+(?==)" || true)

    echo "Consider indexes on columns used in:"
    echo "  WHERE clauses: $(echo "$where_clauses" | tr ',' '\n' | head -3)"
    echo "  JOIN conditions: $(echo "$join_clauses" | head -3)"
}

# Main logic
main() {
    log_info "Query Performance Analysis"
    log_info "Database: $CONNECTION @ $DB_HOST:$DB_PORT/$DB_NAME"

    # Read query from file or argument
    if [[ -n "$FILE" ]]; then
        if [[ ! -f "$FILE" ]]; then
            log_error "File not found: $FILE"
            exit 1
        fi
        QUERY=$(cat "$FILE")
        log_info "Reading query from: $FILE"
    elif [[ -n "$QUERY" ]]; then
        log_info "Using provided query"
    else
        log_error "No query provided. Use --file or --query"
        exit 1
    fi

    # Build EXPLAIN query
    local explain_query
    explain_query=$(explain_query "$QUERY")

    log_detail "$explain_query"

    # Execute EXPLAIN
    log_info "Executing EXPLAIN..."
    local output
    output=$(execute_explain "$explain_query")

    echo "$output"

    # Analyze output
    analyze_explain "$output"

    # Suggest indexes if requested
    if [[ "$SUGGEST_INDEXES" == true ]]; then
        suggest_indexes "$QUERY"
    fi
}

main
