#!/bin/bash
# Rollback Procedure for Statusline on FGSRV6
# Restores previous version if deployment fails

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
BACKUP_DIR="$TARGET_DIR/backups"

echo -e "${BLUE}=== STATUSLINE ROLLBACK PROCEDURE ===${NC}\n"

# Step 1: List available backups
echo -e "${YELLOW}[1/4] Checking for available backups...${NC}"
BACKUPS=$(ssh "$TARGET_USER@$TARGET_HOST" "ls -1t $BACKUP_DIR/statusline-command.sh.* 2>/dev/null" || echo "")

if [ -z "$BACKUPS" ]; then
    echo -e "${RED}✗ No backups found${NC}"
    echo -e "${YELLOW}Cannot rollback - no previous version available${NC}"
    exit 1
fi

echo -e "${GREEN}Available backups:${NC}"
echo "$BACKUPS" | nl

# Step 2: Select most recent backup
LATEST_BACKUP=$(echo "$BACKUPS" | head -n1)
echo -e "\n${YELLOW}[2/4] Selected backup: $(basename $LATEST_BACKUP)${NC}"

# Step 3: Verify backup integrity
echo -e "\n${YELLOW}[3/4] Verifying backup integrity...${NC}"
BACKUP_SIZE=$(ssh "$TARGET_USER@$TARGET_HOST" "stat -c%s $LATEST_BACKUP 2>/dev/null")
if [ -z "$BACKUP_SIZE" ] || [ "$BACKUP_SIZE" -eq 0 ]; then
    echo -e "${RED}✗ Backup file is invalid (size: ${BACKUP_SIZE})${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Backup is valid (${BACKUP_SIZE} bytes)${NC}"

# Step 4: Restore backup
echo -e "\n${YELLOW}[4/4] Restoring backup...${NC}"

# Create safety backup of current version
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
ssh "$TARGET_USER@$TARGET_HOST" "
    if [ -f $TARGET_DIR/statusline-command.sh ]; then
        cp $TARGET_DIR/statusline-command.sh $BACKUP_DIR/statusline-command.sh.failed.$TIMESTAMP
        echo 'Current (failed) version backed up as statusline-command.sh.failed.$TIMESTAMP'
    fi
"

# Restore from backup
ssh "$TARGET_USER@$TARGET_HOST" "cp $LATEST_BACKUP $TARGET_DIR/statusline-command.sh"
ssh "$TARGET_USER@$TARGET_HOST" "chmod +x $TARGET_DIR/statusline-command.sh"

# Verify restoration
RESTORED_SIZE=$(ssh "$TARGET_USER@$TARGET_HOST" "stat -c%s $TARGET_DIR/statusline-command.sh")
if [ "$RESTORED_SIZE" -eq "$BACKUP_SIZE" ]; then
    echo -e "${GREEN}✓ Rollback successful${NC}"
else
    echo -e "${RED}✗ Rollback verification failed${NC}"
    exit 1
fi

# Test restored version
echo -e "\n${YELLOW}Testing restored version...${NC}"
TEST_INPUT='{"model":{"display_name":"Claude"},"workspace":{"current_dir":"/root"},"cwd":"/root"}'
if ssh "$TARGET_USER@$TARGET_HOST" "echo '$TEST_INPUT' | $TARGET_DIR/statusline-command.sh" > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Restored version is functional${NC}"
else
    echo -e "${RED}✗ WARNING: Restored version may have issues${NC}"
fi

# Summary
echo -e "\n${BLUE}=== ROLLBACK COMPLETE ===${NC}"
echo -e "${GREEN}✓ Previous version restored successfully${NC}"
echo -e "\nRollback details:"
echo -e "  Restored from: $(basename $LATEST_BACKUP)"
echo -e "  Current version saved as: statusline-command.sh.failed.$TIMESTAMP"
echo -e "  File size: $RESTORED_SIZE bytes"

exit 0
