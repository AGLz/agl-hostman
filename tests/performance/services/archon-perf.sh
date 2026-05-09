#!/bin/bash
# Archon MCP Service Performance Test
# Tests: API Response Time, Throughput, Concurrent Requests, MCP Tool Performance
# Author: Tester Agent (Hive Mind)
# Date: 2025-11-02

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESULTS_DIR="${RESULTS_DIR:-/tmp/performance-results}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
RESULT_FILE="${RESULTS_DIR}/archon-perf_${TIMESTAMP}.json"

# Test parameters
REQUEST_COUNT="${REQUEST_COUNT:-100}"
CONCURRENCY="${CONCURRENCY:-10}"
DURATION="${DURATION:-30}"

# Archon endpoints (from ARCHON.md)
ARCHON_WG="${ARCHON_WG:-http://10.6.0.21:8051}"
ARCHON_TAILSCALE="${ARCHON_TAILSCALE:-http://100.80.30.59:8051}"
ARCHON_PUBLIC="${ARCHON_PUBLIC:-https://archon.aglz.io}"

# Default to WireGuard
ARCHON_URL="${ARCHON_URL:-$ARCHON_WG}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

mkdir -p "$RESULTS_DIR"

log_info() { echo -e "${BLUE}[INFO]${NC} $*"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $*"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }

# Check Archon availability
check_archon() {
    log_info "Checking Archon availability at $ARCHON_URL..."

    local health_url="${ARCHON_URL}/health"

    if ! curl -sf -m 5 "$health_url" &> /dev/null; then
        log_error "Archon not reachable at $ARCHON_URL"
        log_info "Trying alternative endpoints..."

        # Try Tailscale
        if curl -sf -m 5 "${ARCHON_TAILSCALE}/health" &> /dev/null; then
            ARCHON_URL="$ARCHON_TAILSCALE"
            log_success "Using Tailscale endpoint: $ARCHON_URL"
            return 0
        fi

        return 1
    fi

    log_success "Archon is reachable"
    return 0
}

# Simple response time test
test_response_time() {
    local endpoint=$1
    local url="${ARCHON_URL}${endpoint}"

    log_info "Testing response time for $endpoint..."

    local total_time=0
    local success_count=0
    local error_count=0
    local times=()

    for i in $(seq 1 "$REQUEST_COUNT"); do
        local response_time=$(curl -sf -w "%{time_total}" -o /dev/null -m 10 "$url" 2>/dev/null || echo "-1")

        if [ "$response_time" = "-1" ]; then
            ((error_count++))
        else
            ((success_count++))
            # Convert to milliseconds
            local time_ms=$(echo "$response_time * 1000" | bc)
            times+=("$time_ms")
            total_time=$(echo "$total_time + $time_ms" | bc)
        fi

        # Progress indicator
        [ $((i % 10)) -eq 0 ] && echo -n "." >&2
    done
    echo >&2

    if [ "$success_count" -eq 0 ]; then
        log_error "All requests failed for $endpoint"
        echo "null"
        return 1
    fi

    # Calculate statistics
    local avg_time=$(echo "scale=2; $total_time / $success_count" | bc)
    local error_rate=$(echo "scale=2; ($error_count / $REQUEST_COUNT) * 100" | bc)

    # Sort times for percentiles
    IFS=$'\n' sorted_times=($(sort -n <<<"${times[*]}"))
    unset IFS

    local p50_index=$((success_count / 2))
    local p95_index=$((success_count * 95 / 100))
    local p99_index=$((success_count * 99 / 100))

    local p50=${sorted_times[$p50_index]:-0}
    local p95=${sorted_times[$p95_index]:-0}
    local p99=${sorted_times[$p99_index]:-0}
    local max=${sorted_times[-1]:-0}
    local min=${sorted_times[0]:-0}

    # Determine status (expect <100ms p95 for Archon)
    local status="GOOD"
    if (( $(echo "$p95 > 200" | bc -l) )); then
        status="WARNING"
    fi
    if (( $(echo "$p95 > 500" | bc -l) )); then
        status="CRITICAL"
    fi

    cat <<EOF
    {
      "endpoint": "$endpoint",
      "request_count": $REQUEST_COUNT,
      "success_count": $success_count,
      "error_count": $error_count,
      "error_rate_percent": $error_rate,
      "response_time_ms": {
        "avg": $avg_time,
        "min": $min,
        "max": $max,
        "p50": $p50,
        "p95": $p95,
        "p99": $p99
      },
      "status": "$status"
    }
EOF

    log_success "$endpoint: avg=${avg_time}ms, p95=${p95}ms, errors=${error_rate}%, status=$status"
}

# Concurrent load test
test_concurrent_load() {
    local endpoint=$1
    local url="${ARCHON_URL}${endpoint}"

    log_info "Testing concurrent load for $endpoint (concurrency=$CONCURRENCY)..."

    # Use GNU parallel if available, otherwise fallback
    if command -v parallel &> /dev/null; then
        local start_time=$(date +%s.%N)
        seq 1 "$REQUEST_COUNT" | parallel -j "$CONCURRENCY" --bar \
            "curl -sf -w '%{time_total}\n' -o /dev/null -m 10 '$url' 2>/dev/null || echo -1" \
            > /tmp/concurrent_results_$$.txt 2>/dev/null
        local end_time=$(date +%s.%N)
    else
        # Fallback to basic concurrent execution
        log_warning "GNU parallel not found, using basic concurrency"
        local start_time=$(date +%s.%N)
        for i in $(seq 1 "$REQUEST_COUNT"); do
            curl -sf -w "%{time_total}\n" -o /dev/null -m 10 "$url" 2>/dev/null || echo "-1" &
            # Limit concurrency
            if [ $((i % CONCURRENCY)) -eq 0 ]; then
                wait
            fi
        done
        wait
        local end_time=$(date +%s.%N)
    fi

    # Calculate throughput
    local total_duration=$(echo "$end_time - $start_time" | bc)
    local throughput=$(echo "scale=2; $REQUEST_COUNT / $total_duration" | bc)

    # Count successes
    local success_count=$(grep -v "^-1$" /tmp/concurrent_results_$$.txt 2>/dev/null | wc -l || echo 0)
    local error_count=$((REQUEST_COUNT - success_count))
    local error_rate=$(echo "scale=2; ($error_count / $REQUEST_COUNT) * 100" | bc)

    # Cleanup
    rm -f /tmp/concurrent_results_$$.txt

    # Determine status (expect >50 req/s for Archon)
    local status="GOOD"
    if (( $(echo "$throughput < 25" | bc -l) )); then
        status="WARNING"
    fi
    if (( $(echo "$throughput < 10" | bc -l) )); then
        status="CRITICAL"
    fi

    cat <<EOF
    {
      "endpoint": "$endpoint",
      "request_count": $REQUEST_COUNT,
      "concurrency": $CONCURRENCY,
      "duration_sec": $total_duration,
      "throughput_req_per_sec": $throughput,
      "success_count": $success_count,
      "error_count": $error_count,
      "error_rate_percent": $error_rate,
      "status": "$status"
    }
EOF

    log_success "$endpoint: throughput=${throughput} req/s, errors=${error_rate}%, status=$status"
}

# Test MCP endpoint availability
test_mcp_endpoints() {
    log_info "Testing MCP endpoint availability..."

    local endpoints=("/health" "/mcp" "/api/status")
    local results=()

    for endpoint in "${endpoints[@]}"; do
        local url="${ARCHON_URL}${endpoint}"
        local http_code=$(curl -sf -w "%{http_code}" -o /dev/null -m 5 "$url" 2>/dev/null || echo "000")
        local available=$([[ "$http_code" =~ ^(200|302)$ ]] && echo "true" || echo "false")

        results+=("{\"endpoint\": \"$endpoint\", \"http_code\": $http_code, \"available\": $available}")
    done

    echo "  \"mcp_endpoints\": ["
    local first=1
    for result in "${results[@]}"; do
        [ $first -eq 0 ] && echo ","
        first=0
        echo "    $result"
    done
    echo "  ]"
}

# Main test execution
main() {
    log_info "=== Archon MCP Service Performance Test ==="
    log_info "Archon URL: $ARCHON_URL"
    log_info "Request count: $REQUEST_COUNT"
    log_info "Concurrency: $CONCURRENCY"
    log_info "Results: $RESULT_FILE"
    echo

    # Check Archon availability
    if ! check_archon; then
        log_error "Archon is not available, cannot run tests"
        exit 1
    fi

    # Build JSON results
    {
        echo "{"
        echo '  "test_type": "archon_performance",'
        echo "  \"archon_url\": \"$ARCHON_URL\","
        echo "  \"timestamp\": \"$(date -Iseconds)\","
        echo "  \"request_count\": $REQUEST_COUNT,"
        echo "  \"concurrency\": $CONCURRENCY,"

        # MCP endpoint availability
        test_mcp_endpoints
        echo ","

        # Response time tests
        echo '  "response_time_tests": ['
        test_response_time "/health"
        echo ","
        test_response_time "/api/status"
        echo '  ],'

        # Concurrent load tests
        echo '  "concurrent_load_tests": ['
        test_concurrent_load "/health"
        echo ","
        test_concurrent_load "/api/status"
        echo '  ]'

        echo "}"
    } > "$RESULT_FILE"

    # Display summary
    echo
    log_info "=== Test Results Summary ==="

    if command -v jq &> /dev/null; then
        # Average response time
        local avg_p95=$(jq '[.response_time_tests[].response_time_ms.p95] | add / length' "$RESULT_FILE" 2>/dev/null || echo 0)
        local avg_throughput=$(jq '[.concurrent_load_tests[].throughput_req_per_sec] | add / length' "$RESULT_FILE" 2>/dev/null || echo 0)

        echo "Average p95 Response Time: ${avg_p95} ms"
        echo "Average Throughput: ${avg_throughput} req/s"

        # Count statuses
        local good=$(jq '[.response_time_tests[], .concurrent_load_tests[] | select(.status == "GOOD")] | length' "$RESULT_FILE")
        local warning=$(jq '[.response_time_tests[], .concurrent_load_tests[] | select(.status == "WARNING")] | length' "$RESULT_FILE")
        local critical=$(jq '[.response_time_tests[], .concurrent_load_tests[] | select(.status == "CRITICAL")] | length' "$RESULT_FILE")

        echo -e "Status: ${GREEN}$good GOOD${NC}, ${YELLOW}$warning WARNING${NC}, ${RED}$critical CRITICAL${NC}"
    fi

    echo
    log_success "Results saved to: $RESULT_FILE"

    # Pretty print if requested
    if [ "${VERBOSE:-0}" -eq 1 ] && command -v jq &> /dev/null; then
        echo
        log_info "Detailed Results:"
        jq '.' "$RESULT_FILE"
    fi
}

# Run main
main "$@"
