#!/bin/bash
# WireGuard Network Performance Test
# Tests: Latency, Throughput, Packet Loss, Connection Stability
# Author: Tester Agent (Hive Mind)
# Date: 2025-11-02

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESULTS_DIR="${RESULTS_DIR:-/tmp/performance-results}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
RESULT_FILE="${RESULTS_DIR}/wireguard-perf_${TIMESTAMP}.json"
DURATION="${DURATION:-30}"
PACKET_COUNT="${PACKET_COUNT:-100}"

# Default WireGuard targets (from INFRA.md)
TARGETS="${TARGETS:-10.6.0.5 10.6.0.10 10.6.0.12 10.6.0.20 10.6.0.21}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

mkdir -p "$RESULTS_DIR"

log_info() { echo -e "${BLUE}[INFO]${NC} $*"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $*"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }

# Check WireGuard status
check_wireguard() {
    log_info "Checking WireGuard status..."

    if ! command -v wg &> /dev/null; then
        log_error "WireGuard (wg) not installed"
        return 1
    fi

    if ! wg show &> /dev/null; then
        log_error "WireGuard not running or no permissions"
        return 1
    fi

    local peer_count=$(wg show all peers | wc -l)
    log_success "WireGuard active with $peer_count peers"
    return 0
}

# Test latency to target
test_latency() {
    local target=$1
    local name=$2

    log_info "Testing latency to $name ($target)..."

    # Run ping test
    local ping_output=$(ping -c "$PACKET_COUNT" -i 0.2 -W 2 "$target" 2>&1 || echo "FAILED")

    if echo "$ping_output" | grep -q "FAILED\|100% packet loss"; then
        log_error "Cannot reach $name ($target)"
        echo "null"
        return 1
    fi

    # Parse ping results
    local packet_loss=$(echo "$ping_output" | grep "packet loss" | awk '{print $6}' | sed 's/%//')
    local rtt_stats=$(echo "$ping_output" | grep "rtt min/avg/max" | awk -F'=' '{print $2}')
    local rtt_min=$(echo "$rtt_stats" | cut -d'/' -f1)
    local rtt_avg=$(echo "$rtt_stats" | cut -d'/' -f2)
    local rtt_max=$(echo "$rtt_stats" | cut -d'/' -f3)
    local rtt_mdev=$(echo "$rtt_stats" | cut -d'/' -f4 | awk '{print $1}')

    # Determine status
    local status="GOOD"
    if (( $(echo "$rtt_avg > 10" | bc -l) )); then
        status="WARNING"
    fi
    if (( $(echo "$rtt_avg > 20" | bc -l) )); then
        status="CRITICAL"
    fi
    if (( $(echo "$packet_loss > 1" | bc -l) )); then
        status="WARNING"
    fi

    cat <<EOF
    {
      "target": "$target",
      "name": "$name",
      "packet_count": $PACKET_COUNT,
      "packet_loss_percent": ${packet_loss:-0},
      "rtt_min_ms": ${rtt_min:-0},
      "rtt_avg_ms": ${rtt_avg:-0},
      "rtt_max_ms": ${rtt_max:-0},
      "rtt_mdev_ms": ${rtt_mdev:-0},
      "status": "$status"
    }
EOF

    log_success "$name: RTT avg=${rtt_avg}ms, loss=${packet_loss}%, status=$status"
}

# Test throughput using iperf3
test_throughput() {
    local target=$1
    local name=$2

    log_info "Testing throughput to $name ($target)..."

    # Check if iperf3 is available
    if ! command -v iperf3 &> /dev/null; then
        log_warning "iperf3 not installed, skipping throughput test"
        echo "null"
        return 1
    fi

    # Try to connect to iperf3 server (port 5201)
    if ! timeout 2 bash -c "echo >/dev/tcp/$target/5201" 2>/dev/null; then
        log_warning "iperf3 server not available at $target:5201"
        echo "null"
        return 1
    fi

    # Run iperf3 test
    local iperf_output=$(iperf3 -c "$target" -t "$DURATION" -J 2>/dev/null || echo "FAILED")

    if [ "$iperf_output" = "FAILED" ]; then
        log_warning "iperf3 test failed to $name"
        echo "null"
        return 1
    fi

    # Parse JSON results
    local sent_bps=$(echo "$iperf_output" | jq '.end.sum_sent.bits_per_second' 2>/dev/null || echo 0)
    local recv_bps=$(echo "$iperf_output" | jq '.end.sum_received.bits_per_second' 2>/dev/null || echo 0)
    local sent_mbps=$(echo "scale=2; $sent_bps / 1000000" | bc)
    local recv_mbps=$(echo "scale=2; $recv_bps / 1000000" | bc)

    # Determine status (expected >500 Mbps for WireGuard)
    local status="GOOD"
    if (( $(echo "$recv_mbps < 300" | bc -l) )); then
        status="WARNING"
    fi
    if (( $(echo "$recv_mbps < 100" | bc -l) )); then
        status="CRITICAL"
    fi

    cat <<EOF
    {
      "target": "$target",
      "name": "$name",
      "duration_sec": $DURATION,
      "sent_mbps": $sent_mbps,
      "received_mbps": $recv_mbps,
      "sent_bps": $sent_bps,
      "received_bps": $recv_bps,
      "status": "$status"
    }
EOF

    log_success "$name: Throughput ${recv_mbps} Mbps, status=$status"
}

# Get WireGuard interface stats
get_wg_stats() {
    log_info "Collecting WireGuard statistics..."

    local wg_iface=$(wg show interfaces | head -1)

    if [ -z "$wg_iface" ]; then
        log_warning "No WireGuard interface found"
        echo '  "wireguard_stats": null'
        return
    fi

    # Get interface details
    local listen_port=$(wg show "$wg_iface" listen-port 2>/dev/null || echo 0)
    local peer_count=$(wg show "$wg_iface" peers | wc -l)

    # Get transfer stats
    local rx_bytes=$(cat /sys/class/net/"$wg_iface"/statistics/rx_bytes 2>/dev/null || echo 0)
    local tx_bytes=$(cat /sys/class/net/"$wg_iface"/statistics/tx_bytes 2>/dev/null || echo 0)
    local rx_mb=$(echo "scale=2; $rx_bytes / 1048576" | bc)
    local tx_mb=$(echo "scale=2; $tx_bytes / 1048576" | bc)

    cat <<EOF
  "wireguard_stats": {
    "interface": "$wg_iface",
    "listen_port": $listen_port,
    "peer_count": $peer_count,
    "rx_bytes": $rx_bytes,
    "tx_bytes": $tx_bytes,
    "rx_mb": $rx_mb,
    "tx_mb": $tx_mb
  }
EOF

    log_success "WireGuard: $peer_count peers, RX=${rx_mb}MB, TX=${tx_mb}MB"
}

# Main test execution
main() {
    log_info "=== WireGuard Network Performance Test ==="
    log_info "Packet count: $PACKET_COUNT"
    log_info "Duration: ${DURATION}s"
    log_info "Targets: $TARGETS"
    log_info "Results: $RESULT_FILE"
    echo

    # Check WireGuard
    if ! check_wireguard; then
        log_error "WireGuard checks failed"
        exit 1
    fi

    # Map targets to names (from INFRA.md)
    declare -A target_names=(
        ["10.6.0.5"]="FGSRV6-Hub"
        ["10.6.0.10"]="AGLSRV1"
        ["10.6.0.12"]="AGLSRV6"
        ["10.6.0.20"]="CT111-NFS"
        ["10.6.0.21"]="CT183-Archon"
        ["10.6.0.22"]="CT179-Dev"
    )

    # Build JSON results
    {
        echo "{"
        echo '  "test_type": "wireguard_performance",'
        echo "  \"timestamp\": \"$(date -Iseconds)\","
        echo "  \"duration_sec\": $DURATION,"
        echo "  \"packet_count\": $PACKET_COUNT,"

        # WireGuard stats
        get_wg_stats
        echo ","

        # Latency tests
        echo '  "latency_tests": ['
        local first=1
        for target in $TARGETS; do
            [ $first -eq 0 ] && echo ","
            first=0
            test_latency "$target" "${target_names[$target]:-Unknown}" || true
        done
        echo '  ],'

        # Throughput tests (if iperf3 available)
        echo '  "throughput_tests": ['
        first=1
        for target in $TARGETS; do
            [ $first -eq 0 ] && echo ","
            first=0
            test_throughput "$target" "${target_names[$target]:-Unknown}" || echo "    null"
        done
        echo '  ]'

        echo "}"
    } > "$RESULT_FILE"

    # Display summary
    echo
    log_info "=== Test Results Summary ==="

    if command -v jq &> /dev/null; then
        # Average latency
        local avg_latency=$(jq '[.latency_tests[] | select(.rtt_avg_ms != null) | .rtt_avg_ms] | add / length' "$RESULT_FILE" 2>/dev/null || echo 0)
        local avg_loss=$(jq '[.latency_tests[] | select(.packet_loss_percent != null) | .packet_loss_percent] | add / length' "$RESULT_FILE" 2>/dev/null || echo 0)

        echo "Average Latency: ${avg_latency} ms"
        echo "Average Packet Loss: ${avg_loss}%"

        # Count statuses
        local good=$(jq '[.latency_tests[] | select(.status == "GOOD")] | length' "$RESULT_FILE")
        local warning=$(jq '[.latency_tests[] | select(.status == "WARNING")] | length' "$RESULT_FILE")
        local critical=$(jq '[.latency_tests[] | select(.status == "CRITICAL")] | length' "$RESULT_FILE")

        echo -e "Status: ${GREEN}$good GOOD${NC}, ${YELLOW}$warning WARNING${NC}, ${RED}$critical CRITICAL${NC}"
    fi

    echo
    log_success "Results saved to: $RESULT_FILE"

    # Pretty print if requested
    if [ "${VERBOSE:-0}" -eq 1 ] && command -v jq &> /dev/null; then
        echo
        log_info "Detailed Results:"
        jq '.' "$RESULT_FILE"
    fi
}

# Run main
main "$@"
