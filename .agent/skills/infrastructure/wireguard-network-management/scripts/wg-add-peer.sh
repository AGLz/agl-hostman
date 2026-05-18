#!/bin/bash

###############################################################################
# WireGuard Peer Addition Script
# Adds a new peer to the AGL WireGuard mesh network
#
# Usage: wg-add-peer.sh <hostname> <ip> <port> [type]
#   hostname: Human-readable name (e.g., ct120, aglsrv1)
#   ip: WireGuard IP in 10.6.0.0/24 range
#   port: UDP port for WireGuard (51825-51899 recommended)
#   type: (optional) 'container' or 'host' (default: container)
###############################################################################

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
HUB_PUBLIC_KEY="Dj8XsoPeDlgnqA4Ox++yDy+t4xGxYtEevxQh513fSA8="
HUB_ENDPOINT="186.202.57.120:51823"
HUB_PRESHARED_KEY="DDvQ3xJ9Rs5pbEzXLuGCdep66zBuVNcy654+A/vD+Zk="
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
    echo "Usage: $0 <hostname> <ip> <port> [type]"
    echo ""
    echo "Arguments:"
    echo "  hostname  Human-readable name (e.g., ct120, aglsrv1)"
    echo "  ip        WireGuard IP in 10.6.0.0/24 range (e.g., 10.6.0.25)"
    echo "  port      UDP port for WireGuard (51825-51899 recommended)"
    echo "  type      (optional) 'container' or 'host' (default: container)"
    echo ""
    echo "Example:"
    echo "  $0 new-container 10.6.0.25 51825 container"
    echo "  $0 aglsrv1 10.6.0.10 51810 host"
    exit 1
}

validate_ip() {
    local ip=$1
    if [[ ! $ip =~ ^10\.6\.0\.([1-9][0-9]?|1[0-9][0-9]?|2[0-4][0-9]|25[0-4])$ ]]; then
        log_error "Invalid IP address: $ip (must be in 10.6.0.1-10.6.0.254 range)"
        exit 1
    fi
}

validate_port() {
    local port=$1
    if [[ ! $port =~ ^[0-9]+$ ]] || [ "$port" -lt 1024 ] || [ "$port" -gt 65535 ]; then
        log_error "Invalid port: $port (must be 1024-65535)"
        exit 1
    fi
}

check_dependencies() {
    log_info "Checking dependencies..."

    if ! command -v wg &> /dev/null; then
        log_error "WireGuard tools not installed. Run: apt install wireguard"
        exit 1
    fi

    if ! command -v wg-quick &> /dev/null; then
        log_error "wg-quick not found. Run: apt install wireguard-tools"
        exit 1
    fi

    log_success "Dependencies verified"
}

check_wireguard_installed() {
    log_info "Checking WireGuard installation on target..."

    # Check if this is being run locally or remotely
    if [ -f "$WG_CONFIG_DIR/$WG_INTERFACE.conf" ]; then
        log_warning "WireGuard config already exists at $WG_CONFIG_DIR/$WG_INTERFACE.conf"
        read -p "Overwrite existing configuration? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "Aborting..."
            exit 0
        fi
    fi
}

generate_keys() {
    log_info "Generating WireGuard keys..."

    # Create config directory if it doesn't exist
    sudo mkdir -p "$WG_CONFIG_DIR"

    # Generate private key
    wg genkey | sudo tee "$WG_CONFIG_DIR/privatekey" > /dev/null

    # Generate public key from private key
    sudo cat "$WG_CONFIG_DIR/privatekey" | wg pubkey | sudo tee "$WG_CONFIG_DIR/publickey" > /dev/null

    # Set secure permissions
    sudo chmod 600 "$WG_CONFIG_DIR/privatekey"

    PRIVATE_KEY=$(sudo cat "$WG_CONFIG_DIR/privatekey")
    PUBLIC_KEY=$(sudo cat "$WG_CONFIG_DIR/publickey")

    log_success "Keys generated successfully"
    log_info "Public Key: $PUBLIC_KEY"
}

create_config() {
    local hostname=$1
    local ip=$2
    local port=$3
    local type=${4:-container}

    log_info "Creating WireGuard configuration..."

    local config_file="$WG_CONFIG_DIR/${WG_INTERFACE}.conf"

    # Backup existing config
    if [ -f "$config_file" ]; then
        sudo cp "$config_file" "${config_file}.backup.$(date +%Y%m%d-%H%M%S)"
        log_info "Backed up existing config to ${config_file}.backup.$(date +%Y%m%d-%H%M%S)"
    fi

    # Create configuration based on type
    if [ "$type" = "host" ]; then
        # Host configuration with PresharedKey
        sudo tee "$config_file" > /dev/null <<EOF
# WireGuard Configuration for $hostname
# Generated: $(date)
# Type: Host (with PresharedKey)

[Interface]
PrivateKey = $PRIVATE_KEY
Address = $ip/24
DNS = 1.1.1.1, 8.8.8.8
MTU = 1420
ListenPort = $port

# Hub Peer (FGSRV6)
[Peer]
PublicKey = $HUB_PUBLIC_KEY
PresharedKey = $HUB_PRESHARED_KEY
AllowedIPs = 10.6.0.0/24
PersistentKeepalive = 25
Endpoint = $HUB_ENDPOINT
EOF
    else
        # Container configuration WITHOUT PresharedKey
        sudo tee "$config_file" > /dev/null <<EOF
# WireGuard Configuration for $hostname
# Generated: $(date)
# Type: LXC Container (NO PresharedKey)

[Interface]
PrivateKey = $PRIVATE_KEY
Address = $ip/24
DNS = 1.1.1.1, 8.8.8.8
MTU = 1420

# Hub Peer (FGSRV6)
[Peer]
PublicKey = $HUB_PUBLIC_KEY
AllowedIPs = 10.6.0.0/24
PersistentKeepalive = 25
Endpoint = $HUB_ENDPOINT
EOF
    fi

    sudo chmod 600 "$config_file"

    log_success "Configuration created: $config_file"
}

register_on_hub() {
    local hostname=$1
    local ip=$2
    local public_key=$3

    log_info "Registering peer on hub (FGSRV6)..."
    log_warning "This step requires SSH access to the hub"

    echo ""
    echo "To register this peer on the hub, run these commands on FGSRV6:"
    echo ""
    echo "# Add peer to hub configuration"
    echo "cat >> /etc/wireguard/wg0.conf <<EOF"
    echo ""
    echo "# $hostname"
    echo "[Peer]"
    echo "PublicKey = $public_key"
    echo "AllowedIPs = $ip/32"
    echo "EOF"
    echo ""
    echo "# Reload hub configuration"
    echo "wg syncconf wg0 <(wg-quick strip wg0)"
    echo ""
    echo "# Or restart WireGuard"
    echo "systemctl restart wg-quick@wg0"
    echo ""

    read -p "Run these commands now? (y/N): " -n 1 -r
    echo

    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log_info "SSH to hub and run the commands above"
        log_info "Then press Enter to continue..."
        read

        # Try to connect to hub and register peer
        if ssh root@${HUB_ENDPOINT%:*} "wg set wg0 peer $public_key allowed-ips $ip/32"; then
            log_success "Peer registered on hub"

            # Add to hub config for persistence
            ssh root@${HUB_ENDPOINT%:*} "cat >> /etc/wireguard/wg0.conf <<EOF

# $hostname
[Peer]
PublicKey = $public_key
AllowedIPs = $ip/32
EOF"
            log_success "Peer added to hub configuration"
        else
            log_warning "Could not connect to hub. Please register manually."
        fi
    fi
}

start_wireguard() {
    log_info "Starting WireGuard interface..."

    if sudo wg-quick up "$WG_INTERFACE"; then
        log_success "WireGuard interface started"
    else
        log_error "Failed to start WireGuard interface"
        exit 1
    fi

    # Enable on boot
    sudo systemctl enable wg-quick@"$WG_INTERFACE"
    log_success "WireGuard enabled to start on boot"
}

verify_connectivity() {
    local ip=$1

    log_info "Verifying connectivity..."

    # Wait for handshake
    log_info "Waiting for handshake (up to 30 seconds)..."
    for i in {1..30}; do
        if sudo wg show "$WG_INTERFACE" latest-handshakes | grep -q "[1-9]"; then
            log_success "Handshake established!"
            break
        fi
        sleep 1
    done

    # Show WireGuard status
    echo ""
    log_info "WireGuard Status:"
    sudo wg show "$WG_INTERFACE"

    # Test connectivity to hub
    echo ""
    log_info "Testing connectivity to hub (10.6.0.5)..."
    if ping -c 3 -W 2 10.6.0.5 &> /dev/null; then
        local latency=$(ping -c 3 10.6.0.5 | tail -1 | awk -F '/' '{print $5}')
        log_success "Hub reachable (latency: ${latency}ms)"
    else
        log_warning "Hub not reachable. Check firewall and routing."
    fi

    # Test connectivity to another peer
    echo ""
    log_info "Testing connectivity to AGLSRV1 (10.6.0.10)..."
    if ping -c 3 -W 2 10.6.0.10 &> /dev/null; then
        local latency=$(ping -c 3 10.6.0.10 | tail -1 | awk -F '/' '{print $5}')
        log_success "AGLSRV1 reachable (latency: ${latency}ms)"
    else
        log_warning "AGLSRV1 not reachable (may be offline)"
    fi
}

print_summary() {
    local hostname=$1
    local ip=$2
    local public_key=$3

    echo ""
    log_success "=== WireGuard Peer Addition Complete ==="
    echo ""
    echo "Peer Information:"
    echo "  Hostname: $hostname"
    echo "  WireGuard IP: $ip"
    echo "  Public Key: $public_key"
    echo "  Interface: $WG_INTERFACE"
    echo ""
    echo "Next Steps:"
    echo "  1. Update docs/WIREGUARD.md with new peer"
    echo "  2. Test connectivity to all mesh nodes"
    echo "  3. Configure services to use WireGuard network"
    echo "  4. Monitor connection stability"
    echo ""
    echo "Useful Commands:"
    echo "  Check status: wg show $WG_INTERFACE"
    echo "  Restart: systemctl restart wg-quick@$WG_INTERFACE"
    echo "  View logs: journalctl -u wg-quick@$WG_INTERFACE -f"
    echo ""
}

# Main execution
main() {
    # Parse arguments
    if [ $# -lt 3 ]; then
        usage
    fi

    local hostname=$1
    local ip=$2
    local port=$3
    local type=${4:-container}

    # Validate inputs
    validate_ip "$ip"
    validate_port "$port"

    if [ "$type" != "container" ] && [ "$type" != "host" ]; then
        log_error "Invalid type: $type (must be 'container' or 'host')"
        exit 1
    fi

    echo ""
    log_info "=== WireGuard Peer Addition ==="
    echo "  Hostname: $hostname"
    echo "  IP: $ip"
    echo "  Port: $port"
    echo "  Type: $type"
    echo ""

    # Check dependencies
    check_dependencies
    check_wireguard_installed

    # Generate keys
    generate_keys

    # Create configuration
    create_config "$hostname" "$ip" "$port" "$type"

    # Register on hub
    register_on_hub "$hostname" "$ip" "$PUBLIC_KEY"

    # Start WireGuard
    start_wireguard

    # Verify connectivity
    verify_connectivity "$ip"

    # Print summary
    print_summary "$hostname" "$ip" "$PUBLIC_KEY"
}

# Run main function
main "$@"
