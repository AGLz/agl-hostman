#!/bin/bash

###############################################################################
# WireGuard Key Rotation Script
# Rotates WireGuard keys for security maintenance
#
# Usage: wg-rotate-keys.sh <peer_name> [--hub-only] [--local-only]
#   peer_name: Human-readable name or IP of the peer
#   --hub-only: Only rotate on hub configuration
#   --local-only: Only rotate on local peer configuration
###############################################################################

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
HUB_ENDPOINT="186.202.57.120:51823"
WG_CONFIG_DIR="/etc/wireguard"
WG_INTERFACE="wg0"

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

usage() {
    echo "Usage: $0 <peer_name> [--hub-only] [--local-only]"
    echo ""
    echo "Arguments:"
    echo "  peer_name   Human-readable name or IP of the peer"
    echo "  --hub-only  Only rotate keys on hub configuration"
    echo "  --local-only Only rotate keys on local peer configuration"
    echo ""
    echo "Example:"
    echo "  $0 ct120              # Rotate keys on both hub and local"
    echo "  $0 10.6.0.1 --hub-only # Only rotate on hub"
    echo "  $0 aglsrv1 --local-only # Only rotate locally"
    exit 1
}

check_dependencies() {
    log_info "Checking dependencies..."

    if ! command -v wg &> /dev/null; then
        log_error "WireGuard tools not installed. Run: apt install wireguard"
        exit 1
    fi

    log_success "Dependencies verified"
}

backup_config() {
    local config_file=$1

    if [ -f "$config_file" ]; then
        local backup_file="${config_file}.backup.$(date +%Y%m%d-%H%M%S)"
        sudo cp "$config_file" "$backup_file"
        log_info "Backed up config to: $backup_file"
    fi
}

generate_new_keys() {
    log_info "Generating new WireGuard keys..."

    # Generate new private key
    local new_private_key=$(wg genkey)

    # Derive public key
    local new_public_key=$(echo "$new_private_key" | wg pubkey)

    log_success "New keys generated"
    log_info "New Public Key: $new_public_key"

    echo "$new_private_key"
}

update_local_config() {
    local new_private_key=$1
    local config_file="$WG_CONFIG_DIR/${WG_INTERFACE}.conf"

    log_info "Updating local configuration..."

    if [ ! -f "$config_file" ]; then
        log_error "Local config not found: $config_file"
        return 1
    fi

    # Backup current config
    backup_config "$config_file"

    # Update private key in config
    sudo sed -i "s|^PrivateKey = .*|PrivateKey = $new_private_key|" "$config_file"

    log_success "Local configuration updated"

    # Restart WireGuard
    log_info "Restarting WireGuard interface..."
    sudo wg-quick down "$WG_INTERFACE" 2>/dev/null || true
    sudo wg-quick up "$WG_INTERFACE"

    log_success "WireGuard restarted with new keys"
}

update_hub_config() {
    local peer_ip=$1
    local old_public_key=$2
    local new_public_key=$3

    log_info "Updating hub configuration..."
    log_warning "This requires SSH access to the hub"

    # Backup hub config
    log_info "Backing up hub configuration..."
    ssh root@${HUB_ENDPOINT%:*} "cp /etc/wireguard/${WG_INTERFACE}.conf /etc/wireguard/${WG_INTERFACE}.conf.backup.\$(date +%Y%m%d-%H%M%S)"

    # Remove old peer and add new one
    log_info "Updating peer on hub..."

    # Remove old peer
    ssh root@${HUB_ENDPOINT%:*} "wg set $WG_INTERFACE peer $old_public_key remove" 2>/dev/null || true

    # Add new peer with same IP
    ssh root@${HUB_ENDPOINT%:*} "wg set $WG_INTERFACE peer $new_public_key allowed-ips $peer_ip/32"

    # Update config file
    ssh root@${HUB_ENDPOINT%:*} "sed -i '/PublicKey = $old_public_key/,/^$/d' /etc/wireguard/${WG_INTERFACE}.conf" || true

    # Add new peer to config
    ssh root@${HUB_ENDPOINT%:*} "cat >> /etc/wireguard/${WG_INTERFACE}.conf <<EOF

# Rotated keys: $(date)
[Peer]
PublicKey = $new_public_key
AllowedIPs = $peer_ip/32
EOF"

    log_success "Hub configuration updated"
}

verify_new_keys() {
    log_info "Verifying new keys..."

    # Wait for handshake
    log_info "Waiting for handshake (up to 30 seconds)..."
    for i in {1..30}; do
        if sudo wg show "$WG_INTERFACE" latest-handshakes | grep -q "[1-9]"; then
            log_success "Handshake established with new keys!"
            break
        fi
        sleep 1
    done

    # Show WireGuard status
    echo ""
    log_info "WireGuard Status:"
    sudo wg show "$WG_INTERFACE"
}

print_summary() {
    local peer_name=$1
    local new_public_key=$2

    echo ""
    log_success "=== Key Rotation Complete ==="
    echo ""
    echo "Peer: $peer_name"
    echo "New Public Key: $new_public_key"
    echo ""
    echo "Next Steps:"
    echo "  1. Verify connectivity to all peers"
    echo "  2. Monitor connection stability for next 24 hours"
    echo "  3. Update documentation if needed"
    echo "  4. Store backup keys securely"
    echo ""
}

# Main execution
main() {
    # Parse arguments
    if [ $# -lt 1 ]; then
        usage
    fi

    local peer_name=$1
    local hub_only=false
    local local_only=false

    shift

    while [ $# -gt 0 ]; do
        case $1 in
            --hub-only)
                hub_only=true
                shift
                ;;
            --local-only)
                local_only=true
                shift
                ;;
            *)
                log_error "Unknown option: $1"
                usage
                ;;
        esac
    done

    echo ""
    log_info "=== WireGuard Key Rotation ==="
    echo "  Peer: $peer_name"
    echo "  Hub update: $([ "$hub_only" = "true" ] || [ "$local_only" != "true" ] && echo "Yes" || echo "No")"
    echo "  Local update: $([ "$local_only" = "true" ] || [ "$hub_only" != "true" ] && echo "Yes" || echo "No")"
    echo ""

    # Check dependencies
    check_dependencies

    # Warning
    echo ""
    log_warning "This will rotate WireGuard keys for $peer_name"
    log_warning "Connectivity may be briefly interrupted"
    log_warning "Make sure you have backup access (e.g., Tailscale)"
    echo ""
    read -p "Continue? (y/N): " -n 1 -r
    echo
    echo ""

    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Aborting..."
        exit 0
    fi

    # Get current public key
    local old_public_key=$(sudo wg show "$WG_INTERFACE" public-key)

    # Generate new keys
    local new_private_key=$(generate_new_keys)
    local new_public_key=$(echo "$new_private_key" | wg pubkey)

    # Update local configuration (unless --hub-only)
    if [ "$hub_only" != "true" ]; then
        update_local_config "$new_private_key"
    fi

    # Update hub configuration (unless --local-only)
    if [ "$local_only" != "true" ]; then
        # Get local IP
        local peer_ip=$(ip addr show "$WG_INTERFACE" 2>/dev/null | grep "inet " | awk '{print $2}' | cut -d'/' -f1)

        if [ -z "$peer_ip" ]; then
            log_error "Could not determine local IP"
            exit 1
        fi

        update_hub_config "$peer_ip" "$old_public_key" "$new_public_key"
    fi

    # Verify new keys
    verify_new_keys

    # Print summary
    print_summary "$peer_name" "$new_public_key"
}

# Run main function
main "$@"
