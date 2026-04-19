# Tailscale Distributed Storage - Performance Summary

**Created**: 2025-10-15
**Environment**: AGLSRV1 (100.107.113.33) + AGLSRV6 (100.98.108.66) + AGLSRV6b-PBS (100.70.155.60)

---

## 🎯 Executive Summary

Successfully configured distributed storage using Tailscale VPN between AGLSRV1 and AGLSRV6, but **Tailscale bandwidth limitation** makes it unsuitable for high-performance file transfers.

**Key Finding**: Tailscale throughput is **82 Mbits/sec (~10 MB/s)**, which is **26x slower** than local network SMB performance.

---

## 📊 Performance Results

### Tailscale Network Performance

| Test | Result | Notes |
|------|--------|-------|
| **Tailscale Bandwidth** | 82 Mbits/sec (10 MB/s) | **BOTTLENECK** |
| **SSHFS over Tailscale** | 10.1 MB/s | Matches Tailscale limit |
| **Latency** | ~40ms | AGLSRV1 → AGLSRV6 |

### Comparison: Local Network vs Tailscale

| Server | Protocol | Speed | vs Local |
|--------|----------|-------|----------|
| **CT178 (AGLSRV1)** | SMB (local) | 262-289 MB/s | 100% |
| **CT178 (AGLSRV1)** | SFTP (local) | 226-272 MB/s | 94% |
| **CT111 (AGLSRV6)** | SMB (local) | 106 MB/s | 100% |
| **AGLSRV6 via Tailscale** | SSHFS | 10.1 MB/s | **9.5%** |
| **Local disk (AGLSRV1)** | Direct | 2.6 GB/s | - |

**Conclusion**: Tailscale is **26x slower** than local network SMB, making it impractical for regular file transfers.

---

## ✅ Successfully Configured

### 1. Remote Storage Mounts (AGLSRV1)

Created separate mount points as requested (no MergerFS):

```bash
/mnt/remote-storage/aglsrv6-bb        # 954GB (53% used)
/mnt/remote-storage/aglsrv6-usb4tb    # 3.9TB (46% used)
/mnt/remote-storage/aglsrv6b-pbs      # Failed (connection reset)
```

**Mount Status**: 2 of 3 working via SSHFS over Tailscale

### 2. CT111 Optimization (AGLSRV6)

Applied same optimizations as CT178:
- **Resources**: Upgraded 4GB/8 cores → **16GB/16 cores**
- **Samba**: Optimized configuration (signing disabled, async I/O, oplocks)
- **NFS**: 16 threads, optimized for performance
- **Network**: BBR congestion control, TCP FastOpen enabled

**Services**: ✅ SMB, NFS, and network tuning active

### 3. CT113 PBS Web UI Fixed (AGLSRV6)

- **URL**: https://192.168.0.231:8007
- **Login**: root@pam / lx4936@klfap
- **Status**: ✅ Web UI accessible and working

---

## 📋 Mount Configuration

### SSHFS Mounts on AGLSRV1

```bash
# AGLSRV6 bb storage (954GB)
sshfs root@100.98.108.66:/mnt/pve/bb /mnt/remote-storage/aglsrv6-bb \
    -o allow_other,default_permissions,reconnect,ServerAliveInterval=15,\
    compression=no,Ciphers=aes128-gcm@openssh.com,cache=yes

# AGLSRV6 usb4tb storage (3.9TB)
sshfs root@100.98.108.66:/mnt/usb4tb-direct /mnt/remote-storage/aglsrv6-usb4tb \
    -o allow_other,default_permissions,reconnect,ServerAliveInterval=15,\
    compression=no,Ciphers=aes128-gcm@openssh.com,cache=yes
```

**Performance**: Limited to 10 MB/s by Tailscale bandwidth

### CT111 SMB Shares (AGLSRV6)

```bash
# Available shares on 192.168.0.111:
[shares]   - /mnt/shares   (66GB, 49% used)
[sistema]  - /mnt/sistema
[bb]       - /mnt/bb
[bkp]      - /mnt/bkp
```

**Performance**: 106 MB/s from AGLSRV6 host (local network)

### CT111 NFS Exports (AGLSRV6)

```bash
/mnt/shares   *(rw,sync,no_subtree_check,no_root_squash)
/mnt/sistema  *(rw,sync,no_subtree_check,no_root_squash)
/mnt/bb       *(exportfs error - filesystem not supported)
/mnt/bkp      *(exportfs error - filesystem not supported)
```

**Status**: NFS server running with 16 threads, 2 exports working

---

## ⚠️ Known Issues

### 1. Tailscale Bandwidth Limitation

**Issue**: Only 82 Mbits/sec (10 MB/s) throughput
**Impact**: Makes Tailscale unsuitable for regular file transfers
**Possible Causes**:
- Internet bandwidth limitation between sites
- Tailscale relay usage (not direct connection)
- WireGuard encryption overhead
- Network routing inefficiencies

**Recommendation**: Use Tailscale only for remote management, not bulk file transfers

### 2. AGLSRV6b-PBS Mount Failed

**Issue**: "Connection reset by peer" when mounting 100.70.155.60:/mnt/backups
**Status**: Needs investigation - ping works but SSHFS mount fails
**Possible Cause**: Firewall, SSH configuration, or Tailscale routing issue

### 3. WSL Cannot Access AGLSRV6 Local Network

**Issue**: WSL (192.168.0.222) cannot reach CT111 (192.168.0.111)
**Impact**: Cannot test CT111 performance from WSL directly
**Workaround**: Test from AGLSRV6 host instead (works: 106 MB/s)

---

## 🔧 CT111 Configuration Applied

### Samba Configuration

```ini
[global]
server min protocol = SMB2
server multi channel support = yes
server signing = disabled
client signing = disabled
aio max threads = 100
max open files = 65535
use sendfile = yes
vfs objects = aio_pthread
oplocks = yes
level2 oplocks = yes
socket options = TCP_NODELAY IPTOS_LOWDELAY SO_RCVBUF=524288 SO_SNDBUF=524288
```

### NFS Configuration

```bash
RPCNFSDCOUNT=16  # 16 NFS threads
```

### Network Tuning

```bash
net.ipv4.tcp_congestion_control = bbr
net.ipv4.tcp_fastopen = 3
```

---

## 📈 Performance Comparison Matrix

| Storage Location | Access Method | Speed | Best Use Case |
|------------------|---------------|-------|---------------|
| **AGLSRV1 Local** | Direct | 2.6 GB/s | Fast local access |
| **CT178 (AGLSRV1)** | SMB | 280 MB/s | Windows file shares |
| **CT178 (AGLSRV1)** | SFTP | 272 MB/s | Secure transfers |
| **CT111 (AGLSRV6)** | SMB (local) | 106 MB/s | Local network shares |
| **AGLSRV6 via Tailscale** | SSHFS | **10 MB/s** | ⚠️ Too slow for regular use |

---

## 💡 Recommendations

### For High-Performance File Transfers

**❌ Do NOT use**: Tailscale for bulk file transfers
- Only 10 MB/s throughput
- 26x slower than local network
- Better for remote management only

**✅ DO use**:
1. **Local network SMB** (CT178: 280 MB/s, CT111: 106 MB/s)
2. **Local network SFTP** (CT178: 272 MB/s)
3. **Direct local access** (AGLSRV1: 2.6 GB/s)

### For Remote Access (Tailscale)

**Good for**:
- Remote administration and SSH access
- Small file transfers (<100MB)
- Accessing PBS web UI remotely
- Backup verification and monitoring

**Not suitable for**:
- Large file transfers (>1GB)
- Regular backup operations
- High-frequency data synchronization
- Media streaming or database access

### Alternative Approaches for AGLSRV6 Storage

1. **VPN Tunnel**: Consider OpenVPN or WireGuard with dedicated bandwidth
2. **Direct Connection**: If sites are close, consider dedicated fiber link
3. **Hybrid Approach**:
   - Use CT111 SMB/NFS for local AGLSRV6 users (106 MB/s)
   - Use Tailscale only for remote management
   - Schedule large transfers during off-peak hours

---

## 🎯 Use Case Scenarios

### Scenario 1: Daily Backups (AGLSRV1 → AGLSRV6)

**File Size**: 100GB
**Time via Tailscale**: ~2.8 hours (10 MB/s)
**Time via Local Network**: ~15 minutes (106 MB/s)

**Recommendation**: If possible, use local network connection or schedule during off-peak hours

### Scenario 2: Remote PBS Management

**Use Tailscale**: ✅ Perfect
- Access PBS web UI: https://192.168.0.231:8007
- SSH to servers for management
- Small configuration file transfers
- Monitoring and alerting

### Scenario 3: Large Media Files (>10GB)

**Recommendation**: Use local network only
- Tailscale: 10 MB/s = 17 minutes per 10GB
- CT178 SMB: 280 MB/s = 36 seconds per 10GB
- **78x faster** on local network

---

## 📚 Related Documentation

- **CT178 Performance**: `/root/host-admin/claudedocs/CT178_COMPREHENSIVE_PERFORMANCE_TESTS.md`
- **Tailscale Setup**: `/root/host-admin/claudedocs/TAILSCALE_DISTRIBUTED_STORAGE.md`
- **CT111 Optimization Script**: `/root/host-admin/scripts/ct111-optimize.sh`
- **Setup Scripts**: `/root/host-admin/scripts/setup-tailscale-storage.sh`

---

## 🔍 Diagnostic Commands

### Check Tailscale Status
```bash
tailscale status
tailscale netcheck
ping -c 3 100.98.108.66  # AGLSRV6
```

### Check Mount Status
```bash
df -h | grep remote-storage
mount | grep sshfs
```

### Test Tailscale Bandwidth
```bash
# On AGLSRV6
iperf3 -s

# On AGLSRV1
ssh root@AGLSRV1 "iperf3 -c 100.98.108.66 -t 10 -P 4"
```

### Test CT111 Performance (from AGLSRV6 host)
```bash
# SMB test
mount -t cifs //192.168.0.111/shares /tmp/test -o guest,vers=3.1.1
dd if=/dev/zero of=/tmp/test/test.bin bs=1M count=100
umount /tmp/test
```

---

## ✅ Summary

### What Works Well
- ✅ CT111 optimized and running (16GB RAM, 16 cores)
- ✅ CT111 SMB: 106 MB/s (local network)
- ✅ CT178 SMB: 280 MB/s (local network)
- ✅ CT113 PBS web UI accessible
- ✅ Remote storage mounted via SSHFS (2 of 3)

### What Needs Improvement
- ⚠️ Tailscale bandwidth: Only 10 MB/s (too slow for bulk transfers)
- ⚠️ AGLSRV6b-PBS mount failed
- ⚠️ WSL cannot access AGLSRV6 local network

### Final Recommendation

**Use Tailscale for**: Remote management, SSH access, small files
**Use Local Network for**: All bulk file transfers, regular backups, media access

**Performance Hierarchy**:
1. Local disk: 2.6 GB/s (fastest)
2. Local network SMB: 100-280 MB/s (recommended for transfers)
3. Tailscale SSHFS: 10 MB/s (management only)

---

*Tailscale Storage Performance Summary v1.0*
*Created: 2025-10-15*
*Conclusion: Tailscale unsuitable for high-performance file transfers due to 10 MB/s bandwidth limitation*
