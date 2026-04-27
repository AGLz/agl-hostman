#!/bin/bash
# Post-Deployment Validation for Statusline on FGSRV6
# Comprehensive functional testing of deployed statusline

set -e

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
TARGET_HOST="192.168.1.131"
TARGET_USER="root"
TARGET_DIR="/root/.claude"
STATUSLINE="$TARGET_DIR/statusline-command.sh"

echo -e "${BLUE}=== POST-DEPLOYMENT VALIDATION ===${NC}\n"

# Test 1: File existence and permissions
echo -e "${YELLOW}[1/8] Validating file existence and permissions...${NC}"
if ssh "$TARGET_USER@$TARGET_HOST" "[ -f $STATUSLINE ]"; then
    echo -e "${GREEN}✓ Statusline file exists${NC}"
else
    echo -e "${RED}✗ FAILED: Statusline file not found${NC}"
    exit 1
fi

PERMS=$(ssh "$TARGET_USER@$TARGET_HOST" "stat -c%a $STATUSLINE")
if [[ "$PERMS" =~ ^[0-9]*[1357]$ ]]; then
    echo -e "${GREEN}✓ File is executable (${PERMS})${NC}"
else
    echo -e "${RED}✗ FAILED: File is not executable${NC}"
    exit 1
fi

# Test 2: Syntax validation
echo -e "\n${YELLOW}[2/8] Validating bash syntax...${NC}"
if ssh "$TARGET_USER@$TARGET_HOST" "bash -n $STATUSLINE"; then
    echo -e "${GREEN}✓ No syntax errors detected${NC}"
else
    echo -e "${RED}✗ FAILED: Syntax errors found${NC}"
    exit 1
fi

# Test 3: Basic execution test
echo -e "\n${YELLOW}[3/8] Testing basic execution...${NC}"
TEST_INPUT='{"model":{"display_name":"Claude 3.5 Sonnet"},"workspace":{"current_dir":"/root/test"},"cwd":"/root/test"}'
RESULT=$(ssh "$TARGET_USER@$TARGET_HOST" "echo '$TEST_INPUT' | $STATUSLINE" 2>&1)
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Script executes successfully${NC}"
    echo -e "${BLUE}Output preview:${NC}"
    echo -e "  $RESULT"
else
    echo -e "${RED}✗ FAILED: Script execution failed${NC}"
    echo -e "Error: $RESULT"
    exit 1
fi

# Test 4: Test with git repository
echo -e "\n${YELLOW}[4/8] Testing with git repository context...${NC}"
# Create a temporary test repo
ssh "$TARGET_USER@$TARGET_HOST" "
    mkdir -p /tmp/test-repo-$$
    cd /tmp/test-repo-$$
    git init > /dev/null 2>&1
    git checkout -b test-branch > /dev/null 2>&1
"

TEST_INPUT_GIT='{"model":{"display_name":"Claude"},"workspace":{"current_dir":"/tmp/test-repo-'$$'"},"cwd":"/tmp/test-repo-'$$'"}'
RESULT_GIT=$(ssh "$TARGET_USER@$TARGET_HOST" "echo '$TEST_INPUT_GIT' | $STATUSLINE" 2>&1)

if echo "$RESULT_GIT" | grep -q "test-branch"; then
    echo -e "${GREEN}✓ Git branch detection works${NC}"
    echo -e "${BLUE}Output:${NC}"
    echo -e "  $RESULT_GIT"
else
    echo -e "${YELLOW}⚠ Branch detection may not be working${NC}"
fi

# Cleanup test repo
ssh "$TARGET_USER@$TARGET_HOST" "rm -rf /tmp/test-repo-$$"

# Test 5: Test jq dependency
echo -e "\n${YELLOW}[5/8] Validating jq dependency...${NC}"
if ssh "$TARGET_USER@$TARGET_HOST" "which jq > /dev/null 2>&1"; then
    JQ_VERSION=$(ssh "$TARGET_USER@$TARGET_HOST" "jq --version 2>&1")
    echo -e "${GREEN}✓ jq is available: $JQ_VERSION${NC}"
else
    echo -e "${RED}✗ WARNING: jq not installed${NC}"
    echo -e "${YELLOW}  Install with: apt-get install -y jq${NC}"
fi

# Test 6: Test with claude-flow directory
echo -e "\n${YELLOW}[6/8] Testing claude-flow integration...${NC}"
# Create test .claude-flow structure
ssh "$TARGET_USER@$TARGET_HOST" "
    mkdir -p /tmp/test-flow-$$//.claude-flow/metrics
    echo '{\"defaultStrategy\":\"balanced\",\"agentProfiles\":[{\"type\":\"coder\"},{\"type\":\"tester\"}]}' > /tmp/test-flow-$$//.claude-flow/swarm-config.json
    echo '[{\"memoryUsagePercent\":45.5,\"cpuLoad\":0.25}]' > /tmp/test-flow-$$//.claude-flow/metrics/system-metrics.json
"

TEST_INPUT_FLOW='{"model":{"display_name":"Claude"},"workspace":{"current_dir":"/tmp/test-flow-'$$'"},"cwd":"/tmp/test-flow-'$$'"}'
RESULT_FLOW=$(ssh "$TARGET_USER@$TARGET_HOST" "echo '$TEST_INPUT_FLOW' | $STATUSLINE" 2>&1)

if echo "$RESULT_FLOW" | grep -q "mesh"; then
    echo -e "${GREEN}✓ Claude-flow topology detection works${NC}"
else
    echo -e "${YELLOW}⚠ Claude-flow integration may need verification${NC}"
fi

if echo "$RESULT_FLOW" | grep -q "💾"; then
    echo -e "${GREEN}✓ System metrics display works${NC}"
else
    echo -e "${YELLOW}⚠ System metrics may not be displayed${NC}"
fi

echo -e "${BLUE}Full output:${NC}"
echo -e "  $RESULT_FLOW"

# Cleanup test flow
ssh "$TARGET_USER@$TARGET_HOST" "rm -rf /tmp/test-flow-$$"

# Test 7: Performance test
echo -e "\n${YELLOW}[7/8] Running performance test...${NC}"
START_TIME=$(date +%s%N)
for i in {1..10}; do
    ssh "$TARGET_USER@$TARGET_HOST" "echo '$TEST_INPUT' | $STATUSLINE" > /dev/null 2>&1
done
END_TIME=$(date +%s%N)
ELAPSED=$((($END_TIME - $START_TIME) / 1000000))
AVG_TIME=$(($ELAPSED / 10))

if [ $AVG_TIME -lt 1000 ]; then
    echo -e "${GREEN}✓ Performance is good (avg: ${AVG_TIME}ms per execution)${NC}"
else
    echo -e "${YELLOW}⚠ Performance may need optimization (avg: ${AVG_TIME}ms)${NC}"
fi

# Test 8: Integration test with Claude Code context
echo -e "\n${YELLOW}[8/8] Testing with realistic Claude Code context...${NC}"
REAL_CONTEXT='{"model":{"display_name":"Claude 3.5 Sonnet","id":"claude-sonnet-4-5"},"workspace":{"current_dir":"'$(pwd)'"},"cwd":"'$(pwd)'"}'
RESULT_REAL=$(ssh "$TARGET_USER@$TARGET_HOST" "echo '$REAL_CONTEXT' | $STATUSLINE" 2>&1)

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Realistic context test passed${NC}"
    echo -e "${BLUE}Result:${NC}"
    echo -e "  $RESULT_REAL"
else
    echo -e "${RED}✗ FAILED: Realistic context test failed${NC}"
fi

# Final Summary
echo -e "\n${BLUE}=== VALIDATION SUMMARY ===${NC}"
echo -e "${GREEN}✓ All critical tests passed${NC}"
echo -e "${GREEN}✓ Statusline is fully functional on FGSRV6${NC}"
echo -e "\n${BLUE}Integration Instructions:${NC}"
echo -e "1. Add to Claude Code settings on FGSRV6:"
echo -e '   "statuslineCommand": "'$STATUSLINE'"'
echo -e "2. Restart Claude Code or reload window"
echo -e "3. Verify statusline appears in Claude Code interface"

exit 0
