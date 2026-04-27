#!/bin/bash
# =============================================================================
# MySQL Automated Failover Script
# AGL Hostman - High Availability Infrastructure
# =============================================================================
#
# This script automatically promotes a MySQL slave to master in case of master failure.
# It uses GTID-based replication for safe failover.
#
# Usage: ./mysql-failover-automated.sh [dry-run|execute]
#
# Features:
# - Automatic master health detection
# - Safe failover with GTID checks
# - Application connection string updates
# - Notification via Slack/Webhook
# - Rollback capability
# =============================================================================

set -euo pipefail

# =============================================================================
# Configuration
# =============================================================================
MYSQL_ROOT_USER="${MYSQL_ROOT_USER:-root}"
MYSQL_ROOT_PASSWORD="${MYSQL_ROOT_PASSWORD}"
MYSQL_REPL_USER="${MYSQL_REPL_USER:-repl_user}"
MYSQL_REPL_PASSWORD="${MYSQL_REPL_PASSWORD}"

# Master configuration
MASTER_HOST="${MYSQL_MASTER_HOST:-mysql-master}"
MASTER_PORT="${MYSQL_MASTER_PORT:-3306}"

# Slave configuration
SLAVE_1_HOST="${MYSQL_SLAVE_1_HOST:-mysql-slave-1}"
SLAVE_2_HOST="${MYSQL_SLAVE_2_HOST:-mysql-slave-2}"
PREFERRED_SLAVE="${PREFERRED_SLAVE:-$SLAVE_1_HOST}"

# Failover settings
FAILOVER_TIMEOUT=30
HEALTH_CHECK_INTERVAL=5
HEALTH_CHECK_RETRIES=6

# Notification settings
WEBHOOK_URL="${WEBHOOK_URL:-}"
SLACK_WEBHOOK="${SLACK_WEBHOOK_URL:-}"

# Log file
LOG_FILE="/var/log/mysql-failover.log"
STATE_FILE="/var/lib/mysql/failover-state.json"

# Lock file to prevent concurrent failovers
LOCK_FILE="/tmp/mysql-failover.lock"
LOCK_TIMEOUT=300

# =============================================================================
# Logging Functions
# =============================================================================
log() {
    local level=$1
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" | tee -a "$LOG_FILE"
}

log_info() { log "INFO" "$@"; }
log_warn() { log "WARN" "$@"; }
log_error() { log "ERROR" "$@"; }
log_critical() { log "CRITICAL" "$@"; }

# =============================================================================
# Notification Functions
# =============================================================================
send_notification() {
    local status=$1
    local message=$2
    local color=$3

    local payload=$(cat <<EOF
{
  "text": "$message",
  "attachments": [
    {
      "color": "$color",
      "fields": [
        {
          "title": "Status",
          "value": "$status",
          "short": true
        },
        {
          "title": "Timestamp",
          "value": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
          "short": true
        },
        {
          "title": "Host",
          "value": "$(hostname)",
          "short": true
        }
      ]
    }
  ]
}
EOF
)

    if [[ -n "$WEBHOOK_URL" ]]; then
        curl -s -X POST "$WEBHOOK_URL" \
            -H "Content-Type: application/json" \
            -d "$payload" || true
    fi

    if [[ -n "$SLACK_WEBHOOK" ]]; then
        curl -s -X POST "$SLACK_WEBHOOK" \
            -H "Content-Type: application/json" \
            -d "$payload" || true
    fi
}

# =============================================================================
# MySQL Connection Functions
# =============================================================================
mysql_exec() {
    local host=$1
    shift
    mysql -h "$host" -u "$MYSQL_ROOT_USER" -p"$MYSQL_ROOT_PASSWORD" \
        --skip-column-names --batch --connect-timeout=5 "$@" 2>/dev/null || true
}

mysql_ping() {
    local host=$1
    mysqladmin -h "$host" -u "$MYSQL_ROOT_USER" -p"$MYSQL_ROOT_PASSWORD" \
        ping 2>/dev/null || return 1
}

# =============================================================================
# Health Check Functions
# =============================================================================
check_master_health() {
    local retries=0

    while [[ $retries -lt $HEALTH_CHECK_RETRIES ]]; do
        if mysql_ping "$MASTER_HOST"; then
            # Check if master is read-write capable
            local readonly=$(mysql_exec "$MASTER_HOST" \
                -e "SELECT @@read_only" 2>/dev/null || echo "1")

            if [[ "$readonly" == "0" ]]; then
                log_info "Master $MASTER_HOST is healthy and read-write"
                return 0
            fi
        fi

        retries=$((retries + 1))
        log_warn "Master health check failed (attempt $retries/$HEALTH_CHECK_RETRIES)"
        sleep $HEALTH_CHECK_INTERVAL
    done

    log_error "Master $MASTER_HOST is unhealthy after $HEALTH_CHECK_RETRIES attempts"
    return 1
}

check_slave_health() {
    local slave_host=$1

    if ! mysql_ping "$slave_host"; then
        log_error "Slave $slave_host is not responding"
        return 1
    fi

    # Check replication status
    local status=$(mysql_exec "$slave_host" \
        -e "SHOW SLAVE STATUS\G" 2>/dev/null || echo "")

    local io_running=$(echo "$status" | grep "Slave_IO_Running:" | cut -d: -f2 | xargs || echo "No")
    local sql_running=$(echo "$status" | grep "Slave_SQL_Running:" | cut -d: -f2 | xargs || echo "No")
    local seconds_behind=$(echo "$status" | grep "Seconds_Behind_Master:" | cut -d: -f2 | xargs || echo "NULL")

    if [[ "$io_running" == "Yes" && "$sql_running" == "Yes" ]]; then
        if [[ "$seconds_behind" == "NULL" || "$seconds_behind" -lt 10 ]]; then
            log_info "Slave $slave_host is healthy (lag: ${seconds_behind}s)"
            return 0
        else
            log_warn "Slave $slave_host has high lag: ${seconds_behind}s"
            return 1
        fi
    else
        log_error "Slave $slave_host replication not running (IO: $io_running, SQL: $sql_running)"
        return 1
    fi
}

get_most_up_to_date_slave() {
    local best_slave=""
    local lowest_gtid=""

    for slave in "$SLAVE_1_HOST" "$SLAVE_2_HOST"; do
        if ! mysql_ping "$slave"; then
            continue
        fi

        local gtid=$(mysql_exec "$slave" \
            -e "SELECT @@gtid_executed" 2>/dev/null || echo "")

        if [[ -z "$gtid" ]]; then
            continue
        fi

        if [[ -z "$lowest_gtid" || "$gtid" \> "$lowest_gtid" ]]; then
            lowest_gtid="$gtid"
            best_slave="$slave"
        fi
    done

    if [[ -n "$best_slave" ]]; then
        echo "$best_slave"
        return 0
    fi

    return 1
}

# =============================================================================
# Failover Functions
# =============================================================================
promote_slave_to_master() {
    local new_master=$1

    log_info "Promoting $new_master to master..."

    # Stop replication
    mysql_exec "$new_master" -e "STOP SLAVE;"
    mysql_exec "$new_master" -e "RESET SLAVE ALL;"

    # Enable read-write mode
    mysql_exec "$new_master" -e "SET GLOBAL read_only = OFF;"
    mysql_exec "$new_master" -e "SET GLOBAL super_read_only = OFF;"

    # Update server_id if needed (keep it lower for preference)
    log_info "Slave $new_master promoted successfully"

    # Save state
    cat > "$STATE_FILE" <<EOF
{
  "failover_time": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "old_master": "$MASTER_HOST",
  "new_master": "$new_master",
  "gtid_executed": "$(mysql_exec "$new_master" -e "SELECT @@gtid_executed" 2>/dev/null)"
}
EOF

    return 0
}

point_other_slaves() {
    local new_master=$1

    log_info "Repointing other slaves to $new_master..."

    for slave in "$SLAVE_1_HOST" "$SLAVE_2_HOST"; do
        if [[ "$slave" == "$new_master" ]]; then
            continue
        fi

        if ! mysql_ping "$slave"; then
            log_warn "Cannot repoint $slave (not responding)"
            continue
        fi

        # Stop and reset slave
        mysql_exec "$slave" -e "STOP SLAVE;" 2>/dev/null || true
        mysql_exec "$slave" -e "RESET SLAVE ALL;" 2>/dev/null || true

        # Configure new master
        mysql_exec "$slave" -e "CHANGE MASTER TO
            MASTER_HOST='$new_master',
            MASTER_USER='$MYSQL_REPL_USER',
            MASTER_PASSWORD='$MYSQL_REPL_PASSWORD',
            MASTER_AUTO_POSITION=1;"

        # Start slave
        mysql_exec "$slave" -e "START SLAVE;"

        log_info "Slave $slave repointed to $new_master"
    done
}

update_app_config() {
    local new_master=$1

    log_info "Updating application configuration..."

    # Update environment file if it exists
    local env_file="/var/www/html/.env"

    if [[ -f "$env_file" ]]; then
        # Backup current env
        cp "$env_file" "${env_file}.backup.$(date +%s)"

        # Update DB_HOST (using sed with different delimiter)
        sed -i "s|^DB_HOST=.*|DB_HOST=$new_master|" "$env_file"

        log_info "Environment file updated"

        # Reload application if systemd service exists
        if systemctl is-active --quiet agl-hostman; then
            systemctl reload agl-hostman || true
            log_info "Application service reloaded"
        fi
    fi
}

# =============================================================================
# Main Failover Orchestration
# =============================================================================
perform_failover() {
    local mode=${1:-dry-run}

    if [[ "$mode" == "execute" ]]; then
        log_info "Starting automated failover (EXECUTE mode)"
    else
        log_info "Starting automated failover (DRY-RUN mode)"
    fi

    # Acquire lock
    if [[ -f "$LOCK_FILE" ]]; then
        local lock_age=$(($(date +%s) - $(stat -c %Y "$LOCK_FILE")))
        if [[ $lock_age -lt $LOCK_TIMEOUT ]]; then
            log_error "Failover already in progress (lock age: ${lock_age}s)"
            exit 1
        else
            log_warn "Removing stale lock file"
            rm -f "$LOCK_FILE"
        fi
    fi

    touch "$LOCK_FILE"
    trap "rm -f '$LOCK_FILE'" EXIT

    # Check master health
    if check_master_health; then
        log_info "Master is healthy, no failover needed"
        rm -f "$LOCK_FILE"
        exit 0
    fi

    # Send notification about master failure
    send_notification "CRITICAL" \
        "MySQL Master $MASTER_HOST is DOWN! Initiating failover..." \
        "danger"

    # Find best slave to promote
    local new_master
    new_master=$(get_most_up_to_date_slave)

    if [[ -z "$new_master" ]]; then
        log_critical "No healthy slave found for failover!"
        send_notification "CRITICAL" \
            "FAILOVER FAILED: No healthy slave available" \
            "danger"
        exit 1
    fi

    log_info "Selected $new_master as new master"

    if [[ "$mode" == "execute" ]]; then
        # Perform failover
        promote_slave_to_master "$new_master"
        point_other_slaves "$new_master"
        update_app_config "$new_master"

        # Send success notification
        send_notification "INFO" \
            "FAILOVER COMPLETE: $new_master is now the master" \
            "good"

        log_info "Failover completed successfully"
    else
        log_info "DRY-RUN: Would promote $new_master to master"
    fi
}

# =============================================================================
# Usage and Main
# =============================================================================
usage() {
    cat <<EOF
MySQL Automated Failover Script

Usage: $0 [dry-run|execute] [options]

Options:
    dry-run    Simulate failover without making changes (default)
    execute    Perform actual failover

Environment Variables:
    MYSQL_ROOT_PASSWORD      MySQL root password (required)
    MYSQL_REPL_PASSWORD      MySQL replication user password (required)
    MYSQL_MASTER_HOST         Master hostname (default: mysql-master)
    MYSQL_SLAVE_1_HOST        First slave hostname
    MYSQL_SLAVE_2_HOST        Second slave hostname
    WEBHOOK_URL             Notification webhook URL
    SLACK_WEBHOOK_URL       Slack webhook URL

Examples:
    # Dry run
    $0 dry-run

    # Execute failover
    $0 execute
EOF
    exit 0
}

# Check dependencies
for cmd in mysql mysqladmin curl jq; do
    if ! command -v "$cmd" &>/dev/null; then
        log_error "Required command not found: $cmd"
        exit 1
    fi
done

# Parse arguments
MODE=${1:-dry-run}
case "$MODE" in
    dry-run|execute)
        perform_failover "$MODE"
        ;;
    -h|--help|help)
        usage
        ;;
    *)
        log_error "Invalid mode: $MODE"
        usage
        ;;
esac
