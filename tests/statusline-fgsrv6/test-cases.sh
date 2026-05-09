#!/bin/bash

# Statusline Test Cases - FGSRV6 Deployment
# This script contains comprehensive test cases for validating statusline functionality

set -euo pipefail

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Statusline script path
STATUSLINE_SCRIPT="${STATUSLINE_SCRIPT:-.claude/statusline-command.sh}"

# Helper functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[PASS]${NC} $1"
    ((TESTS_PASSED++))
}

log_fail() {
    echo -e "${RED}[FAIL]${NC} $1"
    ((TESTS_FAILED++))
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

run_test() {
    local test_name="$1"
    local test_command="$2"

    ((TESTS_RUN++))
    log_info "Running: $test_name"

    if eval "$test_command" > /dev/null 2>&1; then
        log_success "$test_name"
        return 0
    else
        log_fail "$test_name"
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
    echo -e "Total tests run: $TESTS_RUN"
    echo -e "${GREEN}Passed: $TESTS_PASSED${NC}"
    echo -e "${RED}Failed: $TESTS_FAILED${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo

    if [ $TESTS_FAILED -eq 0 ]; then
        log_success "All tests passed!"
        return 0
    else
        log_fail "Some tests failed!"
        return 1
    fi
}

# Test Suite 1: Basic Functionality Tests
test_basic_functionality() {
    print_header "Test Suite 1: Basic Functionality"

    # Test 1.1: Script exists and is executable
    run_test "Script exists and is executable" \
        "[ -x '$STATUSLINE_SCRIPT' ]"

    # Test 1.2: Script runs without arguments
    run_test "Script runs without arguments (empty input)" \
        "echo '{}' | '$STATUSLINE_SCRIPT'"

    # Test 1.3: Script handles minimal JSON input
    run_test "Script handles minimal JSON input" \
        "echo '{\"model\":{\"display_name\":\"Test\"},\"cwd\":\"/test\"}' | '$STATUSLINE_SCRIPT'"

    # Test 1.4: Script produces output
    run_test "Script produces non-empty output" \
        "[ -n \"\$(echo '{}' | '$STATUSLINE_SCRIPT')\" ]"

    # Test 1.5: Output contains model name
    run_test "Output contains model name" \
        "echo '{\"model\":{\"display_name\":\"Claude\"}}' | '$STATUSLINE_SCRIPT' | grep -q 'Claude'"

    # Test 1.6: Output contains directory name
    run_test "Output contains directory name" \
        "echo '{\"cwd\":\"/test/dir\"}' | '$STATUSLINE_SCRIPT' | grep -q 'dir'"
}

# Test Suite 2: JSON Parsing Tests
test_json_parsing() {
    print_header "Test Suite 2: JSON Parsing"

    # Test 2.1: Valid full Claude Code JSON input
    run_test "Valid full Claude Code JSON input" \
        "cat << 'EOF' | '$STATUSLINE_SCRIPT'
{
  \"session_id\": \"test-123\",
  \"model\": {
    \"id\": \"claude-sonnet-4-5-20250929\",
    \"display_name\": \"Sonnet 4.5\"
  },
  \"workspace\": {
    \"current_dir\": \"/test\",
    \"project_dir\": \"/test\"
  },
  \"cwd\": \"/test\"
}
EOF"

    # Test 2.2: JSON with missing optional fields
    run_test "JSON with missing optional fields" \
        "echo '{\"model\":{\"display_name\":\"Test\"}}' | '$STATUSLINE_SCRIPT'"

    # Test 2.3: JSON with null values
    run_test "JSON with null values" \
        "echo '{\"model\":null,\"cwd\":null}' | '$STATUSLINE_SCRIPT'"

    # Test 2.4: JSON with empty strings
    run_test "JSON with empty strings" \
        "echo '{\"model\":{\"display_name\":\"\"},\"cwd\":\"\"}' | '$STATUSLINE_SCRIPT'"
}

# Test Suite 3: Git Integration Tests
test_git_integration() {
    print_header "Test Suite 3: Git Integration"

    # Test 3.1: Shows git branch when in git repository
    if [ -d .git ]; then
        run_test "Shows git branch in git repository" \
            "echo '{}' | '$STATUSLINE_SCRIPT' | grep -q '⎇'"
    else
        log_warn "Skipping git tests - not in a git repository"
    fi

    # Test 3.2: Handles non-git directory gracefully
    run_test "Handles non-git directory gracefully" \
        "(cd /tmp && echo '{\"cwd\":\"/tmp\"}' | '$STATUSLINE_SCRIPT')"

    # Test 3.3: Shows branch name correctly
    if [ -d .git ]; then
        local current_branch
        current_branch=$(git branch --show-current 2>/dev/null || echo "")
        if [ -n "$current_branch" ]; then
            run_test "Shows correct branch name" \
                "echo '{}' | '$STATUSLINE_SCRIPT' | grep -q \"$current_branch\""
        fi
    fi
}

# Test Suite 4: Claude-Flow Integration Tests
test_claude_flow_integration() {
    print_header "Test Suite 4: Claude-Flow Integration"

    # Test 4.1: Handles missing .claude-flow directory
    run_test "Handles missing .claude-flow directory" \
        "(cd /tmp && echo '{}' | '$STATUSLINE_SCRIPT')"

    # Test 4.2: Handles existing .claude-flow directory
    if [ -d .claude-flow ]; then
        run_test "Handles existing .claude-flow directory" \
            "echo '{}' | '$STATUSLINE_SCRIPT' | head -1 > /dev/null"
    else
        log_warn "Skipping .claude-flow tests - directory not initialized"
    fi

    # Test 4.3: Handles swarm-config.json (if exists)
    if [ -f .claude-flow/swarm-config.json ]; then
        run_test "Validates swarm-config.json format" \
            "jq '.defaultStrategy' .claude-flow/swarm-config.json > /dev/null"
    fi

    # Test 4.4: Handles metrics files (if exist)
    if [ -f .claude-flow/metrics/system-metrics.json ]; then
        run_test "Validates system-metrics.json format" \
            "jq '.[-1]' .claude-flow/metrics/system-metrics.json > /dev/null"
    fi

    if [ -f .claude-flow/metrics/task-metrics.json ]; then
        run_test "Validates task-metrics.json format" \
            "jq '. | length' .claude-flow/metrics/task-metrics.json > /dev/null"
    fi
}

# Test Suite 5: Error Handling Tests
test_error_handling() {
    print_header "Test Suite 5: Error Handling"

    # Test 5.1: Handles invalid JSON
    run_test "Handles invalid JSON gracefully" \
        "echo 'invalid json' | '$STATUSLINE_SCRIPT' 2>&1 | head -1"

    # Test 5.2: Handles truncated JSON
    run_test "Handles truncated JSON" \
        "echo '{\"model\":{\"display_name\":\"Test\"' | '$STATUSLINE_SCRIPT' 2>&1 | head -1"

    # Test 5.3: Handles empty input
    run_test "Handles empty input" \
        "echo '' | '$STATUSLINE_SCRIPT' 2>&1 | head -1"

    # Test 5.4: Handles special characters in input
    run_test "Handles special characters in input" \
        "echo '{\"model\":{\"display_name\":\"Test<>&\"},\"cwd\":\"/test/path\"}' | '$STATUSLINE_SCRIPT'"
}

# Test Suite 6: Performance Tests
test_performance() {
    print_header "Test Suite 6: Performance"

    # Test 6.1: Execution time < 100ms
    log_info "Testing execution time (should be < 100ms)"
    local start end duration
    start=$(date +%s%N)
    echo '{}' | '$STATUSLINE_SCRIPT' > /dev/null
    end=$(date +%s%N)
    duration=$(( (end - start) / 1000000 ))
    echo "Execution time: ${duration}ms"

    if [ "$duration" -lt 100 ]; then
        log_success "Execution time < 100ms"
    else
        log_fail "Execution time >= 100ms (${duration}ms)"
    fi
    ((TESTS_RUN++))

    # Test 6.2: Execution time < 300ms (maximum acceptable)
    if [ "$duration" -lt 300 ]; then
        log_success "Execution time < 300ms"
    else
        log_fail "Execution time >= 300ms (${duration}ms)"
    fi
    ((TESTS_RUN++))

    # Test 6.3: Multiple rapid executions
    log_info "Testing rapid executions (10x)"
    start=$(date +%s%N)
    for i in {1..10}; do
        echo '{}' | '$STATUSLINE_SCRIPT' > /dev/null
    done
    end=$(date +%s%N)
    duration=$(( (end - start) / 1000000 / 10 ))
    echo "Average execution time: ${duration}ms"

    if [ "$duration" -lt 100 ]; then
        log_success "Rapid executions < 100ms average"
    else
        log_warn "Rapid executions >= 100ms average (${duration}ms)"
    fi
    ((TESTS_RUN++))
}

# Test Suite 7: Visual Output Tests
test_visual_output() {
    print_header "Test Suite 7: Visual Output"

    # Test 7.1: Output contains ANSI color codes
    run_test "Output contains ANSI color codes" \
        "echo '{}' | '$STATUSLINE_SCRIPT' | grep -q $'\\033\\['"

    # Test 7.2: Output does not contain literal escape sequences
    run_test "Output does not contain literal escape sequences" \
        "! echo '{}' | '$STATUSLINE_SCRIPT' | grep -q '\\\\033'"

    # Test 7.3: Output ends with newline
    run_test "Output ends with newline" \
        "echo '{}' | '$STATUSLINE_SCRIPT' | tail -c 1 | grep -q $'\\n'"

    # Test 7.4: Output is single line (no embedded newlines)
    run_test "Output is single line" \
        "[ \$(echo '{}' | '$STATUSLINE_SCRIPT' | wc -l) -eq 1 ]"

    # Test 7.5: Output length is reasonable (< 500 chars)
    run_test "Output length is reasonable" \
        "[ \$(echo '{}' | '$STATUSLINE_SCRIPT' | wc -c) -lt 500 ]"
}

# Test Suite 8: Component Tests
test_components() {
    print_header "Test Suite 8: Component Display Tests"

    # Create test directory with various components
    local test_dir="/tmp/statusline-test-$$"
    mkdir -p "$test_dir"
    cd "$test_dir"

    # Initialize git repo
    git init -q 2>/dev/null || true
    git config user.email "test@test.com" 2>/dev/null || true
    git config user.name "Test User" 2>/dev/null || true
    touch .gitkeep
    git add .gitkeep 2>/dev/null || true
    git commit -m "Initial" 2>/dev/null || true

    # Create .claude-flow structure
    mkdir -p .claude-flow/metrics

    # Test 8.1: Model and directory display
    log_info "Testing model and directory display"
    output=$(echo '{"model":{"display_name":"Claude"},"cwd":"'$test_dir'"}' | "$STATUSLINE_SCRIPT")
    echo "$output" | grep -q "Claude" && log_success "Model name displayed" || log_fail "Model name not displayed"
    echo "$output" | grep -q "statusline-test" && log_success "Directory displayed" || log_fail "Directory not displayed"
    ((TESTS_RUN+=2))

    # Test 8.2: Git branch display
    log_info "Testing git branch display"
    output=$(echo '{"cwd":"'$test_dir'"}' | "$STATUSLINE_SCRIPT")
    echo "$output" | grep -q "⎇" && log_success "Git branch indicator present" || log_warn "Git branch indicator missing"
    ((TESTS_RUN++))

    # Test 8.3: Memory metrics (if metrics file exists)
    if [ -f .claude-flow/metrics/system-metrics.json ]; then
        # Create sample metrics
        echo '[{"memoryUsagePercent":45,"cpuLoad":0.3}]' > .claude-flow/metrics/system-metrics.json
        output=$(echo '{"cwd":"'$test_dir'"}' | "$STATUSLINE_SCRIPT")
        echo "$output" | grep -q "💾" && log_success "Memory metric icon present" || log_warn "Memory metric icon missing"
        ((TESTS_RUN++))
    fi

    # Test 8.4: CPU metrics (if metrics file exists)
    if [ -f .claude-flow/metrics/system-metrics.json ]; then
        output=$(echo '{"cwd":"'$test_dir'"}' | "$STATUSLINE_SCRIPT")
        echo "$output" | grep -q "⚙" && log_success "CPU metric icon present" || log_warn "CPU metric icon missing"
        ((TESTS_RUN++))
    fi

    # Cleanup
    cd - > /dev/null
    rm -rf "$test_dir"
}

# Test Suite 9: Integration with Claude Code
test_claude_code_integration() {
    print_header "Test Suite 9: Claude Code Integration"

    # Test 9.1: Settings.json has correct statusLine configuration
    run_test "Settings.json has statusLine configuration" \
        "jq -e '.statusLine' .claude/settings.json > /dev/null"

    # Test 9.2: StatusLine type is 'command'
    run_test "StatusLine type is 'command'" \
        "[ \"\$(jq -r '.statusLine.type' .claude/settings.json)\" = 'command' ]"

    # Test 9.3: StatusLine command path is correct
    run_test "StatusLine command path is correct" \
        "[ \"\$(jq -r '.statusLine.command' .claude/settings.json)\" = '.claude/statusline-command.sh' ]"

    # Test 9.4: Can read settings.json
    run_test "Settings.json is valid and readable" \
        "jq '.' .claude/settings.json > /dev/null"
}

# Main execution
main() {
    log_info "Starting Statusline Test Suite for FGSRV6"
    log_info "Statusline script: $STATUSLINE_SCRIPT"
    log_info "Test started at: $(date)"

    # Run all test suites
    test_basic_functionality
    test_json_parsing
    test_git_integration
    test_claude_flow_integration
    test_error_handling
    test_performance
    test_visual_output
    test_components
    test_claude_code_integration

    # Print summary
    print_summary

    # Exit with appropriate code
    if [ $TESTS_FAILED -eq 0 ]; then
        exit 0
    else
        exit 1
    fi
}

# Run main function
main "$@"
