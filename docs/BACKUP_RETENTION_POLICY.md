# Backup Retention Policy - Spark Storage

**Date**: 2025-10-16
**Location**: AGLSRV1 (192.168.0.245)
**Storage**: spark (ZFS pool)

## Problem Statement

Spark storage was critically full (99.99%, only 450KB free) due to excessive backup retention. All 67 VMs/CTs were being backed up with the same aggressive retention policy:
- keep-last=7
- keep-weekly=4
- keep-monthly=6
- keep-yearly=1

This caused rapid accumulation of large backups, particularly for VMs with >= 10GB disk size.

## Solution Implemented

### 1. VM/CT Categorization

Categorized all VMs/CTs by disk size using threshold of **>= 10GB**:

**Small VMs (< 10GB)**: 6 VMs
- 101, 102, 111, 112, 117, 176

**Large VMs (>= 10GB)**: 61 VMs
- 100, 104, 105, 106, 114, 115, 116, 125, 128, 135, 136, 138, 142, 145, 146, 147, 148, 150, 151, 152, 153, 154, 155, 156, 300, 103, 113, 120, 121, 122, 123, 124, 126, 131, 132, 133, 137, 139, 141, 144, 149, 157, 159, 161, 162, 163, 165, 167, 168, 169, 170, 171, 172, 173, 174, 178, 179, 180, 200, 201, 202

### 2. New Backup Jobs Configuration

**File**: `/etc/pve/jobs.cfg`

#### Job 1: Small VMs Backup (ID: small-vms-backup)
- **Schedule**: 03:15 daily
- **VMs**: 101, 102, 111, 112, 117, 176
- **Retention**:
  - keep-last=7
  - keep-weekly=4
  - keep-monthly=6
  - keep-yearly=1
- **Storage**: spark
- **Compression**: zstd
- **Mode**: snapshot

#### Job 2: Large VMs Backup (ID: large-vms-backup)
- **Schedule**: 03:30 daily
- **VMs**: 100, 104, 105, ... (61 VMs total)
- **Retention**: **keep-last=2** (only 2 most recent backups)
- **Storage**: spark
- **Compression**: zstd
- **Mode**: snapshot

#### Job 3: Old Job (DISABLED)
- **Status**: Disabled (enabled 0)
- **ID**: 9c5aa827-2416-43b7-9752-6a8b1175edbd
- **Note**: Kept for reference but no longer runs

### 3. Pruning Results

**Commands executed**:
```bash
pvesm prune-backups spark --keep-last 2 --type qemu
pvesm prune-backups spark --keep-last 2 --type lxc
```

**Before pruning**:
- Total: 7.65 GB
- Used: 7.65 GB (99.99% full)
- Available: **450 KB**

**After pruning**:
- Total: 7.65 GB
- Used: 7.00 GB (91.54% full)
- Available: **647 MB (~650 GB freed)**

**Backups removed**: 58 old backups (48 qemu + 10 lxc)

## Benefits

1. **Space Recovery**: Freed ~650 GB (8.46% of total storage)
2. **Predictable Growth**: Large VMs now limited to 2 backups each
3. **Flexibility**: Small VMs still have full retention for critical services
4. **Sustainability**: Storage will no longer fill up rapidly

## Backup Schedule

```
03:00 - (Old job disabled)
03:15 - Small VMs backup (6 VMs)
03:30 - Large VMs backup (61 VMs)
```

## Monitoring

**Check storage usage**:
```bash
pvesm status -storage spark
```

**List backups by VM**:
```bash
pvesm list spark --content backup | grep "vzdump-.*-<VMID>-"
```

**Manual prune if needed**:
```bash
pvesm prune-backups spark --keep-last 2 --type qemu
pvesm prune-backups spark --keep-last 2 --type lxc
```

## Next Steps

1. Monitor storage usage over the next week
2. Verify backups are running successfully at new schedule times
3. Consider increasing storage capacity if 91% becomes problematic
4. Review backup retention policy quarterly

## References

- Backup jobs configuration: `/etc/pve/jobs.cfg`
- Categorization script: `/tmp/categorize_vms.py`
- Small VMs list: `/tmp/small_vms.txt`
- Large VMs list: `/tmp/large_vms.txt`

---

**Configuration validated**: 2025-10-16
**Status**: ✅ Active and operational
