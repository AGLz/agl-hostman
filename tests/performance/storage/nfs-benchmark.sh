#!/bin/bash
# NFS Storage Performance Benchmark
# Tests: Sequential/Random Read/Write, IOPS, Latency, Throughput
# Author: Tester Agent (Hive Mind)
# Date: 2025-11-02

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESULTS_DIR="${RESULTS_DIR:-/tmp/performance-results}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
RESULT_FILE="${RESULTS_DIR}/nfs-benchmark_${TIMESTAMP}.json"

# Test parameters
TEST_SIZE="${TEST_SIZE:-1G}"
TEST_DURATION="${TEST_DURATION:-30}"
BLOCK_SIZE="${BLOCK_SIZE:-4k}"
IO_DEPTH="${IO_DEPTH:-16}"

# NFS mount points (from INFRA.md)
NFS_MOUNTS="${NFS_MOUNTS:-/mnt/pve/fgsrv6-wg /mnt/pve/aglsrv6-wg}"

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

# Check dependencies
check_dependencies() {
    local missing=()

    if ! command -v dd &> /dev/null; then
        missing+=("coreutils")
    fi

    # fio is optional but recommended
    if ! command -v fio &> /dev/null; then
        log_warning "fio not installed - only basic dd tests will run"
        log_info "Install with: apt-get install -y fio"
    fi

    if [ ${#missing[@]} -gt 0 ]; then
        log_error "Missing dependencies: ${missing[*]}"
        return 1
    fi

    return 0
}

# Check NFS mount
check_nfs_mount() {
    local mount_point=$1

    if ! mountpoint -q "$mount_point" 2>/dev/null; then
        log_error "Not a mount point: $mount_point"
        return 1
    fi

    if ! df -t nfs,nfs4 "$mount_point" &> /dev/null; then
        log_warning "$mount_point is not an NFS mount"
        return 1
    fi

    local nfs_server=$(df -t nfs,nfs4 "$mount_point" | tail -1 | awk '{print $1}')
    log_success "NFS mount verified: $mount_point ($nfs_server)"
    return 0
}

# Basic dd test (no fio required)
test_dd_performance() {
    local mount_point=$1
    local test_file="$mount_point/.perf_test_$$"

    log_info "Running dd performance test on $mount_point..."

    # Ensure we have write permission and space
    if ! touch "$test_file" 2>/dev/null; then
        log_error "Cannot write to $mount_point"
        echo "null"
        return 1
    fi

    # Sequential write test
    local write_output=$(dd if=/dev/zero of="$test_file" bs=1M count=1024 oflag=direct 2>&1 | tail -1)
    local write_speed=$(echo "$write_output" | awk '{print $(NF-1), $NF}')
    local write_mbps=$(echo "$write_output" | grep -oP '\d+\.?\d* MB/s' | grep -oP '\d+\.?\d*' || echo 0)

    # Sequential read test
    sync && echo 3 > /proc/sys/vm/drop_caches 2>/dev/null || true
    local read_output=$(dd if="$test_file" of=/dev/null bs=1M iflag=direct 2>&1 | tail -1)
    local read_speed=$(echo "$read_output" | awk '{print $(NF-1), $NF}')
    local read_mbps=$(echo "$read_output" | grep -oP '\d+\.?\d* MB/s' | grep -oP '\d+\.?\d*' || echo 0)

    # Cleanup
    rm -f "$test_file"

    cat <<EOF
    {
      "mount_point": "$mount_point",
      "test_type": "dd_sequential",
      "block_size": "1M",
      "test_size": "1GB",
      "write_speed": "$write_speed",
      "read_speed": "$read_speed",
      "write_mbps": ${write_mbps:-0},
      "read_mbps": ${read_mbps:-0},
      "status": "$([ $(echo "${write_mbps:-0} > 50" | bc -l) -eq 1 ] && echo "GOOD" || echo "SLOW")"
    }
EOF

    log_success "$mount_point: Write=${write_mbps}MB/s, Read=${read_mbps}MB/s"
}

# Advanced fio test (if available)
test_fio_performance() {
    local mount_point=$1
    local test_dir="$mount_point/.perf_test_fio_$$"

    if ! command -v fio &> /dev/null; then
        echo "null"
        return 1
    fi

    log_info "Running fio performance test on $mount_point..."

    mkdir -p "$test_dir"

    # Run comprehensive fio test
    local fio_output=$(fio \
        --name=seqwrite \
        --rw=write \
        --bs="$BLOCK_SIZE" \
        --size="$TEST_SIZE" \
        --numjobs=4 \
        --iodepth="$IO_DEPTH" \
        --direct=1 \
        --runtime="$TEST_DURATION" \
        --time_based \
        --directory="$test_dir" \
        --group_reporting \
        --output-format=json 2>/dev/null || echo "FAILED")

    if [ "$fio_output" = "FAILED" ]; then
        log_error "fio test failed on $mount_point"
        rm -rf "$test_dir"
        echo "null"
        return 1
    fi

    # Parse fio JSON output
    local write_iops=$(echo "$fio_output" | jq '.jobs[0].write.iops' 2>/dev/null || echo 0)
    local write_bw=$(echo "$fio_output" | jq '.jobs[0].write.bw' 2>/dev/null || echo 0)
    local write_lat=$(echo "$fio_output" | jq '.jobs[0].write.lat_ns.mean' 2>/dev/null || echo 0)
    local write_lat_ms=$(echo "scale=3; $write_lat / 1000000" | bc)

    # Random read test
    fio_output=$(fio \
        --name=randread \
        --rw=randread \
        --bs="$BLOCK_SIZE" \
        --size="$TEST_SIZE" \
        --numjobs=4 \
        --iodepth="$IO_DEPTH" \
        --direct=1 \
        --runtime="$TEST_DURATION" \
        --time_based \
        --directory="$test_dir" \
        --group_reporting \
        --output-format=json 2>/dev/null || echo "FAILED")

    local read_iops=0
    local read_bw=0
    local read_lat_ms=0

    if [ "$fio_output" != "FAILED" ]; then
        read_iops=$(echo "$fio_output" | jq '.jobs[0].read.iops' 2>/dev/null || echo 0)
        read_bw=$(echo "$fio_output" | jq '.jobs[0].read.bw' 2>/dev/null || echo 0)
        local read_lat=$(echo "$fio_output" | jq '.jobs[0].read.lat_ns.mean' 2>/dev/null || echo 0)
        read_lat_ms=$(echo "scale=3; $read_lat / 1000000" | bc)
    fi

    # Cleanup
    rm -rf "$test_dir"

    # Convert KB/s to MB/s
    local write_mbps=$(echo "scale=2; $write_bw / 1024" | bc)
    local read_mbps=$(echo "scale=2; $read_bw / 1024" | bc)

    # Determine status
    local status="GOOD"
    if (( $(echo "$write_iops < 3000" | bc -l) )); then
        status="WARNING"
    fi
    if (( $(echo "$write_iops < 1000" | bc -l) )); then
        status="CRITICAL"
    fi

    cat <<EOF
    {
      "mount_point": "$mount_point",
      "test_type": "fio_comprehensive",
      "block_size": "$BLOCK_SIZE",
      "io_depth": $IO_DEPTH,
      "duration_sec": $TEST_DURATION,
      "write_iops": ${write_iops:-0},
      "read_iops": ${read_iops:-0},
      "write_bw_kbps": ${write_bw:-0},
      "read_bw_kbps": ${read_bw:-0},
      "write_mbps": ${write_mbps:-0},
      "read_mbps": ${read_mbps:-0},
      "write_lat_ms": ${write_lat_ms:-0},
      "read_lat_ms": ${read_lat_ms:-0},
      "status": "$status"
    }
EOF

    log_success "$mount_point: Write=${write_iops} IOPS (${write_mbps}MB/s), Read=${read_iops} IOPS (${read_mbps}MB/s)"
}

# Get NFS mount statistics
get_nfs_stats() {
    local mount_point=$1

    local nfs_server=$(df -t nfs,nfs4 "$mount_point" | tail -1 | awk '{print $1}')
    local mount_opts=$(mount | grep "$mount_point" | sed 's/.*(\(.*\))/\1/')
    local total_size=$(df -h "$mount_point" | tail -1 | awk '{print $2}')
    local used_size=$(df -h "$mount_point" | tail -1 | awk '{print $3}')
    local avail_size=$(df -h "$mount_point" | tail -1 | awk '{print $4}')
    local usage_pct=$(df "$mount_point" | tail -1 | awk '{print $5}' | sed 's/%//')

    cat <<EOF
    {
      "mount_point": "$mount_point",
      "nfs_server": "$nfs_server",
      "mount_options": "$mount_opts",
      "total_size": "$total_size",
      "used_size": "$used_size",
      "available_size": "$avail_size",
      "usage_percent": $usage_pct
    }
EOF
}

# Main test execution
main() {
    log_info "=== NFS Storage Performance Benchmark ==="
    log_info "Test size: $TEST_SIZE"
    log_info "Duration: ${TEST_DURATION}s"
    log_info "Block size: $BLOCK_SIZE"
    log_info "I/O depth: $IO_DEPTH"
    log_info "Results: $RESULT_FILE"
    echo

    # Check dependencies
    if ! check_dependencies; then
        exit 1
    fi

    # Build JSON results
    {
        echo "{"
        echo '  "test_type": "nfs_benchmark",'
        echo "  \"timestamp\": \"$(date -Iseconds)\","
        echo "  \"test_size\": \"$TEST_SIZE\","
        echo "  \"test_duration_sec\": $TEST_DURATION,"
        echo "  \"block_size\": \"$BLOCK_SIZE\","
        echo "  \"io_depth\": $IO_DEPTH,"

        echo '  "mount_stats": ['
        local first=1
        for mount in $NFS_MOUNTS; do
            if check_nfs_mount "$mount"; then
                [ $first -eq 0 ] && echo ","
                first=0
                get_nfs_stats "$mount"
            fi
        done
        echo '  ],'

        echo '  "dd_tests": ['
        first=1
        for mount in $NFS_MOUNTS; do
            if check_nfs_mount "$mount" 2>/dev/null; then
                [ $first -eq 0 ] && echo ","
                first=0
                test_dd_performance "$mount" || echo "    null"
            fi
        done
        echo '  ],'

        echo '  "fio_tests": ['
        first=1
        for mount in $NFS_MOUNTS; do
            if check_nfs_mount "$mount" 2>/dev/null; then
                [ $first -eq 0 ] && echo ","
                first=0
                test_fio_performance "$mount" || echo "    null"
            fi
        done
        echo '  ]'

        echo "}"
    } > "$RESULT_FILE"

    # Display summary
    echo
    log_info "=== Test Results Summary ==="

    if command -v jq &> /dev/null; then
        # Count tests
        local dd_count=$(jq '[.dd_tests[] | select(. != null)] | length' "$RESULT_FILE")
        local fio_count=$(jq '[.fio_tests[] | select(. != null)] | length' "$RESULT_FILE")

        echo "DD tests completed: $dd_count"
        echo "FIO tests completed: $fio_count"

        # Average performance
        if [ "$dd_count" -gt 0 ]; then
            local avg_write=$(jq '[.dd_tests[] | select(.write_mbps != null) | .write_mbps] | add / length' "$RESULT_FILE" 2>/dev/null || echo 0)
            local avg_read=$(jq '[.dd_tests[] | select(.read_mbps != null) | .read_mbps] | add / length' "$RESULT_FILE" 2>/dev/null || echo 0)
            echo "Average DD Write: ${avg_write} MB/s"
            echo "Average DD Read: ${avg_read} MB/s"
        fi

        if [ "$fio_count" -gt 0 ]; then
            local avg_write_iops=$(jq '[.fio_tests[] | select(.write_iops != null) | .write_iops] | add / length' "$RESULT_FILE" 2>/dev/null || echo 0)
            local avg_read_iops=$(jq '[.fio_tests[] | select(.read_iops != null) | .read_iops] | add / length' "$RESULT_FILE" 2>/dev/null || echo 0)
            echo "Average FIO Write: ${avg_write_iops} IOPS"
            echo "Average FIO Read: ${avg_read_iops} IOPS"
        fi
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
