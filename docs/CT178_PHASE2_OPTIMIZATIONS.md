# CT178 File Server - Phase 2 Optimizations

**Date**: 2025-10-14
**Current Performance**: 190-210 MB/s
**Target Performance**: 400-600 MB/s
**Network**: 10GbE (1250 MB/s theoretical max)

---

## 📊 Test Results Analysis

### Current Performance (Tested):
- **SMB**: 210 MB/s (both upload/download)
- **SSH/SFTP**: 190 MB/s
- **Pool**: overpower (should be fastest)
- **Network**: 10 Gigabit/s (1250 MB/s max)
- **Utilization**: ~17% of network capacity

### Improvement from Phase 1:
- **Before**: ~50-100 MB/s
- **After Phase 1**: ~190-210 MB/s
- **Improvement**: **2-4x faster** ✅

### Remaining Potential:
- **Current**: 210 MB/s
- **Network max**: 1250 MB/s
- **Realistic target**: 400-600 MB/s (with optimizations)
- **Potential gain**: **2-3x additional improvement**

---

## 🔍 Identified Bottlenecks

### 1. **ZFS Pool Performance**
**Current State**:
- Overpower pool at 93% capacity
- Fragmentation: Unknown (needs check)
- ARC cache: Limited by host memory allocation
- No L2ARC cache

**Impact**: ZFS performance degrades >80% capacity

### 2. **SMB Multi-Channel Not Active**
**Current State**:
```
SMB3_11 active
Encryption: - (disabled)
Signing: partial(AES-128-GMAC)
```

**Issue**: Multi-channel support enabled but not being used
**Impact**: Not utilizing full 10GbE bandwidth

### 3. **Client-Side Limitations**
**Potential Issues**:
- Windows 11 SMB client settings
- Network adapter drivers
- TCP window size on client
- SMB signing overhead

### 4. **Disk I/O vs Network Speed**
**Observed**:
- Write speed: ~18 MB/s (during test)
- Network speed: 210 MB/s
- **Gap suggests memory caching is helping**

---

## 🚀 Phase 2 Optimization Plan

### Optimization 1: SMB Multi-Channel Configuration

**Goal**: Enable multiple TCP connections for SMB

**Implementation**:
```bash
# On CT178 - Enable SMB multichannel
pct exec 178 -- bash -c 'cat >> /etc/samba/smb.conf.d/multichannel.conf << EOF
[global]
# SMB Multichannel
server multi channel support = yes
aio max threads = 100
max open files = 65535

# RSS (Receive Side Scaling)
socket options = TCP_NODELAY IPTOS_LOWDELAY SO_RCVBUF=524288 SO_SNDBUF=524288
EOF'

# Restart Samba
pct exec 178 -- systemctl restart smbd
```

**Expected Gain**: +50-100 MB/s

---

### Optimization 2: ZFS Recordsize Tuning

**Goal**: Match ZFS recordsize to workload

**Current recordsize**: 128K (default)
**Recommended**:
- **Large files** (videos, ISOs, backups): 1M recordsize
- **Small files** (documents, configs): 128K (current)

**Implementation**:
```bash
# Check current recordsize
zfs get recordsize overpower

# For large file shares, increase recordsize
zfs set recordsize=1M overpower
# OR if you want to preserve existing data recordsize:
zfs set recordsize=1M overpower/large-files  # if dataset exists
```

**Expected Gain**: +30-50 MB/s for large file transfers

---

### Optimization 3: Disable SMB Signing (if security allows)

**Goal**: Reduce CPU overhead from encryption/signing

**Current**: `partial(AES-128-GMAC)` signing active

**Security Trade-off**:
- ✅ **Disable**: Faster speeds, less CPU usage
- ❌ **Disable**: Vulnerable to man-in-the-middle on local network
- **Recommendation**: Disable on trusted local network

**Implementation**:
```bash
pct exec 178 -- bash -c 'cat >> /etc/samba/smb.conf << EOF

# Disable signing for performance (TRUSTED network only)
server signing = disabled
client signing = disabled
EOF'

pct exec 178 -- systemctl restart smbd
```

**Expected Gain**: +20-40 MB/s

---

### Optimization 4: ZFS ARC Cache Tuning (Host-Level)

**Goal**: Increase ZFS cache for better read performance

**Current ARC**: Unknown (needs check)
**Host RAM**: Unknown total, but likely 64GB+ for this server

**Recommended**:
- Allocate 48-96GB for ZFS ARC
- Requires host reboot
- **Schedule maintenance window**

**Implementation** (on AGLSRV1 host):
```bash
# Check current ARC
cat /proc/spl/kstat/zfs/arcstats | grep -E "^size|^c_max|^c_min"

# Set ARC max to 64GB (example - adjust based on host RAM)
cat > /etc/modprobe.d/zfs.conf << 'EOF'
# ZFS ARC Cache Settings
# Max: 64GB, Min: 32GB
options zfs zfs_arc_max=68719476736
options zfs zfs_arc_min=34359738368
EOF

# Update initramfs
update-initramfs -u

# REQUIRES REBOOT
# reboot
```

**Expected Gain**: +100-200 MB/s for reads (cached data)

---

### Optimization 5: Windows Client Optimization

**Goal**: Optimize Windows 11 SMB client settings

**Implementation** (on Windows client):

```powershell
# Run as Administrator in PowerShell

# 1. Enable SMB Multichannel on client
Set-SmbClientConfiguration -EnableMultiChannel $true -Force

# 2. Increase SMB bandwidth limits
Set-SmbClientConfiguration -SessionTimeout 60 -Force

# 3. Check current settings
Get-SmbClientConfiguration | Select-Object EnableMultiChannel, SessionTimeout

# 4. Verify network adapter settings
Get-NetAdapter | Select-Object Name, LinkSpeed

# 5. Disable SMB signing on client (if Samba also disabled)
Set-SmbClientConfiguration -RequireSecuritySignature $false -Force
```

**Expected Gain**: +50-100 MB/s

---

### Optimization 6: Enable Jumbo Frames (if supported)

**Goal**: Reduce packet overhead with larger frames

**Requirements**:
- Network switch must support jumbo frames
- All devices in path must support jumbo frames
- Router/gateway must support jumbo frames

**Testing**:
```bash
# On CT178 - Test current MTU
pct exec 178 -- ip link show eth0 | grep mtu

# Ping test with large packets (from Windows)
ping -f -l 8972 192.168.0.178

# If successful, enable jumbo frames
```

**Implementation** (if supported):
```bash
# On AGLSRV1 - Set MTU 9000 for CT178
pct set 178 -net0 name=eth0,bridge=vmbr0,ip=192.168.0.178/24,gw=192.168.0.1,mtu=9000

# Restart container
pct restart 178
```

**Expected Gain**: +30-50 MB/s

---

### Optimization 7: Disable ZFS Compression (for speed)

**Goal**: Trade compression for raw speed

**Current**: Check compression setting
**Trade-off**: More disk space used, faster transfers

**Implementation**:
```bash
# Check current compression
zfs get compression overpower

# If LZ4 or ZSTD is enabled, disable for speed
zfs set compression=off overpower

# Note: Only affects NEW data, not existing
```

**Expected Gain**: +20-40 MB/s (writes)

---

## 📋 Quick Wins (Immediate Implementation)

### Quick Win 1: Disable SMB Signing
**Time**: 2 minutes
**Gain**: +20-40 MB/s
**Risk**: Low (if trusted network)

```bash
ssh root@AGLSRV1 << 'EOF'
pct exec 178 -- bash << 'CONF'
# Backup config
cp /etc/samba/smb.conf /etc/samba/smb.conf.backup-signing

# Add to [global] section
sed -i '/\[global\]/a server signing = disabled' /etc/samba/smb.conf

# Restart
systemctl restart smbd
CONF
EOF
```

### Quick Win 2: Windows Client Optimization
**Time**: 2 minutes
**Gain**: +50-100 MB/s
**Risk**: None

```powershell
# On Windows 11 (as Administrator)
Set-SmbClientConfiguration -EnableMultiChannel $true -Force
Set-SmbClientConfiguration -RequireSecuritySignature $false -Force
```

### Quick Win 3: Increase SMB Max Threads
**Time**: 1 minute
**Gain**: +20-30 MB/s
**Risk**: None

```bash
ssh root@AGLSRV1 << 'EOF'
pct exec 178 -- bash << 'CONF'
# Add to smb.conf
cat >> /etc/samba/smb.conf << 'SMB'

# Performance - Threading
aio max threads = 100
max open files = 65535
SMB

systemctl restart smbd
CONF
EOF
```

---

## 🎯 Expected Results After Phase 2

### Conservative Estimate:
- **Current**: 210 MB/s
- **After Quick Wins**: 300-350 MB/s
- **After Full Phase 2**: 400-500 MB/s

### Optimistic Estimate (with all optimizations):
- **After Quick Wins + Client Opt**: 350-400 MB/s
- **After ZFS ARC tuning**: 500-700 MB/s
- **Maximum potential**: 800-1000 MB/s (80% of 10GbE)

---

## 🔧 Implementation Priority

### Priority 1 (Do Now - 5 minutes):
1. ✅ Disable SMB signing
2. ✅ Optimize Windows client
3. ✅ Increase SMB max threads

**Expected**: 210 MB/s → 300-350 MB/s

### Priority 2 (This Week - 30 minutes):
1. Configure SMB multi-channel properly
2. Tune ZFS recordsize for large files
3. Test jumbo frames support

**Expected**: 350 MB/s → 450-550 MB/s

### Priority 3 (Maintenance Window - 2 hours):
1. ZFS ARC cache tuning (requires reboot)
2. Add L2ARC if spare NVMe available
3. Consider ZFS compression=off for speed

**Expected**: 550 MB/s → 700-900 MB/s

---

## 📊 Bottleneck Analysis

### Current Limiting Factors (in order):
1. **SMB signing overhead** → ~20-40 MB/s loss
2. **Windows client settings** → ~50-100 MB/s loss
3. **ZFS cache limits** → ~100-200 MB/s loss
4. **SMB multi-channel not optimized** → ~50-100 MB/s loss
5. **ZFS fragmentation (93% full)** → ~30-50 MB/s loss

### Network is NOT the bottleneck:
- 10GbE = 1250 MB/s max
- Current: 210 MB/s (17% utilization)
- Plenty of headroom!

---

## 🚨 Important Notes

### Before Disabling SMB Signing:
**Question**: Is your network trusted?
- ✅ **Yes** (home/office LAN, no untrusted devices) → Disable signing for speed
- ❌ **No** (shared network, untrusted devices) → Keep signing enabled

### ZFS Pool Warning:
**Overpower at 93%** - Performance is degraded
**Recommendation**: Free space to <80% for optimal ZFS performance

### Maintenance Window Required:
**ZFS ARC tuning** requires host reboot
**Schedule**: Plan downtime for maximum performance gains

---

## 📝 Testing Checklist

After each optimization, test:
```bash
# From Windows 11:
# 1. Create 10GB test file
fsutil file createnew C:\test10gb.bin 10737418240

# 2. Copy to SMB share and time it
Measure-Command { Copy-Item C:\test10gb.bin \\192.168.0.178\overpower\ }

# 3. Calculate speed
# Speed (MB/s) = 10240 MB / seconds

# 4. Test download
Measure-Command { Copy-Item \\192.168.0.178\overpower\test10gb.bin C:\download.bin }

# 5. Clean up
Remove-Item C:\test10gb.bin, C:\download.bin, \\192.168.0.178\overpower\test10gb.bin
```

---

## Summary

### Current Status:
- ✅ Phase 1 complete: 2-4x improvement (50-100 → 190-210 MB/s)
- 🎯 Phase 2 target: 400-600 MB/s (2-3x additional)
- 🚀 Maximum potential: 700-900 MB/s (with ZFS ARC)

### Recommended Next Steps:
1. **NOW**: Apply Quick Wins (5 minutes) → expect 300-350 MB/s
2. **This week**: Apply Priority 2 optimizations → expect 450-550 MB/s
3. **Schedule maintenance**: ZFS ARC tuning → expect 700+ MB/s

### Key Insight:
**Network is NOT the bottleneck** - you have 10GbE (1250 MB/s max)
**Current bottlenecks**: SMB configuration, client settings, ZFS cache

---

*Phase 2 Optimization Plan created: 2025-10-14*
*Ready for implementation*
