#!/bin/bash

###############################################################################
# Network Protocol Analysis Script
# Analyzes network traffic by protocol and shows detailed breakdown
#
# Usage: net-protocols.sh [options]
#   -i, --interface INTERFACE  Network interface (default: wg0)
#   -c, --count NUM             Number of packets to analyze (default: 10000)
#   -t, --top NUM               Show top N talkers (default: 10)
#   -p, --port                  Show port-based breakdown
#   -d, --duration SECONDS      Capture duration
#   -j, --json                  Output in JSON format
#   -v, --verbose               Verbose output
#   -h, --help                  Show this help
###############################################################################

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m'

# Default values
INTERFACE="${PROTOCOL_INTERFACE:-wg0}"
COUNT=10000
TOP_NUM=10
SHOW_PORTS=false
DURATION=30
JSON_OUTPUT=false
VERBOSE=false

# Temporary files
CAPTURE_FILE=$(mktemp -t capture-XXXXXX.pcap)
TMP_FILE=$(mktemp)

# Cleanup trap
trap cleanup EXIT

cleanup() {
    rm -f "$CAPTURE_FILE" "$TMP_FILE"
}

# Logging functions
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

log_verbose() {
    if [ "$VERBOSE" = "true" ]; then
        echo -e "${CYAN}[DEBUG]${NC} $1"
    fi
}

# Check if running as root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        log_error "This script must be run as root"
        exit 1
    fi
}

# Check if tcpdump is installed
check_tcpdump() {
    if ! command -v tcpdump &> /dev/null; then
        log_error "tcpdump not installed"
        log_info "Install with: apt install tcpdump"
        exit 1
    fi
}

# Check if interface exists
check_interface() {
    if ! ip link show "$INTERFACE" &> /dev/null; then
        log_error "Interface $INTERFACE does not exist"
        log_info "Available interfaces:"
        ip link show | grep -E '^[0-9]+:' | awk '{print "  " $2}' | sed 's/:$//'
        exit 1
    fi
}

# Capture traffic
capture_traffic() {
    log_info "Capturing $COUNT packets on $INTERFACE..."

    if [ "$VERBOSE" = "true" ]; then
        tcpdump -i "$INTERFACE" -c "$COUNT" -w "$CAPTURE_FILE" -v 2>&1 | tee "$TMP_FILE"
    else
        tcpdump -i "$INTERFACE" -c "$COUNT" -w "$CAPTURE_FILE" 2>&1 | tee "$TMP_FILE"
    fi

    log_success "Capture completed"
}

# Analyze protocols
analyze_protocols() {
    log_info "Analyzing protocols..."

    # Extract protocol information
    local protocols=$(tcpdump -r "$CAPTURE_FILE" -n 2>/dev/null | \
        awk '{for(i=1;i<=NF;i++) if($i ~ /TCP|UDP|ICMP|IGMP|ARP|IPV6|ESP|AH|GRE|SCTP/) print $i}' | \
        sort | uniq -c | sort -rn)

    # Total packets
    local total=$(echo "$protocols" | awk '{sum+=$1} END {print sum}')

    echo ""
    echo -e "${BOLD}Protocol Breakdown${NC}"
    echo "────────────────────────────────────────"
    printf "%-15s %-12s %-10s\n" "Protocol" "Packets" "Percentage"
    echo "────────────────────────────────────────"

    echo "$protocols" | while read -r count proto; do
        local percent=$(awk "BEGIN {printf \"%.1f\", ($count / $total) * 100}")
        printf "%-15s %-12s ${GREEN}%-10s${NC}\n" "$proto" "$count" "${percent}%"
    done

    echo "────────────────────────────────────────"
    printf "%-15s %-12s\n" "Total" "$total"
}

# Analyze ports
analyze_ports() {
    log_info "Analyzing port usage..."

    # Extract port information
    local ports=$(tcpdump -r "$CAPTURE_FILE" -n 2>/dev/null | \
        grep -Eo '[0-9]{1,5}\.[0-9]{1,5}\.[0-9]{1,5}\.[0-9]{1,5}\.[0-9]{1,5}' | \
        awk -F'.' '{print $NF}' | \
        sort | uniq -c | sort -rn | head -20)

    echo ""
    echo -e "${BOLD}Top 20 Ports${NC}"
    echo "────────────────────────────────────────"
    printf "%-10s %-15s %-15s\n" "Packets" "Port" "Service"
    echo "────────────────────────────────────────"

    echo "$ports" | while read -r count port; do
        local service=$(getent services "$port" 2>/dev/null | awk '{print $1}' || echo "unknown")
        printf "%-10s %-15s %-15s\n" "$count" "$port" "$service"
    done
}

# Show top talkers
show_top_talkers() {
    log_info "Finding top talkers..."

    # Extract source and destination IPs
    local talkers=$(tcpdump -r "$CAPTURE_FILE" -n 2>/dev/null | \
        awk '{print $3}' | \
        grep -E '^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | \
        sort | uniq -c | sort -rn | head "$TOP_NUM")

    echo ""
    echo -e "${BOLD}Top $TOP_NUM Talkers${NC}"
    echo "────────────────────────────────────────"
    printf "%-10s %-20s %-15s\n" "Packets" "IP Address" "Hostname"
    echo "────────────────────────────────────────"

    echo "$talkers" | while read -r count ip; do
        # Try to resolve hostname
        local hostname=$(host "$ip" 2>/dev/null | grep 'pointer' | awk '{print $5}' | sed 's/\.$//' || echo "-")
        printf "%-10s %-20s %-15s\n" "$count" "$ip" "$hostname"
    done
}

# Analyze packet sizes
analyze_packet_sizes() {
    log_info "Analyzing packet sizes..."

    # Get packet lengths
    local sizes=$(tcpdump -r "$CAPTURE_FILE" -n -v 2>/dev/null | \
        grep 'length' | \
        grep -Eo 'length [0-9]+' | \
        awk '{print $2}' | \
        sort -n | uniq -c)

    echo ""
    echo -e "${BOLD}Packet Size Distribution${NC}"
    echo "────────────────────────────────────────"
    printf "%-15s %-15s %-15s\n" "Size Range" "Count" "Percentage"
    echo "────────────────────────────────────────"

    # Categorize packet sizes
    local tiny=$(echo "$sizes" | awk '$1<64 {sum+=$1} END {print sum}')
    local small=$(echo "$sizes" | awk '$1>=64 && $1<256 {sum+=$1} END {print sum}')
    local medium=$(echo "$sizes" | awk '$1>=256 && $1<1024 {sum+=$1} END {print sum}')
    local large=$(echo "$sizes" | awk '$1>=1024 && $1<1500 {sum+=$1} END {print sum}')
    local jumbo=$(echo "$sizes" | awk '$1>=1500 {sum+=$1} END {print sum}')

    local total=$((tiny + small + medium + large + jumbo))

    printf "%-15s %-15s %-15s\n" "0-63" "${tiny:-0}" "$(awk "BEGIN {printf \"%.1f\", ${tiny:-0} * 100 / $total}")%"
    printf "%-15s %-15s %-15s\n" "64-255" "${small:-0}" "$(awk "BEGIN {printf \"%.1f\", ${small:-0} * 100 / $total}")%"
    printf "%-15s %-15s %-15s\n" "256-1023" "${medium:-0}" "$(awk "BEGIN {printf \"%.1f\", ${medium:-0} * 100 / $total}")%"
    printf "%-15s %-15s %-15s\n" "1024-1499" "${large:-0}" "$(awk "BEGIN {printf \"%.1f\", ${large:-0} * 100 / $total}")%"
    printf "%-15s %-15s %-15s\n" "1500+" "${jumbo:-0}" "$(awk "BEGIN {printf \"%.1f\", ${jumbo:-0} * 100 / $total}")%"
    echo "────────────────────────────────────────"
    printf "%-15s %-15s\n" "Total" "$total"
}

# Analyze TCP flags
analyze_tcp_flags() {
    log_info "Analyzing TCP flags..."

    # Extract TCP flag information
    local flags=$(tcpdump -r "$CAPTURE_FILE" -n 2>/dev/null | \
        grep 'Flags \[' | \
        grep -oE 'Flags \[[^]]+\]' | \
        sort | uniq -c | sort -rn)

    echo ""
    echo -e "${BOLD}TCP Flags Analysis${NC}"
    echo "────────────────────────────────────────"
    printf "%-20s %-15s\n" "Flags" "Count"
    echo "────────────────────────────────────────"

    echo "$flags" | while read -r count flags; do
        printf "%-20s %-15s\n" "$flags" "$count"
    done
}

# Output JSON format
output_json() {
    # Capture and analyze
    capture_traffic

    local protocols=$(tcpdump -r "$CAPTURE_FILE" -n 2>/dev/null | \
        awk '{for(i=1;i<=NF;i++) if($i ~ /TCP|UDP|ICMP|IGMP|ARP|IPV6|ESP|AH|GRE|SCTP/) print $i}' | \
        sort | uniq -c)

    local total_packets=$(tcpdump -r "$CAPTURE_FILE" -n 2>/dev/null | wc -l)

    echo "{"
    echo "  \"interface\": \"$INTERFACE\","
    echo "  \"total_packets\": $total_packets,"
    echo "  \"protocols\": {"

    local first=true
    echo "$protocols" | while read -r count proto; do
        if [ "$first" = "true" ]; then
            first=false
        else
            echo ","
        fi
        local percent=$(awk "BEGIN {printf \"%.2f\", ($count / $total_packets) * 100}")
        printf "    \"%s\": {\"count\": %s, \"percentage\": %s}" "$proto" "$count" "$percent"
    done | sed '$!s/$/,/'

    echo ""
    echo "  }"
    echo "}"
}

# Show summary
show_summary() {
    echo ""
    echo -e "${BOLD}${CYAN}Analysis Summary${NC}"
    echo "────────────────────────────────────────"

    # Get file info
    local file_size=$(du -h "$CAPTURE_FILE" | awk '{print $1}')
    local packet_count=$(tcpdump -r "$CAPTURE_FILE" -n 2>/dev/null | wc -l)
    local duration=$(tcpdump -r "$CAPTURE_FILE" 2>/dev/null | head -1 | grep -oE '[0-9]{2}:[0-9]{2}:[0-9]{2}\.[0-9]+' | head -1)

    echo "Interface:      $INTERFACE"
    echo "Packets:        $packet_count"
    echo "Capture Size:   $file_size"
    echo "Capture Time:   ${duration:-N/A}"
    echo ""
    echo "Capture File:   $CAPTURE_FILE"
    echo ""
    echo -e "Analyze with: ${GREEN}tcpdump -r $CAPTURE_FILE -n${NC}"
    echo -e "              ${GREEN}wireshark $CAPTURE_FILE${NC}"
}

# Main execution
main() {
    # Parse arguments
    while [ $# -gt 0 ]; do
        case $1 in
            -i|--interface)
                INTERFACE="$2"
                shift 2
                ;;
            -c|--count)
                COUNT="$2"
                shift 2
                ;;
            -t|--top)
                TOP_NUM="$2"
                shift 2
                ;;
            -p|--port)
                SHOW_PORTS=true
                shift
                ;;
            -d|--duration)
                DURATION="$2"
                shift 2
                ;;
            -j|--json)
                JSON_OUTPUT=true
                shift
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -h|--help)
                echo "Usage: $0 [options]"
                echo ""
                echo "Network protocol analysis"
                echo ""
                echo "Options:"
                echo "  -i, --interface INTERFACE  Network interface (default: wg0)"
                echo "  -c, --count NUM             Number of packets to analyze (default: 10000)"
                echo "  -t, --top NUM               Show top N talkers (default: 10)"
                echo "  -p, --port                  Show port-based breakdown"
                echo "  -d, --duration SECONDS      Capture duration"
                echo "  -j, --json                  Output in JSON format"
                echo "  -v, --verbose               Verbose output"
                echo "  -h, --help                  Show this help"
                echo ""
                echo "Examples:"
                echo "  $0 -i wg0 -c 5000"
                echo "  $0 -i wg0 -p"
                echo "  $0 -i wg0 -j"
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                exit 1
                ;;
        esac
    done

    # Pre-flight checks
    check_root
    check_tcpdump
    check_interface

    # Run in JSON mode or normal mode
    if [ "$JSON_OUTPUT" = "true" ]; then
        output_json
    else
        # Capture traffic
        capture_traffic

        # Run analyses
        echo ""
        echo -e "${BOLD}${CYAN}═══════════════════════════════════════════════════════════════${NC}"
        echo -e "${BOLD}${CYAN}     Network Protocol Analysis Report${NC}"
        echo -e "${BOLD}${CYAN}═══════════════════════════════════════════════════════════════${NC}"

        analyze_protocols
        show_top_talkers
        analyze_packet_sizes

        if [ "$SHOW_PORTS" = "true" ]; then
            analyze_ports
        fi

        analyze_tcp_flags
        show_summary

        echo ""
        log_success "Analysis complete"
    fi
}

# Run main function
main "$@"
