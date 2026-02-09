#!/bin/bash
# =============================================================================
# Redis Sentinel Failover Monitor Script for AGL Hostman
# Monitors Redis Sentinel and handles failover events
# =============================================================================

set -euo pipefail

# Configuration
SENTINEL_HOST="${SENTINEL_HOST:-localhost}"
SENTINEL_PORT="${SENTINEL_PORT:-26379}"
SENTINEL_MASTER_NAME="${SENTINEL_MASTER_NAME:-mymaster}"
REDIS_PASSWORD_FILE="${REDIS_PASSWORD_FILE:-/run/secrets/redis-password}"

# Monitoring settings
CHECK_INTERVAL=10
MAX_FAILOVER_TIME=30

# State file
STATE_DIR="/var/lib/redis-failover"
STATE_FILE="$STATE_DIR/failover-state.json"

# Logging
LOG_FILE="/var/log/redis-sentinel-failover.log"

# Alert settings
ALERT_EMAIL="${ALERT_EMAIL:-}"
SLACK_WEBHOOK="${SLACK_WEBHOOK:-}"

# =============================================================================
# Logging Functions
# =============================================================================
log() {
    local level=$1
    shift
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $@" | tee -a "$LOG_FILE"
}

send_alert() {
    local severity=$1
    local message=$2

    log "ALERT" "[$severity] $message"

    # Send Slack notification
    if [[ -n "$SLACK_WEBHOOK" ]]; then
        local color="#36a64f"
        [[ "$severity" == "CRITICAL" ]] && color="#dc3545"
        [[ "$severity" == "WARNING" ]] && color="#ffc107"

        curl -s -X POST "$SLACK_WEBHOOK" \
            -H "Content-Type: application/json" \
            -d "{
                \"attachments\": [{
                    \"color\": \"$color\",
                    \"title\": \"[$severity] Redis Sentinel Failover\",
                    \"text\": \"$message\",
                    \"fields\": [{
                        \"title\": \"Hostname\",
                        \"value\": \"$(hostname)\",
                        \"short\": true
                    }, {
                        \"title\": \"Timestamp\",
                        \"value\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",
                        \"short\": true
                    }]
                }]
            }" || true
    fi
}

# =============================================================================
# Redis Functions
# =============================================================================
redis_cli() {
    local password
    if [[ -f "$REDIS_PASSWORD_FILE" ]]; then
        password=$(cat "$REDIS_PASSWORD_FILE")
        redis-cli -h "$SENTINEL_HOST" -p "$SENTINEL_PORT" -a "$password" "$@"
    else
        redis-cli -h "$SENTINEL_HOST" -p "$SENTINEL_PORT" "$@"
    fi
}

# =============================================================================
# State Management
# =============================================================================
save_state() {
    local role=$1
    local master_ip=$2

    mkdir -p "$STATE_DIR"
    cat > "$STATE_FILE" <<EOF
{
  "role": "$role",
  "master_ip": "$master_ip",
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "hostname": "$(hostname)"
}
EOF
}

load_state() {
    if [[ -f "$STATE_FILE" ]]; then
        cat "$STATE_FILE"
    else
        echo '{"role":"unknown","master_ip":null}'
    fi
}

# =============================================================================
# Sentinel Functions
# =============================================================================
get_master_info() {
    redis_cli SENTINEL get-master-addr-by-name "$SENTINEL_MASTER_NAME" 2>/dev/null || echo ""
}

get_sentinel_role() {
    redis_cli ROLE 2>/dev/null | head -n1 || echo "unknown"
}

check_sentinel_health() {
    local output
    output=$(redis_cli PING 2>&1) || true

    if [[ "$output" == "PONG" ]]; then
        return 0
    else
        return 1
    fi
}

get_master_status() {
    local master_info
    master_info=$(get_master_info)

    if [[ -z "$master_info" ]]; then
        echo "unavailable"
        return 1
    fi

    local master_ip
    master_ip=$(echo "$master_info" | head -n1)

    local is_master
    is_master=$(redis_cli -h "$master_ip" -p 6379 ROLE | head -n1 2>/dev/null) || echo "unknown"

    echo "$is_master"
    return 0
}

get_slave_info() {
    redis_cli SENTINEL slaves "$SENTINEL_MASTER_NAME" 2>/dev/null || echo ""
}

get_replication_lag() {
    local slaves
    slaves=$(get_slave_info)

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

# =============================================================================
# Failover Monitoring
# =============================================================================
monitor_failover() {
    log "INFO" "Starting Redis Sentinel failover monitoring..."

    local last_master_ip
    last_master_ip=$(load_state | jq -r '.master_ip // empty')

    while true; do
        if check_sentinel_health; then
            local current_master
            current_master=$(get_master_info)

            if [[ -n "$current_master" ]]; then
                local current_master_ip
                current_master_ip=$(echo "$current_master" | head -n1)

                # Check if master changed
                if [[ -n "$last_master_ip" ]] && [[ "$current_master_ip" != "$last_master_ip" ]]; then
                    log "WARNING" "Master changed from $last_master_ip to $current_master_ip"
                    send_alert "WARNING" "Redis master changed. New master: $current_master_ip"

                    # Update application configuration
                    update_redis_config "$current_master_ip"
                fi

                # Save current state
                save_state "master" "$current_master_ip"
                last_master_ip="$current_master_ip"
            else
                log "ERROR" "No master available"
                save_state "no_master" ""
            fi

            # Check replication lag
            local lag
            lag=$(get_replication_lag)
            log "INFO" "Replication lag: ${lag}s"

            if [[ $lag -gt 30 ]]; then
                log "WARNING" "High replication lag detected: ${lag}s"
                send_alert "WARNING" "Redis replication lag is high: ${lag}s"
            fi
        else
            log "ERROR" "Sentinel is unhealthy"
        fi

        sleep "$CHECK_INTERVAL"
    done
}

# =============================================================================
# Configuration Updates
# =============================================================================
update_redis_config() {
    local new_master=$1
    local config_file="/etc/agl-hostman/redis.json"

    if [[ -f "$config_file" ]]; then
        # Update Laravel Redis configuration
        tmp_file=$(mktemp)
        jq ".default.host = \"$new_master\"" "$config_file" > "$tmp_file"
        mv "$tmp_file" "$config_file"

        # Restart PHP-FPM
        systemctl reload php-fpm || true
    fi
}

# =============================================================================
# Manual Failover Trigger
# =============================================================================
trigger_failover() {
    log "INFO" "Triggering manual failover..."

    local output
    output=$(redis_cli SENTINEL FAILOVER "$SENTINEL_MASTER_NAME" 2>&1) || true

    if [[ "$output" == "OK" ]]; then
        log "INFO" "Failover initiated successfully"
        send_alert "WARNING" "Manual Redis failover initiated"
    else
        log "ERROR" "Failed to trigger failover: $output"
        return 1
    fi
}

# =============================================================================
# Health Check
# =============================================================================
health_check() {
    local master_info
    master_info=$(get_master_info)

    local master_ip
    master_ip=$(echo "$master_info" | head -n1)

    local master_port
    master_port=$(echo "$master_info" | sed -n '2p')

    local slaves
    slaves=$(get_slave_info)

    local slave_count
    slave_count=$(echo "$slaves" | grep -c "name=" || echo "0")

    local lag
    lag=$(get_replication_lag)

    jq -n \
        --argjson healthy "$(check_sentinel_health && echo true || echo false)" \
        --arg master_ip "${master_ip:-unknown}" \
        --arg master_port "${master_port:-6379}" \
        --argjson slave_count "$slave_count" \
        --argjson lag "$lag" \
        '{
            healthy: $healthy,
            master_ip: $master_ip,
            master_port: $master_port,
            slave_count: $slave_count,
            replication_lag: $lag
        }'
}

# =============================================================================
# Main
# =============================================================================
main() {
    local command=${1:-monitor}

    case "$command" in
        monitor)
            monitor_failover
            ;;
        health-check)
            health_check
            ;;
        failover)
            trigger_failover
            ;;
        *)
            echo "Usage: $0 {monitor|health-check|failover}"
            exit 1
            ;;
    esac
}

main "$@"
