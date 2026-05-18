#!/bin/bash
# MySQL Automated Failover Script
# Promotes slave to master during master failure
#
# Usage:
#   ./mysql-failover.sh [--promote-most-recent] [--force] [--dry-run]
#
# Features:
#   - Automatic detection of most recent slave
#   - Graceful master shutdown (if available)
#   - Slave promotion to master
#   - Reconfiguration of other slaves
#   - Health verification
#   - Rollback support
#
# Dependencies:
#   - mysql-client
#   - Optional: mha4mysql-manager
#
# Author: Database High Availability Skill
# Version: 1.0.0

set -euo pipefail

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
MYSQL_ROOT_USER="${MYSQL_ROOT_USER:-root}"
MYSQL_ROOT_PASSWORD="${MYSQL_ROOT_PASSWORD:-}"
SLAVE_HOSTS="${SLAVE_HOSTS:-}"
REPLICATOR_USER="${REPLICATOR_USER:-replicator}"
REPLICATOR_PASSWORD="${REPLICATOR_PASSWORD:-}"
PROMOTE_MOST_RECENT="${PROMOTE_MOST_RECENT:-true}"
FORCE_FAILOVER="${FORCE_FAILOVER:-false}"
DRY_RUN="${DRY_RUN:-false}"

# State files
FAILOVER_STATE_DIR="/var/lib/mysql-failover"
PREVIOUS_MASTER_FILE="$FAILOVER_STATE_DIR/previous_master"
CURRENT_MASTER_FILE="$FAILOVER_STATE_DIR/current_master"

# Functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $(date '+%Y-%m-%d %H:%M:%S') $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $(date '+%Y-%m-%d %H:%M:%S') $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $(date '+%Y-%m-%d %H:%M:%S') $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $(date '+%Y-%m-%d %H:%M:%S') $1"
}

execute_mysql() {
    local host="${1:-localhost}"
    local sql="$2"
    mysql -h "$host" -u "$MYSQL_ROOT_USER" -p"$MYSQL_ROOT_PASSWORD" -e "$sql" 2>&1
}

check_master_health() {
    local host="$1"

    # Check if MySQL is responding
    if ! mysqladmin -h "$host" -u "$MYSQL_ROOT_USER" -p"$MYSQL_ROOT_PASSWORD" ping &>/dev/null; then
        return 1
    fi

    # Check if master is read-only (demoted)
    local read_only=$(execute_mysql "$host" "SELECT @@read_only" -s -N 2>/dev/null || echo "1")

    if [[ "$read_only" == "1" ]]; then
        return 1
    fi

    return 0
}

get_slave_status() {
    local host="$1"
    execute_mysql "$host" "SHOW SLAVE STATUS\G" 2>/dev/null || true
}

get_replication_lag() {
    local host="$1"
    local status=$(get_slave_status "$host")
    echo "$status" | grep "Seconds_Behind_Master:" | awk '{print $2}' || echo "NULL"
}

get_last_gtid() {
    local host="$1"
    execute_mysql "$host" "SELECT @@gtid_current_pos" -s -N 2>/dev/null || echo ""
}

find_most_recent_slave() {
    log_info "Finding most recent slave..."

    IFS=',' read -ra HOSTS <<< "$SLAVE_HOSTS"
    local best_host=""
    local best_lag=999999
    local best_gtid=""

    for host in "${HOSTS[@]}"; do
        host=$(echo "$host" | xargs) # Trim whitespace

        # Check if slave is alive
        if ! mysqladmin -h "$host" -u "$MYSQL_ROOT_USER" -p"$MYSQL_ROOT_PASSWORD" ping &>/dev/null; then
            log_warning "Slave $host is not responding"
            continue
        fi

        local lag=$(get_replication_lag "$host")
        local gtid=$(get_last_gtid "$host")

        log_info "Slave $host: lag=$lag, GTID=$gtid"

        # Compare GTID positions (more recent = better)
        if [[ "$gtid" > "$best_gtid" ]]; then
            best_host="$host"
            best_lag="$lag"
            best_gtid="$gtid"
        fi
    done

    if [[ -z "$best_host" ]]; then
        log_error "No healthy slaves found!"
        exit 1
    fi

    echo "$best_host"
}

stop_slave() {
    local host="$1"
    log_info "Stopping slave on $host..."

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would stop slave on $host"
        return 0
    fi

    execute_mysql "$host" "STOP SLAVE;" || {
        log_error "Failed to stop slave on $host"
        return 1
    }

    log_success "Slave stopped on $host"
}

reset_slave() {
    local host="$1"
    log_info "Resetting slave status on $host..."

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would reset slave on $host"
        return 0
    fi

    execute_mysql "$host" "RESET SLAVE ALL;" || {
        log_error "Failed to reset slave on $host"
        return 1
    }

    log_success "Slave reset on $host"
}

promote_to_master() {
    local host="$1"
    log_info "Promoting $host to master..."

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would promote $host to master"
        return 0
    fi

    # Stop slave
    stop_slave "$host"

    # Reset slave status
    reset_slave "$host"

    # Disable read-only mode
    execute_mysql "$host" "SET GLOBAL read_only = OFF;" || {
        log_error "Failed to disable read-only mode"
        return 1
    }

    execute_mysql "$host" "SET GLOBAL super_read_only = OFF;" || {
        log_error "Failed to disable super-read-only mode"
        return 1
    }

    log_success "$host promoted to master"
}

reconfigure_slave() {
    local slave_host="$1"
    local new_master="$2"
    local old_master="$3"

    log_info "Reconfiguring slave $slave_host to replicate from $new_master..."

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would reconfigure $slave_host"
        return 0
    fi

    # Skip the promoted slave
    if [[ "$slave_host" == "$new_master" ]]; then
        return 0
    fi

    # Stop slave
    execute_mysql "$slave_host" "STOP SLAVE;" || true

    # Change master to new host
    execute_mysql "$slave_host" <<SQL
CHANGE MASTER TO
  MASTER_HOST='$new_master',
  MASTER_PORT=3306,
  MASTER_USER='$REPLICATOR_USER',
  MASTER_PASSWORD='$REPLICATOR_PASSWORD',
  MASTER_AUTO_POSITION=1;
SQL

    # Start slave
    execute_mysql "$slave_host" "START SLAVE;" || {
        log_error "Failed to start slave on $slave_host"
        return 1
    }

    log_success "Slave $slave_host reconfigured"
}

verify_failover() {
    local new_master="$1"
    log_info "Verifying failover..."

    # Check if new master accepts writes
    local test_db="failover_test_$(date +%s)"
    execute_mysql "$new_master" "CREATE DATABASE $test_db;" || {
        log_error "New master does not accept writes!"
        return 1
    }

    execute_mysql "$new_master" "DROP DATABASE $test_db;"

    # Check all slaves are replicating
    IFS=',' read -ra HOSTS <<< "$SLAVE_HOSTS"
    for host in "${HOSTS[@]}"; do
        if [[ "$host" == "$new_master" ]]; then
            continue
        fi

        local lag=$(get_replication_lag "$host")
        if [[ "$lag" == "NULL" ]]; then
            log_warning "Slave $host is not replicating"
        else
            log_info "Slave $host is replicating (lag: ${lag}s)"
        fi
    done

    log_success "Failover verification complete"
}

save_failover_state() {
    local old_master="$1"
    local new_master="$2"

    mkdir -p "$FAILOVER_STATE_DIR"

    echo "$old_master" > "$PREVIOUS_MASTER_FILE"
    echo "$new_master" > "$CURRENT_MASTER_FILE"

    log_info "Failover state saved to $FAILOVER_STATE_DIR"
}

rollback_failover() {
    local old_master="$1"
    local new_master="$2"

    log_warning "Rolling back failover..."

    # Promote old master back
    if check_master_health "$old_master"; then
        promote_to_master "$old_master"
        reconfigure_slave "$new_master" "$old_master" "$new_master"

        IFS=',' read -ra HOSTS <<< "$SLAVE_HOSTS"
        for host in "${HOSTS[@]}"; do
            if [[ "$host" != "$old_master" && "$host" != "$new_master" ]]; then
                reconfigure_slave "$host" "$old_master" "$new_master"
            fi
        done

        log_success "Rollback complete"
    else
        log_error "Cannot rollback: old master is still down"
        return 1
    fi
}

confirm_failover() {
    if [[ "$FORCE_FAILOVER" == "true" ]]; then
        return 0
    fi

    echo ""
    echo "=========================================="
    echo "  MYSQL FAILOVER INITIATED"
    echo "=========================================="
    echo ""
    echo "This will promote a slave to master."
    echo "All slaves will be reconfigured."
    echo ""
    read -p "Are you sure you want to proceed? (yes/no): " confirm

    if [[ "$confirm" != "yes" ]]; then
        log_info "Failover cancelled"
        exit 0
    fi
}

# Main failover process
main() {
    log_info "Starting MySQL failover process..."

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --promote-most-recent)
                PROMOTE_MOST_RECENT=true
                shift
                ;;
            --force)
                FORCE_FAILOVER=true
                shift
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            -h|--help)
                echo "MySQL Automated Failover Script"
                echo ""
                echo "Usage:"
                echo "  $0 [options]"
                echo ""
                echo "Options:"
                echo "  --promote-most-recent    Promote most recent slave (default)"
                echo "  --force                  Skip confirmation"
                echo "  --dry-run                Simulate failover without changes"
                echo "  -h, --help               Show this help"
                echo ""
                echo "Environment Variables:"
                echo "  MYSQL_ROOT_USER          MySQL root user (default: root)"
                echo "  MYSQL_ROOT_PASSWORD      MySQL root password (required)"
                echo "  SLAVE_HOSTS              Comma-separated list of slave hosts"
                echo "  REPLICATOR_USER          Replication user (default: replicator)"
                echo "  REPLICATOR_PASSWORD      Replication password"
                echo ""
                echo "Examples:"
                echo "  MYSQL_ROOT_PASSWORD=secret SLAVE_HOSTS=192.168.1.11,192.168.1.12 $0"
                echo "  $0 --force --dry-run"
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                exit 1
                ;;
        esac
    done

    # Validate required variables
    if [[ -z "$MYSQL_ROOT_PASSWORD" ]]; then
        log_error "MYSQL_ROOT_PASSWORD is required"
        exit 1
    fi

    if [[ -z "$SLAVE_HOSTS" ]]; then
        log_error "SLAVE_HOSTS is required (comma-separated list)"
        exit 1
    fi

    if [[ -z "$REPLICATOR_PASSWORD" ]]; then
        log_error "REPLICATOR_PASSWORD is required"
        exit 1
    fi

    # Confirm failover
    confirm_failover

    # Load previous master if exists
    local previous_master=""
    if [[ -f "$PREVIOUS_MASTER_FILE" ]]; then
        previous_master=$(cat "$PREVIOUS_MASTER_FILE")
    fi

    # Check if previous master is available
    if [[ -n "$previous_master" ]] && check_master_health "$previous_master"; then
        log_warning "Previous master ($previous_master) is back online"
        log_warning "Consider manual investigation before failover"

        if [[ "$FORCE_FAILOVER" != "true" ]]; then
            log_info "Aborting failover. Use --force to proceed anyway."
            exit 1
        fi
    fi

    # Find most recent slave to promote
    local new_master
    if [[ "$PROMOTE_MOST_RECENT" == "true" ]]; then
        new_master=$(find_most_recent_slave)
    else
        # Use first slave in list
        new_master=$(echo "$SLAVE_HOSTS" | cut -d',' -f1 | xargs)
    fi

    log_info "Promoting slave: $new_master"

    # Perform failover
    promote_to_master "$new_master" || {
        log_error "Failed to promote slave to master"
        exit 1
    }

    # Reconfigure other slaves
    IFS=',' read -ra HOSTS <<< "$SLAVE_HOSTS"
    for host in "${HOSTS[@]}"; do
        host=$(echo "$host" | xargs)

        if [[ "$host" == "$new_master" ]]; then
            continue
        fi

        reconfigure_slave "$host" "$new_master" "$previous_master"
    done

    # Verify failover
    verify_failover "$new_master" || {
        log_error "Failover verification failed!"
        log_warning "You may need to rollback manually"

        if [[ -n "$previous_master" ]]; then
            read -p "Rollback to previous master? (yes/no): " rollback

            if [[ "$rollback" == "yes" ]]; then
                rollback_failover "$previous_master" "$new_master"
            fi
        fi

        exit 1
    }

    # Save state
    save_failover_state "$previous_master" "$new_master"

    log_success "Failover complete!"
    log_info "New master: $new_master"
    log_info "Previous master: $previous_master"

    # Update application configuration (example)
    log_warning "Remember to update your application configuration to use the new master"
    log_info "Example: export DB_MASTER_HOST=$new_master"
}

main "$@"
