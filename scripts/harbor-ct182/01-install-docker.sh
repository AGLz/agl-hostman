#!/bin/bash
################################################################################
# Harbor CT182 - Docker Installation Script
# Phase 1: Install Docker and Docker Compose
################################################################################

set -euo pipefail

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

log_info "Starting Docker installation on CT182..."

# Update system
log_info "Updating package lists..."
apt-get update

log_info "Installing prerequisites..."
apt-get install -y \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    apt-transport-https \
    software-properties-common

# Add Docker's official GPG key
log_info "Adding Docker GPG key..."
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

# Set up Docker repository
log_info "Adding Docker repository..."
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker
log_info "Installing Docker Engine..."
apt-get update
apt-get install -y \
    docker-ce \
    docker-ce-cli \
    containerd.io \
    docker-buildx-plugin \
    docker-compose-plugin

# Start and enable Docker
log_info "Starting Docker service..."
systemctl enable docker
systemctl start docker

# Verify installation
log_info "Verifying Docker installation..."
docker --version
docker compose version

# Test Docker
log_info "Testing Docker with hello-world..."
docker run --rm hello-world

# Configure Docker for production
log_info "Configuring Docker daemon..."
mkdir -p /etc/docker
cat > /etc/docker/daemon.json << 'EOF'
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m",
    "max-file": "3"
  },
  "storage-driver": "overlay2",
  "live-restore": true,
  "userland-proxy": false
}
EOF

# Restart Docker to apply configuration
log_info "Restarting Docker with new configuration..."
systemctl restart docker

log_info "Docker installation completed successfully!"
docker info | grep -E 'Server Version|Storage Driver|Logging Driver'

exit 0
