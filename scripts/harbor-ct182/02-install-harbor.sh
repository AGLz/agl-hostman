#!/bin/bash
################################################################################
# Harbor CT182 - Harbor Installation Script
# Phase 2: Download and install Harbor
################################################################################

set -euo pipefail

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Configuration
HARBOR_VERSION="${HARBOR_VERSION:-2.12.2}"
HARBOR_HOSTNAME="${HARBOR_HOSTNAME:-harbor.aglz.io}"
HARBOR_IP="${HARBOR_IP:-192.168.0.182}"
DATA_DIR="/data/registry"
INSTALL_DIR="/opt/harbor"

log_info "Starting Harbor installation..."
log_info "Version: $HARBOR_VERSION"
log_info "Hostname: $HARBOR_HOSTNAME"
log_info "IP: $HARBOR_IP"

# Prepare directories
log_info "Preparing directories..."
mkdir -p "$INSTALL_DIR"
mkdir -p "$DATA_DIR"/{database,redis,job_logs,registry}
chown -R 10000:10000 "$DATA_DIR"

# Download Harbor installer
log_info "Downloading Harbor $HARBOR_VERSION..."
cd /tmp
HARBOR_TAR="harbor-offline-installer-v${HARBOR_VERSION}.tgz"
HARBOR_URL="https://github.com/goharbor/harbor/releases/download/v${HARBOR_VERSION}/${HARBOR_TAR}"

if [ ! -f "$HARBOR_TAR" ]; then
    log_info "Downloading from: $HARBOR_URL"
    curl -L -o "$HARBOR_TAR" "$HARBOR_URL"
else
    log_warn "Harbor tarball already exists, skipping download"
fi

# Extract Harbor
log_info "Extracting Harbor installer..."
tar xzvf "$HARBOR_TAR" -C /opt/

# Generate configuration
log_info "Generating Harbor configuration..."
cd /opt/harbor

# Backup original config if exists
if [ -f harbor.yml ]; then
    cp harbor.yml harbor.yml.bak.$(date +%Y%m%d_%H%M%S)
fi

cp harbor.yml.tmpl harbor.yml

# Configure Harbor
log_info "Configuring Harbor settings..."
sed -i "s/^hostname: .*/hostname: ${HARBOR_HOSTNAME}/" harbor.yml
sed -i "s|^  certificate: .*|  certificate: /data/cert/server.crt|" harbor.yml
sed -i "s|^  private_key: .*|  private_key: /data/cert/server.key|" harbor.yml
sed -i "s|^  location: .*|  location: ${DATA_DIR}/registry|" harbor.yml
sed -i "s|^  password: .*|  password: Harbor12345|" harbor.yml

# Configure data volumes
sed -i "s|^data_volume: .*|data_volume: ${DATA_DIR}|" harbor.yml

# Enable Trivy scanner
sed -i 's/# trivy:/trivy:/' harbor.yml
sed -i '/^trivy:/,/^[^ ]/ s/^  #//g' harbor.yml

# Configure database
sed -i "s|^  location: .*|  location: ${DATA_DIR}/database|" harbor.yml

log_info "Harbor configuration completed"
log_info "Configuration file: /opt/harbor/harbor.yml"

# Note: SSL certificates will be generated in next script
log_warn "Note: SSL certificates need to be configured before running install.sh"
log_warn "Run 03-configure-ssl.sh next"

exit 0
