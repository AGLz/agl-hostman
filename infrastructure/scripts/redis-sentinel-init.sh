#!/bin/bash
# =============================================================================
# Redis Sentinel HA Initialization Script for AGL Hostman
# =============================================================================
# Deploys complete Redis HA with Sentinel, 1 master, 3 slaves, 3 sentinels
#
# Usage:
#   ./redis-sentinel-init.sh deploy      Deploy full HA cluster
#   ./redis-sentinel-init.sh start       Start all services
#   ./redis-sentinel-init.sh stop        Stop all services
#   ./redis-sentinel-init.sh status      Check cluster status
#   ./redis-sentinel-init.sh test        Test failover
#   ./redis-sentinel-init.sh destroy     Destroy cluster
#
# Environment Variables:
#   REDIS_PASSWORD          Redis password (required for production)
#   COMPOSE_PROJECT_NAME   Docker Compose project name
#   MASTER_PORT            Master Redis port (default: 6379)
#   SLAVE_PORTS            Comma-separated slave ports (default: 6380,6381,6382)
#   SENTINEL_PORTS         Comma-separated sentinel ports (default: 26379,26380,26381)
#
# Author: Database High Availability Skill
# Version: 2.0.0

set -euo pipefail

# =============================================================================
# Configuration
# =============================================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
COMPOSE_FILE="$PROJECT_ROOT/docker/docker-compose.redis-ha.yml"

REDIS_PASSWORD="${REDIS_PASSWORD:-agl_redis_ha_$(openssl rand -hex 8)}"
COMPOSE_PROJECT_NAME="${COMPOSE_PROJECT_NAME:-redis-ha}"
MASTER_PORT="${MASTER_PORT:-6379}"
SLAVE_PORTS="${SLAVE_PORTS:-6380,6381,6382}"
SENTINEL_PORTS="${SENTINEL_PORTS:-26379,26380,26381}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# =============================================================================
# Logging Functions
# =============================================================================
log() {
    local level=$1
    shift
    echo -e "${BLUE}[$(date '+%H:%M:%S')]${NC} [$level] $@"
}

log_info() { log "INFO" "$@"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $@"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $@"; }
log_error() { echo -e "${RED}[ERROR]${NC} $@"; }

# =============================================================================
# Docker Compose File Generator
# =============================================================================
generate_compose_file() {
    cat > "$COMPOSE_FILE" <<'EOF'
# =============================================================================
# Docker Compose - Redis High Availability with Sentinel
# AGL Hostman - 1 Master, 3 Slaves, 3 Sentinels
# =============================================================================
# Architecture:
#   1 Redis Master (read-write)
#   3 Redis Slaves (read-only replicas)
#   3 Redis Sentinels (automatic failover coordination)
#
# Usage:
#   docker compose -f docker-compose.redis-ha.yml up -d
#   docker compose -f docker-compose.redis-ha.yml down
# =============================================================================

version: '3.8'

services:
  # =============================================================================
  # Redis Master
  # =============================================================================
  redis-master:
    image: redis:7-alpine
    container_name: ${COMPOSE_PROJECT_NAME}-master
    restart: unless-stopped
    command: redis-server /usr/local/etc/redis/redis.conf
    ports:
      - "${MASTER_PORT:-6379}:6379"
    volumes:
      - redis-master-data:/data
      - ./infrastructure/redis-sentinel/redis-master-ha.conf:/usr/local/etc/redis/redis.conf:ro
    networks:
      - redis-ha
    environment:
      - REDIS_PASSWORD=${REDIS_PASSWORD}
    healthcheck:
      test: ["CMD", "redis-cli", "-a", "${REDIS_PASSWORD}", "ping"]
      interval: 5s
      timeout: 3s
      retries: 5
      start_period: 10s
    deploy:
      resources:
        limits:
          cpus: '1'
          memory: 1G
        reservations:
          cpus: '0.25'
          memory: 256M

  # =============================================================================
  # Redis Slave 1
  # =============================================================================
  redis-slave-1:
    image: redis:7-alpine
    container_name: ${COMPOSE_PROJECT_NAME}-slave-1
    restart: unless-stopped
    command: >
      sh -c '
        echo "replicaof redis-master 6379" >> /usr/local/etc/redis/redis.conf &&
        echo "masterauth ${REDIS_PASSWORD}" >> /usr/local/etc/redis/redis.conf &&
        redis-server /usr/local/etc/redis/redis.conf
      '
    ports:
      - "${SLAVE_PORT_1:-6380}:6379"
    volumes:
      - redis-slave-1-data:/data
      - ./infrastructure/redis-sentinel/redis-slave-ha.conf:/usr/local/etc/redis/redis-template.conf:ro
    networks:
      - redis-ha
    environment:
      - REDIS_PASSWORD=${REDIS_PASSWORD}
    depends_on:
      redis-master:
        condition: service_healthy
    healthcheck:
      test: ["CMD", "redis-cli", "-a", "${REDIS_PASSWORD}", "ping"]
      interval: 5s
      timeout: 3s
      retries: 5
      start_period: 10s
    deploy:
      resources:
        limits:
          cpus: '0.5'
          memory: 512M
        reservations:
          cpus: '0.1'
          memory: 128M

  # =============================================================================
  # Redis Slave 2
  # =============================================================================
  redis-slave-2:
    image: redis:7-alpine
    container_name: ${COMPOSE_PROJECT_NAME}-slave-2
    restart: unless-stopped
    command: >
      sh -c '
        echo "replicaof redis-master 6379" >> /usr/local/etc/redis/redis.conf &&
        echo "masterauth ${REDIS_PASSWORD}" >> /usr/local/etc/redis/redis.conf &&
        redis-server /usr/local/etc/redis/redis.conf
      '
    ports:
      - "${SLAVE_PORT_2:-6381}:6379"
    volumes:
      - redis-slave-2-data:/data
      - ./infrastructure/redis-sentinel/redis-slave-ha.conf:/usr/local/etc/redis/redis-template.conf:ro
    networks:
      - redis-ha
    environment:
      - REDIS_PASSWORD=${REDIS_PASSWORD}
    depends_on:
      redis-master:
        condition: service_healthy
    healthcheck:
      test: ["CMD", "redis-cli", "-a", "${REDIS_PASSWORD}", "ping"]
      interval: 5s
      timeout: 3s
      retries: 5
      start_period: 10s
    deploy:
      resources:
        limits:
          cpus: '0.5'
          memory: 512M
        reservations:
          cpus: '0.1'
          memory: 128M

  # =============================================================================
  # Redis Slave 3
  # =============================================================================
  redis-slave-3:
    image: redis:7-alpine
    container_name: ${COMPOSE_PROJECT_NAME}-slave-3
    restart: unless-stopped
    command: >
      sh -c '
        echo "replicaof redis-master 6379" >> /usr/local/etc/redis/redis.conf &&
        echo "masterauth ${REDIS_PASSWORD}" >> /usr/local/etc/redis/redis.conf &&
        redis-server /usr/local/etc/redis/redis.conf
      '
    ports:
      - "${SLAVE_PORT_3:-6382}:6379"
    volumes:
      - redis-slave-3-data:/data
      - ./infrastructure/redis-sentinel/redis-slave-ha.conf:/usr/local/etc/redis/redis-template.conf:ro
    networks:
      - redis-ha
    environment:
      - REDIS_PASSWORD=${REDIS_PASSWORD}
    depends_on:
      redis-master:
        condition: service_healthy
    healthcheck:
      test: ["CMD", "redis-cli", "-a", "${REDIS_PASSWORD}", "ping"]
      interval: 5s
      timeout: 3s
      retries: 5
      start_period: 10s
    deploy:
      resources:
        limits:
          cpus: '0.5'
          memory: 512M
        reservations:
          cpus: '0.1'
          memory: 128M

  # =============================================================================
  # Redis Sentinel 1
  # =============================================================================
  redis-sentinel-1:
    image: redis:7-alpine
    container_name: ${COMPOSE_PROJECT_NAME}-sentinel-1
    restart: unless-stopped
    command: >
      sh -c '
        envsubst < /etc/redis/sentinel-template.conf > /etc/redis/sentinel.conf &&
        redis-sentinel /etc/redis/sentinel.conf
      '
    ports:
      - "${SENTINEL_PORT_1:-26379}:26379"
    volumes:
      - sentinel-1-data:/data
      - ./infrastructure/redis-sentinel/sentinel-1.conf:/etc/redis/sentinel-template.conf:ro
      - ./infrastructure/scripts/redis-failover-notify.sh:/etc/redis/sentinel-failover-notify.sh:ro
    networks:
      - redis-ha
    environment:
      - REDIS_PASSWORD=${REDIS_PASSWORD}
    depends_on:
      redis-master:
        condition: service_healthy
    healthcheck:
      test: ["CMD", "redis-cli", "-p", "26379", "ping"]
      interval: 5s
      timeout: 3s
      retries: 5
      start_period: 10s
    deploy:
      resources:
        limits:
          cpus: '0.25'
          memory: 256M
        reservations:
          cpus: '0.1'
          memory: 64M

  # =============================================================================
  # Redis Sentinel 2
  # =============================================================================
  redis-sentinel-2:
    image: redis:7-alpine
    container_name: ${COMPOSE_PROJECT_NAME}-sentinel-2
    restart: unless-stopped
    command: >
      sh -c '
        envsubst < /etc/redis/sentinel-template.conf > /etc/redis/sentinel.conf &&
        redis-sentinel /etc/redis/sentinel.conf
      '
    ports:
      - "${SENTINEL_PORT_2:-26380}:26379"
    volumes:
      - sentinel-2-data:/data
      - ./infrastructure/redis-sentinel/sentinel-2.conf:/etc/redis/sentinel-template.conf:ro
      - ./infrastructure/scripts/redis-failover-notify.sh:/etc/redis/sentinel-failover-notify.sh:ro
    networks:
      - redis-ha
    environment:
      - REDIS_PASSWORD=${REDIS_PASSWORD}
    depends_on:
      redis-master:
        condition: service_healthy
    healthcheck:
      test: ["CMD", "redis-cli", "-p", "26379", "ping"]
      interval: 5s
      timeout: 3s
      retries: 5
      start_period: 10s
    deploy:
      resources:
        limits:
          cpus: '0.25'
          memory: 256M
        reservations:
          cpus: '0.1'
          memory: 64M

  # =============================================================================
  # Redis Sentinel 3
  # =============================================================================
  redis-sentinel-3:
    image: redis:7-alpine
    container_name: ${COMPOSE_PROJECT_NAME}-sentinel-3
    restart: unless-stopped
    command: >
      sh -c '
        envsubst < /etc/redis/sentinel-template.conf > /etc/redis/sentinel.conf &&
        redis-sentinel /etc/redis/sentinel.conf
      '
    ports:
      - "${SENTINEL_PORT_3:-26381}:26379"
    volumes:
      - sentinel-3-data:/data
      - ./infrastructure/redis-sentinel/sentinel-3.conf:/etc/redis/sentinel-template.conf:ro
      - ./infrastructure/scripts/redis-failover-notify.sh:/etc/redis/sentinel-failover-notify.sh:ro
    networks:
      - redis-ha
    environment:
      - REDIS_PASSWORD=${REDIS_PASSWORD}
    depends_on:
      redis-master:
        condition: service_healthy
    healthcheck:
      test: ["CMD", "redis-cli", "-p", "26379", "ping"]
      interval: 5s
      timeout: 3s
      retries: 5
      start_period: 10s
    deploy:
      resources:
        limits:
          cpus: '0.25'
          memory: 256M
        reservations:
          cpus: '0.1'
          memory: 64M

  # =============================================================================
  # Redis Exporter (Prometheus Metrics)
  # =============================================================================
  redis-exporter:
    image: oliver006/redis_exporter:latest
    container_name: ${COMPOSE_PROJECT_NAME}-exporter
    restart: unless-stopped
    ports:
      - "9121:9121"
    networks:
      - redis-ha
    environment:
      - REDIS_ADDR=redis-master:6379
      - REDIS_PASSWORD=${REDIS_PASSWORD}
      - REDIS_EXPORTER_LOG_LEVEL=info
    depends_on:
      - redis-master
    deploy:
      resources:
        limits:
          cpus: '0.25'
          memory: 128M
        reservations:
          cpus: '0.1'
          memory: 64M

# =============================================================================
# Networks
# =============================================================================
networks:
  redis-ha:
    name: ${COMPOSE_PROJECT_NAME}
    driver: bridge

# =============================================================================
# Volumes
# =============================================================================
volumes:
  redis-master-data:
    name: ${COMPOSE_PROJECT_NAME}-master-data
    driver: local
  redis-slave-1-data:
    name: ${COMPOSE_PROJECT_NAME}-slave-1-data
    driver: local
  redis-slave-2-data:
    name: ${COMPOSE_PROJECT_NAME}-slave-2-data
    driver: local
  redis-slave-3-data:
    name: ${COMPOSE_PROJECT_NAME}-slave-3-data
    driver: local
  sentinel-1-data:
    name: ${COMPOSE_PROJECT_NAME}-sentinel-1-data
    driver: local
  sentinel-2-data:
    name: ${COMPOSE_PROJECT_NAME}-sentinel-2-data
    driver: local
  sentinel-3-data:
    name: ${COMPOSE_PROJECT_NAME}-sentinel-3-data
    driver: local
EOF

    log_success "Generated Docker Compose file: $COMPOSE_FILE"
}

# =============================================================================
# Commands
# =============================================================================
deploy_cluster() {
    log_info "Deploying Redis HA cluster..."

    # Generate compose file
    generate_compose_file

    # Create Docker network if not exists
    if ! docker network ls | grep -q "$COMPOSE_PROJECT_NAME"; then
        docker network create "$COMPOSE_PROJECT_NAME" || true
    fi

    # Deploy using docker compose
    docker compose -f "$COMPOSE_FILE" -p "$COMPOSE_PROJECT_NAME" up -d

    # Wait for services to be healthy
    log_info "Waiting for services to become healthy..."
    sleep 15

    # Verify deployment
    check_cluster_status

    log_success "Redis HA cluster deployed successfully"
    log_info "Master: localhost:$MASTER_PORT"
    log_info "Sentinels: localhost:26379, localhost:26380, localhost:26381"

    # Save credentials
    cat > "$PROJECT_ROOT/.redis-ha-credentials.env" <<EOF
# Redis HA Credentials - Generated $(date -u +%Y-%m-%dT%H:%M:%SZ)
REDIS_PASSWORD=$REDIS_PASSWORD
REDIS_MASTER_HOST=localhost
REDIS_MASTER_PORT=$MASTER_PORT
REDIS_SENTINEL_HOSTS=localhost:26379,localhost:26380,localhost:26381
REDIS_SENTINEL_MASTER=aglmaster
EOF

    log_success "Credentials saved to: $PROJECT_ROOT/.redis-ha-credentials.env"
}

start_cluster() {
    log_info "Starting Redis HA cluster..."
    docker compose -f "$COMPOSE_FILE" -p "$COMPOSE_PROJECT_NAME" start
    log_success "Cluster started"
}

stop_cluster() {
    log_info "Stopping Redis HA cluster..."
    docker compose -f "$COMPOSE_FILE" -p "$COMPOSE_PROJECT_NAME" stop
    log_success "Cluster stopped"
}

restart_cluster() {
    log_info "Restarting Redis HA cluster..."
    docker compose -f "$COMPOSE_FILE" -p "$COMPOSE_PROJECT_NAME" restart
    log_success "Cluster restarted"
}

destroy_cluster() {
    log_warning "Destroying Redis HA cluster..."
    docker compose -f "$COMPOSE_FILE" -p "$COMPOSE_PROJECT_NAME" down -v

    # Remove network
    docker network rm "$COMPOSE_PROJECT_NAME" 2>/dev/null || true

    log_success "Cluster destroyed"
    log_warning "Data volumes have been removed"
}

check_cluster_status() {
    log_info "Checking Redis HA cluster status..."
    echo ""

    # Check containers
    local running_containers
    running_containers=$(docker compose -f "$COMPOSE_FILE" -p "$COMPOSE_PROJECT_NAME" ps -q | wc -l)

    echo "=== Container Status ==="
    docker compose -f "$COMPOSE_FILE" -p "$COMPOSE_PROJECT_NAME" ps
    echo ""

    # Check master
    echo "=== Master Status ==="
    if redis-cli -h localhost -p "$MASTER_PORT" -a "$REDIS_PASSWORD" --no-auth-warning PING 2>/dev/null | grep -q PONG; then
        echo "Master: OK"
        redis-cli -h localhost -p "$MASTER_PORT" -a "$REDIS_PASSWORD" --no-auth-warning INFO replication 2>/dev/null | grep -E "^role:|^connected_slaves:"
    else
        echo "Master: FAILED"
    fi
    echo ""

    # Check sentinels
    echo "=== Sentinel Status ==="
    local sentinel_ports="26379 26380 26381"
    for port in $sentinel_ports; do
        if redis-cli -h localhost -p "$port" PING 2>/dev/null | grep -q PONG; then
            echo "Sentinel $port: OK"
            redis-cli -h localhost -p "$port" SENTINEL master aglmaster 2>/dev/null | grep -E "name=|flags=|num-other-sentinels="
        else
            echo "Sentinel $port: FAILED"
        fi
    done
    echo ""

    # Check replication
    echo "=== Replication Status ==="
    redis-cli -h localhost -p 26379 SENTINEL slaves aglmaster 2>/dev/null | grep -E "name=|role=|linked-master=|master-link-status="
    echo ""
}

test_failover() {
    log_warning "Starting failover test..."

    # Check current master
    local current_master
    current_master=$(redis-cli -h localhost -p 26379 SENTINEL get-master-addr-by-name aglmaster 2>/dev/null | head -n1)
    log_info "Current master: $current_master"

    # Stop master to trigger failover
    log_info "Stopping master container to trigger failover..."
    docker stop "${COMPOSE_PROJECT_NAME}-master"

    # Wait for failover
    log_info "Waiting for Sentinel to promote a new master..."
    sleep 10

    # Check new master
    local new_master
    new_master=$(redis-cli -h localhost -p 26379 SENTINEL get-master-addr-by-name aglmaster 2>/dev/null | head -n1)

    if [[ "$new_master" != "$current_master" ]]; then
        log_success "Failover successful! New master: $new_master"
    else
        log_error "Failover did not occur"
    fi

    # Restart original master
    log_info "Restarting original master..."
    docker start "${COMPOSE_PROJECT_NAME}-master"
    sleep 5

    # Check final status
    check_cluster_status
}

# =============================================================================
# Main
# =============================================================================
main() {
    local command=${1:-deploy}

    case "$command" in
        deploy)
            deploy_cluster
            ;;
        start)
            start_cluster
            ;;
        stop)
            stop_cluster
            ;;
        restart)
            restart_cluster
            ;;
        status)
            check_cluster_status
            ;;
        test)
            test_failover
            ;;
        destroy)
            destroy_cluster
            ;;
        *)
            echo "Usage: $0 {deploy|start|stop|restart|status|test|destroy}"
            echo ""
            echo "Commands:"
            echo "  deploy   Deploy full HA cluster (1 master, 3 slaves, 3 sentinels)"
            echo "  start    Start all services"
            echo "  stop     Stop all services"
            echo "  restart  Restart all services"
            echo "  status   Check cluster status"
            echo "  test     Test automatic failover"
            echo "  destroy  Remove cluster and data volumes"
            exit 1
            ;;
    esac
}

main "$@"
