#!/bin/bash

###############################################################################
# WireGuard Mesh Status Script
# Shows WireGuard mesh network status and connectivity information
#
# Usage: wg-status.sh [--verbose] [--json] [--test-peers]
#   --verbose: Show detailed information
#   --json: Output in JSON format
#   --test-peers: Test connectivity to all peers
###############################################################################

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# Configuration
HUB_IP="10.6.0.5"
WG_INTERFACE="wg0"
VERBOSE=${VERBOSE:-false}
JSON_OUTPUT=${JSON_OUTPUT:-false}
TEST_PEERS=${TEST_PEERS:-false}

# Known peers with human-readable names
declare -A PEER_NAMES=(
    ["10.6.0.1"]="CT120"
    ["10.6.0.3"]="CT121"
    ["10.6.0.5"]="FGSRV6-Hub"
    ["10.6.0.10"]="AGLSRV1"
    ["10.6.0.11"]="FGSRV5"
    ["10.6.0.12"]="AGLSRV6"
    ["10.6.0.13"]="AGLSRV6B"
    ["10.6.0.14"]="CT113-PBS"
    ["10.6.0.15"]="CT172"
    ["10.6.0.16"]="FGSRV4"
    ["10.6.0.17"]="AGLSRV5"
    ["10.6.0.18"]="FGSRV3"
    ["10.6.0.19"]="CT179-Dev"
    ["10.6.0.20"]="CT111-NFS"
    ["10.6.0.21"]="CT183-Archon"
    ["10.6.0.22"]="AGLSRV6C"
    ["10.6.0.23"]="AGLSRV6D"
    ["10.6.0.24"]="CT181-Dev"
)

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[OK]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    local title=$1
    echo ""
    echo -e "${BOLD}${CYAN}=== $title ===${NC}"
}

check_wireguard_installed() {
    if ! command -v wg &> /dev/null; then
        log_error "WireGuard tools not installed"
        exit 1
    fi
}

get_local_ip() {
    ip addr show "$WG_INTERFACE" 2>/dev/null | grep "inet " | awk '{print $2}' | cut -d'/' -f1
}

format_bytes() {
    local bytes=$1
    if [ "$bytes" -lt 1024 ]; then
        echo "${bytes}B"
    elif [ "$bytes" -lt 1048576 ]; then
        echo "$((bytes / 1024))KB"
    elif [ "$bytes" -lt 1073741824 ]; then
        echo "$((bytes / 1048576))MB"
    else
        echo "$((bytes / 1073741824))GB"
    fi
}

format_duration() {
    local seconds=$1
    if [ "$seconds" -lt 60 ]; then
        echo "${seconds}s"
    elif [ "$seconds" -lt 3600 ]; then
        echo "$((seconds / 60))m $((seconds % 60))s"
    else
        echo "$((seconds / 3600))h $((seconds % 3600 / 60))m"
    fi
}

show_interface_status() {
    print_header "WireGuard Interface Status"

    if ! wg show "$WG_INTERFACE" &> /dev/null; then
        log_error "WireGuard interface $WG_INTERFACE is not running"
        return
    fi

    # Get local IP
    local local_ip=$(get_local_ip)
    echo -e "Local IP: ${BOLD}${GREEN}$local_ip${NC}"

    # Get interface stats
    local listen_port=$(wg show "$WG_INTERFACE" listen-port)
    local public_key=$(wg show "$WG_INTERFACE" public-key)
    local peer_count=$(wg show "$WG_INTERFACE" peers | wc -l)

    echo "Listen Port: $listen_port"
    echo "Public Key: ${public_key:0:20}..."
    echo "Peers Connected: $peer_count"
}

show_peer_status() {
    print_header "Peer Connectivity Status"

    if ! wg show "$WG_INTERFACE" &> /dev/null; then
        log_error "WireGuard interface $WG_INTERFACE is not running"
        return
    fi

    # Table header
    printf "%-20s %-15s %-15s %-15s %-15s\n" "Peer Name" "WireGuard IP" "Endpoint" "Handshake" "Transfer"
    printf "%s\n" "------------------------------------------------------------------------------------"

    # Get current time for handshake calculation
    local current_time=$(date +%s)

    # Iterate through peers
    wg show "$WG_INTERFACE" peers | while read -r peer_key; do
        # Get peer information
        local endpoint=$(wg show "$WG_INTERFACE" peer "$peer_key" endpoint)
        local allowed_ips=$(wg show "$WG_INTERFACE" peer "$peer_key" allowed-ips)
        local latest_handshake=$(wg show "$WG_INTERFACE" peer "$peer_key" latest-handshakes)
        local transfer_rx=$(wg show "$WG_INTERFACE" peer "$peer_key" transfer rx)
        local transfer_tx=$(wg show "$WG_INTERFACE" peer "$peer_key" transfer tx)

        # Extract IP from allowed_ips
        local peer_ip=$(echo "$allowed_ips" | awk '{print $1}' | cut -d'/' -f1)

        # Get peer name
        local peer_name="${PEER_NAMES[$peer_ip]:-Unknown}"
        local is_hub="false"
        [ "$peer_ip" = "$HUB_IP" ] && is_hub="true"

        # Format endpoint
        local endpoint_display=$(echo "$endpoint" | sed 's|:(null)|:N/A|g')

        # Calculate handshake status
        local handshake_status=""
        local handshake_color=""
        if [ -z "$latest_handshake" ] || [ "$latest_handshake" -eq 0 ]; then
            handshake_status="Never"
            handshake_color="$RED"
        else
            local time_since=$((current_time - latest_handshake))
            if [ $time_since -lt 180 ]; then
                handshake_status="$(format_duration $time_since) ago"
                handshake_color="$GREEN"
            elif [ $time_since -lt 3600 ]; then
                handshake_status="$(format_duration $time_since) ago"
                handshake_color="$YELLOW"
            else
                handshake_status="$(format_duration $time_since) ago"
                handshake_color="$RED"
            fi
        fi

        # Format transfer
        local rx_formatted=$(format_bytes $transfer_rx)
        local tx_formatted=$(format_bytes $transfer_tx)

        # Print row
        local name_color=""
        [ "$is_hub" = "true" ] && name_color="$BOLD"

        printf "${name_color}%-20s${NC} %-15s %-15s ${handshake_color}%-15s${NC} %-15s\n" \
            "$peer_name" \
            "$peer_ip" \
            "$endpoint_display" \
            "$handshake_status" \
            "↓${rx_formatted} ↑${tx_formatted}"

        # Show verbose info if requested
        if [ "$VERBOSE" = "true" ]; then
            echo "  Public Key: ${peer_key:0:40}..."
            echo "  Allowed IPs: $allowed_ips"
            echo ""
        fi
    done
}

show_connectivity_tests() {
    if [ "$TEST_PEERS" != "true" ]; then
        return
    fi

    print_header "Connectivity Tests"

    if ! wg show "$WG_INTERFACE" &> /dev/null; then
        log_error "WireGuard interface $WG_INTERFACE is not running"
        return
    fi

    # Test connectivity to hub first
    echo -n "Testing Hub ($HUB_IP)... "
    if ping -c 1 -W 2 "$HUB_IP" &> /dev/null; then
        local latency=$(ping -c 1 "$HUB_IP" | grep "time=" | awk -F'time=' '{print $2}' | awk '{print $1}')
        echo -e "${GREEN}✓${NC} (${latency}ms)"
    else
        echo -e "${RED}✗${NC} Unreachable"
    fi

    # Test connectivity to other peers
    wg show "$WG_INTERFACE" peers | while read -r peer_key; do
        local allowed_ips=$(wg show "$WG_INTERFACE" peer "$peer_key" allowed-ips)
        local peer_ip=$(echo "$allowed_ips" | awk '{print $1}' | cut -d'/' -f1)
        local peer_name="${PEER_NAMES[$peer_ip]:-Unknown}"

        # Skip hub (already tested)
        [ "$peer_ip" = "$HUB_IP" ] && continue

        echo -n "Testing $peer_name ($peer_ip)... "
        if ping -c 1 -W 1 "$peer_ip" &> /dev/null; then
            local latency=$(ping -c 1 "$peer_ip" 2>/dev/null | grep "time=" | awk -F'time=' '{print $2}' | awk '{print $1}')
            echo -e "${GREEN}✓${NC} (${latency}ms)"
        else
            echo -e "${RED}✗${NC} Unreachable"
        fi
    done
}

show_interface_stats() {
    print_header "Interface Statistics"

    if ! ip link show "$WG_INTERFACE" &> /dev/null; then
        log_error "Interface $WG_INTERFACE not found"
        return
    fi

    # Get interface statistics
    local stats=$(ip -s link show "$WG_INTERFACE")
    local rx_packets=$(echo "$stats" | awk '/RX:/ {getline; print $1}')
    local rx_bytes=$(echo "$stats" | awk '/RX:/ {getline; print $2}')
    local tx_packets=$(echo "$stats" | awk '/TX:/ {getline; print $1}')
    local tx_bytes=$(echo "$stats" | awk '/TX:/ {getline; print $2}')

    echo "RX Packets: $(format_bytes $rx_packets) ($rx_bytes bytes)"
    echo "TX Packets: $(format_bytes $tx_packets) ($tx_bytes bytes)"

    # Get MTU
    local mtu=$(ip link show "$WG_INTERFACE" | grep -oP 'mtu \K\d+')
    echo "MTU: $mtu"

    # Get interface state
    local state=$(ip link show "$WG_INTERFACE" | grep -oP 'state \K\w+')
    local state_color=""
    [ "$state" = "UNKNOWN" ] && state_color="$GREEN"
    [ "$state" = "DOWN" ] && state_color="$RED"
    echo -e "State: ${state_color}${state}${NC}"
}

show_routing_table() {
    if [ "$VERBOSE" != "true" ]; then
        return
    fi

    print_header "Routing Table"

    ip route show dev "$WG_INTERFACE" 2>/dev/null || echo "No routes configured"
}

show_json_output() {
    if [ "$JSON_OUTPUT" != "true" ]; then
        return
    fi

    # Build JSON output
    local json="{"
    json+='"interface":"'"$WG_INTERFACE"'",'
    json+='"local_ip":"'"$(get_local_ip)"'",'
    json+='"listen_port":"'$(wg show "$WG_INTERFACE" listen-port)"'",'
    json+='"peer_count":'$(wg show "$WG_INTERFACE" peers | wc -l)','
    json+='"peers":['

    local first=true
    wg show "$WG_INTERFACE" peers | while read -r peer_key; do
        if [ "$first" = "true" ]; then
            first=false
        else
            json+=","
        fi

        local allowed_ips=$(wg show "$WG_INTERFACE" peer "$peer_key" allowed-ips)
        local peer_ip=$(echo "$allowed_ips" | awk '{print $1}' | cut -d'/' -f1)
        local peer_name="${PEER_NAMES[$peer_ip]:-Unknown}"
        local endpoint=$(wg show "$WG_INTERFACE" peer "$peer_key" endpoint)
        local latest_handshake=$(wg show "$WG_INTERFACE" peer "$peer_key" latest-handshakes)
        local transfer_rx=$(wg show "$WG_INTERFACE" peer "$peer_key" transfer rx)
        local transfer_tx=$(wg show "$WG_INTERFACE" peer "$peer_key" transfer tx)

        json+='{'
        json+='"name":"'"$peer_name"'",'
        json+='"ip":"'"$peer_ip"'",'
        json+='"endpoint":"'"$endpoint"'",'
        json+='"latest_handshake":'$latest_handshake','
        json+='"transfer_rx":'$transfer_rx','
        json+='"transfer_tx":'$transfer_tx
        json+='}'
    done

    json+=']}"

    echo ""
    echo "$json"
}

print_summary() {
    print_header "Summary"

    if ! wg show "$WG_INTERFACE" &> /dev/null; then
        log_error "WireGuard interface $WG_INTERFACE is not running"
        echo ""
        echo "Troubleshooting:"
        echo "  1. Start WireGuard: wg-quick up $WG_INTERFACE"
        echo "  2. Check config: cat /etc/wireguard/${WG_INTERFACE}.conf"
        echo "  3. View logs: journalctl -u wg-quick@$WG_INTERFACE -n 50"
        return
    fi

    local local_ip=$(get_local_ip)
    local peer_count=$(wg show "$WG_INTERFACE" peers | wc -l)
    local hub_handshake=$(wg show "$WG_INTERFACE" peers | while read -r pk; do
        local ips=$(wg show "$WG_INTERFACE" peer "$pk" allowed-ips)
        if [[ "$ips" == *"$HUB_IP/32"* ]]; then
            wg show "$WG_INTERFACE" peer "$pk" latest-handshakes
            break
        fi
    done)

    local hub_status=""
    if [ -z "$hub_handshake" ] || [ "$hub_handshake" -eq 0 ]; then
        hub_status="${RED}Not Connected${NC}"
    else
        local current_time=$(date +%s)
        local time_since=$((current_time - hub_handshake))
        if [ $time_since -lt 180 ]; then
            hub_status="${GREEN}Connected${NC} ($(format_duration $time_since) ago)"
        else
            hub_status="${YELLOW}Stale${NC} ($(format_duration $time_since) ago)"
        fi
    fi

    echo "Local IP: $local_ip"
    echo "Peers: $peer_count"
    echo -e "Hub Status: $hub_status"

    echo ""
    echo "Quick Commands:"
    echo "  Restart: systemctl restart wg-quick@$WG_INTERFACE"
    echo "  Logs: journalctl -u wg-quick@$WG_INTERFACE -f"
    echo "  Config: cat /etc/wireguard/${WG_INTERFACE}.conf"
    echo "  Test hub: ping $HUB_IP"
}

# Main execution
main() {
    # Parse arguments
    while [ $# -gt 0 ]; do
        case $1 in
            --verbose)
                VERBOSE=true
                shift
                ;;
            --json)
                JSON_OUTPUT=true
                shift
                ;;
            --test-peers)
                TEST_PEERS=true
                shift
                ;;
            -h|--help)
                echo "Usage: $0 [--verbose] [--json] [--test-peers]"
                echo ""
                echo "Options:"
                echo "  --verbose    Show detailed information"
                echo "  --json       Output in JSON format"
                echo "  --test-peers Test connectivity to all peers"
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                exit 1
                ;;
        esac
    done

    # Check WireGuard installation
    check_wireguard_installed

    # Show status
    show_interface_status
    echo ""
    show_peer_status
    echo ""
    show_connectivity_tests
    show_interface_stats
    show_routing_table
    show_json_output
    print_summary
    echo ""
}

# Run main function
main "$@"
