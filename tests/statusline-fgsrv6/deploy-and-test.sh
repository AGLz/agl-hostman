#!/bin/bash
# Deployment and Testing Script for Statusline on FGSRV6
# Deploys statusline with backup, then validates functionality

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
BACKUP_DIR="$TARGET_DIR/backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

echo -e "${BLUE}=== STATUSLINE DEPLOYMENT TO FGSRV6 ===${NC}\n"

# Step 1: Create backup directory
echo -e "${YELLOW}[1/6] Creating backup directory...${NC}"
ssh "$TARGET_USER@$TARGET_HOST" "mkdir -p $BACKUP_DIR"
echo -e "${GREEN}✓ Backup directory ready${NC}"

# Step 2: Backup existing statusline (if exists)
echo -e "\n${YELLOW}[2/6] Backing up existing statusline...${NC}"
if ssh "$TARGET_USER@$TARGET_HOST" "[ -f $TARGET_DIR/statusline-command.sh ]"; then
    ssh "$TARGET_USER@$TARGET_HOST" "cp $TARGET_DIR/statusline-command.sh $BACKUP_DIR/statusline-command.sh.$TIMESTAMP"
    echo -e "${GREEN}✓ Backup created: statusline-command.sh.$TIMESTAMP${NC}"
else
    echo -e "${YELLOW}⚠ No existing statusline to backup${NC}"
fi

# Step 3: Create target directory
echo -e "\n${YELLOW}[3/6] Ensuring target directory exists...${NC}"
ssh "$TARGET_USER@$TARGET_HOST" "mkdir -p $TARGET_DIR"
echo -e "${GREEN}✓ Target directory ready: $TARGET_DIR${NC}"

# Step 4: Copy statusline script
echo -e "\n${YELLOW}[4/6] Copying statusline script...${NC}"
scp -q "$STATUSLINE_SOURCE" "$TARGET_USER@$TARGET_HOST:$TARGET_DIR/statusline-command.sh"
echo -e "${GREEN}✓ Statusline copied successfully${NC}"

# Step 5: Set permissions
echo -e "\n${YELLOW}[5/6] Setting permissions...${NC}"
ssh "$TARGET_USER@$TARGET_HOST" "chmod +x $TARGET_DIR/statusline-command.sh"
echo -e "${GREEN}✓ Execute permissions set${NC}"

# Step 6: Verify deployment
echo -e "\n${YELLOW}[6/6] Verifying deployment...${NC}"

# Check file exists
if ! ssh "$TARGET_USER@$TARGET_HOST" "[ -f $TARGET_DIR/statusline-command.sh ]"; then
    echo -e "${RED}✗ FAILED: Statusline file not found on target${NC}"
    exit 1
fi

# Check file size matches
LOCAL_SIZE=$(stat -c%s "$STATUSLINE_SOURCE")
REMOTE_SIZE=$(ssh "$TARGET_USER@$TARGET_HOST" "stat -c%s $TARGET_DIR/statusline-command.sh")

if [ "$LOCAL_SIZE" -eq "$REMOTE_SIZE" ]; then
    echo -e "${GREEN}✓ File size matches (${LOCAL_SIZE} bytes)${NC}"
else
    echo -e "${RED}✗ WARNING: File size mismatch!${NC}"
    echo -e "  Local: ${LOCAL_SIZE} bytes"
    echo -e "  Remote: ${REMOTE_SIZE} bytes"
fi

# Check MD5 checksum
LOCAL_MD5=$(md5sum "$STATUSLINE_SOURCE" | awk '{print $1}')
REMOTE_MD5=$(ssh "$TARGET_USER@$TARGET_HOST" "md5sum $TARGET_DIR/statusline-command.sh" | awk '{print $1}')

if [ "$LOCAL_MD5" = "$REMOTE_MD5" ]; then
    echo -e "${GREEN}✓ MD5 checksum matches${NC}"
    echo -e "  ${LOCAL_MD5}"
else
    echo -e "${RED}✗ FAILED: MD5 checksum mismatch!${NC}"
    echo -e "  Local:  ${LOCAL_MD5}"
    echo -e "  Remote: ${REMOTE_MD5}"
    exit 1
fi

# Check executable bit
PERMS=$(ssh "$TARGET_USER@$TARGET_HOST" "stat -c%a $TARGET_DIR/statusline-command.sh")
if [[ "$PERMS" =~ ^[0-9]*[1357]$ ]]; then
    echo -e "${GREEN}✓ Execute permissions verified (${PERMS})${NC}"
else
    echo -e "${RED}✗ WARNING: File is not executable${NC}"
fi

# Success summary
echo -e "\n${BLUE}=== DEPLOYMENT COMPLETE ===${NC}"
echo -e "${GREEN}✓ Statusline successfully deployed to FGSRV6${NC}"
echo -e "\nDeployment details:"
echo -e "  Target host: $TARGET_HOST"
echo -e "  Target path: $TARGET_DIR/statusline-command.sh"
echo -e "  File size: $REMOTE_SIZE bytes"
echo -e "  MD5: $REMOTE_MD5"
echo -e "  Backup: $BACKUP_DIR/statusline-command.sh.$TIMESTAMP"

exit 0
