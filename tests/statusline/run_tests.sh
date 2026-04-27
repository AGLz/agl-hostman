#!/bin/bash
# ===============================================
# Test Runner Script for statusline-command.sh
# ===============================================
# This script provides convenient ways to run the test suite
# with various options and formatting.
# ===============================================

set -euo pipefail

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_FILE="${SCRIPT_DIR}/statusline_command.bats"

# Print header
print_header() {
  echo
  echo -e "${CYAN}============================================${NC}"
  echo -e "${CYAN} $1${NC}"
  echo -e "${CYAN}============================================${NC}"
  echo
}

# Print info
print_info() {
  echo -e "${BLUE}[INFO]${NC} $1"
}

# Print success
print_success() {
  echo -e "${GREEN}[SUCCESS]${NC} $1"
}

# Print error
print_error() {
  echo -e "${RED}[ERROR]${NC} $1"
}

# Check dependencies
check_dependencies() {
  print_info "Checking dependencies..."

  local missing=0

  if ! command -v bats &>/dev/null; then
    print_error "bats is not installed. Install with: apt-get install bats"
    missing=1
  fi

  if ! command -v jq &>/dev/null; then
    print_error "jq is not installed. Install with: apt-get install jq"
    missing=1
  fi

  if ! command -v git &>/dev/null; then
    print_error "git is not installed. Install with: apt-get install git"
    missing=1
  fi

  if [ $missing -eq 1 ]; then
    echo
    exit 1
  fi

  print_success "All dependencies are installed"
  echo
}

# Run all tests
run_all_tests() {
  print_header "Running All Tests"
  bats --formatter tap "$TEST_FILE"
}

# Run with pretty formatter
run_pretty_tests() {
  print_header "Running Tests (Pretty Format)"
  bats --formatter pretty "$TEST_FILE"
}

# Run specific test by name
run_specific_test() {
  local test_name="$1"
  print_header "Running Test: $test_name"
  bats -f "$test_name" "$TEST_FILE"
}

# Run specific test suite by pattern
run_test_suite() {
  local pattern="$1"
  print_header "Running Test Suite: $pattern"
  bats -f "$pattern" "$TEST_FILE"
}

# Run tests and show detailed output on failure
run_verbose_tests() {
  print_header "Running Tests (Verbose)"
  bats -v --pretty "$TEST_FILE"
}

# Run tests with timing information
run_timed_tests() {
  print_header "Running Tests (With Timing)"
  bats --formatter tap --timing "$TEST_FILE"
}

# List all tests without running
list_tests() {
  print_header "Available Tests"
  bats --list "$TEST_FILE" | nl
}

# Run quick tests (subset of fast tests)
run_quick_tests() {
  print_header "Running Quick Tests"
  local quick_tests=(
    "statusline: accepts valid empty JSON object"
    "statusline: handles JSON with missing optional fields"
    "statusline: output contains model name"
    "statusline: output is single line"
    "statusline: executes in reasonable time"
  )

  for test in "${quick_tests[@]}"; do
    bats -f "$test" "$TEST_FILE"
  done
}

# Generate test report
generate_report() {
  print_header "Generating Test Report"

  local output_file="${SCRIPT_DIR}/test-report.txt"
  local total=0
  local passed=0
  local failed=0
  local skipped=0

  # Run tests and capture output
  while IFS= read -r line; do
    ((total++))
    if [[ "$line" =~ "ok" ]]; then
      ((passed++))
    elif [[ "$line" =~ "not ok" ]]; then
      ((failed++))
    elif [[ "$line" =~ "skip" ]]; then
      ((skipped++))
    fi
  done < <(bats --formatter tap "$TEST_FILE" 2>&1)

  # Write report
  {
    echo "=========================================="
    echo "Statusline Test Report"
    echo "=========================================="
    echo "Date: $(date)"
    echo "Total Tests: $total"
    echo "Passed: $passed"
    echo "Failed: $failed"
    echo "Skipped: $skipped"
    echo "=========================================="
    echo
    echo "Detailed Results:"
    bats --formatter tap "$TEST_FILE"
  } > "$output_file"

  print_success "Report saved to: $output_file"
}

# Run tests in CI mode (CI-friendly output)
run_ci_tests() {
  print_header "Running Tests (CI Mode)"
  bats --formatter junit --report-formatter junit "$TEST_FILE"
}

# Clean up test artifacts
cleanup() {
  print_info "Cleaning up test artifacts..."

  # Remove temp directories
  find /tmp -name "statusline-test-*" -type d -mtime +1 -exec rm -rf {} + 2>/dev/null || true

  print_success "Cleanup complete"
}

# Print usage
print_usage() {
  cat << EOF
Usage: $(basename "$0") [COMMAND] [OPTIONS]

Commands:
  all             Run all tests (default)
  pretty          Run tests with pretty formatting
  verbose         Run tests with verbose output
  list            List all available tests
  quick           Run quick subset of tests
  report          Generate test report
  ci              Run tests in CI mode
  time            Run tests with timing information
  test NAME       Run specific test by name
  suite PATTERN   Run tests matching pattern
  cleanup         Clean up test artifacts
  help            Show this help message

Examples:
  $(basename "$0") all
  $(basename "$0") test "statusline: accepts valid empty JSON object"
  $(basename "$0") suite "statusline: git"
  $(basename "$0") pretty
  $(basename "$0") report

EOF
}

# Main function
main() {
  local command="${1:-all}"
  local arg="$2"

  # Check dependencies first
  check_dependencies

  case "$command" in
    all)
      run_all_tests
      ;;
    pretty)
      run_pretty_tests
      ;;
    verbose)
      run_verbose_tests
      ;;
    list)
      list_tests
      ;;
    quick)
      run_quick_tests
      ;;
    report)
      generate_report
      ;;
    ci)
      run_ci_tests
      ;;
    time)
      run_timed_tests
      ;;
    test)
      if [ -z "$arg" ]; then
        print_error "Please provide a test name"
        echo
        print_usage
        exit 1
      fi
      run_specific_test "$arg"
      ;;
    suite)
      if [ -z "$arg" ]; then
        print_error "Please provide a test pattern"
        echo
        print_usage
        exit 1
      fi
      run_test_suite "$arg"
      ;;
    cleanup)
      cleanup
      ;;
    help|--help|-h)
      print_usage
      ;;
    *)
      print_error "Unknown command: $command"
      echo
      print_usage
      exit 1
      ;;
  esac

  echo
}

# Run main
main "$@"
