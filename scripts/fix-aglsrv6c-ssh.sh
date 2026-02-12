#!/bin/bash
#
# Fix Tailscale SSH Flag for aglsrv6c (man6c) Container
# Usage: Execute on AGLSRV6 after finding the correct CTID
#
# Steps:
# 1. ssh root@AGLSRV6 (man6) or ssh AGLSRV1 "ssh root@AGLSRV6"
# 2. pct list
# 3. Note the CTID of aglsrv6c
# 4. ./scripts/fix-aglsrv6c-ssh.sh <CTID>
#

set -e

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Functions
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

# Check if CTID provided
if [[ -z "$1" ]]; then
    log_error "CTID not provided!"
    echo ""
    echo "Usage: $0 <CTID>"
    echo ""
    echo "Example:"
    echo "  $0 201"
    echo ""
    echo "Prerequisites:"
    echo "  1. Must be executed on AGLSRV6 (man6) host"
    echo "  2. CTID must exist and be running"
    exit 1
fi

CTID="$1"

log_info "Fixing Tailscale SSH for CT${CTID} (aglsrv6c)..."

# Check if container exists
if ! pct status "$CTID" &>/dev/null; then
    log_error "Container CT${CTID} not found!"
    echo ""
    echo "Available containers:"
    pct list
    exit 1
fi

# Get container hostname
CT_HOSTNAME=$(pct config "$CTID" | grep hostname | cut -d'=' -f2)
log_info "Container hostname: $CT_HOSTNAME"

# Fix Tailscale with --ssh flag
log_info "Disconnecting Tailscale..."
pct exec "$CTID" -- tailscale down 2>/dev/null || true

sleep 1

log_info "Reconnecting with --ssh flag..."
pct exec "$CTID" -- bash -c '
    tailscale up --ssh 2>/dev/null || tailscale up --ssh --reset
    sleep 2
    echo "Status:"
    tailscale status --peers=false | head -2
    echo ""
    echo "Tailscale IP: $(tailscale ip -4)"
    echo "SSH flag activated!"
'

if [[ $? -eq 0 ]]; then
    log_success "CT${CTID} (aglsrv6c) configured with Tailscale SSH!"
    echo ""
    echo "Tailscale IP: $(pct exec "$CTID" -- tailscale ip -4)"
    echo ""
    echo "Next steps:"
    echo "  1. Configure ACLs in Tailscale Admin Console"
    echo "  2. Test SSH connection: ssh root@aglsrv6c"
else
    log_error "Failed to configure CT${CTID}"
    exit 1
fi
