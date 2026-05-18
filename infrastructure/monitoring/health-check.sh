#!/bin/bash
# =============================================================================
# AGL Hostman Health Check Script
# Checks all critical services and reports status
# =============================================================================

set -euo pipefail

# Configuration
ALERT_WEBHOOK_URL="${ALERT_WEBHOOK_URL:-}"
SLACK_WEBHOOK_URL="${SLACK_WEBHOOK_URL:-}"
LOG_FILE="/var/log/agl-hostman/health-check.log"
STATE_FILE="/var/lib/agl-hostman/health-state.json"

# Service endpoints
APP_HEALTH_URL="${APP_HEALTH_URL:-http://localhost:8080/health}"
API_HEALTH_URL="${API_HEALTH_URL:-http://localhost:8080/api/health}"
MYSQL_HOST="${MYSQL_HOST:-localhost}"
MYSQL_PORT="${MYSQL_PORT:-3306}"
REDIS_HOST="${REDIS_HOST:-localhost}"
REDIS_PORT="${REDIS_PORT:-6379}"
HAPROXY_STATS_URL="${HAPROXY_STATS_URL:-http://localhost:8404/stats}"

# Thresholds
MAX_RESPONSE_TIME=5
MAX_MYSQL_LATENCY=100
MAX_REDIS_LATENCY=50

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging function
log() {
    local level=$1
    shift
    local message="$@"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $message" | tee -a "$LOG_FILE"
}

# Send alert
send_alert() {
    local severity=$1
    local service=$2
    local message=$3

    local payload=$(cat <<EOF
{
  "severity": "$severity",
  "service": "$service",
  "message": "$message",
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "hostname": "$(hostname)"
}
EOF
)

    # Send to webhook
    if [[ -n "$ALERT_WEBHOOK_URL" ]]; then
        curl -s -X POST "$ALERT_WEBHOOK_URL" \
            -H "Content-Type: application/json" \
            -d "$payload" || true
    fi

    # Send to Slack
    if [[ -n "$SLACK_WEBHOOK_URL" ]]; then
        local color="#36a64f"
        [[ "$severity" == "critical" ]] && color="#dc3545"
        [[ "$severity" == "warning" ]] && color="#ffc107"

        curl -s -X POST "$SLACK_WEBHOOK_URL" \
            -H "Content-Type: application/json" \
            -d "$(cat <<EOF
{
  "attachments": [
    {
      "color": "$color",
      "title": "[$severity] $service",
      "text": "$message",
      "fields": [
        {
          "title": "Hostname",
          "value": "$(hostname)",
          "short": true
        },
        {
          "title": "Timestamp",
          "value": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
          "short": true
        }
      ]
    }
  ]
}
EOF
)" || true
    fi
}

# Check HTTP endpoint
check_http() {
    local name=$1
    local url=$2
    local expected_code=${3:-200}

    log "INFO" "Checking $name at $url"

    local start=$(date +%s%N)
    local response=$(curl -s -o /dev/null -w "%{http_code}" --max-time "$MAX_RESPONSE_TIME" "$url" || echo "000")
    local end=$(date +%s%N)
    local duration=$(( (end - start) / 1000000 ))

    if [[ "$response" == "$expected_code" ]]; then
        log "INFO" "$name is healthy (${duration}ms)"
        echo "healthy"
        return 0
    else
        log "ERROR" "$name is unhealthy (HTTP $response, ${duration}ms)"
        echo "unhealthy"
        return 1
    fi
}

# Check MySQL
check_mysql() {
    log "INFO" "Checking MySQL at $MYSQL_HOST:$MYSQL_PORT"

    local output
    output=$(mysqladmin -h "$MYSQL_HOST" -P "$MYSQL_PORT" -u health_check ping 2>&1) || true

    if [[ "$output" =~ "mysqld is alive" ]]; then
        log "INFO" "MySQL is healthy"
        echo "healthy"
        return 0
    else
        log "ERROR" "MySQL is unhealthy: $output"
        echo "unhealthy"
        return 1
    fi
}

# Check Redis
check_redis() {
    log "INFO" "Checking Redis at $REDIS_HOST:$REDIS_PORT"

    local output
    output=$(redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" ping 2>&1) || true

    if [[ "$output" == "PONG" ]]; then
        log "INFO" "Redis is healthy"
        echo "healthy"
        return 0
    else
        log "ERROR" "Redis is unhealthy: $output"
        echo "unhealthy"
        return 1
    fi
}

# Check HAProxy
check_haproxy() {
    log "INFO" "Checking HAProxy stats"

    local response
    response=$(curl -s "$HAPROXY_STATS_URL" -u "admin:${HAPROXY_STATS_PASSWORD}" 2>&1) || true

    if [[ -n "$response" ]]; then
        log "INFO" "HAProxy is healthy"
        echo "healthy"
        return 0
    else
        log "ERROR" "HAProxy is unhealthy"
        echo "unhealthy"
        return 1
    fi
}

# Check disk space
check_disk() {
    local threshold=${1:-80}

    log "INFO" "Checking disk space (threshold: ${threshold}%)"

    local usage
    usage=$(df -h / | awk 'NR==2 {print $5}' | sed 's/%//')

    if [[ $usage -lt $threshold ]]; then
        log "INFO" "Disk space is OK (${usage}%)"
        echo "healthy"
        return 0
    else
        log "ERROR" "Disk space is critical (${usage}%)"
        echo "unhealthy"
        return 1
    fi
}

# Check memory
check_memory() {
    local threshold=${1:-90}

    log "INFO" "Checking memory usage (threshold: ${threshold}%)"

    local usage
    usage=$(free | awk 'NR==2 {printf "%.0f", ($3/$2)*100}')

    if [[ $usage -lt $threshold ]]; then
        log "INFO" "Memory usage is OK (${usage}%)"
        echo "healthy"
        return 0
    else
        log "ERROR" "Memory usage is critical (${usage}%)"
        echo "unhealthy"
        return 1
    fi
}

# Main health check function
run_health_checks() {
    local overall_status="healthy"

    echo "{"
    echo "  \"timestamp\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\","
    echo "  \"hostname\": \"$(hostname)\","
    echo "  \"checks\": {"

    # Application
    printf "    \"app\": \"%s\"" "$(check_http "Application" "$APP_HEALTH_URL")"
    [[ $? -ne 0 ]] && overall_status="unhealthy"
    echo ","

    # API
    printf "    \"api\": \"%s\"" "$(check_http "API" "$API_HEALTH_URL")"
    [[ $? -ne 0 ]] && overall_status="unhealthy"
    echo ","

    # MySQL
    printf "    \"mysql\": \"%s\"" "$(check_mysql)"
    [[ $? -ne 0 ]] && overall_status="unhealthy"
    echo ","

    # Redis
    printf "    \"redis\": \"%s\"" "$(check_redis)"
    [[ $? -ne 0 ]] && overall_status="unhealthy"
    echo ","

    # HAProxy
    printf "    \"haproxy\": \"%s\"" "$(check_haproxy)"
    [[ $? -ne 0 ]] && overall_status="unhealthy"
    echo ","

    # Disk
    printf "    \"disk\": \"%s\"" "$(check_disk 80)"
    [[ $? -ne 0 ]] && overall_status="unhealthy"
    echo ","

    # Memory
    printf "    \"memory\": \"%s\"" "$(check_memory 90)"
    [[ $? -ne 0 ]] && overall_status="unhealthy"
    echo

    echo "  },"
    echo "  \"overall_status\": \"$overall_status\""
    echo "}"

    # Save state
    mkdir -p "$(dirname "$STATE_FILE")"
    local state=$(cat <<EOF
{
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "hostname": "$(hostname)",
  "overall_status": "$overall_status"
}
EOF
)
    echo "$state" > "$STATE_FILE"

    # Send alert if unhealthy
    if [[ "$overall_status" == "unhealthy" ]]; then
        send_alert "critical" "Health Check" "One or more services are unhealthy. Check logs for details."
    fi

    return 0
}

# Export status for monitoring
export_prometheus() {
    local status_file="/var/lib/node_exporter/textfile_collector/agl_hostman_health.prom"

    mkdir -p "$(dirname "$status_file")"

    cat > "$status_file" <<EOF
# HELP agl_hostman_health_status Overall health status (1=healthy, 0=unhealthy)
# TYPE agl_hostman_health_status gauge
agl_hostman_health_status{host="$(hostname)"} $([ "$overall_status" == "healthy" ] && echo 1 || echo 0)
EOF
}

# Main execution
main() {
    mkdir -p "$(dirname "$LOG_FILE")"
    log "INFO" "Starting health check"

    run_health_checks
    export_prometheus

    log "INFO" "Health check completed with status: $overall_status"
}

# Run main function
main "$@"
