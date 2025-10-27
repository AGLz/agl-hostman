#!/bin/bash
# Ollama Models Backup Script for CT200
# Backs up Ollama models to specified location with rotation

set -euo pipefail

# Configuration
CT_ID=200
HOST="192.168.0.245"
SOURCE_DIR="/usr/share/ollama/.ollama/models"
BACKUP_BASE="/mnt/pve/ct111-shares/backups/ollama-ct200"
RETENTION_DAYS=30
LOG_FILE="/var/log/ollama-backup.log"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a ${LOG_FILE}
}

# Error handler
error_exit() {
    echo -e "${RED}ERROR: $1${NC}" >&2
    log "ERROR: $1"
    exit 1
}

# Check if running as root or with sudo
if [[ $EUID -ne 0 ]] && [[ -z "${SUDO_USER:-}" ]]; then
   error_exit "This script must be run as root or with sudo"
fi

# Create backup directory if it doesn't exist
if ! ssh root@${HOST} "test -d ${BACKUP_BASE}"; then
    log "Creating backup directory: ${BACKUP_BASE}"
    ssh root@${HOST} "mkdir -p ${BACKUP_BASE}" || error_exit "Failed to create backup directory"
fi

# Generate backup name with timestamp
BACKUP_DATE=$(date '+%Y%m%d-%H%M%S')
BACKUP_DIR="${BACKUP_BASE}/${BACKUP_DATE}"

echo -e "${GREEN}═══════════════════════════════════════════${NC}"
echo -e "${GREEN}  Ollama Models Backup - CT200${NC}"
echo -e "${GREEN}═══════════════════════════════════════════${NC}"
echo ""

# Get source directory size
log "Calculating source directory size..."
SOURCE_SIZE=$(ssh root@${HOST} "pct exec ${CT_ID} -- du -sh ${SOURCE_DIR} 2>/dev/null | cut -f1" || echo "unknown")
echo -e "Source size: ${YELLOW}${SOURCE_SIZE}${NC}"

# Get available disk space
AVAIL_SPACE=$(ssh root@${HOST} "df -h ${BACKUP_BASE} | tail -1 | awk '{print \$4}'")
echo -e "Available space: ${YELLOW}${AVAIL_SPACE}${NC}"
echo ""

# List models to backup
log "Listing models to backup..."
echo "Models to backup:"
ssh root@${HOST} "pct exec ${CT_ID} -- ollama list" || error_exit "Failed to list models"
echo ""

# Confirm backup
read -p "Proceed with backup? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    log "Backup cancelled by user"
    exit 0
fi

# Create backup
log "Starting backup to: ${BACKUP_DIR}"
echo -e "${YELLOW}Creating backup...${NC}"

# Method 1: Direct rsync (faster)
if command -v rsync &> /dev/null; then
    log "Using rsync for backup"
    ssh root@${HOST} "pct exec ${CT_ID} -- bash -c 'mkdir -p /tmp/ollama-backup && rsync -a ${SOURCE_DIR}/ /tmp/ollama-backup/'" || error_exit "Failed to prepare backup"
    ssh root@${HOST} "mkdir -p ${BACKUP_DIR} && pct exec ${CT_ID} -- bash -c 'tar czf - -C /tmp/ollama-backup .' | tar xzf - -C ${BACKUP_DIR}" || error_exit "Failed to create backup"
    ssh root@${HOST} "pct exec ${CT_ID} -- rm -rf /tmp/ollama-backup"
else
    # Method 2: Tar only (slower but always available)
    log "Using tar for backup"
    ssh root@${HOST} "mkdir -p ${BACKUP_DIR} && pct exec ${CT_ID} -- tar czf - -C ${SOURCE_DIR} . | tar xzf - -C ${BACKUP_DIR}" || error_exit "Failed to create backup"
fi

# Get backup size
BACKUP_SIZE=$(ssh root@${HOST} "du -sh ${BACKUP_DIR} | cut -f1")
log "Backup completed: ${BACKUP_SIZE}"
echo -e "${GREEN}✓ Backup completed: ${BACKUP_SIZE}${NC}"

# Create metadata file
log "Creating backup metadata"
ssh root@${HOST} "cat > ${BACKUP_DIR}/backup-info.txt << EOF
Backup Date: $(date '+%Y-%m-%d %H:%M:%S')
Source: CT${CT_ID}:${SOURCE_DIR}
Backup Size: ${BACKUP_SIZE}
Models Backed Up:
$(ssh root@${HOST} "pct exec ${CT_ID} -- ollama list" | tail -n +2)
EOF"

# Create restore script
log "Creating restore script"
ssh root@${HOST} "cat > ${BACKUP_DIR}/restore.sh << 'EOFSCRIPT'
#!/bin/bash
# Restore script for Ollama models backup

set -euo pipefail

CT_ID=200
HOST=\"192.168.0.245\"
BACKUP_DIR=\"\$(cd \"\$(dirname \"\${BASH_SOURCE[0]}\")\" && pwd)\"
TARGET_DIR=\"/usr/share/ollama/.ollama/models\"

echo \"Restoring Ollama models from: \${BACKUP_DIR}\"
echo \"Target: CT\${CT_ID}:\${TARGET_DIR}\"
echo \"\"
read -p \"This will overwrite existing models. Continue? (y/N): \" -n 1 -r
echo
if [[ ! \$REPLY =~ ^[Yy]$ ]]; then
    echo \"Restore cancelled\"
    exit 0
fi

echo \"Stopping Ollama service...\"
ssh root@\${HOST} \"pct exec \${CT_ID} -- systemctl stop ollama\"

echo \"Backing up current models...\"
ssh root@\${HOST} \"pct exec \${CT_ID} -- mv \${TARGET_DIR} \${TARGET_DIR}.bak-\$(date +%s)\"

echo \"Restoring models...\"
ssh root@\${HOST} \"pct exec \${CT_ID} -- mkdir -p \${TARGET_DIR}\"
ssh root@\${HOST} \"tar czf - -C \${BACKUP_DIR} . | pct exec \${CT_ID} -- tar xzf - -C \${TARGET_DIR}\"

echo \"Starting Ollama service...\"
ssh root@\${HOST} \"pct exec \${CT_ID} -- systemctl start ollama\"

echo \"Restore completed!\"
echo \"Verify models with: ssh root@\${HOST} 'pct exec \${CT_ID} -- ollama list'\"
EOFSCRIPT
chmod +x ${BACKUP_DIR}/restore.sh"

log "Restore script created: ${BACKUP_DIR}/restore.sh"

# Cleanup old backups
log "Cleaning up old backups (retention: ${RETENTION_DAYS} days)"
OLD_BACKUPS=$(ssh root@${HOST} "find ${BACKUP_BASE} -maxdepth 1 -type d -mtime +${RETENTION_DAYS} ! -path ${BACKUP_BASE}" || true)

if [[ -n "${OLD_BACKUPS}" ]]; then
    echo ""
    echo "Old backups to remove:"
    echo "${OLD_BACKUPS}"
    REMOVED=0
    while IFS= read -r backup; do
        ssh root@${HOST} "rm -rf ${backup}"
        log "Removed old backup: ${backup}"
        ((REMOVED++))
    done <<< "${OLD_BACKUPS}"
    echo -e "${GREEN}✓ Removed ${REMOVED} old backup(s)${NC}"
else
    echo -e "${GREEN}✓ No old backups to remove${NC}"
fi

# Summary
echo ""
echo -e "${GREEN}═══════════════════════════════════════════${NC}"
echo -e "${GREEN}  Backup Summary${NC}"
echo -e "${GREEN}═══════════════════════════════════════════${NC}"
echo -e "Backup Location: ${YELLOW}${BACKUP_DIR}${NC}"
echo -e "Backup Size:     ${YELLOW}${BACKUP_SIZE}${NC}"
echo -e "Source Size:     ${YELLOW}${SOURCE_SIZE}${NC}"
echo -e "Restore Script:  ${YELLOW}${BACKUP_DIR}/restore.sh${NC}"
echo ""

# List all backups
echo "All backups:"
ssh root@${HOST} "ls -lh ${BACKUP_BASE} | tail -n +2"

log "Backup completed successfully"
echo -e "${GREEN}✓ Backup completed successfully${NC}"
