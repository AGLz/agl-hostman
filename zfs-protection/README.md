# ZFS Data Corruption Prevention Suite

A comprehensive solution for preventing ZFS data corruption on Proxmox servers through automated monitoring, backup, and maintenance.

## 🎯 Overview

This suite implements a complete ZFS protection strategy including:
- **Real-time health monitoring** with automated alerts
- **3-2-1 backup strategy** with local and remote replication
- **Automated scrub scheduling** with intelligent load management
- **Performance tuning** for optimal ZFS configuration
- **Monitoring dashboard** with Grafana visualization
- **Emergency response procedures** with detailed runbook

## 🚀 Quick Start

### Installation

1. **Clone and prepare the installation**:
   ```bash
   git clone <repository> /root/zfs-protection
   cd /root/zfs-protection
   chmod +x install.sh
   ```

2. **Install on your Proxmox server**:
   ```bash
   ./install.sh
   ```

3. **Configure email alerts** (edit `/etc/zfs-protection/alert-config.conf`):
   ```bash
   EMAIL_RECIPIENTS="admin@yourdomain.com"
   EMAIL_ENABLED=true
   ```

4. **Start monitoring**:
   ```bash
   systemctl start zfs-health-monitor.service
   systemctl enable zfs-health-monitor.service
   ```

### Immediate Protection

The installation automatically enables:
- ✅ **Continuous health monitoring** (every 5 minutes)
- ✅ **Daily snapshots** with automated retention
- ✅ **Weekly scrubs** (Sunday 2:00 AM)
- ✅ **Automated alerts** for critical issues
- ✅ **Performance optimization** tuning

## 📊 Components

### 🔍 Health Monitoring (`zfs-health-monitor.sh`)
- **Pool health** - Detects degraded/faulted pools instantly
- **Capacity monitoring** - Alerts at 80% (warning) and 90% (critical)
- **Error detection** - Monitors read/write/checksum errors
- **SMART monitoring** - Tracks drive health and temperature
- **ARC analysis** - Monitors cache hit ratios and memory usage
- **Real-time alerts** - Immediate notifications for critical issues

### 💾 Backup System (`zfs-backup.sh`)
Implements the **3-2-1 backup rule**:
1. **3 copies** - Production + Local backup + Remote backup
2. **2 media types** - Different storage systems
3. **1 off-site** - Remote location protection

**Features:**
- **Incremental backups** using ZFS send/receive
- **Automated retention** - Configurable snapshot lifecycles
- **Backup verification** - Integrity checking
- **Resume capability** - Handle interrupted transfers
- **Compression** - Efficient storage utilization

### 🔍 Scrub Management (`zfs-scrub-manager.sh`)
- **Intelligent scheduling** - Avoids high-load periods
- **Progress monitoring** - Real-time scrub tracking
- **Performance impact control** - Pauses during high system load
- **Error reporting** - Detailed analysis of found issues
- **Automated retry** - Handles transient failures

### 🚨 Alert System (`send-alert.sh`)
**Multi-channel notifications:**
- 📧 **Email** - Detailed reports with system context
- 💬 **Slack** - Instant team notifications
- 🔗 **Webhooks** - Integration with external systems
- 📱 **SMS** - Critical alerts via Twilio
- 🚨 **PagerDuty** - Professional incident management

### ⚙️ Performance Tuning (`zfs-tuning.sh`)
**Optimized for Proxmox environments:**
- **ARC sizing** - Balanced memory allocation
- **TXG optimization** - Improved write performance
- **Compression** - LZ4 for best performance/compression ratio
- **Recordsize** - Optimized for VM workloads
- **Scrub tuning** - Minimized performance impact

### 📊 Monitoring Dashboard
**Grafana integration with:**
- **Pool health status** - Real-time health indicators
- **Capacity trends** - Historical usage patterns
- **Performance metrics** - I/O statistics and latency
- **ARC statistics** - Cache performance analysis
- **Alert history** - Incident tracking and patterns

## 📁 Directory Structure

```
/opt/zfs-protection/
├── scripts/
│   ├── zfs-health-monitor.sh    # Continuous health monitoring
│   ├── zfs-backup.sh            # Backup and snapshot management
│   ├── zfs-scrub-manager.sh     # Scrub scheduling and monitoring
│   ├── send-alert.sh            # Multi-channel alerting
│   ├── zfs-tuning.sh            # Performance optimization
│   └── setup-monitoring.sh      # Dashboard setup
├── configs/
│   ├── monitor-config.conf      # Monitoring thresholds
│   ├── backup-config.conf       # Backup settings
│   ├── scrub-config.conf        # Scrub scheduling
│   └── alert-config.conf        # Notification settings
└── docs/
    └── runbook.md               # Emergency procedures

/var/log/zfs-protection/
├── health-monitor.log           # Health check logs
├── backup.log                   # Backup operation logs
├── scrub.log                    # Scrub operation logs
└── alerts.log                   # Alert delivery logs
```

## ⚙️ Configuration

### Email Alerts
```bash
# Edit /etc/zfs-protection/alert-config.conf
EMAIL_ENABLED=true
EMAIL_RECIPIENTS="admin@domain.com,ops@domain.com"
EMAIL_SMTP_SERVER="mail.domain.com"
```

### Backup Settings
```bash
# Edit /etc/zfs-protection/backup-config.conf
LOCAL_BACKUP_ENABLED=true
LOCAL_BACKUP_POOL="backup"
REMOTE_BACKUP_ENABLED=true
REMOTE_HOST="backup-server.domain.com"
DAILY_RETENTION=30
WEEKLY_RETENTION=12
```

### Monitoring Thresholds
```bash
# Edit /etc/zfs-protection/monitor-config.conf
CAPACITY_WARNING_THRESHOLD=80
CAPACITY_CRITICAL_THRESHOLD=90
TEMP_WARNING_THRESHOLD=50
ARC_HIT_RATIO_THRESHOLD=85
```

## 🚨 Emergency Procedures

### Pool Degraded
```bash
# 1. Check status
zpool status -v

# 2. Replace failed disk
zpool replace tank /dev/failed_disk /dev/replacement_disk

# 3. Monitor rebuild
watch zpool status
```

### Data Corruption Detected
```bash
# 1. Immediate scrub
zpool scrub pool_name

# 2. Check recent backups
zfs list -t snapshot | tail -10

# 3. If corruption confirmed, restore from backup
zfs rollback pool/dataset@last_good_snapshot
```

### System Recovery
```bash
# 1. Boot from rescue media
# 2. Import pools
zpool import -f tank

# 3. Mount and repair
mount -t zfs tank/ROOT/pve-1 /mnt
chroot /mnt
```

## 📊 Monitoring and Metrics

### Access Monitoring Dashboard
1. **Install monitoring**: `./scripts/setup-monitoring.sh`
2. **Access Grafana**: `http://YOUR_SERVER_IP:3000`
3. **Login**: admin/admin (change on first login)
4. **View ZFS Dashboard**: Pre-configured with pool health, capacity, and performance metrics

### Key Metrics Monitored
- **Pool Health**: ONLINE/DEGRADED/FAULTED status
- **Capacity**: Usage percentage and free space trends
- **ARC Performance**: Hit ratio and memory utilization
- **Scrub Status**: Completion status and error counts
- **Backup Success**: Success rates and timing
- **Drive Health**: SMART status and temperature

### Command-Line Monitoring
```bash
# Pool status overview
zpool status

# Capacity monitoring
zfs list -o space

# Performance monitoring
zpool iostat -v 1

# ARC statistics
cat /proc/spl/kstat/zfs/arcstats

# Health check
/opt/zfs-protection/scripts/zfs-health-monitor.sh --check
```

## 🔧 Maintenance Tasks

### Daily (Automated)
- Health monitoring checks
- Snapshot creation and cleanup
- Log rotation
- Metrics collection

### Weekly (Automated)
- Pool scrubbing
- Backup verification
- Capacity trend analysis

### Monthly (Manual)
- Configuration review
- Performance baseline update
- Contact information verification
- Disaster recovery test

### Quarterly (Manual)
- Full backup restoration test
- Hardware inventory update
- Documentation review
- Training and procedure updates

## 🛠️ Advanced Configuration

### Custom Alert Channels
```bash
# Slack integration
SLACK_ENABLED=true
SLACK_WEBHOOK_URL="https://hooks.slack.com/services/..."

# PagerDuty integration
PAGERDUTY_ENABLED=true
PAGERDUTY_INTEGRATION_KEY="your_key_here"

# Custom webhook
WEBHOOK_ENABLED=true
WEBHOOK_URL="https://your-monitoring-system.com/webhook"
```

### Performance Tuning
```bash
# Apply all optimizations
./scripts/zfs-tuning.sh all

# Apply specific optimizations
./scripts/zfs-tuning.sh pools     # Pool-level tuning
./scripts/zfs-tuning.sh datasets  # Dataset-level tuning
./scripts/zfs-tuning.sh kernel    # Kernel parameter tuning
```

### Backup Scheduling
```bash
# Hourly snapshots (high-activity datasets)
./scripts/zfs-backup.sh --hourly tank/vm-data

# Daily backups (standard)
./scripts/zfs-backup.sh --daily

# Weekly backups (long-term retention)
./scripts/zfs-backup.sh --weekly

# Monthly archives
./scripts/zfs-backup.sh --monthly
```

## 🔍 Troubleshooting

### Service Issues
```bash
# Check service status
systemctl status zfs-health-monitor.service

# View service logs
journalctl -u zfs-health-monitor.service -f

# Restart services
systemctl restart zfs-health-monitor.service
```

### Backup Issues
```bash
# Test backup manually
./scripts/zfs-backup.sh --daily tank/test-dataset

# Check backup logs
tail -100 /var/log/zfs-protection/backup.log

# Verify backup integrity
./scripts/zfs-backup.sh --verify backup/tank/test-dataset
```

### Alert Issues
```bash
# Test alert system
./scripts/send-alert.sh --test

# Check alert configuration
cat /etc/zfs-protection/alert-config.conf

# Test specific alert
./scripts/send-alert.sh INFO test-pool "Test message"
```

## 📞 Support and Documentation

### Log Files
- **Health Monitor**: `/var/log/zfs-protection/health-monitor.log`
- **Backup Operations**: `/var/log/zfs-protection/backup.log`
- **Scrub Operations**: `/var/log/zfs-protection/scrub.log`
- **Alerts**: `/var/log/zfs-protection/alerts.log`

### Configuration Files
- **Monitoring**: `/etc/zfs-protection/monitor-config.conf`
- **Backup**: `/etc/zfs-protection/backup-config.conf`
- **Scrub**: `/etc/zfs-protection/scrub-config.conf`
- **Alerts**: `/etc/zfs-protection/alert-config.conf`

### Emergency Contacts
Update `/etc/zfs-protection/alert-config.conf` with your contact information:
- Primary administrator
- Secondary on-call engineer
- Escalation contacts
- Vendor support numbers

## 🔒 Security Considerations

### Access Control
- Scripts run as root (required for ZFS operations)
- Configuration files protected (600 permissions)
- Log files readable by admin group
- SSH key-based authentication for remote backups

### Network Security
- Firewall rules for monitoring ports
- VPN for remote backup connections
- Encrypted backup streams (optional)
- Secure webhook endpoints

### Data Protection
- Snapshot encryption (configurable)
- Secure key management
- Audit trail logging
- Compliance reporting

## 🚀 Performance Optimization

### Memory Tuning
The suite automatically configures:
- **ARC size**: 25% of total RAM (1GB minimum, 8GB maximum)
- **Meta limit**: 25% of ARC size
- **TXG timeout**: 5 seconds for consistent performance

### I/O Optimization
- **Record size**: 64K for VMs, 128K for general use
- **Compression**: LZ4 (best performance/ratio balance)
- **Checksum**: SHA256 for data integrity
- **Sync**: Standard for most workloads

### Network Optimization
For remote backups:
- TCP window scaling
- Compression during transfer
- Bandwidth limiting (configurable)
- Resume capability for interrupted transfers

## 📈 Capacity Planning

### Growth Monitoring
- Historical usage trends
- Predictive capacity alerts
- Automated cleanup policies
- Expansion recommendations

### Retention Policies
Default retention (configurable):
- **Hourly**: 24 snapshots (1 day)
- **Daily**: 30 snapshots (1 month)
- **Weekly**: 12 snapshots (3 months)
- **Monthly**: 12 snapshots (1 year)

## 🔄 Upgrade and Maintenance

### Updating the Suite
```bash
# Backup current configuration
tar -czf zfs-protection-backup-$(date +%Y%m%d).tar.gz /etc/zfs-protection/

# Update scripts
git pull origin main

# Restart services
systemctl restart zfs-health-monitor.service
```

### Configuration Migration
The suite preserves configurations during updates. Manual migration may be required for major version changes.

---

## 📝 License

This ZFS Data Corruption Prevention Suite is provided as-is for operational use. Always test in non-production environments before deployment.

## 🤝 Contributing

Issues and improvements welcome. Please test thoroughly before submitting changes that affect data protection mechanisms.

---

**⚠️ Important**: This suite provides protection mechanisms but cannot guarantee against all data loss scenarios. Always maintain proper backups and test recovery procedures regularly.