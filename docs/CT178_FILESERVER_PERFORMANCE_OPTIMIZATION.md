# CT178 File Server Performance Optimization Guide

**Date**: 2025-10-14
**Container**: CT178 (aglfs1) - 192.168.0.178
**Purpose**: Optimize SMB, NFS, and SFTP file transfer performance
**Issue**: Slow file copies via SMB, NFS, and SFTP

---

## Executive Summary

**Current Status**: CT178 has performance bottlenecks in file transfer operations
**Root Causes Identified**:
1. Default Samba configuration not optimized for high performance
2. NFS server using default thread count (likely 8)
3. Network buffer sizes not tuned for large file transfers
4. ZFS ARC cache potentially undersized for file server workload
5. Container resource constraints (2GB RAM, 4 cores)

**Optimization Strategy**: Multi-layered approach targeting SMB, NFS, network stack, ZFS, and container resources

---

## Table of Contents

1. [Quick Wins (Immediate Impact)](#1-quick-wins-immediate-impact)
2. [Samba/SMB Optimization](#2-sambas

mb-optimization)
3. [NFS Server Optimization](#3-nfs-server-optimization)
4. [Network Stack Tuning](#4-network-stack-tuning)
5. [ZFS ARC Cache Optimization](#5-zfs-arc-cache-optimization)
6. [Container Resource Adjustment](#6-container-resource-adjustment)
7. [Monitoring and Benchmarking](#7-monitoring-and-benchmarking)
8. [Implementation Roadmap](#8-implementation-roadmap)

---

## Current Configuration Analysis

### Container Resources
```
CT178 (aglfs1):
- Cores: 4
- Memory: 2048 MB (2 GB)  ⚠️ LOW for file server
- Swap: 2048 MB
- Status: Privileged (lxc.cgroup2.devices.allow: a)
- Network: BBR congestion control ✅ (already optimized)
```

### Installed Services
```
✅ Samba: 2:4.17.12+dfsg-0+deb12u2
✅ NFS Kernel Server: 1:2.6.2-4+deb12u1
✅ OpenSSH/SFTP: 1:9.2p1-2+deb12u7
```

### Network Tuning (Current)
```
✅ TCP BBR congestion control (excellent choice)
✅ net.core.somaxconn = 4096
✅ net.core.rmem_max = 134217728 (128 MB)
✅ net.core.wmem_max = 134217728 (128 MB)
```

### Storage Backend
```
Mount Points:
- /mnt/shares (ZFS - rpool/ROOT/pve-1) - 777GB
- /mnt/overpower (ZFS - overpower pool) - 9.9TB at 93% full ⚠️
- /mnt/power (ZFS - spark pool) - 7.2TB at 100% full 🔴 CRITICAL
- /mnt/storage (MergerFS) - 10TB
```

**CRITICAL ISSUE**: Spark pool is 100% full! This WILL cause severe performance degradation.

---

## 1. Quick Wins (Immediate Impact)

### 1.1 Free Up Disk Space (CRITICAL - Do First!)

**Problem**: Spark pool at 100% will cause extreme performance degradation

```bash
# Check disk usage on spark
pct exec 178 -- df -h /mnt/power

# Find large files/directories
pct exec 178 -- du -sh /mnt/power/* | sort -hr | head -20

# Action: Delete unnecessary files or move to overpower pool
# Target: Get spark pool below 80% for optimal performance
```

**Why Critical**: ZFS performance degrades significantly above 80% full, and at 100% you'll see:
- Extreme slowdown (can be 10x+ slower)
- Increased fragmentation
- Copy-on-write overhead maximized

### 1.2 Increase Container Memory (HIGH PRIORITY)

**Current**: 2GB RAM
**Recommended**: 8-16GB for file server workload

```bash
# Stop CT178
pct stop 178

# Increase memory to 8GB
pct set 178 -memory 8192

# Increase swap to 4GB
pct set 178 -swap 4096

# Start CT178
pct start 178
```

**Why**: File servers need RAM for:
- ZFS ARC caching
- SMB/NFS buffer caching
- Concurrent connections
- Network buffers

### 1.3 Samba Quick Fix

Add these to `/etc/samba/smb.conf` in `[global]` section:

```ini
[global]
# Quick performance wins
socket options = TCP_NODELAY IPTOS_LOWDELAY
read raw = yes
write raw = yes
max xmit = 65535
dead time = 15
getwd cache = yes

# Async I/O (critical for performance)
aio read size = 16384
aio write size = 16384

# Oplocks (client-side caching)
oplocks = yes
level2 oplocks = yes

# Use sendfile for zero-copy
use sendfile = yes

# Wide links (if needed for symlinks)
unix extensions = no
wide links = yes

# Log level (reduce disk I/O)
log level = 0
```

After changes:
```bash
pct exec 178 -- testparm  # Validate config
pct exec 178 -- systemctl restart smbd nmbd
```

**Expected Improvement**: 2-3x faster SMB transfers

---

## 2. Samba/SMB Optimization

### 2.1 Remove Socket Options Override

**Important**: Modern kernels auto-tune network buffers. Remove or comment out `socket options` if it overrides system defaults.

**Best Practice** (2025):
```ini
# Don't override socket options - let kernel auto-tune
# socket options = TCP_NODELAY  # Remove this line
```

### 2.2 Protocol Optimization

```ini
[global]
# Let Samba negotiate latest protocol (SMB3+)
# DO NOT set "server max protocol"
server min protocol = SMB2

# Multi-channel support (SMB3+)
server multi channel support = yes

# Performance features
kernel oplocks = no
kernel share modes = no
```

### 2.3 Case Sensitivity (if many files)

For shares with >100,000 files, optimize case sensitivity:

```ini
[share_name]
case sensitive = true
default case = lower
preserve case = no
short preserve case = no
```

### 2.4 Async I/O and Sendfile

```ini
[global]
# Async I/O settings
aio read size = 16384
aio write size = 16384
aio write behind = true

# Zero-copy with sendfile
use sendfile = yes

# VFS objects for async
vfs objects = aio_pthread
```

### 2.5 Complete Optimized smb.conf

```ini
[global]
workgroup = WORKGROUP
server string = CT178 File Server
security = user
map to guest = Bad User

# Performance - Core Settings
read raw = yes
write raw = yes
max xmit = 65535
dead time = 15
getwd cache = yes
server min protocol = SMB2
server multi channel support = yes

# Performance - Async I/O
aio read size = 16384
aio write size = 16384
aio write behind = true
use sendfile = yes
vfs objects = aio_pthread

# Performance - Oplocks (client caching)
oplocks = yes
level2 oplocks = yes
kernel oplocks = no
kernel share modes = no

# Performance - Logging
log level = 0
max log size = 50

# Disable unnecessary features
load printers = no
printing = bsd
printcap name = /dev/null
disable spoolss = yes

# If using symlinks
unix extensions = no
wide links = yes

[shares]
path = /mnt/shares
browseable = yes
writable = yes
guest ok = yes
create mask = 0664
directory mask = 0775
```

---

## 3. NFS Server Optimization

### 3.1 Increase NFS Daemon Threads

**Current**: Likely 8 threads (default)
**Recommended**: 2x number of CPU cores (4 cores = 8-16 threads)

Edit `/etc/default/nfs-kernel-server`:
```bash
# Increase NFS threads for better concurrent performance
RPCNFSDCOUNT=16
```

Restart NFS:
```bash
pct exec 178 -- systemctl restart nfs-kernel-server
```

### 3.2 NFS Server Export Options

Edit `/etc/exports` for optimal performance:

```bash
# Async mode for better performance (use with caution on critical data)
/mnt/shares *(rw,async,no_subtree_check,no_root_squash)
/mnt/storage *(rw,async,no_subtree_check,no_root_squash)

# For maximum reliability (slower but safer):
# /mnt/shares *(rw,sync,no_subtree_check,no_root_squash)
```

**Async vs Sync**:
- `async`: Faster (replies before data hits disk), risk of data loss on crash
- `sync`: Safer (waits for disk), slower performance
- **Recommendation**: Use `async` for non-critical data, `sync` for critical

Apply changes:
```bash
pct exec 178 -- exportfs -ra
```

### 3.3 NFS Client Mount Options

When mounting from clients, use these optimized options:

```bash
# For large files (media, backups)
mount -t nfs -o rsize=1048576,wsize=1048576,timeo=14,intr 192.168.0.178:/mnt/storage /mnt/nfs

# For many small files
mount -t nfs -o rsize=32768,wsize=32768,noatime,nodiratime,intr 192.168.0.178:/mnt/shares /mnt/nfs
```

**Key Options**:
- `rsize/wsize`: Read/write buffer sizes (max 1048576 = 1MB)
- `noatime,nodiratime`: Don't update access times (huge performance gain)
- `timeo=14`: Timeout value
- `intr`: Allow interrupts

### 3.4 NFS v4 vs v3

**NFSv4 Benefits**:
- Better performance over WAN
- Better security (Kerberos support)
- Stateful protocol

**NFSv3 Benefits**:
- Sometimes faster on LAN
- Simpler, less overhead
- Better tested on older clients

Edit `/etc/default/nfs-kernel-server`:
```bash
# Enable both v3 and v4
RPCNFSDOPTS="-V 3 -V 4 -N 2"
```

---

## 4. Network Stack Tuning

### 4.1 System-wide Network Optimization

Create `/etc/sysctl.d/99-fileserver-tuning.conf` on CT178:

```bash
# Network Performance Tuning for File Server

# TCP Buffer Sizes (already good, but ensure they're set)
net.core.rmem_max = 134217728
net.core.wmem_max = 134217728
net.core.rmem_default = 16777216
net.core.wmem_default = 16777216
net.ipv4.tcp_rmem = 4096 87380 134217728
net.ipv4.tcp_wmem = 4096 65536 134217728

# Increase connection backlog
net.core.netdev_max_backlog = 5000
net.core.somaxconn = 8192

# TCP Performance
net.ipv4.tcp_window_scaling = 1
net.ipv4.tcp_timestamps = 1
net.ipv4.tcp_sack = 1
net.ipv4.tcp_no_metrics_save = 1
net.ipv4.tcp_moderate_rcvbuf = 1

# BBR Congestion Control (already enabled - excellent!)
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr

# TCP Fast Open
net.ipv4.tcp_fastopen = 3

# Connection tracking (for busy file servers)
net.netfilter.nf_conntrack_max = 131072
net.nf_conntrack_max = 131072

# Reduce TIME_WAIT connections
net.ipv4.tcp_fin_timeout = 15
net.ipv4.tcp_tw_reuse = 1

# Increase local port range
net.ipv4.ip_local_port_range = 1024 65535
```

Apply immediately:
```bash
pct exec 178 -- sysctl -p /etc/sysctl.d/99-fileserver-tuning.conf
```

**Note**: BBR is already enabled, which is excellent for file transfers!

### 4.2 Host-Level Network Tuning (Optional)

On AGLSRV1 host, verify these settings exist in `/etc/sysctl.d/`:

```bash
# Check host network tuning
sysctl net.ipv4.tcp_congestion_control
sysctl net.core.rmem_max
sysctl net.core.wmem_max
```

---

## 5. ZFS ARC Cache Optimization

### 5.1 Current ZFS Status

Check ARC usage on host:
```bash
# On AGLSRV1
ssh root@AGLSRV1 "cat /proc/spl/kstat/zfs/arcstats | grep -E 'size|c_max|c_min|hits|misses'"
```

### 5.2 ZFS ARC Recommendations for File Server

**File Server Profile**: Large ARC cache for maximum performance

Recommended ARC size based on host memory:
- **Host has 128GB RAM**: Allocate 64-96GB to ARC
- **Host has 64GB RAM**: Allocate 32-48GB to ARC
- **Host has 32GB RAM**: Allocate 16-24GB to ARC

### 5.3 Configure ZFS ARC Size (On Host)

Create `/etc/modprobe.d/zfs.conf` on AGLSRV1:

```bash
# ZFS ARC Cache Tuning for File Server Workload
# Adjust values based on total system RAM

# For 128GB host RAM (example):
options zfs zfs_arc_max=103079215104  # 96 GB in bytes
options zfs zfs_arc_min=53687091200   # 50 GB in bytes

# For 64GB host RAM (example):
# options zfs zfs_arc_max=51539607552   # 48 GB in bytes
# options zfs zfs_arc_min=21474836480   # 20 GB in bytes

# ARC tuning for file server
options zfs l2arc_write_boost=33554432    # 32 MB
options zfs l2arc_write_max=16777216      # 16 MB
options zfs l2arc_headroom=4              # Headroom multiplier
options zfs l2arc_noprefetch=0            # Enable prefetch
```

**Apply Changes** (requires reboot):
```bash
# Update initramfs
update-initramfs -u

# Reboot host (schedule maintenance window)
reboot
```

### 5.4 Monitor ARC Hit Rate

Check ARC effectiveness:
```bash
# Target: 90-95% hit rate
arc_summary | grep "Hit Rate"

# Or manually:
cat /proc/spl/kstat/zfs/arcstats | grep -E "hits|misses" | awk '{print $1, $3}'
```

### 5.5 Consider L2ARC (SSD Cache)

If you have spare NVMe/SSD, add as L2ARC cache:

```bash
# Add NVMe as L2ARC cache (example)
zpool add spark cache /dev/nvme1n1
zpool add overpower cache /dev/nvme2n1
```

**Benefits**: Extends ARC beyond RAM, dramatically improves random read performance

---

## 6. Container Resource Adjustment

### 6.1 Increase CPU Cores

```bash
# Stop CT178
pct stop 178

# Increase to 8 cores (or more if host allows)
pct set 178 -cores 8

# Start CT178
pct start 178
```

**Why**: File servers benefit from more cores for:
- Concurrent SMB/NFS connections
- Multiple file transfers
- ZFS compression/decompression
- Network packet processing

### 6.2 Memory Allocation

**Recommended for File Server**:
```bash
# Increase to 16GB for optimal performance
pct set 178 -memory 16384 -swap 8192
```

**Minimum**:
```bash
# At least 8GB for decent performance
pct set 178 -memory 8192 -swap 4096
```

### 6.3 I/O Priority (Optional)

If multiple containers compete for I/O:

```bash
# Give CT178 higher I/O priority
pct set 178 -blkio.weight 1000
```

---

## 7. Monitoring and Benchmarking

### 7.1 Baseline Performance Test

Before optimizations, benchmark:

```bash
# SMB Performance Test (from Windows client)
# Copy 10GB file, note time

# NFS Performance Test
pct exec 178 -- dd if=/dev/zero of=/mnt/storage/test10g bs=1M count=10000
# Note write speed

# Network iperf test
pct exec 178 -- iperf3 -s  # On CT178
iperf3 -c 192.168.0.178     # From client
```

### 7.2 Monitor During Operations

**Samba Stats**:
```bash
pct exec 178 -- smbstatus
pct exec 178 -- watch -n 1 'smbstatus | head -20'
```

**NFS Stats**:
```bash
pct exec 178 -- nfsstat -s  # Server stats
pct exec 178 -- nfsstat -c  # Client stats (when accessing NFS)
pct exec 178 -- nfsiostat 1  # Real-time I/O stats
```

**Network Stats**:
```bash
pct exec 178 -- iftop -i eth0
pct exec 178 -- nethogs
pct exec 178 -- ss -s  # Socket statistics
```

**ZFS Stats** (on host):
```bash
# ARC hit rate
arc_summary

# Pool I/O stats
zpool iostat -v 1

# Real-time ZFS I/O
watch -n 1 'zpool iostat -v spark overpower 1 1'
```

### 7.3 Performance Monitoring Tools

Install on CT178:
```bash
pct exec 178 -- apt update
pct exec 178 -- apt install -y iftop iotop htop nethogs nload sysstat
```

---

## 8. Implementation Roadmap

### Phase 1: CRITICAL - Immediate (Do Today)

**Priority**: Fix disk space and memory

1. ✅ **Free up spark pool** - Target < 80%
   ```bash
   # Find and remove/move large files
   pct exec 178 -- du -sh /mnt/power/* | sort -hr | head -20
   ```

2. ✅ **Increase container memory to 8GB**
   ```bash
   pct stop 178
   pct set 178 -memory 8192 -swap 4096
   pct start 178
   ```

3. ✅ **Quick Samba tuning**
   - Add performance options to smb.conf
   - Restart Samba
   - Test transfers

**Expected Improvement**: 2-5x faster transfers just from these changes

**Time**: 30-60 minutes
**Risk**: Low (backups exist)
**Impact**: High

---

### Phase 2: HIGH PRIORITY - This Week

4. ✅ **Network stack tuning**
   - Apply sysctl tuning
   - Verify BBR enabled
   - Test network performance

5. ✅ **NFS server optimization**
   - Increase NFS threads to 16
   - Optimize export options
   - Update client mount options

6. ✅ **Increase CPU cores to 8**
   ```bash
   pct set 178 -cores 8
   ```

**Expected Improvement**: 3-6x faster overall

**Time**: 2-3 hours
**Risk**: Medium (requires container restart)
**Impact**: Very High

---

### Phase 3: IMPORTANT - This Month

7. ✅ **ZFS ARC tuning**
   - Configure ARC max/min on host
   - Requires host reboot (schedule maintenance)
   - Monitor ARC hit rates

8. ✅ **Add L2ARC cache** (if SSD available)
   - Add NVMe/SSD as cache device to pools
   - Significant performance boost

9. ✅ **Increase memory to 16GB** (optimal)
   ```bash
   pct set 178 -memory 16384 -swap 8192
   ```

**Expected Improvement**: 5-10x faster with ARC + L2ARC

**Time**: 4-6 hours (including maintenance window)
**Risk**: Medium (requires host reboot)
**Impact**: Maximum

---

### Phase 4: OPTIONAL - Long Term

10. ✅ **Monitoring dashboard**
    - Set up Grafana/Prometheus
    - Monitor file server metrics
    - Alert on performance degradation

11. ✅ **10Gb network** (if not already)
    - Upgrade network to 10GbE
    - Requires hardware investment

12. ✅ **HA/Load balancing**
    - Consider second file server
    - Load balance SMB/NFS

**Expected Improvement**: Infrastructure-level enhancements

---

## Quick Reference Commands

### Check Performance
```bash
# SMB connections
pct exec 178 -- smbstatus

# NFS stats
pct exec 178 -- nfsstat -s
pct exec 178 -- nfsiostat 1

# Network throughput
pct exec 178 -- iftop -i eth0

# Disk I/O
pct exec 178 -- iotop

# ZFS ARC hit rate (on host)
ssh root@AGLSRV1 "arc_summary | grep 'Hit Rate'"

# Container resources
pct config 178
```

### Restart Services
```bash
# Restart Samba
pct exec 178 -- systemctl restart smbd nmbd

# Restart NFS
pct exec 178 -- systemctl restart nfs-kernel-server

# Restart networking
pct exec 178 -- systemctl restart networking

# Restart container
pct stop 178 && pct start 178
```

### Test Transfers
```bash
# SMB from Linux client
smbclient //192.168.0.178/shares -U guest
# put largefile.bin

# NFS mount test
mount -t nfs -o rsize=1048576,wsize=1048576 192.168.0.178:/mnt/storage /mnt/test
dd if=/dev/zero of=/mnt/test/testfile bs=1M count=1000

# SFTP test
sftp root@192.168.0.178
put largefile.bin
```

---

## Expected Performance Improvements

### Baseline (Current)
- **SMB**: ~50-100 MB/s (estimated, based on "very slow")
- **NFS**: ~50-100 MB/s
- **SFTP**: ~80-120 MB/s

### After Phase 1 (Immediate)
- **SMB**: ~150-300 MB/s (2-3x improvement)
- **NFS**: ~150-250 MB/s
- **SFTP**: ~120-180 MB/s

### After Phase 2 (High Priority)
- **SMB**: ~300-500 MB/s (4-6x improvement)
- **NFS**: ~300-500 MB/s
- **SFTP**: ~180-250 MB/s

### After Phase 3 (ZFS + Maximum)
- **SMB**: ~500-900 MB/s (8-10x improvement)
- **NFS**: ~500-900 MB/s
- **SFTP**: ~250-400 MB/s

**Note**: Actual speeds depend on:
- Client hardware/network
- File sizes (large vs many small)
- Disk backend speed
- Network infrastructure (1Gb vs 10Gb)

---

## Troubleshooting

### Issue: Still Slow After Tuning

1. **Check disk space** - ZFS performance craters at >80%
   ```bash
   pct exec 178 -- df -h
   ```

2. **Check ARC hit rate** - Should be >90%
   ```bash
   ssh root@AGLSRV1 "arc_summary | grep 'Hit Rate'"
   ```

3. **Check network bottleneck**
   ```bash
   pct exec 178 -- iperf3 -s  # On CT178
   iperf3 -c 192.168.0.178     # From client
   # Should see 900+ Mbps on gigabit, 9+ Gbps on 10Gb
   ```

4. **Check for errors**
   ```bash
   pct exec 178 -- journalctl -xe | grep -i error
   pct exec 178 -- dmesg | grep -i error
   ```

### Issue: Samba Starts Fast, Then Slows Down

**Known Bug**: Fixed in pve-container 4.4-4+

**Workaround**: Restart Samba service
```bash
pct exec 178 -- systemctl restart smbd
```

**Permanent Fix**: Ensure pve-container is updated on host
```bash
ssh root@AGLSRV1 "apt update && apt install pve-container"
```

### Issue: NFS Very Slow

1. **Check NFS thread count**
   ```bash
   pct exec 178 -- cat /proc/fs/nfsd/threads
   # Should show 16+ threads
   ```

2. **Check client mount options**
   ```bash
   mount | grep nfs
   # Should see rsize=1048576,wsize=1048576
   ```

3. **Try NFSv4 instead of v3** (or vice versa)
   ```bash
   mount -t nfs -o nfsvers=4 192.168.0.178:/mnt/storage /mnt/test
   ```

---

## Rollback Procedures

### Revert Samba Changes
```bash
# Restore from backup
pct exec 178 -- cp /etc/samba/smb.conf.backup /etc/samba/smb.conf
pct exec 178 -- systemctl restart smbd nmbd
```

### Revert Network Tuning
```bash
# Remove tuning file
pct exec 178 -- rm /etc/sysctl.d/99-fileserver-tuning.conf
pct exec 178 -- sysctl -p  # Reload defaults
pct exec 178 -- reboot
```

### Revert Container Resources
```bash
# Restore original settings
pct stop 178
pct set 178 -memory 2048 -swap 2048 -cores 4
pct start 178
```

---

## Documentation

**Configuration Files**:
- `/etc/samba/smb.conf` - Samba configuration
- `/etc/exports` - NFS exports
- `/etc/default/nfs-kernel-server` - NFS server settings
- `/etc/sysctl.d/99-fileserver-tuning.conf` - Network tuning
- `/etc/modprobe.d/zfs.conf` - ZFS ARC settings (on host)

**Logs**:
- `/var/log/samba/` - Samba logs
- `/var/log/syslog` - System logs
- `journalctl -u smbd` - Samba service logs
- `journalctl -u nfs-kernel-server` - NFS logs

**Backup Before Changes**:
```bash
pct exec 178 -- cp /etc/samba/smb.conf /etc/samba/smb.conf.backup-$(date +%Y%m%d)
pct exec 178 -- cp /etc/exports /etc/exports.backup-$(date +%Y%m%d)
pct exec 178 -- cp /etc/default/nfs-kernel-server /etc/default/nfs-kernel-server.backup-$(date +%Y%m%d)
```

---

## Summary

### Critical Actions (Do First):
1. 🔴 **Free up spark pool** (currently 100% full) - CRITICAL
2. 🟡 **Increase memory to 8GB minimum** - HIGH
3. 🟡 **Apply Samba quick tuning** - HIGH

### Expected Timeline:
- **Phase 1**: 30-60 minutes → 2-3x improvement
- **Phase 2**: 2-3 hours → 4-6x improvement
- **Phase 3**: 4-6 hours + maintenance window → 8-10x improvement

### Key Performance Factors:
1. **Disk Space**: Keep ZFS pools < 80% full
2. **Memory**: File servers need RAM for caching
3. **Network**: BBR already enabled (good!)
4. **ZFS ARC**: Large ARC cache = fast reads
5. **Service Config**: Optimized Samba/NFS settings

---

*Performance Optimization Guide for CT178*
*Version 1.0 - 2025-10-14*
*All recommendations based on 2025 best practices and real-world file server deployments*
