# 🔧 Backup Troubleshooting Guide

**Document Version**: 1.0
**Last Updated**: 2026-02-10
**Classification**: Internal Use - AGL-22 Compliance
**Maintainer**: Hive Mind Collective

---

## 📋 TABLE OF CONTENTS

1. [Common Backup Issues](#common-backup-issues)
2. [Error Code Reference](#error-code-reference)
3. [Performance Troubleshooting](#performance-troubleshooting)
4. [Storage Issues](#storage-issues)
5. [Network Problems](#network-problems)
6. [VM/CT Specific Issues](#vmct-specific-issues)
7. [Recovery Failures](#recovery-failures)
8. [Monitoring and Diagnostics](#monitoring-and-diagnostics)
9. [Preventive Measures](#preventive-measures)
10. [Escalation Procedures](#escalation-procedures)

---

## 🔴 Common Backup Issues

### Issue 1: Backup Job Fails with "Storage not available"

**Error Message**:
```
TASK ERROR: storage 'spark' not available
```

**Root Cause**: Proxmox storage disconnected or unavailable

**Solution**:

```bash
# Check storage status
pvesm status -storage spark

# Remount ZFS storage if needed
zpool import -f rpool
zfs mount rpool/dump

# Check ZFS pool status
zpool status rpool

# Restart storage services
systemctl restart pve-storage
systemctl restart proxmox-backup-service
```

**Prevention**:
- Add storage monitoring to daily checks
- Configure automatic remount scripts
- Set up storage alerts

### Issue 2: Backup Job Stuck at "Starting" State

**Symptoms**:
- Backup job shows "running" but no progress
- High I/O wait on host
- Job persists for hours

**Solution**:

```bash
# Check job status details
pvesh get /cluster/backup/jobs/<job-id>/status

# Check for stuck processes
ps aux | grep vzdump

# Kill stuck job
pvesh delete /cluster/backup/jobs/<job-id>

# Clear any temporary files
rm -f /var/tmp/vzdump.*

# Restart backup service
systemctl restart proxmox-backup-service
```

**Prevention**:
- Implement job timeout mechanisms
- Monitor backup progress in real-time
- Regular service restarts

### Issue 3: Backup File Corruption Detected

**Symptoms**:
- Backup files won't restore
- ZFS reports checksum errors
- File size seems incorrect

**Solution**:

```bash
# Check file integrity
zstd -t /mnt/pve/bb/dump/vzdump-qemu-100-*.vma.zst

# Check for partial files
find /mnt/pve/bb/dump/ -name "*.vma.zst" -size 0 -delete

# Recreate corrupted backup
vzdump 100 --mode snapshot --compress zstd --storage spark --node $(hostname)

# If persistent issue, check storage health
zpool scrub rpool
```

**Prevention**:
- Regular integrity checks
- Multiple backup copies
- Storage monitoring

---

## ⚠️ Error Code Reference

### Proxmox Backup Error Codes

| Error Code | Description | Solution |
|------------|-------------|----------|
| **100** | Storage not available | Check ZFS mount, remount storage |
| **200** | Disk space insufficient | Clear space, increase retention |
| **300** | Permission denied | Check file permissions, root access |
| **400** | Network timeout | Check network connectivity, increase timeout |
| **500** | VM/CT not running | Start VM before backup |
| **600** | Backup file corrupted | Recreate backup, check storage |
| **700** | Compression error | Recreate with different compression |
| **800** | Memory allocation failed | Increase available memory |

### ZFS Error Codes

| Error Code | Description | Solution |
|------------|-------------|----------|
| **EIO** | I/O error | Check disk health, replace if needed |
| **ENOSPC** | No space left | Clear space, add storage |
| **EFAULT** | Bad address | Check filesystem corruption |
| **ENOMEM** | Out of memory | Increase swap, check memory leaks |
| **ENXIO** | No such device | Check disk connections |

### Custom Error Handling

```bash
#!/bin/bash
# error-handler.sh

ERROR_CODE=$1
BACKUP_JOB=$2

case $ERROR_CODE in
    100)
        echo "Storage error - attempting remount"
        zpool import -f rpool
        ;;
    200)
        echo "Space error - clearing old backups"
        pvesm prune-backups spark --keep-last 2
        ;;
    400)
        echo "Network timeout - retrying with extended timeout"
        vzdump $BACKUP_JOB --mode snapshot --timeout 7200
        ;;
    600)
        echo "Corruption detected - recreating backup"
        vzdump $BACKUP_JOB --compress zstd --storage spark
        ;;
    *)
        echo "Unknown error $ERROR_CODE - manual intervention required"
        # Create incident ticket
        curl -X POST "$INCIDENT_WEBHOOK" -d "Backup error $ERROR_CODE for job $BACKUP_JOB"
        ;;
esac
```

---

## 📊 Performance Troubleshooting

### Slow Backup Performance

**Symptoms**:
- Backup taking much longer than usual
- High CPU usage during backup
- Network saturation

**Diagnostic Commands**:

```bash
# Monitor backup progress in real-time
while true; do
    echo "=== $(date) ==="
    du -sh /mnt/pve/bb/dump/vzdump-* 2>/dev/null | tail -5
    sleep 300
done

# Check system resources during backup
iotop -o -b -n 1
htop -u root

# Network throughput monitoring
nload -u 1000 -d 5
```

**Optimization Solutions**:

```bash
# Adjust Proxmox backup settings
# Edit /etc/pve/jobs.cfg to add:
# throttle: 0
# compression: zstd
# mode: snapshot

# Increase system resources for backup
echo "vm.swappiness=10" >> /etc/sysctl.conf
sysctl -p

# Tune ZFS for backup performance
echo "zfs:zfs_prefetch_disable=1" > /etc/sysctl.d/99-zfs.conf
sysctl -p
```

### Memory Issues During Backup

**Symptoms**:
- OOM killer terminating processes
- Backup jobs failing with memory errors

**Solution**:

```bash
# Check memory usage
free -h
cat /proc/meminfo

# Adjust memory limits
# Add to /etc/pve/jobs.cfg:
# max-memory: 2048
# balloon: 0

# Monitor memory during backup
watch -n 5 'free -h && echo "VM Memory:" && ps aux | grep -E "(vzdump|qemu)"'

# If persistent, increase swap
fallocate -l 4G /swapfile
chmod 600 /swapfile
mkswap /swapfile
swapon /swapfile
echo "/swapfile none swap defaults 0 0" >> /etc/fstab
```

### I/O Performance Bottlenecks

**Symptoms**:
- High disk wait times
- Slow write operations
- Backup progress stalling

**Solution**:

```bash
# Check I/O statistics
iostat -x 1 5

# Check ZFS performance metrics
zpool iostat -v 1 5

# Tune ZFS for better performance
echo "zfs:zfs_arc_max=4294967296" > /etc/sysctl.d/99-zfs.conf
echo "zfs:zfs_vdev_async_write_max_active=100" >> /etc/sysctl.d/99-zfs.conf
sysctl -p

# Consider using SSD for ZFS cache
echo "cache device /dev/sdb" >> /etc/zfs/zpool.conf
```

---

## 💾 Storage Issues

### Storage Full - Immediate Actions

```bash
#!/bin/bash
# storage-emergency.sh

STORAGE="/mnt/pve/bb/dump"
THRESHOLD=90

# Get current usage
USAGE=$(df -h $STORAGE | awk 'NR==2 {print $5}' | tr -d '%')

if [ $USAGE -gt $THRESHOLD ]; then
    echo "⚠️ Storage usage: ${USAGE}% - Emergency measures needed"

    # Step 1: Prune aggressively
    pvesm prune-backups spark --keep-last 1 --type qemu
    pvesm prune-backups spark --keep-last 1 --type lxc

    # Step 2: Remove test/restore files
    find $STORAGE -name "*_test*" -delete
    find $STORAGE -name "*_temp*" -delete

    # Step 3: Check largest files
    echo "Largest files:"
    ls -lh $STORAGE/*.vma.zst | sort -k5 -hr | head -10

    # Step 4: Manual removal if needed
    echo "Manual removal required for largest files?"
    read -p "Enter file pattern to remove: " PATTERN
    if [ -n "$PATTERN" ]; then
        find $STORAGE -name "$PATTERN" -delete
    fi

    # Final check
    USAGE_NEW=$(df -h $STORAGE | awk 'NR==2 {print $5}' | tr -d '%')
    echo "New usage: ${USAGE_NEW}%"
fi
```

### ZFS Pool Issues

**Scenario: Pool Degraded**

```bash
# Check pool status
zpool status rpool

# Attempt to clear transient errors
zpool clear rpool

# If device is actually faulted:
# 1. Emergency snapshot
zfs snapshot -r rpool@emergency-$(date +%Y%m%d)

# 2. Replace device
zpool replace rpool old-device new-device

# 3. Wait for resilvering
watch -n 30 'zpool status rpool'
```

**Scenario: Scrub Errors**

```bash
# Start manual scrub
zpool scrub rpool

# Monitor progress
while true; do
    echo "$(date): Scrub status"
    zpool status rpool | grep scrub
    sleep 300
done

# If errors found:
zpool status -v | grep "errors:"

# Replace corrupted data if needed
zpool scrub rpool
```

### Mount Issues

**CIFS Mount Problems**:

```bash
# Check mount status
mount | grep usb4tb

# Remount CIFS share
umount /mnt/pve/usb4tb
mount -t cifs //192.168.0.100/usb4tb /mnt/pve/usb4tb \
    -o username=admin,password=securepass,vers=3.0

# Test connectivity
ping 192.168.0.100

# Check share accessibility
ls -la /mnt/pve/usb4tb/
```

**ZFS Mount Issues**:

```bash
# Check ZFS mounts
zfs list | grep mountpoint

# Mount specific dataset
zfs mount rpool/dump

# Force remount entire pool
zpool export rpool
zpool import -f rpool
zfs mount -a
```

---

## 🌐 Network Problems

### Backup Sync Failures

**Symptoms**:
- Off-site backup sync failing
- Network timeout errors
- Slow transfer speeds

**Solution**:

```bash
# Test network connectivity
ping 192.168.0.100
traceroute 192.168.0.100

# Check CIFS mount
mount | grep usb4tb
df -h /mnt/pve/usb4tb

# Test file transfer speed
dd if=/dev/zero of=/mnt/pve/usb4tb/testfile bs=1M count=100
ls -lh /mnt/pve/usb4tb/testfile

# Network tuning
echo "net.core.rmem_max = 16777216" >> /etc/sysctl.conf
echo "net.core.wmem_max = 16777216" >> /etc/sysctl.conf
sysctl -p
```

### Bandwidth Throttling

**Symptoms**:
- Network affecting VM performance during backup
- Slow backup speeds affecting production

**Solution**:

```bash
# Configure Proxmox to limit bandwidth
# Edit /etc/pve/jobs.cfg:
# throttle: 1024  # Limit to 1MB/s

# Use tc for advanced throttling
tc qdisc add dev eth0 root handle 1: htb
tc class add dev eth0 parent 1: classid 1:1 htb rate 100mbit
tc class add dev eth0 parent 1:1 classid 1:10 htb rate 1mbit
tc filter add dev eth0 protocol ip parent 1:0 prio 0 u32 match ip dport 8006 0xffff flowid 1:10

# Monitor bandwidth usage
nload -u 1000 -d 5
```

---

## 🖥️ VM/CT Specific Issues

### VM Backup Issues

**Issue: VM Fails to Backup**

```bash
# Check VM status
qm status 100

# Check VM locks
qm lockinfo 100

# Stop VM if necessary
qm stop 100 --skiplock

# Retry backup
vzdump 100 --mode snapshot --compress zstd --storage spark

# If persistent, check VM configuration
qm config 100
```

**Issue: VM Backup Too Large**

```bash
# Check VM disk usage
qm disk 100

# Clean up VM before backup
qm resize 100 scsi0 50G  # Reduce disk size

# Use linked clones if possible
qm clone 100 100_backup --full

# Backup the clone instead
```

### Container Backup Issues

**Issue: Container Backup Corruption**

```bash
# Check container status
pct status 111

# Check container filesystem
pct exec 111 df -h

# Create emergency backup
pct stop 111
vzdump 111 --mode snapshot --compress zstd --storage spark

# If backup corrupted, try different compression
vzdump 111 --mode snapshot --compress gzip --storage spark
```

**Issue: Container Won't Stop**

```bash
# Force stop container
pct stop 111 --skiplock

# Kill processes if needed
lxc-stop -n 111 --kill
kill -9 $(lxc-info -n 111 -p | grep PID | awk '{print $2}')

# Reset container state
pct set 111 --onboot 0
pct start 111
```

### Network Configuration Issues

**Issue: VM Network Connectivity After Restore**

```bash
# Check VM network configuration
qm config 100 | grep net

# Update network settings
qm set 100 --net0 name=eth0,bridge=vmbr0,ip=dhcp

# Or set static IP
qm set 100 --net0 name=eth0,bridge=vmbr0,ip=192.168.0.100/24,gateway=192.168.0.1

# Restart VM
qm reboot 100
```

---

## 🔄 Recovery Failures

### VM Restore Failure

**Issue: VM Won't Start After Restore**

```bash
# Check VM configuration
qm config 200

# Check disk status
qm disk 200

# Reattach disk if needed
qm set 200 --scsi0 local-zfs:vm-200-disk-0

# Fix boot order
qm set 200 --boot order=scsi0

# Try starting with debug
qm start 200 --debug
```

**Issue: VM Missing After Restore**

```bash
# Scan for restored VMs
qm rescan --vmid=all

# Check VM configuration files
ls -la /etc/pve/nodes/$(hostname)/qemu/

# Manually recreate VM if needed
qm create 200 --cdrom none --agent 1 --boot order=scsi0 --cores 2 --memory 4096 --net0 virtio,bridge=vmbr0 --scsi0 local-zfs:vm-200-disk-0
```

### Container Restore Failure

**Issue: Container Won't Start**

```bash
# Check container configuration
pct config 111

# Check root filesystem
zfs list rpool/subvol-111-disk-0

# Recreate rootfs if corrupted
pct stop 111
zfs rollback rpool/subvol-111-disk-0@clean-snapshot
pct start 111

# Or restore from backup
pct restore 111 /mnt/pve/bb/dump/vzdump-lxc-111-*.tar.zst
```

### Configuration Mismatch Issues

**Issue: Configuration After Restore**

```bash
# Compare configurations
diff /etc/pve/nodes/$(hostname)/qemu/100.conf /etc/pve/nodes/$(hostname)/qemu/100_new.conf

# Update configuration with original settings
qm set 100 --cores 4 --memory 8192

# Update network if needed
qm set 100 --delete net0
qm set 100 --net0 virtio,bridge=vmbr0,ip=192.168.0.100/24
```

---

## 🔍 Monitoring and Diagnostics

### Real-time Monitoring

```bash
#!/bin/bash
# real-time-monitor.sh

while true; do
    clear
    echo "=== AGL BACKUP MONITORING ==="
    echo "Time: $(date)"
    echo ""

    echo "=== SYSTEM STATUS ==="
    uptime
    echo ""

    echo "=== STORAGE USAGE ==="
    pvesm status -storage spark | grep -E "(total|used|avail)"
    echo ""

    echo "=== BACKUP JOBS ==="
    pvesh get /cluster/backup | grep -E "(schedule|status)"
    echo ""

    echo "=== VM STATUS ==="
    qm list | grep -E "(running|stopped)"
    echo ""

    echo "=== NETWORK ==="
    ip a | grep -E "inet "
    echo ""

    sleep 10
done
```

### Log Analysis

```bash
#!/bin/bash
# log-analyzer.sh

# Analyze backup logs
echo "=== RECENT BACKUP LOGS ==="
journalctl -u proxmox-backup-service --since "1 hour ago" | grep -E "(error|failed|success)"

# Check for common error patterns
echo "=== ERROR PATTERN ANALYSIS ==="
grep -i "error\|failed\|exception" /var/log/pve/tasks/*.log | tail -10

# Performance metrics
echo "=== PERFORMANCE METRICS ==="
grep "vzdump" /var/log/pve/tasks/*.log | grep -E "(duration|size)" | tail -5

# Generate alert if issues found
ERROR_COUNT=$(grep -i "error\|failed" /var/log/pve/tasks/*.log | wc -l)
if [ $ERROR_COUNT -gt 5 ]; then
    echo "⚠️ High error count detected: $ERROR_COUNT"
    # Send alert
    curl -X POST "$ALERT_WEBHOOK" -d "High error count: $ERROR_COUNT"
fi
```

### Performance Baselines

```bash
#!/bin/bash
# performance-baseline.sh

# Create performance baseline
BASELINE_FILE="/root/performance-baseline-$(date +%Y%m%d).txt"

echo "Performance Baseline - $(date)" > "$BASELINE_FILE"
echo "======================================" >> "$BASELINE_FILE"

# System metrics
echo "System:" >> "$BASELINE_FILE"
uptime >> "$BASELINE_FILE"
free -h >> "$BASELINE_FILE"
echo "" >> "$BASELINE_FILE"

# Storage metrics
echo "Storage:" >> "$BASELINE_FILE"
pvesm status -storage spark >> "$BASELINE_FILE"
echo "" >> "$BASELINE_FILE"

# Backup performance
echo "Backup Performance:" >> "$BASELINE_FILE"
du -sh /mnt/pve/bb/dump/ >> "$BASELINE_FILE"
find /mnt/pve/bb/dump/ -name "*.vma.zst" | wc -l >> "$BASELINE_FILE"
echo "" >> "$BASELINE_FILE"

# Network performance
echo "Network Performance:" >> "$BASELINE_FILE"
ping -c 3 8.8.8.8 >> "$BASELINE_FILE"
echo "" >> "$BASELINE_FILE"

echo "Baseline saved to: $BASELINE_FILE"
```

---

## 🛡️ Preventive Measures

### Regular Health Checks

```bash
#!/bin/bash
# health-check.sh

# Daily health check
HEALTH_LOG="/var/log/health-check-$(date +%Y%m%d).log"
DATE=$(date)

echo "=== DAILY HEALTH CHECK ===" > "$HEALTH_LOG"
echo "Date: $DATE" >> "$HEALTH_LOG"

# Check storage
STORAGE_USAGE=$(df -h /mnt/pve/bb/dump | awk 'NR==2 {print $5}')
echo "Storage usage: $STORAGE_USAGE" >> "$HEALTH_LOG"

if [ ${STORAGE_USAGE%\%} -gt 85 ]; then
    echo "❌ Storage usage critical" >> "$HEALTH_LOG"
else
    echo "✅ Storage OK" >> "$HEALTH_LOG"
fi

# Check backup jobs
BACKUP_STATUS=$(pvesh get /cluster/backup | grep "status" | grep -v "active")
if echo "$BACKUP_STATUS" | grep -q "OK"; then
    echo "✅ Backup jobs OK" >> "$HEALTH_LOG"
else
    echo "❌ Backup job issues detected" >> "$HEALTH_LOG"
fi

# Check VMs
RUNNING_VMS=$(qm list | grep -c "running")
TOTAL_VMS=$(qm list | wc -l -l)
echo "VMs: $RUNNING_VMS/$TOTAL_VMS running" >> "$HEALTH_LOG"

if [ $RUNNING_VMS -eq 0 ]; then
    echo "❌ No VMs running - critical issue" >> "$HEALTH_LOG"
elif [ $RUNNING_VMS -lt $((TOTAL_VMS / 2)) ]; then
    echo "⚠️ Many VMs offline" >> "$HEALTH_LOG"
else
    echo "✅ VMs OK" >> "$HEALTH_LOG"
fi

echo "Health check completed"
```

### Automated Maintenance

```bash
#!/bin/bash
# maintenance.sh

# Weekly maintenance tasks
WEEKLY_MAINT="/root/weekly-maintenance-$(date +%Y%m%d).log"

echo "=== WEEKLY MAINTENANCE ===" > "$WEEKLY_MAINT"
echo "Date: $(date)" >> "$WEEKLY_MAINT"

# ZFS scrub
echo "Starting ZFS scrub..."
zpool scrub rpool
while zpool scrub rpool | grep -q "scrub in progress"; do
    sleep 300
done
zpool status rpool >> "$WEEKLY_MAINT"

# Backup cleanup
echo "Pruning old backups..."
pvesm prune-backups spark --keep-last 7 --type qemu
pvesm prune-backups spark --keep-last 7 --type lxc

# System update check
echo "Checking for updates..."
apt list --upgradable 2>/dev/null >> "$WEEKLY_MAINT"

# Log rotation
echo "Rotating logs..."
logrotate -f /etc/logrotate.conf

echo "Maintenance completed"
```

### Configuration Validation

```bash
#!/bin/bash
# config-validation.sh

# Validate all backup job configurations
JOB_DIR="/etc/pve/jobs"
VALIDATION_LOG="/root/config-validation-$(date +%Y%m%d).log"

echo "=== CONFIGURATION VALIDATION ===" > "$VALIDATION_LOG"
echo "Date: $(date)" >> "$VALIDATION_LOG"

for job_file in $JOB_DIR/*.cfg; do
    if [ -f "$job_file" ]; then
        job_id=$(basename "$job_file" .cfg)
        echo "Validating job: $job_id" >> "$VALIDATION_LOG"

        # Check job configuration
        if grep -q "storage.*spark" "$job_file"; then
            echo "✅ Storage configured" >> "$VALIDATION_LOG"
        else
            echo "❌ Storage not configured" >> "$VALIDATION_LOG"
        fi

        if grep -q "schedule.*03:" "$job_file"; then
            echo "✅ Schedule configured" >> "$VALIDATION_LOG"
        else
            echo "❌ Schedule missing" >> "$VALIDATION_LOG"
        fi

        # Test job configuration
        if pvesh get /cluster/backup/jobs/$job_id >/dev/null 2>&1; then
            echo "✅ Job accessible via API" >> "$VALIDATION_LOG"
        else
            echo "❌ Job not accessible" >> "$VALIDATION_LOG"
        fi
    fi
done

echo "Configuration validation completed"
```

---

## 📞 Escalation Procedures

### Alert Thresholds

```bash
#!/bin/bash
# escalation-monitor.sh

ALERT_LEVEL=$1
MESSAGE=$2

case $ALERT_LEVEL in
    "CRITICAL")
        # Critical alert - immediate escalation
        curl -X POST "$CRITICAL_WEBHOOK" -d "$MESSAGE"
        curl -X POST "$SMS_WEBHOOK" -d "CRITICAL: $MESSAGE"
        # Pager duty
        curl -X POST "$PAGERDUTY_WEBHOOK" -d "event_type=trigger&service_key=$PAGERDUTY_KEY&description=$MESSAGE"
        ;;
    "HIGH")
        # High priority alert
        curl -X POST "$HIGH_WEBHOOK" -d "$MESSAGE"
        curl -X POST "$EMAIL_WEBHOOK" -d "Subject: HIGH PRIORITY ALERT\n\n$MESSAGE"
        ;;
    "MEDIUM")
        # Medium priority alert
        curl -X POST "$MEDIUM_WEBHOOK" -d "$MESSAGE"
        ;;
    "LOW")
        # Low priority alert - log only
        echo "$(date): LOW: $MESSAGE" >> /var/log/backup-alerts.log
        ;;
esac
```

### Incident Management

```bash
#!/bin/bash
# incident-manager.sh

INCIDENT_ID=$(date +%Y%m%d-%H%M%S)
SEVERITY=$1
INCIDENT_TYPE=$2
DESCRIPTION=$3

# Create incident ticket
INCIDENT_FILE="/root/incidents/${INCIDENT_ID}.md"

cat > "$INCIDENT_FILE" <<EOF
# INCIDENT REPORT: $INCIDENT_ID

**Severity**: $SEVERITY
**Type**: $INCIDENT_TYPE
**Date**: $(date)
**Reporter**: $USER

## Description
$DESCRIPTION

## Timeline
- **$(date)**: Incident detected
- **[ ]**: [Time] - Action taken
- **[ ]**: [Time] - Resolution achieved

## Systems Affected
- [ ] List affected systems

## Actions Taken
- [ ] [Initial action]
- [ ] [Investigation steps]

## Root Cause
[ ] To be determined

## Resolution Status
- [ ] Open
- [ ] In Progress
- [ ] Resolved

## Follow-up
- [ ] [Follow-up action]
- [ ] [Post-mortem required]
EOF

# Alert incident management system
curl -X POST "$INCIDENT_WEBHOOK" \
    -H "Content-Type: application/json" \
    -d "{
        'incident_id': '$INCIDENT_ID',
        'severity': '$SEVERITY',
        'type': '$INCIDENT_TYPE',
        'description': '$DESCRIPTION',
        'timestamp': '$(date)',
        'status': 'open'
    }"

echo "Incident created: $INCIDENT_FILE"
```

### Emergency Response Team Contact

```bash
#!/bin/bash
# emergency-contacts.sh

EMERGENCY_LEVEL=$1

case $EMERGENCY_LEVEL in
    "P1")
        # Critical - notify everyone
        curl -X POST "$TEAM_WEBHOOK" -d "@-"
        curl -X POST "$MANAGER_WEBHOOK" -d "@-"
        curl -X POST "$EXTERNAL_SUPPORT_WEBHOOK" -d "@-"
        ;;
    "P2")
        # High priority - core team
        curl -X POST "$TEAM_WEBHOOK" -d "@-"
        curl -X POST "$MANAGER_WEBHOOK" -d "@-"
        ;;
    "P3")
        # Medium priority - on-call team
        curl -X POST "$ONCALL_WEBHOOK" -d "@-"
        ;;
esac <<EOF
Emergency Alert Level: $EMERGENCY_LEVEL
Time: $(date)
Incident: [Description]
Systems Affected: [List]
Estimated Impact: [Description]
EOF
```

---

## 📚 Related Documentation

- [Backup Operations Guide](/mnt/overpower/apps/dev/agl/agl-hostman/docs/backup-operations-guide.md)
- [Disaster Recovery Runbook](/mnt/overpower/apps/dev/agl/agl-hostman/docs/disaster-recovery-runbook.md)
- [SLA Compliance Guide](/mnt/overpower/apps/dev/agl/agl-hostman/docs/sla-compliance-guide.md)
- [Backup Retention Policy](/mnt/overpower/apps/dev/agl/agl-hostman/docs/BACKUP_RETENTION_POLICY.md)

---

**Document Control**:
- **Version**: 1.0
- **Status**: Active
- **Next Review**: 2026-05-10
- **Approver**: Hive Mind Collective

**END OF BACKUP TROUBLESHOOTING GUIDE**