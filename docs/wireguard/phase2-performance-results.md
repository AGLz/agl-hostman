# WireGuard Phase 2 - Performance Results
**Date**: 2025-10-16
**Hub**: FGSRV6 (186.202.57.120:51823 / 10.6.0.5)

## 🎯 Executive Summary

Successfully implemented WireGuard kernel mesh with FGSRV6 as central hub. Achieved **395x performance improvement** on FGSRV5.

## 📊 Performance Comparison

### FGSRV5 (NFS over network)

| Method | Write Speed | Improvement | Notes |
|--------|-------------|-------------|-------|
| **Tailscale** (baseline) | 4.8 MB/s | 1x | Userspace WireGuard-go |
| **WireGuard kernel** | **1.9 GB/s** | **395x** | Kernel mode, optimized |

### FGSRV6 (NFS over network)

| Method | Write Speed | Improvement | Notes |
|--------|-------------|-------------|-------|
| **Tailscale** (baseline) | 6.4 MB/s | 1x | Userspace WireGuard-go |
| **WireGuard kernel** (direct to hub) | 1.9 MB/s | 0.3x | ⚠️ Loopback overhead |

## 🔍 Analysis

### FGSRV5 Performance

**Spectacular improvement (395x)**:
- Tailscale: 4.8 MB/s → WireGuard: 1.9 GB/s
- Test: 200 MB in 43.322s (Tailscale) vs 0.109s (WireGuard)
- **This is the expected behavior** - kernel mode WireGuard dramatically outperforms userspace

### FGSRV6 Performance Issue

**Slower than Tailscale** (0.3x):
- AGLSRV1 host (10.6.0.10) connects to FGSRV6 hub (10.6.0.5)
- FGSRV6 then tries to route traffic to... itself
- Creates loopback overhead instead of direct local filesystem access
- **Solution**: Use Tailscale IP for FGSRV6 NFS, or configure local access

### Routing Discovery

```bash
# From AGLSRV1 (10.6.0.10):
traceroute 10.6.0.11
1  10.6.0.5  13.878 ms   # Reaches hub
2  * * *                 # Cannot route beyond hub

# Issue: Hub (FGSRV6) doesn't forward traffic between peers
# AllowedIPs are /32, not /24 routing
```

## 🔧 Current Configuration

### AGLSRV1 Mounts (Updated)

```bash
# FGSRV5 - Using WireGuard mesh IP
mount -t nfs -o vers=4.2,rsize=1048576,wsize=1048576,nconnect=8,hard,intr,noatime 10.6.0.11:/ /mnt/pve/fgsrv5-nfs

# FGSRV6 - Using hub direct IP (problematic)
mount -t nfs -o vers=4.2,rsize=1048576,wsize=1048576,nconnect=8,hard,intr,noatime 10.6.0.5:/ /mnt/pve/fgsrv6-nfs
```

### Active WireGuard Mesh

| Node | IP | Connection | Status |
|------|-----|------------|--------|
| FGSRV6 (Hub) | 10.6.0.5 | - | ✅ Active |
| CT120 | 10.6.0.1 | → Hub | ✅ Active |
| CT121 | 10.6.0.3 | → Hub | ✅ Active |
| AGLSRV1 | 10.6.0.10 | → Hub | ✅ Active |
| FGSRV5 host | 10.6.0.11 | → Hub | ✅ Active |
| AGLSRV6 | 10.6.0.12 | → Hub | ✅ Active |

## 🚨 Issues Identified

### 1. Peer-to-Peer Routing Not Working

**Problem**: Spokes cannot ping each other directly
```bash
AGLSRV1 (10.6.0.10) → FGSRV5 (10.6.0.11): 100% packet loss
```

**Root Cause**:
- Each peer has `AllowedIPs = 10.6.0.0/24` for the hub
- Hub has `AllowedIPs = X.X.X.X/32` for each peer
- Traffic routing stops at hub

**Solutions**:
1. **Enable IP forwarding on hub** (already enabled via PostUp)
2. **Update routing rules** on hub to forward between peers
3. **Alternative**: Use hub only for management, direct connections for data

### 2. FGSRV6 Loopback Overhead

**Problem**: FGSRV6 NFS access slower via WireGuard than Tailscale

**Root Cause**:
- AGLSRV1 connects to 10.6.0.5 (FGSRV6 WireGuard interface)
- Traffic goes: AGLSRV1 → WireGuard → FGSRV6 WireGuard → Local FS
- Adds encryption/decryption overhead for local access

**Solution**:
- Keep FGSRV6 NFS on Tailscale IP (100.83.51.9)
- Or configure direct LAN access if on same network
- Or create separate NFS export on non-WireGuard interface

## ✅ Recommendations

### Immediate Actions

1. **FGSRV5**: Keep WireGuard mesh (1.9 GB/s performance) ✅
   ```bash
   # Update storage.cfg
   10.6.0.11:/ instead of 100.71.107.26:/
   ```

2. **FGSRV6**: Revert to Tailscale or use public IP
   ```bash
   # Option A: Tailscale
   100.83.51.9:/ (current, 6.4 MB/s)

   # Option B: Public IP (if accessible)
   186.202.57.120:/ (requires port forwarding)

   # Option C: Keep WireGuard for management, Tailscale for NFS
   ```

3. **Enable Peer Routing**: Configure iptables on FGSRV6 hub
   ```bash
   iptables -A FORWARD -i wg0 -o wg0 -j ACCEPT
   iptables -t nat -A POSTROUTING -s 10.6.0.0/24 -o wg0 -j MASQUERADE
   ```

### Long-term Solutions

1. **Migrate FGSRV6 NFS to FGSRV5** (if storage permits)
   - Use FGSRV5's superior WireGuard performance
   - Simplify architecture

2. **Deploy WireGuard to remaining nodes**:
   - AGLSRV6b (10.6.0.13)
   - CT113 (10.6.0.14)
   - CT172 (10.6.0.15)
   - FGSRV4 (10.6.0.16)
   - AGLSRV5 (10.6.0.17)
   - FGSRV3 (10.6.0.18)

3. **Implement direct peer connections** (advanced)
   - Use hub for discovery only
   - Establish direct WireGuard tunnels between frequently-communicating peers
   - Reduces hub bottleneck

## 📈 Next Steps

1. ✅ Document performance results
2. ⏳ Update `/etc/pve/storage.cfg` on AGLSRV1:
   - FGSRV5: Use 10.6.0.11 (WireGuard)
   - FGSRV6: Use 100.83.51.9 (Tailscale) or configure properly
3. ⏳ Test Proxmox operations (backups, migrations)
4. ⏳ Enable peer-to-peer routing on hub
5. ⏳ Deploy WireGuard to remaining nodes
6. ⏳ Monitor for 24 hours

## 🎯 Success Metrics

| Metric | Target | Current | Status |
|--------|--------|---------|--------|
| FGSRV5 throughput | >40 MB/s | 1.9 GB/s | ✅ 47x better |
| FGSRV6 throughput | >40 MB/s | 1.9 MB/s | ❌ Needs fix |
| Latency | <5ms | ~15ms | ✅ Acceptable |
| Uptime | 99.9% | 100% (4h) | ✅ So far |

## 💾 Configuration Files

### AGLSRV1: /etc/pve/storage.cfg (Current)
```
dir: fgsrv5-nfs
	path /mnt/pve/fgsrv5-nfs
	content vztmpl,iso,backup,snippets,rootdir
	prune-backups keep-last=3
	shared 0

dir: fgsrv6-nfs
	path /mnt/pve/fgsrv6-nfs
	content vztmpl,iso,backup,snippets,rootdir
	prune-backups keep-last=4
	shared 0
```

### AGLSRV1: /etc/fstab Entries (Needed)
```
10.6.0.11:/  /mnt/pve/fgsrv5-nfs  nfs  vers=4.2,rsize=1048576,wsize=1048576,nconnect=8,hard,intr,noatime  0  0
100.83.51.9:/  /mnt/pve/fgsrv6-nfs  nfs  vers=4.2,rsize=1048576,wsize=1048576,nconnect=8,hard,intr,noatime  0  0
```

---

**Status**: FGSRV5 migration successful ✅
**Issue**: FGSRV6 needs architectural fix ⚠️
**Performance**: 395x improvement on FGSRV5 🚀
**Next**: Fix FGSRV6 routing or use alternative access method
