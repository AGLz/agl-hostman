#!/bin/bash

# Statusline Quick Test Runner - FGSRV6
# Run this script to quickly validate statusline deployment

set -euo pipefail

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

STATUSLINE_SCRIPT="${1:-.claude/statusline-command.sh}"
VERBOSE="${2:-false}"

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

log_error() {
    echo -e "${RED}[✗]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[!]${NC} $1"
}

# Test counter
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_TOTAL=0

run_test() {
    local name="$1"
    local command="$2"

    ((TESTS_TOTAL++))

    if eval "$command" > /dev/null 2>&1; then
        log_success "$name"
        ((TESTS_PASSED++))
        return 0
    else
        log_error "$name"
        ((TESTS_FAILED++))
        return 1
    fi
}

print_header() {
    echo
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE} $1${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo
}

print_summary() {
    echo
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE} Test Summary${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo -e "Total: $TESTS_TOTAL tests"
    echo -e "${GREEN}Passed: $TESTS_PASSED${NC}"
    echo -e "${RED}Failed: $TESTS_FAILED${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo

    if [ $TESTS_FAILED -eq 0 ]; then
        log_success "All tests passed! Statusline is ready for deployment."
        return 0
    else
        log_error "Some tests failed! Please fix before deploying."
        return 1
    fi
}

main() {
    log_info "Quick Statusline Validation for FGSRV6"
    log_info "Script: $STATUSLINE_SCRIPT"
    log_info "Started at: $(date)"
    echo

    # Pre-flight checks
    print_header "Pre-flight Checks"

    run_test "Script exists" "[ -f '$STATUSLINE_SCRIPT' ]"
    run_test "Script is executable" "[ -x '$STATUSLINE_SCRIPT' ]"
    run_test "jq is available" "which jq > /dev/null"
    run_test "bash is available" "which bash > /dev/null"
    run_test "git is available" "which git > /dev/null"
    run_test "bc is available" "which bc > /dev/null"
    run_test "awk is available" "which awk > /dev/null"
    run_test "Settings.json exists" "[ -f '.claude/settings.json' ]"
    run_test "Settings.json is valid JSON" "jq '.' .claude/settings.json > /dev/null"
    run_test "Settings has statusLine config" "jq -e '.statusLine' .claude/settings.json > /dev/null"

    # Execution tests
    print_header "Execution Tests"

    run_test "Script runs with empty input" "echo '{}' | '$STATUSLINE_SCRIPT' > /dev/null"
    run_test "Script runs with minimal input" "echo '{\"model\":{\"display_name\":\"Test\"}}' | '$STATUSLINE_SCRIPT' > /dev/null"
    run_test "Script runs with full input" "echo '{\"model\":{\"display_name\":\"Claude\"},\"cwd\":\"/test\"}' | '$STATUSLINE_SCRIPT' > /dev/null"

    # Output validation
    print_header "Output Validation"

    # Test 1: Output is not empty
    OUTPUT=$(echo '{}' | "$STATUSLINE_SCRIPT" 2>/dev/null)
    if [ -n "$OUTPUT" ]; then
        log_success "Output is not empty"
        ((TESTS_PASSED++))
    else
        log_error "Output is empty"
        ((TESTS_FAILED++))
    fi
    ((TESTS_TOTAL++))

    # Test 2: Output contains model name
    OUTPUT=$(echo '{"model":{"display_name":"Claude"}}' | "$STATUSLINE_SCRIPT" 2>/dev/null)
    if echo "$OUTPUT" | grep -q "Claude"; then
        log_success "Output contains model name"
        ((TESTS_PASSED++))
    else
        log_error "Output missing model name"
        ((TESTS_FAILED++))
    fi
    ((TESTS_TOTAL++))

    # Test 3: Output contains directory name
    OUTPUT=$(echo '{"cwd":"/test/dir"}' | "$STATUSLINE_SCRIPT" 2>/dev/null)
    if echo "$OUTPUT" | grep -q "dir"; then
        log_success "Output contains directory name"
        ((TESTS_PASSED++))
    else
        log_error "Output missing directory name"
        ((TESTS_FAILED++))
    fi
    ((TESTS_TOTAL++))

    # Test 4: Output contains ANSI colors
    OUTPUT=$(echo '{}' | "$STATUSLINE_SCRIPT" 2>/dev/null)
    if echo "$OUTPUT" | grep -q $'\033\[36m'; then
        log_success "Output contains ANSI color codes"
        ((TESTS_PASSED++))
    else
        log_error "Output missing ANSI color codes"
        ((TESTS_FAILED++))
    fi
    ((TESTS_TOTAL++))

    # Test 5: Output is single line
    LINE_COUNT=$(echo '{}' | "$STATUSLINE_SCRIPT" 2>/dev/null | wc -l)
    if [ "$LINE_COUNT" -eq 1 ]; then
        log_success "Output is single line"
        ((TESTS_PASSED++))
    else
        log_error "Output has $LINE_COUNT lines (should be 1)"
        ((TESTS_FAILED++))
    fi
    ((TESTS_TOTAL++))

    # Test 6: No literal escape sequences
    OUTPUT=$(echo '{}' | "$STATUSLINE_SCRIPT" 2>/dev/null)
    if ! echo "$OUTPUT" | grep -q '\\033'; then
        log_success "No literal escape sequences"
        ((TESTS_PASSED++))
    else
        log_error "Found literal escape sequences"
        ((TESTS_FAILED++))
    fi
    ((TESTS_TOTAL++))

    # Performance test
    print_header "Performance Test"

    log_info "Testing execution time..."
    START=$(date +%s%N)
    for i in {1..5}; do
        echo '{}' | "$STATUSLINE_SCRIPT" > /dev/null
    done
    END=$(date +%s%N)
    AVG_MS=$(( (END - START) / 1000000 / 5 ))

    echo "Average execution time: ${AVG_MS}ms"

    if [ "$AVG_MS" -lt 100 ]; then
        log_success "Execution time < 100ms (${AVG_MS}ms)"
        ((TESTS_PASSED++))
    else
        log_warn "Execution time >= 100ms (${AVG_MS}ms) - may be acceptable"
    fi
    ((TESTS_TOTAL++))

    # Error handling
    print_header "Error Handling"

    run_test "Handles invalid JSON" "echo 'invalid' | '$STATUSLINE_SCRIPT' 2>&1 | head -1"
    run_test "Handles empty input" "echo '' | '$STATUSLINE_SCRIPT' 2>&1 | head -1"

    # Git integration (if in git repo)
    print_header "Git Integration"

    if [ -d .git ]; then
        run_test "In git repository" "test -d .git"
        run_test "Shows git branch" "echo '{}' | '$STATUSLINE_SCRIPT' 2>/dev/null | grep -q '⎇'"
    else
        log_warn "Not in git repository - skipping git tests"
    fi

    # Print summary
    print_summary

    # Provide next steps
    echo
    if [ $TESTS_FAILED -eq 0 ]; then
        log_success "Statusline passed all quick tests!"
        echo
        echo "Next steps:"
        echo "  1. Run full test suite: ./test-cases.sh"
        echo "  2. Review expected output: cat expected-output.md"
        echo "  3. Deploy to FGSRV6"
        echo "  4. Monitor statusline in Claude Code"
    else
        log_error "Statusline has issues that need fixing!"
        echo
        echo "Next steps:"
        echo "  1. Review failed tests above"
        echo "  2. Check validation checklist: cat validation-checklist.md"
        echo "  3. Fix issues and re-run this script"
    fi
    echo

    return $TESTS_FAILED
}

# Run main
main "$@"
