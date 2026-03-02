#!/bin/bash
################################################################################
# Harbor CT182 - Harbor Deployment Script
# Phase 4: Install and start Harbor services
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

INSTALL_DIR="/opt/harbor"

log_info "Starting Harbor deployment..."

# Verify prerequisites
if ! command -v docker &> /dev/null; then
    log_error "Docker is not installed. Run 01-install-docker.sh first"
    exit 1
fi

if [ ! -f "$INSTALL_DIR/harbor.yml" ]; then
    log_error "Harbor configuration not found. Run 02-install-harbor.sh first"
    exit 1
fi

if [ ! -f "/data/cert/server.crt" ]; then
    log_error "SSL certificates not found. Run 03-configure-ssl.sh first"
    exit 1
fi

cd "$INSTALL_DIR"

# Run Harbor installer
log_info "Running Harbor installer with Trivy scanner..."
./install.sh --with-trivy

# Wait for services to start
log_info "Waiting for Harbor services to start..."
sleep 10

# Check service status
log_info "Checking Harbor service status..."
docker compose ps

# Test Harbor API
HARBOR_HOSTNAME=$(grep '^hostname:' harbor.yml | awk '{print $2}')
log_info "Testing Harbor API..."
sleep 5
curl -k -I https://${HARBOR_HOSTNAME}/ || log_warn "Harbor API not responding yet, may need more time"

log_info "Harbor deployment completed!"
log_info ""
log_info "═══════════════════════════════════════════════════"
log_info "  Harbor Registry Successfully Deployed!"
log_info "═══════════════════════════════════════════════════"
log_info ""
log_info "Access Harbor at: https://${HARBOR_HOSTNAME}"
log_info "Default credentials:"
log_info "  Username: admin"
log_info "  Password: Harbor12345"
log_info ""
log_warn "⚠️  CHANGE THE ADMIN PASSWORD IMMEDIATELY!"
log_info ""
log_info "Next steps:"
log_info "  1. Login and change admin password"
log_info "  2. Run 05-configure-harbor.sh for initial setup"
log_info "  3. Create projects and configure RBAC"
log_info ""

exit 0
