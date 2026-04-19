#!/bin/bash
# =============================================================================
# MySQL Failover Script for AGL Hostman
# Automatically promotes slave to master when master fails
# =============================================================================

set -euo pipefail

# Configuration
MYSQL_MASTER_HOST="${MYSQL_MASTER_HOST:-mysql-master}"
MYSQL_SLAVE_HOST="${MYSQL_SLAVE_HOST:-mysql-slave}"
MYSQL_REPLICATION_USER="${MYSQL_REPLICATION_USER:-replicator}"
MYSQL_ROOT_USER="${MYSQL_ROOT_USER:-root}"
MYSQL_PASSWORD_FILE="${MYSQL_PASSWORD_FILE:-/run/secrets/mysql-root-password}"

# Failover settings
FAILOVER_CHECK_INTERVAL=10
FAILOVER_TIMEOUT=60
MAX_REPLICATION_LAG=30

# State file
STATE_DIR="/var/lib/mysql-failover"
STATE_FILE="$STATE_DIR/failover-state.json"
LOCK_FILE="$STATE_DIR/failover.lock"

# Logging
LOG_FILE="/var/log/mysql-failover.log"

# Email/Alert settings
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

    # Send email
    if [[ -n "$ALERT_EMAIL" ]]; then
        echo "$message" | mail -s "[$severity] MySQL Failover Alert" "$ALERT_EMAIL" 2>/dev/null || true
    fi

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
                    \"title\": \"[$severity] MySQL Failover\",
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
# MySQL Functions
# =============================================================================
mysql_exec() {
    local host=$1
    shift
    MYSQL_PWD="$(cat "$MYSQL_PASSWORD_FILE")" mysql -h "$host" -u "$MYSQL_ROOT_USER" "$@" 2>&1
}

mysql_exec_slave() {
    MYSQL_PWD="$(cat "$MYSQL_PASSWORD_FILE")" mysql -h "$MYSQL_SLAVE_HOST" -u "$MYSQL_ROOT_USER" "$@" 2>&1
}

# =============================================================================
# State Management
# =============================================================================
load_state() {
    if [[ -f "$STATE_FILE" ]]; then
        cat "$STATE_FILE"
    else
        echo '{"status":"unknown","last_check":null}'
    fi
}

save_state() {
    local status=$1
    local message=${2:-}

    mkdir -p "$STATE_DIR"
    cat > "$STATE_FILE" <<EOF
{
  "status": "$status",
  "last_check": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "message": "$message",
  "hostname": "$(hostname)"
}
EOF
}

acquire_lock() {
    if mkdir "$LOCK_FILE" 2>/dev/null; then
        trap 'release_lock' EXIT
        return 0
    else
        log "ERROR" "Could not acquire lock. Another failover may be in progress."
        return 1
    fi
}

release_lock() {
    rm -rf "$LOCK_FILE"
}

# =============================================================================
# Health Checks
# =============================================================================
check_master_health() {
    local response
    response=$(mysql_exec "$MYSQL_MASTER_HOST" -e "SELECT 1" -s -N 2>&1) || true

    if [[ "$response" == "1" ]]; then
        return 0
    else
        return 1
    fi
}

check_slave_health() {
    local response
    response=$(mysql_exec_slave -e "SELECT 1" -s -N 2>&1) || true

    if [[ "$response" == "1" ]]; then
        return 0
    else
        return 1
    fi
}

check_replication_lag() {
    local lag
    lag=$(mysql_exec_slave -e "SHOW SLAVE STATUS\G" | awk '/Seconds_Behind_Master/ {print $2}') || echo "NULL"

    if [[ "$lag" == "NULL" ]]; then
        echo 9999
        return 1
    fi

    echo "$lag"
    if [[ "$lag" -le "$MAX_REPLICATION_LAG" ]]; then
        return 0
    else
        return 1
    fi
}

# =============================================================================
# Failover Functions
# =============================================================================
perform_failover() {
    log "CRITICAL" "Starting failover process..."

    local state
    state=$(load_state)
    local current_status
    current_status=$(echo "$state" | jq -r '.status')

    if [[ "$current_status" == "failed_over" ]]; then
        log "WARNING" "Already in failed over state. Skipping failover."
        return 0
    fi

    # Stop slave
    log "INFO" "Stopping slave replication..."
    mysql_exec_slave -e "STOP SLAVE;" || true

    # Reset slave settings
    log "INFO" "Resetting slave configuration..."
    mysql_exec_slave -e "RESET SLAVE ALL;" || true

    # Enable read-write mode
    log "INFO" "Enabling read-write mode..."
    mysql_exec_slave -e "SET GLOBAL read_only = OFF;" || true
    mysql_exec_slave -e "SET GLOBAL super_read_only = OFF;" || true

    # Update application configuration
    log "INFO" "Updating application configuration..."
    update_app_config "$MYSQL_SLAVE_HOST"

    # Save state
    save_state "failed_over" "Failover completed. Slave promoted to master."

    # Send alert
    send_alert "CRITICAL" "MySQL failover completed. $MYSQL_SLAVE_HOST is now the master."

    log "INFO" "Failover completed successfully."
}

update_app_config() {
    local new_master=$1
    local config_file="/etc/agl-hostman/database.json"

    if [[ -f "$config_file" ]]; then
        # Update Laravel database configuration
        tmp_file=$(mktemp)
        jq ".connections.pgsql.host = \"$new_master\"" "$config_file" > "$tmp_file"
        mv "$tmp_file" "$config_file"

        # Restart PHP-FPM to reload configuration
        systemctl reload php-fpm || true
        systemctl reload nginx || true
    fi
}

revert_failover() {
    log "INFO" "Reverting failover (old master is back online)..."

    # This should be done manually after verifying data consistency
    send_alert "WARNING" "Manual intervention required to revert failover. Verify data integrity before promoting old master."
}

# =============================================================================
# Main Monitoring Loop
# =============================================================================
monitor() {
    log "INFO" "Starting MySQL failover monitoring..."
    log "INFO" "Master: $MYSQL_MASTER_HOST"
    log "INFO" "Slave: $MYSQL_SLAVE_HOST"

    local consecutive_failures=0

    while true; do
        if check_master_health; then
            log "INFO" "Master is healthy"

            consecutive_failures=0

            # Check if we need to revert failover
            local state
            state=$(load_state)
            local current_status
            current_status=$(echo "$state" | jq -r '.status')

            if [[ "$current_status" == "failed_over" ]]; then
                log "INFO" "Master is back online. Consider reverting failover."
                send_alert "WARNING" "MySQL master is back online. Manual failback recommended."
                save_state "master_recovered" "Old master is back online"
            fi

            save_state "healthy" "Master and slave are healthy"
        else
            log "ERROR" "Master is unhealthy"
            consecutive_failures=$((consecutive_failures + 1))

            if [[ $consecutive_failures -ge 3 ]]; then
                log "CRITICAL" "Master failed for $consecutive_failures consecutive checks"

                # Check slave health and replication lag
                if check_slave_health && check_replication_lag; then
                    log "INFO" "Slave is healthy and replication lag is acceptable"

                    # Acquire lock and perform failover
                    if acquire_lock; then
                        perform_failover
                        release_lock
                    fi
                else
                    log "ERROR" "Slave is unhealthy or replication lag is too high. Cannot failover."
                    send_alert "CRITICAL" "MySQL master is down but slave is not ready for failover."
                fi
            fi
        fi

        sleep "$FAILOVER_CHECK_INTERVAL"
    done
}

# =============================================================================
# Single Health Check Mode
# =============================================================================
health_check() {
    local master_healthy slave_healthy lag

    if check_master_health; then
        master_healthy="true"
    else
        master_healthy="false"
    fi

    if check_slave_health; then
        slave_healthy="true"
    else
        slave_healthy="false"
    fi

    lag=$(check_replication_lag)

    jq -n \
        --argjson master_healthy "$master_healthy" \
        --argjson slave_healthy "$slave_healthy" \
        --argjson lag "$lag" \
        '{
            master_healthy: $master_healthy,
            slave_healthy: $slave_healthy,
            replication_lag: $lag,
            can_failover: ($slave_healthy and ($lag <= '"$MAX_REPLICATION_LAG"'))
        }'
}

# =============================================================================
# Main
# =============================================================================
main() {
    local command=${1:-monitor}

    case "$command" in
        monitor)
            monitor
            ;;
        health-check)
            health_check
            ;;
        failover)
            if acquire_lock; then
                perform_failover
                release_lock
            fi
            ;;
        *)
            echo "Usage: $0 {monitor|health-check|failover}"
            exit 1
            ;;
    esac
}

main "$@"
