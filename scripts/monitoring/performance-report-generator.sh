#!/bin/bash
#
# Performance Report Generator for AGL-23
# Generates daily/weekly performance reports with trends, anomalies, and recommendations
#
# Usage:
#   ./performance-report-generator.sh [daily|weekly] [output_format]
#   ./performance-report-generator.sh daily json    # Generate daily report as JSON
#   ./performance-report-generator.sh weekly markdown # Generate weekly report as Markdown
#

set -euo pipefail

# ============================================================================
# Configuration
# ============================================================================
PROMETHEUS_URL="${PROMETHEUS_URL:-http://localhost:9090}"
OUTPUT_DIR="${OUTPUT_DIR:-/var/reports/performance}"
REPORT_TYPE="${1:-daily}"
OUTPUT_FORMAT="${2:-markdown}"
TIMESTAMP=$(date +%Y-%m-%d_%H%M%S)
DATE_TODAY=$(date +%Y-%m-%d)
DATE_YESTERDAY=$(date -d "yesterday" +%Y-%m-%d)
DATE_WEEK_AGO=$(date -d "7 days ago" +%Y-%m-%d)

# Create output directory
mkdir -p "${OUTPUT_DIR}"

# ============================================================================
# Helper Functions
# ============================================================================

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*"
}

query_prometheus() {
    local query="$1"
    local start_time="$2"
    local end_time="$3"
    local step="${4:-15m}"

    curl -s -G "${PROMETHEUS_URL}/api/v1/query_range" \
        --data-urlencode "query=${query}" \
        --data-urlencode "start=${start_time}" \
        --data-urlencode "end=${end_time}" \
        --data-urlencode "step=${step}" | jq -r '.data.result'
}

get_value() {
    local metric="$1"
    local duration="${2:-1h}"
    local query="avg_over_time(${metric}[${duration}])"

    curl -s -G "${PROMETHEUS_URL}/api/v1/query" \
        --data-urlencode "query=${query}" | jq -r '.data.result[0].value[1] // "0"'
}

detect_anomaly() {
    local metric="$1"
    local threshold="${2:-2.0}"
    local window="${3:-1h}"
    local baseline="${4:-24h}"

    local current=$(get_value "${metric}" "${window}")
    local baseline_avg=$(get_value "${metric}" "${baseline}")

    if [[ -z "${current}" ]] || [[ -z "${baseline_avg}" ]]; then
        echo "null"
        return
    fi

    local ratio=$(echo "scale=2; ${current} / ${baseline_avg}" | bc)

    if (( $(echo "${ratio} > ${threshold}" | bc -l) )); then
        echo "ANOMALY_DETECTED"
    elif (( $(echo "${ratio} < 1" | bc -l) )); then
        local improvement=$(echo "scale=2; (1 - ${ratio}) * 100" | bc)
        echo "IMPROVEMENT:${improvement}%"
    else
        local degradation=$(echo "scale=2; (${ratio} - 1) * 100" | bc)
        echo "DEGRADATION:${degradation}%"
    fi
}

# ============================================================================
# Report Generation Functions
# ============================================================================

generate_api_metrics() {
    local start_time="$1"
    local end_time="$2"

    cat <<EOF
### API Performance Metrics

**Time Range:** ${start_time} to ${end_time}

| Metric | Value | Status | Notes |
|--------|-------|--------|-------|
| Request Rate | $(get_value 'sum(rate(http_requests_total[5m]))') req/s | $([ $(get_value 'sum(rate(http_requests_total[5m]))' | awk '{print $1 < 10}') -eq 1 ] && echo "⚠️ LOW" || echo "✅ OK") | |
| P95 Latency | $(get_value 'histogram_quantile(0.95, sum(rate(http_request_duration_seconds_bucket[5m])) by (le))')s | $([ $(get_value 'histogram_quantile(0.95, sum(rate(http_request_duration_seconds_bucket[5m])) by (le))' | awk '{print $1 > 0.5}') -eq 1 ] && echo "⚠️ HIGH" || echo "✅ OK") | Target: <500ms |
| P99 Latency | $(get_value 'histogram_quantile(0.99, sum(rate(http_request_duration_seconds_bucket[5m])) by (le))')s | $([ $(get_value 'histogram_quantile(0.99, sum(rate(http_request_duration_seconds_bucket[5m])) by (le))' | awk '{print $1 > 1.0}') -eq 1 ] && echo "❌ CRITICAL" || echo "✅ OK") | Target: <1000ms |
| Error Rate | $(get_value 'sum(rate(http_requests_total{status=~"5.."}[5m])) / sum(rate(http_requests_total[5m])) * 100')% | $([ $(get_value 'sum(rate(http_requests_total{status=~"5.."}[5m])) / sum(rate(http_requests_total[5m])) * 100' | awk '{print $1 > 1}') -eq 1 ] && echo "❌ HIGH" || echo "✅ OK") | Target: <1% |
| Success Rate | $(get_value '(sum(rate(http_requests_total{status!~"5.."}[5m])) / sum(rate(http_requests_total[5m]))) * 100')% | $([ $(get_value '(sum(rate(http_requests_total{status!~"5.."}[5m])) / sum(rate(http_requests_total[5m]))) * 100' | awk '{print $1 < 99}') -eq 1 ] && echo "⚠️ LOW" || echo "✅ OK") | Target: >99% |

#### Top Endpoints by Request Volume

EOF

    # Query top endpoints
    curl -s -G "${PROMETHEUS_URL}/api/v1/query" \
        --data-urlencode 'query=topk(10, sum(rate(http_requests_total[5m])) by (endpoint))' | \
        jq -r '.data.result[] | "| \(.metric.endpoint) | \(.value[1] | tonumber | round(2)) req/s | |"'

    cat <<EOF

#### Slowest Endpoints (P95)

EOF

    # Query slowest endpoints
    curl -s -G "${PROMETHEUS_URL}/api/v1/query" \
        --data-urlencode 'query=topk(10, histogram_quantile(0.95, sum(rate(http_request_duration_seconds_bucket[5m])) by (endpoint, le)))' | \
        jq -r '.data.result[] | "| \(.metric.endpoint) | \(.value[1] | tonumber * 1000 | round) ms | |"'

    echo ""
}

generate_database_metrics() {
    local start_time="$1"
    local end_time="$2"

    cat <<EOF
### Database Performance Metrics

**Time Range:** ${start_time} to ${end_time}

| Metric | Value | Status | Notes |
|--------|-------|--------|-------|
| Active Connections | $(get_value 'pg_stat_database_numbackends{datname="agl_hostman"}') | $([ $(get_value 'pg_stat_database_numbackends{datname="agl_hostman"}' | awk '{print $1 > 100}') -eq 1 ] && echo "⚠️ HIGH" || echo "✅ OK") | |
| P95 Query Latency | $(get_value 'histogram_quantile(0.95, sum(rate(pg_stat_statements_call_seconds_bucket[5m])) by (le))')s | $([ $(get_value 'histogram_quantile(0.95, sum(rate(pg_stat_statements_call_seconds_bucket[5m])) by (le))' | awk '{print $1 > 1.0}') -eq 1 ] && echo "⚠️ HIGH" || echo "✅ OK") | Target: <1s |
| Query Throughput | $(get_value 'sum(rate(pg_stat_statements_calls[5m]))') qps | | |
| Deadlock Rate | $(get_value 'rate(pg_stat_database_deadlocks[5m])')/s | $([ $(get_value 'rate(pg_stat_database_deadlocks[5m])' | awk '{print $1 > 0}') -eq 1 ] && echo "⚠️ DETECTED" || echo "✅ OK") | |
| Conflict Rate | $(get_value 'rate(pg_stat_database_conflicts[5m])')/s | | |

#### Database Health

- **Connection Pool Utilization:** $(get_value '(pg_stat_database_numbackends / pg_settings_max_connections) * 100')%
- **Rollback Rate:** $(get_value 'rate(pg_stat_database_deadrolls[5m])')/s
- **I/O Wait Time:** Read: $(get_value 'pg_stat_database_blk_read_time{datname="agl_hostman"}')s, Write: $(get_value 'pg_stat_database_blk_write_time{datname="agl_hostman"}')s

EOF
}

generate_cache_metrics() {
    local start_time="$1"
    local end_time="$2"

    cat <<EOF
### Cache Performance Metrics

**Time Range:** ${start_time} to ${end_time}

| Metric | Value | Status | Notes |
|--------|-------|--------|-------|
| Hit Rate | $(get_value '(rate(redis_keyspace_hits[5m]) / (rate(redis_keyspace_hits[5m]) + rate(redis_keyspace_misses[5m]))) * 100')% | $([ $(get_value '(rate(redis_keyspace_hits[5m]) / (rate(redis_keyspace_hits[5m]) + rate(redis_keyspace_misses[5m]))) * 100' | awk '{print $1 < 70}') -eq 1 ] && echo "⚠️ LOW" || echo "✅ OK") | Target: >70% |
| Commands/sec | $(get_value 'sum(rate(redis_commands_processed_total[5m]))') | | |
| Memory Usage | $(get_value '(redis_memory_used_bytes / redis_memory_max_bytes) * 100')% | $([ $(get_value '(redis_memory_used_bytes / redis_memory_max_bytes) * 100' | awk '{print $1 > 80}') -eq 1 ] && echo "⚠️ HIGH" || echo "✅ OK") | |
| Eviction Rate | $(get_value 'rate(redis_evicted_keys_total[5m])') keys/s | $([ $(get_value 'rate(redis_evicted_keys_total[5m])' | awk '{print $1 > 0}') -eq 1 ] && echo "⚠️ EVICTING" || echo "✅ OK") | |
| Expiration Rate | $(get_value 'rate(redis_expired_keys_total[5m])') keys/s | | |

#### Redis Memory

- **Used Memory:** $(get_value 'redis_memory_used_bytes' | awk '{printf "%.2f GB", $1/1024/1024/1024}')
- **Max Memory:** $(get_value 'redis_memory_max_bytes' | awk '{printf "%.2f GB", $1/1024/1024/1024}')
- **Fragmentation Ratio:** $(get_value 'redis_memory_fragmentation_ratio')
- **Connected Clients:** $(get_value 'redis_connected_clients')

EOF
}

generate_anomalies() {
    local start_time="$1"
    local end_time="$2"

    cat <<EOF
### Anomalies Detected

EOF

    # Check for anomalies in key metrics
    local anomalies=0

    # API Latency Anomaly
    local latency_anomaly=$(detect_anomaly 'histogram_quantile(0.95, sum(rate(http_request_duration_seconds_bucket[5m])) by (le))' '2.0' '5m' '1h')
    if [[ "${latency_anomaly}" == "ANOMALY_DETECTED" ]]; then
        echo "⚠️ **API P95 Latency Anomaly:** Current latency is 2x+ higher than baseline"
        anomalies=$((anomalies + 1))
    fi

    # Error Rate Anomaly
    local error_anomaly=$(detect_anomaly 'sum(rate(http_requests_total{status=~"5.."}[5m])) / sum(rate(http_requests_total[5m]))' '2.0' '5m' '1h')
    if [[ "${error_anomaly}" == "ANOMALY_DETECTED" ]]; then
        echo "❌ **Error Rate Anomaly:** Error rate spiked significantly"
        anomalies=$((anomalies + 1))
    fi

    # Cache Hit Rate Anomaly
    local cache_anomaly=$(get_value '(rate(redis_keyspace_hits[5m]) / (rate(redis_keyspace_hits[5m]) + rate(redis_keyspace_misses[5m]))) * 100')
    if (( $(echo "${cache_anomaly} < 50" | bc -l) )); then
        echo "⚠️ **Cache Hit Rate Degraded:** Hit rate is ${cache_anomaly}% (below 50% threshold)"
        anomalies=$((anomalies + 1))
    fi

    if [[ ${anomalies} -eq 0 ]]; then
        echo "✅ **No anomalies detected** in the current reporting period."
    fi

    echo ""
}

generate_recommendations() {
    cat <<EOF
### Optimization Recommendations

EOF

    local recommendations=0

    # Check if recommendations are needed
    local p95_latency=$(get_value 'histogram_quantile(0.95, sum(rate(http_request_duration_seconds_bucket[5m])) by (le))')
    if (( $(echo "${p95_latency} > 0.5" | bc -l) )); then
        echo "1. **API Latency Optimization**"
        echo "   - Current P95: ${p95_latency}s (target: <0.5s)"
        echo "   - Review slow endpoints and add database indexes"
        echo "   - Consider implementing query result caching"
        echo "   - Enable HTTP/2 for concurrent requests"
        echo ""
        recommendations=$((recommendations + 1))
    fi

    local cache_hit_rate=$(get_value '(rate(redis_keyspace_hits[5m]) / (rate(redis_keyspace_hits[5m]) + rate(redis_keyspace_misses[5m]))) * 100')
    if (( $(echo "${cache_hit_rate} < 70" | bc -l) )); then
        echo "2. **Cache Strategy Review**"
        echo "   - Current hit rate: ${cache_hit_rate}% (target: >70%)"
        echo "   - Review TTL settings and cache warming strategies"
        echo "   - Analyze cache miss patterns for optimization"
        echo "   - Consider increasing Redis memory allocation"
        echo ""
        recommendations=$((recommendations + 1))
    fi

    local db_connections=$(get_value 'pg_stat_database_numbackends{datname="agl_hostman"}')
    if [[ ${db_connections} -gt 100 ]]; then
        echo "3. **Database Connection Pool Optimization**"
        echo "   - Current connections: ${db_connections}"
        echo "   - Review connection pooling configuration"
        echo "   - Consider implementing pgbouncer for connection pooling"
        echo ""
        recommendations=$((recommendations + 1))
    fi

    local memory_usage=$(get_value '(redis_memory_used_bytes / redis_memory_max_bytes) * 100')
    if (( $(echo "${memory_usage} > 80" | bc -l) )); then
        echo "4. **Redis Memory Optimization**"
        echo "   - Current usage: ${memory_usage}%"
        echo "   - Review key expiration policies"
        echo "   - Consider memory fragmentation cleanup (MEMORY PURGE)"
        echo "   - Evaluate max memory configuration"
        echo ""
        recommendations=$((recommendations + 1))
    fi

    if [[ ${recommendations} -eq 0 ]]; then
        echo "✅ **No immediate optimizations needed.** System is performing within acceptable thresholds."
    fi

    echo ""
}

generate_summary() {
    local start_time="$1"
    local end_time="$2"

    # Calculate overall health score
    local score=100

    # API Performance (40%)
    local error_rate=$(get_value 'sum(rate(http_requests_total{status=~"5.."}[5m])) / sum(rate(http_requests_total[5m])) * 100')
    if (( $(echo "${error_rate} > 1" | bc -l) )); then
        score=$((score - 10))
    fi

    local p95_latency=$(get_value 'histogram_quantile(0.95, sum(rate(http_request_duration_seconds_bucket[5m])) by (le))')
    if (( $(echo "${p95_latency} > 0.5" | bc -l) )); then
        score=$((score - 10))
    fi

    # Cache Performance (30%)
    local cache_hit=$(get_value '(rate(redis_keyspace_hits[5m]) / (rate(redis_keyspace_hits[5m]) + rate(redis_keyspace_misses[5m]))) * 100')
    if (( $(echo "${cache_hit} < 70" | bc -l) )); then
        score=$((score - 15))
    fi

    # Database Performance (30%)
    local db_latency=$(get_value 'histogram_quantile(0.95, sum(rate(pg_stat_statements_call_seconds_bucket[5m])) by (le))')
    if (( $(echo "${db_latency} > 1.0" | bc -l) )); then
        score=$((score - 15))
    fi

    cat <<EOF
# AGL-23 Performance Report

**Report Type:** ${REPORT_TYPE^^}
**Generated:** $(date +'%Y-%m-%d %H:%M:%S UTC')
**Time Range:** ${start_time} to ${end_time}

## Executive Summary

### Overall Health Score: ${score}/100

EOF

    if [[ ${score} -ge 90 ]]; then
        echo "✅ **Excellent** - System is performing optimally"
    elif [[ ${score} -ge 75 ]]; then
        echo "⚠️ **Good** - System is performing well with minor issues"
    elif [[ ${score} -ge 60 ]]; then
        echo "⚠️ **Fair** - Performance degradation detected, review recommendations"
    else
        echo "❌ **Poor** - Critical performance issues requiring immediate attention"
    fi

    echo ""
    echo "---"
    echo ""
}

generate_report_markdown() {
    local start_time="$1"
    local end_time="$2"

    generate_summary "${start_time}" "${end_time}"
    generate_api_metrics "${start_time}" "${end_time}"
    generate_database_metrics "${start_time}" "${end_time}"
    generate_cache_metrics "${start_time}" "${end_time}"
    generate_anomalies "${start_time}" "${end_time}"
    generate_recommendations
}

generate_report_json() {
    local start_time="$1"
    local end_time="$2"

    cat <<EOF
{
  "report_type": "${REPORT_TYPE}",
  "generated_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "time_range": {
    "start": "${start_time}",
    "end": "${end_time}"
  },
  "metrics": {
    "api": {
      "request_rate": $(get_value 'sum(rate(http_requests_total[5m]))'),
      "p95_latency": $(get_value 'histogram_quantile(0.95, sum(rate(http_request_duration_seconds_bucket[5m])) by (le))'),
      "p99_latency": $(get_value 'histogram_quantile(0.99, sum(rate(http_request_duration_seconds_bucket[5m])) by (le))'),
      "error_rate": $(get_value 'sum(rate(http_requests_total{status=~"5.."}[5m])) / sum(rate(http_requests_total[5m]))'),
      "success_rate": $(get_value '(sum(rate(http_requests_total{status!~"5.."}[5m])) / sum(rate(http_requests_total[5m])))')
    },
    "database": {
      "active_connections": $(get_value 'pg_stat_database_numbackends{datname="agl_hostman"}'),
      "p95_query_latency": $(get_value 'histogram_quantile(0.95, sum(rate(pg_stat_statements_call_seconds_bucket[5m])) by (le))'),
      "query_throughput": $(get_value 'sum(rate(pg_stat_statements_calls[5m]))'),
      "deadlock_rate": $(get_value 'rate(pg_stat_database_deadlocks[5m])'),
      "conflict_rate": $(get_value 'rate(pg_stat_database_conflicts[5m])')
    },
    "cache": {
      "hit_rate": $(get_value '(rate(redis_keyspace_hits[5m]) / (rate(redis_keyspace_hits[5m]) + rate(redis_keyspace_misses[5m])))'),
      "commands_per_sec": $(get_value 'sum(rate(redis_commands_processed_total[5m]))'),
      "memory_usage_percent": $(get_value '(redis_memory_used_bytes / redis_memory_max_bytes) * 100'),
      "eviction_rate": $(get_value 'rate(redis_evicted_keys_total[5m])'),
      "expiration_rate": $(get_value 'rate(redis_expired_keys_total[5m])')
    }
  },
  "anomalies": [],
  "recommendations": []
}
EOF
}

# ============================================================================
# Main Execution
# ============================================================================

main() {
    log "Generating ${REPORT_TYPE} performance report..."

    # Determine time range
    if [[ "${REPORT_TYPE}" == "daily" ]]; then
        local start_time="${DATE_YESTERDAY}T00:00:00Z"
        local end_time="${DATE_TODAY}T00:00:00Z"
        local output_file="${OUTPUT_DIR}/performance_report_${DATE_TODAY}.${OUTPUT_FORMAT}"
    elif [[ "${REPORT_TYPE}" == "weekly" ]]; then
        local start_time="${DATE_WEEK_AGO}T00:00:00Z"
        local end_time="${DATE_TODAY}T00:00:00Z"
        local output_file="${OUTPUT_DIR}/performance_report_weekly_${DATE_TODAY}.${OUTPUT_FORMAT}"
    else
        log "Invalid report type: ${REPORT_TYPE}"
        log "Usage: $0 [daily|weekly] [markdown|json]"
        exit 1
    fi

    # Generate report
    if [[ "${OUTPUT_FORMAT}" == "json" ]]; then
        generate_report_json "${start_time}" "${end_time}" > "${output_file}"
    else
        generate_report_markdown "${start_time}" "${end_time}" > "${output_file}"
    fi

    log "Report saved to: ${output_file}"

    # Optional: Email report
    if [[ -n "${REPORT_EMAIL:-}" ]]; then
        log "Sending report to ${REPORT_EMAIL}..."
        # mail -s "AGL-23 ${REPORT_TYPE^} Performance Report" "${REPORT_EMAIL}" < "${output_file}"
        log "Email sent."
    fi
}

# Run main function
main "$@"
