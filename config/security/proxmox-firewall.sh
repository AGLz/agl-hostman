#!/bin/bash
# AGL Infrastructure - Proxmox Firewall Configuration
# Version: 1.0.0
# Description: Configure firewall rules for Proxmox hosts and containers
# Author: Security Agent V3
# Date: 2026-02-08

set -euo pipefail

# Configuration
PROXMOX_HOST="192.168.0.1"  # Update with your Proxmox host IP
CONTAINERS=(
    "182:192.168.0.182:Harbor"
    "200:192.168.0.200:Ollama"
)
VPN_NETWORK="10.6.0.0/24"
INTERNAL_NETWORK="192.168.0.0/24"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $@"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $@"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $@"
}

# Function to execute command on Proxmox host
exec_pvesh() {
    pvesh create "/nodes/$(hostname)/$@" 2>/dev/null || pvesh set "/nodes/$(hostname)/$@" 2>/dev/null || pvesh get "/nodes/$(hostname)/$@" 2>/dev/null
}

# Enable firewall on Proxmox host
enable_host_firewall() {
    log_info "Enabling firewall on Proxmox host..."

    # Enable firewall at datacenter level
    pvesh set /cluster/firewall --enable 1 || true

    # Enable firewall on host
    pvesh set /nodes/$(hostname)/firewall --enable 1 || true

    # Set default policies
    pvesh set /nodes/$(hostname)/firewall/options --input ACCEPT --output ACCEPT --forward DROP || true

    log_info "Firewall enabled on Proxmox host"
}

# Configure Proxmox host firewall rules
configure_host_rules() {
    log_info "Configuring host firewall rules..."

    # Allow SSH from VPN only
    pvesh create /nodes/$(hostname)/firewall/rules \
        --action ACCEPT \
        --type IN \
        --pos 100 \
        --source "${VPN_NETWORK}" \
        --dport 22 \
        --proto tcp \
        --log "n" \
        --comment "Allow SSH from VPN" || true

    # Allow Proxmox web interface from VPN
    pvesh create /nodes/$(hostname)/firewall/rules \
        --action ACCEPT \
        --type IN \
        --pos 110 \
        --source "${VPN_NETWORK}" \
        --dport 8006 \
        --proto tcp \
        --log "n" \
        --comment "Allow Proxmox Web UI from VPN" || true

    # Allow WireGuard
    pvesh create /nodes/$(hostname)/firewall/rules \
        --action ACCEPT \
        --type IN \
        --pos 120 \
        --dport 51820 \
        --proto udp \
        --log "n" \
        --comment "Allow WireGuard VPN" || true

    # Allow ICMP for ping
    pvesh create /nodes/$(hostname)/firewall/rules \
        --action ACCEPT \
        --type IN \
        --pos 130 \
        --proto icmp \
        --log "n" \
        --comment "Allow ICMP" || true

    # Allow established connections
    pvesh create /nodes/$(hostname)/firewall/rules \
        --action ACCEPT \
        --type IN \
        --pos 140 \
        --log "n" \
        --comment "Allow established connections" || true

    # Drop and log everything else
    pvesh create /nodes/$(hostname)/firewall/rules \
        --action DROP \
        --type IN \
        --pos 999 \
        --log "y" \
        --comment "Drop and log all other traffic" || true

    log_info "Host firewall rules configured"
}

# Configure container firewall
configure_container_firewall() {
    local ctid=$1
    local ip=$2
    local name=$3

    log_info "Configuring firewall for CT${ctid} (${name})..."

    # Enable firewall on container
    pct exec ${ctid} -- bash -c "
        # Install iptables if not present
        if ! command -v iptables &> /dev/null; then
            apt-get update && apt-get install -y iptables
        fi

        # Clear existing rules
        iptables -F
        iptables -X
        iptables -t nat -F
        iptables -t nat -X
        iptables -t mangle -F
        iptables -t mangle -X

        # Default policies
        iptables -P INPUT DROP
        iptables -P FORWARD DROP
        iptables -P OUTPUT ACCEPT

        # Allow loopback
        iptables -A INPUT -i lo -j ACCEPT

        # Allow established connections
        iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

        # Allow SSH from VPN only
        iptables -A INPUT -p tcp -s ${VPN_NETWORK} --dport 22 -j ACCEPT

        # Allow HTTP/HTTPS
        iptables -A INPUT -p tcp --dport 80 -j ACCEPT
        iptables -A INPUT -p tcp --dport 443 -j ACCEPT

        # Service-specific rules
        case \"${name}\" in
            Harbor)
                # Harbor container registry
                iptables -A INPUT -p tcp --dport 5000 -j ACCEPT
                ;;
            Ollama)
                # Ollama AI service
                iptables -A INPUT -p tcp --dport 11434 -j ACCEPT
                ;;
            Archon)
                # Archon MCP endpoint
                iptables -A INPUT -p tcp --dport 8051 -j ACCEPT
                ;;
        esac

        # Allow ICMP
        iptables -A INPUT -p icmp --icmp-type echo-request -j ACCEPT

        # Log and drop everything else
        iptables -A INPUT -j LOG --log-prefix \"FIREWALL_DROP: \"
        iptables -A INPUT -j DROP
    " || log_warn "Failed to configure firewall for CT${ctid}"

    # Enable firewall in Proxmox config
    pvesh set /nodes/$(hostname)/lxc/${ctid}/firewall --enable 1 || true

    # Configure network firewall rules in Proxmox
    pvesh create /nodes/$(hostname)/lxc/${ctid}/firewall/rules \
        --action ACCEPT \
        --type IN \
        --pos 100 \
        --source "${VPN_NETWORK}" \
        --dport 22 \
        --proto tcp \
        --comment "Allow SSH from VPN" || true

    log_info "Firewall configured for CT${ctid} (${name})"
}

# Install iptables persistence
install_persistence() {
    log_info "Installing iptables persistence..."

    for entry in "${CONTAINERS[@]}"; do
        local ctid=$(echo $entry | cut -d: -f1)

        pct exec ${ctid} -- bash -c "
            if [ -f /etc/debian_version ]; then
                apt-get update && apt-get install -y iptables-persistent netfilter-persistent
                mkdir -p /etc/iptables
                iptables-save > /etc/iptables/rules.v4
                ip6tables-save > /etc/iptables/rules.v6
                systemctl enable netfilter-persistent
            fi
        " || log_warn "Failed to install persistence for CT${ctid}"
    done
}

# Backup current firewall rules
backup_rules() {
    log_info "Backing up current firewall rules..."

    local backup_dir="/var/backups/proxmox-firewall"
    local timestamp=$(date +%Y%m%d_%H%M%S)
    mkdir -p "${backup_dir}"

    for entry in "${CONTAINERS[@]}"; do
        local ctid=$(echo $entry | cut -d: -f1)

        pct exec ${ctid} -- iptables-save > "${backup_dir}/ct${ctid}-${timestamp}.rules" || true
    done

    log_info "Firewall rules backed up to ${backup_dir}"
}

# Display current rules
display_rules() {
    log_info "Current firewall rules:"

    for entry in "${CONTAINERS[@]}"; do
        local ctid=$(echo $entry | cut -d: -f1)
        local name=$(echo $entry | cut -d: -f3)

        echo ""
        echo "=== CT${ctid} (${name}) ==="
        pct exec ${ctid} -- iptables -L -n -v || true
    done
}

# Main execution
main() {
    log_info "Starting Proxmox firewall configuration..."
    log_info "============================================"

    # Check if running as root
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root"
        exit 1
    }

    # Check if pvesh is available
    if ! command -v pvesh &> /dev/null; then
        log_error "pvesh command not found. Run this on a Proxmox host."
        exit 1
    fi

    # Ask for confirmation
    log_warn "This will configure firewall rules for Proxmox and containers"
    read -p "Are you sure you want to continue? (yes/no): " confirm

    if [[ "$confirm" != "yes" ]]; then
        log_info "Firewall configuration cancelled"
        exit 0
    fi

    # Execute configuration
    backup_rules
    enable_host_firewall
    configure_host_rules

    for entry in "${CONTAINERS[@]}"; do
        local ctid=$(echo $entry | cut -d: -f1)
        local ip=$(echo $entry | cut -d: -f2)
        local name=$(echo $entry | cut -d: -f3)

        configure_container_firewall "$ctid" "$ip" "$name"
    done

    install_persistence
    display_rules

    log_info "============================================"
    log_info "Firewall configuration completed!"
    log_warn "Test all services after configuration"
    log_warn "Keep SSH session open until verified"
}

# Run main function
main "$@"
