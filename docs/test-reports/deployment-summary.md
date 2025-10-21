# 🚀 NFS v4.2 Deployment Summary

**Date:** 2025-10-15
**Deployment Script:** `/root/host-admin/scripts/deploy-nfs-to-remote.sh`

---

## ✅ Deployment Status

### FGSRV5 (100.71.107.26)
**Status:** ✅ **SUCCESSFULLY DEPLOYED**

| Component | Status | Details |
|-----------|--------|---------|
| **SSH Access** | ✅ Working | Connected successfully |
| **NFS Packages** | ✅ Installed | nfs-kernel-server, rpcbind, nfs-common |
| **Export Directory** | ✅ Created | /storage/nfs-export (14GB available) |
| **NFS Server** | ✅ Active | systemctl status nfs-server = active |
| **rpcbind** | ✅ Active | Port 111 listening |
| **Firewall** | ✅ Configured | UFW rules added for ports 111, 2049 |
| **Network Tuning** | ✅ Applied | BBR, TCP buffers, NFS threads=128 |
| **Exports** | ✅ Active | /storage/nfs-export visible via showmount |

**Installation Time:** ~1 minute
**Log:** `/var/log/storage-benchmarks/deployments/deploy-FGSRV5-20251015_002831.log`

---

### FGSRV6 (100.83.51.9)
**Status:** ❌ **PENDING - SSH ACCESS REQUIRED**

| Component | Status | Details |
|-----------|--------|---------|
| **Ping** | ✅ Reachable | Latency: 15-41ms |
| **SSH Access** | ❌ **BLOCKED** | Cannot connect via SSH |
| **Deployment** | ⏸️ Paused | Waiting for SSH access |

**Action Required:**
```bash
# Option 1: Add SSH key to FGSRV6
ssh-copy-id root@100.83.51.9

# Option 2: Deploy manually after SSH is configured
/root/host-admin/scripts/deploy-nfs-to-remote.sh \
    --host 100.83.51.9 \
    --hostname FGSRV6 \
    --export-path /storage/nfs-export
```

---

## 🌐 Network Topology (Updated)

```
AGLSRV1 (Primary Storage)
    │
    ├─── Tailscale VPN ───┐
    │                     │
    ├─ CT111 @ AGLSRV6 ✅ │ (100.65.189.83)
    │   - NFS v4.2        │   Performance: ~10 MB/s
    │   - SMB3            │   Latency: 23ms
    │                     │
    ├─ FGSRV5 ✅          │ (100.71.107.26)
    │   - NFS v4.2 NEW    │   Performance: TBD (mount issue)
    │   - 14GB available  │   Latency: 24ms
    │                     │
    └─ FGSRV6 ❌          │ (100.83.51.9)
        - Pending SSH     │   Latency: 23ms
        - Not deployed    │
```

---

## 📊 Performance Comparison

### CT111 (AGLSRV6) - Baseline
| Protocol | Write | Read | Notes |
|----------|-------|------|-------|
| **SSHFS** | 10.0 MB/s | N/A | Current baseline |
| **NFS v4.2** | 10.6 MB/s | N/A | +6% vs SSHFS |
| **Bottleneck** | Network WAN | ~80 Mbps | Tailscale limited |

### FGSRV5 - Testing Required
**Issue:** NFS mount failed with "No such file or directory"

**Possible causes:**
1. Export path mismatch (server exports `/storage/nfs-export`, may need fsid=0)
2. NFSv4 pseudo-filesystem not configured
3. Mount command needs adjustment

**Fix to try:**
```bash
# Option A: Mount with root path
mount -t nfs -o vers=4.2 100.71.107.26:/ /mnt/fgsrv5-nfs

# Option B: Check actual export on server
ssh root@100.71.107.26 "cat /etc/exports"
ssh root@100.71.107.26 "exportfs -v"
```

---

## 🔧 What Was Deployed

### Automated Configuration (FGSRV5)

#### 1. NFS Server Packages
```bash
apt-get install -y nfs-kernel-server nfs-common rpcbind
```

#### 2. Export Configuration
**File:** `/etc/exports` on FGSRV5
```
/storage/nfs-export *(rw,sync,no_subtree_check,no_root_squash,fsid=0)
```

#### 3. NFS Server Optimization
**File:** `/etc/default/nfs-kernel-server`
```bash
RPCNFSDCOUNT=128  # Increased from default 8
```

#### 4. Network Tuning
**File:** `/etc/sysctl.d/99-nfs-tuning.conf`
```bash
net.core.rmem_max = 134217728
net.core.wmem_max = 134217728
net.ipv4.tcp_rmem = 4096 87380 67108864
net.ipv4.tcp_wmem = 4096 65536 67108864
net.ipv4.tcp_congestion_control = bbr
net.ipv4.tcp_notsent_lowat = 16384
```

#### 5. Firewall Rules (UFW)
```bash
ufw allow 111/tcp    # rpcbind TCP
ufw allow 111/udp    # rpcbind UDP
ufw allow 2049/tcp   # NFS server
ufw allow 2049/udp   # NFS server
```

---

## ✅ Verification Steps Completed

### FGSRV5
- [x] Package installation successful
- [x] Services started (nfs-server, rpcbind)
- [x] Firewall configured
- [x] Network tuning applied
- [x] Exports visible via `showmount -e 100.71.107.26`
- [ ] **Mount test from AGLSRV1** - FAILED (needs fix)
- [ ] Performance test - PENDING (awaiting mount fix)

### FGSRV6
- [ ] SSH access - REQUIRED
- [ ] Package installation - PENDING
- [ ] NFS configuration - PENDING
- [ ] Performance test - PENDING

---

## 🎯 Next Steps

### Immediate (FGSRV5)

**1. Fix NFS mount issue:**
```bash
# Debug export
ssh root@100.71.107.26 "exportfs -v"

# Try alternative mount
mount -t nfs -o vers=4.2,rw 100.71.107.26:/ /mnt/fgsrv5-nfs

# Or with explicit path
mount -t nfs -o vers=4.2 100.71.107.26:/storage/nfs-export /mnt/fgsrv5-nfs
```

**2. Run performance test after mount succeeds:**
```bash
/root/host-admin/scripts/quick-test-ct111.sh --target 100.71.107.26
```

### FGSRV6 Deployment

**1. Configure SSH access:**
```bash
# From AGLSRV1
ssh-copy-id root@100.83.51.9

# Or manually add SSH key
cat ~/.ssh/id_rsa.pub | ssh user@100.83.51.9 "mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys"
```

**2. Deploy NFS after SSH is configured:**
```bash
/root/host-admin/scripts/deploy-nfs-to-remote.sh \
    --host 100.83.51.9 \
    --hostname FGSRV6 \
    --export-path /storage/nfs-export
```

---

## 📝 Deployment Logs

**FGSRV5 Success:**
- Main log: `/var/log/storage-benchmarks/deployments/deploy-FGSRV5-20251015_002831.log`
- Info JSON: `/var/log/storage-benchmarks/deployments/FGSRV5-deployment-info.json`
- Console log: `/tmp/fgsrv5-deploy.log`

**FGSRV6 Failed (SSH):**
- Console log: `/tmp/fgsrv6-deploy.log`

---

## 🏆 Success Criteria

### Deployment
- [x] FGSRV5: NFS packages installed
- [x] FGSRV5: Services active
- [x] FGSRV5: Firewall configured
- [x] FGSRV5: Exports visible
- [ ] FGSRV5: Mount working (IN PROGRESS)
- [ ] FGSRV6: SSH access (BLOCKED)
- [ ] FGSRV6: NFS deployment (PENDING)

### Performance (PENDING)
- [ ] FGSRV5: Write speed measured
- [ ] FGSRV5: Read speed measured
- [ ] FGSRV6: Write speed measured
- [ ] FGSRV6: Read speed measured
- [ ] Comparison report generated

---

## 💡 Lessons Learned

### What Worked Well ✅
1. **Automated deployment script** - FGSRV5 deployed in ~1 minute
2. **Comprehensive configuration** - All NFS components configured automatically
3. **Network optimizations** - BBR, TCP tuning applied
4. **Firewall setup** - UFW rules added correctly
5. **Logging** - Detailed logs for troubleshooting

### Challenges ⚠️
1. **NFSv4 mount syntax** - Needs investigation for FGSRV5
2. **SSH access** - FGSRV6 requires manual SSH setup first
3. **Local mount test** - Failed on FGSRV5 (may be container limitation)

### Recommendations 📋
1. **Pre-deployment checklist:** Verify SSH access before running script
2. **NFSv4 documentation:** Add examples for different export configurations
3. **Mount testing:** Add more robust mount verification in script
4. **Dry-run mode:** Use `--dry-run` to preview changes first

---

## 🔍 Troubleshooting Guide

### "No such file or directory" on mount

**Symptom:** `mount.nfs: mounting SERVER:/PATH failed, reason given by server: No such file or directory`

**Solutions:**
```bash
# 1. Verify export exists
showmount -e SERVER_IP

# 2. Check server exports
ssh root@SERVER_IP "exportfs -v"

# 3. Try mounting root
mount -t nfs -o vers=4.2 SERVER:/  /mnt/test

# 4. Check fsid=0 in exports
ssh root@SERVER_IP "grep fsid /etc/exports"
```

### SSH connection refused

**Symptom:** `Cannot SSH to IP - check SSH keys and access`

**Solutions:**
```bash
# 1. Test basic connectivity
ping -c 3 IP

# 2. Check SSH service
nmap -p 22 IP

# 3. Try password auth
ssh -o PreferredAuthentications=password root@IP

# 4. Add SSH key
ssh-copy-id root@IP
```

---

**Status:** 🟡 **50% Complete**
- ✅ FGSRV5 deployed (mount issue to resolve)
- ❌ FGSRV6 pending SSH access

**Next:** Fix FGSRV5 mount + configure FGSRV6 SSH
