# ZFS Protection Suite - Deployment Instructions

## 🚨 Server Connection Issue
The Proxmox server at **100.107.113.33** is currently unreachable. Please follow these manual deployment steps once connectivity is restored.

## 📦 Package Created
- **File**: `zfs-protection-suite.tar.gz` (35KB)
- **Location**: `/root/host-admin/zfs-protection-suite.tar.gz`

## 🚀 Manual Deployment Steps

### Option 1: When Server is Accessible via SSH

```bash
# 1. Copy the package to your Proxmox server
scp /root/host-admin/zfs-protection-suite.tar.gz root@100.107.113.33:/tmp/

# 2. SSH into your Proxmox server
ssh root@100.107.113.33

# 3. Extract and install
cd /opt
tar xzf /tmp/zfs-protection-suite.tar.gz
cd zfs-protection
./install.sh
```

### Option 2: Direct Installation on Proxmox Console

If you have physical/console access to the Proxmox server:

```bash
# 1. Transfer the package via USB or network share
# 2. On the Proxmox server console:
cd /opt
tar xzf /path/to/zfs-protection-suite.tar.gz
cd zfs-protection

# 3. Make installation script executable
chmod +x install.sh

# 4. Run the local installation
./install-local.sh
```

## 🔧 Quick Local Installation Script

Create this script directly on your Proxmox server if needed:

```bash
#!/bin/bash
# Save as: /opt/quick-zfs-protection.sh

INSTALL_DIR="/opt/zfs-protection"
LOG_DIR="/var/log/zfs-protection"
CONFIG_DIR="/etc/zfs-protection"

# Create directories
mkdir -p $INSTALL_DIR/{scripts,configs,templates}
mkdir -p $LOG_DIR
mkdir -p $CONFIG_DIR

# Install required packages
apt-get update && apt-get install -y \
    smartmontools \
    postfix \
    mailutils \
    curl \
    jq \
    bc \
    prometheus-node-exporter

# Enable monitoring services
systemctl enable zfs-health-monitor.service
systemctl enable zfs-scrub-scheduler.timer
systemctl start zfs-health-monitor.service
systemctl start zfs-scrub-scheduler.timer

echo "✅ Basic ZFS protection installed!"
```

## 📋 Post-Installation Configuration

### 1. Configure Email Alerts
```bash
vi /etc/zfs-protection/alert-config.conf

# Add your email:
EMAIL_RECIPIENTS="your-email@example.com"
EMAIL_ENABLED=true
SMTP_SERVER="your-smtp-server"
```

### 2. Verify Services
```bash
# Check service status
systemctl status zfs-health-monitor.service
systemctl status zfs-scrub-scheduler.timer

# View logs
journalctl -u zfs-health-monitor -f
```

### 3. Run Initial Checks
```bash
# Health check
/opt/zfs-protection/scripts/zfs-health-monitor.sh --check

# Test alerts
/opt/zfs-protection/scripts/send-alert.sh --test

# Check current pool status
zpool status -v
zpool list
```

### 4. Set Up Monitoring Dashboard (Optional)
```bash
/opt/zfs-protection/scripts/setup-monitoring.sh
# Access at: http://100.107.113.33:3000
```

## 🛠️ Troubleshooting

### If Installation Fails:

1. **Check ZFS is available**:
```bash
zpool version
zfs version
```

2. **Verify Proxmox version**:
```bash
pveversion
```

3. **Check system resources**:
```bash
free -h
df -h
```

4. **Manual service creation**:
```bash
# Create service file manually
cat > /etc/systemd/system/zfs-health-monitor.service << EOF
[Unit]
Description=ZFS Health Monitor
After=zfs.target

[Service]
Type=simple
ExecStart=/opt/zfs-protection/scripts/zfs-health-monitor.sh
Restart=always
RestartSec=300

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable zfs-health-monitor.service
systemctl start zfs-health-monitor.service
```

## 📊 What Gets Installed

- **Monitoring Scripts** → `/opt/zfs-protection/scripts/`
  - `zfs-health-monitor.sh` - Real-time health monitoring
  - `zfs-backup.sh` - Automated backup system
  - `zfs-scrub-manager.sh` - Scrub scheduling
  - `zfs-tuning.sh` - Performance optimization
  - `send-alert.sh` - Multi-channel alerting

- **Configuration Files** → `/etc/zfs-protection/`
  - `alert-config.conf` - Alert settings
  - `backup-config.conf` - Backup destinations
  - `monitor-config.conf` - Monitoring thresholds

- **Systemd Services** → `/etc/systemd/system/`
  - `zfs-health-monitor.service` - Continuous monitoring
  - `zfs-scrub-scheduler.timer` - Weekly scrubs
  - `zfs-snapshot-manager.timer` - Snapshot automation

- **Logs** → `/var/log/zfs-protection/`
  - `health-monitor.log` - Health check logs
  - `backup.log` - Backup operation logs
  - `scrub.log` - Scrub operation logs
  - `alerts.log` - Alert history

## ⚠️ Important Notes

1. **Server Currently Unreachable**: The server at 100.107.113.33 is not responding. Check:
   - Network connectivity
   - Firewall rules
   - SSH service status
   - Server power state

2. **Before Deployment**:
   - Ensure you have root access
   - Verify ZFS is installed and pools are available
   - Have at least 100MB free space in /opt

3. **After Deployment**:
   - Monitor initial runs for any errors
   - Adjust thresholds based on your environment
   - Test backup restoration procedures

## 📞 Support

For issues or questions:
1. Check logs in `/var/log/zfs-protection/`
2. Review systemd service status
3. Run diagnostic: `/opt/zfs-protection/scripts/diagnose.sh`

## ✅ Success Indicators

After successful deployment, you should see:
- ✅ Services active in `systemctl status`
- ✅ Logs being written to `/var/log/zfs-protection/`
- ✅ Email alerts for test messages
- ✅ Scheduled tasks in `systemctl list-timers`
- ✅ Monitoring metrics available

---
Package ready for deployment once server connectivity is restored.