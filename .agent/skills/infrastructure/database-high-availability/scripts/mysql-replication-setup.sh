#!/bin/bash
# MySQL Replication Setup Script
# Configures master-slave replication with GTID for high availability
#
# Usage:
#   ./mysql-replication-setup.sh --mode=master|slave --master-host=<host> [--replicator-password=<pass>]
#
# Environment Variables:
#   MYSQL_ROOT_PASSWORD - MySQL root password
#   MYSQL_REPLICATOR_PASSWORD - Replication user password (default: auto-generated)
#   MYSQL_SERVER_ID - Unique server ID (default: auto-detected)
#
# Dependencies:
#   - mysql-client
#   - percona-xtrabackup (for initial backup)
#
# Author: Database High Availability Skill
# Version: 1.0.0

set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
MYSQL_CONFIG_FILE="/etc/mysql/mysql.conf.d/mysqld.cnf"
MYSQL_DATA_DIR="/var/lib/mysql"
BACKUP_DIR="/var/lib/mysql-backup"
REPLICATOR_USER="replicator"
REPLICATOR_HOST="%"

# Functions
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

check_mysql_running() {
    if ! systemctl is-active --quiet mysql; then
        log_error "MySQL is not running. Please start MySQL first."
        exit 1
    fi
}

get_mysql_root_password() {
    if [[ -z "${MYSQL_ROOT_PASSWORD:-}" ]]; then
        read -sp "Enter MySQL root password: " MYSQL_ROOT_PASSWORD
        echo
    fi
}

test_mysql_connection() {
    local password=$1
    if mysql -u root -p"$password" -e "SELECT 1" &>/dev/null; then
        return 0
    else
        return 1
    fi
}

generate_password() {
    openssl rand -base64 32 | tr -d "=+/" | cut -c1-32
}

get_server_id() {
    if [[ -n "${MYSQL_SERVER_ID:-}" ]]; then
        echo "$MYSQL_SERVER_ID"
    else
        # Generate server ID from last octet of IP
        hostname -I | awk '{print $1}' | awk -F. '{print $4}'
    fi
}

backup_mysql_config() {
    local timestamp=$(date +%Y%m%d_%H%M%S)
    cp "$MYSQL_CONFIG_FILE" "${MYSQL_CONFIG_FILE}.backup_${timestamp}"
    log_info "Backed up MySQL configuration to ${MYSQL_CONFIG_FILE}.backup_${timestamp}"
}

configure_master() {
    log_info "Configuring MySQL as master..."

    local server_id=$(get_server_id)

    # Backup original config
    backup_mysql_config

    # Configure master settings
    cat > "$MYSQL_CONFIG_FILE" <<EOF
[mysqld]
# Basic settings
server-id = $server_id
bind-address = 0.0.0.0

# Binary logging for replication
log-bin = mysql-bin
binlog-format = ROW
binlog-do-db = laravel
expire_logs_days = 7
max_binlog_size = 100M

# GTID settings
gtid-mode = ON
enforce-gtid-consistency = ON
log_slave_updates = 1

# Sync settings for durability
sync-binlog = 1
innodb_flush_log_at_trx_commit = 1

# Performance
innodb_buffer_pool_size = 1G
max_connections = 500
EOF

    log_success "Master configuration written to $MYSQL_CONFIG_FILE"

    # Restart MySQL
    log_info "Restarting MySQL..."
    systemctl restart mysql

    # Wait for MySQL to start
    sleep 5
    check_mysql_running

    # Create replication user
    log_info "Creating replication user..."
    local replicator_password="${MYSQL_REPLICATOR_PASSWORD:-$(generate_password)}"

    mysql -u root -p"$MYSQL_ROOT_PASSWORD" <<SQL
CREATE USER IF NOT EXISTS '$REPLICATOR_USER'@'$REPLICATOR_HOST' IDENTIFIED WITH mysql_native_password BY '$replicator_password';
GRANT REPLICATION SLAVE ON *.* TO '$REPLICATOR_USER'@'$REPLICATOR_HOST';
FLUSH PRIVILEGES;
SQL

    log_success "Replication user '$REPLICATOR_USER' created"

    # Show master status
    log_info "Master status:"
    mysql -u root -p"$MYSQL_ROOT_PASSWORD" -e "SHOW MASTER STATUS\G"

    # Save credentials for slaves
    cat > "/root/.mysql_replication_credentials" <<EOF
MYSQL_REPLICATOR_USER=$REPLICATOR_USER
MYSQL_REPLICATOR_PASSWORD=$replicator_password
MYSQL_MASTER_HOST=$(hostname -I | awk '{print $1}')
MYSQL_MASTER_PORT=3306
EOF

    chmod 600 "/root/.mysql_replication_credentials"

    log_success "Master configuration complete!"
    log_info "Replication credentials saved to /root/.mysql_replication_credentials"
    log_warning "Share these credentials with slave servers securely"
}

configure_slave() {
    local master_host="$1"
    local replicator_password="${2:-}"

    if [[ -z "$replicator_password" ]]; then
        log_error "Replicator password required for slave configuration"
        log_info "Usage: $0 --mode=slave --master-host=<host> --replicator-password=<pass>"
        exit 1
    fi

    log_info "Configuring MySQL as slave..."

    local server_id=$(get_server_id)

    # Ensure server ID is different from master
    while [[ "$server_id" == "$(get_server_id_from_master "$master_host")" ]]; do
        server_id=$((server_id + 1))
    done

    # Backup original config
    backup_mysql_config

    # Configure slave settings
    cat > "$MYSQL_CONFIG_FILE" <<EOF
[mysqld]
# Basic settings
server-id = $server_id
bind-address = 0.0.0.0

# Relay log settings
relay-log = mysql-relay-bin
relay-log-index = mysql-relay-bin.index
relay-log-recovery = 1

# Read-only settings
read-only = 1
super-read-only = 1

# GTID settings
gtid-mode = ON
enforce-gtid-consistency = ON
log_slave_updates = 1

# Performance
innodb_buffer_pool_size = 1G
max_connections = 500
EOF

    log_success "Slave configuration written to $MYSQL_CONFIG_FILE"

    # Restart MySQL
    log_info "Restarting MySQL..."
    systemctl restart mysql

    # Wait for MySQL to start
    sleep 5
    check_mysql_running

    # Stop slave if already running
    mysql -u root -p"$MYSQL_ROOT_PASSWORD" -e "STOP SLAVE;" 2>/dev/null || true

    # Configure slave to connect to master
    log_info "Configuring slave connection to master at $master_host..."
    mysql -u root -p"$MYSQL_ROOT_PASSWORD" <<SQL
CHANGE MASTER TO
  MASTER_HOST='$master_host',
  MASTER_PORT=3306,
  MASTER_USER='$REPLICATOR_USER',
  MASTER_PASSWORD='$replicator_password',
  MASTER_AUTO_POSITION=1;
SQL

    # Start slave
    log_info "Starting slave..."
    mysql -u root -p"$MYSQL_ROOT_PASSWORD" -e "START SLAVE;"

    # Wait for replication to start
    sleep 3

    # Check slave status
    log_info "Checking slave status..."
    local slave_status=$(mysql -u root -p"$MYSQL_ROOT_PASSWORD" -e "SHOW SLAVE STATUS\G")

    if echo "$slave_status" | grep -q "Slave_IO_Running: Yes" && \
       echo "$slave_status" | grep -q "Slave_SQL_Running: Yes"; then
        log_success "Slave is running and replicating!"
    else
        log_error "Slave failed to start. Check status:"
        echo "$slave_status"
        exit 1
    fi

    # Show replication lag
    local lag=$(echo "$slave_status" | grep "Seconds_Behind_Master" | awk '{print $2}')
    log_info "Replication lag: ${lag} seconds"

    log_success "Slave configuration complete!"
}

get_server_id_from_master() {
    local master_host="$1"
    mysql -h "$master_host" -u "$REPLICATOR_USER" -p"$replicator_password" \
        -e "SELECT @@server_id" -s -N 2>/dev/null || echo "0"
}

take_full_backup() {
    log_info "Taking full backup for slave provisioning..."

    local backup_path="$BACKUP_DIR/full_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$backup_path"

    # Use Percona XtraBackup for hot backup
    if command -v xtrabackup &> /dev/null; then
        log_info "Using Percona XtraBackup..."
        xtrabackup --backup \
            --target-dir="$backup_path" \
            --user=root \
            --password="$MYSQL_ROOT_PASSWORD" \
            --stream=xbstream | gzip > "$backup_path/backup.xbstream.gz"

        log_success "Backup completed: $backup_path"
        log_info "Extract on slave using: cat backup.xbstream.gz | gunzip | xbstream -x"
    else
        log_warning "Percona XtraBackup not found. Using mysqldump..."
        mysqldump -u root -p"$MYSQL_ROOT_PASSWORD" \
            --all-databases \
            --master-data=2 \
            --single-transaction \
            --quick \
            --lock-tables=false | gzip > "$backup_path/mysqldump.sql.gz"

        log_success "Backup completed: $backup_path"
        log_info "Extract on slave using: gunzip < mysqldump.sql.gz | mysql"
    fi
}

check_replication_health() {
    log_info "Checking replication health..."

    local health_check=$(mysql -u root -p"$MYSQL_ROOT_PASSWORD" -e "SHOW SLAVE STATUS\G")

    # Extract key metrics
    local io_running=$(echo "$health_check" | grep "Slave_IO_Running:" | awk '{print $2}')
    local sql_running=$(echo "$health_check" | grep "Slave_SQL_Running:" | awk '{print $2}')
    local lag=$(echo "$health_check" | grep "Seconds_Behind_Master:" | awk '{print $2}')
    local errors=$(echo "$health_check" | grep "Last_Error:" | cut -d: -f2-)

    echo "=== Replication Health Status ==="
    echo "IO Thread: $io_running"
    echo "SQL Thread: $sql_running"
    echo "Replication Lag: ${lag} seconds"

    if [[ -n "$errors" && "$errors" != " " ]]; then
        echo "Last Error: $errors"
    fi

    # Return exit code based on health
    if [[ "$io_running" == "Yes" && "$sql_running" == "Yes" && "$lag" -lt 60 ]]; then
        return 0
    else
        return 1
    fi
}

# Main script logic
main() {
    local mode=""
    local master_host=""
    local replicator_password=""

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --mode=*)
                mode="${1#*=}"
                shift
                ;;
            --master-host=*)
                master_host="${1#*=}"
                shift
                ;;
            --replicator-password=*)
                replicator_password="${1#*=}"
                export MYSQL_REPLICATOR_PASSWORD="$replicator_password"
                shift
                ;;
            --check-health)
                get_mysql_root_password
                check_replication_health
                exit $?
                ;;
            --backup)
                get_mysql_root_password
                check_mysql_running
                take_full_backup
                exit 0
                ;;
            -h|--help)
                echo "MySQL Replication Setup Script"
                echo ""
                echo "Usage:"
                echo "  $0 --mode=master                          Configure as master"
                echo "  $0 --mode=slave --master-host=<host>       Configure as slave"
                echo "  $0 --check-health                         Check replication health"
                echo "  $0 --backup                               Take full backup"
                echo ""
                echo "Environment Variables:"
                echo "  MYSQL_ROOT_PASSWORD           MySQL root password"
                echo "  MYSQL_REPLICATOR_PASSWORD     Replication user password"
                echo "  MYSQL_SERVER_ID               Unique server ID (auto-detected)"
                echo ""
                echo "Examples:"
                echo "  MYSQL_ROOT_PASSWORD=secret $0 --mode=master"
                echo "  MYSQL_ROOT_PASSWORD=secret $0 --mode=slave --master-host=192.168.1.10 --replicator-password=replica_pass"
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                exit 1
                ;;
        esac
    done

    # Validate mode
    if [[ -z "$mode" ]]; then
        log_error "Mode required. Use --mode=master or --mode=slave"
        exit 1
    fi

    # Get MySQL root password
    get_mysql_root_password

    # Test MySQL connection
    if ! test_mysql_connection "$MYSQL_ROOT_PASSWORD"; then
        log_error "Failed to connect to MySQL. Check password."
        exit 1
    fi

    # Execute based on mode
    case "$mode" in
        master)
            check_mysql_running
            configure_master
            ;;
        slave)
            if [[ -z "$master_host" ]]; then
                log_error "Master host required for slave configuration"
                log_info "Usage: $0 --mode=slave --master-host=<host> --replicator-password=<pass>"
                exit 1
            fi
            check_mysql_running
            configure_slave "$master_host" "$replicator_password"
            ;;
        *)
            log_error "Invalid mode: $mode"
            exit 1
            ;;
    esac
}

main "$@"
