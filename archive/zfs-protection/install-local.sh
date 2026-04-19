#!/bin/bash
#
# ZFS Protection Suite - Local Installation Script
# For direct installation on Proxmox server when remote access is unavailable
#

set -euo pipefail

INSTALL_DIR="/opt/zfs-protection"
LOG_DIR="/var/log/zfs-protection"
CONFIG_DIR="/etc/zfs-protection"
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

echo "🛡️ ZFS Data Corruption Prevention Suite - Local Installer"
echo "========================================================="
echo ""

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}✅${NC} $1"
}

print_error() {
    echo -e "${RED}❌${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠️${NC} $1"
}

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   print_error "This script must be run as root"
   exit 1
fi

# Check if ZFS is available
echo "🔍 Checking system requirements..."
if ! command -v zpool &> /dev/null; then
    print_error "ZFS not found! Please install ZFS first."
    exit 1
fi

# Check if running on Proxmox
if ! command -v pvesm &> /dev/null; then
    print_warning "Proxmox VE not detected. Some features may not work correctly."
    read -p "Continue anyway? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

print_status "System requirements met"

# Create directory structure
echo ""
echo "📁 Creating directory structure..."
mkdir -p "$INSTALL_DIR"/{scripts,configs,templates,docs}
mkdir -p "$LOG_DIR"
mkdir -p "$CONFIG_DIR"
print_status "Directories created"

# Install required packages
echo ""
echo "📦 Installing required packages..."
apt-get update > /dev/null 2>&1
PACKAGES="smartmontools mailutils curl jq bc moreutils"
MISSING_PACKAGES=""

for package in $PACKAGES; do
    if ! dpkg -l | grep -q "^ii  $package"; then
        MISSING_PACKAGES="$MISSING_PACKAGES $package"
    fi
done

if [ -n "$MISSING_PACKAGES" ]; then
    echo "Installing:$MISSING_PACKAGES"
    apt-get install -y $MISSING_PACKAGES > /dev/null 2>&1
    print_status "Packages installed"
else
    print_status "All required packages already installed"
fi

# Copy scripts
echo ""
echo "📋 Installing ZFS protection scripts..."
cp -r "$SCRIPT_DIR/scripts/"* "$INSTALL_DIR/scripts/" 2>/dev/null || true
cp -r "$SCRIPT_DIR/configs/"* "$CONFIG_DIR/" 2>/dev/null || true
cp -r "$SCRIPT_DIR/docs/"* "$INSTALL_DIR/docs/" 2>/dev/null || true
chmod +x "$INSTALL_DIR/scripts/"*.sh
print_status "Scripts installed"

# Install systemd services
echo ""
echo "⚙️ Setting up systemd services..."

# ZFS Health Monitor Service
cat > /etc/systemd/system/zfs-health-monitor.service << 'EOF'
[Unit]
Description=ZFS Health Monitor
After=zfs.target network.target

[Service]
Type=simple
ExecStart=/opt/zfs-protection/scripts/zfs-health-monitor.sh --daemon
Restart=always
RestartSec=300
StandardOutput=append:/var/log/zfs-protection/health-monitor.log
StandardError=append:/var/log/zfs-protection/health-monitor.log

[Install]
WantedBy=multi-user.target
EOF

# ZFS Scrub Scheduler Timer
cat > /etc/systemd/system/zfs-scrub-scheduler.timer << 'EOF'
[Unit]
Description=Weekly ZFS Scrub
Requires=zfs-scrub-scheduler.service

[Timer]
OnCalendar=Sun 02:00:00
Persistent=true

[Install]
WantedBy=timers.target
EOF

cat > /etc/systemd/system/zfs-scrub-scheduler.service << 'EOF'
[Unit]
Description=ZFS Scrub Service
After=zfs.target

[Service]
Type=oneshot
ExecStart=/opt/zfs-protection/scripts/zfs-scrub-manager.sh --auto
StandardOutput=append:/var/log/zfs-protection/scrub.log
StandardError=append:/var/log/zfs-protection/scrub.log
EOF

# ZFS Snapshot Manager Timer
cat > /etc/systemd/system/zfs-snapshot-manager.timer << 'EOF'
[Unit]
Description=Hourly ZFS Snapshots
Requires=zfs-snapshot-manager.service

[Timer]
OnCalendar=hourly
Persistent=true

[Install]
WantedBy=timers.target
EOF

cat > /etc/systemd/system/zfs-snapshot-manager.service << 'EOF'
[Unit]
Description=ZFS Snapshot Service
After=zfs.target

[Service]
Type=oneshot
ExecStart=/opt/zfs-protection/scripts/zfs-backup.sh --snapshot-only
StandardOutput=append:/var/log/zfs-protection/snapshot.log
StandardError=append:/var/log/zfs-protection/snapshot.log
EOF

systemctl daemon-reload
print_status "Systemd services configured"

# Create default configuration files if they don't exist
echo ""
echo "📝 Creating configuration files..."

if [ ! -f "$CONFIG_DIR/alert-config.conf" ]; then
    cat > "$CONFIG_DIR/alert-config.conf" << 'EOF'
# ZFS Protection Alert Configuration

# Email Settings
EMAIL_ENABLED=false
EMAIL_RECIPIENTS="admin@example.com"
EMAIL_FROM="zfs-monitor@$(hostname -f)"
SMTP_SERVER="localhost"
SMTP_PORT="25"

# Slack Settings
SLACK_ENABLED=false
SLACK_WEBHOOK_URL=""
SLACK_CHANNEL="#alerts"

# Alert Thresholds
POOL_CAPACITY_WARNING=80
POOL_CAPACITY_CRITICAL=90
SCRUB_AGE_WARNING_DAYS=14
SNAPSHOT_AGE_WARNING_HOURS=25

# Rate Limiting
ALERT_COOLDOWN_MINUTES=60
MAX_ALERTS_PER_HOUR=10
EOF
    print_status "Alert configuration created"
fi

if [ ! -f "$CONFIG_DIR/backup-config.conf" ]; then
    cat > "$CONFIG_DIR/backup-config.conf" << 'EOF'
# ZFS Backup Configuration

# Local Backup Settings
LOCAL_BACKUP_ENABLED=true
LOCAL_BACKUP_POOL="backup"
LOCAL_BACKUP_PATH="/backup/zfs"

# Remote Backup Settings
REMOTE_BACKUP_ENABLED=false
REMOTE_BACKUP_HOST=""
REMOTE_BACKUP_USER="backup"
REMOTE_BACKUP_PATH="/backup/proxmox"
REMOTE_BACKUP_PORT="22"

# Snapshot Retention Policy
HOURLY_SNAPSHOTS=24
DAILY_SNAPSHOTS=30
WEEKLY_SNAPSHOTS=12
MONTHLY_SNAPSHOTS=12

# Backup Options
COMPRESSION_ENABLED=true
COMPRESSION_LEVEL="lz4"
INCREMENTAL_ENABLED=true
VERIFY_AFTER_BACKUP=true
EOF
    print_status "Backup configuration created"
fi

# Enable and start services
echo ""
echo "🚀 Enabling services..."
systemctl enable zfs-health-monitor.service > /dev/null 2>&1
systemctl enable zfs-scrub-scheduler.timer > /dev/null 2>&1
systemctl enable zfs-snapshot-manager.timer > /dev/null 2>&1
print_status "Services enabled"

echo ""
echo "▶️ Starting services..."
systemctl start zfs-health-monitor.service
systemctl start zfs-scrub-scheduler.timer
systemctl start zfs-snapshot-manager.timer
print_status "Services started"

# Run initial health check
echo ""
echo "🔍 Running initial health check..."
if "$INSTALL_DIR/scripts/zfs-health-monitor.sh" --check; then
    print_status "Health check completed"
else
    print_warning "Health check reported issues - review the output above"
fi

# Create log rotation configuration
echo ""
echo "📊 Setting up log rotation..."
cat > /etc/logrotate.d/zfs-protection << 'EOF'
/var/log/zfs-protection/*.log {
    daily
    rotate 30
    compress
    missingok
    notifempty
    create 0644 root root
    sharedscripts
    postrotate
        systemctl reload rsyslog > /dev/null 2>&1 || true
    endscript
}
EOF
print_status "Log rotation configured"

# Final status check
echo ""
echo "═══════════════════════════════════════════════════════"
echo ""
print_status "ZFS Protection Suite installed successfully!"
echo ""
echo "📊 Service Status:"
systemctl --no-pager status zfs-health-monitor.service | grep Active || true
echo ""
echo "⏰ Scheduled Tasks:"
systemctl list-timers | grep zfs || true
echo ""
echo "📁 Installation Locations:"
echo "   • Scripts: $INSTALL_DIR/scripts/"
echo "   • Configs: $CONFIG_DIR/"
echo "   • Logs: $LOG_DIR/"
echo "   • Docs: $INSTALL_DIR/docs/"
echo ""
echo "🔧 Next Steps:"
echo "   1. Configure email alerts:"
echo "      vi $CONFIG_DIR/alert-config.conf"
echo ""
echo "   2. Test the alert system:"
echo "      $INSTALL_DIR/scripts/send-alert.sh --test"
echo ""
echo "   3. Configure backup destinations:"
echo "      vi $CONFIG_DIR/backup-config.conf"
echo ""
echo "   4. View monitoring logs:"
echo "      tail -f $LOG_DIR/health-monitor.log"
echo ""
echo "   5. Check current ZFS status:"
echo "      zpool status -v"
echo ""
echo "📖 Documentation available at:"
echo "   $INSTALL_DIR/docs/runbook.md"
echo ""
echo "═══════════════════════════════════════════════════════"