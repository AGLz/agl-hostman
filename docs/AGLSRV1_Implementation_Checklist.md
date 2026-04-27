# AGLSRV1 Backup Solution - Implementation Checklist

## Pre-Implementation Verification

### [ ] System Health Check
```bash
# Run these commands to verify current state:
ssh root@algsrv1 << 'EOF'
  echo "=== Storage Status ==="
  zpool list
  df -h /spark /rpool /overpower

  echo -e "\n=== Active Backups ==="
  ps aux | grep vzdump

  echo -e "\n=== Recent Backup Tasks ==="
  pvesh get /cluster/tasks --typefilter backup --limit 5

  echo -e "\n=== Current Backup Jobs ==="
  pvesh get /cluster/backup

  echo -e "\n=== Lock Files ==="
  find /var/lock -name "*vzdump*" -ls
EOF
```

**Expected Results:**
- Spark: ~94% used (critical)
- rpool: ~1% used (plenty of space)
- Active backups: 0 (or note running jobs)
- Lock files: None (or identify stuck locks)

### [ ] Backup Current Configuration
```bash
ssh root@algsrv1 << 'EOF'
  mkdir -p /root/backup-config-$(date +%Y%m%d)
  cp -a /etc/pve/jobs.cfg /root/backup-config-$(date +%Y%m%d)/
  pvesh get /cluster/backup --output-format json-pretty > /root/backup-config-$(date +%Y%m%d)/backup-jobs.json
  zpool status > /root/backup-config-$(date +%Y%m%d)/zpool-status.txt
  df -h > /root/backup-config-$(date +%Y%m%d)/df-before.txt
EOF
```

---

## Phase 1: Immediate Relief (1-2 Hours)

### [ ] Task 1.1: Clear Stuck Locks (if any)

**CAUTION:** Only run if verified no backups are running!

```bash
ssh root@algsrv1 << 'EOF'
  # Verify no backups running
  RUNNING=$(ps aux | grep vzdump | grep -v grep)
  if [ -z "$RUNNING" ]; then
    echo "No backups running - safe to clear locks"

    # Clear locks
    rm -f /var/lock/vzdump.lock
    find /var/lock -name "*qemu-server*.lock" -delete
    find /spark/base/dump -name "*.lck" -delete
    find /mnt/pve/usb4tb/dump -name "*.lck" -delete 2>/dev/null

    echo "Locks cleared"
  else
    echo "WARNING: Backups are running - DO NOT clear locks"
    echo "$RUNNING"
  fi
EOF
```

**Status:** [ ] Complete | [ ] Skipped (no locks found) | [ ] Deferred (backups running)

### [ ] Task 1.2: Reduce Backup Retention

**Choose retention level:**
- [ ] Conservative: keep-last=4 (saves ~2TB)
- [ ] Aggressive: keep-last=3 (saves ~2.8TB)

```bash
# Option A: Conservative (keep-last=4)
ssh root@algsrv1 << 'EOF'
  # Update all USB backup jobs
  for job in $(pvesh get /cluster/backup --output-format json | jq -r '.[] | select(.storage=="usb4tb") | .id'); do
    echo "Updating job: $job"
    pvesh set /cluster/backup/$job \
      -prune-backups keep-last=4,keep-weekly=1,keep-monthly=1,keep-yearly=1
  done

  # Update all PBS backup jobs
  for job in $(pvesh get /cluster/backup --output-format json | jq -r '.[] | select(.storage=="man6b-pbs") | .id'); do
    echo "Updating job: $job"
    pvesh set /cluster/backup/$job \
      -prune-backups keep-last=4,keep-weekly=1,keep-monthly=1,keep-yearly=1
  done
EOF
```

```bash
# Option B: Aggressive (keep-last=3) - MORE SPACE SAVINGS
ssh root@algsrv1 << 'EOF'
  # Update all USB backup jobs
  for job in $(pvesh get /cluster/backup --output-format json | jq -r '.[] | select(.storage=="usb4tb") | .id'); do
    echo "Updating job: $job"
    pvesh set /cluster/backup/$job \
      -prune-backups keep-last=3,keep-weekly=1,keep-monthly=1,keep-yearly=1
  done

  # Update all PBS backup jobs
  for job in $(pvesh get /cluster/backup --output-format json | jq -r '.[] | select(.storage=="man6b-pbs") | .id'); do
    echo "Updating job: $job"
    pvesh set /cluster/backup/$job \
      -prune-backups keep-last=3,keep-weekly=1,keep-monthly=1,keep-yearly=1
  done
EOF
```

**Status:** [ ] Complete - Option: ______ (A/B)

### [ ] Task 1.3: Trigger Prune Operations

**WARNING:** This will delete old backups. Verify retention settings first!

```bash
ssh root@algsrv1 << 'EOF'
  echo "=== Current retention settings ==="
  pvesh get /cluster/backup --output-format json | jq -r '.[] | "\(.id): \(.["prune-backups"])"'

  echo -e "\n=== Triggering prune (this may take 10-30 minutes) ==="
  vzdump --remove 1 --all 0

  echo -e "\n=== Prune initiated - monitor with: ==="
  echo "tail -f /var/log/pve/tasks/*vzdump*.log"
EOF
```

**Monitor progress:**
```bash
ssh root@algsrv1 "tail -f /var/log/pve/tasks/\$(ls -t /var/log/pve/tasks/ | grep vzdump | head -1)"
```

**Status:** [ ] Complete | [ ] In Progress (monitor log)

### [ ] Task 1.4: Verify Space Freed

```bash
ssh root@algsrv1 << 'EOF'
  echo "=== Storage Status After Prune ==="
  zpool list spark
  df -h /spark

  echo -e "\n=== Backup Count Verification ==="
  echo "USB4TB backups:"
  find /mnt/pve/usb4tb/dump -name "*.vma.zst" 2>/dev/null | wc -l

  echo "Spark backups:"
  find /spark/base/dump -name "*.vma.zst" 2>/dev/null | wc -l
EOF
```

**Expected:** Spark usage should drop from 94% to 50-60%

**Actual Result:** ________% used (fill after verification)

**Status:** [ ] Success (>30% freed) | [ ] Partial (<30% freed) | [ ] Failed (proceed to Phase 2)

---

## Phase 2: Optimization (2-4 Hours)

### [ ] Task 2.1: Enable ZFS Compression

```bash
ssh root@algsrv1 << 'EOF'
  echo "=== Current Compression Status ==="
  zfs get compression,compressratio spark/base

  echo -e "\n=== Enabling LZ4 Compression ==="
  zfs set compression=lz4 spark/base
  zfs set compression=lz4 spark/base/dump

  echo -e "\n=== Verification ==="
  zfs get compression spark/base

  echo "Note: Compression only affects NEW data written"
  echo "Existing data compression ratio will improve over time"
EOF
```

**Status:** [ ] Complete

### [ ] Task 2.2: Create rpool Hot Backup Tier

```bash
ssh root@algsrv1 << 'EOF'
  echo "=== Creating rpool backup storage ==="

  # Create dataset
  zfs create rpool/backup-hot
  zfs set quota=500G rpool/backup-hot
  zfs set compression=lz4 rpool/backup-hot
  zfs set mountpoint=/rpool/backup-hot rpool/backup-hot

  # Create dump directory
  mkdir -p /rpool/backup-hot/dump
  chmod 755 /rpool/backup-hot/dump

  # Add to Proxmox storage
  pvesm add dir rpool-backup \
    --path /rpool/backup-hot/dump \
    --content backup \
    --maxfiles 4 \
    --prune-backups keep-last=4

  echo "=== Verification ==="
  zfs list rpool/backup-hot
  pvesm status | grep rpool-backup
EOF
```

**Status:** [ ] Complete

### [ ] Task 2.3: Create Hot Tier Backup Job for VM 147

```bash
ssh root@algsrv1 << 'EOF'
  echo "=== Creating rpool backup job for VM 147 ==="

  pvesh create /cluster/backup \
    --id backup-rpool-vm147-hot \
    --comment "RPOOL-Hot-VM147-Daily" \
    --storage rpool-backup \
    --vmid 147 \
    --schedule '04:30' \
    --dow mon,tue,wed,thu,fri,sat,sun \
    --mode snapshot \
    --compress zstd \
    --zstd 3 \
    --prune-backups keep-last=4 \
    --mailnotification failure \
    --enabled 1

  echo "=== Verification ==="
  pvesh get /cluster/backup/backup-rpool-vm147-hot
EOF
```

**Status:** [ ] Complete

### [ ] Task 2.4: Install Backup Health Monitor

```bash
ssh root@algsrv1 << 'EOF'
  echo "=== Installing Backup Health Monitor ==="

  cat > /usr/local/bin/backup-health-monitor.sh << 'SCRIPT'
#!/bin/bash
# AGLSRV1 Backup Health Monitor

LOG_FILE="/var/log/backup-health.log"

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

# Check storage capacity
SPARK_PCT=$(df /spark | tail -1 | awk '{print $5}' | sed 's/%//')
RPOOL_PCT=$(df /rpool | tail -1 | awk '{print $5}' | sed 's/%//')

if [ "$SPARK_PCT" -gt 90 ]; then
  log "CRITICAL: Spark at ${SPARK_PCT}% - immediate action required"
elif [ "$SPARK_PCT" -gt 80 ]; then
  log "WARNING: Spark at ${SPARK_PCT}% - plan cleanup soon"
fi

# Check for stuck locks
if [ -z "$(ps aux | grep vzdump | grep -v grep)" ]; then
  LOCKS=$(find /var/lock -name "*vzdump*" 2>/dev/null)
  if [ -n "$LOCKS" ]; then
    log "WARNING: Stuck locks detected without active backup - cleanup recommended"
  fi
fi

# Check for long-running backups
LONG_BACKUP=$(ps aux | grep vzdump | grep -v grep | awk '$10 > "03:00:00" {print $2}')
if [ -n "$LONG_BACKUP" ]; then
  log "WARNING: Long-running backup (>3hrs) - PID: $LONG_BACKUP"
fi

# Check recent failures
FAILURES=$(pvesh get /cluster/tasks --errors 1 --typefilter backup --limit 1 2>/dev/null | grep -c UPID)
if [ "$FAILURES" -gt 0 ]; then
  log "ERROR: Recent backup failures detected - check Proxmox UI"
fi

log "Health check OK - Spark: ${SPARK_PCT}%, rpool: ${RPOOL_PCT}%"
SCRIPT

  chmod +x /usr/local/bin/backup-health-monitor.sh

  # Create cron job
  cat > /etc/cron.d/backup-health << 'CRON'
# AGLSRV1 Backup Health Monitoring
*/15 * * * * root /usr/local/bin/backup-health-monitor.sh
CRON

  echo "=== Testing monitor ==="
  /usr/local/bin/backup-health-monitor.sh

  echo "Monitor installed - check /var/log/backup-health.log"
EOF
```

**Status:** [ ] Complete

---

## Phase 3: Verification (30 Minutes)

### [ ] Task 3.1: Verify Backup Job Configuration

```bash
ssh root@algsrv1 << 'EOF'
  echo "=== Current Backup Jobs ==="
  pvesh get /cluster/backup --output-format json | \
    jq -r '.[] | "\(.id): VMs=\(.vmid) Storage=\(.storage) Retention=\(.["prune-backups"])"'
EOF
```

**Expected:**
- All jobs show reduced retention (keep-last=3 or 4)
- VM 147 has rpool-backup job
- PBS jobs still configured

**Status:** [ ] Verified

### [ ] Task 3.2: Test Backup to rpool

```bash
ssh root@algsrv1 << 'EOF'
  echo "=== Testing manual backup of VM 147 to rpool ==="
  vzdump 147 --storage rpool-backup --mode snapshot --compress zstd --remove 0

  echo -e "\n=== Verify backup created ==="
  ls -lh /rpool/backup-hot/dump/vzdump-qemu-147-*
EOF
```

**Status:** [ ] Success | [ ] Failed (check logs)

### [ ] Task 3.3: Storage Capacity Trend Check

```bash
ssh root@algsrv1 << 'EOF'
  echo "=== Storage Summary ==="
  echo "BEFORE (from backup file):"
  cat /root/backup-config-*/df-before.txt | grep -E "spark|rpool"

  echo -e "\nAFTER (current):"
  df -h | grep -E "spark|rpool"

  echo -e "\n=== Space Freed ==="
  BEFORE=$(cat /root/backup-config-*/df-before.txt | grep spark | awk '{print $3}')
  AFTER=$(df -h | grep spark | awk '{print $3}')
  echo "Before: $BEFORE"
  echo "After: $AFTER"
EOF
```

**Result:** Freed _________ GB/TB (fill in actual)

**Status:** [ ] Acceptable (>500GB freed) | [ ] Insufficient (proceed to Phase 4)

---

## Phase 4: Optional Cloud Archival (1-2 Days)

### [ ] Task 4.1: Install and Configure rclone

```bash
ssh root@algsrv1 << 'EOF'
  # Install rclone
  apt update && apt install rclone -y

  echo "rclone installed - manual configuration required:"
  echo "1. Sign up for Backblaze B2 account"
  echo "2. Create application key"
  echo "3. Run: rclone config"
  echo "4. Choose 'b2' provider"
  echo "5. Name it: b2backup"
EOF
```

**Manual Steps Required:**
1. [ ] Create Backblaze B2 account
2. [ ] Create bucket: aglsrv1-archive
3. [ ] Generate application key
4. [ ] Run `rclone config` interactively

**Status:** [ ] Complete | [ ] Deferred

### [ ] Task 4.2: Create Cloud Sync Script

```bash
ssh root@algsrv1 << 'EOF'
  cat > /usr/local/bin/backup-cloud-sync.sh << 'SCRIPT'
#!/bin/bash
# Archive old backups to Backblaze B2

BACKUP_DIRS="/spark/base/dump /mnt/pve/usb4tb/dump"
CUTOFF_DAYS=30
ARCHIVE_TARGET="b2backup:aglsrv1-archive"

log() {
  echo "[$(date)] $*" | tee -a /var/log/cloud-backup-sync.log
}

for DIR in $BACKUP_DIRS; do
  [ ! -d "$DIR" ] && continue

  log "Scanning: $DIR"

  find "$DIR" -type f -name "*.vma.zst" -mtime +${CUTOFF_DAYS} | while read backup; do
    BASENAME=$(basename "$backup")

    # Check if already in cloud
    if rclone ls "${ARCHIVE_TARGET}/${BASENAME}" &>/dev/null; then
      log "Already archived: $BASENAME"
      continue
    fi

    log "Uploading: $BASENAME"
    if rclone copy "$backup" "${ARCHIVE_TARGET}/" --progress --transfers 2; then
      # Verify upload
      if rclone ls "${ARCHIVE_TARGET}/${BASENAME}" &>/dev/null; then
        log "Upload verified, removing local: $BASENAME"
        rm -f "$backup"
      else
        log "ERROR: Upload verification failed: $BASENAME"
      fi
    else
      log "ERROR: Upload failed: $BASENAME"
    fi
  done
done

log "Cloud sync completed"
SCRIPT

  chmod +x /usr/local/bin/backup-cloud-sync.sh

  # Schedule weekly (Sundays at 2 AM)
  cat > /etc/cron.d/cloud-backup-sync << 'CRON'
0 2 * * 0 root /usr/local/bin/backup-cloud-sync.sh
CRON

  echo "Cloud sync script installed"
EOF
```

**Status:** [ ] Complete | [ ] Deferred

### [ ] Task 4.3: Test Cloud Upload

```bash
ssh root@algsrv1 << 'EOF'
  # Test with a small file first
  echo "Test upload to B2" > /tmp/test-upload.txt

  if rclone copy /tmp/test-upload.txt b2backup:aglsrv1-archive/; then
    echo "SUCCESS: Cloud upload working"
    rclone ls b2backup:aglsrv1-archive/test-upload.txt
    rm /tmp/test-upload.txt
  else
    echo "FAILED: Check rclone configuration"
  fi
EOF
```

**Status:** [ ] Success | [ ] Failed | [ ] Deferred

---

## Phase 5: Long-Term Storage Expansion (2-4 Weeks)

### [ ] Task 5.1: Capacity Planning

**Current State Assessment:**
- Spark total: 6.86TB
- Current usage (before optimization): 6.54TB (94%)
- Usage after Phase 1-2: ______TB (______%)
- Projected growth rate: ______GB/month
- Months until next critical (>80%): ______

**Expansion Decision:**
- [ ] Not needed (optimization sufficient)
- [ ] Needed - proceed to disk procurement
- [ ] Deferred - revisit in ______ months

**Status:** [ ] Assessment complete

### [ ] Task 5.2: Disk Procurement (if needed)

**Recommended Specifications:**
- [ ] 4TB enterprise SATA (7200 RPM, 256MB cache)
- [ ] 8TB enterprise SATA (for longer runway)
- [ ] NVMe option (if performance critical)

**Vendors:**
- [ ] WD Red Pro / WD Ultrastar
- [ ] Seagate IronWolf Pro / Exos
- [ ] Toshiba N300 Pro

**Estimated Cost:** $______
**Procurement Date:** ______
**Expected Delivery:** ______

**Status:** [ ] Ordered | [ ] Received | [ ] Not needed

### [ ] Task 5.3: Disk Installation & Pool Expansion

**CAUTION:** Plan carefully - disks cannot be removed from ZFS pools!

```bash
# After physical disk installation
ssh root@algsrv1 << 'EOF'
  # Identify new disk
  lsblk

  # EXAMPLE - adjust device name as needed
  NEW_DISK="/dev/sdc"

  # Check pool structure
  zpool status spark

  # Option A: Add as mirror (for redundancy)
  # zpool attach spark sda ${NEW_DISK}

  # Option B: Add as new vdev (for capacity)
  # zpool add spark ${NEW_DISK}

  echo "MANUAL INTERVENTION REQUIRED"
  echo "Choose expansion method based on pool structure"
EOF
```

**Status:** [ ] Complete | [ ] Deferred | [ ] Not needed

---

## Post-Implementation Validation

### [ ] Week 1 Check (7 Days After Implementation)

```bash
ssh root@algsrv1 << 'EOF'
  echo "=== Week 1 Health Check ==="

  echo "1. Storage Utilization:"
  df -h /spark /rpool | tail -2

  echo -e "\n2. Backup Success Rate:"
  TOTAL=$(pvesh get /cluster/tasks --typefilter backup --limit 50 | grep -c UPID)
  FAILED=$(pvesh get /cluster/tasks --typefilter backup --errors 1 --limit 50 | grep -c UPID)
  SUCCESS=$((TOTAL - FAILED))
  echo "Total: $TOTAL, Success: $SUCCESS, Failed: $FAILED"
  echo "Success Rate: $(( SUCCESS * 100 / TOTAL ))%"

  echo -e "\n3. Compression Ratio:"
  zfs get compressratio spark/base

  echo -e "\n4. Health Monitor Log:"
  tail -20 /var/log/backup-health.log
EOF
```

**Expected Results:**
- [ ] Spark usage: <70%
- [ ] Backup success rate: >95%
- [ ] Compression ratio: >1.2x
- [ ] No critical warnings in health log

**Status:** [ ] All checks passed | [ ] Issues found (document below)

**Issues (if any):**
```
[Write any issues or anomalies here]
```

### [ ] Month 1 Check (30 Days After Implementation)

```bash
ssh root@algsrv1 << 'EOF'
  echo "=== Month 1 Trend Analysis ==="

  echo "1. Storage Growth Rate:"
  # Compare to baseline
  BASELINE=$(cat /root/backup-config-*/df-before.txt | grep spark | awk '{print $3}')
  CURRENT=$(df -h /spark | tail -1 | awk '{print $3}')
  echo "Baseline (before): $BASELINE"
  echo "Current (30 days): $CURRENT"

  echo -e "\n2. Backup Performance:"
  echo "Average backup duration (last 10 VM 147 backups):"
  pvesh get /cluster/tasks --typefilter backup --limit 100 | \
    grep "vm-147" | head -10

  echo -e "\n3. Cloud Archival (if enabled):"
  [ -f /var/log/cloud-backup-sync.log ] && tail -20 /var/log/cloud-backup-sync.log

  echo -e "\n4. Effective Compression:"
  zfs get used,compressratio,logicalused spark/base
EOF
```

**Expected Results:**
- [ ] Storage growth: <50GB/month
- [ ] VM 147 backup duration: <20 minutes
- [ ] Cloud archival: Working (if enabled)
- [ ] Effective compression: >1.5x

**Status:** [ ] Healthy trend | [ ] Needs attention

---

## Rollback Procedures

### If You Need to Undo Changes:

#### Rollback Task 1.2 (Restore Original Retention)
```bash
ssh root@algsrv1 << 'EOF'
  # Restore keep-last=7
  for job in $(pvesh get /cluster/backup --output-format json | jq -r '.[].id'); do
    pvesh set /cluster/backup/$job \
      -prune-backups keep-last=7,keep-weekly=1,keep-monthly=1,keep-yearly=1
  done
EOF
```

#### Rollback Task 2.1 (Disable Compression)
```bash
ssh root@algsrv1 << 'EOF'
  # Note: Cannot uncompress existing data
  zfs set compression=off spark/base
  zfs set compression=off spark/base/dump
EOF
```

#### Rollback Task 2.2 (Remove rpool Backup Storage)
```bash
ssh root@algsrv1 << 'EOF'
  # Remove from Proxmox
  pvesm remove rpool-backup

  # Optionally destroy dataset (DELETES BACKUPS!)
  # zfs destroy -r rpool/backup-hot
EOF
```

---

## Success Metrics Summary

| Metric | Baseline | Target | Actual | Status |
|--------|----------|--------|--------|--------|
| Spark Usage | 94% | <70% | ____% | [ ] |
| Effective Capacity | 6.86TB | 12TB+ | ____TB | [ ] |
| Backup Success Rate | ___% | >95% | ____% | [ ] |
| VM 147 Backup Time | ___min | <20min | ____min | [ ] |
| Storage Growth | ___GB/mo | <50GB/mo | ____GB/mo | [ ] |
| Compression Ratio | 1.0x | >1.5x | ____x | [ ] |

---

## Notes & Observations

**Implementation Date:** ______________________

**Implemented By:** ______________________

**Phases Completed:**
- [ ] Phase 1: Immediate Relief
- [ ] Phase 2: Optimization
- [ ] Phase 3: Verification
- [ ] Phase 4: Cloud Archival (optional)
- [ ] Phase 5: Storage Expansion (optional)

**Issues Encountered:**
```
[Document any problems, errors, or unexpected behavior]
```

**Deviations from Plan:**
```
[Note any changes made to the planned approach]
```

**Recommendations for Future:**
```
[Lessons learned, improvements, optimizations]
```

---

**Checklist Version:** 1.0
**Last Updated:** 2025-10-07
**Document Location:** `/root/host-admin/claudedocs/AGLSRV1_Implementation_Checklist.md`
