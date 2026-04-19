#!/bin/bash
# Redis Cluster Setup Script
# Creates a Redis Cluster with sharding and replication
#
# Usage:
#   ./redis-cluster.sh --create|--add-node|--reshard [--nodes=<hosts>] [--replicas=<n>]
#
# Environment Variables:
#   REDIS_CLUSTER_NODES    Comma-separated list of nodes (default: auto-detected)
#   REDIS_CLUSTER_REPLICAS Replicas per master (default: 1)
#   REDIS_PASSWORD         Cluster password
#   REDIS_PORT_BASE        Base port for nodes (default: 7000)
#
# Dependencies:
#   - redis-server (>= 5.0)
#   - redis-cli
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
REDIS_CLUSTER_DIR="/etc/redis/cluster"
REDIS_DATA_DIR="/var/lib/redis/cluster"
REDIS_LOG_DIR="/var/log/redis/cluster"
REDIS_PORT_BASE="${REDIS_PORT_BASE:-7000}"
REDIS_CLUSTER_REPLICAS="${REDIS_CLUSTER_REPLICAS:-1}"
REDIS_PASSWORD="${REDIS_PASSWORD:-}"

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

check_redis_cluster_support() {
    local version=$(redis-server --version | grep -oP 'v=\K[0-9.]+' | cut -d. -f1)

    if [[ "$version" -lt 5 ]]; then
        log_error "Redis 5.0 or higher required for cluster mode"
        log_info "Current version: $version"
        exit 1
    fi
}

create_cluster_node_config() {
    local port=$1
    local node_dir="$REDIS_CLUSTER_DIR/$port"
    local data_dir="$REDIS_DATA_DIR/$port"

    mkdir -p "$node_dir"
    mkdir -p "$data_dir"
    mkdir -p "$REDIS_LOG_DIR"

    cat > "$node_dir/redis.conf" <<EOF
# Redis Cluster Node Configuration

port $port
cluster-enabled yes
cluster-config-file nodes-$port.conf
cluster-node-timeout 5000
cluster-require-full-coverage no

# Network
bind 0.0.0.0
protected-mode no

# General
daemonize yes
pidfile /var/run/redis/cluster-$port.pid
logfile $REDIS_LOG_DIR/cluster-$port.log
dir $data_dir

# Security
$(if [[ -n "$REDIS_PASSWORD" ]]; then
    echo "masterauth $REDIS_PASSWORD"
    echo "requirepass $REDIS_PASSWORD"
fi)

# Persistence
save ""
appendonly yes
appendfilename "appendonly.$port.aof"
appendfsync everysec

# Memory
maxmemory 512mb
maxmemory-policy allkeys-lru

# Performance
tcp-backlog 511
tcp-keepalive 300
EOF

    log_success "Created config for node on port $port"
}

start_cluster_node() {
    local port=$1
    local config="$REDIS_CLUSTER_DIR/$port/redis.conf"

    if redis-server "$config"; then
        log_success "Started cluster node on port $port"
        return 0
    else
        log_error "Failed to start cluster node on port $port"
        return 1
    fi
}

stop_cluster_node() {
    local port=$1

    if redis-cli -p "$port" ${REDIS_PASSWORD:+-a "$REDIS_PASSWORD"} shutdown &>/dev/null; then
        log_success "Stopped cluster node on port $port"
        return 0
    else
        log_warning "Node on port $port was not running"
        return 0
    fi
}

create_local_cluster() {
    local num_nodes="${1:-6}"
    local num_masters=$((num_nodes / (REDIS_CLUSTER_REPLICAS + 1)))
    local node_ports=()

    log_info "Creating local Redis cluster with $num_nodes nodes..."

    check_redis_cluster_support

    # Create configuration for each node
    for ((i = 0; i < num_nodes; i++)); do
        local port=$((REDIS_PORT_BASE + i))
        node_ports+=("$port")
        create_cluster_node_config "$port"
    done

    # Start all nodes
    for port in "${node_ports[@]}"; do
        start_cluster_node "$port"
        sleep 1
    done

    # Wait for nodes to start
    sleep 3

    # Create cluster
    log_info "Creating Redis cluster..."

    local create_cmd="redis-cli --cluster create"
    for ((i = 0; i < num_masters; i++)); do
        local port=$((REDIS_PORT_BASE + i))
        create_cmd+=" 127.0.0.1:$port"
    done

    create_cmd+=" --cluster-replicas $REDIS_CLUSTER_REPLICAS"

    if [[ -n "$REDIS_PASSWORD" ]]; then
        create_cmd+=" -a $REDIS_PASSWORD"
    fi

    create_cmd+=" --cluster-yes"

    if eval "$create_cmd"; then
        log_success "Redis cluster created successfully"
    else
        log_error "Failed to create cluster"
        return 1
    fi

    # Show cluster status
    show_cluster_status "${node_ports[0]}"

    log_success "Local cluster setup complete!"
    log_info "Nodes: ${node_ports[*]}"
}

create_distributed_cluster() {
    local nodes="$1"
    local replicas="${2:-1}"

    log_info "Creating distributed Redis cluster..."

    IFS=',' read -ra NODE_ARRAY <<< "$nodes"
    local master_nodes=()

    # Build node list
    local node_list=""
    for node in "${NODE_ARRAY[@]}"; do
        node=$(echo "$node" | xargs)
        node_list+=" $node"
    done

    # Create cluster
    local create_cmd="redis-cli --cluster create $node_list"
    create_cmd+=" --cluster-replicas $replicas --cluster-yes"

    if [[ -n "$REDIS_PASSWORD" ]]; then
        create_cmd+=" -a $REDIS_PASSWORD"
    fi

    log_info "Executing: $create_cmd"

    if eval "$create_cmd"; then
        log_success "Distributed Redis cluster created"
    else
        log_error "Failed to create distributed cluster"
        return 1
    fi
}

add_node_to_cluster() {
    local new_node="$1"
    local existing_node="$2"

    log_info "Adding node $new_node to cluster..."

    local add_cmd="redis-cli --cluster add-node $new_node $existing_node"

    if [[ -n "$REDIS_PASSWORD" ]]; then
        add_cmd+=" -a $REDIS_PASSWORD"
    fi

    if eval "$add_cmd"; then
        log_success "Node $new_node added to cluster"
    else
        log_error "Failed to add node to cluster"
        return 1
    fi
}

add_replica_to_node() {
    local replica_node="$1"
    local master_node="$2"

    log_info "Adding replica $replica_node to master $master_node..."

    local add_cmd="redis-cli --cluster add-node $replica_node $master_node --cluster-slave"

    if [[ -n "$REDIS_PASSWORD" ]]; then
        add_cmd+=" -a $REDIS_PASSWORD"
    fi

    if eval "$add_cmd"; then
        log_success "Replica $replica_node added"
    else
        log_error "Failed to add replica"
        return 1
    fi
}

reshard_cluster() {
    local target_node="${1:-}"
    local slots="${2:-4096}"

    log_info "Resharding cluster..."

    if [[ -z "$target_node" ]]; then
        # Get first node in cluster
        target_node="127.0.0.1:$REDIS_PORT_BASE"
    fi

    local reshard_cmd="redis-cli --cluster reshard $target_node"
    reshard_cmd+=" --cluster-from all"
    reshard_cmd+=" --cluster-to $target_node"
    reshard_cmd+=" --cluster-slots $slots"
    reshard_cmd+=" --cluster-yes"

    if [[ -n "$REDIS_PASSWORD" ]]; then
        reshard_cmd+=" -a $REDIS_PASSWORD"
    fi

    if eval "$reshard_cmd"; then
        log_success "Cluster resharded"
    else
        log_error "Failed to reshard cluster"
        return 1
    fi
}

rebalance_cluster() {
    log_info "Rebalancing cluster slots..."

    local rebalance_cmd="redis-cli --cluster rebalance 127.0.0.1:$REDIS_PORT_BASE"
    rebalance_cmd+=" --cluster-use-empty-masters"
    rebalance_cmd+=" --cluster-yes"

    if [[ -n "$REDIS_PASSWORD" ]]; then
        rebalance_cmd+=" -a $REDIS_PASSWORD"
    fi

    if eval "$rebalance_cmd"; then
        log_success "Cluster rebalanced"
    else
        log_error "Failed to rebalance cluster"
        return 1
    fi
}

show_cluster_status() {
    local port="${1:-$REDIS_PORT_BASE}"

    log_info "Cluster status for node on port $port:"

    echo ""
    echo "=== Cluster Nodes ==="
    redis-cli -p "$port" ${REDIS_PASSWORD:+-a "$REDIS_PASSWORD"} cluster nodes

    echo ""
    echo "=== Cluster Info ==="
    redis-cli -p "$port" ${REDIS_PASSWORD:+-a "$REDIS_PASSWORD"} cluster info
}

check_cluster_health() {
    local port="${1:-$REDIS_PORT_BASE}"

    log_info "Checking cluster health..."

    # Check if cluster is down
    local cluster_state=$(redis-cli -p "$port" ${REDIS_PASSWORD:+-a "$REDIS_PASSWORD"} cluster info | grep cluster_state | cut -d: -f2 | tr -d '\r')

    if [[ "$cluster_state" == "ok" ]]; then
        log_success "Cluster state: OK"
    else
        log_error "Cluster state: $cluster_state"
        return 1
    fi

    # Check if all slots are covered
    local slots_assigned=$(redis-cli -p "$port" ${REDIS_PASSWORD:+-a "$REDIS_PASSWORD"} cluster info | grep cluster_slots_assigned | cut -d: -f2 | tr -d '\r')
    local slots_ok=$(redis-cli -p "$port" ${REDIS_PASSWORD:+-a "$REDIS_PASSWORD"} cluster info | grep cluster_slots_ok | cut -d: -f2 | tr -d '\r')

    if [[ "$slots_assigned" == "$slots_ok" && "$slots_assigned" == "16384" ]]; then
        log_success "All hash slots covered: $slots_ok/16384"
    else
        log_warning "Hash slots: $slots_ok/16384 assigned"
    fi

    # Check node connectivity
    local known_nodes=$(redis-cli -p "$port" ${REDIS_PASSWORD:+-a "$REDIS_PASSWORD"} cluster info | grep cluster_known_nodes | cut -d: -f2 | tr -d '\r')
    log_info "Known nodes: $known_nodes"
}

remove_node_from_cluster() {
    local node_id="$1"
    local target_node="${2:-127.0.0.1:$REDIS_PORT_BASE}"

    log_info "Removing node $node_id from cluster..."

    local remove_cmd="redis-cli --cluster del-node $target_node $node_id"

    if [[ -n "$REDIS_PASSWORD" ]]; then
        remove_cmd+=" -a $REDIS_PASSWORD"
    fi

    if eval "$remove_cmd"; then
        log_success "Node $node_id removed from cluster"
    else
        log_error "Failed to remove node from cluster"
        return 1
    fi
}

failover_node() {
    local target_node="$1"
    local port="${2:-$REDIS_PORT_BASE}"

    log_info "Triggering failover for node $target_node..."

    # Execute cluster failover
    if redis-cli -p "$port" ${REDIS_PASSWORD:+-a "$REDIS_PASSWORD"} cluster failover &>/dev/null; then
        log_success "Failover initiated for $target_node"
    else
        log_error "Failed to trigger failover"
        return 1
    fi
}

create_systemd_services() {
    local num_nodes="${1:-6}"

    log_info "Creating systemd services for cluster nodes..."

    for ((i = 0; i < num_nodes; i++)); do
        local port=$((REDIS_PORT_BASE + i))
        local config="$REDIS_CLUSTER_DIR/$port/redis.conf"

        cat > "/etc/systemd/system/redis-cluster-node-$i.service" <<EOF
[Unit]
Description=Redis Cluster Node $i (port $port)
After=network.target

[Service]
User=redis
Group=redis
ExecStart=/usr/bin/redis-server $config
ExecStop=/usr/bin/redis-cli -p $port ${REDIS_PASSWORD:+-a $REDIS_PASSWORD} shutdown
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

        systemctl enable "redis-cluster-node-$i"
    done

    systemctl daemon-reload

    log_success "Systemd services created for $num_nodes nodes"
}

# Main script logic
main() {
    local action=""
    local nodes=""
    local replicas="$REDIS_CLUSTER_REPLICAS"

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --create)
                action="create"
                shift
                ;;
            --create-local)
                action="create-local"
                shift
                ;;
            --add-node)
                action="add-node"
                shift
                ;;
            --add-replica)
                action="add-replica"
                shift
                ;;
            --reshard)
                action="reshard"
                shift
                ;;
            --rebalance)
                action="rebalance"
                shift
                ;;
            --status)
                action="status"
                shift
                ;;
            --health)
                action="health"
                shift
                ;;
            --remove-node)
                action="remove-node"
                shift
                ;;
            --failover)
                action="failover"
                shift
                ;;
            --nodes=*)
                nodes="${1#*=}"
                shift
                ;;
            --replicas=*)
                replicas="${1#*=}"
                shift
                ;;
            --port=*)
                REDIS_PORT_BASE="${1#*=}"
                shift
                ;;
            -h|--help)
                echo "Redis Cluster Setup Script"
                echo ""
                echo "Usage:"
                echo "  $0 --create-local                    Create local 6-node cluster"
                echo "  $0 --create --nodes=<hosts>          Create distributed cluster"
                echo "  $0 --add-node --nodes=<new>,<existing>  Add node to cluster"
                echo "  $0 --reshard [--port=<port>]        Reshard cluster"
                echo "  $0 --rebalance                       Rebalance slots"
                echo "  $0 --status [--port=<port>]         Show cluster status"
                echo "  $0 --health [--port=<port>]         Check cluster health"
                echo ""
                echo "Environment Variables:"
                echo "  REDIS_PORT_BASE        Base port for nodes (default: 7000)"
                echo "  REDIS_CLUSTER_REPLICAS Replicas per master (default: 1)"
                echo "  REDIS_PASSWORD         Cluster password"
                echo ""
                echo "Examples:"
                echo "  $0 --create-local"
                echo "  $0 --create --nodes=192.168.1.10:7000,192.168.1.11:7000,192.168.1.12:7000"
                echo "  REDIS_PASSWORD=secret $0 --create-local --replicas=2"
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                exit 1
                ;;
        esac
    done

    # Validate action
    if [[ -z "$action" ]]; then
        log_error "Action required. Use --create, --add-node, --reshard, etc."
        exit 1
    fi

    # Create directories
    mkdir -p "$REDIS_CLUSTER_DIR"
    mkdir -p "$REDIS_DATA_DIR"
    mkdir -p "$REDIS_LOG_DIR"
    chown -R redis:redis "$REDIS_DATA_DIR"
    chown -R redis:redis "$REDIS_LOG_DIR"

    # Execute action
    case "$action" in
        create)
            if [[ -z "$nodes" ]]; then
                log_error "Nodes required for distributed cluster"
                exit 1
            fi
            create_distributed_cluster "$nodes" "$replicas"
            ;;
        create-local)
            create_local_cluster 6
            create_systemd_services 6
            ;;
        add-node)
            IFS=',' read -ra NODE_LIST <<< "$nodes"
            add_node_to_cluster "${NODE_LIST[0]}" "${NODE_LIST[1]}"
            ;;
        add-replica)
            IFS=',' read -ra NODE_LIST <<< "$nodes"
            add_replica_to_node "${NODE_LIST[0]}" "${NODE_LIST[1]}"
            ;;
        reshard)
            reshard_cluster
            ;;
        rebalance)
            rebalance_cluster
            ;;
        status)
            show_cluster_status
            ;;
        health)
            check_cluster_health
            ;;
        remove-node)
            remove_node_from_cluster "$nodes"
            ;;
        failover)
            failover_node "$nodes"
            ;;
        *)
            log_error "Invalid action: $action"
            exit 1
            ;;
    esac
}

main "$@"
