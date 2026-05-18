#!/bin/bash
# Redis Sentinel Setup Script
# Configures Redis Sentinel for automatic failover
#
# Usage:
#   ./redis-sentinel.sh --mode=sentinel|master|slave --master-host=<host> [--port=<port>]
#
# Environment Variables:
#   REDIS_PASSWORD              Redis password (default: none)
#   REDIS_SENTINEL_PASSWORD     Sentinel password (default: auto-generated)
#   REDIS_PORT                 Redis port (default: 6379)
#   REDIS_SENTINEL_PORT         Sentinel port (default: 26379)
#   REDIS_QUORUM               Quorum for failover (default: 2)
#
# Dependencies:
#   - redis-server
#   - redis-sentinel
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
REDIS_CONFIG="/etc/redis/redis.conf"
SENTINEL_CONFIG="/etc/redis/sentinel.conf"
SENTINEL_DIR="/etc/redis/sentinel.d"
REDIS_DATA_DIR="/var/lib/redis"
SENTINEL_RUN_DIR="/var/run/redis/sentinel"

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

generate_password() {
    openssl rand -base64 32 | tr -d "=+/" | cut -c1-32
}

check_redis_installed() {
    if ! command -v redis-server &> /dev/null; then
        log_error "Redis is not installed"
        log_info "Install with: sudo apt install redis-server"
        exit 1
    fi
}

check_sentinel_installed() {
    if ! command -v redis-sentinel &> /dev/null && ! command -v redis-server --sentinel &> /dev/null; then
        log_error "Redis Sentinel is not installed"
        log_info "Install with: sudo apt install redis-sentinel"
        exit 1
    fi
}

configure_redis_master() {
    local port="${REDIS_PORT:-6379}"
    local password="${REDIS_PASSWORD:-}"

    log_info "Configuring Redis as master on port $port..."

    # Backup existing config
    if [[ -f "$REDIS_CONFIG" ]]; then
        cp "$REDIS_CONFIG" "${REDIS_CONFIG}.backup_$(date +%Y%m%d_%H%M%S)"
    fi

    # Create Redis master configuration
    cat > "$REDIS_CONFIG" <<EOF
# Redis Master Configuration

# Network
bind 0.0.0.0
port $port
protected-mode no

# General
daemonize yes
pidfile /var/run/redis/redis-server.pid
logfile /var/log/redis/redis-server.log
dir $REDIS_DATA_DIR

# Security
$(if [[ -n "$password" ]]; then
    echo "requirepass $password"
    echo "masterauth $password"
else
    echo "# requirepass (not set)"
fi)

# Replication
repl-diskless-sync yes
repl-diskless-sync-delay 5
repl-ping-slave-period 10
repl-timeout 60
repl-disable-tcp-nodelay no
repl-backlog-size 1mb
repl-backlog-ttl 3600

# Persistence
save 900 1
save 300 10
save 60 10000

appendonly yes
appendfilename "appendonly.aof"
appendfsync everysec

# Memory
maxmemory 1gb
maxmemory-policy allkeys-lru

# Slow log
slowlog-log-slower-than 10000
slowlog-max-len 128
EOF

    # Create data directory
    mkdir -p "$REDIS_DATA_DIR"
    chown redis:redis "$REDIS_DATA_DIR"

    # Restart Redis
    systemctl restart redis-server || systemctl restart redis

    # Wait for Redis to start
    sleep 2

    # Verify Redis is running
    if redis-cli -p "$port" ${password:+-a "$password"} ping &>/dev/null; then
        log_success "Redis master is running"
    else
        log_error "Failed to start Redis master"
        exit 1
    fi

    # Save credentials for sentinel
    cat > "/root/.redis_sentinel_credentials" <<EOF
REDIS_MASTER_HOST=$(hostname -I | awk '{print $1}')
REDIS_MASTER_PORT=$port
REDIS_MASTER_PASSWORD=${password:-}
EOF

    chmod 600 "/root/.redis_sentinel_credentials"

    log_success "Redis master configuration complete"
    log_info "Credentials saved to /root/.redis_sentinel_credentials"
}

configure_redis_slave() {
    local master_host="$1"
    local master_port="${2:-6379}"
    local port="${REDIS_PORT:-6379}"
    local password="${REDIS_PASSWORD:-}"
    local master_password="${3:-$password}"

    log_info "Configuring Redis as slave of $master_host:$master_port..."

    # Backup existing config
    if [[ -f "$REDIS_CONFIG" ]]; then
        cp "$REDIS_CONFIG" "${REDIS_CONFIG}.backup_$(date +%Y%m%d_%H%M%S)"
    fi

    # Create Redis slave configuration
    cat > "$REDIS_CONFIG" <<EOF
# Redis Slave Configuration

# Network
bind 0.0.0.0
port $port
protected-mode no

# General
daemonize yes
pidfile /var/run/redis/redis-server.pid
logfile /var/log/redis/redis-server.log
dir $REDIS_DATA_DIR

# Security
$(if [[ -n "$password" ]]; then
    echo "requirepass $password"
else
    echo "# requirepass (not set)"
fi)

$(if [[ -n "$master_password" ]]; then
    echo "masterauth $master_password"
else
    echo "# masterauth (not set)"
fi)

# Replication
slaveof $master_host $master_port
slave-read-only yes
repl-diskless-sync yes
repl-diskless-sync-delay 5

# Persistence
save ""
appendonly yes
appendfilename "appendonly.aof"
appendfsync everysec

# Memory
maxmemory 1gb
maxmemory-policy allkeys-lru
EOF

    # Create data directory
    mkdir -p "$REDIS_DATA_DIR"
    chown redis:redis "$REDIS_DATA_DIR"

    # Restart Redis
    systemctl restart redis-server || systemctl restart redis

    # Wait for Redis to start
    sleep 2

    # Verify replication
    local role=$(redis-cli -p "$port" ${password:+-a "$password"} ROLE 2>/dev/null | head -n1 || echo "")

    if [[ "$role" == "slave" ]]; then
        log_success "Redis slave is running and replicating"
    else
        log_warning "Redis may not be in slave role. Check logs."
    fi

    log_success "Redis slave configuration complete"
}

configure_sentinel() {
    local master_host="$1"
    local master_port="${2:-6379}"
    local master_password="${3:-}"
    local port="${REDIS_SENTINEL_PORT:-26379}"
    local quorum="${REDIS_QUORUM:-2}"
    local down_after="${REDIS_DOWN_AFTER:-5000}"
    local parallel_syncs="${REDIS_PARALLEL_SYNCS:-1}"
    local failover_timeout="${REDIS_FAILOVER_TIMEOUT:-10000}"
    local sentinel_password="${REDIS_SENTINEL_PASSWORD:-$(generate_password)}"

    log_info "Configuring Redis Sentinel on port $port..."

    check_sentinel_installed

    # Create sentinel config directory
    mkdir -p "$SENTINEL_DIR"
    mkdir -p "$SENTINEL_RUN_DIR"
    chown redis:redis "$SENTINEL_RUN_DIR"

    # Create sentinel configuration
    cat > "$SENTINEL_CONFIG" <<EOF
# Redis Sentinel Configuration

port $port
daemonize yes
pidfile $SENTINEL_RUN_DIR/redis-sentinel.pid
logfile /var/log/redis/sentinel.log
dir $SENTINEL_DIR

$(if [[ -n "$sentinel_password" ]]; then
    echo "sentinel auth-pass mymaster $sentinel_password"
fi)

# Monitor the master
sentinel monitor mymaster $master_host $master_port $quorum

# Failover settings
sentinel down-after-milliseconds mymaster $down_after
sentinel parallel-syncs mymaster $parallel_syncs
sentinel failover-timeout mymaster $failover_timeout

# Notification scripts (optional)
# sentinel notification-script mymaster /var/lib/redis/notify.sh
# sentinel client-reconfig-script mymaster /var/lib/redis/reconfig.sh
EOF

    # Create systemd service
    cat > "/etc/systemd/system/redis-sentinel.service" <<EOF
[Unit]
Description=Redis Sentinel
After=network.target

[Service]
User=redis
Group=redis
ExecStart=/usr/bin/redis-sentinel $SENTINEL_CONFIG
ExecStop=/usr/bin/redis-cli -p $port shutdown
Restart=always

[Install]
WantedBy=multi-user.target
EOF

    # Reload systemd
    systemctl daemon-reload

    # Start sentinel
    systemctl enable redis-sentinel
    systemctl restart redis-sentinel

    # Wait for sentinel to start
    sleep 2

    # Verify sentinel is running
    if redis-cli -p "$port" ping &>/dev/null; then
        log_success "Redis Sentinel is running"
    else
        log_error "Failed to start Redis Sentinel"
        exit 1
    fi

    # Check sentinel masters
    log_info "Checking monitored masters:"
    redis-cli -p "$port" SENTINEL masters

    # Save sentinel credentials
    cat > "/root/.redis_sentinel_credentials" <<EOF
REDIS_SENTINEL_PORT=$port
REDIS_SENTINEL_PASSWORD=$sentinel_password
REDIS_MASTER_HOST=$master_host
REDIS_MASTER_PORT=$master_port
EOF

    chmod 600 "/root/.redis_sentinel_credentials"

    log_success "Redis Sentinel configuration complete"
}

test_failover() {
    local port="${REDIS_SENTINEL_PORT:-26379}"

    log_info "Testing Sentinel failover..."

    # Check sentinel status
    log_info "Sentinel masters:"
    redis-cli -p "$port" SENTINEL masters

    log_info "Sentinel slaves:"
    redis-cli -p "$port" SENTINEL slaves mymaster

    log_warning "To simulate master failure, run:"
    log_info "  redis-cli DEBUG SLEEP 30"
    log_info "Then monitor sentinel logs:"
    log_info "  journalctl -u redis-sentinel -f"
}

setup_multiple_sentinels() {
    local master_host="$1"
    local master_port="${2:-6379}"
    local master_password="${3:-}"
    local base_port="${REDIS_SENTINEL_PORT:-26379}"

    log_info "Setting up 3 sentinel instances..."

    for i in 1 2 3; do
        local port=$((base_port + i - 1))
        local config="$SENTINEL_DIR/sentinel$i.conf"

        mkdir -p "$SENTINEL_DIR"

        cat > "$config" <<EOF
port $port
daemonize yes
pidfile $SENTINEL_RUN_DIR/redis-sentinel$i.pid
logfile /var/log/redis/sentinel$i.log
dir $SENTINEL_DIR

sentinel monitor mymaster $master_host $master_port 2
sentinel down-after-milliseconds mymaster 5000
sentinel parallel-syncs mymaster 1
sentinel failover-timeout mymaster 10000
EOF

        # Create systemd service
        cat > "/etc/systemd/system/redis-sentinel$i.service" <<EOF
[Unit]
Description=Redis Sentinel $i
After=network.target

[Service]
User=redis
Group=redis
ExecStart=/usr/bin/redis-sentinel $config
ExecStop=/usr/bin/redis-cli -p $port shutdown
Restart=always

[Install]
WantedBy=multi-user.target
EOF

        systemctl enable "redis-sentinel$i"
        systemctl restart "redis-sentinel$i"

        log_success "Sentinel $i started on port $port"
    done

    log_success "3 sentinel instances configured"
    log_info "Monitor with: redis-cli -p $base_port SENTINEL masters"
}

# Main script logic
main() {
    local mode=""
    local master_host=""
    local master_port="6379"

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
            --master-port=*)
                master_port="${1#*=}"
                shift
                ;;
            --port=*)
                REDIS_PORT="${1#*=}"
                shift
                ;;
            --sentinel-port=*)
                REDIS_SENTINEL_PORT="${1#*=}"
                shift
                ;;
            --test-failover)
                test_failover
                exit 0
                ;;
            --multi-sentinel)
                setup_multiple_sentinels "$master_host" "$master_port"
                exit 0
                ;;
            -h|--help)
                echo "Redis Sentinel Setup Script"
                echo ""
                echo "Usage:"
                echo "  $0 --mode=master                          Configure Redis as master"
                echo "  $0 --mode=slave --master-host=<host>      Configure Redis as slave"
                echo "  $0 --mode=sentinel --master-host=<host>   Configure Sentinel"
                echo "  $0 --multi-sentinel --master-host=<host>  Setup 3 sentinel instances"
                echo "  $0 --test-failover                        Test sentinel failover"
                echo ""
                echo "Environment Variables:"
                echo "  REDIS_PASSWORD              Redis password"
                echo "  REDIS_SENTINEL_PASSWORD     Sentinel password"
                echo "  REDIS_PORT                  Redis port (default: 6379)"
                echo "  REDIS_SENTINEL_PORT          Sentinel port (default: 26379)"
                echo "  REDIS_QUORUM                Quorum for failover (default: 2)"
                echo ""
                echo "Examples:"
                echo "  $0 --mode=master"
                echo "  $0 --mode=slave --master-host=192.168.1.10"
                echo "  REDIS_PASSWORD=secret $0 --mode=sentinel --master-host=192.168.1.10"
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
        log_error "Mode required. Use --mode=master|slave|sentinel"
        exit 1
    fi

    check_redis_installed

    # Execute based on mode
    case "$mode" in
        master)
            configure_redis_master
            ;;
        slave)
            if [[ -z "$master_host" ]]; then
                log_error "Master host required for slave configuration"
                exit 1
            fi
            configure_redis_slave "$master_host" "$master_port"
            ;;
        sentinel)
            if [[ -z "$master_host" ]]; then
                log_error "Master host required for sentinel configuration"
                exit 1
            fi
            configure_sentinel "$master_host" "$master_port"
            ;;
        *)
            log_error "Invalid mode: $mode"
            exit 1
            ;;
    esac
}

main "$@"
