#!/bin/bash
################################################################################
# Health Check Script: Post-deployment Verification
# Purpose: Comprehensive health checks after deployment
# Supports: Staging and Production environments
#
# Usage:
#   ./scripts/deployment/health-check.sh [--environment ENV] [--detailed]
#
# Environment Variables Required:
#   STAGING_DOMAIN - Staging domain
#   PRODUCTION_DOMAIN - Production domain
#
# Features:
#   - HTTP endpoint health checks
#   - Database connectivity verification
#   - Cache service verification
#   - API endpoint smoke tests
#   - Performance metrics collection
#   - Detailed reporting
################################################################################

set -e  # Exit on error
set -o pipefail  # Exit on pipe failure

################################################################################
# Configuration
################################################################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
REPORT_FILE="/tmp/health-check-report-$(date +%Y%m%d-%H%M%S).json"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
ENVIRONMENT="staging"
DETAILED=false
TIMEOUT=30
RETRY_COUNT=3
RETRY_DELAY=5

# Health check thresholds
MAX_RESPONSE_TIME=500  # milliseconds
MAX_ERROR_RATE=0.01    # 1%
MIN_SUCCESS_RATE=0.99  # 99%

# Load environment variables
if [ -f "$PROJECT_ROOT/.env" ]; then
    source "$PROJECT_ROOT/.env"
fi

# Get domain based on environment
get_domain() {
    case "$ENVIRONMENT" in
        "production")
            echo "${PRODUCTION_DOMAIN:-prod-agl.aglz.io}"
            ;;
        "staging")
            echo "${STAGING_DOMAIN:-staging-agl.aglz.io}"
            ;;
        *)
            echo "unknown"
            ;;
    esac
}

DOMAIN=$(get_domain)
BASE_URL="https://$DOMAIN"

################################################################################
# Utility Functions
################################################################################

log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${timestamp} [${level}] ${message}"
}

log_info() { log "INFO" "${BLUE}$*${NC}"; }
log_success() { log "PASS" "${GREEN}$*${NC}"; }
log_warning() { log "WARN" "${YELLOW}$*${NC}"; }
log_error() { log "FAIL" "${RED}$*${NC}"; }

show_usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Run comprehensive health checks on deployed environment.

OPTIONS:
    --environment ENV   Target environment (production|staging, default: staging)
    --detailed          Show detailed metrics and diagnostics
    --help              Show this help message

CHECKS PERFORMED:
    HTTP Endpoints:
        - /api/health         (required)
        - /api/overview       (required)
        - /api/containers     (required)
        - /api/vms            (required)
        - /api/network        (optional)
        - /api/metrics        (optional)

    Service Health:
        - Database connectivity
        - Cache/Redis connectivity
        - Queue worker status
        - WebSocket connection

    Performance:
        - Response times
        - Error rates
        - Throughput

EXAMPLES:
    $0                                    # Check staging health
    $0 --environment production            # Check production health
    $0 --environment production --detailed # Detailed production check
EOF
}

# Initialize report
init_report() {
    cat > "$REPORT_FILE" << EOF
{
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "environment": "$ENVIRONMENT",
  "domain": "$DOMAIN",
  "checks": []
}
EOF
}

# Add check result to report
add_check_result() {
    local name="$1"
    local status="$2"
    local details="$3"
    local response_time="${4:-0}"
    local output=""

    output=$(jq -r \
        --arg name "$name" \
        --arg status "$status" \
        --arg details "$details" \
        --argjson response_time "$response_time" \
        '.checks += [{
            "name": $name,
            "status": $status,
            "details": $details,
            "response_time_ms": $response_time,
            "timestamp": (now | todate)
        }]' "$REPORT_FILE")

    echo "$output" > "$REPORT_FILE"
}

################################################################################
# HTTP Health Checks
################################################################################

check_http_endpoint() {
    local endpoint="$1"
    local required="${2:-true}"
    local url="$BASE_URL$endpoint"

    log_info "Checking: $endpoint"

    local start_time=$(date +%s%3N)  # Milliseconds
    local http_code=""
    local response_time=0
    local status="fail"
    local details=""

    for attempt in $(seq 1 $RETRY_COUNT); do
        response=$(curl -s -w "\n%{http_code}" -m "$TIMEOUT" "$url" 2>&1)
        http_code=$(echo "$response" | tail -n1)
        body=$(echo "$response" | head -n-1)

        end_time=$(date +%s%3N)
        response_time=$((end_time - start_time))

        if [ "$http_code" = "200" ] || [ "$http_code" = "204" ]; then
            status="pass"
            details="HTTP $http_code, ${response_time}ms"
            log_success "$endpoint: ${response_time}ms"
            break
        elif [ "$http_code" = "000" ]; then
            details="Connection failed (attempt $attempt/$RETRY_COUNT)"
            if [ $attempt -lt $RETRY_COUNT ]; then
                sleep $RETRY_DELAY
                continue
            fi
        else
            details="HTTP $http_code"
        fi
    done

    if [ "$status" = "fail" ]; then
        log_error "$endpoint: $details"
        if [ "$required" = "true" ]; then
            add_check_result "$endpoint" "$status" "$details" "$response_time"
            return 1
        fi
    fi

    add_check_result "$endpoint" "$status" "$details" "$response_time"
    return 0
}

check_all_endpoints() {
    log_info "Running HTTP endpoint checks..."

    local required_endpoints=(
        "/api/health"
        "/api/overview"
        "/api/containers"
        "/api/vms"
    )

    local optional_endpoints=(
        "/api/network"
        "/api/metrics"
        "/api/alerts"
    )

    local failed=0

    for endpoint in "${required_endpoints[@]}"; do
        if ! check_http_endpoint "$endpoint" "true"; then
            failed=1
        fi
    done

    for endpoint in "${optional_endpoints[@]}"; do
        check_http_endpoint "$endpoint" "false" || true
    done

    return $failed
}

################################################################################
# Service Health Checks
################################################################################

check_database() {
    log_info "Checking database connectivity..."

    local url="$BASE_URL/api/health/db"
    local response
    local status="fail"
    local details=""

    response=$(curl -s -m "$TIMEOUT" "$url" 2>&1)

    if echo "$response" | jq -e '.status == "ok"' > /dev/null 2>&1; then
        status="pass"
        details="Database connected"

        # Extract connection details if available
        local connections
        connections=$(echo "$response" | jq -r '.connections // "unknown"')
        details="$details (connections: $connections)"

        log_success "Database: $details"
    else
        details="Database check failed: $response"
        log_error "$details"
    fi

    add_check_result "database" "$status" "$details"
    [ "$status" = "pass" ]
}

check_cache() {
    log_info "Checking cache connectivity..."

    local url="$BASE_URL/api/health/cache"
    local response
    local status="fail"
    local details=""

    response=$(curl -s -m "$TIMEOUT" "$url" 2>&1)

    if echo "$response" | jq -e '.status == "ok"' > /dev/null 2>&1; then
        status="pass"
        details="Cache connected"

        # Extract cache stats if available
        local hits
        local misses
        hits=$(echo "$response" | jq -r '.hits // "unknown"')
        misses=$(echo "$response" | jq -r '.misses // "unknown"')
        details="$details (hits: $hits, misses: $misses)"

        log_success "Cache: $details"
    else
        details="Cache check failed"
        log_error "$details"
    fi

    add_check_result "cache" "$status" "$details"
    [ "$status" = "pass" ]
}

check_queue() {
    log_info "Checking queue workers..."

    local url="$BASE_URL/api/health/queue"
    local response
    local status="fail"
    local details=""

    response=$(curl -s -m "$TIMEOUT" "$url" 2>&1)

    if echo "$response" | jq -e '.status == "ok"' > /dev/null 2>&1; then
        status="pass"
        details="Queue workers running"

        # Extract worker count
        local workers
        workers=$(echo "$response" | jq -r '.workers // "unknown"')
        local pending
        pending=$(echo "$response" | jq -r '.pending // "unknown"')
        details="$details (workers: $workers, pending: $pending)"

        log_success "Queue: $details"
    else
        details="Queue check failed"
        log_warning "$details"
        # Queue check is not critical for health
        status="warn"
    fi

    add_check_result "queue" "$status" "$details"
    [ "$status" != "fail" ]
}

check_websocket() {
    log_info "Checking WebSocket connection..."

    local url="$BASE_URL/api/health/websocket"
    local response
    local status="fail"
    local details=""

    response=$(curl -s -m "$TIMEOUT" "$url" 2>&1)

    if echo "$response" | jq -e '.status == "ok"' > /dev/null 2>&1; then
        status="pass"
        details="WebSocket connected"

        # Extract connection count
        local connections
        connections=$(echo "$response" | jq -r '.connections // "unknown"')
        details="$details (connections: $connections)"

        log_success "WebSocket: $details"
    else
        details="WebSocket check failed"
        log_warning "$details"
        # WebSocket is not critical
        status="warn"
    fi

    add_check_result "websocket" "$status" "$details"
    [ "$status" != "fail" ]
}

################################################################################
# Performance Metrics
################################################################################

collect_metrics() {
    if [ "$DETAILED" != "true" ]; then
        return 0
    fi

    log_info "Collecting performance metrics..."

    local url="$BASE_URL/api/metrics"
    local response
    local status="pass"
    local details=""

    response=$(curl -s -m "$TIMEOUT" "$url" 2>&1)

    if echo "$response" | jq -e '.' > /dev/null 2>&1; then
        # Extract metrics
        local error_rate
        local avg_response_time
        local throughput
        local memory_usage

        error_rate=$(echo "$response" | jq -r '.error_rate // 0')
        avg_response_time=$(echo "$response" | jq -r '.avg_response_time // 0')
        throughput=$(echo "$response" | jq -r '.throughput // 0')
        memory_usage=$(echo "$response" | jq -r '.memory_usage // 0')

        details="error_rate: $error_rate, response_time: ${avg_response_time}ms, throughput: $throughput, memory: ${memory_usage}%"

        # Check thresholds
        local issues=()

        if (( $(echo "$error_rate > $MAX_ERROR_RATE" | bc -l) )); then
            issues+=("error rate high: $error_rate")
            status="fail"
        fi

        if [ "$avg_response_time" -gt "$MAX_RESPONSE_TIME" ]; then
            issues+=("response time high: ${avg_response_time}ms")
            status="warn"
        fi

        if [ "$memory_usage" -gt 85 ]; then
            issues+=("memory usage high: ${memory_usage}%")
            status="warn"
        fi

        if [ ${#issues[@]} -gt 0 ]; then
            details="$details | Issues: ${issues[*]}"
        fi

        log_info "Metrics: $details"
    else
        status="warn"
        details="Failed to collect metrics"
        log_warning "$details"
    fi

    add_check_result "metrics" "$status" "$details"
    [ "$status" != "fail" ]
}

################################################################################
# Reporting
################################################################################

generate_summary() {
    log_info "Generating health check summary..."

    local total
    local passed
    local failed
    local warned

    total=$(jq -r '.checks | length' "$REPORT_FILE")
    passed=$(jq -r '[.checks[].status | select(. == "pass")] | length' "$REPORT_FILE")
    failed=$(jq -r '[.checks[].status | select(. == "fail")] | length' "$REPORT_FILE")
    warned=$(jq -r '[.checks[].status | select(. == "warn")] | length' "$REPORT_FILE")

    echo ""
    echo "═══════════════════════════════════════════════════════════"
    echo "  HEALTH CHECK SUMMARY"
    echo "═══════════════════════════════════════════════════════════"
    echo ""
    echo "Environment: $ENVIRONMENT"
    echo "Domain: $DOMAIN"
    echo "Timestamp: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo ""
    echo "Results:"
    echo "  Total:   $total"
    echo "  Passed:  $passed"
    echo "  Warned:  $warned"
    echo "  Failed:  $failed"
    echo ""

    if [ "$DETAILED" = "true" ]; then
        echo "Detailed Results:"
        jq -r '.checks[] | "  \(.name): \(.status) - \(.details)"' "$REPORT_FILE"
        echo ""
    fi

    echo "═══════════════════════════════════════════════════════════"
    echo ""

    # Save report
    log_info "Report saved to: $REPORT_FILE"

    if [ "$failed" -gt 0 ]; then
        return 1
    fi

    return 0
}

################################################################################
# Main Health Check Flow
################################################################################

main() {
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --environment)
                ENVIRONMENT="$2"
                DOMAIN=$(get_domain)
                BASE_URL="https://$DOMAIN"
                shift 2
                ;;
            --detailed)
                DETAILED=true
                shift
                ;;
            --help|-h)
                show_usage
                exit 0
                ;;
            *)
                echo "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done

    log_info "Starting health check for $ENVIRONMENT..."
    log_info "Domain: $DOMAIN"

    # Initialize report
    init_report

    local exit_code=0

    # Run all health checks
    if ! check_all_endpoints; then
        exit_code=1
    fi

    if ! check_database; then
        exit_code=1
    fi

    if ! check_cache; then
        exit_code=1
    fi

    if ! check_queue; then
        exit_code=1
    fi

    if ! check_websocket; then
        exit_code=1
    fi

    if ! collect_metrics; then
        exit_code=1
    fi

    # Generate summary
    if ! generate_summary; then
        exit_code=1
    fi

    if [ $exit_code -eq 0 ]; then
        log_success "All health checks passed!"
    else
        log_error "Some health checks failed!"
    fi

    exit $exit_code
}

# Run main function
main "$@"
