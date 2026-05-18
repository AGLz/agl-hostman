#!/bin/bash
# =============================================================================
# Redis Sentinel Failover Notification Script
# AGL Hostman - High Availability Infrastructure
# =============================================================================
#
# This script is called by Redis Sentinel when a failover occurs.
# It notifies administrators and updates application configuration.
#
# Configuration in sentinel.conf:
#   sentinel notification-script mymaster /path/to/redis-sentinel-failover-notify.sh
#
# Arguments passed by Sentinel:
# $1 = <event-type> (failover, +failover-end, etc)
# $2 = <master-name>
# $3 = <master-ip>
# $4 = <master-port>
# $5 = <sentinel-ip>
# $6 = <sentinel-port>
# =============================================================================

set -euo pipefail

# Configuration
NOTIFICATION_WEBHOOK="${WEBHOOK_URL:-}"
SLACK_WEBHOOK="${SLACK_WEBHOOK_URL:-}"
LOG_FILE="/var/log/redis-sentinel-failover.log"

# Redis connection details
REDIS_PASSWORD="${REDIS_PASSWORD:-}"

# Logging
log() {
    local level=$1
    shift
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $*" | tee -a "$LOG_FILE"
}

# Get current master from Sentinel
get_current_master() {
    local sentinel_host=$1
    local sentinel_port=${2:-26379}

    redis-cli -h "$sentinel_host" -p "$sentinel_port" \
        --no-auth-warning -a "$REDIS_PASSWORD" \
        SENTINEL get-master-addr-by-name mymaster 2>/dev/null || echo "unknown"
}

# Send notification
send_notification() {
    local event_type=$1
    local master_name=$2
    local master_ip=$3
    local master_port=$4
    local sentinel_ip=$5
    local sentinel_port=$6

    local current_master=$(get_current_master "$sentinel_ip" "$sentinel_port")

    local message=""
    local color="warning"

    case "$event_type" in
        +failover-end)
            message="Redis failover completed for master '$master_name'"
            color="good"
            ;;
        +switch-master)
            message="Redis master switched to $current_master"
            color="warning"
            ;;
        +sdown)
            message="Redis master '$master_name' (IP: $master_ip) is SUBJECTIVELY down"
            color="danger"
            ;;
        +odown)
            message="Redis master '$master_name' (IP: $master_ip) is OBJECTIVELY down"
            color="danger"
            ;;
        *)
            message="Redis Sentinel event: $event_type"
            color="warning"
            ;;
    esac

    local payload=$(cat <<EOF
{
  "text": ":rotating_light: Redis Sentinel Alert",
  "attachments": [
    {
      "color": "$color",
      "fields": [
        {
          "title": "Event",
          "value": "$event_type",
          "short": true
        },
        {
          "title": "Master",
          "value": "$master_name",
          "short": true
        },
        {
          "title": "Old Master",
          "value": "$master_ip:$master_port",
          "short": true
        },
        {
          "title": "Current Master",
          "value": "$current_master",
          "short": true
        },
        {
          "title": "Sentinel",
          "value": "$sentinel_ip:$sentinel_port",
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
)

    # Send to webhook
    if [[ -n "$NOTIFICATION_WEBHOOK" ]]; then
        curl -s -X POST "$NOTIFICATION_WEBHOOK" \
            -H "Content-Type: application/json" \
            -d "$payload" || true
    fi

    # Send to Slack
    if [[ -n "$SLACK_WEBHOOK" ]]; then
        curl -s -X POST "$SLACK_WEBHOOK" \
            -H "Content-Type: application/json" \
            -d "$payload" || true
    fi

    log "NOTIFICATION" "$message"
}

# Main
EVENT_TYPE=$1
MASTER_NAME=$2
MASTER_IP=$3
MASTER_PORT=$4
SENTINEL_IP=$5
SENTINEL_PORT=$6

log "INFO" "Received event: $EVENT_TYPE for master $MASTER_NAME ($MASTER_IP:$MASTER_PORT)"

send_notification "$EVENT_TYPE" "$MASTER_NAME" "$MASTER_IP" "$MASTER_PORT" "$SENTINEL_IP" "$SENTINEL_PORT"

# Update application config on failover-end
if [[ "$EVENT_TYPE" == "+failover-end" ]]; then
    current_master=$(get_current_master "$SENTINEL_IP" "$SENTINEL_PORT")
    log "INFO" "Updating Redis configuration to point to $current_master"

    # Update Laravel config if file exists
    env_file="/var/www/html/.env"
    if [[ -f "$env_file" ]]; then
        cp "$env_file" "${env_file}.backup.$(date +%s)"
        sed -i "s|^REDIS_HOST=.*|REDIS_HOST=$current_master|" "$env_file"

        # Reload app if using systemd
        if systemctl is-active --quiet agl-hostman; then
            systemctl reload agl-hostman || true
        fi

        log "INFO" "Application configuration updated"
    fi
fi

exit 0
