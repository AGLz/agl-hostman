# Storage Connectivity Implementation Scripts

**Version:** 1.0.0
**Author:** Hive Mind - Coder Agent
**Purpose:** Production-ready scripts for Proxmox storage connectivity via Tailscale

---

## 📋 Table of Contents

1. [Overview](#overview)
2. [Quick Start](#quick-start)
3. [Scripts Reference](#scripts-reference)
4. [Configuration Files](#configuration-files)
5. [Usage Examples](#usage-examples)
6. [Monitoring & Maintenance](#monitoring--maintenance)
7. [Troubleshooting](#troubleshooting)
8. [Best Practices](#best-practices)

---

## 🎯 Overview

This collection provides comprehensive tooling for establishing, managing, and monitoring storage connectivity between AGLSRV1 and remote Proxmox hosts over Tailscale VPN.

### Architecture

```
┌─────────────────┐         Tailscale VPN          ┌──────────────────┐
│    AGLSRV1      │◄──────────────────────────────►│  Remote Proxmox  │
│  (NFS Server)   │      100.64.0.0/10 Network     │   (NFS Client)   │
│                 │                                 │                  │
│ /mnt/storage/   │                                 │ /mnt/aglsrv1/    │
│  ├─ pbs-backups │────────────────────────────────►│  ├─ pbs-backups  │
│  ├─ vm-images   │────────────────────────────────►│  ├─ vm-images    │
│  ├─ containers  │────────────────────────────────►│  ├─ containers   │
│  └─ shared-data │────────────────────────────────►│  └─ shared-data  │
└─────────────────┘                                 └──────────────────┘
```

### Features

✅ **Automated Setup** - One-command server and client configuration
✅ **Health Monitoring** - Continuous mount health checks with alerting
✅ **Performance Tracking** - Transfer speed monitoring and benchmarking
✅ **PBS Integration** - Proxmox Backup Server sync utilities
✅ **Container Migration** - Tools for LXC and Docker container migration
✅ **Error Recovery** - Automatic mount recovery and stale handle detection
✅ **Comprehensive Logging** - Detailed logs for all operations
✅ **Dry-Run Mode** - Test changes safely before applying

---

## 🚀 Quick Start

### On AGLSRV1 (NFS Server)

```bash
# 1. Setup NFS server exports
sudo /root/host-admin/scripts/setup-nfs-server.sh

# 2. Verify exports
showmount -e localhost

# 3. Check firewall
sudo ufw status
```

### On Remote Proxmox Host (NFS Client)

```bash
# 1. Setup NFS client and mount AGLSRV1 exports
sudo /root/host-admin/scripts/setup-nfs-client.sh --server 100.64.1.1

# 2. Verify mounts
mount | grep aglsrv1
df -h

# 3. Test connectivity
sudo /root/host-admin/scripts/verify-connectivity.sh --once
```

### Start Monitoring

```bash
# Run health monitoring as daemon
sudo /root/host-admin/scripts/check-mount-health.sh --daemon

# Monitor transfer speeds
sudo /root/host-admin/scripts/monitor-transfer-speeds.sh --interval 300
```

---

## 📚 Scripts Reference

### Setup & Configuration Scripts

#### `setup-nfs-server.sh`

Configure NFS server on AGLSRV1 for exporting storage.

**Usage:**
```bash
setup-nfs-server.sh [OPTIONS]

Options:
  -d, --dry-run              Preview changes without applying
  -v, --verbose              Enable detailed output
  -e, --export-path PATH     NFS export base (default: /mnt/storage)
  -n, --network CIDR         Allowed network (default: 100.64.0.0/10)
  -o, --options OPTS         NFS export options
```

**Examples:**
```bash
# Dry run to preview configuration
./setup-nfs-server.sh --dry-run

# Configure with custom export path
./setup-nfs-server.sh --export-path /srv/nfs

# Configure with specific network
./setup-nfs-server.sh --network 192.168.1.0/24
```

**What it does:**
- Installs NFS server packages
- Creates export directories
- Configures `/etc/exports`
- Optimizes NFS server settings
- Configures firewall rules
- Starts and enables NFS services
- Validates configuration

---

#### `setup-nfs-client.sh`

Configure NFS client on remote Proxmox hosts.

**Usage:**
```bash
setup-nfs-client.sh [OPTIONS]

Options:
  -s, --server HOSTNAME      NFS server (required)
  -m, --mount-base PATH      Mount base path (default: /mnt/aglsrv1)
  -n, --nfs-version VER      NFS version (default: 4.2)
  --auto-discover            Find server via Tailscale
```

**Examples:**
```bash
# Auto-discover and mount
./setup-nfs-client.sh --auto-discover

# Manual server specification
./setup-nfs-client.sh --server 100.64.1.1

# Custom mount location
./setup-nfs-client.sh --server aglsrv1 --mount-base /srv/remote
```

**What it does:**
- Installs NFS client packages
- Tests connectivity to server
- Creates mount points
- Generates systemd mount units
- Adds fstab entries (backup method)
- Enables and starts mounts
- Verifies mount success

---

#### `mount-remote-storage.sh`

Mount remote Proxmox storage on AGLSRV1 (reverse direction).

**Usage:**
```bash
mount-remote-storage.sh [OPTIONS]

Options:
  -r, --remote HOST          Remote host (can specify multiple)
  -t, --type METHOD          Mount method: nfs, sshfs, iscsi
  --discover-tailscale       Auto-discover Proxmox hosts
  --all                      Mount all discovered hosts
```

**Examples:**
```bash
# Mount specific host via NFS
./mount-remote-storage.sh --remote 100.64.1.10 --type nfs

# Auto-discover and mount all
./mount-remote-storage.sh --discover-tailscale --all

# Mount via SSHFS for encryption
./mount-remote-storage.sh --remote host1 --type sshfs
```

**What it does:**
- Discovers Proxmox hosts via Tailscale
- Mounts remote storage (NFS/SSHFS/iSCSI)
- Creates systemd mount units
- Verifies mount accessibility

---

### Monitoring & Health Scripts

#### `verify-connectivity.sh`

Comprehensive storage connectivity verification.

**Usage:**
```bash
verify-connectivity.sh [OPTIONS]

Options:
  -q, --quick                Skip performance tests
  -p, --path PATH            Add custom mount path
  -s, --size SIZE            Test file size (default: 100M)
  -t, --threshold MBPS       Performance threshold
```

**Examples:**
```bash
# Quick connectivity check
./verify-connectivity.sh --quick

# Full verification with custom threshold
./verify-connectivity.sh --threshold 200

# Single path test
./verify-connectivity.sh --path /mnt/custom --quick
```

**Tests performed:**
- ✓ Network connectivity (ping, latency)
- ✓ Service availability (NFS, SSH, iSCSI)
- ✓ Mount point status
- ✓ Read/write permissions
- ✓ Performance benchmarks
- ✓ NFS statistics
- ✓ System resources

**Output:**
- Detailed report in `/var/log/storage-setup/connectivity-report-*.txt`
- Pass/fail status for each test
- Performance metrics
- Recommendations

---

#### `check-mount-health.sh`

Continuous mount health monitoring with auto-recovery.

**Usage:**
```bash
check-mount-health.sh [OPTIONS]

Options:
  -i, --interval SECONDS     Check interval (default: 60)
  -t, --threshold COUNT      Alert threshold (default: 3)
  -e, --email EMAIL          Alert email address
  -w, --webhook URL          Alert webhook URL
  --daemon                   Run as background daemon
  --once                     Single check and exit
```

**Examples:**
```bash
# Run single health check
./check-mount-health.sh --once

# Monitor every 30 seconds
./check-mount-health.sh --interval 30

# Daemon with email alerts
./check-mount-health.sh --daemon --email admin@example.com
```

**Features:**
- Detects stale NFS handles
- Monitors mount accessibility
- Automatic recovery attempts
- Configurable alerting (email, webhook)
- JSON status output
- Failure count tracking

**Status file:** `/var/log/storage-monitoring/mount-health-status.json`

---

#### `monitor-transfer-speeds.sh`

Performance monitoring and benchmarking.

**Usage:**
```bash
monitor-transfer-speeds.sh [OPTIONS]

Options:
  -s, --size SIZE_MB         Test file size (default: 100)
  -i, --interval SECONDS     Test interval (default: 300)
  -d, --duration HOURS       Monitoring duration (default: 24)
  --once                     Single test
  --report                   Generate report from data
```

**Examples:**
```bash
# Single performance test
./monitor-transfer-speeds.sh --once

# Monitor for 1 hour, test every minute
./monitor-transfer-speeds.sh --duration 1 --interval 60

# Generate performance report
./monitor-transfer-speeds.sh --report
```

**Metrics collected:**
- Write speed (MB/s)
- Read speed (MB/s)
- IOPS
- Latency (ms)
- Trends and statistics

**Output:** CSV data in `/var/log/storage-monitoring/transfer-speeds-*.csv`

---

### PBS & Backup Scripts

#### `sync-pbs-backups.sh`

Synchronize Proxmox Backup Server backups.

**Usage:**
```bash
sync-pbs-backups.sh [OPTIONS]

Options:
  -s, --source PATH          Source PBS path
  -t, --dest PATH            Destination path
  -m, --method METHOD        Sync method: rsync, rclone, cp
  --no-verify                Skip integrity verification
  --delete-old               Delete old backups
  --retention DAYS           Retention period (default: 30)
```

**Examples:**
```bash
# Dry run
./sync-pbs-backups.sh --dry-run

# Sync with verification
./sync-pbs-backups.sh --source /var/lib/proxmox-backup/backups

# Sync and cleanup old backups
./sync-pbs-backups.sh --delete-old --retention 14
```

**Features:**
- Multiple sync methods (rsync, rclone, cp)
- Integrity verification
- Retention management
- Detailed sync reports

---

## 📁 Configuration Files

### `/config/exports.example`

NFS server exports configuration template for `/etc/exports`.

**Usage:**
```bash
# Copy to system location
sudo cp config/exports.example /etc/exports

# Edit with your IPs
sudo nano /etc/exports

# Apply changes
sudo exportfs -ra
```

**Key sections:**
- NFSv4 root export
- PBS backups (sync mode)
- VM images (async mode)
- Container volumes
- Shared data

---

### `/config/fstab.example`

NFS client fstab entries template.

**Usage:**
```bash
# Backup current fstab
sudo cp /etc/fstab /etc/fstab.backup

# Append NFS entries
sudo cat config/fstab.example >> /etc/fstab

# Edit IPs
sudo nano /etc/fstab

# Test without rebooting
sudo mount -a
```

**Features:**
- NFSv4.2 entries
- Systemd integration
- Performance-optimized options
- Alternative SSHFS examples

---

### `/config/systemd-mount-template.mount`

Systemd mount unit template.

**Usage:**
```bash
# Generate unit filename
systemd-escape -p --suffix=mount /mnt/aglsrv1/pbs-backups

# Copy template
sudo cp config/systemd-mount-template.mount \
  /etc/systemd/system/mnt-aglsrv1-pbs\\x2dbackups.mount

# Edit configuration
sudo nano /etc/systemd/system/mnt-aglsrv1-pbs\\x2dbackups.mount

# Enable and start
sudo systemctl daemon-reload
sudo systemctl enable --now mnt-aglsrv1-pbs\\x2dbackups.mount
```

**Benefits over fstab:**
- Better dependency management
- Automatic retry
- Detailed logging
- Automount support

---

## 💡 Usage Examples

### Scenario 1: Initial Setup

**Goal:** Configure AGLSRV1 as NFS server and mount on remote host.

```bash
# On AGLSRV1
sudo /root/host-admin/scripts/setup-nfs-server.sh
sudo systemctl status nfs-kernel-server
sudo exportfs -v

# On Remote Proxmox
sudo /root/host-admin/scripts/setup-nfs-client.sh \
  --server 100.64.1.1 \
  --mount-base /mnt/aglsrv1

# Verify
mount | grep aglsrv1
df -h /mnt/aglsrv1/*
```

---

### Scenario 2: Performance Monitoring

**Goal:** Benchmark and monitor storage performance.

```bash
# Initial benchmark
sudo /root/host-admin/scripts/verify-connectivity.sh

# Start continuous monitoring
sudo /root/host-admin/scripts/monitor-transfer-speeds.sh \
  --interval 600 \
  --duration 24 &

# Check results next day
sudo /root/host-admin/scripts/monitor-transfer-speeds.sh --report
```

---

### Scenario 3: PBS Backup Sync

**Goal:** Sync PBS backups to AGLSRV1 for centralized storage.

```bash
# Test sync (dry run)
sudo /root/host-admin/scripts/sync-pbs-backups.sh \
  --dry-run \
  --source /var/lib/proxmox-backup/backups \
  --dest /mnt/aglsrv1/pbs-backups

# Real sync with verification
sudo /root/host-admin/scripts/sync-pbs-backups.sh \
  --source /var/lib/proxmox-backup/backups \
  --dest /mnt/aglsrv1/pbs-backups \
  --method rsync

# Schedule in cron (daily at 2 AM)
echo "0 2 * * * root /root/host-admin/scripts/sync-pbs-backups.sh \
  --source /var/lib/proxmox-backup/backups \
  --dest /mnt/aglsrv1/pbs-backups >> /var/log/pbs-sync/cron.log 2>&1" \
  | sudo tee -a /etc/crontab
```

---

### Scenario 4: Health Monitoring with Alerts

**Goal:** Continuous monitoring with email/webhook alerts.

```bash
# Start health monitoring daemon
sudo /root/host-admin/scripts/check-mount-health.sh \
  --daemon \
  --interval 60 \
  --threshold 3 \
  --email admin@example.com \
  --webhook https://hooks.slack.com/services/YOUR/WEBHOOK/URL

# Create systemd service for persistence
sudo tee /etc/systemd/system/mount-health-monitor.service << 'EOF'
[Unit]
Description=NFS Mount Health Monitoring
After=network-online.target

[Service]
Type=simple
ExecStart=/root/host-admin/scripts/check-mount-health.sh --daemon --interval 60
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable --now mount-health-monitor.service
sudo systemctl status mount-health-monitor.service
```

---

## 🔧 Monitoring & Maintenance

### Daily Checks

```bash
# Quick health check
sudo /root/host-admin/scripts/check-mount-health.sh --once

# View mount status
mount | grep -E "nfs|aglsrv1"
df -h | grep -E "aglsrv1|storage"

# Check NFS stats
nfsstat -m
```

### Weekly Reviews

```bash
# Performance report
sudo /root/host-admin/scripts/monitor-transfer-speeds.sh --report

# Connectivity verification
sudo /root/host-admin/scripts/verify-connectivity.sh

# Check logs
sudo journalctl -u *.mount --since "7 days ago"
tail -100 /var/log/storage-monitoring/*.log
```

### Monthly Maintenance

```bash
# Review PBS backup sync
ls -lh /mnt/aglsrv1/pbs-backups/
du -sh /mnt/aglsrv1/pbs-backups/*

# Cleanup old logs
find /var/log/storage-monitoring -name "*.log" -mtime +30 -delete

# Update scripts (if needed)
cd /root/host-admin
git pull  # if using version control
```

---

## 🐛 Troubleshooting

### Issue: Mounts fail at boot

**Symptoms:**
- Mounts work manually but fail at boot
- `systemctl status *.mount` shows failed

**Solution:**
```bash
# Ensure network is ready
sudo systemctl enable NetworkManager-wait-online.service

# Check mount unit dependencies
systemctl cat mnt-aglsrv1-*.mount

# Add network dependency if missing
sudo systemctl edit mnt-aglsrv1-pbs\\x2dbackups.mount
# Add:
# [Unit]
# After=network-online.target
# Requires=network-online.target

sudo systemctl daemon-reload
sudo systemctl restart mnt-aglsrv1-*.mount
```

---

### Issue: Stale NFS file handle

**Symptoms:**
- `ls: cannot access '/mnt/aglsrv1': Stale file handle`
- Mount appears active but inaccessible

**Solution:**
```bash
# Automatic recovery (recommended)
sudo /root/host-admin/scripts/check-mount-health.sh --once

# Manual recovery
sudo umount -l /mnt/aglsrv1/pbs-backups
sudo systemctl restart mnt-aglsrv1-pbs\\x2dbackups.mount

# Verify
ls -la /mnt/aglsrv1/pbs-backups
```

---

### Issue: Poor performance

**Symptoms:**
- Transfer speeds below 50 MB/s
- High latency (>100ms)

**Diagnosis:**
```bash
# Run performance test
sudo /root/host-admin/scripts/monitor-transfer-speeds.sh --once

# Check network latency
ping -c 10 100.64.1.1

# Check NFS stats
nfsstat -m
```

**Solutions:**
```bash
# 1. Optimize mount options (remount)
sudo mount -o remount,rw,tcp,vers=4.2,rsize=1048576,wsize=1048576 \
  /mnt/aglsrv1/pbs-backups

# 2. Increase NFS threads on server
sudo nano /etc/default/nfs-kernel-server
# Set: RPCNFSDCOUNT=16
sudo systemctl restart nfs-kernel-server

# 3. Check Tailscale performance
tailscale ping 100.64.1.1
```

---

### Issue: Permission denied

**Symptoms:**
- Cannot write to mounted directory
- `touch: cannot touch '/mnt/aglsrv1/test': Permission denied`

**Solution:**
```bash
# Check mount options
mount | grep aglsrv1

# Verify NFS exports on server
sudo exportfs -v

# Ensure no_root_squash is set (on server)
sudo nano /etc/exports
# Use: /export 100.64.0.0/10(rw,no_root_squash,...)
sudo exportfs -ra

# Remount on client
sudo systemctl restart mnt-aglsrv1-*.mount
```

---

## ✅ Best Practices

### Security

1. **Restrict to Tailscale Network**
   ```bash
   # In /etc/exports, use specific Tailscale CIDR
   /mnt/storage 100.64.0.0/10(rw,...)
   # NOT: /mnt/storage *(rw,...)
   ```

2. **Use no_root_squash Carefully**
   - Only for trusted hosts
   - Consider root_squash for shared data

3. **Monitor Access**
   ```bash
   # Watch NFS connections
   watch -n 5 'netstat -an | grep :2049'
   ```

### Performance

1. **Use NFSv4.2**
   - Better performance
   - Improved security
   - Server-side copy support

2. **Optimize Mount Options**
   - Large files: `async,rsize=1048576,wsize=1048576`
   - Small files: `sync,actimeo=30`
   - Databases: `sync,hard,intr`

3. **Monitor Regularly**
   ```bash
   # Setup performance monitoring
   sudo /root/host-admin/scripts/monitor-transfer-speeds.sh \
     --interval 300 --duration 168 &  # Monitor for 1 week
   ```

### Reliability

1. **Use Systemd Mount Units**
   - Better dependency management
   - Automatic recovery
   - Detailed logging

2. **Enable Health Monitoring**
   ```bash
   # Run as systemd service
   sudo systemctl enable --now mount-health-monitor.service
   ```

3. **Regular Backups**
   ```bash
   # Daily PBS backup sync
   0 2 * * * /root/host-admin/scripts/sync-pbs-backups.sh
   ```

### Logging

1. **Centralize Logs**
   ```bash
   # All scripts log to /var/log/storage-*
   ls -lh /var/log/storage-*
   ```

2. **Review Regularly**
   ```bash
   # Check for errors
   grep -i error /var/log/storage-*/*.log
   ```

3. **Log Rotation**
   ```bash
   # Add logrotate config
   sudo tee /etc/logrotate.d/storage-monitoring << 'EOF'
   /var/log/storage-monitoring/*.log {
       weekly
       rotate 4
       compress
       missingok
       notifempty
   }
   EOF
   ```

---

## 📞 Support & Contribution

### Log Locations

- Setup logs: `/var/log/storage-setup/`
- Monitoring logs: `/var/log/storage-monitoring/`
- PBS sync logs: `/var/log/pbs-sync/`
- System logs: `journalctl -u *.mount`

### Useful Commands

```bash
# View all storage-related systemd units
systemctl list-units --type=mount --all

# Check NFS statistics
nfsstat -m

# Monitor NFS operations live
watch -n 2 'nfsstat -c | head -20'

# View Tailscale status
tailscale status

# Check firewall
sudo ufw status verbose
```

---

**Last Updated:** 2025-10-14
**Script Version:** 1.0.0
**Compatibility:** Proxmox VE 7.x/8.x, Debian 11/12, Ubuntu 20.04+
