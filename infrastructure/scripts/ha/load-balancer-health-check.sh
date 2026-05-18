#!/bin/bash
# =============================================================================
# Load Balancer Health Check Script
# AGL Hostman - High Availability Infrastructure
# =============================================================================
#
# Performs comprehensive health checks on backend services
# Used by HAProxy/Nginx for active/passive health monitoring
#
# Usage: ./load-balancer-health-check.sh [endpoint]
#
# Endpoints:
#   - health: Basic health check (returns 200 if service is running)
#   - database: Database connectivity and latency
#   - cache: Redis/Cache connectivity and latency
#   - queue: Queue worker status
#   - all: Run all checks and return aggregate status
# =============================================================================

set -euo pipefail

# Configuration
HEALTH_CHECK_HOST="${HEALTH_CHECK_HOST:-127.0.0.1}"
HEALTH_CHECK_PORT="${HEALTH_CHECK_PORT:-8080}"
HEALTH_CHECK_TIMEOUT="${HEALTH_CHECK_TIMEOUT:-5}"

# Output format (text|json|prometheus)
OUTPUT_FORMAT="${OUTPUT_FORMAT:-text}"

# Thresholds (milliseconds)
WARNING_THRESHOLD=500
CRITICAL_THRESHOLD=2000

# Results storage
declare -A results
declare -A latencies

# =============================================================================
# Utility Functions
# -----------------------------------------------------------------------------
curl_health() {
    local endpoint=$1
    local start_time=$(date +%s%3N)

    local response=$(curl -s -o /dev/null -w "%{http_code}" \
        --connect-timeout "$HEALTH_CHECK_TIMEOUT" \
        --max-time "$HEALTH_CHECK_TIMEOUT" \
        "http://${HEALTH_CHECK_HOST}:${HEALTH_CHECK_PORT}/${endpoint}" 2>/dev/null || echo "000")

    local end_time=$(date +%s%3N)
    local latency=$(( (end_time - start_time) / 1000000 ))

    echo "$response|$latency"
}

check_http_status() {
    local response=$1
    local expected=${2:-200}

    if [[ "$response" == "$expected" ]]; then
        return 0
    else
        return 1
    fi
}

get_status_color() {
    local latency=$1

    if [[ $latency -lt $WARNING_THRESHOLD ]]; then
        echo "green"
    elif [[ $latency -lt $CRITICAL_THRESHOLD ]]; then
        echo "yellow"
    else
        echo "red"
    fi
}

# =============================================================================
# Health Check Functions
# -----------------------------------------------------------------------------
check_basic_health() {
    local result=$(curl_health "health")
    local status=$(echo "$result" | cut -d'|' -f1)
    local latency=$(echo "$result" | cut -d'|' -f2)

    results[health]=$status
    latencies[health]=$latency

    if check_http_status "$status" "200"; then
        echo "OK: Basic health check (latency: ${latency}ms)"
        return 0
    else
        echo "CRITICAL: Basic health check failed (status: $status)"
        return 2
    fi
}

check_database_health() {
    local result=$(curl_health "health/database")
    local status=$(echo "$result" | cut -d'|' -f1)
    local latency=$(echo "$result" | cut -d'|' -f2)

    results[database]=$status
    latencies[database]=$latency

    if check_http_status "$status" "200"; then
        local color=$(get_status_color $latency)
        echo "${color^^}: Database health check (latency: ${latency}ms)"
        [[ "$color" == "green" ]] && return 0 || return 1
    else
        echo "CRITICAL: Database health check failed (status: $status)"
        return 2
    fi
}

check_cache_health() {
    local result=$(curl_health "health/cache")
    local status=$(echo "$result" | cut -d'|' -f1)
    local latency=$(echo "$result" | cut -d'|' -f2)

    results[cache]=$status
    latencies[cache]=$latency

    if check_http_status "$status" "200"; then
        local color=$(get_status_color $latency)
        echo "${color^^}: Cache health check (latency: ${latency}ms)"
        [[ "$color" == "green" ]] && return 0 || return 1
    else
        echo "CRITICAL: Cache health check failed (status: $status)"
        return 2
    fi
}

check_queue_health() {
    local result=$(curl_health "health/queue")
    local status=$(echo "$result" | cut -d'|' -f1)
    local latency=$(echo "$result" | cut -d'|' -f2)

    results[queue]=$status
    latencies[queue]=$latency

    if check_http_status "$status" "200"; then
        echo "OK: Queue health check (latency: ${latency}ms)"
        return 0
    else
        echo "CRITICAL: Queue health check failed (status: $status)"
        return 2
    fi
}

check_readiness() {
    local result=$(curl_health "health/readiness")
    local status=$(echo "$result" | cut -d'|' -f1)
    local latency=$(echo "$result" | cut -d'|' -f2)

    results[readiness]=$status
    latencies[readiness]=$latency

    if check_http_status "$status" "200"; then
        echo "OK: Readiness probe passed (latency: ${latency}ms)"
        return 0
    else
        echo "CRITICAL: Readiness probe failed (status: $status)"
        return 2
    fi
}

check_liveness() {
    local result=$(curl_health "health/liveness")
    local status=$(echo "$result" | cut -d'|' -f1)
    local latency=$(echo "$result" | cut -d'|' -f2)

    results[liveness]=$status
    latencies[liveness]=$latency

    if check_http_status "$status" "200"; then
        echo "OK: Liveness probe passed (latency: ${latency}ms)"
        return 0
    else
        echo "CRITICAL: Liveness probe failed (status: $status)"
        return 2
    fi
}

run_all_checks() {
    local overall_status=0
    declare -a check_results

    echo "=== AGL Hostman Health Check Report ==="
    echo "Timestamp: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo

    # Run all checks
    check_basic_health | read -r line; check_results+=("$line")
    check_database_health | read -r line; check_results+=("$line")
    check_cache_health | read -r line; check_results+=("$line")
    check_queue_health | read -r line; check_results+=("$line")
    check_readiness | read -r line; check_results+=("$line")
    check_liveness | read -r line; check_results+=("$line")

    # Print results
    printf '%s\n' "${check_results[@]}"
    echo

    # Calculate overall status
    for result in "${check_results[@]}"; do
        if [[ "$result" == *"CRITICAL"* ]]; then
            overall_status=2
            break
        elif [[ "$result" == *"YELLOW"* ]] && [[ $overall_status -eq 0 ]]; then
            overall_status=1
        fi
    done

    return $overall_status
}

# =============================================================================
# Output Functions
# -----------------------------------------------------------------------------
output_text() {
    echo "$@"
}

output_json() {
    local status=$1
    shift
    local message="$*"

    cat <<EOF
{
  "status": "$status",
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "hostname": "$(hostname)",
  "checks": {
    "health": {
      "status": "${results[health]:-unknown}",
      "latency_ms": ${latencies[health]:-0}
    },
    "database": {
      "status": "${results[database]:-unknown}",
      "latency_ms": ${latencies[database]:-0}
    },
    "cache": {
      "status": "${results[cache]:-unknown}",
      "latency_ms": ${latencies[cache]:-0}
    },
    "queue": {
      "status": "${results[queue]:-unknown}",
      "latency_ms": ${latencies[queue]:-0}
    },
    "readiness": {
      "status": "${results[readiness]:-unknown}",
      "latency_ms": ${latencies[readiness]:-0}
    },
    "liveness": {
      "status": "${results[liveness]:-unknown}",
      "latency_ms": ${latencies[liveness]:-0}
    }
  },
  "message": "$message"
}
EOF
}

output_prometheus() {
    local timestamp=$(date +%s)

    echo "# HELP agl_health_check_status Health check status (0=critical, 1=warning, 2=ok)"
    echo "# TYPE agl_health_check_status gauge"
    echo "agl_health_check_status{check=\"health\"} ${results[health]:-0} $timestamp"
    echo "agl_health_check_status{check=\"database\"} ${results[database]:-0} $timestamp"
    echo "agl_health_check_status{check=\"cache\"} ${results[cache]:-0} $timestamp"
    echo "agl_health_check_status{check=\"queue\"} ${results[queue]:-0} $timestamp"

    echo "# HELP agl_health_check_latency_ms Health check latency in milliseconds"
    echo "# TYPE agl_health_check_latency_ms gauge"
    echo "agl_health_check_latency_ms{check=\"health\"} ${latencies[health]:-0} $timestamp"
    echo "agl_health_check_latency_ms{check=\"database\"} ${latencies[database]:-0} $timestamp"
    echo "agl_health_check_latency_ms{check=\"cache\"} ${latencies[cache]:-0} $timestamp"
    echo "agl_health_check_latency_ms{check=\"queue\"} ${latencies[queue]:-0} $timestamp"
}

# =============================================================================
# Main
# -----------------------------------------------------------------------------
usage() {
    cat <<EOF
Load Balancer Health Check Script

Usage: $0 [endpoint] [options]

Endpoints:
    health       Basic health check (default)
    database     Database connectivity check
    cache         Cache/Redis check
    queue         Queue worker check
    readiness     Kubernetes readiness probe
    liveness      Kubernetes liveness probe
    all           Run all checks

Environment Variables:
    HEALTH_CHECK_HOST     Host to check (default: 127.0.0.1)
    HEALTH_CHECK_PORT     Port to use (default: 8080)
    HEALTH_CHECK_TIMEOUT  Timeout in seconds (default: 5)
    OUTPUT_FORMAT        Output format: text|json|prometheus

Examples:
    $0 health
    $0 database
    $0 all

    OUTPUT_FORMAT=json $0 health
EOF
    exit 0
}

# Parse arguments
ENDPOINT=${1:-health}
shift || true

# Run checks based on endpoint
case "$ENDPOINT" in
    health)
        check_basic_health
        exit_code=$?
        ;;
    database)
        check_database_health
        exit_code=$?
        ;;
    cache)
        check_cache_health
        exit_code=$?
        ;;
    queue)
        check_queue_health
        exit_code=$?
        ;;
    readiness)
        check_readiness
        exit_code=$?
        ;;
    liveness)
        check_liveness
        exit_code=$?
        ;;
    all)
        run_all_checks
        exit_code=$?
        ;;
    -h|--help|help)
        usage
        ;;
    *)
        echo "Unknown endpoint: $ENDPOINT" >&2
        usage
        ;;
esac

# Format output
case "$OUTPUT_FORMAT" in
    json)
        status="ok"
        [[ $exit_code -eq 1 ]] && status="warning"
        [[ $exit_code -eq 2 ]] && status="critical"
        output_json "$status" "Health check completed"
        ;;
    prometheus)
        output_prometheus
        ;;
    *)
        # Default text output already done in functions
        ;;
esac

exit $exit_code
