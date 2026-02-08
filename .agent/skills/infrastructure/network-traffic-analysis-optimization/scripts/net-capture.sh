#!/bin/bash

###############################################################################
# Network Traffic Capture Script
# Captures network traffic with configurable filters and rotation
#
# Usage: net-capture.sh [options]
#   -i, --interface INTERFACE  Network interface (default: wg0)
#   -o, --output FILE           Output file (default: /tmp/capture.pcap)
#   -c, --count NUM             Number of packets to capture
#   -f, --filter FILTER         BPF filter expression
#   -s, --size SIZE             Snapshot length (default: 0 = full)
#   -r, --rotate SIZE           Rotate files at SIZE MB
#   -n, --num-files NUM         Number of rotate files (default: 5)
#   -t, --duration SECONDS      Capture duration
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
BOLD='\033[1m'
NC='\033[0m'

# Default values
INTERFACE="${CAPTURE_INTERFACE:-wg0}"
OUTPUT="/tmp/capture-$(date +%Y%m%d-%H%M%S).pcap"
COUNT=""
FILTER=""
SIZE="0"
ROTATE_SIZE=""
NUM_FILES="5"
DURATION=""
VERBOSE=false

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

# Validate BPF filter
validate_filter() {
    if [ -n "$FILTER" ]; then
        log_verbose "Validating filter: $FILTER"
        if ! tcpdump -i "$INTERFACE" -d "$FILTER" 2>/dev/null; then
            log_error "Invalid BPF filter: $FILTER"
            exit 1
        fi
        log_success "Filter validated"
    fi
}

# Show capture statistics
show_stats() {
    local pcap_file=$1

    if [ ! -f "$pcap_file" ]; then
        log_warning "Capture file not found: $pcap_file"
        return
    fi

    echo ""
    log_info "Capture Statistics:"
    echo "────────────────────────────────────"

    # Get packet count
    local packets=$(tcpdump -r "$pcap_file" 2>/dev/null | wc -l)
    echo "Total Packets: $packets"

    # Get file size
    local size=$(du -h "$pcap_file" | awk '{print $1}')
    echo "File Size: $size"

    # Get duration (if applicable)
    if [ -n "$DURATION" ]; then
        echo "Duration: ${DURATION}s"
    fi

    # Protocol breakdown
    echo ""
    echo "Protocol Breakdown:"
    tcpdump -r "$pcap_file" -n 2>/dev/null | \
        awk '{for(i=1;i<=NF;i++) if($i ~ /TCP|UDP|ICMP|IGMP|ARP/) print $i}' | \
        sort | uniq -c | sort -rn | \
        while read -r count proto; do
            printf "  %-6s: %d\n" "$proto" "$count"
        done

    # Top talkers
    echo ""
    echo "Top Talkers:"
    tcpdump -r "$pcap_file" -n 2>/dev/null | \
        awk '{print $3}' | cut -d'.' -f1-3 | \
        sort | uniq -c | sort -rn | head -5 | \
        while read -r count ip; do
            printf "  %-15s: %d packets\n" "$ip" "$count"
        done

    echo "────────────────────────────────────"
}

# Start packet capture
start_capture() {
    local cmd="tcpdump -i $INTERFACE"

    if [ -n "$COUNT" ]; then
        cmd="$cmd -c $COUNT"
    fi

    if [ -n "$FILTER" ]; then
        cmd="$cmd '$FILTER'"
    fi

    if [ -n "$SIZE" ]; then
        cmd="$cmd -s $SIZE"
    fi

    if [ -n "$ROTATE_SIZE" ]; then
        cmd="$cmd -C $ROTATE_SIZE -W $NUM_FILES"
    fi

    cmd="$cmd -w $OUTPUT"

    log_info "Starting capture on $INTERFACE"
    log_verbose "Command: $cmd"

    # Show active capture info
    echo ""
    echo -e "${BOLD}Capture Configuration:${NC}"
    echo "  Interface:   $INTERFACE"
    echo "  Output:      $OUTPUT"
    echo "  Filter:      ${FILTER:-none}"
    echo "  Packet Count: ${COUNT:-unlimited}"
    echo "  Snap Length: ${SIZE:-full}"
    if [ -n "$ROTATE_SIZE" ]; then
        echo "  Rotate:      ${ROTATE_SIZE}MB, $NUM_FILES files"
    fi
    if [ -n "$DURATION" ]; then
        echo "  Duration:    ${DURATION}s"
    fi
    echo ""

    # Execute capture
    if [ -n "$DURATION" ]; then
        timeout "$DURATION" eval "$cmd"
        local exit_code=$?
        if [ $exit_code -eq 124 ]; then
            log_info "Capture completed after ${DURATION}s"
        fi
    else
        eval "$cmd"
    fi

    log_success "Capture completed"

    # Show statistics
    show_stats "$OUTPUT"

    # Analyze with tshark if available
    if command -v tshark &> /dev/null; then
        echo ""
        log_info "TShark Analysis:"
        tshark -r "$OUTPUT" -q -z io,stat,0 2>/dev/null || true
        tshark -r "$OUTPUT" -q -z conv,tcp 2>/dev/null | head -20 || true
    fi
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
            -o|--output)
                OUTPUT="$2"
                shift 2
                ;;
            -c|--count)
                COUNT="$2"
                shift 2
                ;;
            -f|--filter)
                FILTER="$2"
                shift 2
                ;;
            -s|--size)
                SIZE="$2"
                shift 2
                ;;
            -r|--rotate)
                ROTATE_SIZE="$2"
                shift 2
                ;;
            -n|--num-files)
                NUM_FILES="$2"
                shift 2
                ;;
            -t|--duration)
                DURATION="$2"
                shift 2
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -h|--help)
                echo "Usage: $0 [options]"
                echo ""
                echo "Network traffic capture with tcpdump"
                echo ""
                echo "Options:"
                echo "  -i, --interface INTERFACE  Network interface (default: wg0)"
                echo "  -o, --output FILE           Output file (default: /tmp/capture-TIMESTAMP.pcap)"
                echo "  -c, --count NUM             Number of packets to capture"
                echo "  -f, --filter FILTER         BPF filter expression"
                echo "  -s, --size SIZE             Snapshot length (default: 0 = full)"
                echo "  -r, --rotate SIZE           Rotate files at SIZE MB"
                echo "  -n, --num-files NUM         Number of rotate files (default: 5)"
                echo "  -t, --duration SECONDS      Capture duration"
                echo "  -v, --verbose               Verbose output"
                echo "  -h, --help                  Show this help"
                echo ""
                echo "Common Filters:"
                echo "  host 10.6.0.5              Capture specific host"
                echo "  port 2049                  Capture NFS traffic"
                echo "  tcp                        TCP traffic only"
                echo "  udp and port 51823         WireGuard traffic"
                echo ""
                echo "Examples:"
                echo "  $0 -i wg0 -c 1000"
                echo "  $0 -i wg0 -f 'host 10.6.0.20 and port 2049'"
                echo "  $0 -i wg0 -r 100 -t 60"
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
    validate_filter

    # Create output directory if needed
    local output_dir=$(dirname "$OUTPUT")
    if [ ! -d "$output_dir" ]; then
        mkdir -p "$output_dir"
    fi

    # Start capture
    start_capture

    echo ""
    log_success "Capture saved to: $OUTPUT"
    log_info "Analyze with: wireshark $OUTPUT"
    log_info "Or: tcpdump -r $OUTPUT -n"
}

# Run main function
main "$@"
