# 🚨 DISASTER RECOVERY PROCEDURES
## Proxmox Host: man6b (100.98.119.51)

**Last Updated**: 2025-10-04
**Document Version**: 1.0
**Classification**: CRITICAL - Keep Secure

---

## 📋 TABLE OF CONTENTS

1. [Emergency Contacts](#emergency-contacts)
2. [Quick Recovery Decision Tree](#quick-recovery-decision-tree)
3. [Scenario 1: ZFS Pool Degraded](#scenario-1-zfs-pool-degraded)
4. [Scenario 2: Complete Disk Failure](#scenario-2-complete-disk-failure)
5. [Scenario 3: Data Corruption Detected](#scenario-3-data-corruption-detected)
6. [Scenario 4: Snapshot Restore](#scenario-4-snapshot-restore)
7. [Scenario 5: VM/CT Recovery](#scenario-5-vmct-recovery)
8. [Scenario 6: System Won't Boot](#scenario-6-system-wont-boot)
9. [Backup Verification](#backup-verification)
10. [Testing Schedule](#testing-schedule)

---

## 🆘 EMERGENCY CONTACTS

| Role | Contact | Availability |
|------|---------|--------------|
| **Primary Admin** | [TO BE FILLED] | 24/7 |
| **Backup Admin** | [TO BE FILLED] | Business Hours |
| **Proxmox Support** | https://www.proxmox.com/en/proxmox-virtual-environment/support | Subscription Required |
| **ZFS Community** | r/zfs, #zfs on Freenode | Community Support |

---

## 🌳 QUICK RECOVERY DECISION TREE

```
┌─── PROBLEM DETECTED ───┐
│                         │
├─ ZFS Pool Status? ─────┤
│                         │
├─ ONLINE ──────────────┐ │
│  └─> See Scenario 3   │ │
│                         │
├─ DEGRADED ────────────┐ │
│  └─> See Scenario 1   │ │
│                         │
├─ FAULTED/UNAVAIL ─────┐ │
│  └─> See Scenario 2   │ │
│                         │
└─ BOOT FAILURE ────────┐
   └─> See Scenario 6
```

---

## ⚠️ SCENARIO 1: ZFS Pool Degraded

### Symptoms
- `zpool status` shows DEGRADED
- One or more devices FAULTED or UNAVAILABLE
- System still operational but at risk

### Immediate Actions (Within 1 hour)

**Step 1: Assess Current State**
```bash
# Check pool status
zpool status -v

# Check for read/write/checksum errors
zpool status | grep -E "errors:|DEGRADED|FAULTED"

# Document current state
zpool status > /root/recovery-$(date +%Y%m%d-%H%M%S)-status.txt
```

**Step 2: Create Emergency Snapshot**
```bash
# Snapshot entire pool recursively
zfs snapshot -r rpool@emergency-$(date +%Y%m%d-%H%M%S)

# Verify snapshot creation
zfs list -t snapshot | grep emergency
```

**Step 3: Identify Failed Device**
```bash
# Get device details
zpool status -v rpool | grep -A5 "FAULTED\|UNAVAIL"

# Check physical disk
lsblk -o NAME,SIZE,MODEL,SERIAL
smartctl -a /dev/sda
```

### Recovery Options

**Option A: Clear Transient Errors (If no hardware failure)**
```bash
# Clear errors if disk is actually healthy
zpool clear rpool

# Wait 30 seconds
sleep 30

# Check if pool recovered
zpool status
```

**Option B: Replace Failed Disk (Hardware failure confirmed)**

⚠️ **WARNING**: Only proceed if you have:
- Verified the replacement disk is compatible
- Created emergency snapshots
- Documented current configuration

```bash
# For single-disk pool (like rpool on man6b):
# THIS IS DESTRUCTIVE - Creates new pool on new disk

# 1. Boot from Proxmox installation media
# 2. Import degraded pool in read-only mode:
zpool import -f -o readonly=on rpool

# 3. Send full pool to new disk:
zfs send -R rpool@latest | ssh newhost zfs recv newpool

# 4. Once verified, rebuild on new hardware
```

**Option C: Emergency Replication to Backup Server**
```bash
# If pool is degraded but still readable, replicate immediately
for dataset in $(zfs list -H -o name | grep ^rpool/); do
    zfs snapshot ${dataset}@emergency-backup
    zfs send ${dataset}@emergency-backup | ssh backup-server zfs recv backup/${dataset}
done
```

### Post-Recovery Validation

```bash
# Verify pool health
zpool status

# Run scrub
zpool scrub rpool

# Check for data integrity
zpool status -v | grep "errors:"

# Test critical VMs/CTs
pct start <ctid>
qm start <vmid>
```

---

## 💥 SCENARIO 2: Complete Disk Failure

### Symptoms
- Pool status: FAULTED or UNAVAILABLE
- Cannot import pool
- System may not boot

### Emergency Response (Immediate)

**Step 1: DO NOT PANIC - DO NOT RUN DESTRUCTIVE COMMANDS**

❌ **NEVER RUN**:
- `zpool destroy`
- `dd` to overwrite disks
- `zpool create` on failed pool's disks
- `zpool import -F` without full understanding

**Step 2: Preserve Current State**
```bash
# Boot from Live USB/Installation Media

# List all pools (including those not imported)
zpool import

# Document everything
zpool import > /root/pool-discovery-$(date +%Y%m%d).txt
lsblk -f > /root/disk-layout-$(date +%Y%m%d).txt
```

**Step 3: Attempt Read-Only Import**
```bash
# Try to import pool read-only
zpool import -f -o readonly=on rpool

# If successful, immediately backup critical data
mkdir /mnt/emergency-backup
rsync -av /rpool/ /mnt/emergency-backup/
```

### Recovery Paths

**Path A: Pool Import Successful (Read-Only)**

1. **Data Extraction**
```bash
# Mount external backup drive
mount /dev/sdX1 /mnt/backup

# Copy critical data
rsync -av --progress /rpool/ROOT/pve-1/ /mnt/backup/system/
rsync -av --progress /rpool/subvol-*/ /mnt/backup/containers/
rsync -av --progress /rpool/var-lib-vz/ /mnt/backup/templates/

# Export VM/CT configurations
cp -r /etc/pve /mnt/backup/pve-config/
```

2. **Rebuild on New Hardware**
```bash
# Install fresh Proxmox on new disk
# Restore configurations
# Restore VMs/CTs from backup
```

**Path B: Pool Import Failed - Forensic Recovery**

1. **Use ZFS Recovery Tools**
```bash
# Install recovery tools (from our forensic suite)
apt install testdisk photorec gddrescue

# Create disk image first (to prevent further damage)
ddrescue -f -n /dev/sda /mnt/backup/sda-image.raw /mnt/backup/sda-recovery.log

# Attempt ZFS label recovery
zdb -l /mnt/backup/sda-image.raw

# Try to import from image
zpool import -d /mnt/backup/
```

2. **File-Level Recovery (Last Resort)**
```bash
# Use photorec for file carving
photorec /mnt/backup/sda-image.raw

# Use testdisk for partition recovery
testdisk /mnt/backup/sda-image.raw
```

**Path C: Restore from Off-Site Backup**

```bash
# Connect to backup server
ssh backup-server

# List available backups
zfs list -t snapshot | grep rpool

# Send latest backup to new server
zfs send backup/rpool@latest | ssh newhost zfs recv rpool
```

---

## 🔍 SCENARIO 3: Data Corruption Detected

### Symptoms
- `zpool status` shows checksum errors
- ZFS scrub reports errors
- Files return I/O errors

### Immediate Actions

**Step 1: Identify Corruption Scope**
```bash
# Check error count
zpool status -v | grep -E "errors:"

# Get detailed error locations
zpool status -v

# Check which datasets are affected
zfs list
```

**Step 2: Stop Further Damage**
```bash
# For affected VMs/CTs, stop immediately
pct stop <affected_ctid>
qm stop <affected_vmid>

# Create snapshot before any recovery attempts
zfs snapshot rpool/affected-dataset@pre-recovery-$(date +%Y%m%d)
```

### Recovery Actions

**Option 1: ZFS Self-Healing (If redundancy exists)**
```bash
# Run scrub to repair
zpool scrub rpool

# Monitor scrub progress
watch -n 5 'zpool status'

# After completion, check results
zpool status -v | grep "errors:"
```

**Option 2: Restore from Clean Snapshot**
```bash
# List available snapshots
zfs list -t snapshot | grep affected-dataset

# Identify last known-good snapshot
# Example: rpool/vm-100-disk-0@__replicate_100-0_1758842101__

# Test snapshot integrity first (read-only)
zfs clone rpool/dataset@snapshot /tmp/test-recovery
ls -la /tmp/test-recovery

# If clean, rollback (⚠️ DESTROYS DATA AFTER SNAPSHOT)
zfs rollback rpool/dataset@clean-snapshot

# Or use non-destructive clone method:
zfs clone rpool/dataset@clean-snapshot rpool/dataset-recovered
# Then rename datasets after verification
```

**Option 3: Manual File Recovery**
```bash
# Access snapshot directly via .zfs/snapshot
cd /rpool/dataset/.zfs/snapshot
ls -la

# Copy clean files from snapshot
cp snapshot-name/critical-file /rpool/dataset/critical-file
```

### Post-Recovery

```bash
# Verify data integrity
zpool scrub rpool

# Test affected services
systemctl status <affected-service>

# Document incident
cat > /root/corruption-incident-$(date +%Y%m%d).txt <<EOF
Date: $(date)
Affected Datasets: [list]
Error Count: [count]
Recovery Method: [method used]
Data Loss: [yes/no/extent]
EOF
```

---

## ⏮️ SCENARIO 4: Snapshot Restore

### When to Use
- Accidental file deletion
- Configuration error
- Testing rollback before changes
- Recovering from ransomware/malware

### Non-Destructive Method (Recommended)

**Step 1: Identify Target Snapshot**
```bash
# List all snapshots with dates
zfs list -t snapshot -o name,creation -s creation | grep dataset-name

# Example output:
# rpool/subvol-108-disk-0@vzdump  Sun Sep 28  2:21 2025
```

**Step 2: Clone Snapshot for Testing**
```bash
# Create clone (instant, no copy)
zfs clone rpool/dataset@snapshot rpool/dataset-test

# Mount point automatically created
ls -la /rpool/dataset-test

# Verify data
cat /rpool/dataset-test/important-file
```

**Step 3: Access Files from Clone**
```bash
# Copy specific files
cp /rpool/dataset-test/file /rpool/dataset/file

# Or rsync entire directory
rsync -av /rpool/dataset-test/ /rpool/dataset/
```

**Step 4: Cleanup**
```bash
# Destroy test clone when done
zfs destroy rpool/dataset-test
```

### Destructive Rollback (When Necessary)

⚠️ **WARNING**: This DESTROYS all data created after the snapshot!

```bash
# Stop all services using the dataset
systemctl stop <service>

# Unmount if needed
zfs unmount rpool/dataset

# Rollback (cannot be undone!)
zfs rollback rpool/dataset@snapshot

# Restart services
systemctl start <service>
```

### For VMs/CTs

**Container Restore**:
```bash
# Stop container
pct stop 108

# Rollback rootfs
zfs rollback rpool/subvol-108-disk-0@vzdump

# Start container
pct start 108
```

**VM Restore**:
```bash
# Stop VM
qm stop 100

# Rollback disk
zfs rollback rpool/vm-100-disk-0@__replicate_100-0_1758842101__

# Start VM
qm start 100
```

---

## 🖥️ SCENARIO 5: VM/CT Recovery

### Missing or Corrupted VM/CT

Based on historical recovery experience (from forensic analysis), the following VMs/CTs have been previously lost and recovered:

**Previously Recovered** (Reference):
- CT 109: OpenMediaVault
- CT 110: Scrypted (Home Security)
- CT 118: Shinobi (CCTV/NVR)
- VM 108: TrueNAS
- VM 134: Workstation (aglwk47)

### Recovery from Snapshots

**Step 1: Identify Available Snapshots**
```bash
# List all CT/VM snapshots
zfs list -t snapshot | grep -E "subvol-|vm-"

# For specific ID (example CT 108):
zfs list -t snapshot | grep "subvol-108"
```

**Step 2: Clone for Inspection**
```bash
# Clone VM disk snapshot
zfs clone rpool/vm-<VMID>-disk-0@snapshot rpool/vm-<VMID>-disk-0-recovered

# Clone CT rootfs snapshot
zfs clone rpool/subvol-<CTID>-disk-0@snapshot rpool/subvol-<CTID>-disk-0-recovered
```

**Step 3: Recreate Configuration**

**For Containers**:
```bash
# Create new CT with recovered rootfs
pct create <CTID> /rpool/subvol-<CTID>-disk-0-recovered \
  --hostname <name> \
  --memory 2048 \
  --net0 name=eth0,bridge=vmbr0,ip=dhcp \
  --storage local-zfs

# Or restore from Proxmox backup if available:
pct restore <CTID> /var/lib/vz/dump/vzdump-lxc-<CTID>-*.tar.zst
```

**For VMs**:
```bash
# Import VM configuration
qm importdisk <VMID> /rpool/vm-<VMID>-disk-0-recovered local-zfs

# Attach disk to VM
qm set <VMID> --scsi0 local-zfs:vm-<VMID>-disk-0
```

### Recovery from vzdump Backups

**Step 1: Locate Backups**
```bash
# Check local backup storage
ls -lh /var/lib/vz/dump/

# Check remote CIFS storage
ls -lh /mnt/pve/bb/dump/
ls -lh /mnt/pve/usb4tb/dump/
```

**Step 2: Restore VM**
```bash
# Restore VM
qmrestore /var/lib/vz/dump/vzdump-qemu-<VMID>-*.vma.zst <VMID>

# Or restore to different ID
qmrestore /var/lib/vz/dump/vzdump-qemu-<VMID>-*.vma.zst <NEW_VMID>
```

**Step 3: Restore Container**
```bash
# Restore CT
pct restore <CTID> /var/lib/vz/dump/vzdump-lxc-<CTID>-*.tar.zst

# Or to different ID
pct restore <NEW_CTID> /var/lib/vz/dump/vzdump-lxc-<CTID>-*.tar.zst
```

---

## 🚫 SCENARIO 6: System Won't Boot

### Symptoms
- Grub error
- Kernel panic
- ZFS pool not found
- Initramfs errors

### Recovery via Installation Media

**Step 1: Boot Proxmox Installation USB**

**Step 2: Access Recovery Shell**
```bash
# Alt+F2 or Ctrl+Alt+F2 to get shell

# Import pool
zpool import -f rpool

# Mount root filesystem
zfs mount rpool/ROOT/pve-1
```

**Step 3: Chroot into System**
```bash
# Mount necessary filesystems
mount --bind /dev /rpool/ROOT/pve-1/dev
mount --bind /proc /rpool/ROOT/pve-1/proc
mount --bind /sys /rpool/ROOT/pve-1/sys

# Chroot
chroot /rpool/ROOT/pve-1
```

**Step 4: Fix Boot Issues**

**Grub Reinstall**:
```bash
# Update grub
update-grub

# Reinstall grub
grub-install /dev/sda

# Update initramfs
update-initramfs -u -k all
```

**ZFS Boot Fix**:
```bash
# Ensure ZFS pools are cached
zpool set cachefile=/etc/zfs/zpool.cache rpool

# Regenerate initramfs
update-initramfs -u -k all
```

**Kernel Issues**:
```bash
# List available kernels
ls /boot/vmlinuz-*

# Reinstall latest kernel
apt install --reinstall pve-kernel-$(uname -r)

# Or install new kernel
apt install pve-kernel-6.14.11-2-pve
```

**Step 5: Exit and Reboot**
```bash
# Exit chroot
exit

# Unmount
umount /rpool/ROOT/pve-1/dev
umount /rpool/ROOT/pve-1/proc
umount /rpool/ROOT/pve-1/sys
zfs unmount rpool/ROOT/pve-1

# Export pool
zpool export rpool

# Reboot
reboot
```

---

## ✅ BACKUP VERIFICATION

### Monthly Verification Checklist

**Automated Backups**:
```bash
# Check backup job status
pvesh get /cluster/backup

# Verify recent backups exist
ls -lth /mnt/pve/bb/dump/ | head -20
ls -lth /mnt/pve/usb4tb/dump/ | head -20

# Check backup ages (should be < 7 days for weekly backups)
find /mnt/pve/bb/dump/ -name "*.vma.zst" -mtime +7
find /mnt/pve/bb/dump/ -name "*.tar.zst" -mtime +7
```

**Snapshot Verification**:
```bash
# Check snapshot count and age
zfs list -t snapshot -o name,used,creation -s creation | tail -20

# Verify snapshots accessible
zfs mount rpool/vm-100-disk-0@__replicate_100-0_1758842101__ /mnt/test || echo "Snapshot test passed"
```

**Test Restore (Quarterly)**:
```bash
# Pick random VM/CT to test restore
# Restore to temporary ID
qmrestore /mnt/pve/bb/dump/vzdump-qemu-100-*.vma.zst 999 --storage local-zfs

# Start and verify
qm start 999
sleep 60
qm status 999

# Cleanup
qm stop 999
qm destroy 999
```

---

## 📅 TESTING SCHEDULE

| Test Type | Frequency | Next Due | Status |
|-----------|-----------|----------|--------|
| Snapshot Access Test | Monthly | 2025-11-04 | ✅ Scheduled |
| ZFS Scrub | Monthly | 2025-11-01 | ✅ Automated |
| Backup Restore Test | Quarterly | 2026-01-04 | 📅 Pending |
| Full DR Drill | Annually | 2026-10-04 | 📅 Pending |
| Documentation Review | Quarterly | 2026-01-04 | 📅 Pending |

---

## 🔐 SECURITY & COMPLIANCE

### Access Control
- This document contains sensitive system information
- Store securely with access controls
- Update contact information regularly
- Test procedures in isolated environment first

### Change Log

| Date | Version | Changes | Author |
|------|---------|---------|--------|
| 2025-10-04 | 1.0 | Initial creation | Hive Mind Collective |

---

## 📚 RELATED DOCUMENTATION

- **Forensic Analysis Report**: `/root/host-admin/claudedocs/DISK_FORENSIC_ANALYSIS_REPORT_man6b.md`
- **Diagnostic Framework**: `/root/host-admin/claudedocs/disk-failure-diagnostic-framework.md`
- **QA Strategy**: `/root/host-admin/claudedocs/zfs-forensic-qa-strategy.md`
- **Research Report**: `/root/host-admin/zfs_forensic_analysis_recovery_research.md`

---

**REMEMBER**:
- 🛑 **NEVER** panic or rush destructive commands
- 📸 **ALWAYS** snapshot before major changes
- 📝 **DOCUMENT** everything during recovery
- 🧪 **TEST** procedures before production use
- 📞 **CONTACT** support when unsure

**END OF DISASTER RECOVERY PROCEDURES**
