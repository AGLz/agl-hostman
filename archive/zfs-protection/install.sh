#!/bin/bash
#
# ZFS Data Corruption Prevention Suite Installer
# For Proxmox Server: 100.107.113.33
#
# This script installs comprehensive ZFS monitoring, backup, and maintenance tools
#

set -euo pipefail

PROXMOX_HOST="100.107.113.33"
INSTALL_DIR="/opt/zfs-protection"
LOG_DIR="/var/log/zfs-protection"
CONFIG_DIR="/etc/zfs-protection"

echo "🛡️ ZFS Data Corruption Prevention Suite Installer"
echo "=================================================="
echo "Target: $PROXMOX_HOST"
echo "Install Directory: $INSTALL_DIR"
echo ""

# Function to run commands on remote Proxmox server
run_remote() {
    ssh root@$PROXMOX_HOST "$1"
}

# Function to copy files to remote server
copy_to_remote() {
    scp -r "$1" root@$PROXMOX_HOST:"$2"
}

echo "🔍 Step 1: Checking Proxmox server connectivity and ZFS status..."
if ! run_remote "zpool status" > /dev/null 2>&1; then
    echo "❌ Cannot connect to Proxmox server or ZFS not available"
    exit 1
fi
echo "✅ Proxmox server accessible and ZFS operational"

echo "📁 Step 2: Creating directory structure..."
run_remote "mkdir -p $INSTALL_DIR/{scripts,configs,templates}"
run_remote "mkdir -p $LOG_DIR"
run_remote "mkdir -p $CONFIG_DIR"

echo "📦 Step 3: Installing required packages..."
run_remote "apt-get update && apt-get install -y smartmontools postfix mailutils curl jq bc"

echo "📋 Step 4: Copying ZFS protection scripts..."
copy_to_remote "scripts/" "$INSTALL_DIR/"
copy_to_remote "configs/" "$CONFIG_DIR/"

echo "🔧 Step 5: Setting up systemd services..."
copy_to_remote "systemd/" "/etc/systemd/system/"
run_remote "systemctl daemon-reload"

echo "⚙️ Step 6: Making scripts executable..."
run_remote "chmod +x $INSTALL_DIR/scripts/*.sh"

echo "📊 Step 7: Setting up monitoring configuration..."
run_remote "$INSTALL_DIR/scripts/setup-monitoring.sh"

echo "🔄 Step 8: Enabling and starting services..."
run_remote "systemctl enable zfs-health-monitor.service"
run_remote "systemctl enable zfs-scrub-scheduler.timer"
run_remote "systemctl enable zfs-snapshot-manager.timer"
run_remote "systemctl start zfs-health-monitor.service"
run_remote "systemctl start zfs-scrub-scheduler.timer"
run_remote "systemctl start zfs-snapshot-manager.timer"

echo "🎯 Step 9: Running initial health check..."
run_remote "$INSTALL_DIR/scripts/zfs-health-check.sh --initial"

echo ""
echo "✅ ZFS Data Corruption Prevention Suite installed successfully!"
echo ""
echo "🔧 Next Steps:"
echo "1. Review configuration files in $CONFIG_DIR"
echo "2. Customize email alerts in $CONFIG_DIR/alert-config.conf"
echo "3. Set up off-site backup destination in $CONFIG_DIR/backup-config.conf"
echo "4. Run initial backup: $INSTALL_DIR/scripts/zfs-backup.sh --initial"
echo ""
echo "📊 Monitoring Dashboard: http://$PROXMOX_HOST:3000 (after Grafana setup)"
echo "📋 Logs: $LOG_DIR/"
echo "📖 Documentation: $INSTALL_DIR/docs/"