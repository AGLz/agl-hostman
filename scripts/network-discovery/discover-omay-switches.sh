#!/bin/bash
#
# OMAY Switch Discovery Script
# Multi-method network discovery for OMAY managed switches
#
# Usage: ./discover-omay-switches.sh [subnet]
# Example: ./discover-omay-switches.sh 192.168.0.0/24
#

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESULTS_DIR="${SCRIPT_DIR}/results"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
RESULTS_FILE="${RESULTS_DIR}/omay_discovery_${TIMESTAMP}.txt"
JSON_FILE="${RESULTS_DIR}/omay_discovery_${TIMESTAMP}.json"

# Known OMAY MAC OUI prefixes (first 3 octets)
OMAY_MAC_PATTERNS=(
    "00:0E:C4"  # Common Taiwanese manufacturer
    "00:11:22"  # Example - need to research actual OMAY OUI
    "00:50:C2"  # Another potential prefix
)

# Common switch management ports
SWITCH_PORTS="22,23,80,443,8080,161"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $*" | tee -a "${RESULTS_FILE}"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*" | tee -a "${RESULTS_FILE}"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $*" | tee -a "${RESULTS_FILE}"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*" | tee -a "${RESULTS_FILE}"
}

check_dependencies() {
    local missing_deps=()

    for cmd in nmap arp-scan fping ip; do
        if ! command -v "$cmd" &> /dev/null; then
            missing_deps+=("$cmd")
        fi
    done

    if [ ${#missing_deps[@]} -ne 0 ]; then
        log_error "Missing dependencies: ${missing_deps[*]}"
        log_info "Install with: apt-get install -y nmap arp-scan fping iproute2"
        exit 1
    fi

    log_success "All dependencies available"
}

detect_subnets() {
    log_info "Detecting local subnets..."

    # Get all non-loopback, non-docker IPv4 subnets
    SUBNETS=$(ip -4 addr show | \
        grep -E "inet.*scope global" | \
        grep -v "docker\|tailscale" | \
        awk '{print $2}' | \
        sed 's/\.[0-9]\+\//.0\//')

    if [ -z "$SUBNETS" ]; then
        log_error "No subnets detected"
        exit 1
    fi

    echo "$SUBNETS" | while read -r subnet; do
        log_info "Found subnet: $subnet"
    done

    echo "$SUBNETS"
}

arp_scan_discovery() {
    local subnet="$1"
    log_info "Running ARP scan on $subnet..."

    # Requires root/sudo
    if ! arp-scan -q -x "$subnet" 2>/dev/null; then
        log_warning "ARP scan failed (may need sudo)"
        return 1
    fi
}

ping_sweep() {
    local subnet="$1"
    log_info "Running ping sweep on $subnet..."

    # Fast ping sweep with fping
    fping -a -g "$subnet" 2>/dev/null || true
}

nmap_discovery() {
    local subnet="$1"
    log_info "Running nmap discovery on $subnet..."

    # Fast host discovery with common switch ports
    nmap -sn -PS"${SWITCH_PORTS}" -PA"${SWITCH_PORTS}" \
         --min-rate 1000 --max-retries 2 \
         "$subnet" 2>/dev/null | \
         grep "Nmap scan report" | \
         awk '{print $5}'
}

port_scan_switches() {
    local ip="$1"
    log_info "Scanning switch ports on $ip..."

    # Quick port scan for switch management interfaces
    nmap -Pn -sT -p "${SWITCH_PORTS}" --open \
         --max-retries 1 --host-timeout 5s \
         "$ip" 2>/dev/null
}

get_mac_address() {
    local ip="$1"

    # Check ARP table
    ip neighbor show "$ip" 2>/dev/null | awk '{print $5}' | grep -E '^[0-9a-f]{2}:' || echo "Unknown"
}

check_omay_mac() {
    local mac="$1"

    # Convert to uppercase and get OUI
    local oui=$(echo "$mac" | tr '[:lower:]' '[:upper:]' | cut -d: -f1-3)

    for pattern in "${OMAY_MAC_PATTERNS[@]}"; do
        if [ "$oui" = "$pattern" ]; then
            return 0
        fi
    done

    return 1
}

probe_web_interface() {
    local ip="$1"
    log_info "Probing web interface on $ip..."

    # Try HTTP
    local http_response=$(curl -s -m 2 -o /dev/null -w "%{http_code}" "http://${ip}" 2>/dev/null || echo "000")

    # Try HTTPS
    local https_response=$(curl -s -k -m 2 -o /dev/null -w "%{http_code}" "https://${ip}" 2>/dev/null || echo "000")

    echo "HTTP: $http_response, HTTPS: $https_response"

    # Check for switch-specific headers or content
    if [ "$http_response" != "000" ]; then
        local headers=$(curl -s -m 2 -I "http://${ip}" 2>/dev/null | grep -i "server\|omay\|switch")
        if [ -n "$headers" ]; then
            echo "Headers: $headers"
        fi
    fi
}

identify_device() {
    local ip="$1"
    local mac="$2"

    log_info "Identifying device at $ip ($mac)..."

    # Run port scan
    local port_scan=$(port_scan_switches "$ip")

    # Check for web interface
    local web_info=$(probe_web_interface "$ip")

    # Check MAC OUI
    local is_omay=false
    if check_omay_mac "$mac"; then
        is_omay=true
        log_success "Potential OMAY switch detected (MAC OUI match): $ip"
    fi

    # Look for switch indicators
    if echo "$port_scan" | grep -q "open"; then
        log_info "Switch management ports detected on $ip"

        # Generate JSON entry
        cat >> "$JSON_FILE" <<EOF
{
  "ip": "$ip",
  "mac": "$mac",
  "is_omay_candidate": $is_omay,
  "open_ports": "$(echo "$port_scan" | grep "open" | awk '{print $1}' | tr '\n' ',' | sed 's/,$//')",
  "web_interface": "$web_info",
  "timestamp": "$(date -Iseconds)"
}
EOF

        return 0
    fi

    return 1
}

main() {
    # Setup
    mkdir -p "$RESULTS_DIR"
    echo "# OMAY Switch Discovery Results" > "$RESULTS_FILE"
    echo "# Timestamp: $(date)" >> "$RESULTS_FILE"
    echo "# Hostname: $(hostname)" >> "$RESULTS_FILE"
    echo "" >> "$RESULTS_FILE"
    echo "[" > "$JSON_FILE"

    log_info "Starting OMAY switch discovery..."
    check_dependencies

    # Determine subnets to scan
    local target_subnets
    if [ $# -gt 0 ]; then
        target_subnets="$1"
        log_info "Using provided subnet: $target_subnets"
    else
        target_subnets=$(detect_subnets)
    fi

    # Discover hosts
    log_info "Step 1: Host discovery across all subnets"
    local all_hosts=()

    while IFS= read -r subnet; do
        log_info "Scanning subnet: $subnet"

        # Method 1: ARP scan
        local arp_hosts=$(arp_scan_discovery "$subnet" || echo "")

        # Method 2: Ping sweep
        local ping_hosts=$(ping_sweep "$subnet" || echo "")

        # Method 3: Nmap discovery
        local nmap_hosts=$(nmap_discovery "$subnet" || echo "")

        # Combine all results
        all_hosts+=($(echo -e "${arp_hosts}\n${ping_hosts}\n${nmap_hosts}" | sort -u))
    done <<< "$target_subnets"

    log_info "Found ${#all_hosts[@]} unique hosts"

    # Identify switches
    log_info "Step 2: Identifying switch devices"
    local switch_count=0

    for host in "${all_hosts[@]}"; do
        if [ -n "$host" ]; then
            local mac=$(get_mac_address "$host")

            if identify_device "$host" "$mac"; then
                ((switch_count++))
            fi
        fi
    done

    # Finalize JSON
    echo "]" >> "$JSON_FILE"

    # Summary
    log_success "Discovery complete!"
    log_info "Total hosts scanned: ${#all_hosts[@]}"
    log_info "Potential switches found: $switch_count"
    log_info "Results saved to:"
    log_info "  - Text: $RESULTS_FILE"
    log_info "  - JSON: $JSON_FILE"

    # Display results
    if [ -f "$JSON_FILE" ]; then
        log_info "Switch candidates:"
        cat "$JSON_FILE" | grep -E "ip|mac|is_omay" | head -20
    fi
}

# Run main function
main "$@"
