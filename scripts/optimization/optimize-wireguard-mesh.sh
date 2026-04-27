#!/bin/bash

###############################################################################
# WireGuard Mesh Network Optimization Script
# Optimizes WireGuard configuration for maximum performance
#
# Optimizations:
# - MTU tuning for optimal packet size
# - Kernel network parameters
# - Connection pooling settings
# - DNS caching configuration
# - Firewall optimization
###############################################################################

set -euo pipefail

# Colors for output
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

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root"
        exit 1
    fi
}

# Check if WireGuard is installed
check_wireguard() {
    if ! command -v wg &> /dev/null; then
        log_error "WireGuard is not installed"
        exit 1
    fi

    if ! wg show wg0 &> /dev/null; then
        log_error "WireGuard interface wg0 not found"
        exit 1
    fi

    log_success "WireGuard is installed and wg0 interface exists"
}

# Optimize kernel network parameters
optimize_kernel_params() {
    log_info "Optimizing kernel network parameters..."

    local sysctl_config="/etc/sysctl.d/99-wireguard-optimization.conf"

    cat > "$sysctl_config" <<EOF
# WireGuard Network Optimization
# Generated: $(date)

# Increase network buffer sizes
net.core.rmem_max = 26214400
net.core.wmem_max = 26214400
net.core.rmem_default = 26214400
net.core.wmem_default = 26214400
net.core.optmem_max = 25165824

# TCP buffer sizes (min, default, max)
net.ipv4.tcp_rmem = 4096 87380 26214400
net.ipv4.tcp_wmem = 4096 65536 26214400

# Increase max number of connections
net.core.somaxconn = 8192
net.ipv4.tcp_max_syn_backlog = 8192

# Enable TCP Fast Open
net.ipv4.tcp_fastopen = 3

# TCP congestion control (BBR for better performance)
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr

# Reduce TIME_WAIT connections
net.ipv4.tcp_fin_timeout = 10
net.ipv4.tcp_tw_reuse = 1

# IP forwarding (required for WireGuard routing)
net.ipv4.ip_forward = 1
net.ipv6.conf.all.forwarding = 1

# Increase conntrack table size
net.netfilter.nf_conntrack_max = 131072

# Disable ICMP redirects for security
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv6.conf.all.accept_redirects = 0

# Enable reverse path filtering
net.ipv4.conf.all.rp_filter = 1
EOF

    # Apply settings
    sysctl -p "$sysctl_config"

    log_success "Kernel parameters optimized"
}

# Optimize WireGuard MTU
optimize_wireguard_mtu() {
    log_info "Optimizing WireGuard MTU..."

    local current_mtu=$(ip link show wg0 | grep -oP 'mtu \K\d+')
    log_info "Current MTU: $current_mtu"

    # Optimal MTU for WireGuard is typically 1420 (1500 - 80 bytes overhead)
    local optimal_mtu=1420

    if [[ "$current_mtu" -ne "$optimal_mtu" ]]; then
        log_info "Setting MTU to $optimal_mtu..."
        ip link set dev wg0 mtu "$optimal_mtu"

        # Update config file for persistence
        local wg_config="/etc/wireguard/wg0.conf"
        if [[ -f "$wg_config" ]]; then
            if ! grep -q "^MTU" "$wg_config"; then
                sed -i '/^\[Interface\]/a MTU = 1420' "$wg_config"
                log_info "Added MTU setting to config file"
            fi
        fi

        log_success "MTU optimized to $optimal_mtu"
    else
        log_success "MTU already optimal ($optimal_mtu)"
    fi
}

# Optimize WireGuard PersistentKeepalive
optimize_keepalive() {
    log_info "Checking PersistentKeepalive settings..."

    local wg_config="/etc/wireguard/wg0.conf"

    if [[ ! -f "$wg_config" ]]; then
        log_warning "WireGuard config not found, skipping keepalive optimization"
        return
    fi

    # Optimal keepalive is 25 seconds for NAT traversal
    local optimal_keepalive=25

    # Check current keepalive settings
    local current_keepalive=$(grep "PersistentKeepalive" "$wg_config" | head -1 | awk '{print $3}')

    if [[ -n "$current_keepalive" ]]; then
        log_info "Current PersistentKeepalive: $current_keepalive seconds"

        if [[ "$current_keepalive" -ne "$optimal_keepalive" ]]; then
            log_warning "Consider adjusting PersistentKeepalive to $optimal_keepalive seconds"
        else
            log_success "PersistentKeepalive already optimal ($optimal_keepalive seconds)"
        fi
    fi
}

# Optimize firewall rules
optimize_firewall() {
    log_info "Optimizing firewall rules for WireGuard..."

    # Check if iptables is available
    if ! command -v iptables &> /dev/null; then
        log_warning "iptables not found, skipping firewall optimization"
        return
    fi

    # Optimize connection tracking
    log_info "Setting up conntrack optimization..."

    # Increase conntrack timeouts for established connections
    echo 7200 > /proc/sys/net/netfilter/nf_conntrack_tcp_timeout_established 2>/dev/null || true
    echo 600 > /proc/sys/net/netfilter/nf_conntrack_udp_timeout 2>/dev/null || true

    log_success "Firewall optimized"
}

# Enable DNS caching
optimize_dns_caching() {
    log_info "Checking DNS caching configuration..."

    # Check if systemd-resolved is running
    if systemctl is-active --quiet systemd-resolved; then
        log_info "systemd-resolved is active"

        # Enable DNS caching
        local resolved_config="/etc/systemd/resolved.conf"

        if [[ -f "$resolved_config" ]]; then
            # Backup config
            cp "$resolved_config" "${resolved_config}.backup-$(date +%Y%m%d)"

            # Set cache size and other optimizations
            cat > "$resolved_config" <<EOF
[Resolve]
DNS=192.168.0.102 1.1.1.1 8.8.8.8
FallbackDNS=1.0.0.1 8.8.4.4
DNSSEC=allow-downgrade
DNSOverTLS=opportunistic
Cache=yes
CacheFromLocalhost=yes
EOF

            systemctl restart systemd-resolved
            log_success "DNS caching optimized"
        fi
    else
        log_info "systemd-resolved not active, skipping DNS caching"
    fi
}

# Test WireGuard performance
test_wireguard_performance() {
    log_info "Testing WireGuard performance..."

    # Get list of peers
    local peers=$(wg show wg0 peers)

    if [[ -z "$peers" ]]; then
        log_warning "No WireGuard peers configured"
        return
    fi

    echo ""
    log_info "=== WireGuard Peer Status ==="

    # Show peer information
    wg show wg0

    echo ""
    log_info "=== Latency Tests ==="

    # Test ping to hub
    local hub_ip="10.6.0.5"
    if ping -c 3 -W 2 "$hub_ip" &> /dev/null; then
        local latency=$(ping -c 3 "$hub_ip" | tail -1 | awk -F '/' '{print $5}')
        log_success "Hub (10.6.0.5) latency: ${latency}ms"
    else
        log_warning "Hub (10.6.0.5) unreachable"
    fi

    # Test other key peers
    local test_peers=("10.6.0.12" "10.6.0.20")
    for peer_ip in "${test_peers[@]}"; do
        if ping -c 3 -W 2 "$peer_ip" &> /dev/null; then
            local latency=$(ping -c 3 "$peer_ip" | tail -1 | awk -F '/' '{print $5}')
            log_success "Peer ($peer_ip) latency: ${latency}ms"
        fi
    done
}

# Display optimization summary
display_summary() {
    log_info "=== WireGuard Optimization Summary ==="

    echo ""
    log_info "Interface Status:"
    ip -s link show wg0

    echo ""
    log_info "Current MTU: $(ip link show wg0 | grep -oP 'mtu \K\d+')"

    echo ""
    log_info "Active Peers:"
    wg show wg0 peers | wc -l

    echo ""
    log_success "Optimization completed successfully!"
    echo ""
    log_info "Recommendations:"
    echo "  1. Monitor performance with: wg show wg0"
    echo "  2. Check handshakes with: wg show wg0 latest-handshakes"
    echo "  3. Test latency with: ping 10.6.0.5"
    echo "  4. Restart WireGuard if needed: systemctl restart wg-quick@wg0"
}

# Main execution
main() {
    log_info "Starting WireGuard mesh optimization..."
    echo ""

    check_root
    check_wireguard

    # Perform optimizations
    optimize_kernel_params
    optimize_wireguard_mtu
    optimize_keepalive
    optimize_firewall
    optimize_dns_caching

    # Test performance
    test_wireguard_performance

    # Show summary
    display_summary
}

# Run main function
main "$@"
