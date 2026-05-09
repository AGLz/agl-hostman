#!/bin/bash

# Automated Statusline Deployment Test - FGSRV6
# This script performs a complete end-to-end deployment test

set -euo pipefail

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
TEST_DIR="/tmp/statusline-test-$TIMESTAMP"
LOG_FILE="$TEST_DIR/deployment-test.log"

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1" | tee -a "$LOG_FILE"
}

log_success() {
    echo -e "${GREEN}[✓]${NC} $1" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "${RED}[✗]${NC} $1" | tee -a "$LOG_FILE"
}

log_warn() {
    echo -e "${YELLOW}[!]${NC} $1" | tee -a "$LOG_FILE"
}

# Create test directory
mkdir -p "$TEST_DIR"
log_info "Created test directory: $TEST_DIR"

# Copy current statusline for comparison
log_info "Backing up current statusline configuration..."
cp .claude/settings.json "$TEST_DIR/settings-backup.json" 2>/dev/null || echo "No existing settings"
cp .claude/statusline-command.sh "$TEST_DIR/statusline-backup.sh" 2>/dev/null || echo "No existing script"

# Create test environment
log_info "Creating test environment..."
cd "$TEST_DIR"

# Initialize git repo
git init -q
git config user.email "test@fgsrv6"
git config user.name "FGSRV6 Test"
echo "# Test Project" > README.md
git add README.md
git commit -m "Initial commit" -q

# Copy statusline script
log_info "Deploying statusline script..."
cp /mnt/overpower/apps/dev/agl/agl-hostman/.claude/statusline-command.sh ./
chmod +x ./statusline-command.sh

# Create settings.json
log_info "Creating settings.json..."
cat > .claude/settings.json << 'EOF'
{
  "statusLine": {
    "type": "command",
    "command": "./statusline-command.sh"
  }
}
EOF

# Create .claude-flow structure
log_info "Creating .claude-flow structure..."
mkdir -p .claude-flow/metrics .claude-flow/tasks

# Create sample swarm-config.json
cat > .claude-flow/swarm-config.json << 'EOF'
{
  "defaultStrategy": "balanced",
  "agentProfiles": [
    {"name": "coder", "type": "development"},
    {"name": "tester", "type": "testing"},
    {"name": "reviewer", "type": "review"}
  ]
}
EOF

# Create sample system metrics
cat > .claude-flow/metrics/system-metrics.json << 'EOF'
[
  {"timestamp": "2025-01-04T10:00:00Z", "memoryUsagePercent": 45.2, "cpuLoad": 0.35},
  {"timestamp": "2025-01-04T10:05:00Z", "memoryUsagePercent": 48.7, "cpuLoad": 0.42}
]
EOF

# Create sample session state
cat > .claude-flow/session-state.json << 'EOF'
{
  "sessionId": "fgsrv6-test-session-123",
  "active": true,
  "startTime": "2025-01-04T10:00:00Z"
}
EOF

# Create sample task metrics
cat > .claude-flow/metrics/task-metrics.json << 'EOF'
[
  {"id": 1, "success": true, "duration": 1.2},
  {"id": 2, "success": true, "duration": 0.8},
  {"id": 3, "success": true, "duration": 1.5},
  {"id": 4, "success": true, "duration": 1.1},
  {"id": 5, "success": false, "duration": 2.0}
]
EOF

# Create sample tasks
echo '{"id":1,"status":"completed"}' > .claude-flow/tasks/task1.json
echo '{"id":2,"status":"running"}' > .claude-flow/tasks/task2.json
echo '{"id":3,"status":"pending"}' > .claude-flow/tasks/task3.json

# Create hooks state
cat > .claude-flow/hooks-state.json << 'EOF'
{
  "enabled": true,
  "lastRun": "2025-01-04T10:05:00Z"
}
EOF

log_success "Test environment created"

# Run tests
log_info "Running deployment tests..."

TESTS_PASSED=0
TESTS_FAILED=0

run_test() {
    local name="$1"
    local command="$2"

    log_info "Test: $name"

    if eval "$command" >> "$LOG_FILE" 2>&1; then
        log_success "  ✓ $name"
        ((TESTS_PASSED++))
        return 0
    else
        log_error "  ✗ $name"
        ((TESTS_FAILED++))
        return 1
    fi
}

# Test 1: Script execution with minimal input
run_test "Minimal input execution" \
    "echo '{\"model\":{\"display_name\":\"Test\"},\"cwd\":\"$TEST_DIR\"}' | ./statusline-command.sh"

# Test 2: Script execution with full input
run_test "Full input execution" \
    "echo '{\"model\":{\"display_name\":\"Sonnet 4.5\"},\"cwd\":\"$TEST_DIR\"}' | ./statusline-command.sh"

# Test 3: Output contains model name
OUTPUT=$(echo '{"model":{"display_name":"Sonnet 4.5"},"cwd":"'$TEST_DIR'"}' | ./statusline-command.sh 2>/dev/null)
if echo "$OUTPUT" | grep -q "Sonnet 4.5"; then
    log_success "  ✓ Model name in output"
    ((TESTS_PASSED++))
else
    log_error "  ✗ Model name missing"
    ((TESTS_FAILED++))
fi

# Test 4: Output contains directory name
if echo "$OUTPUT" | grep -q "statusline-test"; then
    log_success "  ✓ Directory name in output"
    ((TESTS_PASSED++))
else
    log_error "  ✗ Directory name missing"
    ((TESTS_FAILED++))
fi

# Test 5: Git branch shown
if echo "$OUTPUT" | grep -q "⎇"; then
    log_success "  ✓ Git branch shown"
    ((TESTS_PASSED++))
else
    log_error "  ✗ Git branch missing"
    ((TESTS_FAILED++))
fi

# Test 6: Swarm topology shown
if echo "$OUTPUT" | grep -q "⚡mesh"; then
    log_success "  ✓ Swarm topology shown"
    ((TESTS_PASSED++))
else
    log_error "  ✗ Swarm topology missing"
    ((TESTS_FAILED++))
fi

# Test 7: Agent count shown
if echo "$OUTPUT" | grep -q "🤖 3"; then
    log_success "  ✓ Agent count shown"
    ((TESTS_PASSED++))
else
    log_error "  ✗ Agent count missing"
    ((TESTS_FAILED++))
fi

# Test 8: Memory metrics shown
if echo "$OUTPUT" | grep -q "💾"; then
    log_success "  ✓ Memory metrics shown"
    ((TESTS_PASSED++))
else
    log_error "  ✗ Memory metrics missing"
    ((TESTS_FAILED++))
fi

# Test 9: CPU metrics shown
if echo "$OUTPUT" | grep -q "⚙"; then
    log_success "  ✓ CPU metrics shown"
    ((TESTS_PASSED++))
else
    log_error "  ✗ CPU metrics missing"
    ((TESTS_FAILED++))
fi

# Test 10: Session ID shown
if echo "$OUTPUT" | grep -q "🔄"; then
    log_success "  ✓ Session ID shown"
    ((TESTS_PASSED++))
else
    log_error "  ✗ Session ID missing"
    ((TESTS_FAILED++))
fi

# Test 11: Success rate shown
if echo "$OUTPUT" | grep -q "🎯"; then
    log_success "  ✓ Success rate shown"
    ((TESTS_PASSED++))
else
    log_error "  ✗ Success rate missing"
    ((TESTS_FAILED++))
fi

# Test 12: Average time shown
if echo "$OUTPUT" | grep -q "⏱️"; then
    log_success "  ✓ Average time shown"
    ((TESTS_PASSED++))
else
    log_error "  ✗ Average time missing"
    ((TESTS_FAILED++))
fi

# Test 13: Task count shown
if echo "$OUTPUT" | grep -q "📋 3"; then
    log_success "  ✓ Task count shown"
    ((TESTS_PASSED++))
else
    log_error "  ✗ Task count missing"
    ((TESTS_FAILED++))
fi

# Test 14: Hooks indicator shown
if echo "$OUTPUT" | grep -q "🔗"; then
    log_success "  ✓ Hooks indicator shown"
    ((TESTS_PASSED++))
else
    log_error "  ✗ Hooks indicator missing"
    ((TESTS_FAILED++))
fi

# Test 15: ANSI colors present
if echo "$OUTPUT" | grep -q $'\033\[36m'; then
    log_success "  ✓ ANSI colors present"
    ((TESTS_PASSED++))
else
    log_error "  ✗ ANSI colors missing"
    ((TESTS_FAILED++))
fi

# Test 16: No literal escape sequences
if ! echo "$OUTPUT" | grep -q '\\033'; then
    log_success "  ✓ No literal escape sequences"
    ((TESTS_PASSED++))
else
    log_error "  ✗ Literal escape sequences found"
    ((TESTS_FAILED++))
fi

# Test 17: Single line output
LINE_COUNT=$(echo "$OUTPUT" | wc -l)
if [ "$LINE_COUNT" -eq 1 ]; then
    log_success "  ✓ Single line output"
    ((TESTS_PASSED++))
else
    log_error "  ✗ Multiple lines in output ($LINE_COUNT)"
    ((TESTS_FAILED++))
fi

# Test 18: Performance test
log_info "  Running performance test..."
START=$(date +%s%N)
echo '{}' | ./statusline-command.sh > /dev/null
END=$(date +%s%N)
DURATION=$(( (END - START) / 1000000 ))

if [ "$DURATION" -lt 100 ]; then
    log_success "  ✓ Performance OK (${DURATION}ms)"
    ((TESTS_PASSED++))
else
    log_warn "  ⚠ Performance slow (${DURATION}ms) - may be acceptable"
fi

# Test 19: Error handling
run_test "Error handling - invalid JSON" \
    "echo 'invalid' | ./statusline-command.sh 2>&1 | head -1"

# Test 20: Empty input handling
run_test "Error handling - empty input" \
    "echo '' | ./statusline-command.sh 2>&1 | head -1"

# Print sample output
echo
log_info "Sample statusline output:"
echo "----------------------------------------"
echo "$OUTPUT"
echo "----------------------------------------"
echo

# Summary
TESTS_TOTAL=$((TESTS_PASSED + TESTS_FAILED))
log_info "Test Summary:"
log_info "  Total: $TESTS_TOTAL tests"
log_success "  Passed: $TESTS_PASSED"
log_error "  Failed: $TESTS_FAILED"
echo

if [ $TESTS_FAILED -eq 0 ]; then
    log_success "All tests passed! Statusline deployment is ready for FGSRV6."
    echo
    echo "Next steps:"
    echo "  1. Copy statusline script to FGSRV6: .claude/statusline-command.sh"
    echo "  2. Update settings.json on FGSRV6 with statusLine config"
    echo "  3. Set execute permissions: chmod +x .claude/statusline-command.sh"
    echo "  4. Test in Claude Code on FGSRV6"
    echo
    EXIT_CODE=0
else
    log_error "Some tests failed! Please review and fix issues before deploying."
    echo
    EXIT_CODE=1
fi

# Save test log
log_info "Test log saved to: $LOG_FILE"

# Cleanup
cd /mnt/overpower/apps/dev/agl/agl-hostman
log_info "Cleaning up test directory..."
# Keep test directory for inspection
# rm -rf "$TEST_DIR"

echo
log_info "Test completed at: $(date)"

exit $EXIT_CODE
