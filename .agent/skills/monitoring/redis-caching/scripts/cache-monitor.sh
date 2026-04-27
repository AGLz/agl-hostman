#!/usr/bin/env bash
##
# Redis Cache Monitoring Script
#
# Monitors Redis performance, memory usage, and hit rates
# Alerts on potential issues
#
# Usage: ./cache-monitor.sh [options]
#   --host=HOST        Redis host (default: 127.0.0.1)
#   --port=PORT        Redis port (default: 6379)
#   --password=PASS    Redis password
#   --db=DB            Database number (default: 0)
#   --alert-threshold  Hit rate threshold for alert (default: 80)
##

set -euo pipefail

# Configuration
REDIS_HOST="${REDIS_HOST:-127.0.0.1}"
REDIS_PORT="${REDIS_PORT:-6379}"
REDIS_PASSWORD="${REDIS_PASSWORD:-}"
REDIS_DB="${REDIS_DB:-0}"
ALERT_THRESHOLD="${ALERT_THRESHOLD:-80}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_detail() { echo -e "${BLUE}[REDIS]${NC} $1"; }

# Parse arguments
for arg in "$@"; do
    case $arg in
        --host=*)        REDIS_HOST="${arg#*=}" ;;
        --port=*)        REDIS_PORT="${arg#*=}" ;;
        --password=*)    REDIS_PASSWORD="${arg#*=}" ;;
        --db=*)          REDIS_DB="${arg#*=}" ;;
        --alert-threshold=*) ALERT_THRESHOLD="${arg#*=}" ;;
    esac
done

# Redis CLI command
redis_cmd() {
    if [[ -n "$REDIS_PASSWORD" ]]; then
        redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" -a "$REDIS_PASSWORD" -n "$REDIS_DB" "$@"
    else
        redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" -n "$REDIS_DB" "$@"
    fi
}

# Get Redis INFO
get_info() {
    redis_cmd INFO "$1"
}

# Format bytes
format_bytes() {
    local bytes=$1
    if (( bytes < 1024 )); then
        echo "${bytes}B"
    elif (( bytes < 1024*1024 )); then
        echo "$((bytes / 1024))KB"
    elif (( bytes < 1024*1024*1024 )); then
        echo "$((bytes / (1024*1024)))MB"
    else
        echo "$((bytes / (1024*1024*1024)))GB"
    fi
}

# Check Redis connectivity
check_connectivity() {
    log_info "Checking Redis connectivity..."

    local pong
    pong=$(redis_cmd PING)

    if [[ "$pong" == "PONG" ]]; then
        log_info "Redis connection: OK"
        return 0
    else
        log_error "Redis connection: FAILED"
        return 1
    fi
}

# Get memory usage
check_memory() {
    log_info "Memory Usage:"

    local used_memory max_memory used_memory_peak used_memory_rss

    used_memory=$(get_info memory | grep "used_memory:" | cut -d: -f2 | tr -d '\r')
    max_memory=$(get_info memory | grep "maxmemory:" | cut -d: -f2 | tr -d '\r')
    used_memory_peak=$(get_info memory | grep "used_memory_peak:" | cut -d: -f2 | tr -d '\r')
    used_memory_rss=$(get_info memory | grep "used_memory_rss:" | cut -d: -f2 | tr -d '\r')

    log_detail "Used: $(format_bytes $used_memory)"
    log_detail "RSS: $(format_bytes $used_memory_rss)"
    log_detail "Peak: $(format_bytes $used_memory_peak)"

    if [[ "$max_memory" != "0" ]]; then
        local usage_pct
        usage_pct=$((used_memory * 100 / max_memory))
        log_detail "Max: $(format_bytes $max_memory) ($usage_pct%)"

        if (( usage_pct > 90 )); then
            log_error "Memory usage above 90%!"
        elif (( usage_pct > 80 )); then
            log_warn "Memory usage above 80%"
        fi
    fi
}

# Get hit rate
check_hit_rate() {
    log_info "Cache Performance:"

    local keyspace_hits keyspace_misses hit_rate

    keyspace_hits=$(get_info stats | grep "keyspace_hits:" | cut -d: -f2 | tr -d '\r')
    keyspace_misses=$(get_info stats | grep "keyspace_misses:" | cut -d: -f2 | tr -d '\r')

    local total=$((keyspace_hits + keyspace_misses))

    if (( total > 0 )); then
        hit_rate=$((keyspace_hits * 100 / total))
    else
        hit_rate=0
    fi

    log_detail "Hits: $keyspace_hits"
    log_detail "Misses: $keyspace_misses"
    log_detail "Hit Rate: $hit_rate%"

    if (( hit_rate < ALERT_THRESHOLD )); then
        log_error "Hit rate below $ALERT_THRESHOLD%!"
    fi
}

# Get key count
check_key_count() {
    log_info "Key Count:"

    local db_stats
    db_stats=$(get_info keyspace | grep "^db$REDIS_DB:" || echo "")

    if [[ -n "$db_stats" ]]; then
        local keys
        keys=$(echo "$db_stats" | cut -d: -f2 | cut -d, -f1 | cut -d= -f2)
        log_detail "DB $REDIS_DB: $keys keys"
    else
        log_detail "DB $REDIS_DB: 0 keys"
    fi
}

# Get connection count
check_connections() {
    log_info "Connections:"

    local connected_clients
    connected_clients=$(get_info clients | grep "connected_clients:" | cut -d: -f2 | tr -d '\r')

    log_detail "Connected clients: $connected_clients"
}

# Get slow log
check_slow_log() {
    log_info "Slow Log:"

    local slow_log_len
    slow_log_len=$(get_info commandstats | grep "slowlog_length:" | cut -d: -f2 | tr -d '\r' || echo "0")

    if (( slow_log_len > 0 )); then
        log_warn "$slow_log_len slow commands logged"

        # Show recent slow commands
        redis_cmd SLOWLOG GET 5 | while read -r line; do
            log_detail "$line"
        done
    else
        log_detail "No slow commands"
    fi
}

# Get expired keys
check_expiration() {
    log_info "Expiration:"

    local expired_keys evicted_keys
    expired_keys=$(get_info stats | grep "expired_keys:" | cut -d: -f2 | tr -d '\r')
    evicted_keys=$(get_info stats | grep "evicted_keys:" | cut -d: -f2 | tr -d '\r')

    log_detail "Expired: $expired_keys"
    log_detail "Evicted: $evicted_keys"

    if (( evicted_keys > 0 )); then
        log_warn "Keys were evicted (maxmemory reached?)"
    fi
}

# Main monitoring logic
main() {
    echo "======================================"
    echo "Redis Cache Monitor"
    echo "======================================"
    echo "Host: $REDIS_HOST:$REDIS_PORT"
    echo "Database: $REDIS_DB"
    echo ""

    check_connectivity || exit 1

    echo ""
    check_memory

    echo ""
    check_hit_rate

    echo ""
    check_key_count

    echo ""
    check_connections

    echo ""
    check_slow_log

    echo ""
    check_expiration

    echo ""
    echo "======================================"
    echo "Monitoring complete"
    echo "======================================"
}

main
