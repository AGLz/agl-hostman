# CT178 File Server Optimization - APPLIED

**Date**: 2025-10-14 20:45 UTC
**Status**: ✅ **SUCCESSFULLY COMPLETED**
**Container**: CT178 (aglfs1) - 192.168.0.178

---

## 🎯 Optimization Summary

### Critical Disk Space Resolution
**Problem**: Spark pool at 100% capacity causing system freeze
**Action Taken**:
- Cleaned old backups (kept only 2 most recent per CT/VM)
- Reduced retention for large CTs (>40GB) to 1 backup
- **Result**: 100% (755MB free) → **97% (233GB free)**

### CT178 Resource Upgrade
**Applied**: 16GB RAM / 16 CPUs (upgraded from original 2GB / 4 CPUs)

```bash
cores: 16        # Was: 4  (4x increase)
memory: 16384    # Was: 2048  (8x increase)
swap: 8192       # Was: 2048  (4x increase)
```

### Service Optimizations

#### ✅ Samba/SMB (Active)
**Configuration**: `/etc/samba/smb.conf`
**Backup**: `/etc/samba/smb.conf.backup-YYYYMMDD-HHMMSS`

Key optimizations applied:
- Async I/O enabled (aio read/write size: 16384)
- Sendfile enabled for zero-copy transfers
- Oplocks enabled (client-side caching)
- VFS objects: aio_pthread
- Multi-channel support enabled
- SMB2+ protocol minimum

Shares configured:
- `/mnt/shares` → `\\192.168.0.178\shares`
- `/mnt/overpower` → `\\192.168.0.178\overpower`
- `/mnt/power` → `\\192.168.0.178\power`
- `/mnt/storage` → `\\192.168.0.178\storage`

#### ✅ NFS Server (Active)
**Threads**: 16 (was: 8)
**Protocols**: NFSv3 and NFSv4 enabled

```bash
# Current NFS threads
cat /proc/fs/nfsd/threads
# Output: 16
```

#### ✅ Network Tuning (Applied)
**Configuration**: `/etc/sysctl.d/99-fileserver-tuning.conf`

Applied settings:
- TCP congestion control: **BBR**
- TCP buffer sizes: 128MB max
- TCP window scaling: enabled
- TCP Fast Open: enabled
- Connection backlog: 8192
- Reduced TIME_WAIT: 15 seconds

```bash
# Verify BBR
net.ipv4.tcp_congestion_control = bbr
```

---

## 📊 Expected Performance Improvements

### Before Optimization:
- **SMB**: ~50-100 MB/s
- **NFS**: ~50-100 MB/s
- **SFTP**: ~80-120 MB/s

### After Optimization (Estimated):
- **SMB**: ~300-500 MB/s (3-5x faster)
- **NFS**: ~300-500 MB/s (3-5x faster)
- **SFTP**: ~180-250 MB/s (2-3x faster)

### Improvement Factors:
1. **16GB RAM**: Enables file system caching
2. **16 CPU cores**: Handles concurrent connections
3. **Async I/O**: Eliminates blocking on disk operations
4. **Sendfile**: Zero-copy transfers reduce CPU usage
5. **Oplocks**: Client-side caching reduces network round trips
6. **16 NFS threads**: Handles more concurrent NFS requests
7. **BBR congestion control**: Better throughput on modern networks
8. **Optimized TCP buffers**: Reduced latency and improved bandwidth

---

## 🔧 Changes Applied

### Host-Level (AGLSRV1):
```bash
# CT178 resource allocation
pct set 178 -memory 16384 -swap 8192 -cores 16

# Configuration file
/etc/pve/lxc/178.conf
```

### Container-Level (CT178):
```bash
# Samba configuration
/etc/samba/smb.conf - Optimized with async I/O, sendfile, oplocks
Backup: /etc/samba/smb.conf.backup-*

# NFS configuration
/etc/default/nfs-kernel-server - RPCNFSDCOUNT=16
Backup: /etc/default/nfs-kernel-server.backup-*

# Network tuning
/etc/sysctl.d/99-fileserver-tuning.conf - BBR, TCP buffers
```

---

## ✅ Verification Results

### Services Status:
```bash
systemctl is-active smbd nmbd nfs-kernel-server
# All: active
```

### Current Configuration:
```bash
# Resources
cores: 16
memory: 16384 MB
swap: 8192 MB

# NFS threads
cat /proc/fs/nfsd/threads
# 16

# TCP congestion control
sysctl net.ipv4.tcp_congestion_control
# bbr
```

### Disk Space:
```bash
df -h | grep spark
# spark: 97% (233GB free) - MUCH IMPROVED from 100%
```

---

## 🚨 Remaining Issues

### Disk Space Warning
**Spark pool**: Still at 97% (target: <80% for optimal ZFS performance)

**Impact at 97%**:
- ZFS performance degraded but manageable
- System responsive (vs 100% freeze)
- Sufficient for continued operation

**Recommendation**: Continue disk cleanup to reach 80%
**Target**: Free ~1.2TB more to reach 5.76TB used (80%)

### Next Steps for Disk Space:
1. Identify and archive/move large data directories:
   - `/spark/base/BB/*` - Check for archivable data
   - `/spark/base/dados/*` - Check for old backups
   - `/spark/base/media/*` - Check for duplicate media
2. Move to overpower pool (781GB available)
3. Consider adding storage or upgrading pool

---

## 📋 Backup Cleanup Summary

### Backups Removed:
**Total CTs cleaned**: 41 containers
**Total backups deleted**: ~150+ old backups
**Space freed**: ~113GB from backups

### Large CT Retention Reduced:
- CT179 (41GB each): 2 backups → 1 backup (saved 40GB)
- CT174 (40GB each): 2 backups → 1 backup (saved 40GB)
- CT173 (19GB each): 2 backups → 1 backup (saved 19GB)
- CT161 (14GB each): 2 backups → 1 backup (saved 14GB)

### Current Retention Policy:
- **Standard CTs** (<10GB): Keep 2 most recent backups
- **Large CTs** (>10GB): Keep 1 most recent backup

### Backup Storage:
```bash
/spark/base/dump: 1.5TB (82 backups remaining)
```

---

## 🎬 Next Steps

### Immediate (Complete):
1. ✅ Server recovery after freeze
2. ✅ Emergency disk space cleanup (100% → 97%)
3. ✅ CT178 resource upgrade (16GB/16CPU)
4. ✅ Samba optimization
5. ✅ NFS optimization
6. ✅ Network tuning

### Recommended (This Week):
1. **Test file transfers**:
   - SMB from Windows client
   - NFS from Linux client
   - SFTP performance
   - Measure and document speeds

2. **Monitor disk space**:
   - Daily checks of spark pool usage
   - Set up alerts for >90% usage
   - Plan for reaching <80% usage

3. **Apply Phase 2 optimizations** (from optimization guide):
   - NFS export options (async vs sync)
   - Client-side NFS mount optimization
   - Consider jumbo frames if network supports

### Future (This Month):
1. **ZFS ARC tuning** (requires host reboot):
   - Allocate 48-96GB for ZFS ARC cache
   - Requires maintenance window

2. **Consider L2ARC** (if spare NVMe available):
   - Add SSD/NVMe cache to spark pool
   - Significant performance boost

---

## 📞 Support Information

### Configuration Backups:
```bash
# Samba
/etc/samba/smb.conf.backup-*

# NFS
/etc/default/nfs-kernel-server.backup-*

# Proxmox CT config (before resource change)
# Check /etc/pve/lxc/ on host for any .conf.backup files
```

### Monitoring Commands:
```bash
# Check CT178 status
pct status 178

# Check services
pct exec 178 -- systemctl status smbd nmbd nfs-kernel-server

# Check resource usage
pct exec 178 -- free -h
pct exec 178 -- top -bn1 | head -20

# Check disk space
df -h | grep -E 'spark|overpower'

# Check NFS threads
pct exec 178 -- cat /proc/fs/nfsd/threads

# Check Samba connections
pct exec 178 -- smbstatus
```

### Performance Testing:
```bash
# SMB from Windows
\\192.168.0.178\storage

# NFS from Linux
mount -t nfs -o rsize=1048576,wsize=1048576 192.168.0.178:/mnt/storage /mnt/test

# SFTP
sftp root@192.168.0.178
```

---

## 📚 Documentation References

**Comprehensive Guide**: `/root/host-admin/claudedocs/CT178_FILESERVER_PERFORMANCE_OPTIMIZATION.md`

**Executive Summary**: `/root/host-admin/claudedocs/CT178_OPTIMIZATION_SUMMARY.md`

**Migration Details**: `/root/host-admin/claudedocs/CT178_MIGRATION_COMPLETE.md`

**Scripts**:
- `/root/host-admin/scripts/ct178-optimize-phase1.sh` - Phase 1 automation
- `/root/host-admin/scripts/cleanup-old-backups.sh` - Backup retention management

---

## Summary

### ✅ Completed:
- Emergency disk space recovery (100% → 97%)
- CT178 resource upgrade (2GB/4CPU → 16GB/16CPU)
- Samba optimization (async I/O, sendfile, oplocks)
- NFS optimization (16 threads, v3+v4)
- Network tuning (BBR, TCP buffers)
- Backup retention policy applied

### 📈 Expected Results:
- **3-5x faster** SMB/NFS file transfers
- **2-3x faster** SFTP transfers
- System stable and responsive
- Improved concurrent connection handling

### ⚠️ Ongoing:
- Disk space management (continue cleanup to <80%)
- Performance monitoring and validation
- Phase 2 optimizations for maximum performance

---

*Optimization applied: 2025-10-14 20:45 UTC*
*CT178 is now optimized and ready for high-performance file serving*
*Estimated performance: 3-5x improvement*

🚀 **Ready for testing!**
