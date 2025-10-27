#!/bin/bash
#
# Harbor CT182 Remote Deployment Wrapper
# Deploys Harbor to aglsrv1 Proxmox host from remote location
#
# Usage: ./deploy-remote.sh [aglsrv1-ip]
#

set -euo pipefail

# Configuration
AGLSRV1_HOST="${1:-aglsrv1}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REMOTE_TEMP_DIR="/tmp/harbor-ct182-deploy-$(date +%s)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

# Check if we can reach aglsrv1
log_info "Checking connectivity to $AGLSRV1_HOST..."
if ! ping -c 2 "$AGLSRV1_HOST" &>/dev/null; then
    log_error "Cannot reach $AGLSRV1_HOST"
    log_warn "Please ensure:"
    log_warn "  1. aglsrv1 is running and accessible"
    log_warn "  2. Network connectivity is working"
    log_warn "  3. Host is correct (current: $AGLSRV1_HOST)"
    exit 1
fi
log_success "Host $AGLSRV1_HOST is reachable"

# Check SSH connectivity
log_info "Checking SSH connectivity..."
if ! ssh -o ConnectTimeout=5 -o BatchMode=yes root@"$AGLSRV1_HOST" "echo SSH_OK" &>/dev/null; then
    log_error "Cannot SSH to root@$AGLSRV1_HOST"
    log_warn "Please ensure:"
    log_warn "  1. SSH service is running on aglsrv1"
    log_warn "  2. SSH keys are configured (or run: ssh-copy-id root@$AGLSRV1_HOST)"
    log_warn "  3. Root access is enabled"
    exit 1
fi
log_success "SSH connectivity confirmed"

# Verify Proxmox host
log_info "Verifying Proxmox environment on $AGLSRV1_HOST..."
if ! ssh root@"$AGLSRV1_HOST" "test -f /etc/pve/.version" 2>/dev/null; then
    log_error "$AGLSRV1_HOST is not a Proxmox host"
    exit 1
fi
PVE_VERSION=$(ssh root@"$AGLSRV1_HOST" "cat /etc/pve/.version 2>/dev/null")
log_success "Proxmox version: $PVE_VERSION"

# Create remote temp directory
log_info "Creating temporary directory on aglsrv1..."
ssh root@"$AGLSRV1_HOST" "mkdir -p $REMOTE_TEMP_DIR"
log_success "Remote directory created: $REMOTE_TEMP_DIR"

# Transfer deployment scripts
log_info "Transferring deployment scripts to aglsrv1..."
scp -r "$SCRIPT_DIR"/*.sh root@"$AGLSRV1_HOST":"$REMOTE_TEMP_DIR/" &>/dev/null
if [ -d "$SCRIPT_DIR/../config/harbor-ct182" ]; then
    ssh root@"$AGLSRV1_HOST" "mkdir -p $REMOTE_TEMP_DIR/config"
    scp -r "$SCRIPT_DIR/../config/harbor-ct182" root@"$AGLSRV1_HOST":"$REMOTE_TEMP_DIR/config/" &>/dev/null
fi
log_success "Scripts transferred successfully"

# Make scripts executable
log_info "Setting execute permissions on scripts..."
ssh root@"$AGLSRV1_HOST" "chmod +x $REMOTE_TEMP_DIR/*.sh"

# Show available scripts
log_info "Available deployment scripts on aglsrv1:"
ssh root@"$AGLSRV1_HOST" "ls -lh $REMOTE_TEMP_DIR/*.sh"

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}Scripts transferred to aglsrv1 successfully!${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo -e "1. Run master deployment script:"
echo -e "   ${GREEN}ssh root@$AGLSRV1_HOST${NC}"
echo -e "   ${GREEN}cd $REMOTE_TEMP_DIR${NC}"
echo -e "   ${GREEN}./deploy-harbor.sh --hostname harbor.agl.local --ip-address 192.168.0.182${NC}"
echo ""
echo -e "2. Or run individual scripts in order:"
echo -e "   ${GREEN}./create-container.sh${NC}     # Create CT182"
echo -e "   ${GREEN}./setup-docker.sh${NC}          # Install Docker"
echo -e "   ${GREEN}./configure-network.sh${NC}     # Configure network"
echo -e "   ${GREEN}./install-harbor.sh${NC}        # Install Harbor"
echo ""
echo -e "3. After deployment, run tests:"
echo -e "   ${GREEN}cd /mnt/overpower/apps/dev/agl/agl-hostman/tests/harbor-ct182${NC}"
echo -e "   ${GREEN}./installation-verification.sh --ctid 182 --harbor-ip 192.168.0.182${NC}"
echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"

# Optionally, execute deployment automatically
read -p "Do you want to execute the deployment now? (yes/no): " EXECUTE_NOW
if [[ "$EXECUTE_NOW" == "yes" ]]; then
    log_info "Starting Harbor deployment on aglsrv1..."
    ssh root@"$AGLSRV1_HOST" "cd $REMOTE_TEMP_DIR && ./deploy-harbor.sh --hostname harbor.agl.local --ip-address 192.168.0.182"
else
    log_info "Deployment not started. Connect to aglsrv1 manually to continue."
fi

log_success "Remote deployment setup complete!"
