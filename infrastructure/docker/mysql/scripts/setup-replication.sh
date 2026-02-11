#!/bin/bash
# =============================================================================
# MySQL Replication Setup Script
# AGL Hostman - MySQL Master-Slave Replication Automation
# =============================================================================
#
# This script sets up GTID-based MySQL replication with semi-sync replication.
# It creates the replication user, configures the slaves, and verifies the setup.
#
# Usage:
#   ./setup-replication.sh [verify|init|status|reset]
#
# =============================================================================
set -euo pipefail

# =============================================================================
# Configuration
# =============================================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
CONFIG_FILE="$PROJECT_ROOT/mysql/ha/replication-config.env"

# Load configuration
if [[ -f "$CONFIG_FILE" ]]; then
    source "$CONFIG_FILE"
else
    echo "ERROR: Configuration file not found: $CONFIG_FILE"
    exit 1
fi

# Default values
MYSQL_MASTER_HOST="${MYSQL_MASTER_HOST:-mysql-master}"
MYSQL_REPLICATION_USER="${MYSQL_REPLICATION_USER:-replicator}"
MYSQL_REPLICATION_PASSWORD="${MYSQL_REPLICATION_PASSWORD:-}"
MYSQL_ROOT_PASSWORD="${MYSQL_ROOT_PASSWORD:-}"
MYSQL_PORT="${MYSQL_PORT:-3306}"
MYSQL_DATABASE="${MYSQL_DATABASE:-agl_hostman}"

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# =============================================================================
# Logging Functions
# =============================================================================
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# =============================================================================
# MySQL Connection Functions
# =============================================================================
mysql_master_exec() {
    MYSQL_PWD="$MYSQL_ROOT_PASSWORD" mysql -h "$MYSQL_MASTER_HOST" -P "$MYSQL_PORT" -u root "$@" 2>&1
}

mysql_slave_exec() {
    local slave_host=$1
    shift
    MYSQL_PWD="$MYSQL_ROOT_PASSWORD" mysql -h "$slave_host" -P "$MYSQL_PORT" -u root "$@" 2>&1
}

wait_for_mysql() {
    local host=$1
    local max_attempts=30
    local attempt=1

    log_info "Waiting for MySQL at $host to be ready..."
    while [[ $attempt -le $max_attempts ]]; do
        if MYSQL_PWD="$MYSQL_ROOT_PASSWORD" mysqladmin ping -h "$host" -P "$MYSQL_PORT" -u root --silent 2>/dev/null; then
            log_success "MySQL at $host is ready!"
            return 0
        fi
        echo -n "."
        sleep 2
        ((attempt++))
    done
    echo
    log_error "MySQL at $host failed to start after $max_attempts attempts"
    return 1
}

# =============================================================================
# Replication Setup Functions
# =============================================================================
create_replication_user() {
    log_info "Creating replication user on master..."

    local result
    result=$(mysql_master_exec -e "
        CREATE USER IF NOT EXISTS '$MYSQL_REPLICATION_USER'@'%' IDENTIFIED WITH mysql_native_password BY '$MYSQL_REPLICATION_PASSWORD';
        GRANT REPLICATION SLAVE ON *.* TO '$MYSQL_REPLICATION_USER'@'%';
        FLUSH PRIVILEGES;
        SELECT 'Replication user created successfully' AS status;
    " 2>&1)

    if [[ $? -eq 0 ]]; then
        log_success "Replication user created/updated"
        echo "$result"
    else
        log_error "Failed to create replication user"
        echo "$result"
        return 1
    fi
}

get_master_gtid_purged() {
    mysql_master_exec -e "SELECT @@GLOBAL.GTID_PURGED" -s -N 2>/dev/null || echo ""
}

get_master_status() {
    log_info "Getting master status..."
    mysql_master_exec -e "SHOW MASTER STATUS\G" 2>/dev/null || mysql_master_exec -e "SELECT @@GLOBAL.GTID_EXECUTED AS GTID_Executed" -s -N
}

configure_slave() {
    local slave_host=$1
    local server_id=$2

    log_info "Configuring slave: $slave_host (server-id: $server_id)"

    # Wait for slave to be ready
    wait_for_mysql "$slave_host" || return 1

    # Stop existing slave
    mysql_slave_exec "$slave_host" -e "STOP SLAVE;" 2>/dev/null || true
    mysql_slave_exec "$slave_host" -e "RESET SLAVE ALL;" 2>/dev/null || true

    # Get master GTID position
    local master_gtid
    master_gtid=$(get_master_gtid_purged)

    # Configure slave with GTID auto-position
    local result
    result=$(mysql_slave_exec "$slave_host" -e "
        CHANGE MASTER TO
            MASTER_HOST='$MYSQL_MASTER_HOST',
            MASTER_PORT=$MYSQL_PORT,
            MASTER_USER='$MYSQL_REPLICATION_USER',
            MASTER_PASSWORD='$MYSQL_REPLICATION_PASSWORD',
            MASTER_AUTO_POSITION=1;
        START SLAVE;
        SELECT 'Slave started successfully' AS status;
    " 2>&1)

    if [[ $? -eq 0 ]]; then
        log_success "Slave $slave_host configured and started"
    else
        log_error "Failed to configure slave $slave_host"
        echo "$result"
        return 1
    fi
}

# =============================================================================
# Verification Functions
# =============================================================================
check_replication_status() {
    local slave_host=$1

    log_info "Checking replication status for $slave_host..."

    local io_running sql_running lag error_msg
    io_running=$(mysql_slave_exec "$slave_host" -e "SHOW SLAVE STATUS\G" 2>/dev/null | awk '/Slave_IO_Running:/ {print $2}')
    sql_running=$(mysql_slave_exec "$slave_host" -e "SHOW SLAVE STATUS\G" 2>/dev/null | awk '/Slave_SQL_Running:/ {print $2}')
    lag=$(mysql_slave_exec "$slave_host" -e "SHOW SLAVE STATUS\G" 2>/dev/null | awk '/Seconds_Behind_Master:/ {print $2}')
    error_msg=$(mysql_slave_exec "$slave_host" -e "SHOW SLAVE STATUS\G" 2>/dev/null | awk '/Last_Error:/ {for(i=3;i<=NF;i++)printf $i" "}')

    echo -e "\n${BLUE}=== Replication Status: $slave_host ===${NC}"
    echo "  IO Thread:  $io_running"
    echo "  SQL Thread: $sql_running"
    echo "  Lag:        ${lag:-NULL} seconds"

    if [[ "$io_running" == "Yes" && "$sql_running" == "Yes" ]]; then
        log_success "Replication is running on $slave_host"
        return 0
    else
        log_error "Replication is NOT running on $slave_host"
        [[ -n "$error_msg" ]] && echo "  Last Error:  $error_msg"
        return 1
    fi
}

verify_replication() {
    log_info "Verifying replication setup..."

    # Check master
    log_info "Checking master..."
    local master_gtid
    master_gtid=$(mysql_master_exec -e "SELECT @@GLOBAL.GTID_EXECUTED" -s -N 2>/dev/null)

    if [[ -z "$master_gtid" ]]; then
        log_error "Master GTID not available"
        return 1
    fi
    log_success "Master GTID: $master_gtid"

    # Check all slaves
    local all_healthy=true
    for slave in $MYSQL_SLAVE_HOSTS; do
        if ! check_replication_status "$slave"; then
            all_healthy=false
        fi
    done

    if [[ "$all_healthy" == "true" ]]; then
        log_success "All slaves are replicating successfully"
        return 0
    else
        log_error "Some slaves are not replicating properly"
        return 1
    fi
}

# =============================================================================
# Health Check Functions
# =============================================================================
health_check() {
    local master_healthy=false
    local slaves_healthy=0
    local total_slaves=0
    local results=()

    # Check master
    if MYSQL_PWD="$MYSQL_ROOT_PASSWORD" mysqladmin ping -h "$MYSQL_MASTER_HOST" -P "$MYSQL_PORT" -u root --silent 2>/dev/null; then
        master_healthy=true
    fi

    # Check slaves
    for slave in $MYSQL_SLAVE_HOSTS; do
        ((total_slaves++))
        if check_replication_status "$slave" >/dev/null 2>&1; then
            ((slaves_healthy++))
        fi
    done

    # Build JSON output
    cat <<EOF
{
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "master": {
    "host": "$MYSQL_MASTER_HOST",
    "healthy": $master_healthy
  },
  "slaves": {
    "total": $total_slaves,
    "healthy": $slaves_healthy,
    "unhealthy": $((total_slaves - slaves_healthy))
  },
  "overall_status": "$([[ $master_healthy == true && $slaves_healthy == $total_slaves ]] && echo "healthy" || echo "degraded")",
  "can_failover": $( ([[ $master_healthy == false && $slaves_healthy -gt 0 ]] && echo "true" || echo "false"))
}
EOF
}

# =============================================================================
# Reset Functions
# =============================================================================
reset_slave() {
    local slave_host=$1

    log_warning "Resetting slave: $slave_host"
    log_warning "This will stop and remove all replication configuration"

    mysql_slave_exec "$slave_host" -e "
        STOP SLAVE;
        RESET SLAVE ALL;
        SELECT 'Slave reset successfully' AS status;
    " 2>&1

    log_success "Slave $slave_host has been reset"
}

reset_all() {
    log_warning "Resetting all slaves..."
    for slave in $MYSQL_SLAVE_HOSTS; do
        reset_slave "$slave"
    done
    log_success "All slaves have been reset"
}

# =============================================================================
# Main
# =============================================================================
main() {
    local command=${1:-help}

    case "$command" in
        init)
            log_info "Initializing MySQL replication..."
            create_replication_user

            local server_id=2
            for slave in $MYSQL_SLAVE_HOSTS; do
                configure_slave "$slave" "$server_id"
                ((server_id++))
            done

            sleep 5
            verify_replication
            ;;

        verify|status)
            verify_replication
            ;;

        health)
            health_check
            ;;

        reset)
            if [[ -z "${2:-}" ]]; then
                reset_all
            else
                reset_slave "$2"
            fi
            ;;

        gtid)
            get_master_status
            ;;

        help|*)
            cat <<EOF
MySQL Replication Setup Script

Usage: $0 [command] [options]

Commands:
  init              Initialize replication on all slaves
  verify, status    Verify replication status
  health            Output health check JSON
  reset [slave]     Reset slave(s) configuration
  gtid              Show master GTID status

Examples:
  $0 init
  $0 verify
  $0 health
  $0 reset mysql-slave-1

Configuration file: $CONFIG_FILE
EOF
            ;;
    esac
}

main "$@"
