#!/bin/bash
# Performance Test Suite Runner
# Executes all performance tests and generates comprehensive reports
# Author: Tester Agent (Hive Mind)
# Date: 2025-11-02

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESULTS_DIR="${RESULTS_DIR:-/tmp/performance-results}"
REPORT_DIR="${REPORT_DIR:-/mnt/overpower/apps/dev/agl/agl-hostman/docs/test-reports/performance}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
REPORT_FILE="${REPORT_DIR}/performance-suite-report_${TIMESTAMP}.md"

# Test categories
CATEGORIES="${CATEGORIES:-baseline network storage services}"
RUN_ALL="${RUN_ALL:-1}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# Create directories
mkdir -p "$RESULTS_DIR" "$REPORT_DIR"

# Logging functions
log_info() { echo -e "${BLUE}[INFO]${NC} $*"; }
log_success() { echo -e "${GREEN}[✓]${NC} $*"; }
log_warning() { echo -e "${YELLOW}[!]${NC} $*"; }
log_error() { echo -e "${RED}[✗]${NC} $*"; }
log_section() { echo -e "\n${CYAN}${BOLD}=== $* ===${NC}\n"; }

# Test results tracking
declare -a PASSED_TESTS=()
declare -a FAILED_TESTS=()
declare -a SKIPPED_TESTS=()

# Run a test script
run_test() {
    local test_name=$1
    local test_script=$2

    if [ ! -f "$test_script" ]; then
        log_warning "Test script not found: $test_script"
        SKIPPED_TESTS+=("$test_name")
        return 1
    fi

    if [ ! -x "$test_script" ]; then
        chmod +x "$test_script"
    fi

    log_info "Running: $test_name"

    if RESULTS_DIR="$RESULTS_DIR" "$test_script" 2>&1 | tee "${RESULTS_DIR}/${test_name}_output.log"; then
        PASSED_TESTS+=("$test_name")
        log_success "$test_name completed"
        return 0
    else
        FAILED_TESTS+=("$test_name")
        log_error "$test_name failed"
        return 1
    fi
}

# Run baseline tests
run_baseline_tests() {
    log_section "Baseline Performance Tests"

    run_test "system-baseline" "${SCRIPT_DIR}/baseline/system-baseline.sh" || true
}

# Run network tests
run_network_tests() {
    log_section "Network Performance Tests"

    run_test "wireguard-perf" "${SCRIPT_DIR}/network/wireguard-perf.sh" || true
}

# Run storage tests
run_storage_tests() {
    log_section "Storage Performance Tests"

    run_test "nfs-benchmark" "${SCRIPT_DIR}/storage/nfs-benchmark.sh" || true
}

# Run service tests
run_service_tests() {
    log_section "Service Performance Tests"

    run_test "archon-perf" "${SCRIPT_DIR}/services/archon-perf.sh" || true
}

# Generate comprehensive report
generate_report() {
    log_section "Generating Performance Report"

    cat > "$REPORT_FILE" <<'EOF'
# Performance Testing Suite Report

> **Generated**: $(date -Iseconds)
> **Test Run**: $(basename "$RESULTS_DIR")

---

## Executive Summary

This report provides comprehensive performance testing results for the AGL infrastructure, including baseline metrics, network performance, storage I/O, and service-level benchmarks.

### Test Execution Summary

EOF

    # Add test counts
    cat >> "$REPORT_FILE" <<EOF
- **Total Tests**: $((${#PASSED_TESTS[@]} + ${#FAILED_TESTS[@]} + ${#SKIPPED_TESTS[@]}))
- **Passed**: ${#PASSED_TESTS[@]} ✓
- **Failed**: ${#FAILED_TESTS[@]} ✗
- **Skipped**: ${#SKIPPED_TESTS[@]} ⊘

EOF

    # List test results
    if [ ${#PASSED_TESTS[@]} -gt 0 ]; then
        cat >> "$REPORT_FILE" <<EOF
### Passed Tests
EOF
        for test in "${PASSED_TESTS[@]}"; do
            echo "- ✓ $test" >> "$REPORT_FILE"
        done
        echo >> "$REPORT_FILE"
    fi

    if [ ${#FAILED_TESTS[@]} -gt 0 ]; then
        cat >> "$REPORT_FILE" <<EOF
### Failed Tests
EOF
        for test in "${FAILED_TESTS[@]}"; do
            echo "- ✗ $test" >> "$REPORT_FILE"
        done
        echo >> "$REPORT_FILE"
    fi

    if [ ${#SKIPPED_TESTS[@]} -gt 0 ]; then
        cat >> "$REPORT_FILE" <<EOF
### Skipped Tests
EOF
        for test in "${SKIPPED_TESTS[@]}"; do
            echo "- ⊘ $test" >> "$REPORT_FILE"
        done
        echo >> "$REPORT_FILE"
    fi

    # Add detailed results from JSON files
    cat >> "$REPORT_FILE" <<'EOF'

---

## Detailed Test Results

EOF

    # Process JSON results if jq is available
    if command -v jq &> /dev/null; then
        for json_file in "$RESULTS_DIR"/*.json; do
            [ -f "$json_file" ] || continue

            local test_name=$(basename "$json_file" .json)

            cat >> "$REPORT_FILE" <<EOF

### $(echo "$test_name" | sed 's/_/ /g' | sed 's/\b\(.\)/\u\1/g')

\`\`\`json
$(jq '.' "$json_file" 2>/dev/null || echo "{}")
\`\`\`

EOF
        done
    fi

    # Add recommendations
    cat >> "$REPORT_FILE" <<'EOF'

---

## Performance Analysis & Recommendations

### Network Performance
EOF

    # Analyze network results
    if [ -f "$RESULTS_DIR"/wireguard-perf_*.json ]; then
        local latest_wg=$(ls -t "$RESULTS_DIR"/wireguard-perf_*.json | head -1)
        if command -v jq &> /dev/null; then
            local avg_latency=$(jq -r '[.latency_tests[] | select(.rtt_avg_ms != null) | .rtt_avg_ms] | add / length' "$latest_wg" 2>/dev/null || echo "N/A")
            cat >> "$REPORT_FILE" <<EOF

**WireGuard Mesh Performance**:
- Average Latency: ${avg_latency} ms
- Status: $([ $(echo "$avg_latency < 10" | bc -l 2>/dev/null || echo 0) -eq 1 ] && echo "✓ GOOD" || echo "⚠ NEEDS ATTENTION")

EOF
        fi
    fi

    cat >> "$REPORT_FILE" <<'EOF'
**Recommendations**:
1. Monitor network latency trends over time
2. Investigate any peers with >10ms latency
3. Check WireGuard configuration for optimal MTU settings
4. Consider load balancing for high-traffic routes

### Storage Performance
EOF

    # Analyze storage results
    if [ -f "$RESULTS_DIR"/nfs-benchmark_*.json ]; then
        cat >> "$REPORT_FILE" <<'EOF'

**NFS Performance**:
- See detailed results above for IOPS and throughput metrics
- Status: Based on individual mount point benchmarks

**Recommendations**:
1. Optimize NFS mount options (rsize, wsize, async)
2. Consider increasing NFS server threads
3. Monitor for network saturation during peak usage
4. Evaluate local caching strategies for frequently accessed data

### Service Performance
EOF
    fi

    # Analyze service results
    if [ -f "$RESULTS_DIR"/archon-perf_*.json ]; then
        local latest_archon=$(ls -t "$RESULTS_DIR"/archon-perf_*.json | head -1)
        if command -v jq &> /dev/null; then
            local avg_p95=$(jq -r '[.response_time_tests[].response_time_ms.p95] | add / length' "$latest_archon" 2>/dev/null || echo "N/A")
            cat >> "$REPORT_FILE" <<EOF

**Archon MCP Performance**:
- Average p95 Response Time: ${avg_p95} ms
- Status: $([ $(echo "$avg_p95 < 200" | bc -l 2>/dev/null || echo 0) -eq 1 ] && echo "✓ GOOD" || echo "⚠ NEEDS ATTENTION")

EOF
        fi
    fi

    cat >> "$REPORT_FILE" <<'EOF'
**Recommendations**:
1. Implement response time monitoring and alerting
2. Optimize database queries for frequently used MCP tools
3. Consider implementing caching for read-heavy operations
4. Review and optimize container resource allocation

---

## Next Steps

1. **Trending Analysis**: Run tests regularly to establish performance trends
2. **Optimization**: Address any performance warnings or critical issues
3. **Monitoring**: Set up continuous performance monitoring
4. **Documentation**: Update baseline expectations based on results

---

## Test Environment

- **Hostname**: $(hostname)
- **Test Date**: $(date -Iseconds)
- **Kernel**: $(uname -r)
- **Architecture**: $(uname -m)

---

**Report Generated By**: Performance Test Suite
**Framework Version**: 1.0.0
**Maintained By**: Tester Agent (Hive Mind)
EOF

    log_success "Report generated: $REPORT_FILE"
}

# Main execution
main() {
    log_section "Performance Test Suite"
    log_info "Results directory: $RESULTS_DIR"
    log_info "Report directory: $REPORT_DIR"
    log_info "Categories: $CATEGORIES"
    echo

    # Check for required tools
    local missing_tools=()
    command -v bc &> /dev/null || missing_tools+=("bc")
    command -v jq &> /dev/null || log_warning "jq not found - reports will be limited"

    if [ ${#missing_tools[@]} -gt 0 ]; then
        log_error "Missing required tools: ${missing_tools[*]}"
        log_info "Install with: apt-get install -y ${missing_tools[*]}"
        exit 1
    fi

    # Run test categories
    for category in $CATEGORIES; do
        case "$category" in
            baseline)
                run_baseline_tests
                ;;
            network)
                run_network_tests
                ;;
            storage)
                run_storage_tests
                ;;
            services)
                run_service_tests
                ;;
            *)
                log_warning "Unknown category: $category"
                ;;
        esac
    done

    # Generate report
    generate_report

    # Display summary
    log_section "Test Suite Complete"
    echo
    log_info "Results saved to: $RESULTS_DIR"
    log_info "Report saved to: $REPORT_FILE"
    echo
    log_info "Summary:"
    echo -e "  ${GREEN}Passed:  ${#PASSED_TESTS[@]}${NC}"
    echo -e "  ${RED}Failed:  ${#FAILED_TESTS[@]}${NC}"
    echo -e "  ${YELLOW}Skipped: ${#SKIPPED_TESTS[@]}${NC}"
    echo

    # Exit code based on failures
    if [ ${#FAILED_TESTS[@]} -gt 0 ]; then
        log_warning "Some tests failed - review results"
        exit 1
    else
        log_success "All tests passed!"
        exit 0
    fi
}

# Handle command line arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --category)
            CATEGORIES="$2"
            shift 2
            ;;
        --results-dir)
            RESULTS_DIR="$2"
            shift 2
            ;;
        --report-dir)
            REPORT_DIR="$2"
            shift 2
            ;;
        --help)
            cat <<EOF
Usage: $0 [OPTIONS]

Options:
  --category CATS    Run specific categories (baseline, network, storage, services)
  --results-dir DIR  Directory for test results (default: /tmp/performance-results)
  --report-dir DIR   Directory for reports (default: docs/test-reports/performance)
  --help             Show this help message

Examples:
  $0                                    # Run all tests
  $0 --category network                 # Run only network tests
  $0 --category "baseline network"      # Run baseline and network tests
  $0 --results-dir /tmp/my-results      # Custom results directory

EOF
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Run main
main
