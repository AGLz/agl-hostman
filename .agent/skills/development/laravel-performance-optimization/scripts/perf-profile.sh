#!/bin/bash

###############################################################################
# Laravel Performance Profiler
#
# Profiles Laravel application performance using Blackfire or XHProf
# and generates detailed performance reports.
#
# Usage:
#   ./perf-profile.sh [endpoint] [requests] [concurrency]
#
# Examples:
#   ./perf-profile.sh /api/containers 100 10
#   ./perf-profile.sh /api/deployments 50 5
###############################################################################

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
ENDPOINT="${1:-/api/containers}"
REQUESTS="${2:-100}"
CONCURRENCY="${3:-10}"
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
OUTPUT_DIR="${PROJECT_ROOT}/storage/app/perf-profiles"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Create output directory
mkdir -p "${OUTPUT_DIR}"

echo -e "${BLUE}=== Laravel Performance Profiler ===${NC}"
echo "Endpoint: ${ENDPOINT}"
echo "Requests: ${REQUESTS}"
echo "Concurrency: ${CONCURRENCY}"
echo ""

###############################################################################
# Check for required tools
###############################################################################

check_tools() {
    echo -e "${BLUE}Checking for required tools...${NC}"

    # Check for ab (Apache Bench)
    if command -v ab &> /dev/null; then
        AB_AVAILABLE=true
        echo -e "${GREEN}✓ Apache Bench (ab) found${NC}"
    else
        AB_AVAILABLE=false
        echo -e "${YELLOW}⚠ Apache Bench (ab) not found${NC}"
        echo "  Install: apt-get install apache2-utils"
    fi

    # Check for curl
    if command -v curl &> /dev/null; then
        CURL_AVAILABLE=true
        echo -e "${GREEN}✓ curl found${NC}"
    else
        CURL_AVAILABLE=false
        echo -e "${RED}✗ curl not found${NC}"
    fi

    # Check for Blackfire
    if command -v blackfire &> /dev/null; then
        BLACKFIRE_AVAILABLE=true
        echo -e "${GREEN}✓ Blackfire found${NC}"
    else
        BLACKFIRE_AVAILABLE=false
        echo -e "${YELLOW}⚠ Blackfire not found (optional)${NC}"
    fi

    # Check for XHProf
    if php -m | grep -q xhprof; then
        XHPROF_AVAILABLE=true
        echo -e "${GREEN}✓ XHProf found${NC}"
    else
        XHPROF_AVAILABLE=false
        echo -e "${YELLOW}⚠ XHProf not found (optional)${NC}"
    fi

    echo ""
}

###############################################################################
# Get base URL from .env
###############################################################################

get_base_url() {
    if [ -f "${PROJECT_ROOT}/.env" ]; then
        source "${PROJECT_ROOT}/.env"
        if [ -n "${APP_URL}" ]; then
            echo "${APP_URL}"
        else
            echo "http://localhost:8000"
        fi
    else
        echo "http://localhost:8000"
    fi
}

###############################################################################
# Run Apache Bench load test
###############################################################################

run_ab_benchmark() {
    if [ "${AB_AVAILABLE}" != true ]; then
        echo -e "${RED}Apache Bench not available, skipping load test${NC}"
        return
    fi

    echo -e "${BLUE}Running Apache Bench load test...${NC}"

    BASE_URL=$(get_base_url)
    OUTPUT_FILE="${OUTPUT_DIR}/ab_${TIMESTAMP}.txt"

    cd "${PROJECT_ROOT}"

    ab -n "${REQUESTS}" -c "${CONCURRENCY}" \
       -g "${OUTPUT_DIR}/ab_${TIMESTAMP}.gnuplot" \
       "${BASE_URL}${ENDPOINT}" \
       | tee "${OUTPUT_FILE}"

    echo -e "${GREEN}Load test complete: ${OUTPUT_FILE}${NC}"
    echo ""
}

###############################################################################
# Run curl timing test
###############################################################################

run_curl_timing() {
    if [ "${CURL_AVAILABLE}" != true ]; then
        return
    fi

    echo -e "${BLUE}Running curl timing test...${NC}"

    BASE_URL=$(get_base_url)
    OUTPUT_FILE="${OUTPUT_DIR}/curl_${TIMESTAMP}.txt"

    # Run 10 requests and collect timing data
    echo "Timing test for ${ENDPOINT}" > "${OUTPUT_FILE}"
    echo "================================" >> "${OUTPUT_FILE}"
    echo "" >> "${OUTPUT_FILE}"

    for i in {1..10}; do
        echo -n "Request ${i}/10... "
        curl -o /dev/null -s -w "\nName lookup: %{time_namelookup}s\nConnect: %{time_connect}s\nStart transfer: %{time_starttransfer}s\nTotal time: %{time_total}s\nHTTP code: %{http_code}\n" \
             "${BASE_URL}${ENDPOINT}" >> "${OUTPUT_FILE}"
        echo -e "${GREEN}done${NC}"
    done

    echo -e "${GREEN}Timing test complete: ${OUTPUT_FILE}${NC}"
    echo ""
}

###############################################################################
# Analyze results
###############################################################################

analyze_results() {
    echo -e "${BLUE}Analyzing results...${NC}"
    echo ""

    OUTPUT_FILE="${OUTPUT_DIR}/summary_${TIMESTAMP}.txt"

    {
        echo "Performance Summary"
        echo "==================="
        echo ""
        echo "Endpoint: ${ENDPOINT}"
        echo "Requests: ${REQUESTS}"
        echo "Concurrency: ${CONCURRENCY}"
        echo "Timestamp: ${TIMESTAMP}"
        echo ""

        # Parse Apache Bench results if available
        if [ -f "${OUTPUT_DIR}/ab_${TIMESTAMP}.txt" ]; then
            echo "--- Apache Bench Results ---"
            grep -E "(Requests per second|Time per request|Transfer rate)" \
                 "${OUTPUT_DIR}/ab_${TIMESTAMP}.txt" || true
            echo ""
        fi

        # Calculate average curl timing if available
        if [ -f "${OUTPUT_DIR}/curl_${TIMESTAMP}.txt" ]; then
            echo "--- Average Response Times (10 requests) ---"
            grep "Total time:" "${OUTPUT_DIR}/curl_${TIMESTAMP}.txt" | \
                awk '{sum+=$3; count++} END {if(count>0) print "Average: " sum/count "s"}'
            echo ""
        fi

        echo "--- Recommendations ---"

        # Check for slow responses
        if [ -f "${OUTPUT_DIR}/ab_${TIMESTAMP}.txt" ]; then
            RPS=$(grep "Requests per second" "${OUTPUT_DIR}/ab_${TIMESTAMP}.txt" | \
                  awk '{print $4}')
            if [ -n "${RPS}" ]; then
                RPS_INT=${RPS%.*}
                if [ "${RPS_INT}" -lt 10 ]; then
                    echo -e "${YELLOW}⚠ Low throughput (${RPS} req/s)${NC}"
                    echo "  Consider: Caching, query optimization, eager loading"
                elif [ "${RPS_INT}" -lt 50 ]; then
                    echo -e "${YELLOW}⚠ Moderate throughput (${RPS} req/s)${NC}"
                    echo "  Consider: Redis caching, database indexing"
                else
                    echo -e "${GREEN}✓ Good throughput (${RPS} req/s)${NC}"
                fi
            fi
        fi

        # Check for high latency
        if [ -f "${OUTPUT_DIR}/curl_${TIMESTAMP}.txt" ]; then
            AVG_TIME=$(grep "Total time:" "${OUTPUT_DIR}/curl_${TIMESTAMP}.txt" | \
                       awk '{sum+=$3; count++} END {if(count>0) print sum/count}')
            if [ -n "${AVG_TIME}" ]; then
                AVG_INT=${AVG_TIME%.*}
                if [ "${AVG_INT}" -gt 1 ]; then
                    echo -e "${YELLOW}⚠ High latency (${AVG_TIME}s average)${NC}"
                    echo "  Consider: N+1 query prevention, lazy loading, HTTP caching"
                elif [ "${AVG_INT}" -gt 500 ]; then
                    echo -e "${YELLOW}⚠ Moderate latency (${AVG_TIME}s average)${NC}"
                    echo "  Consider: Query optimization, response caching"
                else
                    echo -e "${GREEN}✓ Good latency (${AVG_TIME}s average)${NC}"
                fi
            fi
        fi

    } | tee "${OUTPUT_FILE}"

    echo ""
    echo -e "${GREEN}Summary saved to: ${OUTPUT_FILE}${NC}"
    echo ""
}

###############################################################################
# Generate performance report
###############################################################################

generate_report() {
    echo -e "${BLUE}Generating performance report...${NC}"

    REPORT_FILE="${OUTPUT_DIR}/report_${TIMESTAMP}.md"

    cat > "${REPORT_FILE}" <<EOF
# Performance Report

## Test Configuration
- **Endpoint**: ${ENDPOINT}
- **Total Requests**: ${REQUESTS}
- **Concurrency**: ${CONCURRENCY}
- **Timestamp**: ${TIMESTAMP}

## Results

### Throughput
$(if [ -f "${OUTPUT_DIR}/ab_${TIMESTAMP}.txt" ]; then
    grep -E "(Requests per second|Time per request|Transfer rate)" \
         "${OUTPUT_DIR}/ab_${TIMESTAMP}.txt" | sed 's/^/- /'
else
    echo "- Load test not available"
fi)

### Response Times
$(if [ -f "${OUTPUT_DIR}/curl_${TIMESTAMP}.txt" ]; then
    echo "| Metric | Average |"
    echo "|--------|---------|"
    grep "Total time:" "${OUTPUT_DIR}/curl_${TIMESTAMP}.txt" | \
        awk '{sum+=$3; count++} END {printf "| Total Time | %.3fs |\n", sum/count}'
    grep "Start transfer:" "${OUTPUT_DIR}/curl_${TIMESTAMP}.txt" | \
        awk '{sum+=$3; count++} END {printf "| Start Transfer | %.3fs |\n", sum/count}'
    grep "Connect:" "${OUTPUT_DIR}/curl_${TIMESTAMP}.txt" | \
        awk '{sum+=$3; count++} END {printf "| Connect | %.3fs |\n", sum/count}'
else
    echo "Timing data not available"
fi)

## Recommendations

### Caching
- [ ] Enable Redis caching for ${ENDPOINT}
- [ ] Set appropriate TTL (short: 5min, medium: 30min, long: 1hour)
- [ ] Implement cache invalidation on data changes
- [ ] Use cache tags for hierarchical invalidation

### Database Optimization
- [ ] Check for N+1 queries using Laravel Debugbar
- [ ] Add eager loading for relationships
- [ ] Use selective column loading
- [ ] Add database indexes for filtered columns
- [ ] Implement query result caching

### API Optimization
- [ ] Implement cursor-based pagination
- [ ] Use API resources to limit response size
- [ ] Add HTTP caching headers (ETag, Cache-Control)
- [ ] Optimize filtering and sorting with indexes

### Monitoring
- [ ] Set up performance monitoring with Telescope
- [ ] Configure alerts for slow queries (>100ms)
- [ ] Track cache hit rates
- [ ] Monitor memory usage per request

## Files Generated
- Load test: \`ab_${TIMESTAMP}.txt\`
- Timing data: \`curl_${TIMESTAMP}.txt\`
- Summary: \`summary_${TIMESTAMP}.txt\`

EOF

    echo -e "${GREEN}Report saved to: ${REPORT_FILE}${NC}"
    echo ""
}

###############################################################################
# Main execution
###############################################################################

main() {
    check_tools
    run_ab_benchmark
    run_curl_timing
    analyze_results
    generate_report

    echo -e "${GREEN}=== Profiling Complete ===${NC}"
    echo "All results saved to: ${OUTPUT_DIR}"
    echo ""
    echo "Next steps:"
    echo "  1. Review the summary: ${OUTPUT_DIR}/summary_${TIMESTAMP}.txt"
    echo "  2. Check the report: ${OUTPUT_DIR}/report_${TIMESTAMP}.md"
    echo "  3. Run query analyzer: ./perf-query-analyzer.sh"
    echo "  4. Check index recommendations: ./perf-index-recommend.sh"
}

main "$@"
