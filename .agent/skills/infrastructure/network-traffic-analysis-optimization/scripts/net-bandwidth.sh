#!/bin/bash

###############################################################################
# Network Bandwidth Monitoring Script
# Real-time bandwidth monitoring and statistics collection
#
# Usage: net-bandwidth.sh [options]
#   -i, --interface INTERFACE  Network interface (default: wg0)
#   -r, --rate SECONDS          Update interval (default: 1)
#   -c, --count NUM             Number of samples (default: 0 = infinite)
#   -h, --history               Show historical statistics (vnstat)
#   -t, --top                   Show top talkers
#   -j, --json                  Output in JSON format
#   -v, --verbose               Verbose output
#   -H, --help                  Show this help
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
INTERFACE="${BANDWIDTH_INTERFACE:-wg0}"
RATE=1
COUNT=0
SHOW_HISTORY=false
SHOW_TOP=false
JSON_OUTPUT=false
VERBOSE=false

# Store previous stats
declare -A PREV_RX
declare -A PREV_TX
declare -A PREV_TIME

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

# Format bytes to human readable
format_bytes() {
    local bytes=$1
    local awk_script='
        function format(b) {
            if (b < 1024) return sprintf("%.2f B", b)
            if (b < 1048576) return sprintf("%.2f KB", b/1024)
            if (b < 1073741824) return sprintf("%.2f MB", b/1048576)
            return sprintf("%.2f GB", b/1073741824)
        }
        {print format($1)}'
    echo "$bytes" | awk "$awk_script"
}

# Format bits per second
format_bps() {
    local bps=$1
    local awk_script='
        function format(b) {
            if (b < 1024) return sprintf("%.2f bps", b)
            if (b < 1048576) return sprintf("%.2f Kbps", b/1024)
            if (b < 1073741824) return sprintf("%.2f Mbps", b/1048576)
            return sprintf("%.2f Gbps", b/1073741824)
        }
        {print format($1)}'
    echo "$bps" | awk "$awk_script"
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

# Get interface statistics
get_interface_stats() {
    local iface=$1

    # Get RX and TX bytes
    local stats=$(cat "/sys/class/net/$iface/statistics/rx_bytes" "/sys/class/net/$iface/statistics/tx_bytes")
    local rx_bytes=$(echo "$stats" | sed -n '1p')
    local tx_bytes=$(echo "$stats" | sed -n '2p')

    echo "$rx_bytes $tx_bytes"
}

# Calculate bandwidth
calculate_bandwidth() {
    local iface=$1
    local current_rx=$2
    local current_tx=$3
    local current_time=$4

    # Check if we have previous stats
    if [ -z "${PREV_RX[$iface]}" ]; then
        PREV_RX[$iface]=$current_rx
        PREV_TX[$iface]=$current_tx
        PREV_TIME[$iface]=$current_time
        echo "0 0"
        return
    fi

    local prev_rx=${PREV_RX[$iface]}
    local prev_tx=${PREV_TX[$iface]}
    local prev_time=${PREV_TIME[$iface]}

    # Calculate differences
    local rx_delta=$((current_rx - prev_rx))
    local tx_delta=$((current_tx - prev_tx))
    local time_delta=$((current_time - prev_time))

    # Update previous stats
    PREV_RX[$iface]=$current_rx
    PREV_TX[$iface]=$current_tx
    PREV_TIME[$iface]=$current_time

    # Avoid division by zero
    if [ "$time_delta" -eq 0 ]; then
        echo "0 0"
        return
    fi

    # Calculate bytes per second
    local rx_bps=$((rx_delta * 8 / time_delta))
    local tx_bps=$((tx_delta * 8 / time_delta))

    echo "$rx_bps $tx_bps"
}

# Show real-time bandwidth
show_realtime() {
    local iteration=0

    while true; do
        # Check count limit
        if [ "$COUNT" -gt 0 ] && [ "$iteration" -ge "$COUNT" ]; then
            break
        fi

        # Get current time and stats
        local current_time=$(date +%s)
        local stats=$(get_interface_stats "$INTERFACE")
        local current_rx=$(echo "$stats" | awk '{print $1}')
        local current_tx=$(echo "$stats" | awk '{print $2}')

        # Calculate bandwidth
        local bandwidth=$(calculate_bandwidth "$INTERFACE" "$current_rx" "$current_tx" "$current_time")
        local rx_bps=$(echo "$bandwidth" | awk '{print $1}')
        local tx_bps=$(echo "$bandwidth" | awk '{print $2}')

        # Clear screen for first iteration
        if [ "$iteration" -eq 0 ]; then
            clear
        fi

        # Print header
        echo -e "${BOLD}Network Bandwidth Monitor${NC}"
        echo "Interface: $INTERFACE"
        echo "Update Rate: ${RATE}s"
        echo "────────────────────────────────────────"
        echo ""

        # Print bandwidth
        local rx_formatted=$(format_bps "$rx_bps")
        local tx_formatted=$(format_bps "$tx_bps")
        local total_bps=$((rx_bps + tx_bps))
        local total_formatted=$(format_bps "$total_bps")

        printf "  RX: ${CYAN}%-15s${NC}\n" "$rx_formatted"
        printf "  TX: ${GREEN}%-15s${NC}\n" "$tx_formatted"
        printf "  Total: ${BOLD}%-15s${NC}\n" "$total_formatted"

        echo ""

        # Show progress bar
        local max_bps=1000000000  # 1 Gbps reference
        local rx_percent=$((rx_bps * 100 / max_bps))
        local tx_percent=$((tx_bps * 100 / max_bps))

        printf "  RX:  ["
        local i
        for ((i=0; i<50; i++)); do
            if [ $i -lt $((rx_percent / 2)) ]; then
                printf "="
            else
                printf " "
            fi
        done
        printf "] ${rx_percent}%%\n"

        printf "  TX:  ["
        for ((i=0; i<50; i++)); do
            if [ $i -lt $((tx_percent / 2)) ]; then
                printf "="
            else
                printf " "
            fi
        done
        printf "] ${tx_percent}%%\n"

        # Show total stats
        echo ""
        printf "  Total RX: $(format_bytes $current_rx)\n"
        printf "  Total TX: $(format_bytes $current_tx)\n"
        printf "  Total:    $(format_bytes $((current_rx + current_tx)))\n"

        # Increment iteration
        iteration=$((iteration + 1))

        # Wait for next update
        sleep "$RATE"
    done
}

# Show historical statistics
show_history() {
    if ! command -v vnstat &> /dev/null; then
        log_warning "vnstat not installed. Install with: apt install vnstat"
        return
    fi

    log_info "Historical Statistics (vnstat)"
    echo ""

    # Check if database exists
    if ! vnstat -i "$INTERFACE" &> /dev/null; then
        log_warning "No vnstat database for $INTERFACE"
        log_info "Create database: vnstat -i $INTERFACE --create"
        return
    fi

    echo -e "${BOLD}Daily Statistics:${NC}"
    vnstat -i "$INTERFACE" -d
    echo ""

    echo -e "${BOLD}Monthly Statistics:${NC}"
    vnstat -i "$INTERFACE" -m
    echo ""

    echo -e "${BOLD}Top 10 Days:${NC}"
    vnstat -i "$INTERFACE" -t
}

# Show top talkers
show_top_talkers() {
    log_info "Top Talkers on $INTERFACE"
    echo ""

    # Use tcpdump to capture top talkers
    log_warning "Capturing traffic for 30 seconds..."
    local tmp_file=$(mktemp)

    timeout 30 tcpdump -i "$INTERFACE" -n -t 2>/dev/null | \
        awk '{print $3}' | \
        cut -d'.' -f1-3 | \
        sort | uniq -c | sort -rn | head -10 > "$tmp_file"

    echo -e "${BOLD}Top 10 Talkers (last 30s):${NC}"
    echo "────────────────────────────────────────"
    printf "%-20s %-15s\n" "IP Address" "Packets"
    echo "────────────────────────────────────────"

    while read -r count ip; do
        printf "%-20s %-15s\n" "$ip" "$count"
    done < "$tmp_file"

    rm -f "$tmp_file"
}

# Output JSON format
output_json() {
    local stats=$(get_interface_stats "$INTERFACE")
    local current_rx=$(echo "$stats" | awk '{print $1}')
    local current_tx=$(echo "$stats" | awk '{print $2}')
    local current_time=$(date +%s)

    local bandwidth=$(calculate_bandwidth "$INTERFACE" "$current_rx" "$current_tx" "$current_time")
    local rx_bps=$(echo "$bandwidth" | awk '{print $1}')
    local tx_bps=$(echo "$bandwidth" | awk '{print $2}')

    cat <<EOF
{
  "interface": "$INTERFACE",
  "timestamp": $current_time,
  "rx": {
    "bytes": $current_rx,
    "bytes_per_second": $rx_bps,
    "human_readable": "$(format_bps $rx_bps)"
  },
  "tx": {
    "bytes": $current_tx,
    "bytes_per_second": $tx_bps,
    "human_readable": "$(format_bps $tx_bps)"
  },
  "total": {
    "bytes": $((current_rx + current_tx)),
    "bytes_per_second": $((rx_bps + tx_bps)),
    "human_readable": "$(format_bps $((rx_bps + tx_bps)))"
  }
}
EOF
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
            -r|--rate)
                RATE="$2"
                shift 2
                ;;
            -c|--count)
                COUNT="$2"
                shift 2
                ;;
            -h|--history)
                SHOW_HISTORY=true
                shift
                ;;
            -t|--top)
                SHOW_TOP=true
                shift
                ;;
            -j|--json)
                JSON_OUTPUT=true
                shift
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -H|--help)
                echo "Usage: $0 [options]"
                echo ""
                echo "Network bandwidth monitoring"
                echo ""
                echo "Options:"
                echo "  -i, --interface INTERFACE  Network interface (default: wg0)"
                echo "  -r, --rate SECONDS          Update interval (default: 1)"
                echo "  -c, --count NUM             Number of samples (default: 0 = infinite)"
                echo "  -h, --history               Show historical statistics"
                echo "  -t, --top                   Show top talkers"
                echo "  -j, --json                  Output in JSON format"
                echo "  -v, --verbose               Verbose output"
                echo "  -H, --help                  Show this help"
                echo ""
                echo "Examples:"
                echo "  $0 -i wg0 -r 2 -c 60"
                echo "  $0 -i wg0 -j"
                echo "  $0 -i wg0 -h"
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                exit 1
                ;;
        esac
    done

    # Check interface
    check_interface

    # Run requested mode
    if [ "$JSON_OUTPUT" = "true" ]; then
        output_json
    elif [ "$SHOW_HISTORY" = "true" ]; then
        show_history
    elif [ "$SHOW_TOP" = "true" ]; then
        show_top_talkers
    else
        show_realtime
    fi
}

# Run main function
main "$@"
