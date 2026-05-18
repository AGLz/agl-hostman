#!/bin/bash
################################################################################
# Network Diagnostics
#
# Description: Check network connectivity and routing
# Output: JSON report with findings and recommendations
# Usage: ./diag-network.sh [--target host]
################################################################################

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_HOST="${1:-google.com}"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# JSON output structure
json_output='{
  "scan_info": {
    "timestamp": "'"$TIMESTAMP"'",
    "scan_version": "1.0.0",
    "target": "'"$TARGET_HOST"'"
  },
  "checks": {}
}'

# Helper functions
add_finding() {
    local category="$1"
    local check="$2"
    local status="$3"
    local message="$4"
    local recommendation="${5:-}"

    json_output=$(echo "$json_output" | jq --arg cat "$category" --arg chk "$check" --arg st "$status" --arg msg "$message" --arg rec "$recommendation" '
        .checks[$cat] |= . + {
            $chk: {
                "status": $st,
                "message": $msg,
                "recommendation": $rec
            }
        }
    ')
}

################################################################################
# Interface Check
################################################################################
check_interfaces() {
    echo "Checking network interfaces..."

    local interface_count=0
    local active_interfaces=0

    # Get list of network interfaces
    while read -r iface state; do
        interface_count=$((interface_count + 1))
        if [ "$state" = "UP" ] || [ "$state" = "UNKNOWN" ]; then
            active_interfaces=$((active_interfaces + 1))
        fi
    done < <(ip link show 2>/dev/null | grep -E "^[0-9]+:" | awk '{print $2, $9}')

    echo "  Total interfaces: $interface_count"
    echo "  Active interfaces: $active_interfaces"

    if [ "$active_interfaces" -eq 0 ]; then
        add_finding "interfaces" "status" "critical" "No active network interfaces" "Check network configuration"
    else
        add_finding "interfaces" "status" "pass" "$active_interfaces active interface(s)" ""
    fi

    # Show interface details
    echo "  Interface details:"
    ip addr show 2>/dev/null | grep -E "^[0-9]+:|inet " | while read -r line; do
        if [[ "$line" =~ ^[0-9]+: ]]; then
            local iface=$(echo "$line" | awk '{print $2}' | tr -d ':')
            echo "    $iface"
        elif [[ "$line" =~ inet ]]; then
            local ip=$(echo "$line" | awk '{print $2}')
            echo "      $ip"
        fi
    done
}

################################################################################
# Routing Check
################################################################################
check_routing() {
    echo "Checking routing..."

    # Check default gateway
    local gateway=$(ip route | grep default | awk '{print $3}')

    if [ -n "$gateway" ]; then
        echo "  Default gateway: $gateway"

        # Ping gateway
        if ping -c 1 -W 2 "$gateway" &>/dev/null; then
            echo "  Gateway reachable"
            add_finding "routing" "gateway" "pass" "Gateway $gateway reachable" ""
        else
            echo "  ERROR: Gateway not reachable"
            add_finding "routing" "gateway" "critical" "Gateway $gateway not reachable" "Check network configuration"
        fi
    else
        echo "  WARNING: No default gateway found"
        add_finding "routing" "gateway" "warning" "No default gateway configured" "Configure default gateway"
    fi

    # Show routing table
    echo "  Routing table:"
    ip route show 2>/dev/null | head -5 | while read -r route; do
        echo "    $route"
    done
}

################################################################################
# DNS Check
################################################################################
check_dns() {
    echo "Checking DNS..."

    # Check DNS servers
    local dns_servers=$(cat /etc/resolv.conf 2>/dev/null | grep "nameserver" | awk '{print $2}')

    if [ -z "$dns_servers" ]; then
        echo "  WARNING: No DNS servers configured"
        add_finding "dns" "servers" "warning" "No DNS servers configured" "Configure DNS in /etc/resolv.conf"
        return
    fi

    echo "  DNS servers:"
    echo "$dns_servers" | while read -r dns; do
        echo "    $dns"
    done

    # Test DNS resolution
    if command -v nslookup &>/dev/null; then
        if nslookup "$TARGET_HOST" &>/dev/null; then
            echo "  DNS resolution working"
            add_finding "dns" "resolution" "pass" "DNS resolution working for $TARGET_HOST" ""
        else
            echo "  ERROR: DNS resolution failed"
            add_finding "dns" "resolution" "critical" "Cannot resolve $TARGET_HOST" "Check DNS configuration"
        fi
    fi

    # Test DNS to 8.8.8.8
    if ping -c 1 -W 2 8.8.8.8 &>/dev/null; then
        echo "  External IP reachable (8.8.8.8)"
        add_finding "dns" "external_ip" "pass" "Can reach 8.8.8.8" ""
    else
        echo "  WARNING: Cannot reach 8.8.8.8"
        add_finding "dns" "external_ip" "warning" "Cannot reach 8.8.8.8" "Check internet connectivity"
    fi
}

################################################################################
# Connectivity Check
################################################################################
check_connectivity() {
    echo "Checking connectivity..."

    # Test basic connectivity
    if ping -c 3 -W 2 "$TARGET_HOST" &>/dev/null; then
        echo "  Can reach $TARGET_HOST"
        add_finding "connectivity" "ping" "pass" "Can ping $TARGET_HOST" ""
    else
        echo "  ERROR: Cannot reach $TARGET_HOST"
        add_finding "connectivity" "ping" "critical" "Cannot ping $TARGET_HOST" "Check network connectivity"
    fi

    # Test HTTP/HTTPS if curl is available
    if command -v curl &>/dev/null; then
        if curl -s -o /dev/null -w "%{http_code}" "https://$TARGET_HOST" | grep -q "200\|301\|302"; then
            echo "  HTTPS working"
            add_finding "connectivity" "https" "pass" "HTTPS working for $TARGET_HOST" ""
        else
            echo "  WARNING: HTTPS not working"
            add_finding "connectivity" "https" "warning" "HTTPS not working for $TARGET_HOST" "Check firewall/proxy"
        fi
    fi
}

################################################################################
# Port Check
################################################################################
check_ports() {
    echo "Checking common ports..."

    # Common ports to check
    local ports=("22" "80" "443" "3306" "6379" "8006")

    for port in "${ports[@]}"; do
        if command -v nc &>/dev/null; then
            if nc -zv 127.0.0.1 "$port" 2>&1 | grep -q "succeeded"; then
                echo "  Port $port: listening"
            else
                echo "  Port $port: not listening"
            fi
        fi
    done
}

################################################################################
# Firewall Check
################################################################################
check_firewall() {
    echo "Checking firewall..."

    # Check UFW if available
    if command -v ufw &>/dev/null; then
        local ufw_status=$(ufw status | head -1)
        echo "  UFW: $ufw_status"
        add_finding "firewall" "ufw" "pass" "$ufw_status" ""
    fi

    # Check iptables rules count
    if command -v iptables &>/dev/null; then
        local iptables_rules=$(iptables -L -n 2>/dev/null | wc -l)
        echo "  iptables rules: $iptables_rules"
        add_finding "firewall" "iptables" "pass" "$iptables_rules iptables rules" ""
    fi
}

################################################################################
# VPN Check
################################################################################
check_vpn() {
    echo "Checking VPN..."

    # Check WireGuard
    if command -v wg &>/dev/null; then
        if wg show wg0 &>/dev/null; then
            local wg_peers=$(wg show wg0 peers | wc -l)
            local wg_handshakes=$(wg show wg0 latest-handshakes | wc -l)
            echo "  WireGuard: active ($wg_peers peers)"
            add_finding "vpn" "wireguard" "pass" "WireGuard active with $wg_peers peers" ""
        else
            echo "  WireGuard: not active"
            add_finding "vpn" "wireguard" "info" "WireGuard not active" ""
        fi
    fi

    # Check Tailscale
    if command -v tailscale &>/dev/null; then
        if tailscale status &>/dev/null; then
            local ts_peers=$(tailscale status --peers 2>/dev/null | grep -c "-" || echo "0")
            echo "  Tailscale: active ($ts_peers peers)"
            add_finding "vpn" "tailscale" "pass" "Tailscale active with $ts_peers peers" ""
        else
            echo "  Tailscale: not active"
            add_finding "vpn" "tailscale" "info" "Tailscale not active" ""
        fi
    fi
}

################################################################################
# Latency Check
################################################################################
check_latency() {
    echo "Checking latency..."

    # Measure latency to target
    if command -v ping &>/dev/null; then
        local latency=$(ping -c 5 -W 2 "$TARGET_HOST" 2>/dev/null | tail -1 | awk -F '/' '{print $5}' || echo "0")

        if [ "$latency" != "0" ]; then
            echo "  Latency to $TARGET_HOST: ${latency}ms"

            # Check if latency is high
            if (( $(echo "$latency > 150" | bc -l 2>/dev/null || echo "0") )); then
                add_finding "latency" "target" "warning" "High latency: ${latency}ms" "Check network congestion"
            elif (( $(echo "$latency > 50" | bc -l 2>/dev/null || echo "0") )); then
                add_finding "latency" "target" "pass" "Latency: ${latency}ms" ""
            else
                add_finding "latency" "target" "pass" "Good latency: ${latency}ms" ""
            fi
        fi
    fi

    # Check local network latency (ping gateway)
    local gateway=$(ip route | grep default | awk '{print $3}')
    if [ -n "$gateway" ]; then
        local gateway_latency=$(ping -c 5 -W 2 "$gateway" 2>/dev/null | tail -1 | awk -F '/' '{print $5}' || echo "0")
        echo "  Gateway latency: ${gateway_latency}ms"
    fi
}

################################################################################
# Main Execution
################################################################################
main() {
    echo "=== Network Diagnostic Scan ==="
    echo "Timestamp: $TIMESTAMP"
    echo "Target: $TARGET_HOST"
    echo ""

    # Run all checks
    check_interfaces
    check_routing
    check_dns
    check_connectivity
    check_ports
    check_firewall
    check_vpn
    check_latency

    # Output JSON report
    echo ""
    echo "=== JSON Report ==="
    echo "$json_output" | jq '.'

    # Check for critical issues
    local critical=$(echo "$json_output" | jq '[.checks[][] | select(.status == "critical")] | length')
    if [ "$critical" -gt 0 ]; then
        exit 1
    fi

    exit 0
}

main "$@"
