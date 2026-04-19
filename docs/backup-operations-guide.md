# 🛡️ Backup Operations Guide

**Document Version**: 1.0
**Last Updated**: 2026-02-10
**Classification**: Internal Use - AGL-22 Compliance
**Maintainer**: Hive Mind Collective

---

## 📋 TABLE OF CONTENTS

1. [Overview](#overview)
2. [Backup Architecture](#backup-architecture)
3. [Daily Backup Operations](#daily-backup-operations)
4. [Weekly Backup Operations](#weekly-backup-operations)
5. [Monthly Backup Operations](#monthly-backup-operations)
6. [Backup Validation Procedures](#backup-validation-procedures)
7. [Storage Management](#storage-management)
8. [Emergency Backup Procedures](#emergency-backup-procedures)
9. [Backup Security](#backup-security)
10. [Monitoring and Alerting](#monitoring-and-alerting)
11. [Troubleshooting](#troubleshooting)
12. [Compliance Documentation](#compliance-documentation)

---

## 🎯 Overview

This document provides comprehensive guidance for all backup operations within the AGL infrastructure. The backup system is designed to ensure data protection, business continuity, and compliance with AGL-22 requirements.

### Key Components

- **Primary Storage**: Spark (ZFS pool) - Local backups
- **Secondary Storage**: USB4TB (CIFS mount) - Off-site backups
- **Backup Types**: Full VM/container snapshots
- **Retention Policy**: Tiered based on VM size and importance
- **Compression**: zstd for efficient storage usage

### Backup Goals

- **RPO (Recovery Point Objective)**: 24 hours maximum
- **RTO (Recovery Time Objective)**: 4 hours for critical systems
- **Compliance**: 100% backup success rate for critical VMs
- **Storage Efficiency**: Optimize retention to prevent storage exhaustion

---

## 🏗️ Backup Architecture

### Storage Hierarchy

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│   Local VMs    │     │  Backup Jobs   │     │  Remote Storage │
│                 │     │                 │     │                 │
│ VM 100-200      │────▶│ Daily 03:15     │────▶│ Spark (ZFS)     │
│ CT 101-200      │     │ Daily 03:30     │     │ USB4TB (CIFS)   │
│                 │     │                 │     │                 │
└─────────────────┘     └─────────────────┘     └─────────────────┘
                              │
                              ▼
                       ┌─────────────────┐
                       │  Monitoring    │
                       │                 │
                       │ Health Checks  │
                       │ Alerting       │
                       │ Validation     │
                       │                 │
                       └─────────────────┘
```

### Backup Flow

1. **Daily Snapshots**: 03:15-03:45 AM
2. **Transfer to Local Storage**: Within 1 hour
3. **Off-site Replication**: Within 4 hours
4. **Health Verification**: Within 6 hours
5. **Monthly Validation**: Full restore testing

---

## 📅 Daily Backup Operations

### Standard Daily Procedure

**Time**: 03:00-04:00 AM
**Frequency**: Daily
**Automated**: Yes (Proxmox jobs)

**Checklist**:
- [ ] Verify backup services are running
- [ ] Monitor backup job execution
- [ ] Check storage availability
- [ ] Review backup logs
- [ ] Verify completion status

### Daily Commands

**Start Monitoring**:
```bash
# Check backup job status
pvesh get /cluster/backup

# Monitor real-time backup progress
journalctl -f -u proxmox-backup-service

# Check storage availability
pvesm status -storage spark
```

**Post-Backup Verification**:
```bash
# List recent backups (last 24 hours)
find /mnt/pve/bb/dump/ -name "*.vma.zst" -mtime 0 -ls

# Check backup file integrity
ls -lh /mnt/pve/bb/dump/vzdump-*.vma.zst | tail -10

# Verify backup sizes are reasonable
du -sh /mnt/pve/bb/dump/vzdump-* | sort -h
```

### Small VMs Backup (03:15 AM)

**VM List**: 101, 102, 111, 112, 117, 176
**Retention**: 7 daily + 4 weekly + 6 monthly + 1 yearly
**Storage**: spark

```bash
# Check specific backup job
pvesh get /cluster/backup/jobs/small-vms-backup

# Monitor job execution
pvesh get /cluster/backup/jobs/small-vms-backup/status
```

### Large VMs Backup (03:30 AM)

**VM List**: All remaining VMs (61 total)
**Retention**: keep-last=2 only
**Storage**: spark

```bash
# Check storage usage before backup
pvesm status -storage spark

# Monitor large backup job
pvesh get /cluster/backup/jobs/large-vms-backup/status
```

---

## 📊 Weekly Backup Operations

**Time**: Sunday 01:00 AM
**Frequency**: Weekly
**Automated**: Yes (Proxmox jobs)

### Weekly Tasks

**Storage Pruning**:
```bash
# Prune old backup files automatically handled by Proxmox
# Manual override if needed:
pvesm prune-backups spark --keep-last 7 --type qemu
pvesm prune-backups spark --keep-last 7 --type lxc

# Check retention policy effectiveness
find /mnt/pve/bb/dump/ -name "*.vma.zst" -mtime +14 | wc -l
```

**Off-site Sync Verification**:
```bash
# Check USB4TB connection
mount | grep usb4tb

# Verify recent backups on remote storage
ls -lh /mnt/pve/usb4tb/dump/ | grep "$(date +%Y-%m-%d)"

# Check sync status
ls -la /mnt/pve/usb4tb/dump/ | grep "$(date +%Y-%m-%d)"
```

**Health Monitoring Report**:
```bash
# Generate weekly backup report
cat > /root/weekly-backup-report-$(date +%Y%m%d).txt <<EOF
WEEKLY BACKUP REPORT - $(date)

=== Storage Status ===
$(pvesm status -storage spark)

=== Backup Counts ===
QEMU Backups: $(find /mnt/pve/bb/dump/ -name "*.vma.zst" | wc -l)
LXC Backups: $(find /mnt/pve/bb/dump/ -name "*.tar.zst" | wc -l)

=== Recent Backups (Last 7 days) ===
$(find /mnt/pve/bb/dump/ -name "*.vma.zst" -mtime -7 | sort)

=== Off-site Status ===
USB4TB Mounted: $(mount | grep usb4tb | wc -l)
EOF

# Report summary
echo "Weekly backup report generated: /root/weekly-backup-report-$(date +%Y%m%d).txt"
```

---

## 📈 Monthly Backup Operations

**Time**: First Sunday of month, 02:00 AM
**Frequency**: Monthly
**Automated**: Partial (Requires manual intervention)

### Monthly Tasks Checklist

**1. Full Backup Validation**
```bash
# Select random VM/CT for test restore
RANDOM_VM=$(shuf -i 100-200 -n 1)
echo "Testing restore for VM: $RANDOM_VM"

# Create temporary test environment
qmrestore /mnt/pve/bb/dump/vzdump-qemu-${RANDOM_VM}-*.vma.zst 999 --storage local-zfs

# Start and verify
qm start 999
sleep 120  # Allow boot time
qm status 999

# Verify VM is running
if qm status 999 | grep -q "running"; then
    echo "✅ VM $RANDOM_VM restore test successful"
else
    echo "❌ VM $RANDOM_VM restore test failed"
fi

# Cleanup
qm stop 999
qm destroy 999
```

**2. Storage Optimization**
```bash
# Check current storage usage
echo "Current storage status:"
pvesm status -storage spark

# Calculate backup growth
echo "Backup growth analysis:"
du -sh /mnt/pve/bb/dump/vzdump-* 2>/dev/null | tail -5

# Plan storage capacity if needed
CURRENT_USAGE=$(pvesm status -storage spark | grep "total" | awk '{print $3}')
THRESHOLD=90
if [ ${CURRENT_USAGE%\%} -gt $THRESHOLD ]; then
    echo "⚠️ Storage usage above $THRESHOLD% - review retention policy"
fi
```

**3. Backup Job Review**
```bash
# Review all backup jobs
echo "=== Backup Job Review ==="
pvesh get /cluster/backup

# Check job configurations
echo "=== Job Configurations ==="
cat /etc/pve/jobs.cfg | grep -E "(small-vms|large-vms)"

# Verify retention policies
echo "=== Retention Policy Check ==="
find /mnt/pve/bb/dump/ -name "*.vma.zst" | awk -F'-' '{print $3}' | sort | uniq -c
```

**4. Documentation Update**
```bash
# Update backup schedule documentation
cat > /root/backup-schedule-$(date +%Y%m%d).txt <<EOF
BACKUP SCHEDULE - $(date)

Small VMs (03:15): VMs 101,102,111,112,117,176
  Retention: 7+4+6+1

Large VMs (03:30): All other VMs
  Retention: 2 most recent

Off-site Sync: Daily to USB4TB
Testing: Monthly restore test

Storage Status: $(pvesm status -storage spark | grep "used")
EOF
```

---

## ✅ Backup Validation Procedures

### Automated Validation

**Daily Health Checks**:
```bash
# Backup job success monitoring
BACKUP_LOG="/var/log/pve/tasks/$(date +%Y%m%d).log"
if grep -q "TASK OK.*vzdump" "$BACKUP_LOG"; then
    echo "✅ Daily backup completed successfully"
else
    echo "❌ Backup job failed - check $BACKUP_LOG"
    # Send alert
    curl -X POST "$WEBHOOK_URL" -d "Backup job failed on $(hostname)"
fi
```

**File Integrity Verification**:
```bash
# Check backup file integrity
find /mnt/pve/bb/dump/ -name "*.vma.zst" -exec zstd -t {} \; 2>/dev/null

# Check for corrupted files
CORRUPTED=$(find /mnt/pve/bb/dump/ -name "*.vma.zst" -exec zstd -t {} \; 2>&1 | grep -v "stdout" | wc -l)
if [ $CORRUPTED -gt 0 ]; then
    echo "⚠️ Found $CORRUPTED corrupted backup files"
fi
```

### Manual Validation

**Step-by-Step Verification Process**:

1. **Backup Existence Check**:
```bash
# Verify all expected VMs have recent backups
for vmid in {100..200}; do
    BACKUP_COUNT=$(find /mnt/pve/bb/dump/ -name "vzdump-qemu-${vmid}-*.vma.zst" | wc -l)
    if [ $BACKUP_COUNT -eq 0 ]; then
        echo "❌ No backup found for VM $vmid"
    fi
done
```

2. **Snapshot Integrity Test**:
```bash
# Test ZFS snapshot accessibility
zfs list -t snapshot | grep vm-100-disk-0
zfs mount rpool/vm-100-disk-0@test-snapshot /mnt/test-snapshot
if [ $? -eq 0 ]; then
    echo "✅ Snapshot mount test successful"
    umount /mnt/test-snapshot
else
    echo "❌ Snapshot mount failed"
fi
```

3. **Data Consistency Check**:
```bash
# Compare VM config with backup metadata
pvesh get /nodes/$(hostname)/qemu/100/config > /tmp/vm100-current.conf
# Extract backup metadata
zfs get -r all rpool/vm-100-disk-0@latest | grep "creation"
```

### Quarterly Validation

**Comprehensive Restoration Test**:
```bash
#!/bin/bash
# quarterly-validation.sh

RESTORE_SUCCESS=0
TOTAL_TESTS=3

echo "Starting quarterly backup validation..."

# Test 1: Small VM Restore
TEST_VM=102
qmrestore /mnt/pve/bb/dump/vzdump-qemu-${TEST_VM}-*.vma.zst 999 --storage local-zfs
qm start 999 2>/dev/null
sleep 90
if qm status 999 | grep -q "running"; then
    ((RESTORE_SUCCESS++))
    echo "✅ Small VM restore test passed"
else
    echo "❌ Small VM restore test failed"
fi
qm stop 999 >/dev/null 2>&1
qm destroy 999 >/dev/null 2>&1

# Test 2: Large VM Restore
TEST_VM=150
qmrestore /mnt/pve/bb/dump/vzdump-qemu-${TEST_VM}-*.vma.zst 998 --storage local-zfs
qm start 998 2>/dev/null
sleep 120
if qm status 998 | grep -q "running"; then
    ((RESTORE_SUCCESS++))
    echo "✅ Large VM restore test passed"
else
    echo "❌ Large VM restore test failed"
fi
qm stop 998 >/dev/null 2>&1
qm destroy 998 >/dev/null 2>&1

# Test 3: Container Restore
TEST_CT=111
pct restore 111 /mnt/pve/bb/dump/vzdump-lxc-${TEST_CT}-*.tar.zst
pct start 111 2>/dev/null
sleep 60
if pct status 111 | grep -q "running"; then
    ((RESTORE_SUCCESS++))
    echo "✅ Container restore test passed"
else
    echo "❌ Container restore test failed"
fi

echo "Validation Results: $RESTORE_SUCCESS/$TOTAL_TESTS successful"
if [ $RESTORE_SUCCESS -eq $TOTAL_TESTS ]; then
    echo "✅ All validation tests passed"
else
    echo "❌ Some validation tests failed - investigate immediately"
fi

# Cleanup
rm -f /tmp/validation-*.log
```

---

## 💾 Storage Management

### Storage Monitoring

**Daily Storage Checks**:
```bash
#!/bin/bash
# storage-monitor.sh

STORAGE="/mnt/pve/bb/dump"
THRESHOLD=85

# Calculate usage
USAGE=$(df -h $STORAGE | awk 'NR==2 {print $5}' | tr -d '%')
CURRENT=$(df -h $STORAGE | awk 'NR==2 {print $4}')
TOTAL=$(df -h $STORAGE | awk 'NR==2 {print $2}')

echo "Storage Status: $USAGE% used ($CURRENT free of $TOTAL)"

# Alert if over threshold
if [ $USAGE -gt $THRESHOLD ]; then
    echo "⚠️ Storage usage above ${THRESHOLD}%!"

    # Check backup counts
    echo "Backup statistics:"
    echo "  QEMU backups: $(find $STORAGE -name "*.vma.zst" | wc -l)"
    echo "  LXC backups: $(find $STORAGE -name "*.tar.zst" | wc -l)"

    # List oldest backups for pruning consideration
    echo "Oldest backups for potential pruning:"
    find $STORAGE -name "*.vma.zst" -printf "%T@ %p\n" | sort -n | head -5
fi
```

### Backup Pruning Procedures

**Manual Pruning**:
```bash
# Emergency pruning (use with caution)
pvesm prune-backups spark --keep-last 1 --type qemu
pvesm prune-backups spark --keep-last 1 --type lxc

# Targeted pruning by VM
# Remove all backups for specific VM
find /mnt/pve/bb/dump/ -name "vzdump-qemu-100-*.vma.zst" -delete

# Remove old backups (older than 30 days)
find /mnt/pve/bb/dump/ -name "*.vma.zst" -mtime +30 -delete
```

**Automated Pruning Schedule**:
```bash
# Add to crontab for daily pruning
# 04:00 every night prune to retention limits
0 4 * * * /usr/bin/pvesm prune-backups spark --keep-last 7 --type qemu >> /var/log/prune.log 2>&1
0 4 * * * /usr/bin/pvesm prune-backups spark --keep-last 7 --type lxc >> /var/log/prune.log 2>&1
```

### Storage Expansion Planning

**Capacity Planning**:
```bash
#!/bin/bash
# capacity-planner.sh

BACKUP_DIR="/mnt/pve/bb/dump"
DAYS_TO_PROJECT=90

# Calculate daily growth
TODAY=$(date +%Y%m%d)
PAST_WEEK=$(date -d "7 days ago" +%Y%m%d)
WEEKLY_GROWTH=$(du -sb $BACKUP_DIR | cut -f1)
MONTHLY_GROWTH=$(($WEEKLY_GROWTH * 4))

# Project future needs
PROJECTED_NEED=$(($MONTHLY_GROWTH * ($DAYS_TO_PROJECT/30)))
CURRENT_FREE=$(df -k $BACKUP_DIR | awk 'NR==2 {print $4}')

echo "Capacity Projection:"
echo "Current free: $((CURRENT_FREE/1024/1024)) GB"
echo "Monthly growth: $((MONTHLY_GROWTH/1024/1024)) GB"
echo "$DAYS_TO_PROJECT day projection: $((PROJECTED_NEED/1024/1024)) GB"

# Check if expansion needed
if [ $PROJECTED_NEED -gt $CURRENT_FREE ]; then
    echo "⚠️ Storage expansion needed in $DAYS_TO_PROJECT days"
    echo "Recommended capacity: $(((PROJECTED_NEED*120/1024/1024/100+1)*100)) GB"
fi
```

---

## 🚨 Emergency Backup Procedures

### Critical System Failure Response

**Immediate Actions (First 15 minutes)**:

1. **Assess Current Backup State**:
```bash
# Check what backups are available
BACKUP_COUNT=$(find /mnt/pve/bb/dump/ -name "*.vma.zst" | wc -l)
echo "Available backups: $BACKUP_COUNT"

# Check recent backups
echo "Recent backups (last 24 hours):"
find /mnt/pve/bb/dump/ -name "*.vma.zst" -mtime 0 -printf "%T@ %p\n" | sort -n
```

2. **Create Emergency Backup**:
```bash
# For critical VMs, create immediate snapshot
CRITICAL_VMS="100 105 150"  # List critical VM IDs
for vm in $CRITICAL_VMS; do
    # Create emergency snapshot
    qm suspend $vm 2>/dev/null || true

    # Create immediate backup
    vzdump $vm --mode snapshot --compress zstd --storage spark --node $(hostname)
    echo "Emergency backup started for VM $vm"
done
```

### Partial System Failure

**VM-Level Recovery**:
```bash
# If specific VM is lost but backups exist
VMID=100
BACKUP_FILE=$(ls -t /mnt/pve/bb/dump/vzdump-qemu-${VMID}-*.vma.zst | head -1)

# Restore with new ID
qmrestore "$BACKUP_FILE" ${VMID}_recovered --storage local-zfs

# Configure networking
qm set ${VMID}_recovered --net0 name=eth0,bridge=vmbr0,ip=dhcp

# Start VM
qm start ${VMID}_recovered
```

### Complete System Recovery

**Step-by-Step Recovery Process**:

1. **Prepare Environment**:
```bash
# Mount backup storage
mkdir -p /mnt/recovery
mount /dev/sdX1 /mnt/recovery  # Replace with actual device

# Verify backup availability
ls /mnt/recovery/dump/ | wc -l
```

2. **Restore Proxmox Configuration**:
```bash
# If /etc/pve is lost, create basic config
mkdir -p /etc/pve/nodes/$(hostname)
mkdir -p /etc/pve/{private,storage}
touch /etc/pve/ncd/ceph.conf
touch /etc/pve/priv/storage/ssh1.cron

# Start Proxmox services
systemctl start pve-cluster
systemctl start pvedaemon
systemctl start corosync
```

3. **Restore VMs Systematically**:
```bash
#!/bin/bash
# systematic-restore.sh

RESTORE_ORDER="100 105 150 110 120"  # Critical VMs first
NEW_BASE=300  # Starting ID for restored VMs

for vmid in $RESTORE_ORDER; do
    BACKUP_FILE=$(ls -t /mnt/recovery/dump/vzdump-qemu-${vmid}-*.vma.zst | head -1)
    if [ -n "$BACKUP_FILE" ]; then
        NEW_VMID=$((NEW_BASE))
        echo "Restoring VM $vmid to $NEW_VMID..."

        qmrestore "$BACKUP_FILE" $NEW_VMID --storage local-zfs

        # Update configuration
       qm set $NEW_VMID --net0 name=eth0,bridge=vmbr0,ip=dhcp

        # Start VM
        qm start $NEW_VMID

        # Wait for boot
        sleep 180

        ((NEW_BASE++))
    else
        echo "⚠️ No backup found for VM $vmid"
    fi
done
```

### Off-site Backup Recovery

**USB4TB Recovery Procedure**:
```bash
# Check USB4TB connection
if ! mount | grep -q usb4tb; then
    mount -t cifs //192.168.0.100/usb4tb /mnt/pve/usb4tb -o username=admin,password=securepass
fi

# List available backups
ls -la /mnt/pve/usb4tb/dump/ | grep "$(date +%Y)"

# Restore from off-site
OFFSITE_BACKUP=$(ls -t /mnt/pve/usb4tb/dump/vzdump-qemu-100-*.vma.zst | head -1)
if [ -n "$OFFSITE_BACKUP" ]; then
    qmrestore "$OFFSITE_BACKUP" 990 --storage local-zfs
    echo "Off-site recovery initiated"
fi
```

---

## 🔐 Backup Security

### Access Control

**File Permissions**:
```bash
# Set proper permissions on backup directory
chmod 700 /mnt/pve/bb/dump
chown root:root /mnt/pve/bb/dump

# Restrict access to backup files
find /mnt/pve/bb/dump/ -name "*.vma.zst" -chmod 600
find /mnt/pve/bb/dump/ -name "*.tar.zst" -chmod 600
```

**User Access Management**:
```bash
# Backup user creation
useradd -m backupadmin
usermod -aG backup backupadmin

# Set secure password
echo "backupadmin:securepassword" | chpasswd

# SSH key for remote backup access
mkdir -p /home/backupadmin/.ssh
chmod 700 /home/backupadmin/.ssh
cp /root/.ssh/authorized_keys /home/backupadmin/.ssh/
chown -R backupadmin:backupadmin /home/backupadmin/.ssh
```

### Encryption

**Backup Encryption Setup**:
```bash
# Install encryption tools
apt install gpg

# Create encryption key
gpg --batch --gen-key <<EOF
Key-Type: RSA
Key-Length: 4096
Subkey-Type: RSA
Subkey-Length: 4096
Name-Real: Backup Encryption Key
Name-Email: backup@agl.local
Expire-Date: 0
%no-protection
EOF

# Export public key for distribution
gpg --export --armor backup@agl.local > /etc/pve/backup-public-key.asc

# Encrypt backup files
find /mnt/pve/bb/dump/ -name "*.vma.zst" -exec gpg --encrypt --recipient backup@agl.local {} \;
```

**Backup Verification**:
```bash
# Verify encrypted backups
for file in /mnt/pve/bb/dump/*.gpg; do
    gpg --list-packets "$file" >/dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo "✅ $file is valid"
    else
        echo "❌ $file is corrupted"
    fi
done
```

### Audit Logging

**Backup Activity Monitoring**:
```bash
# Enable detailed logging
echo "log-file = /var/log/pve/backup.log" >> /etc/pve/jobs.cfg

# Monitor backup activities
tail -f /var/log/pve/backup.log | grep -E "(vzdump|backup|restore)"

# Log backup completion
BACKUP_LOG="/var/log/pve/completed-backups-$(date +%Y%m%d).log"
pvesh get /cluster/backup | grep "TASK OK" >> "$BACKUP_LOG"
```

---

## 📡 Monitoring and Alerting

### System Monitoring

**Daily Health Checks** (cron job):
```bash
#!/bin/bash
# daily-backup-health.sh

BACKUP_DIR="/mnt/pve/bb/dump"
ALERT_EMAIL="admin@agl.local"
THRESHOLD=85

# Check storage usage
USAGE=$(df -h $BACKUP_DIR | awk 'NR==2 {print $5}' | tr -d '%')

if [ $USAGE -gt $THRESHOLD ]; then
    mail -s "BACKUP ALERT: Storage ${USAGE}% used on $(hostname)" "$ALERT_EMAIL" <<EOF
Alert: Backup storage is ${USAGE}% full on $(hostname)
Location: $BACKUP_DIR
Current capacity: $(df -h $BACKUP_DIR | awk 'NR==2 {print $2}')
Free space: $(df -h $BACKUP_DIR | awk 'NR==2 {print $4}')

Immediate action required to prevent backup failures.
EOF
fi

# Check for failed backups
FAILED_JOBS=$(journalctl -u proxmox-backup-service --since "24 hours ago" | grep -i "error" | wc -l)
if [ $FAILED_JOBS -gt 0 ]; then
    mail -s "BACKUP ALERT: $FAILED_JOBS failed jobs on $(hostname)" "$ALERT_EMAIL" <<EOF
Failed backup jobs detected in the last 24 hours:

$(journalctl -u proxmox-backup-service --since "24 hours ago" | grep -i "error")

Investigate immediately.
EOF
fi
```

### Dashboard Metrics

**Proxmox Backup Dashboard**:
```bash
#!/bin/bash
# backup-metrics.sh

# Generate backup summary
echo "=== AGL Backup Status ==="
echo "Generated: $(date)"
echo "Host: $(hostname)"
echo ""

echo "=== Storage Status ==="
pvesm status -storage spark | grep -E "(total|used|avail)"
echo ""

echo "=== Backup Counts ==="
echo "QEMU VMs: $(find /mnt/pve/bb/dump/ -name "*.vma.zst" | wc -l)"
echo "LXC CTs: $(find /mnt/pve/bb/dump/ -name "*.tar.zst" | wc -l)"
echo ""

echo "=== Recent Backups (Last 24h) ==="
find /mnt/pve/bb/dump/ -name "*.vma.zst" -mtime 0 | sort | tail -5
echo ""

echo "=== Job Status ==="
pvesh get /cluster/backup | grep -E "(schedule|status)"
echo ""

echo "=== Off-site Status ==="
if mount | grep -q usb4tb; then
    echo "USB4TB: Mounted and ready"
    echo "Recent off-site backups: $(ls /mnt/pve/usb4tb/dump/ | grep "$(date +%Y-%m-%d)" | wc -l)"
else
    echo "USB4TB: Not mounted - CHECK IMMEDIATELY"
fi
```

### Alert Thresholds

**Critical Alerts** (Immediate action):
- Backup storage > 90% full
- Failed backup jobs > 2 in 24 hours
- Off-site backup sync failure
- Encryption verification failure

**Warning Alerts** (Monitor within 24 hours):
- Backup storage > 75% full
- Failed backup jobs = 1 in 24 hours
- Backup validation test failure
- Performance degradation > 50%

---

## 🔧 Troubleshooting

### Common Backup Issues

**Issue 1: Backup Job Fails**

```bash
# Check backup job logs
tail -f /var/log/pve/tasks/$(date +%Y%m%d).log

# Check disk space
df -h /mnt/pve/bb/dump/

# Check storage status
pvesm status -storage spark

# Reset failed job
pvesh delete /cluster/backup/jobs/job-id
```

**Issue 2: Storage Full**

```bash
# Check storage usage
pvesm status -storage spark

# Manual pruning
pvesm prune-backups spark --keep-last 1 --type qemu
pvesm prune-backups spark --keep-last 1 --type lxc

# Check for large backup files
ls -lh /mnt/pve/bb/dump/vzdump-* | sort -k5 -hr | head -10
```

**Issue 3: Backup Access Problems**

```bash
# Check permissions
ls -la /mnt/pve/bb/dump/

# Check ZFS mount status
zpool list rpool
zfs list | grep dump

# Remount if needed
mount -t zfs rpool/dump /mnt/pve/bb/dump
```

### Performance Optimization

**Backup Performance Tuning**:
```bash
# Check backup speed
echo "Monitoring backup performance..."
while true; do
    DU=$(du -sb /mnt/pve/bb/dump/ 2>/dev/null | cut -f1)
    TIMESTAMP=$(date)
    echo "$TIMESTAMP: $DU bytes backed up"
    sleep 300
done

# Adjust Proxmox backup settings
# Edit /etc/pve/jobs.cfg to add:
# compression: zstd
# mode: snapshot
# throttle: 0
```

**Network Optimization for Off-site Sync**:
```bash
# Increase buffer size for large transfers
echo "net.core.rmem_max = 16777216" >> /etc/sysctl.conf
echo "net.core.wmem_max = 16777216" >> /etc/sysctl.conf
sysctl -p

# Use rsync with compression for off-site sync
rsync -avz --delete /mnt/pve/bb/dump/ /mnt/pve/usb4tb/dump/
```

---

## 📋 Compliance Documentation

### AGL-22 Compliance Requirements

**Backup Success Rate**
- **Requirement**: 100% for critical systems
- **Monitoring**: Daily validation
- **Action Plan**: Immediate investigation on any failure

**Retention Policy**
- **Requirement**: Minimum 7 days for all systems
- **Critical Systems**: 30 days + monthly + yearly
- **Verification**: Monthly audit report

**Off-site Backups**
- **Requirement**: Daily sync to off-site location
- **Verification**: Daily mount check
- **Recovery**: Quarterly restore test

**Documentation Updates**
- **Requirement**: Quarterly reviews
- **Current Status**: ✅ Updated 2026-02-10

### Audit Trail

**Compliance Log**:
```bash
#!/bin/bash
# compliance-logger.sh

LOG_FILE="/var/log/agl-compliance.log"
DATE=$(date)

# Log backup completion
echo "[$DATE] Backup completion check" >> "$LOG_FILE"
pvesh get /cluster/backup | grep "TASK OK" >> "$LOG_FILE"

# Log storage compliance
echo "[$DATE] Storage compliance check" >> "$LOG_FILE"
USAGE=$(df -h /mnt/pve/bb/dump | awk 'NR==2 {print $5}')
echo "Storage usage: $USAGE" >> "$LOG_FILE"

# Log off-site status
if mount | grep -q usb4tb; then
    echo "[$DATE] Off-site backup: Synced" >> "$LOG_FILE"
else
    echo "[$DATE] OFF-SITE BACKUP FAILURE" >> "$LOG_FILE"
fi

echo "Compliance log updated"
```

### Change Management

**Backup Configuration Changes**:
```bash
# Document all configuration changes
CONFIG_LOG="/var/log/backup-config-changes.log"
CHANGE_DATE=$(date)
CHANGE_TYPE=$1
CHANGE_DETAILS=$2

echo "[$CHANGE_DATE] $CHANGE_TYPE: $CHANGE_DETAILS" >> "$CONFIG_LOG"

# Require approval for changes
echo "Change submitted for review:"
echo "Type: $CHANGE_TYPE"
echo "Details: $CHANGE_DETAILS"
echo "Submitter: $USER"
echo "Time: $(date)"
```

---

## 📚 Related Documentation

- [Disaster Recovery Runbook](/mnt/overpower/apps/dev/agl/agl-hostman/docs/disaster-recovery-runbook.md)
- [Backup Retention Policy](/mnt/overpower/apps/dev/agl/agl-hostman/docs/BACKUP_RETENTION_POLICY.md)
- [SLA Compliance Guide](/mnt/overpower/apps/dev/agl/agl-hostman/docs/sla-compliance-guide.md)
- [Backup Troubleshooting Guide](/mnt/overpower/apps/dev/agl/agl-hostman/docs/backup-troubleshooting.md)

---

**Document Control**:
- **Version**: 1.0
- **Status**: Active
- **Next Review**: 2026-05-10
- **Approver**: Hive Mind Collective

**END OF BACKUP OPERATIONS GUIDE**