#!/bin/bash
#
# FGSRV07 Tailscale Setup with SSH Option
# Host: FGSRV07 (VPS Locaweb - Debian 13)
# IP: 191.252.93.227
# Purpose: Install Tailscale with --ssh flag for Tailscale SSH authentication
#
# Usage: ./scripts/setup-fgsrv7-tailscale-ssh.sh
#

set -e

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
FGSRV7_IP="191.252.93.227"
FGSRV7_USER="root"
SSH_KEY="${HOME}/.ssh/fg_srv.pem"

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Step 1: Verify SSH key exists
check_ssh_key() {
    log_info "Checking SSH key..."
    if [[ ! -f "$SSH_KEY" ]]; then
        log_error "SSH key not found: $SSH_KEY"
        exit 1
    fi
    log_success "SSH key found: $SSH_KEY"
}

# Step 2: Test SSH connectivity
test_ssh_connection() {
    log_info "Testing SSH connection to FGSRV07..."
    if ssh -i "$SSH_KEY" -o ConnectTimeout=10 -o StrictHostKeyChecking=no \
        "${FGSRV7_USER}@${FGSRV7_IP}" "echo 'Connection successful'" 2>/dev/null; then
        log_success "SSH connection successful"
    else
        log_error "Cannot connect to FGSRV07. Please verify:"
        echo "  - IP address: $FGSRV7_IP"
        echo "  - SSH key: $SSH_KEY"
        echo "  - Network connectivity"
        exit 1
    fi
}

# Step 3: Install Tailscale on FGSRV07
install_tailscale() {
    log_info "Installing Tailscale on FGSRV07..."

    ssh -i "$SSH_KEY" "${FGSRV7_USER}@${FGSRV7_IP}" << 'ENDSSH'
set -e

# Update package lists
apt-get update

# Install curl if not present
which curl || apt-get install -y curl

# Install Tailscale using official script
curl -fsSL https://tailscale.com/install.sh | sh

# Enable IP forwarding for subnet router/exit node capability
echo 'net.ipv4.ip_forward = 1' >> /etc/sysctl.d/99-tailscale.conf
echo 'net.ipv6.conf.all.forwarding = 1' >> /etc/sysctl.d/99-tailscale.conf
sysctl -p /etc/sysctl.d/99-tailscale.conf

# Enable tailscaled service
systemctl enable tailscaled
systemctl start tailscaled

echo "Tailscale installed successfully"
ENDSSH

    log_success "Tailscale package installed"
}

# Step 4: Authenticate Tailscale with SSH enabled
authenticate_tailscale_ssh() {
    log_info "Authenticating Tailscale with SSH option..."
    log_warn "You will need to:"
    echo "  1. Copy the authentication URL from the output"
    echo "  2. Open it in a browser on your local machine"
    echo "  3. Log in to your Tailscale account"
    echo "  4. Click 'Connect' to authorize FGSRV07"

    ssh -i "$SSH_KEY" "${FGSRV7_USER}@${FGSRV7_IP}" << 'ENDSSH'
# Start Tailscale with SSH enabled
# The --ssh flag enables Tailscale SSH which allows:
# - Authentication via Tailscale identity instead of SSH keys
# - Centralized access control through Tailscale ACLs
# - Automatic key management

tailscale up --ssh

# Note: If you need additional options, use:
# tailscale up --ssh --advertise-exit-node   # To advertise as exit node
# tailscale up --ssh --accept-routes         # To accept routes
# tailscale up --ssh --tags=tag:fgsrv       # To add tags for ACLs
ENDSSH

    log_success "Tailscale authentication completed"
}

# Step 5: Verify Tailscale status
verify_tailscale() {
    log_info "Verifying Tailscale status..."

    ssh -i "$SSH_KEY" "${FGSRV7_USER}@${FGSRV7_IP}" << 'ENDSSH'
echo "=== Tailscale Status ==="
tailscale status

echo ""
echo "=== Tailscale IP Address ==="
tailscale ip -4

echo ""
echo "=== Tailscale SSH Status ==="
tailscale status --json | grep -A5 "\"TSHTML\":" || echo "Checking SSH configuration..."

echo ""
echo "=== Service Status ==="
systemctl is-active tailscaled
ENDSSH
}

# Step 6: Update SSH config with Tailscale IP
update_ssh_config() {
    log_info "Please update your SSH config with the Tailscale IP:"
    echo ""
    echo "Edit ~/.ssh/config and update:"
    echo ""
    echo "Host fgsrv7"
    echo "  HostName <TAILSCALE_IP>  # Replace with actual Tailscale IP from above"
    echo "  User root"
    echo "  StrictHostKeyChecking no"
    echo ""
    echo "Then test connection: ssh fgsrv7"
}

# Step 7: Test Tailscale connectivity
test_tailscale_connectivity() {
    log_info "Testing connectivity to other FGSRV nodes..."

    ssh -i "$SSH_KEY" "${FGSRV7_USER}@${FGSRV7_IP}" << 'ENDSSH'
# Test connection to known Tailscale peers
echo "Attempting to ping known Tailscale nodes..."

# Try pinging fgsrv6 if accessible via Tailscale
if ping -c 2 -W 2 100.83.51.9 &>/dev/null; then
    echo "✓ FGSRV06 (100.83.51.9) is reachable via Tailscale"
else
    echo "✗ FGSRV06 not reachable - may not be on same tailnet"
fi
ENDSSH
}

# Main execution
main() {
    echo -e "${BLUE}"
    echo "=========================================="
    echo " FGSRV07 Tailscale SSH Setup"
    echo "=========================================="
    echo -e "${NC}"
    echo "Host: FGSRV07"
    echo "IP: $FGSRV7_IP"
    echo "Feature: Tailscale with --ssh flag"
    echo ""

    check_ssh_key
    test_ssh_connection

    read -p "$(echo -e ${YELLOW}Continue with Tailscale installation? [y/N]: ${NC})" -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_warn "Installation cancelled"
        exit 0
    fi

    install_tailscale
    authenticate_tailscale_ssh
    verify_tailscale
    update_ssh_config
    test_tailscale_connectivity

    echo ""
    log_success "FGSRV07 Tailscale SSH setup completed!"
    echo ""
    echo "Next steps:"
    echo "  1. Update ~/.ssh/config with the Tailscale IP shown above"
    echo "  2. Enable Tailscale SSH in admin console: https://login.tailscale.com/admin/machines"
    echo "  3. Configure ACLs for SSH access in Tailscale admin console"
    echo "  4. Test connection: ssh fgsrv7 (after updating config)"
    echo ""
}

# Run main function
main "$@"
