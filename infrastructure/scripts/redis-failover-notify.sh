#!/bin/bash
# =============================================================================
# Redis Sentinel Failover Notification Script
# =============================================================================
# Called by Sentinel during failover events
#
# This script is called by Sentinel with the following arguments:
# <failover-type> <role> <state> <from-ip> <from-port> <to-ip> <to-port>
#
# Environment Variables:
#   ALERT_WEBHOOK          Slack/webhook URL for alerts
#   ALERT_EMAIL           Email address for alerts
#   LOG_FILE              Log file location
#
# Author: Database High Availability Skill
# Version: 1.0.0

set -euo pipefail

# Configuration
LOG_FILE="${LOG_FILE:-/var/log/redis-failover-notify.log}"
ALERT_WEBHOOK="${ALERT_WEBHOOK:-}"
ALERT_EMAIL="${ALERT_EMAIL:-}"

# Logging
log() {
    local level=$1
    shift
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $@" | tee -a "$LOG_FILE"
}

# Alert function
send_alert() {
    local severity=$1
    local title=$2
    local message=$3
    local color="#36a64f"

    [[ "$severity" == "CRITICAL" ]] && color="#dc3545"
    [[ "$severity" == "WARNING" ]] && color="#ffc107"

    log "ALERT" "[$severity] $title: $message"

    # Webhook notification
    if [[ -n "$ALERT_WEBHOOK" ]]; then
        curl -s -X POST "$ALERT_WEBHOOK" \
            -H "Content-Type: application/json" \
            -d "{
                \"attachments\": [{
                    \"color\": \"$color\",
                    \"title\": \"$title\",
                    \"text\": \"$message\",
                    \"fields\": [
                        {\"title\": \"Hostname\", \"value\": \"$(hostname)\", \"short\": true},
                        {\"title\": \"Timestamp\", \"value\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\", \"short\": true}
                    ]
                }]
            }" || true
    fi

    # Email notification
    if [[ -n "$ALERT_EMAIL" ]]; then
        echo "$message" | mail -s "[$severity] $title" "$ALERT_EMAIL" || true
    fi
}

# Main failover handler
handle_failover() {
    local failover_type=$1
    local role=$2
    local state=$3
    local from_ip=$4
    local from_port=$5
    local to_ip=$6
    local to_port=$7

    log "INFO" "Failover event: type=$failover_type role=$role state=$state"
    log "INFO" "Transition: $from_ip:$from_port -> $to_ip:$to_port"

    case "$failover_type" in
        failover)
            if [[ "$state" == "start" ]]; then
                send_alert "WARNING" \
                    "Redis Failover Started" \
                    "Failover initiated. Master $from_ip:$from_port is being demoted."
            elif [[ "$state" == "end" ]]; then
                send_alert "CRITICAL" \
                    "Redis Failover Completed" \
                    "New master promoted: $to_ip:$to_port (old: $from_ip:$from_port)

IP Address Update for Applications:
- New Master: $to_ip:$to_port
- Sentinel will automatically redirect connections

Application Action Required:
- Connection pools will auto-recover if using Sentinel
- Monitor application logs for connection errors
- No manual intervention required if using Redis Sentinel client"

                # Update application configuration (optional)
                update_app_config "$to_ip" "$to_port"
            fi
            ;;
        config-update)
            send_alert "INFO" \
                "Redis Configuration Updated" \
                "Sentinel configuration updated for $to_ip:$to_port"
            ;;
        *)
            log "INFO" "Unknown failover type: $failover_type"
            ;;
    esac
}

# Update application configuration
update_app_config() {
    local new_master_ip=$1
    local new_master_port=$2

    # Laravel application config
    local app_config="/var/www/html/.env"
    if [[ -f "$app_config" ]]; then
        # Update Redis host in .env
        sed -i "s/^REDIS_HOST=.*/REDIS_HOST=$new_master_ip/" "$app_config" || true
        sed -i "s/^REDIS_PORT=.*/REDIS_PORT=$new_master_port/" "$app_config" || true

        # Reload PHP-FPM if using Laravel
        if systemctl is-active --quiet php-fpm || systemctl is-active --quiet php8.2-fpm; then
            systemctl reload php-fpm || systemctl reload php8.2-fpm || true
        fi

        log "INFO" "Updated application config: $new_master_ip:$new_master_port"
    fi

    # Horizon worker restart (if using Laravel Horizon)
    if systemctl is-active --quiet horizon; then
        systemctl restart horizon || true
        log "INFO" "Restarted Laravel Horizon"
    fi

    # Queue worker restart
    if systemctl is-active --quiet redis-queue-worker; then
        systemctl restart redis-queue-worker || true
        log "INFO" "Restarted queue workers"
    fi
}

# Main execution
if [[ $# -lt 3 ]]; then
    log "ERROR" "Insufficient arguments. Usage: $0 <failover-type> <role> <state> ..."
    exit 1
fi

handle_failover "$@"
