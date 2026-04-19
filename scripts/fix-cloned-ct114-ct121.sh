#!/bin/bash
#
# Fix Cloned Containers CT114 (cloudflared6b) and CT121
# Problem: Both CTs have the same node key - need unique keys
#
# Usage: Execute on AGLSRV6 (man6) host
# ./scripts/fix-cloned-ct114-ct121.sh
#

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running on correct host
hostnamectl hostname | grep -q "aglsrv6" || {
    log_error "Este script deve ser executado no AGLSRV6 (man6)"
    exit 1
}

log_info "Fixing cloned containers CT114 and CT121..."
log_info "Host: aglsrv6c (100.124.53.91)"
echo ""

# Check if containers exist
log_info "=== Checking if containers exist ==="
CT114_EXISTS=$(pct list | grep -q "114")
CT121_EXISTS=$(pct list | grep -q "121")

if [[ "$CT114_EXISTS" == "yes" ]]; then
    log_success "CT114 (cloudflared6b) found"
else
    log_error "CT114 not found!"
fi

if [[ "$CT121_EXISTS" == "yes" ]]; then
    log_success "CT121 (arr stack) found"
else
    log_error "CT121 not found!"
fi
echo ""

# Function to fix container SSH keys
fix_container_ssh() {
    local ctid="$1"
    local ctname="$2"

    log_info "Fixing CT${ctid} (${ctname})..."

    # Generate new SSH key pair for the container
    log_info "Generating new SSH key pair for CT${ctid}..."

    # Create temp directory for keys
    mkdir -p /tmp/ct${ctid}_ssh_fix

    # Generate new key
    ssh-keygen -t ecdsa -b 4096 -f /tmp/ct${ctid}_ssh_fix/id_${ctid} -N "" >/dev/null 2>&1

    # Copy new public key to temp file
    cp /tmp/ct${ctid}_ssh_fix/id_${ctid}.pub /tmp/ct${ctid}_ssh_fix/authorized_keys

    # Remove old authorized keys from container
    log_info "Removing old authorized_keys from CT${ctid}..."
    pct exec "$ctid" -- bash -c "
        # Remove old authorized_keys file if exists
        rm -f ~/.ssh/authorized_keys
        # Remove old SSH keys
        rm -f ~/.ssh/id_*
        # Copy new authorized_keys
        cp /tmp/ct${ctid}_ssh_fix/authorized_keys ~/.ssh/authorized_keys
        # Set correct permissions
        chmod 700 ~/.ssh
        chmod 600 ~/.ssh/authorized_keys
        echo 'CT${ctid}: SSH keys fixed'
    "

    local exit_code=$?

    if [[ $exit_code -eq 0 ]]; then
        log_success "CT${ctid} (${ctname}): New SSH key pair generated and installed"
        echo ""
        echo "  ${GREEN}New keys:${NC}"
        echo "    Private: /tmp/ct${ctid}_ssh_fix/id_${ctid}"
        echo "    Public:  /tmp/ct${ctid}_ssh_fix/id_${ctid}.pub"
        echo ""
        echo "To install in CT${ctid}:"
        echo "  pct push ${ctid} /tmp/ct${ctid}_ssh_fix/authorized_keys ~/.ssh/authorized_keys"
        echo ""
        echo "Then restart CT${ctid}:"
        echo "  pct shutdown ${ctid} && pct start ${ctid}"
    else
        log_error "Failed to fix CT${ctid}"
    fi

    # Cleanup temp files
    rm -rf /tmp/ct${ctid}_ssh_fix
}

# Fix CT114 if exists
if [[ "$CT114_EXISTS" == "yes" ]]; then
    fix_container_ssh "114" "cloudflared6b"
fi

# Fix CT121 if exists
if [[ "$CT121_EXISTS" == "yes" ]]; then
    fix_container_ssh "121" "arr-stack"
fi

echo ""
log_info "=== Summary ==="
log_success "Fix script completed!"
echo ""
echo "Next steps:"
echo "  1. Restart containers to apply new SSH keys:"
echo "     pct shutdown 114 && pct start 114"
echo "     pct shutdown 121 && pct start 121"
echo ""
echo "  2. Verify SSH access:"
echo "     ssh root@192.168.0.233 'hostname'  # CT114"
echo "     ssh root@192.168.0.233 'echo CT121_HOSTNAME'  # CT121 (verify hostname first)"
