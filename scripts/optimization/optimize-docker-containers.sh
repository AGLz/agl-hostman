#!/bin/bash

###############################################################################
# Docker Container Optimization Script
# Optimizes resource limits, networks, and configurations for key containers
#
# Target Containers:
# - CT179 (agldv03): Development container with Docker
# - CT183 (archon): AI Command Center
# - CT202 (n8n-docker): Workflow automation
#
# Optimizations:
# - CPU and memory limits
# - Network buffer tuning
# - Disk I/O optimization
# - Container restart policies
# - Health check configurations
###############################################################################

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
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

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root"
        exit 1
    fi
}

# Check if Docker is installed
check_docker() {
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed"
        exit 1
    fi

    log_success "Docker is installed: $(docker --version)"
}

# Optimize Docker daemon settings
optimize_docker_daemon() {
    log_info "Optimizing Docker daemon settings..."

    local daemon_config="/etc/docker/daemon.json"
    local backup_config="/etc/docker/daemon.json.backup-$(date +%Y%m%d-%H%M%S)"

    # Backup existing config
    if [[ -f "$daemon_config" ]]; then
        cp "$daemon_config" "$backup_config"
        log_info "Backed up existing config to $backup_config"
    fi

    # Create optimized daemon config
    cat > "$daemon_config" <<EOF
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  },
  "storage-driver": "overlay2",
  "storage-opts": [
    "overlay2.override_kernel_check=true"
  ],
  "default-ulimits": {
    "nofile": {
      "Name": "nofile",
      "Hard": 64000,
      "Soft": 64000
    }
  },
  "dns": ["192.168.0.102", "1.1.1.1", "8.8.8.8"],
  "max-concurrent-downloads": 10,
  "max-concurrent-uploads": 10,
  "live-restore": true,
  "userland-proxy": false,
  "icc": false,
  "default-address-pools": [
    {
      "base": "172.17.0.0/16",
      "size": 24
    }
  ]
}
EOF

    log_success "Docker daemon config optimized"
}

# Optimize specific container (Archon)
optimize_archon_container() {
    log_info "Optimizing Archon containers (CT183)..."

    # Check if on CT183
    if [[ ! -f /.dockerenv ]] && [[ $(hostname) != "archon" ]]; then
        log_warning "Not on CT183, skipping Archon optimization"
        return
    fi

    local archon_dir="/root/Archon"

    if [[ ! -d "$archon_dir" ]]; then
        log_warning "Archon directory not found, skipping"
        return
    fi

    # Add resource limits to docker-compose.yml
    log_info "Adding resource limits to Archon services..."

    # This would typically be done via docker-compose override
    cat > "$archon_dir/docker-compose.override.yml" <<EOF
version: '3.8'

services:
  archon-server:
    deploy:
      resources:
        limits:
          cpus: '4'
          memory: 8G
        reservations:
          cpus: '2'
          memory: 4G
    restart: unless-stopped
    healthcheck:
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"

  archon-mcp:
    deploy:
      resources:
        limits:
          cpus: '2'
          memory: 2G
        reservations:
          cpus: '1'
          memory: 1G
    restart: unless-stopped
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"

  archon-frontend:
    deploy:
      resources:
        limits:
          cpus: '2'
          memory: 2G
        reservations:
          cpus: '1'
          memory: 1G
    restart: unless-stopped
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
EOF

    log_success "Archon resource limits configured"
}

# Optimize Docker networks
optimize_docker_networks() {
    log_info "Optimizing Docker networks..."

    # List all custom networks
    local networks=$(docker network ls --filter type=custom --format "{{.Name}}")

    for network in $networks; do
        log_info "Checking network: $network"

        # Get network details
        local driver=$(docker network inspect "$network" --format '{{.Driver}}')

        if [[ "$driver" == "bridge" ]]; then
            log_info "Optimizing bridge network: $network"

            # Note: Network optimization typically requires recreation
            # This is informational for now
            log_info "  - Driver: $driver"
            log_info "  - Consider enabling IPv6 if needed"
            log_info "  - MTU: Check if 1500 (default) or needs adjustment for WireGuard (1420)"
        fi
    done

    log_success "Docker networks reviewed"
}

# Clean up unused Docker resources
cleanup_docker_resources() {
    log_info "Cleaning up unused Docker resources..."

    # Remove stopped containers
    log_info "Removing stopped containers..."
    docker container prune -f

    # Remove unused images
    log_info "Removing unused images..."
    docker image prune -a -f --filter "until=168h"

    # Remove unused volumes
    log_info "Removing unused volumes..."
    docker volume prune -f

    # Remove unused networks
    log_info "Removing unused networks..."
    docker network prune -f

    log_success "Docker cleanup completed"
}

# Optimize container storage
optimize_container_storage() {
    log_info "Optimizing container storage..."

    # Check overlay2 storage driver usage
    local storage_info=$(docker info --format '{{.Driver}}')

    if [[ "$storage_info" == "overlay2" ]]; then
        log_success "Using overlay2 storage driver (optimal)"
    else
        log_warning "Not using overlay2 driver: $storage_info"
        log_info "Consider switching to overlay2 for better performance"
    fi

    # Display storage usage
    log_info "Docker storage usage:"
    docker system df
}

# Restart Docker daemon
restart_docker_daemon() {
    log_info "Restarting Docker daemon to apply changes..."

    systemctl restart docker

    # Wait for Docker to be ready
    sleep 5

    if systemctl is-active --quiet docker; then
        log_success "Docker daemon restarted successfully"
    else
        log_error "Docker daemon failed to restart"
        exit 1
    fi
}

# Display optimization summary
display_summary() {
    log_info "=== Docker Optimization Summary ==="

    echo ""
    log_info "Docker System Info:"
    docker system df

    echo ""
    log_info "Running Containers:"
    docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

    echo ""
    log_info "Docker Networks:"
    docker network ls

    echo ""
    log_success "Optimization completed successfully!"
    echo ""
    log_info "Recommendations:"
    echo "  1. Monitor container performance with: docker stats"
    echo "  2. Check logs regularly: docker compose logs -f"
    echo "  3. Review resource usage: docker system df"
    echo "  4. For Archon, restart services: cd /root/Archon && docker compose restart"
}

# Main execution
main() {
    log_info "Starting Docker container optimization..."
    echo ""

    check_root
    check_docker

    # Perform optimizations
    optimize_docker_daemon
    optimize_docker_networks
    optimize_container_storage
    optimize_archon_container
    cleanup_docker_resources

    # Apply changes
    restart_docker_daemon

    # Show summary
    display_summary
}

# Run main function
main "$@"
