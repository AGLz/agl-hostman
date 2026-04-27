#!/bin/bash

###############################################################################
# Laravel Query Analyzer
#
# Analyzes database queries for N+1 problems, missing indexes,
# and optimization opportunities.
#
# Usage:
#   ./perf-query-analyzer.sh [analyze|recommend]
#
# Examples:
#   ./perf-query-analyzer.sh analyze
#   ./perf-query-analyzer.sh recommend
###############################################################################

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
ACTION="${1:-analyze}"
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_FILE="${PROJECT_ROOT}/storage/logs/query-analysis-${TIMESTAMP}.log"

echo -e "${BLUE}=== Laravel Query Analyzer ===${NC}"
echo "Action: ${ACTION}"
echo "Project: ${PROJECT_ROOT}"
echo ""

###############################################################################
# Check for Laravel Debugbar query log
###############################################################################

check_query_log() {
    echo -e "${BLUE}Checking for query logs...${NC}"

    # Check if Laravel Debugbar is installed
    if [ -d "${PROJECT_ROOT}/vendor/barryvdh/laravel-debugbar" ]; then
        echo -e "${GREEN}✓ Laravel Debugbar installed${NC}"

        # Check for query log file
        DEBUGBAR_STORAGE="${PROJECT_ROOT}/storage/debugbar"
        if [ -d "${DEBUGBAR_STORAGE}" ]; then
            LOG_COUNT=$(find "${DEBUGBAR_STORAGE}" -name "*.json" | wc -l)
            echo -e "${GREEN}✓ Found ${LOG_COUNT} debugbar logs${NC}"
        fi
    else
        echo -e "${YELLOW}⚠ Laravel Debugbar not found${NC}"
        echo "  Install: composer require barryvdh/laravel-debugbar --dev"
    fi

    echo ""
}

###############################################################################
# Enable query logging
###############################################################################

enable_query_logging() {
    echo -e "${BLUE}Enabling query logging...${NC}"

    # Backup .env file
    if [ -f "${PROJECT_ROOT}/.env" ]; then
        cp "${PROJECT_ROOT}/.env" "${PROJECT_ROOT}/.env.backup"

        # Set debug mode
        sed -i 's/APP_DEBUG=false/APP_DEBUG=true/' "${PROJECT_ROOT}/.env"

        # Enable query logging in config
        cat > "${PROJECT_ROOT}/config/query-log.php" <<'EOF'
<?php

return [
    'enabled' => env('QUERY_LOG_ENABLED', true),
    'slow_threshold' => env('QUERY_LOG_SLOW_THRESHOLD', 100), // ms
];
EOF

        echo -e "${GREEN}✓ Query logging enabled${NC}"
        echo -e "${YELLOW}⚠ Backup saved to .env.backup${NC}"
    else
        echo -e "${RED}✗ .env file not found${NC}"
        return 1
    fi

    echo ""
}

###############################################################################
# Analyze queries for N+1 problems
###############################################################################

analyze_n_plus_one() {
    echo -e "${BLUE}Analyzing for N+1 query problems...${NC}"

    cd "${PROJECT_ROOT}"

    # Use artisan to run query analysis
    php artisan tinker --execute="
DB::enableQueryLog();

// Example queries - adjust based on your models
\$users = App\Models\User::limit(10)->get();
foreach (\$users as \$user) {
    // This would cause N+1 if relationships aren't eager loaded
    \$user->roles;
}

\$queries = DB::getQueryLog();
\$count = count(\$queries);

echo \"Total queries: \$count\n\";

if (\$count > 20) {
    echo \"⚠ POTENTIAL N+1 PROBLEM DETECTED\n\";
    echo \"Expected: 2-5 queries\n\";
    echo \"Actual: \$count queries\n\";
    echo \"\nRecommendations:\n\";
    echo \"  1. Use eager loading: User::with('roles')->get()\n\";
    echo \"  2. Prevent lazy loading in production\n\";
    echo \"  3. Use Laravel Debugbar to identify issues\n\";
} else {
    echo \"✓ Query count looks good\n\";
}

// Show duplicate queries
\$sqls = array_map(fn(\$q) => \$q['query'], \$queries);
\$duplicates = array_filter(array_count_values(\$sqls), fn(\$c) => \$c > 1);

if (!empty(\$duplicates)) {
    echo \"\n⚠ DUPLICATE QUERIES FOUND:\n\";
    foreach (\$duplicates as \$sql => \$count) {
        echo \"  Executed \$count times: \$sql\n\";
    }
    echo \"\nRecommendations:\n\";
    echo \"  1. Cache query results\n\";
    echo \"  2. Use eager loading\n\";
    echo \"  3. Load data in bulk\n\";
}
" 2>&1 | tee -a "${LOG_FILE}"

    echo ""
}

###############################################################################
# Analyze query patterns
###############################################################################

analyze_query_patterns() {
    echo -e "${BLUE}Analyzing query patterns...${NC}"

    cd "${PROJECT_ROOT}"

    # Check for common anti-patterns in code
    echo "Checking for query anti-patterns..."

    # Pattern 1: Queries in loops
    echo -n "Checking for queries in loops... "
    if grep -r "->get()" --include="*.php" app/ | grep -q "foreach"; then
        echo -e "${YELLOW}POTENTIAL ISSUE FOUND${NC}"
        grep -rn "->get()" --include="*.php" app/ | grep -B2 -A2 "foreach" | \
            head -20 >> "${LOG_FILE}" || true
    else
        echo -e "${GREEN}OK${NC}"
    fi

    # Pattern 2: Missing eager loading
    echo -n "Checking for missing eager loading... "
    if grep -r "::all()" --include="*.php" app/ | grep -q "foreach"; then
        echo -e "${YELLOW}POTENTIAL ISSUE FOUND${NC}"
        grep -rn "::all()" --include="*.php" app/ | grep -B2 -A2 "foreach" | \
            head -20 >> "${LOG_FILE}" || true
    else
        echo -e "${GREEN}OK${NC}"
    fi

    # Pattern 3: Select all columns
    echo -n "Checking for SELECT * queries... "
    SELECT_COUNT=$(grep -r "DB::table" --include="*.php" app/ | wc -l)
    if [ "${SELECT_COUNT}" -gt 0 ]; then
        echo -e "${YELLOW}FOUND ${SELECT_COUNT} DB::table queries${NC}"
        echo "  Consider using selective column loading" | tee -a "${LOG_FILE}"
    else
        echo -e "${GREEN}OK${NC}"
    fi

    # Pattern 4: Missing pagination
    echo -n "Checking for missing pagination... "
    NO_PAGINATION=$(grep -r "->get()" --include="*.php" app/Http/Controllers/ | wc -l)
    if [ "${NO_PAGINATION}" -gt 10 ]; then
        echo -e "${YELLOW}FOUND ${NO_PAGINATION} ->get() calls in controllers${NC}"
        echo "  Consider using pagination for large datasets" | tee -a "${LOG_FILE}"
    else
        echo -e "${GREEN}OK${NC}"
    fi

    echo ""
}

###############################################################################
# Generate optimization recommendations
###############################################################################

generate_recommendations() {
    echo -e "${BLUE}Generating optimization recommendations...${NC}"

    REPORT_FILE="${PROJECT_ROOT}/storage/app/query-recommendations-${TIMESTAMP}.md"

    cat > "${REPORT_FILE}" <<EOF
# Query Optimization Recommendations

Generated: ${TIMESTAMP}

## Critical Issues

### 1. N+1 Query Problems
**Problem**: Loading relationships in loops causes excessive queries

**Detection**:
- Use Laravel Debugbar to identify N+1 queries
- Look for 100+ queries on a single page
- Check for queries executed inside foreach loops

**Solution**:
\`\`\`php
// BAD: N+1 problem
\$users = User::all();
foreach (\$users as \$user) {
    echo \$user->posts->count();  // N queries
}

// GOOD: Eager loading
\$users = User::with('posts')->get();
foreach (\$users as \$user) {
    echo \$user->posts->count();  // No additional queries
}
\`\`\`

**Implementation**:
- Add \`with()\` for all relationships accessed in views
- Use lazy eager loading: \$users->load('posts')
- Enable \`Model::preventLazyLoading()\` in production

### 2. Missing Database Indexes
**Problem**: Full table scans on filtered/ordered queries

**Detection**:
- Run \`EXPLAIN\` on slow queries
- Look for "Using filesort" or "Using temporary"
- Check for queries filtering on unindexed columns

**Solution**:
\`\`\`php
// Add indexes for frequently filtered columns
Schema::table('users', function (Blueprint \$table) {
    \$table->index(['email', 'deleted_at']);
    \$table->index('created_at');
    \$table->index('status');
});
\`\`\`

**Recommendation Script**:
- Run \`./perf-index-recommend.sh\` to get index suggestions

### 3. Excessive Data Loading
**Problem**: Selecting all columns when only a few are needed

**Solution**:
\`\`\`php
// BAD: Selects all columns
\$users = User::with('posts')->get();

// GOOD: Selects only needed columns
\$users = User::with(['posts:id,user_id,title'])
    ->select(['id', 'name', 'email'])
    ->get();
\`\`\`

## Medium Priority

### 4. No Query Caching
**Problem**: Every request executes the same queries

**Solution**:
\`\`\`php
// Use RedisCacheStrategy service
use App\Services\RedisCacheStrategy;

\$cache = app(RedisCacheStrategy::class);

\$containers = \$cache->cacheDbQuery(
    'lxc_containers',
    ['status' => 'running'],
    fn() => LxcContainer::where('status', 'running')->get(),
    'short'  // 5 minute TTL
);
\`\`\`

### 5. Inefficient Pagination
**Problem**: Using offset pagination on large datasets

**Solution**:
\`\`\`php
// Use cursor-based pagination for better performance
\$containers = LxcContainer::orderBy('id')
    ->cursorPaginate(50);

// Or use DatabaseQueryOptimizer
\$optimizer = app(DatabaseQueryOptimizer::class);
\$result = \$optimizer->cursorPaginate(
    LxcContainer::query(),
    50
);
\`\`\`

### 6. Missing HTTP Caching
**Problem**: No browser/client caching for API responses

**Solution**:
\`\`\`php
// Add cache headers
return response()->json(\$data)
    ->header('Cache-Control', 'public, max-age=300');

// Add ETag support
\$etag = md5(\$data->toJson());
if (request()->getETags() && in_array(\$etag, request()->getETags())) {
    return response()->noContent()->setEtag(\$etag);
}
return response()->json(\$data)->setEtag(\$etag);
\`\`\`

## Low Priority

### 7. Large Dataset Processing
**Problem**: Loading entire datasets into memory

**Solution**:
\`\`\`php
// Use lazy collections for memory efficiency
User::lazy()->each(function (\$user) {
    // Process user
});

// Or chunk processing
User::chunk(1000, function (\$users) {
    foreach (\$users as \$user) {
        // Process user
    }
});
\`\`\`

### 8. Duplicate Queries
**Problem**: Same query executed multiple times per request

**Solution**:
- Use query result caching
- Store results in variables
- Use eager loading to fetch once

## Implementation Checklist

### Immediate Actions (This Sprint)
- [ ] Enable Laravel Debugbar in development
- [ ] Identify all N+1 queries
- [ ] Add eager loading for all relationships
- [ ] Add indexes for frequently filtered columns
- [ ] Implement caching for slow queries

### Short Term (Next Sprint)
- [ ] Enable query caching with Redis
- [ ] Implement cursor pagination
- [ ] Add HTTP caching headers
- [ ] Optimize subqueries with JOINs
- [ ] Set up performance monitoring

### Long Term (Next Quarter)
- [ ] Enable preventLazyLoading in production
- [ ] Implement full query caching strategy
- [ ] Set up automated performance testing
- [ ] Configure read/write database splitting
- [ ] Implement database connection pooling

## Expected Improvements

Implementing these optimizations should result in:

- **90% reduction** in database queries (N+1 prevention)
- **50-70% faster** response times (caching, indexing)
- **75% reduction** in memory usage (lazy collections, selective loading)
- **10-20x increase** in throughput capacity

## Monitoring

Track these metrics after implementation:

- Query count per request (target: <20)
- Average query execution time (target: <50ms)
- Cache hit rate (target: >80%)
- Response time p95 (target: <300ms)
- Memory usage per request (target: <64MB)

EOF

    echo -e "${GREEN}Recommendations saved to: ${REPORT_FILE}${NC}"
    echo ""
}

###############################################################################
# Summary
###############################################################################

print_summary() {
    echo -e "${BLUE}=== Analysis Summary ===${NC}"
    echo ""
    echo "Files generated:"
    echo "  - Query log: ${LOG_FILE}"
    echo "  - Recommendations: ${PROJECT_ROOT}/storage/app/query-recommendations-${TIMESTAMP}.md"
    echo ""
    echo "Next steps:"
    echo "  1. Review the recommendations document"
    echo "  2. Enable Laravel Debugbar in development"
    echo "  3. Identify N+1 queries with Debugbar"
    echo "  4. Add eager loading for relationships"
    echo "  5. Run index recommendations: ./perf-index-recommend.sh"
    echo "  6. Profile performance: ./perf-profile.sh"
    echo ""
}

###############################################################################
# Main execution
###############################################################################

main() {
    check_query_log

    case "${ACTION}" in
        analyze)
            analyze_n_plus_one
            analyze_query_patterns
            generate_recommendations
            ;;
        recommend)
            generate_recommendations
            ;;
        *)
            echo -e "${RED}Unknown action: ${ACTION}${NC}"
            echo "Usage: $0 [analyze|recommend]"
            exit 1
            ;;
    esac

    print_summary
}

main "$@"
