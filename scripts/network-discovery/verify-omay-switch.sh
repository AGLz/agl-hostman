#!/bin/bash
#
# OMAY Switch Verification Script
# Deep verification of suspected OMAY switches
#
# Usage: ./verify-omay-switch.sh <IP_ADDRESS>
# Example: ./verify-omay-switch.sh 192.168.0.254
#

set -euo pipefail

# Configuration
IP_ADDRESS="${1:-}"
VERBOSE="${VERBOSE:-false}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

log_success() {
    echo -e "${GREEN}[✓]${NC} $*"
}

log_warning() {
    echo -e "${YELLOW}[!]${NC} $*"
}

log_error() {
    echo -e "${RED}[✗]${NC} $*"
}

usage() {
    cat <<EOF
Usage: $0 <IP_ADDRESS>

Verify if a device is an OMAY managed switch.

Options:
    VERBOSE=true    Enable verbose output

Example:
    $0 192.168.0.254
    VERBOSE=true $0 192.168.1.1
EOF
    exit 1
}

check_connectivity() {
    log_info "Checking connectivity to $IP_ADDRESS..."

    if ping -c 1 -W 2 "$IP_ADDRESS" &>/dev/null; then
        log_success "Host is reachable"
        return 0
    else
        log_error "Host is unreachable"
        return 1
    fi
}

get_mac_info() {
    log_info "Retrieving MAC address..."

    local mac=$(ip neighbor show "$IP_ADDRESS" 2>/dev/null | awk '{print $5}')

    if [ -z "$mac" ]; then
        # Force ARP discovery
        ping -c 1 -W 1 "$IP_ADDRESS" &>/dev/null || true
        sleep 1
        mac=$(ip neighbor show "$IP_ADDRESS" 2>/dev/null | awk '{print $5}')
    fi

    if [ -n "$mac" ]; then
        log_success "MAC Address: $mac"

        # Look up OUI
        local oui=$(echo "$mac" | cut -d: -f1-3 | tr '[:lower:]' '[:upper:]')
        log_info "MAC OUI: $oui"

        # Check against known OMAY OUIs
        case "$oui" in
            00:0E:C4|00:11:22|00:50:C2)
                log_success "MAC OUI matches known OMAY prefix!"
                return 0
                ;;
            *)
                log_warning "MAC OUI does not match known OMAY prefixes"
                return 1
                ;;
        esac
    else
        log_warning "Could not retrieve MAC address"
        return 1
    fi
}

scan_ports() {
    log_info "Scanning management ports..."

    local nmap_output=$(nmap -Pn -sV -p 22,23,80,443,8080,161 --open "$IP_ADDRESS" 2>/dev/null)

    if [ "$VERBOSE" = "true" ]; then
        echo "$nmap_output"
    fi

    # Extract open ports
    local open_ports=$(echo "$nmap_output" | grep "^[0-9]" | grep "open")

    if [ -n "$open_ports" ]; then
        log_success "Open management ports found:"
        echo "$open_ports" | while read -r line; do
            echo "  - $line"
        done
        return 0
    else
        log_warning "No standard management ports detected"
        return 1
    fi
}

probe_http() {
    log_info "Probing HTTP/HTTPS interfaces..."

    local found_web=false

    # Try HTTP
    if timeout 3 curl -s -f "http://${IP_ADDRESS}" -o /tmp/http_response.html 2>/dev/null; then
        log_success "HTTP interface available (Port 80)"

        # Check for OMAY indicators
        if grep -qi "omay\|switch\|managed" /tmp/http_response.html 2>/dev/null; then
            log_success "Found switch-related content in HTTP response"
            found_web=true
        fi
    fi

    # Try HTTPS
    if timeout 3 curl -s -k -f "https://${IP_ADDRESS}" -o /tmp/https_response.html 2>/dev/null; then
        log_success "HTTPS interface available (Port 443)"

        # Check for OMAY indicators
        if grep -qi "omay\|switch\|managed" /tmp/https_response.html 2>/dev/null; then
            log_success "Found switch-related content in HTTPS response"
            found_web=true
        fi
    fi

    # Get HTTP headers
    local headers=$(timeout 2 curl -s -I "http://${IP_ADDRESS}" 2>/dev/null | head -10)
    if [ -n "$headers" ]; then
        log_info "HTTP Headers:"
        echo "$headers" | grep -i "server\|content-type\|omay" | sed 's/^/  /'
    fi

    $found_web && return 0 || return 1
}

try_telnet() {
    log_info "Attempting telnet connection..."

    if timeout 3 bash -c "echo | nc -w 2 $IP_ADDRESS 23" 2>/dev/null | grep -qi "login\|username\|password\|switch\|omay"; then
        log_success "Telnet service detected with login prompt"
        return 0
    else
        log_warning "Telnet not available or no login prompt"
        return 1
    fi
}

try_ssh() {
    log_info "Attempting SSH banner grab..."

    local ssh_banner=$(timeout 3 ssh -o ConnectTimeout=2 -o StrictHostKeyChecking=no "$IP_ADDRESS" 2>&1 | head -5)

    if [ -n "$ssh_banner" ]; then
        log_info "SSH Banner:"
        echo "$ssh_banner" | sed 's/^/  /'

        if echo "$ssh_banner" | grep -qi "omay\|switch"; then
            log_success "SSH banner indicates OMAY switch"
            return 0
        fi
    else
        log_warning "SSH not available"
        return 1
    fi
}

try_snmp() {
    log_info "Attempting SNMP query..."

    if ! command -v snmpwalk &>/dev/null; then
        log_warning "snmpwalk not installed (install with: apt-get install snmp)"
        return 1
    fi

    # Try common community strings
    for community in public private admin; do
        local snmp_result=$(timeout 3 snmpwalk -v2c -c "$community" "$IP_ADDRESS" system.sysDescr.0 2>/dev/null)

        if [ -n "$snmp_result" ]; then
            log_success "SNMP accessible with community '$community'"
            log_info "System Description:"
            echo "$snmp_result" | sed 's/^/  /'

            if echo "$snmp_result" | grep -qi "omay\|switch"; then
                log_success "SNMP description indicates OMAY switch"
                return 0
            fi
        fi
    done

    log_warning "SNMP not accessible with common community strings"
    return 1
}

generate_report() {
    local score="$1"

    echo ""
    echo "═══════════════════════════════════════════════════"
    echo "         OMAY Switch Verification Report"
    echo "═══════════════════════════════════════════════════"
    echo "Target IP:       $IP_ADDRESS"
    echo "Timestamp:       $(date)"
    echo "Confidence:      $score/6"
    echo ""

    if [ "$score" -ge 4 ]; then
        log_success "High confidence: This is likely an OMAY managed switch"
        echo "Recommendation: Proceed with configuration"
    elif [ "$score" -ge 2 ]; then
        log_warning "Medium confidence: Could be an OMAY switch or similar device"
        echo "Recommendation: Manual verification recommended"
    else
        log_error "Low confidence: Unlikely to be an OMAY switch"
        echo "Recommendation: Verify device type manually"
    fi

    echo "═══════════════════════════════════════════════════"
}

main() {
    if [ -z "$IP_ADDRESS" ]; then
        usage
    fi

    echo "═══════════════════════════════════════════════════"
    echo "       OMAY Switch Verification Tool v1.0"
    echo "═══════════════════════════════════════════════════"
    echo ""

    local confidence_score=0

    # Run verification steps
    check_connectivity && ((confidence_score++)) || true
    get_mac_info && ((confidence_score++)) || true
    scan_ports && ((confidence_score++)) || true
    probe_http && ((confidence_score++)) || true
    try_telnet && ((confidence_score++)) || true
    try_ssh && ((confidence_score++)) || true
    # try_snmp && ((confidence_score++)) || true  # Optional - requires snmp package

    # Generate report
    generate_report "$confidence_score"
}

# Trap errors
trap 'log_error "Script failed at line $LINENO"' ERR

# Run main
main "$@"
