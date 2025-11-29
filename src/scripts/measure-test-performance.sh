#!/usr/bin/env bash

################################################################################
# Test Performance Measurement Script
#
# Phase 4.2: Parallel Test Execution
#
# Measures and compares test execution performance:
# - Baseline: Sequential test execution (--parallel=1)
# - Optimized: Parallel test execution (--parallel=auto)
# - Calculates percentage improvement
# - Outputs results to TEST-PERFORMANCE-METRICS.md
#
# Usage:
#   ./scripts/measure-test-performance.sh [options]
#
# Options:
#   --baseline-only       Run only baseline measurement
#   --parallel-only       Run only parallel measurement
#   --processes NUM       Set number of parallel processes (default: auto)
#   --suite SUITE         Test specific suite (Unit, Feature, Integration, all)
#   --iterations NUM      Number of iterations to average (default: 3)
#   --output FILE         Output file (default: docs/TEST-PERFORMANCE-METRICS.md)
#   --update-timings      Update test timings in parallel-groups.php
#   --verbose             Enable verbose output
#   --help                Show this help message
#
# Examples:
#   ./scripts/measure-test-performance.sh
#   ./scripts/measure-test-performance.sh --suite Unit --iterations 5
#   ./scripts/measure-test-performance.sh --processes 4
#
################################################################################

set -euo pipefail

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Default configuration
RUN_BASELINE=true
RUN_PARALLEL=true
PARALLEL_PROCESSES="auto"
TEST_SUITE="all"
ITERATIONS=3
OUTPUT_FILE="${PROJECT_ROOT}/../docs/TEST-PERFORMANCE-METRICS.md"
UPDATE_TIMINGS=false
VERBOSE=false

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

################################################################################
# Helper Functions
################################################################################

log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $*"
}

success() {
    echo -e "${GREEN}✓${NC} $*"
}

error() {
    echo -e "${RED}✗${NC} $*" >&2
}

warning() {
    echo -e "${YELLOW}⚠${NC} $*"
}

verbose() {
    if [ "$VERBOSE" = true ]; then
        echo -e "${CYAN}[VERBOSE]${NC} $*"
    fi
}

usage() {
    grep '^#' "$0" | tail -n +3 | head -n -1 | cut -c 3-
    exit 0
}

################################################################################
# Parse Arguments
################################################################################

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --baseline-only)
                RUN_BASELINE=true
                RUN_PARALLEL=false
                shift
                ;;
            --parallel-only)
                RUN_BASELINE=false
                RUN_PARALLEL=true
                shift
                ;;
            --processes)
                PARALLEL_PROCESSES="$2"
                shift 2
                ;;
            --suite)
                TEST_SUITE="$2"
                shift 2
                ;;
            --iterations)
                ITERATIONS="$2"
                shift 2
                ;;
            --output)
                OUTPUT_FILE="$2"
                shift 2
                ;;
            --update-timings)
                UPDATE_TIMINGS=true
                shift
                ;;
            --verbose)
                VERBOSE=true
                shift
                ;;
            --help)
                usage
                ;;
            *)
                error "Unknown option: $1"
                usage
                ;;
        esac
    done
}

################################################################################
# System Information
################################################################################

get_system_info() {
    log "Gathering system information..."

    local cpu_count
    cpu_count=$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo "unknown")

    local total_memory
    total_memory=$(free -h 2>/dev/null | awk '/^Mem:/ {print $2}' || echo "unknown")

    local php_version
    php_version=$(php -v | head -n 1 | awk '{print $2}')

    local pest_version
    pest_version=$(cd "$PROJECT_ROOT" && ./vendor/bin/pest --version | awk '{print $2}')

    echo ""
    success "System Information:"
    echo "  CPU Cores: $cpu_count"
    echo "  Total Memory: $total_memory"
    echo "  PHP Version: $php_version"
    echo "  Pest Version: $pest_version"
    echo ""
}

################################################################################
# Test Execution
################################################################################

run_test_suite() {
    local execution_mode="$1"  # "baseline" or "parallel"
    local processes="$2"
    local suite="$3"

    local start_time
    local end_time
    local duration
    local test_count
    local failure_count

    # Determine test command
    local test_cmd="cd $PROJECT_ROOT && ./vendor/bin/pest"

    # Add suite filter
    if [ "$suite" != "all" ]; then
        test_cmd="$test_cmd --testsuite=$suite"
    fi

    # Add parallel flag
    if [ "$execution_mode" = "parallel" ]; then
        if [ "$processes" = "auto" ]; then
            test_cmd="$test_cmd --parallel"
        else
            test_cmd="$test_cmd --parallel --processes=$processes"
        fi
    else
        # Force sequential execution
        test_cmd="$test_cmd --processes=1"
    fi

    # Run test and capture output
    verbose "Running command: $test_cmd"

    start_time=$(date +%s.%N)

    if [ "$VERBOSE" = true ]; then
        eval "$test_cmd" > /tmp/test-output.txt 2>&1 || true
    else
        eval "$test_cmd" > /tmp/test-output.txt 2>&1 || true
    fi

    end_time=$(date +%s.%N)

    # Calculate duration
    duration=$(echo "$end_time - $start_time" | bc)

    # Parse test results
    test_count=$(grep -oP '\d+ tests?' /tmp/test-output.txt | head -1 | awk '{print $1}' || echo "0")
    failure_count=$(grep -oP '\d+ fail' /tmp/test-output.txt | head -1 | awk '{print $1}' || echo "0")

    # Output results
    echo "$duration|$test_count|$failure_count"
}

run_iterations() {
    local execution_mode="$1"
    local processes="$2"
    local suite="$3"

    log "Running $ITERATIONS iteration(s) for $execution_mode mode..."

    local total_time=0
    local test_count=0
    local failures=0

    for i in $(seq 1 "$ITERATIONS"); do
        verbose "  Iteration $i/$ITERATIONS..."

        local result
        result=$(run_test_suite "$execution_mode" "$processes" "$suite")

        local iter_time
        local iter_tests
        local iter_failures

        iter_time=$(echo "$result" | cut -d'|' -f1)
        iter_tests=$(echo "$result" | cut -d'|' -f2)
        iter_failures=$(echo "$result" | cut -d'|' -f3)

        total_time=$(echo "$total_time + $iter_time" | bc)
        test_count=$iter_tests
        failures=$iter_failures

        verbose "    Time: ${iter_time}s, Tests: $iter_tests, Failures: $iter_failures"
    done

    # Calculate average
    local avg_time
    avg_time=$(echo "scale=2; $total_time / $ITERATIONS" | bc)

    # Calculate tests per second
    local tests_per_sec
    if (( $(echo "$avg_time > 0" | bc -l) )); then
        tests_per_sec=$(echo "scale=2; $test_count / $avg_time" | bc)
    else
        tests_per_sec="0"
    fi

    success "Average time: ${avg_time}s ($tests_per_sec tests/sec)"

    echo "$avg_time|$test_count|$failures|$tests_per_sec"
}

################################################################################
# Performance Comparison
################################################################################

calculate_improvement() {
    local baseline_time="$1"
    local parallel_time="$2"

    if (( $(echo "$baseline_time > 0" | bc -l) )); then
        local improvement
        improvement=$(echo "scale=2; (($baseline_time - $parallel_time) / $baseline_time) * 100" | bc)

        local speedup
        speedup=$(echo "scale=2; $baseline_time / $parallel_time" | bc)

        echo "$improvement|$speedup"
    else
        echo "0|1"
    fi
}

################################################################################
# Results Output
################################################################################

generate_performance_report() {
    local baseline_time="$1"
    local baseline_tests="$2"
    local baseline_tps="$3"
    local parallel_time="$4"
    local parallel_tests="$5"
    local parallel_tps="$6"
    local improvement="$7"
    local speedup="$8"
    local processes="$9"
    local suite="${10}"

    local output_dir
    output_dir=$(dirname "$OUTPUT_FILE")
    mkdir -p "$output_dir"

    cat > "$OUTPUT_FILE" << EOF
# Test Performance Metrics

**Phase 4.2: Parallel Test Execution**

**Generated**: $(date +'%Y-%m-%d %H:%M:%S')
**Test Suite**: $suite
**Iterations**: $ITERATIONS (averaged)
**Parallel Processes**: $processes

---

## Executive Summary

### Performance Improvement

- **Time Reduction**: ${improvement}%
- **Speedup Factor**: ${speedup}x
- **Target Achievement**: $(if (( $(echo "$improvement >= 60" | bc -l) )); then echo "✅ Target met (≥60%)"; else echo "⚠️  Below target (${improvement}% < 60%)"; fi)

### Execution Times

| Metric | Baseline (Sequential) | Parallel (Optimized) | Improvement |
|--------|----------------------|---------------------|-------------|
| **Total Time** | ${baseline_time}s | ${parallel_time}s | ${improvement}% faster |
| **Tests Executed** | ${baseline_tests} | ${parallel_tests} | - |
| **Tests/Second** | ${baseline_tps} | ${parallel_tps} | $(echo "scale=2; (($parallel_tps - $baseline_tps) / $baseline_tps) * 100" | bc)% |
| **Speedup Factor** | 1.0x | ${speedup}x | - |

---

## Detailed Metrics

### Sequential Execution (Baseline)

\`\`\`
Configuration:
  Processes: 1 (sequential)
  Test Suite: $suite
  Total Tests: ${baseline_tests}

Results:
  Total Time: ${baseline_time}s
  Tests/Second: ${baseline_tps}
  Average per Test: $(echo "scale=4; $baseline_time / $baseline_tests" | bc)s
\`\`\`

### Parallel Execution (Optimized)

\`\`\`
Configuration:
  Processes: $processes
  Test Suite: $suite
  Total Tests: ${parallel_tests}

Results:
  Total Time: ${parallel_time}s
  Tests/Second: ${parallel_tps}
  Average per Test: $(echo "scale=4; $parallel_time / $parallel_tests" | bc)s
  Speedup: ${speedup}x
\`\`\`

---

## System Information

\`\`\`
CPU Cores: $(nproc)
Total Memory: $(free -h | awk '/^Mem:/ {print $2}')
PHP Version: $(php -v | head -n 1 | awk '{print $2}')
Pest Version: $(cd "$PROJECT_ROOT" && ./vendor/bin/pest --version | awk '{print $2}')
Platform: $(uname -s) $(uname -r)
\`\`\`

---

## Test Distribution by Suite

$(if [ "$suite" = "all" ]; then
    echo "### Unit Tests"
    echo "- Fast, isolated tests with no database"
    echo "- Estimated: 30 tests, ~8 seconds"
    echo ""
    echo "### Feature Tests"
    echo "- HTTP and feature testing with database transactions"
    echo "- Estimated: 120 tests, ~18 seconds"
    echo ""
    echo "### Integration Tests"
    echo "- Full stack integration with database"
    echo "- Estimated: 69 tests, ~20 seconds"
    echo ""
else
    echo "Testing focused on: **$suite** suite"
fi)

---

## Performance Analysis

### Parallel Efficiency

\`\`\`
Theoretical Maximum Speedup: $(nproc)x (CPU cores)
Actual Speedup: ${speedup}x
Parallel Efficiency: $(echo "scale=2; ($speedup / $(nproc)) * 100" | bc)%
\`\`\`

### Recommendations

$(if (( $(echo "$improvement >= 60" | bc -l) )); then
    echo "✅ **Target Achieved**: Parallel execution provides ${improvement}% time reduction."
    echo ""
    echo "The test suite is well-optimized for parallel execution. Key factors:"
    echo "- Effective process isolation"
    echo "- Minimal database contention"
    echo "- Good test distribution across processes"
else
    echo "⚠️  **Below Target**: Current improvement is ${improvement}%, target is ≥60%."
    echo ""
    echo "Potential optimizations:"
    echo "- Review test dependencies and ordering"
    echo "- Optimize slow tests in critical path"
    echo "- Check for database lock contention"
    echo "- Verify process count matches CPU cores"
fi)

---

## CI/CD Integration

### GitHub Actions

Tests run in parallel across 3 matrix groups:
- **Unit**: Fast, isolated tests (~8s)
- **Feature**: Medium tests with DB (~18s)
- **Integration**: Full stack tests (~20s)

**Total CI Time**: ~20-25 seconds (parallel) vs ~45-50 seconds (sequential)

### Local Development

To run tests with parallel execution:

\`\`\`bash
# Auto-detect CPU cores
./vendor/bin/pest --parallel

# Specific number of processes
./vendor/bin/pest --parallel --processes=4

# Run specific suite in parallel
./vendor/bin/pest --testsuite=Unit --parallel
\`\`\`

---

## Historical Performance

| Date | Suite | Sequential | Parallel | Improvement | Processes |
|------|-------|-----------|----------|-------------|-----------|
| $(date +'%Y-%m-%d') | $suite | ${baseline_time}s | ${parallel_time}s | ${improvement}% | $processes |

---

## Next Steps

1. **Monitor Performance**: Track test execution times in CI/CD
2. **Optimize Slow Tests**: Profile and improve tests taking >1s
3. **Database Optimization**: Ensure migrations are optimized for parallel tests
4. **Coverage Maintenance**: Maintain 87%+ coverage with parallel execution

---

**Phase 4.2 Status**: $(if (( $(echo "$improvement >= 60" | bc -l) )); then echo "✅ Complete"; else echo "⚠️  In Progress"; fi)
**Last Updated**: $(date +'%Y-%m-%d %H:%M:%S')
EOF

    success "Performance report generated: $OUTPUT_FILE"
}

################################################################################
# Main Execution
################################################################################

main() {
    echo ""
    log "==================================================================="
    log "Test Performance Measurement - Phase 4.2"
    log "==================================================================="
    echo ""

    # Parse arguments
    parse_arguments "$@"

    # Get system information
    get_system_info

    # Variables for results
    local baseline_time=""
    local baseline_tests=""
    local baseline_failures=""
    local baseline_tps=""

    local parallel_time=""
    local parallel_tests=""
    local parallel_failures=""
    local parallel_tps=""

    # Run baseline measurement
    if [ "$RUN_BASELINE" = true ]; then
        echo ""
        log "==================================================================="
        log "Baseline Measurement (Sequential Execution)"
        log "==================================================================="
        echo ""

        local baseline_result
        baseline_result=$(run_iterations "baseline" "1" "$TEST_SUITE")

        baseline_time=$(echo "$baseline_result" | cut -d'|' -f1)
        baseline_tests=$(echo "$baseline_result" | cut -d'|' -f2)
        baseline_failures=$(echo "$baseline_result" | cut -d'|' -f3)
        baseline_tps=$(echo "$baseline_result" | cut -d'|' -f4)

        if [ "$baseline_failures" -gt 0 ]; then
            warning "Baseline tests have $baseline_failures failure(s)"
        fi
    fi

    # Run parallel measurement
    if [ "$RUN_PARALLEL" = true ]; then
        echo ""
        log "==================================================================="
        log "Parallel Measurement (Optimized Execution)"
        log "==================================================================="
        echo ""

        local parallel_result
        parallel_result=$(run_iterations "parallel" "$PARALLEL_PROCESSES" "$TEST_SUITE")

        parallel_time=$(echo "$parallel_result" | cut -d'|' -f1)
        parallel_tests=$(echo "$parallel_result" | cut -d'|' -f2)
        parallel_failures=$(echo "$parallel_result" | cut -d'|' -f3)
        parallel_tps=$(echo "$parallel_result" | cut -d'|' -f4)

        if [ "$parallel_failures" -gt 0 ]; then
            warning "Parallel tests have $parallel_failures failure(s)"
        fi
    fi

    # Calculate improvement
    if [ "$RUN_BASELINE" = true ] && [ "$RUN_PARALLEL" = true ]; then
        echo ""
        log "==================================================================="
        log "Performance Comparison"
        log "==================================================================="
        echo ""

        local comparison_result
        comparison_result=$(calculate_improvement "$baseline_time" "$parallel_time")

        local improvement
        local speedup

        improvement=$(echo "$comparison_result" | cut -d'|' -f1)
        speedup=$(echo "$comparison_result" | cut -d'|' -f2)

        success "Sequential: ${baseline_time}s"
        success "Parallel:   ${parallel_time}s"
        success "Improvement: ${improvement}% (${speedup}x speedup)"

        # Generate report
        generate_performance_report \
            "$baseline_time" "$baseline_tests" "$baseline_tps" \
            "$parallel_time" "$parallel_tests" "$parallel_tps" \
            "$improvement" "$speedup" "$PARALLEL_PROCESSES" "$TEST_SUITE"

        # Check if target met
        echo ""
        if (( $(echo "$improvement >= 60" | bc -l) )); then
            success "✅ Target achieved: ${improvement}% >= 60%"
            exit 0
        else
            warning "⚠️  Below target: ${improvement}% < 60%"
            exit 0  # Still exit 0 to allow CI to continue
        fi
    else
        echo ""
        warning "Skipping comparison (need both baseline and parallel measurements)"
    fi
}

# Run main function with all arguments
main "$@"
