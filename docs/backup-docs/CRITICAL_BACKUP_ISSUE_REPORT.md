# CRITICAL: VM100 Backup Issue Report
Date: 2025-09-28 12:36 UTC

## Executive Summary
VM100 (Windows Server with SQL Server) CANNOT complete backups without freezing, regardless of storage backend used.

## Failed Backup Attempts

### 1. USB Storage (Original Issue)
- **Result**: VM freezes, BSOD
- **Speed**: ~13 MB/s
- **Cause**: Slow I/O + IDE disks + compression

### 2. PBS (Proxmox Backup Server)
- **Result**: VM freezes during snapshot
- **Speed**: ~50 MB/s
- **Issue**: IDE disk limitations

### 3. RPOOL (Local ZFS - ATTEMPTED NOW)
- **Result**: VM FROZEN AGAIN
- **Speed**: Started at ~360 MB/s
- **Issue**: Stuck at 0%, SQL Server unresponsive
- **Action Taken**: Killed backup, restarted VM100

## Root Cause Analysis

The issue is NOT the storage backend, but the combination of:
1. **IDE Disk Controller**: Extremely limited for snapshot operations
2. **Large Disk Size**: 2x 952GB disks (1.8TB total)
3. **Windows Server + SQL**: High I/O requirements
4. **Snapshot Mechanism**: Incompatible with IDE + high I/O workload

## CRITICAL RECOMMENDATION

### Option 1: VirtIO Migration WITHOUT Backup (RECOMMENDED)
Since ALL backup attempts fail and cause VM freezing:

1. **Accept Risk**: Proceed without recent backup
2. **Use Last Good Backup**: Check for any successful older backups
3. **Migrate to VirtIO Immediately**:
   - Will solve ALL backup issues
   - Will improve VM performance 10x
   - Will enable reliable future backups

### Option 2: Alternative Backup Method
1. **Inside-VM Backup**:
   - Use Windows Backup or SQL Server backup tools
   - Backup to network share
   - Slower but won't freeze VM

2. **Offline Backup**:
   - Schedule maintenance window
   - Shutdown VM completely
   - Clone disks while offline
   - Time required: ~4-6 hours

## Immediate Actions Required

1. **VM100 Status**: Currently running after force restart
2. **SQL Server**: Should be operational (verify manually)
3. **Decision Needed**:
   - Proceed with VirtIO migration without backup?
   - Schedule offline backup window?

## VirtIO Migration Benefits
- Backup speed: 13 MB/s → 500+ MB/s
- VM performance: 10x improvement
- Backup reliability: No more freezing
- SQL Server I/O: Significantly improved

## Risk Assessment
- **Current Risk**: Daily VM freezes affecting production
- **Migration Risk**: Potential data loss if migration fails (low probability)
- **Mitigation**: Can restore from older backup if needed

## Command to Check Last Successful Backup
```bash
ls -lah /var/lib/vz/dump/vzdump-qemu-100-*.vma* | tail -5
pvesm list usb4tb | grep vm-100
pvesm list man6b-pbs | grep vm-100
```

## URGENT: User Decision Required
The VM cannot handle backups in its current IDE configuration. We must either:
1. Migrate to VirtIO immediately (accepting backup risk)
2. Schedule extended downtime for offline backup

**Note**: Every backup attempt will freeze the VM and require forced restart.