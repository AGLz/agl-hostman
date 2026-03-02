# AGLSRV1 Backup Solutions - Quick Reference Guide

## Situation Summary

**Current State:**
- Spark pool: 6.54TB used / 6.86TB total (94% full, **CRITICAL**)
- 23 VMs + 36 CTs requiring backups
- VM 147 (agldv01): 34GB backup, development critical
- rpool: 1.5TB FREE (99% available, **UNDERUTILIZED**)

**Problem:** Insufficient storage for backup retention

---

## Solution Rankings

| Rank | Solution | Time | Cost | Space Freed | Risk |
|------|----------|------|------|-------------|------|
| **#1** | **A+D+F: Reduce Retention + Incrementals + Cleanup** | 2hrs | $0 | **2.8TB** | LOW |
| **#2** | **B: Enable Compression** | 1hr | $0 | **6TB effective** | LOW |
| **#3** | **C: Use rpool for Hot Backups** | 4hrs | $0 | **500GB hot tier** | LOW |
| **#4** | **D: PBS Incremental (verify)** | 1hr | $0 | **5.4TB** | LOW |
| **#5** | **E: Add 4TB Disk** | 2wks | $150 | **4TB permanent** | MED |
| **#6** | **F: Lock Cleanup + Schedule** | 1hr | $0 | Reliability | LOW |

---

## Recommended Action Plan

### IMMEDIATE (Today) - Choose One:

#### **Option 1: Conservative (Safest)**
```bash
# Reduce retention from 7 to 4 backups
pvesh set /cluster/backup/backup-usb-tier1-sql-6h \
  -prune-backups keep-last=4,keep-weekly=1,keep-monthly=1,keep-yearly=1

vzdump --remove 1

# Result: Free ~2TB immediately, minimal risk
```

#### **Option 2: Aggressive (Most Effective)**
```bash
# 1. Enable compression
zfs set compression=lz4 spark/base

# 2. Reduce retention
pvesh set /cluster/backup/backup-usb-tier1-sql-6h \
  -prune-backups keep-last=3,keep-weekly=1,keep-monthly=1,keep-yearly=1
vzdump --remove 1

# 3. Use rpool for critical VMs
zfs create rpool/backup-hot
pvesm add dir rpool-backup --path /rpool/backup-hot --content backup

# Result: Free ~3TB + 2x future capacity + fast restore tier
```

### WEEK 1

```bash
# Implement monitoring
wget -O /usr/local/bin/backup-health-monitor.sh \
  https://your-script-location/backup-health-monitor.sh
chmod +x /usr/local/bin/backup-health-monitor.sh
crontab -e  # Add: */15 * * * * /usr/local/bin/backup-health-monitor.sh

# Verify PBS incremental
ssh root@192.168.0.232 "proxmox-backup-manager datastore list"
```

### WEEK 2-4 (Optional)

```bash
# Setup cloud archival (Backblaze B2)
apt install rclone -y
rclone config create b2backup b2
# Cost: $10/month for 2TB offsite

# Archive old backups
find /spark/base/dump -mtime +30 -exec rclone copy {} b2backup:archive/ \;
```

---

## Quick Commands Reference

### Check Storage Status
```bash
# Overall storage
zpool list
df -h /spark /rpool /overpower

# Backup locations
du -sh /spark/base/dump/*
du -sh /mnt/pve/usb4tb/dump/*
```

### Clear Stuck Locks
```bash
# VERIFY NO BACKUPS RUNNING FIRST
ps aux | grep vzdump

# If clear, remove locks
rm -f /var/lock/vzdump.lock
find /var/lock -name "*qemu*.lock" -delete
find /spark/base/dump -name "*.lck" -delete
```

### Manual Prune
```bash
# List old backups
find /spark/base/dump -name "*.vma.zst" -mtime +30 -ls

# Remove backups older than 30 days
find /spark/base/dump -name "*.vma.zst" -mtime +30 -delete

# Trigger Proxmox prune
vzdump --remove 1
```

### Check Backup Job Status
```bash
# List all jobs
pvesh get /cluster/backup

# Recent tasks
pvesh get /cluster/tasks --typefilter backup --limit 10

# Failed backups
pvesh get /cluster/tasks --typefilter backup --errors 1
```

---

## Decision Matrix

### If You Have:

**< 1 Hour Available:**
→ Option F (Lock cleanup) + reduce retention to keep-last=4

**1-2 Hours Available:**
→ Option A + F (Reduce retention + cleanup) = 2TB freed

**Half Day Available:**
→ Option A + B + C (Retention + compression + rpool) = 8TB effective

**Budget Available ($150):**
→ Do Option A+B+C first, then order 4TB disk for permanent solution

**Cloud Budget ($10/mo):**
→ Setup Backblaze B2 archival for offsite protection

---

## Space Savings Cheat Sheet

| Action | Space Freed | Time | Reversible? |
|--------|-------------|------|-------------|
| keep-last: 7→4 | ~2.0TB | 1hr | Yes |
| keep-last: 7→3 | ~2.8TB | 1hr | Yes |
| Enable LZ4 compression | +6TB effective | 1hr | Yes* |
| PBS incrementals | ~5.4TB | 0hr** | N/A |
| Archive to cloud | 2TB | 1day | Yes |
| Delete backups >90 days | Varies | 15min | NO |
| Add 4TB disk | +4TB | 2wks | NO*** |

\* Compression only affects new data
\** Already enabled, just verify
\*** Cannot remove disk from ZFS pool once added

---

## Risk Assessment

### LOW RISK (Safe to Execute)
- Reduce retention: 7→4 (still 4 restore points)
- Enable LZ4 compression (minimal CPU overhead)
- Lock cleanup (if verified no backups running)
- Use rpool storage (1.5TB free available)
- PBS verification (read-only check)

### MEDIUM RISK (Test First)
- Reduce retention: 7→3 (limited restore window)
- Cloud integration (verify restore before relying)
- Add disk to ZFS pool (cannot undo, plan carefully)

### HIGH RISK (Avoid Unless Desperate)
- Delete backups >30 days without archival
- Disable backups to free space
- Modify running backup jobs during execution

---

## Emergency Procedures

### If Backup Fails Due to No Space:

```bash
# 1. Immediate space creation
find /spark/base/dump -name "*.vma.zst" -mtime +60 -delete

# 2. Verify space freed
df -h /spark

# 3. Retry backup
vzdump <VMID> --storage spark --mode snapshot --compress zstd
```

### If Spark Pool Reaches 100%:

```bash
# CRITICAL: ZFS performs poorly at >95%
# Emergency cleanup:

# 1. Delete oldest backups
cd /spark/base/dump
ls -t *.vma.zst | tail -20 | xargs rm -f

# 2. Clear ZFS snapshots if any
zfs list -t snapshot spark | tail -10 | awk '{print $1}' | xargs -n1 zfs destroy

# 3. Verify below 90%
zpool list spark
```

### If VM 147 Backup Fails:

```bash
# Use rpool instead (plenty of space)
vzdump 147 --storage rpool --mode snapshot --compress zstd

# Or backup to USB4TB
vzdump 147 --storage usb4tb --mode snapshot --compress zstd
```

---

## Success Criteria

### After Implementation, Verify:

```bash
# Storage health
zpool list spark  # Should show <80% used

# Backup success
pvesh get /cluster/tasks --typefilter backup --limit 5 --errors 0

# No stuck locks
find /var/lock -name "*vzdump*"  # Should be empty when not backing up

# Compression active
zfs get compression spark/base  # Should show 'lz4'

# Space trend
df -h /spark  # Monitor daily, should be stable or decreasing
```

---

## Support Contacts

**Documentation Location:** `/root/host-admin/claudedocs/`
- Full report: `AGLSRV1_Backup_Solution_Options_Report.md`
- This guide: `AGLSRV1_Solution_Quick_Reference.md`

**Monitoring Logs:**
- Backup health: `/var/log/backup-health.log`
- Proxmox tasks: Web UI → Datacenter → Tasks
- ZFS status: `zpool status` and `zpool list`

---

**Last Updated:** 2025-10-07
**Priority:** CRITICAL - Implement within 24-48 hours
**Recommended:** Start with Option 1 (Conservative) today, Option 2 (Aggressive) this week
