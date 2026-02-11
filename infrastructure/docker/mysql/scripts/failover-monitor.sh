#!/bin/bash
# =============================================================================
# MySQL Failover Monitor Script
# AGL Hostman - Automated Failover Monitoring and Promotion
# =============================================================================
#
# Features:
#   - Master health monitoring
#   - Slave health verification
#   - Automatic slave promotion on master failure
#   - Alert notifications
#   - State management
#
# Usage:
#   ./failover-monitor.sh           # Continuous monitoring mode
#   ./failover-monitor.sh health      # Single health check
#   ./failover-monitor.sh failover    # Manual failover trigger
#   ./failover-monitor.sh status      # Show current state
#
# =============================================================================

set -euo pipefail

# =============================================================================
# Configuration
# =============================================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${CONFIG_FILE:-$SCRIPT_DIR/../ha/replication-config.env}"
STATE_DIR="${STATE_DIR:-/var/lib/mysql-failover}"
LOG_FILE="${LOG_FILE:-/var/log/mysql-failover.log}"

# Load configuration if available
if [[ -f "$CONFIG_FILE" ]]; then
    source "$CONFIG_FILE"
fi

# Default values
MYSQL_MASTER_HOST="${MYSQL_MASTER_HOST:-mysql-master}"
MYSQL_SLAVE_HOSTS="${MYSQL_SLAVE_HOSTS:-mysql-slave-1,mysql-slave-2}"
MYSQL_ROOT_USER="${MYSQL_ROOT_USER:-root}"
MYSQL_ROOT_PASSWORD="${MYSQL_ROOT_PASSWORD:-}"
MYSQL_REPLICATION_USER="${MYSQL_REPLICATION_USER:-replicator}"

# Failover settings
FAILOVER_CHECK_INTERVAL="${FAILOVER_CHECK_INTERVAL:-10}"
FAILOVER_TIMEOUT="${FAILOVER_TIMEOUT:-60}"
MAX_REPLICATION_LAG="${MAX_REPLICATION_LAG:-30}"
CONSECUTIVE_FAILURES_THRESHOLD=3

# State files
STATE_FILE="$STATE_DIR/failover-state.json"
LOCK_FILE="$STATE_DIR/failover.lock"
HEALTH_FILE="$STATE_DIR/health-status.json"

# Alert settings
ALERT_WEBHOOK="${ALERT_WEBHOOK:-}"
SLACK_WEBHOOK="${SLACK_WEBHOOK:-}"

# =============================================================================
# Logging Functions
# =============================================================================
setup_logging() {
    mkdir -p "$STATE_DIR" "$(dirname "$LOG_FILE")"
    exec > >(tee -a "$LOG_FILE")
    exec 2>&1
}

log() {
    local level=$1
    shift
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $*"
}

log_info() { log "INFO" "$@"; }
log_success() { log "SUCCESS" "$@"; }
log_warning() { log "WARNING" "$@"; }
log_error() { log "ERROR" "$@"; }
log_critical() { log "CRITICAL" "$@"; }

# =============================================================================
# Alert Functions
# =============================================================================
send_alert() {
    local severity=$1
    local message=$2
    local details=${3:-}

    log "ALERT" "[$severity] $message"

    local color="#36a64f"
    [[ "$severity" == "CRITICAL" ]] && color="#dc3545"
    [[ "$severity" == "WARNING" ]] && color="#ffc107"
    [[ "$severity" == "INFO" ]] && color="#17a2b8"

    # Send webhook
    if [[ -n "$ALERT_WEBHOOK" ]]; then
        local payload
        payload=$(jq -n \
            --arg severity "$severity" \
            --arg message "$message" \
            --arg details "$details" \
            --arg hostname "$(hostname)" \
            --arg timestamp "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
            '{
                severity: $severity,
                message: $message,
                details: $details,
                hostname: $hostname,
                timestamp: $timestamp
            }')

        curl -s -X POST "$ALERT_WEBHOOK" \
            -H "Content-Type: application/json" \
            -d "$payload" || true
    fi

    # Send Slack notification
    if [[ -n "$SLACK_WEBHOOK" ]]; then
        local slack_payload
        slack_payload=$(jq -n \
            --arg color "$color" \
            --arg title "[$severity] MySQL Failover Alert" \
            --arg text "$message" \
            --arg hostname "$(hostname)" \
            --arg timestamp "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
            '{
                attachments: [{
                    color: $color,
                    title: $title,
                    text: $text,
                    fields: [
                        {title: "Hostname", value: $hostname, short: true},
                        {title: "Timestamp", value: $timestamp, short: true}
                    ]
                }]
            }')

        curl -s -X POST "$SLACK_WEBHOOK" \
            -H "Content-Type: application/json" \
            -d "$slack_payload" || true
    fi
}

# =============================================================================
# State Management
# =============================================================================
load_state() {
    if [[ -f "$STATE_FILE" ]]; then
        cat "$STATE_FILE"
    else
        jq -n '{
            status: "unknown",
            last_check: null,
            last_failover: null,
            hostname: "$(hostname)"
        }'
    fi
}

save_state() {
    local status=$1
    local message=${2:-}
    local failover_time=${3:-}

    local state
    state=$(load_state)

    state=$(echo "$state" | jq --arg status "$status" --arg message "$message" '
        .status = $status |
        .message = $message |
        .last_check = (now | todate) |
        if $failover_time then .last_failover = $failover_time else . end
    ')

    echo "$state" > "$STATE_FILE"
}

acquire_lock() {
    if mkdir "$LOCK_FILE" 2>/dev/null; then
        trap 'release_lock' EXIT
        return 0
    else
        log_warning "Could not acquire lock. Another failover may be in progress."
        return 1
    fi
}

release_lock() {
    rm -rf "$LOCK_FILE"
}

# =============================================================================
# MySQL Connection Functions
# =============================================================================
mysql_exec() {
    local host=$1
    shift
    MYSQL_PWD="$MYSQL_ROOT_PASSWORD" mysql -h "$host" -u "$MYSQL_ROOT_USER" "$@" 2>&1
}

check_mysql_health() {
    local host=$1
    local response

    response=$(MYSQL_PWD="$MYSQL_ROOT_PASSWORD" mysqladmin -h "$host" -u "$MYSQL_ROOT_USER" ping 2>&1) || true

    if [[ "$response" == "mysqld is alive" || "$response" == "mysqld is alive" ]]; then
        return 0
    else
        return 1
    fi
}

# =============================================================================
# Health Checks
# =============================================================================
check_master_health() {
    if check_mysql_health "$MYSQL_MASTER_HOST"; then
        return 0
    else
        return 1
    fi
}

check_slave_health() {
    local slave_host=$1

    if ! check_mysql_health "$slave_host"; then
        return 1
    fi

    # Check replication status
    local slave_status
    slave_status=$(mysql_exec "$slave_host" -e "SHOW SLAVE STATUS\G" 2>/dev/null) || return 1

    local io_running sql_running lag
    io_running=$(echo "$slave_status" | awk '/Slave_IO_Running:/ {print $2}')
    sql_running=$(echo "$slave_status" | awk '/Slave_SQL_Running:/ {print $2}')
    lag=$(echo "$slave_status" | awk '/Seconds_Behind_Master:/ {print $2}')

    if [[ "$io_running" == "Yes" && "$sql_running" == "Yes" ]]; then
        # Check lag
        if [[ -n "$lag" && "$lag" != "NULL" && "$lag" -le "$MAX_REPLICATION_LAG" ]]; then
            return 0
        fi
    fi

    return 1
}

get_healthiest_slave() {
    local healthiest_slave=""
    local lowest_lag=99999

    IFS=',' read -ra SLAVES <<< "$MYSQL_SLAVE_HOSTS"

    for slave in "${SLAVES[@]}"; do
        slave=$(echo "$slave" | xargs)  # trim whitespace

        if check_slave_health "$slave"; then
            local lag
            lag=$(mysql_exec "$slave" -e "SHOW SLAVE STATUS" 2>/dev/null | awk '/Seconds_Behind_Master:/ {print $2}')

            if [[ -z "$lag" || "$lag" == "NULL" ]]; then
                lag=0
            fi

            if [[ "$lag" -lt "$lowest_lag" ]]; then
                lowest_lag=$lag
                healthiest_slave=$slave
            fi
        fi
    done

    echo "$healthiest_slave"
}

# =============================================================================
# Failover Functions
# =============================================================================
perform_failover() {
    log_critical "Starting failover process..."

    local healthiest_slave
    healthiest_slave=$(get_healthiest_slave)

    if [[ -z "$healthiest_slave" ]]; then
        log_error "No healthy slave available for failover!"
        send_alert "CRITICAL" "MySQL master is down but no healthy slave for failover"
        return 1
    fi

    log_info "Healthiest slave identified: $healthiest_slave"

    # Get master GTID position
    local master_gtid
    master_gtid=$(mysql_exec "$MYSQL_MASTER_HOST" -e "SELECT @@GLOBAL.GTID_EXECUTED" -s -N 2>/dev/null || echo "")

    # Stop slave on healthiest slave
    log_info "Stopping slave on $healthiest_slave..."
    mysql_exec "$healthiest_slave" -e "STOP SLAVE;" 2>/dev/null || true
    mysql_exec "$healthiest_slave" -e "RESET SLAVE ALL;" 2>/dev/null || true

    # Promote to master
    log_info "Promoting $healthiest_slave to master..."
    mysql_exec "$healthiest_slave" -e "
        SET GLOBAL read_only = OFF;
        SET GLOBAL super_read_only = OFF;
    " 2>/dev/null || true

    # Save failover state
    save_state "failed_over" "Failover completed. $healthiest_slave promoted to master." "$(date -u +%Y-%m-%dT%H:%M:%SZ)"

    # Update application configuration
    update_app_config "$healthiest_slave"

    # Send alert
    local slave_lag
    slave_lag=$(mysql_exec "$healthiest_slave" -e "SHOW SLAVE STATUS" 2>/dev/null | awk '/Seconds_Behind_Master:/ {print $2}')
    slave_lag=${slave_lag:-0}

    send_alert "CRITICAL" "MySQL failover completed" \
        "New master: $healthiest_slave
Lag before promotion: ${slave_lag}s
Old master GTID: ${master_gtid:-N/A}"

    log_success "Failover completed. $healthiest_slave is now the master."

    # Note: Manual intervention required to:
    # 1. Rebuild old master as slave
    # 2. Update DNS if needed
    # 3. Verify application connectivity
}

update_app_config() {
    local new_master=$1
    local config_files=(
        "/var/www/html/.env"
        "/etc/agl-hostman/database.json"
    )

    for config_file in "${config_files[@]}"; do
        if [[ -f "$config_file" ]]; then
            log_info "Updating application configuration: $config_file"

            # Handle .env files
            if [[ "$config_file" == *.env ]]; then
                sed -i.bak "s/DB_WRITE_HOST=.*/DB_WRITE_HOST=$new_master/" "$config_file"
                sed -i.bak "s/DB_MASTER_HOST=.*/DB_MASTER_HOST=$new_master/" "$config_file"
            else
                # Handle JSON config files
                if command -v jq &> /dev/null; then
                    jq ".connections.mysql.host = \"$new_master\"" "$config_file" > "${config_file}.tmp"
                    mv "${config_file}.tmp" "$config_file"
                fi
            fi
        fi
    done

    # Reload PHP-FPM if running
    if systemctl is-active --quiet php-fpm; then
        log_info "Reloading PHP-FPM..."
        systemctl reload php-fpm
    fi
}

# =============================================================================
# Single Health Check
# =============================================================================
health_check() {
    local master_healthy=false
    local slaves_healthy=0
    local total_slaves=0
    local unhealthy_slaves=()
    local slave_status=()

    # Check master
    if check_master_health; then
        master_healthy=true
    fi

    # Check all slaves
    IFS=',' read -ra SLAVES <<< "$MYSQL_SLAVE_HOSTS"
    for slave in "${SLAVES[@]}"; do
        slave=$(echo "$slave" | xargs)  # trim whitespace
        ((total_slaves++))

        local lag io_running sql_running
        lag=$(mysql_exec "$slave" -e "SHOW SLAVE STATUS" 2>/dev/null | awk '/Seconds_Behind_Master:/ {print $2}')
        io_running=$(mysql_exec "$slave" -e "SHOW SLAVE STATUS" 2>/dev/null | awk '/Slave_IO_Running:/ {print $2}')
        sql_running=$(mysql_exec "$slave" -e "SHOW SLAVE STATUS" 2>/dev/null | awk '/Slave_SQL_Running:/ {print $2}')

        if [[ "$io_running" == "Yes" && "$sql_running" == "Yes" && ( -z "$lag" || "$lag" == "NULL" || "$lag" -le "$MAX_REPLICATION_LAG" ) ]]; then
            ((slaves_healthy++))
            slave_status+=("$slave:healthy")
        else
            unhealthy_slaves+=("$slave")
            slave_status+=("$slave:unhealthy")
        fi
    done

    # Save health status
    cat > "$HEALTH_FILE" <<EOF
{
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "master": {
    "host": "$MYSQL_MASTER_HOST",
    "healthy": $master_healthy
  },
  "slaves": {
    "total": $total_slaves,
    "healthy": $slaves_healthy,
    "unhealthy": $((total_slaves - slaves_healthy)),
    "unhealthy_hosts": [$(IFS=,; echo "${unhealthy_slaves[*]}" | sed 's/ /", "/g' | sed 's/,$//' | sed 's/,/, /g')]
  },
  "overall_status": "$([[ $master_healthy == true && $slaves_healthy -eq $total_slaves ]] && echo "healthy" || echo "degraded")",
  "can_failover": $( [[ $master_healthy == false && $slaves_healthy -gt 0 ]] && echo "true" || echo "false" )
}
EOF

    # Output JSON
    cat "$HEALTH_FILE"

    # Log summary
    log_info "Health check completed:"
    log_info "  Master: $MYSQL_MASTER_HOST - $([[ $master_healthy == true ]] && echo "UP" || echo "DOWN")"
    log_info "  Slaves: $slaves_healthy/$total_slaves healthy"

    # Return exit code based on health
    if [[ $master_healthy == false || $slaves_healthy -lt $total_slaves ]]; then
        return 1
    fi
    return 0
}

# =============================================================================
# Main Monitoring Loop
# =============================================================================
monitor() {
    log_info "Starting MySQL failover monitoring..."
    log_info "Configuration:"
    log_info "  Master: $MYSQL_MASTER_HOST"
    log_info "  Slaves: $MYSQL_SLAVE_HOSTS"
    log_info "  Check interval: ${FAILOVER_CHECK_INTERVAL}s"
    log_info "  Failover threshold: $CONSECUTIVE_FAILURES_THRESHOLD failures"

    local consecutive_failures=0

    while true; do
        local current_state
        current_state=$(load_state)
        local current_status
        current_status=$(echo "$current_state" | jq -r '.status')

        # Skip monitoring if already failed over
        if [[ "$current_status" == "failed_over" ]]; then
            log_warning "Already in failed over state. Monitoring but not taking action."
            # Check if master is back online
            if check_master_health; then
                log_info "Master is back online. Manual failback recommended."
                send_alert "INFO" "MySQL master is back online. Manual failback to original topology recommended."
            fi
            sleep "$FAILOVER_CHECK_INTERVAL"
            continue
        fi

        # Perform health check
        if check_master_health; then
            # Master is healthy
            consecutive_failures=0
            save_state "healthy" "Master and all slaves are healthy"

            log_info "Master is healthy - consecutive_failures reset"

            # Check slaves' replication lag
            local warning_count=0
            IFS=',' read -ra SLAVES <<< "$MYSQL_SLAVE_HOSTS"
            for slave in "${SLAVES[@]}"; do
                slave=$(echo "$slave" | xargs)
                local lag
                lag=$(mysql_exec "$slave" -e "SHOW SLAVE STATUS" 2>/dev/null | awk '/Seconds_Behind_Master:/ {print $2}')

                if [[ -n "$lag" && "$lag" != "NULL" && "$lag" -gt "$MAX_REPLICATION_LAG" ]]; then
                    log_warning "Replication lag on $slave: ${lag}s"
                    ((warning_count++))
                fi
            done

            if [[ $warning_count -gt 0 ]]; then
                send_alert "WARNING" "MySQL replication lag detected on $warning_count slave(s)"
            fi

        else
            # Master is unhealthy
            consecutive_failures=$((consecutive_failures + 1))
            log_critical "Master is unhealthy (failure $consecutive_failures/$CONSECUTIVE_FAILURES_THRESHOLD)"

            if [[ $consecutive_failures -ge $CONSECUTIVE_FAILURES_THRESHOLD ]]; then
                log_critical "Master failure threshold reached. Initiating failover..."

                # Check if we have healthy slaves
                local healthiest_slave
                healthiest_slave=$(get_healthiest_slave)

                if [[ -n "$healthiest_slave" ]]; then
                    # Acquire lock and perform failover
                    if acquire_lock; then
                        perform_failover
                        release_lock
                    fi
                else
                    log_error "No healthy slaves available for failover!"
                    send_alert "CRITICAL" "MySQL master is down but no healthy slave for failover"
                fi
            fi
        fi

        sleep "$FAILOVER_CHECK_INTERVAL"
    done
}

# =============================================================================
# Status Display
# =============================================================================
show_status() {
    echo
    echo "=== MySQL Failover Status ==="
    echo

    local state
    state=$(load_state)
    echo "$state" | jq -r '."

    echo
    echo "=== Health Status ==="
    echo
    cat "$HEALTH_FILE" 2>/dev/null || echo "No health data available"
    echo
}

# =============================================================================
# Main
# =============================================================================
main() {
    setup_logging

    local command=${1:-monitor}

    case "$command" in
        monitor)
            monitor
            ;;

        health)
            health_check
            ;;

        failover)
            log_warning "Manual failover triggered..."
            if acquire_lock; then
                perform_failover
                release_lock
            fi
            ;;

        status)
            show_status
            ;;

        reset)
            log_warning "Resetting failover state..."
            rm -f "$STATE_FILE"
            log_success "State reset. Monitoring will start fresh."
            ;;

        *)
            cat <<EOF
MySQL Failover Monitor

Usage: $0 [command] [options]

Commands:
  monitor          Continuous monitoring loop (default)
  health           Single health check (outputs JSON)
  failover         Manual failover trigger
  status           Show current status and health
  reset            Reset failover state

Environment Variables:
  MYSQL_MASTER_HOST           Master host (default: mysql-master)
  MYSQL_SLAVE_HOSTS            Comma-separated slave hosts
  MYSQL_ROOT_PASSWORD          MySQL root password
  FAILOVER_CHECK_INTERVAL    Check interval in seconds (default: 10)
  MAX_REPLICATION_LAG        Max acceptable lag (default: 30)
  ALERT_WEBHOOK              Alert webhook URL
  SLACK_WEBHOOK              Slack webhook URL

Examples:
  $0 monitor
  $0 health
  $0 failover
  $0 status

Output:
  Health check outputs JSON with fields:
  - master.healthy: true/false
  - slaves.total: number
  - slaves.healthy: number
  - overall_status: healthy/degraded
  - can_failover: true/false
EOF
            exit 1
            ;;
    esac
}

main "$@"
