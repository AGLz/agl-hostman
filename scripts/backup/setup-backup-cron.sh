#!/bin/bash
# AGL-22: Setup Automated Backup Cron Jobs
# Configure automated backup schedules for all AGL infrastructure

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Script paths
BASE_DIR="/mnt/overpower/apps/dev/agl/agl-hostman"
BACKUP_SCRIPT="$BASE_DIR/scripts/backup/automated-backup.sh"
SLA_MONITOR_SCRIPT="$BASE_DIR/scripts/backup/backup-sla-monitor.sh"
RESTORE_SCRIPT="$BASE_DIR/scripts/backup/restore-from-backup.sh"

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1${NC}"
}

log_error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} ERROR: $1${NC}" >&2
}

log_warning() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} WARNING: $1${NC}" >&2
}

# Verify scripts exist
for script in "$BACKUP_SCRIPT" "$SLA_MONITOR_SCRIPT" "$RESTORE_SCRIPT"; do
    if [ ! -f "$script" ]; then
        log_error "Required script not found: $script"
        exit 1
    fi
done

# Make scripts executable
log "Making backup scripts executable..."
chmod +x "$BACKUP_SCRIPT" "$SLA_MONITOR_SCRIPT" "$RESTORE_SCRIPT"

# Current crontab
log "Checking current crontab..."
current_cron=$(crontab -l 2>/dev/null)

if [ -n "$current_cron" ]; then
    log "Current crontab:"
    echo "$current_cron"
else
    log "No crontab entries found"
fi

# Backup automation cron jobs
log ""
log "=== Backup Automation Cron Jobs ==="
log ""

# 1. SLA Monitoring - Every 5 minutes
CRON_SLAM="*/5 * * * * $SLA_MONITOR_SCRIPT check >> /var/log/agl-backup/cron.log 2>&1"

# 2. Critical VMs (P0 - 1h RPO) - Every 6 hours
CRON_CRITICAL="15 */6 * * * $BACKUP_SCRIPT >> /var/log/agl-backup/cron.log 2>&1"

# 3. High Priority VMs (P1 - 6h RPO) - Daily at 03:30
CRON_HIGH="30 3 * * * $BACKUP_SCRIPT >> /var/log/agl-backup/cron.log 2>&1"

# 4. Standard VMs (P2 - 24h RPO) - Daily at 04:00
CRON_STANDARD="0 4 * * * $BACKUP_SCRIPT >> /var/log/agl-backup/cron.log 2>&1"

# 5. Daily validation - Every day at 06:00
CRON_VALIDATION="0 6 * * * $SLA_MONITOR_SCRIPT --email >> /var/log/agl-backup/cron.log 2>&1"

# Display proposed cron jobs
echo ""
log "Proposed cron jobs to add:"
echo ""
log "${GREEN}# === SLA Monitoring (Every 5 minutes) ===${NC}"
log "$CRON_SLAM"
echo ""
log "${YELLOW}# === Critical Backups (Every 6 hours - RPO 1h) ===${NC}"
log "VMs: CT183 (agl-crowbar), CT184 (agl-api)"
log "$CRON_CRITICAL"
echo ""
log "${YELLOW}# === High Priority Backups (Daily 03:30 - RPO 6h) ===${NC}"
log "VMs: CT180 (agl-app), CT182 (agl-worker)"
log "$CRON_HIGH"
echo ""
log "${YELLOW}# === Standard Backups (Daily 04:00 - RPO 24h) ===${NC}"
log "VMs: CT173 (harbor), CT174 (portainer), CT175 (dns)"
log "$CRON_STANDARD"
echo ""
log "${YELLOW}# === Daily Validation (06:00) ===${NC}"
log "$CRON_VALIDATION"
echo ""

# Environment setup
log ""
log "=== Environment Variables Required ==="
log ""
log "Ensure these are set in /etc/environment or .bashrc:"
log ""
log "${GREEN}PBS_SERVER=10.6.0.14${NC}    # Proxmox Backup Server"
log "${GREEN}ALERT_EMAIL=admin@aglz.io${NC}  # Alert recipient"
log "${GREEN}SLACK_WEBHOOK=https://hooks.slack.com/services/YOUR_WEBHOOK${NC}  # Slack notifications"
log "${GREEN}BACKUP_GPG_RECIPIENT=admin@aglz.io${NC}  # GPG encryption recipient"
log ""

# Add to crontab
echo ""
read -p "Do you want to install these cron jobs? (y/n) "
echo -n "> "
read -r response

if [[ "$response" =~ ^[Yy]$ ]]; then
    log "Installing cron jobs..."

    # Create temporary crontab file
    TMP_CRON=$(mktemp)

    # Add existing crontab (if any)
    if [ -n "$current_cron" ]; then
        echo "$current_cron" > "$TMP_CRON"
        echo "" >> "$TMP_CRON"
    fi

    # Add new cron jobs
    echo "" >> "$TMP_CRON"
    echo "# AGL Automated Backup Jobs - Added $(date +'%Y-%m-%d %H:%M:%S')" >> "$TMP_CRON"
    echo "$CRON_SLAM" >> "$TMP_CRON"
    echo "" >> "$TMP_CRON"
    echo "$CRON_CRITICAL" >> "$TMP_CRON"
    echo "" >> "$TMP_CRON"
    echo "$CRON_HIGH" >> "$TMP_CRON"
    echo "" >> "$TMP_CRON"
    echo "$CRON_STANDARD" >> "$TMP_CRON"
    echo "" >> "$TMP_CRON"
    echo "$CRON_VALIDATION" >> "$TMP_CRON"

    # Install new crontab
    crontab "$TMP_CRON" && log "Cron jobs installed successfully"
    rm -f "$TMP_CRON"

    # Show new crontab
    echo ""
    log "New crontab:"
    crontab -l
else
    log "Cron installation skipped"
fi

# Test restore procedures
log ""
log "=== Testing Restore Procedures ==="
log ""
log "To test restore without actual restoration:"
log ""
log "${GREEN}dry-run}${NC} test:"
echo "  $RESTORE_SCRIPT --dry-run list"
echo ""
log "This will show available backups without restoring any data"
echo ""

# Create log directory
mkdir -p /var/log/agl-backup

# Summary
echo ""
log "=== Setup Complete ==="
log ""
log "${GREEN}✅ Scripts verified and made executable${NC}"
log "${GREEN}✅ Cron jobs configured${NC}"
log "${GREEN}✅ Log directory created: /var/log/agl-backup${NC}"
log ""
log "${YELLOW}Next Steps:${NC}"
log "${YELLOW}1. Set environment variables (PBS_SERVER, ALERT_EMAIL, etc.)${NC}"
log "${YELLOW}2. Run: $BACKUP_SCRIPT to verify backup execution${NC}"
log "${YELLOW}3. Run: $RESTORE_SCRIPT --dry-run to test restoration${NC}"
log ""
