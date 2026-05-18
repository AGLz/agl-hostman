#!/bin/bash
# =============================================================================
# Redis Health Monitoring Script for AGL Hostman
# =============================================================================
# Monitors Redis cluster health, replication status, and sends alerts
#
# Usage:
#   ./redis-health-monitor.sh [monitor|check|alert]
#
# Environment Variables:
#   REDIS_PASSWORD           Redis authentication password
#   SENTINEL_PORT           Sentinel port (default: 26379)
#   MASTER_NAME             Sentinel master name (default: aglmaster)
#   ALERT_WEBHOOK           Slack/webhook URL for alerts
#   ALERT_EMAIL            Email address for alerts
#   CHECK_INTERVAL          Check interval in seconds (default: 30)
#
# Author: Database High Availability Skill
# Version: 2.0.0

set -euo pipefail

# =============================================================================
# Configuration
# =============================================================================
REDIS_PASSWORD="${REDIS_PASSWORD:-}"
SENTINEL_PORT="${SENTINEL_PORT:-26379}"
MASTER_NAME="${MASTER_NAME:-aglmaster}"
CHECK_INTERVAL="${CHECK_INTERVAL:-30}"
ALERT_WEBHOOK="${ALERT_WEBHOOK:-}"
ALERT_EMAIL="${ALERT_EMAIL:-}"

# State tracking
STATE_DIR="/var/lib/redis-monitor"
STATE_FILE="$STATE_DIR/health-state.json"
LOG_FILE="/var/log/redis-health-monitor.log"

# Monitoring thresholds
WARN_REPLICATION_LAG=5
CRIT_REPLICATION_LAG=30
WARN_MEMORY_PERCENT=80
CRIT_MEMORY_PERCENT=95
WARN_CONNECTIONS=8000
CRIT_CONNECTIONS=9500

# =============================================================================
# Logging Functions
# =============================================================================
log() {
    local level=$1
    shift
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $@" | tee -a "$LOG_FILE"
}

log_info() { log "INFO" "$@"; }
log_warn() { log "WARN" "$@"; }
log_error() { log "ERROR" "$@"; }
log_crit() { log "CRITICAL" "$@"; }

# =============================================================================
# Alert Functions
# =============================================================================
send_alert() {
    local severity=$1
    local message=$2
    local details=${3:-}

    log "ALERT" "[$severity] $message"

    # Send webhook notification
    if [[ -n "$ALERT_WEBHOOK" ]]; then
        local color="#36a64f"
        [[ "$severity" == "CRITICAL" ]] && color="#dc3545"
        [[ "$severity" == "WARNING" ]] && color="#ffc107"

        local payload=$(cat <<EOF
{
    "attachments": [{
        "color": "$color",
        "title": "[$severity] Redis Cluster Alert",
        "text": "$message",
        "fields": [
            {"title": "Hostname", "value": "$(hostname)", "short": true},
            {"title": "Timestamp", "value": "$(date -u +%Y-%m-%dT%H:%M:%SZ)", "short": true},
            {"title": "Master", "value": "$MASTER_NAME", "short": true},
            {"title": "Severity", "value": "$severity", "short": true}
        ]
    }]
}
EOF
)
        curl -s -X POST "$ALERT_WEBHOOK" \
            -H "Content-Type: application/json" \
            -d "$payload" || true
    fi

    # Send email notification
    if [[ -n "$ALERT_EMAIL" ]]; then
        echo "$details" | mail -s "[$severity] Redis Cluster Alert: $message" "$ALERT_EMAIL" || true
    fi
}

# =============================================================================
# Redis CLI Helper
# =============================================================================
redis_cli() {
    local host=${1:-localhost}
    local port=${2:-6379}
    local password=$3

    if [[ -n "$password" ]]; then
        redis-cli -h "$host" -p "$port" -a "$password" --no-auth-warning 2>/dev/null
    else
        redis-cli -h "$host" -p "$port" 2>/dev/null
    fi
}

# =============================================================================
# Sentinel Functions
# =============================================================================
get_master_address() {
    local sentinel_host=${1:-localhost}
    local output

    output=$(redis_cli "$sentinel_host" "$SENTINEL_PORT" "" \
        SENTINEL get-master-addr-by-name "$MASTER_NAME" 2>/dev/null) || return 1

    echo "$output"
    return 0
}

get_master_info() {
    local sentinel_host=${1:-localhost}
    redis_cli "$sentinel_host" "$SENTINEL_PORT" "" \
        SENTINEL master "$MASTER_NAME" 2>/dev/null
}

get_slave_info() {
    local sentinel_host=${1:-localhost}
    redis_cli "$sentinel_host" "$SENTINEL_PORT" "" \
        SENTINEL slaves "$MASTER_NAME" 2>/dev/null
}

get_sentinel_info() {
    local sentinel_host=${1:-localhost}
    redis_cli "$sentinel_host" "$SENTINEL_PORT" "" \
        SENTINEL sentinels "$MASTER_NAME" 2>/dev/null
}

check_quorum() {
    local sentinel_host=${1:-localhost}
    local info

    info=$(get_master_info "$sentinel_host") || return 1

    # Extract quorum and available sentinels
    local quorum=$(echo "$info" | grep -oP 'quorum=\K\d+' || echo "0")
    local num_sentinels=$(get_sentinel_info "$sentinel_host" | wc -l || echo "0")

    if [[ $num_sentinels -lt $quorum ]]; then
        return 1
    fi

    return 0
}

# =============================================================================
# Redis Health Checks
# =============================================================================
check_redis_ping() {
    local host=$1
    local port=$2
    local password=$3

    local pong
    pong=$(redis_cli "$host" "$port" "$password" PING 2>/dev/null) || return 1

    [[ "$pong" == "PONG" ]]
}

check_redis_info() {
    local host=$1
    local port=$2
    local password=$3

    redis_cli "$host" "$port" "$password" INFO 2>/dev/null
}

check_redis_memory() {
    local info=$1

    local used_mem=$(echo "$info" | grep -oP '^used_memory:\K\d+' || echo "0")
    local max_mem=$(echo "$info" | grep -oP '^maxmemory:\K\d+' || echo "0")

    if [[ $max_mem -eq 0 ]]; then
        echo "0"
        return
    fi

    local percent=$((used_mem * 100 / max_mem))
    echo "$percent"
}

check_redis_connections() {
    local info=$1

    echo "$info" | grep -oP '^connected_clients:\K\d+' || echo "0"
}

check_replication_lag() {
    local sentinel_host=${1:-localhost}
    local slaves

    slaves=$(get_slave_info "$sentinel_host") || return 1

    local max_lag=0

    while IFS= read -r line; do
        if [[ "$line" =~ "lag=" ]]; then
            local lag
            lag=$(echo "$line" | grep -oP 'lag=\K\d+' || echo "0")
            [[ $lag -gt $max_lag ]] && max_lag=$lag
        fi
    done <<< "$slaves"

    echo "$max_lag"
}

check_replication_status() {
    local info=$1

    local role=$(echo "$info" | grep -oP '^role:\K\w+' || echo "unknown")
    local connected_slaves=$(echo "$info" | grep -oP '^connected_slaves:\K\d+' || echo "0")
    local master_link_status=$(echo "$info" | grep -oP '^master_link_status:\K\w+' || echo "unknown")

    echo "$role|$connected_slaves|$master_link_status"
}

# =============================================================================
# State Management
# =============================================================================
load_state() {
    if [[ -f "$STATE_FILE" ]]; then
        cat "$STATE_FILE"
    else
        echo '{"last_master":"","alerts_sent":[]}'
    fi
}

save_state() {
    local new_state=$1
    mkdir -p "$STATE_DIR"
    echo "$new_state" > "$STATE_FILE"
}

# =============================================================================
# Health Check Functions
# =============================================================================
health_check_master() {
    local master_host=$1
    local master_port=$2

    if ! check_redis_ping "$master_host" "$master_port" "$REDIS_PASSWORD"; then
        return 1
    fi

    local info
    info=$(check_redis_info "$master_host" "$master_port" "$REDIS_PASSWORD") || return 1

    local role
    role=$(echo "$info" | grep -oP '^role:\K\w+' || echo "unknown")

    if [[ "$role" != "master" ]]; then
        return 1
    fi

    return 0
}

health_check_slaves() {
    local sentinel_host=${1:-localhost}
    local slaves

    slaves=$(get_slave_info "$sentinel_host") || return 1

    local healthy_slaves=0
    local total_slaves=0

    while IFS= read -r line; do
        if [[ "$line" =~ "name=" ]]; then
            ((total_slaves++))

            local flags
            flags=$(echo "$line" | grep -oP 'flags=\K[^,]+' || echo "")

            if [[ "$flags" =~ "disconnected" ]]; then
                log_warn "Slave disconnected: $line"
            else
                ((healthy_slaves++))
            fi
        fi
    done <<< "$slaves"

    echo "$healthy_slaves|$total_slaves"
}

health_check_sentinels() {
    local sentinel_host=${1:-localhost}
    local sentinels

    sentinels=$(get_sentinel_info "$sentinel_host") || return 1

    local healthy_sentinels=0
    local total_sentinels=0

    while IFS= read -r line; do
        if [[ "$line" =~ "name=" ]]; then
            ((total_sentinels++))

            local flags
            flags=$(echo "$line" | grep -oP 'flags=\K[^,]+' || echo "")

            if [[ "$flags" =~ "disconnected" ]]; then
                log_warn "Sentinel disconnected: $line"
            else
                ((healthy_sentinels++))
            fi
        fi
    done <<< "$sentinels"

    echo "$healthy_sentinels|$total_sentinels"
}

# =============================================================================
# Comprehensive Health Check
# =============================================================================
comprehensive_check() {
    local sentinel_host=${1:-localhost}
    local issues=()

    # Check master
    local master_addr
    master_addr=$(get_master_address "$sentinel_host")

    if [[ -z "$master_addr" ]]; then
        issues+=("No master available")
        send_alert "CRITICAL" "No Redis master available" "Sentinel cannot find any master instance"
    else
        local master_host
        local master_port
        master_host=$(echo "$master_addr" | head -n1)
        master_port=$(echo "$master_addr" | sed -n '2p')

        if ! health_check_master "$master_host" "$master_port"; then
            issues+=("Master health check failed")
        fi

        local info
        info=$(check_redis_info "$master_host" "$master_port" "$REDIS_PASSWORD")

        # Check memory
        local mem_percent
        mem_percent=$(check_redis_memory "$info")
        if [[ $mem_percent -ge $CRIT_MEMORY_PERCENT ]]; then
            issues+=("Critical memory usage: ${mem_percent}%")
            send_alert "CRITICAL" "Redis master memory at ${mem_percent}%"
        elif [[ $mem_percent -ge $WARN_MEMORY_PERCENT ]]; then
            issues+=("High memory usage: ${mem_percent}%")
            send_alert "WARNING" "Redis master memory at ${mem_percent}%"
        fi

        # Check connections
        local connections
        connections=$(check_redis_connections "$info")
        if [[ $connections -ge $CRIT_CONNECTIONS ]]; then
            issues+=("Critical connection count: $connections")
            send_alert "CRITICAL" "Redis master has $connections connections"
        elif [[ $connections -ge $WARN_CONNECTIONS ]]; then
            issues+=("High connection count: $connections")
            send_alert "WARNING" "Redis master has $connections connections"
        fi
    fi

    # Check replication lag
    local lag
    lag=$(check_replication_lag "$sentinel_host")
    if [[ $lag -ge $CRIT_REPLICATION_LAG ]]; then
        issues+=("Critical replication lag: ${lag}s")
        send_alert "CRITICAL" "Redis replication lag is ${lag}s"
    elif [[ $lag -ge $WARN_REPLICATION_LAG && $lag -gt 0 ]]; then
        issues+=("High replication lag: ${lag}s")
        send_alert "WARNING" "Redis replication lag is ${lag}s"
    fi

    # Check slaves
    local slave_status
    slave_status=$(health_check_slaves "$sentinel_host")
    local healthy_slaves
    local total_slaves
    IFS='|' read -r healthy_slaves total_slaves <<< "$slave_status"

    if [[ $healthy_slaves -lt $total_slaves ]]; then
        issues+=("Only $healthy_slaves/$total_slaves slaves healthy")
        send_alert "WARNING" "Only $healthy_slaves/$total_slaves Redis slaves healthy"
    fi

    # Check sentinels
    local sentinel_status
    sentinel_status=$(health_check_sentinels "$sentinel_host")
    local healthy_sentinels
    local total_sentinels
    IFS='|' read -r healthy_sentinels total_sentinels <<< "$sentinel_status"

    if [[ $healthy_sentinels -lt 3 ]]; then
        issues+=("Only $healthy_sentinels/3 sentinels healthy")
        send_alert "WARNING" "Only $healthy_sentinels/3 Redis Sentinels healthy"
    fi

    # Check quorum
    if ! check_quorum "$sentinel_host"; then
        issues+=("Sentinel quorum not met")
        send_alert "CRITICAL" "Redis Sentinel quorum not met - failover may not be possible"
    fi

    # Return health status
    if [[ ${#issues[@]} -eq 0 ]]; then
        return 0
    else
        return 1
    fi
}

# =============================================================================
# JSON Output
# =============================================================================
json_status() {
    local sentinel_host=${1:-localhost}
    local master_addr master_host master_port
    local mem_percent connections lag
    local slave_status sentinel_status

    master_addr=$(get_master_address "$sentinel_host")
    master_host=$(echo "$master_addr" | head -n1)
    master_port=$(echo "$master_addr" | sed -n '2p')

    local info
    info=$(check_redis_info "$master_host" "$master_port" "$REDIS_PASSWORD")

    mem_percent=$(check_redis_memory "$info")
    connections=$(check_redis_connections "$info")
    lag=$(check_replication_lag "$sentinel_host")

    IFS='|' read -r healthy_slaves total_slaves <<< "$(health_check_slaves "$sentinel_host")"
    IFS='|' read -r healthy_sentinels total_sentinels <<< "$(health_check_sentinels "$sentinel_host")"

    comprehensive_check "$sentinel_host"
    local health=$?

    cat <<EOF
{
    "healthy": $( [[ $health -eq 0 ]] && echo "true" || echo "false" ),
    "master": {
        "host": "$master_host",
        "port": "$master_port",
        "memory_percent": $mem_percent,
        "connections": $connections
    },
    "replication": {
        "lag_seconds": $lag,
        "healthy_slaves": $healthy_slaves,
        "total_slaves": $total_slaves
    },
    "sentinels": {
        "healthy": $healthy_sentinels,
        "total": $total_sentinels
    },
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF
}

# =============================================================================
# Continuous Monitoring
# =============================================================================
monitor_mode() {
    local sentinel_host=${1:-localhost}

    log_info "Starting Redis health monitoring (interval: ${CHECK_INTERVAL}s)..."

    while true; do
        if ! comprehensive_check "$sentinel_host"; then
            log_warn "Health check completed with issues"
        else
            log_info "Health check passed"
        fi

        sleep "$CHECK_INTERVAL"
    done
}

# =============================================================================
# Main
# =============================================================================
main() {
    local command=${1:-monitor}
    local sentinel_host=${2:-localhost}

    mkdir -p "$(dirname "$LOG_FILE")"
    mkdir -p "$STATE_DIR"

    case "$command" in
        monitor)
            monitor_mode "$sentinel_host"
            ;;
        check)
            comprehensive_check "$sentinel_host"
            ;;
        json)
            json_status "$sentinel_host"
            ;;
        *)
            echo "Usage: $0 {monitor|check|json} [sentinel_host]"
            exit 1
            ;;
    esac
}

main "$@"
