#!/bin/bash
# Pre-Deployment Verification Script for Statusline on FGSRV6
# Tests network connectivity, SSH access, and prerequisites

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
STATUSLINE_SOURCE="/mnt/overpower/apps/dev/agl/agl-hostman/.claude/statusline-command.sh"
TARGET_DIR="/root/.claude"

echo -e "${BLUE}=== PRE-DEPLOYMENT VERIFICATION FOR FGSRV6 ===${NC}\n"

# Test 1: Network Connectivity
echo -e "${YELLOW}[1/7] Testing network connectivity...${NC}"
if ping -c 3 -W 5 "$TARGET_HOST" > /dev/null 2>&1; then
    echo -e "${GREEN}✓ FGSRV6 is reachable at $TARGET_HOST${NC}"
else
    echo -e "${RED}✗ FAILED: Cannot reach $TARGET_HOST${NC}"
    exit 1
fi

# Test 2: SSH Connectivity
echo -e "\n${YELLOW}[2/7] Testing SSH connectivity...${NC}"
if ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no "$TARGET_USER@$TARGET_HOST" "echo 'SSH test successful'" > /dev/null 2>&1; then
    echo -e "${GREEN}✓ SSH connection successful${NC}"
else
    echo -e "${RED}✗ FAILED: Cannot establish SSH connection${NC}"
    exit 1
fi

# Test 3: Check target hostname
echo -e "\n${YELLOW}[3/7] Verifying target hostname...${NC}"
HOSTNAME=$(ssh -o StrictHostKeyChecking=no "$TARGET_USER@$TARGET_HOST" "hostname" 2>/dev/null)
echo -e "${GREEN}✓ Connected to host: $HOSTNAME${NC}"

# Test 4: Check local statusline exists
echo -e "\n${YELLOW}[4/7] Checking local statusline script...${NC}"
if [ -f "$STATUSLINE_SOURCE" ]; then
    SIZE=$(stat -c%s "$STATUSLINE_SOURCE")
    PERMS=$(stat -c%a "$STATUSLINE_SOURCE")
    echo -e "${GREEN}✓ Statusline found: $STATUSLINE_SOURCE${NC}"
    echo -e "  Size: ${SIZE} bytes, Permissions: ${PERMS}"
else
    echo -e "${RED}✗ FAILED: Source statusline not found at $STATUSLINE_SOURCE${NC}"
    exit 1
fi

# Test 5: Check dependencies on target
echo -e "\n${YELLOW}[5/7] Checking dependencies on target system...${NC}"

# Check jq
if ssh "$TARGET_USER@$TARGET_HOST" "which jq > /dev/null 2>&1"; then
    JQ_VERSION=$(ssh "$TARGET_USER@$TARGET_HOST" "jq --version 2>&1")
    echo -e "${GREEN}✓ jq is installed: $JQ_VERSION${NC}"
else
    echo -e "${RED}✗ WARNING: jq not found on target system${NC}"
    echo -e "  ${YELLOW}Install with: apt-get install -y jq${NC}"
fi

# Check git
if ssh "$TARGET_USER@$TARGET_HOST" "which git > /dev/null 2>&1"; then
    GIT_VERSION=$(ssh "$TARGET_USER@$TARGET_HOST" "git --version 2>&1")
    echo -e "${GREEN}✓ git is installed: $GIT_VERSION${NC}"
else
    echo -e "${YELLOW}⚠ git not found (optional for branch display)${NC}"
fi

# Test 6: Check target directory
echo -e "\n${YELLOW}[6/7] Checking target directory...${NC}"
if ssh "$TARGET_USER@$TARGET_HOST" "[ -d $TARGET_DIR ]"; then
    echo -e "${GREEN}✓ Target directory exists: $TARGET_DIR${NC}"
else
    echo -e "${YELLOW}⚠ Target directory does not exist, will be created${NC}"
fi

# Test 7: Check for existing statusline
echo -e "\n${YELLOW}[7/7] Checking for existing statusline...${NC}"
if ssh "$TARGET_USER@$TARGET_HOST" "[ -f $TARGET_DIR/statusline-command.sh ]"; then
    EXISTING_SIZE=$(ssh "$TARGET_USER@$TARGET_HOST" "stat -c%s $TARGET_DIR/statusline-command.sh 2>/dev/null")
    echo -e "${YELLOW}⚠ Existing statusline found (${EXISTING_SIZE} bytes)${NC}"
    echo -e "  ${BLUE}Backup will be created during deployment${NC}"
else
    echo -e "${GREEN}✓ No existing statusline (clean deployment)${NC}"
fi

# Summary
echo -e "\n${BLUE}=== PRE-DEPLOYMENT SUMMARY ===${NC}"
echo -e "${GREEN}✓ All critical checks passed${NC}"
echo -e "${YELLOW}ℹ Ready for deployment to FGSRV6${NC}"
echo -e "\nNext step: Run deployment script"

exit 0
