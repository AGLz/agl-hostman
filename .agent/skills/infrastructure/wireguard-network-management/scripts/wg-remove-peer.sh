#!/bin/bash

###############################################################################
# WireGuard Peer Removal Script
# Removes a peer from the AGL WireGuard mesh network
#
# Usage: wg-remove-peer.sh <ip> [--hub-only] [--local-only]
#   ip: WireGuard IP to remove (e.g., 10.6.0.25)
#   --hub-only: Only remove from hub configuration
#   --local-only: Only remove from local peer configuration
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
    echo "Usage: $0 <ip> [--hub-only] [--local-only]"
    echo ""
    echo "Arguments:"
    echo "  ip          WireGuard IP to remove (e.g., 10.6.0.25)"
    echo "  --hub-only  Only remove from hub configuration"
    echo "  --local-only Only remove from local peer configuration"
    echo ""
    echo "Example:"
    echo "  $0 10.6.0.25              # Remove from both hub and local"
    echo "  $0 10.6.0.25 --hub-only   # Only remove from hub"
    echo "  $0 10.6.0.25 --local-only # Only remove from local"
    exit 1
}

validate_ip() {
    local ip=$1
    if [[ ! $ip =~ ^10\.6\.0\.([1-9][0-9]?|1[0-9][0-9]?|2[0-4][0-9]|25[0-4])$ ]]; then
        log_error "Invalid IP address: $ip (must be in 10.6.0.1-10.6.0.254 range)"
        exit 1
    fi
}

check_dependencies() {
    log_info "Checking dependencies..."

    if ! command -v wg &> /dev/null; then
        log_error "WireGuard tools not installed. Run: apt install wireguard"
        exit 1
    fi

    log_success "Dependencies verified"
}

get_peer_public_key() {
    local ip=$1

    # Get public key for IP from WireGuard config
    local config_file="$WG_CONFIG_DIR/${WG_INTERFACE}.conf"

    if [ ! -f "$config_file" ]; then
        log_warning "Local WireGuard config not found: $config_file"
        return
    fi

    # Try to get public key from local interface
    if wg show "$WG_INTERFACE" &> /dev/null; then
        # Get peer info by looking at allowed IPs
        wg show "$WG_INTERFACE" peers | while read -r peer_key; do
            local allowed_ips=$(wg show "$WG_INTERFACE" peer "$peer_key" allowed-ips)
            if [[ "$allowed_ips" == *"$ip/32"* ]]; then
                echo "$peer_key"
                return
            fi
        done
    fi
}

remove_from_hub() {
    local ip=$1

    log_info "Removing peer from hub (FGSRV6)..."
    log_warning "This requires SSH access to the hub"

    # Get peer public key from hub
    log_info "Fetching peer information from hub..."

    local peer_key=$(ssh root@${HUB_ENDPOINT%:*} "wg show $WG_INTERFACE peers | while read -r pk; do allowed_ips=\$(wg show $WG_INTERFACE peer \$pk allowed-ips); if [[ \"\$allowed_ips\" == *\"$ip/32\"* ]]; then echo \$pk; fi; done" 2>/dev/null || true)

    if [ -z "$peer_key" ]; then
        log_warning "Peer with IP $ip not found on hub"
        return
    fi

    log_info "Found peer with public key: $peer_key"

    echo ""
    log_warning "This will remove peer $ip from the hub configuration"
    read -p "Continue? (y/N): " -n 1 -r
    echo

    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Aborting hub removal..."
        return
    fi

    # Remove peer from hub WireGuard interface
    log_info "Removing peer from WireGuard interface..."
    if ssh root@${HUB_ENDPOINT%:*} "wg set $WG_INTERFACE peer $peer_key remove"; then
        log_success "Peer removed from WireGuard interface"
    else
        log_error "Failed to remove peer from WireGuard interface"
        return
    fi

    # Remove peer from hub config file
    log_info "Removing peer from configuration file..."

    # Create backup
    ssh root@${HUB_ENDPOINT%:*} "cp /etc/wireguard/${WG_INTERFACE}.conf /etc/wireguard/${WG_INTERFACE}.conf.backup.\$(date +%Y%m%d-%H%M%S)"

    # Remove peer block from config
    ssh root@${HUB_ENDPOINT%:*} "sed -i '/# Peer.*$ip/,/^$/d' /etc/wireguard/${WG_INTERFACE}.conf" || true

    log_success "Peer removed from hub configuration"
}

remove_from_local() {
    local ip=$1

    log_info "Removing local WireGuard configuration..."

    local config_file="$WG_CONFIG_DIR/${WG_INTERFACE}.conf"

    if [ ! -f "$config_file" ]; then
        log_warning "Local WireGuard config not found: $config_file"
        return
    fi

    # Backup config
    log_info "Creating backup..."
    sudo cp "$config_file" "${config_file}.backup.$(date +%Y%m%d-%H%M%S)"

    # Stop WireGuard interface
    log_info "Stopping WireGuard interface..."
    if wg show "$WG_INTERFACE" &> /dev/null; then
        sudo wg-quick down "$WG_INTERFACE"
    fi

    # Remove config file
    log_info "Removing configuration file..."
    sudo rm -f "$config_file"

    log_success "Local WireGuard configuration removed"

    # Remove keys
    log_info "Removing WireGuard keys..."
    sudo rm -f "$WG_CONFIG_DIR/privatekey"
    sudo rm -f "$WG_CONFIG_DIR/publickey"
    sudo rm -f "$WG_CONFIG_DIR/psk"

    log_success "WireGuard keys removed"
}

verify_removal() {
    local ip=$1

    log_info "Verifying removal..."

    # Check if IP is still reachable
    if ping -c 1 -W 1 "$ip" &> /dev/null; then
        log_warning "IP $ip is still reachable (may have been reassigned)"
    else
        log_success "IP $ip is no longer reachable"
    fi

    # Check hub configuration
    log_info "Checking hub configuration..."
    local hub_count=$(ssh root@${HUB_ENDPOINT%:*} "wg show $WG_INTERFACE peers | wc -l" 2>/dev/null || echo "0")
    log_info "Hub has $hub_count peers configured"

    # Check local configuration
    log_info "Checking local configuration..."
    if [ -f "$WG_CONFIG_DIR/${WG_INTERFACE}.conf" ]; then
        log_warning "Local configuration still exists"
    else
        log_success "Local configuration removed"
    fi
}

print_summary() {
    local ip=$1
    local hub_only=$2
    local local_only=$3

    echo ""
    log_success "=== WireGuard Peer Removal Complete ==="
    echo ""
    echo "Removed IP: $ip"
    echo "Hub removal: $([ "$hub_only" = "true" ] || [ "$local_only" != "true" ] && echo "Yes" || echo "No")"
    echo "Local removal: $([ "$local_only" = "true" ] || [ "$hub_only" != "true" ] && echo "Yes" || echo "No")"
    echo ""
    echo "Next Steps:"
    echo "  1. Update docs/WIREGUARD.md to reflect removal"
    echo "  2. Notify team of network topology change"
    echo "  3. Verify no services depend on removed peer"
    echo "  4. Consider reassigning IP if needed"
    echo ""
}

# Main execution
main() {
    # Parse arguments
    if [ $# -lt 1 ]; then
        usage
    fi

    local ip=$1
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

    # Validate IP
    validate_ip "$ip"

    echo ""
    log_info "=== WireGuard Peer Removal ==="
    echo "  IP: $ip"
    echo "  Hub removal: $([ "$hub_only" = "true" ] || [ "$local_only" != "true" ] && echo "Yes" || echo "No")"
    echo "  Local removal: $([ "$local_only" = "true" ] || [ "$hub_only" != "true" ] && echo "Yes" || echo "No")"
    echo ""

    # Check dependencies
    check_dependencies

    # Warning
    echo ""
    log_warning "This will remove WireGuard peer $ip from the mesh network"
    log_warning "This action cannot be easily undone"
    echo ""
    read -p "Continue? (y/N): " -n 1 -r
    echo
    echo ""

    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Aborting..."
        exit 0
    fi

    # Remove from hub (unless --local-only)
    if [ "$local_only" != "true" ]; then
        remove_from_hub "$ip"
    fi

    # Remove from local (unless --hub-only)
    if [ "$hub_only" != "true" ]; then
        remove_from_local "$ip"
    fi

    # Verify removal
    verify_removal "$ip"

    # Print summary
    print_summary "$ip" "$hub_only" "$local_only"
}

# Run main function
main "$@"
