# n8n (CT202) Troubleshooting Notes - 2025-12-12

## Problem Summary

n8n container (CT202) completely inaccessible with critical filesystem corruption and loop device mount failures.

## Current Status

- **Container**: Cannot start (failed startup for multiple attempts)
- **Filesystem**: ext4 on RAW disk format (not ZFS subvolume)
- **Storage**: spark (98% full - 7.0TB/7.2TB used)
- **Hostname**: n8n-docker
- **Resources**: 4 cores, 8GB RAM, 64GB disk
- **Disk Path**: `/spark/base/images/202/vm-202-disk-0.raw` (2.6GB used)

## Root Causes (Multiple Issues)

### 1. Filesystem Corruption
- **Initial Error**: `(needs journal recovery) (errors)` in ext4 filesystem
- **Repaired**: Successfully ran `e2fsck -fy` which fixed:
  - Journal recovery
  - 10 deleted inodes with zero dtime
  - Inode bitmap corrections
  - Free inodes count corrections
  - Orphan file block cleanup

### 2. Loop Device Mount Failure
- **Error**: `Can't mount, would change RO state`
- **Symptom**: `/dev/loop0 already mounted or mount point busy`
- **Diagnosis**: Loop device gets created but mount fails with read-only state conflict
- **Persists**: Even after filesystem repair and cleanup

### 3. Storage Capacity Critical
- **spark storage**: 98% full (only 185GB free of 7.2TB)
- **Risk**: Near-full storage may have contributed to filesystem corruption
- **Impact**: Limited space for operations and recovery attempts

## Error Timeline

```
1. Initial access attempt → I/O error (filesystem corrupted)
2. Backup lock found → Removed with `pct unlock 202`
3. Container restart attempted → Still I/O error
4. Filesystem check revealed corruption → Fixed with e2fsck
5. Loop device conflict discovered → Loop0 already mounted
6. Loop device cleared → Recreates on startup but mount fails
7. Manual mount attempted → "Can't mount, would change RO state"
8. Filesystem state verified clean → Mount still fails
9. Error persists after all attempts → Cannot start container
```

## Commands Attempted

### Filesystem Repair
```bash
# Stop container
pct stop 202

# Repair filesystem
e2fsck -fy /spark/base/images/202/vm-202-disk-0.raw
# Result: ***** FILE SYSTEM WAS MODIFIED *****
# Fixed: Journal, inodes, bitmaps, orphan file

# Verify filesystem
tune2fs -l /spark/base/images/202/vm-202-disk-0.raw | grep state
# Result: Filesystem state: clean

# Preen check
e2fsck -fp /spark/base/images/202/vm-202-disk-0.raw
# Result: Clean, no errors
```

### Loop Device Management
```bash
# Remove backup lock
pct unlock 202

# Check loop devices
losetup -a | grep 202
# Result: /dev/loop0: [0043]:492439 (/base/images/202/vm-202-disk-0.raw)

# Detach loop device
losetup -d /dev/loop0

# Detach all unused
losetup -D

# Manual mount test
mount -o loop /spark/base/images/202/vm-202-disk-0.raw /mnt
# Error: mount: /mnt: /dev/loop0 already mounted or mount point busy.
#        mount warning: * loop0: Can't mount, would change RO state
```

### Container Operations
```bash
# Multiple start attempts
pct start 202
# Error: startup for container '202' failed
#        run_buffer: 571 Script exited with status 32
#        lxc_init: 845 Failed to run lxc.hook.pre-start for container "202"
```

## Diagnostic Logs

```
lxc-start 202 20251212182734.516 DEBUG utils - Script exec /usr/share/lxc/hooks/lxc-pve-prestart-hook 202 lxc pre-start produced output:
mount warning:
      * loop0: Can't mount, would change RO state
mount: /var/lib/lxc/.pve-staged-mounts/rootfs: /dev/loop0 already mounted or mount point busy.
       dmesg(1) may have more information after failed mount system call.

lxc-start 202 20251212182734.517 DEBUG utils - Script exec /usr/share/lxc/hooks/lxc-pve-prestart-hook 202 lxc pre-start produced output:
command 'mount /dev/loop0 /var/lib/lxc/.pve-staged-mounts/rootfs' failed: exit code 32
```

## Resolution Options

### Option 1: Restore from Backup (Recommended if backup exists)

1. **Check for backups**:
   ```bash
   pvesm list backup | grep 202
   ls -lh /var/lib/vz/dump/vzdump-lxc-202-*.tar.*
   ```

2. **Restore from backup**:
   ```bash
   pct restore 202 /path/to/backup.tar.gz -storage local-lvm
   ```

### Option 2: Migrate to ZFS Subvolume (Clean Slate)

1. **Backup n8n data if accessible** (via host filesystem mount):
   ```bash
   mkdir -p /tmp/n8n-backup
   mount -o loop,ro /spark/base/images/202/vm-202-disk-0.raw /mnt
   rsync -av /mnt/root/.n8n/ /tmp/n8n-backup/
   rsync -av /mnt/var/lib/docker/ /tmp/n8n-docker-backup/
   umount /mnt
   ```

2. **Create new CT with ZFS subvolume**:
   ```bash
   pct destroy 202  # Remove old container
   pct create 202 local:vztmpl/debian-12-standard_12.7-1_amd64.tar.zst \
     --hostname n8n-docker \
     --memory 8192 \
     --cores 4 \
     --rootfs local-zfs:64 \  # Use ZFS instead of RAW
     --net0 name=eth0,bridge=vmbr0,ip=192.168.0.202/24,gw=192.168.0.1
   ```

3. **Restore n8n data to new container**

4. **Reinstall Docker and n8n**

### Option 3: Advanced Loop Device Recovery

1. **Create loop device with explicit read-write**:
   ```bash
   losetup -d /dev/loop0  # Clear
   losetup /dev/loop0 /spark/base/images/202/vm-202-disk-0.raw
   losetup -a  # Verify
   ```

2. **Manual mount with force write**:
   ```bash
   mount -t ext4 -o rw /dev/loop0 /mnt
   ```

3. **If successful, try container start again**

### Option 4: Storage Migration (Long-term Fix)

**Problem**: spark storage at 98% capacity is dangerous for data integrity

1. **Identify largest container** (CT135 = 15GB):
   ```bash
   du -sh /spark/base/images/*/vm-*-disk-*.raw | sort -rh
   ```

2. **Migrate CT135 to different storage**:
   ```bash
   pct stop 135
   pct move-volume 135 rootfs local-zfs
   ```

3. **Free up space on spark** (target <90% usage)

4. **Attempt CT202 recovery with more space**

## n8n Data Considerations

**Critical to preserve**:
- `/root/.n8n/database.sqlite` - Workflow database
- `/root/.n8n/config` - n8n configuration
- Docker volumes (if n8n runs in Docker)
- Environment variables and credentials

**Backup method** (if container becomes accessible):
```bash
pct exec 202 -- tar -czf /tmp/n8n-backup.tar.gz /root/.n8n /var/lib/docker/volumes
pct pull 202 /tmp/n8n-backup.tar.gz ./n8n-backup-$(date +%Y%m%d).tar.gz
```

## Recommended Action Plan

**Priority**: 🔴 **CRITICAL** - n8n automation workflows are offline

**Steps**:
1. ✅ Check for existing backups (vzd ump files)
2. ⏸️ If backup exists → Restore (Option 1)
3. ⏸️ If no backup → Attempt data extraction via loop mount (Option 2 step 1)
4. ⏸️ Create new container with ZFS (Option 2)
5. ⏸️ Address spark storage capacity issue (Option 4)

**Decision needed**:
- Does n8n have critical workflows that must be preserved?
- Are there recent backups available?
- Is clean reinstall acceptable if data recovery fails?

## Storage Health Alert

**spark storage at 98% capacity is CRITICAL**:
- Total: 7.2TB
- Used: 7.0TB
- Available: Only 185GB (2% remaining)

**Largest consumers**:
- CT135: 15GB
- CT202: 2.6GB (but can't start)
- CT154: 1.4GB
- CT151: 1.3GB

**Action required**: Migrate containers off spark or expand storage capacity

## Last Updated

2025-12-12 18:30 UTC

## Next Steps

1. Check `/var/lib/vz/dump/` for CT202 backups
2. Decide on recovery approach based on backup availability
3. Execute chosen option
4. Address spark storage capacity issue
5. Consider migrating remaining RAW disk containers to ZFS for better reliability
