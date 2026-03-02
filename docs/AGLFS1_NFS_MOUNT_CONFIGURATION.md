# AGLFS1 Storage Mounts - Configuration Documentation

**Date**: 2025-10-21
**Server**: aglfs1 (CT178) at 192.168.0.178
**Client**: WSL on Windows host
**Protocol**: SSHFS (NFS unavailable in WSL)
**Status**: ✅ Production Ready

---

## 📋 Executive Summary

Successfully configured **2 automatic SSHFS mounts** from WSL to aglfs1 (CT178):

1. **overpower storage**: `/mnt/overpower` → `/mnt/nfs-overpower-base` (9.9TB, 93% used)
2. **spark storage**: `/mnt/power` → `/mnt/nfs-spark-base` (7.2TB, 87% used)

**Auto-mount**: Configured via `/etc/wsl.conf` to mount on Windows boot
**Authentication**: Passwordless SSH key authentication
**Reliability**: Automatic reconnection on network interruption

---

## 🎯 Why SSHFS Instead of NFS?

**Problem**: NFS from WSL has persistent connection timeout issues (documented in CT178 reports)

**Solution**: SSHFS over SSH tunnel provides:
- ✅ Reliable mounting from WSL
- ✅ Automatic reconnection on network interruption
- ✅ Encrypted transport (SSH encryption)
- ✅ Same functionality as NFS for file access
- ✅ Better WSL compatibility

**Performance**: SSHFS achieves 50-200 MB/s over local network (suitable for file server access)

---

## 🏗️ Configuration Details

### 1. Mount Points Created

```bash
/mnt/nfs-overpower-base  → root@192.168.0.178:/mnt/overpower (9.9TB)
/mnt/nfs-spark-base      → root@192.168.0.178:/mnt/power (7.2TB)
```

### 2. SSHFS Mount Options

```bash
-o allow_other              # Allow other users to access
-o default_permissions      # Use normal permission checks
-o reconnect                # Auto-reconnect on connection loss
-o ServerAliveInterval=15   # Keep SSH connection alive
-o StrictHostKeyChecking=no # Skip host key verification (local network)
```

### 3. WSL Boot Configuration

**File**: `/etc/wsl.conf`

```ini
[boot]
command = "/usr/local/bin/wsl-mount-nfs-shares.sh"

[network]
generateResolvConf = false
```

### 4. Auto-Mount Script

**File**: `/usr/local/bin/wsl-mount-nfs-shares.sh`

**Features**:
- ✅ Waits for network connectivity (60s timeout)
- ✅ Starts required services (rpcbind)
- ✅ Retry logic (5 attempts with 5s delay)
- ✅ Comprehensive logging to `/var/log/wsl-mount-nfs.log`
- ✅ Skips already-mounted shares
- ✅ Reports success/failure status

**Execution**: Automatically runs on every WSL boot

---

## 📊 Current Status

```bash
$ df -h | grep 192.168.0.178
root@192.168.0.178:/mnt/overpower  9.9T  9.2T  753G  93% /mnt/nfs-overpower-base
root@192.168.0.178:/mnt/power      7.2T  6.2T  1.0T  87% /mnt/nfs-spark-base
```

**Both mounts**: ✅ Active and functioning

---

## 🔧 Management Commands

### Check Mount Status

```bash
# View all mounts
df -h | grep 192.168.0.178

# Check specific mount
mountpoint /mnt/nfs-overpower-base
mountpoint /mnt/nfs-spark-base

# List mount details
mount | grep 192.168.0.178
```

### Manual Mounting

```bash
# Mount overpower
sshfs root@192.168.0.178:/mnt/overpower /mnt/nfs-overpower-base \
  -o allow_other,default_permissions,reconnect,ServerAliveInterval=15

# Mount spark
sshfs root@192.168.0.178:/mnt/power /mnt/nfs-spark-base \
  -o allow_other,default_permissions,reconnect,ServerAliveInterval=15
```

### Manual Unmounting

```bash
# Unmount overpower
fusermount -u /mnt/nfs-overpower-base

# Unmount spark
fusermount -u /mnt/nfs-spark-base

# Force unmount if hung
fusermount -uz /mnt/nfs-overpower-base
```

### Test Auto-Mount Script

```bash
# Run the boot script manually
/usr/local/bin/wsl-mount-nfs-shares.sh

# Check log output
tail -f /var/log/wsl-mount-nfs.log
```

---

## 🔍 Troubleshooting

### Problem: Mounts not appearing on WSL boot

**Solution**:
```bash
# Verify wsl.conf
cat /etc/wsl.conf

# Check script permissions
ls -la /usr/local/bin/wsl-mount-nfs-shares.sh

# Make executable if needed
chmod +x /usr/local/bin/wsl-mount-nfs-shares.sh

# Test script manually
/usr/local/bin/wsl-mount-nfs-shares.sh
```

### Problem: SSH connection refused

**Solution**:
```bash
# Test SSH connectivity
ssh root@192.168.0.178 'echo OK'

# Check SSH key
ls -la /root/.ssh/id_rsa*

# Test passwordless auth
ssh -o BatchMode=yes root@192.168.0.178 'echo OK'
```

### Problem: Mount timeout or hung

**Solution**:
```bash
# Force unmount
fusermount -uz /mnt/nfs-overpower-base
fusermount -uz /mnt/nfs-spark-base

# Verify network connectivity
ping -c 2 192.168.0.178

# Remount
/usr/local/bin/wsl-mount-nfs-shares.sh
```

### Problem: Permission denied on mounted shares

**Solution**:
```bash
# Check SSHFS mount options (allow_other required)
mount | grep sshfs

# Remount with correct options
fusermount -u /mnt/nfs-overpower-base
sshfs root@192.168.0.178:/mnt/overpower /mnt/nfs-overpower-base \
  -o allow_other,default_permissions
```

### Problem: Slow performance

**Diagnostics**:
```bash
# Test transfer speed
dd if=/dev/zero of=/mnt/nfs-overpower-base/test.bin bs=1M count=100
dd if=/mnt/nfs-overpower-base/test.bin of=/dev/null bs=1M

# Check network latency
ping -c 10 192.168.0.178
```

**Expected Performance**:
- Write: 50-200 MB/s (depends on network)
- Read: 50-200 MB/s (depends on caching)
- Latency: <1ms (local network)

---

## 📚 Log Files

### Auto-Mount Log

**Location**: `/var/log/wsl-mount-nfs.log`

**Sample Output**:
```
2025-10-21 14:49:51 - =========================================
2025-10-21 14:49:51 - WSL NFS Auto-Mount Script Starting
2025-10-21 14:49:51 - =========================================
2025-10-21 14:49:51 - Starting required services...
2025-10-21 14:49:51 - Waiting for network connectivity to aglfs1 (192.168.0.178)...
2025-10-21 14:49:51 - Network is ready!
2025-10-21 14:49:51 - Mounting overpower...
2025-10-21 14:49:51 - ✓ Successfully mounted overpower at /mnt/nfs-overpower-base
2025-10-21 14:49:51 - Mounting spark...
2025-10-21 14:49:52 - ✓ Successfully mounted spark at /mnt/nfs-spark-base
2025-10-21 14:49:52 - =========================================
2025-10-21 14:49:52 - Mount Summary:
2025-10-21 14:49:52 -   - overpower: ✓ OK
2025-10-21 14:49:52 -   - spark:     ✓ OK
2025-10-21 14:49:52 - =========================================
```

**View Log**:
```bash
# View entire log
cat /var/log/wsl-mount-nfs.log

# View last 20 lines
tail -20 /var/log/wsl-mount-nfs.log

# Follow log in real-time
tail -f /var/log/wsl-mount-nfs.log
```

---

## 🔐 Security Considerations

### SSH Key Authentication

**Location**: `/root/.ssh/id_rsa`

**Status**: ✅ Configured for passwordless authentication

**Verification**:
```bash
ssh -o BatchMode=yes root@192.168.0.178 'echo OK'
```

### Network Security

- ✅ SSH encryption for all traffic
- ✅ Local network only (192.168.0.0/24)
- ✅ StrictHostKeyChecking disabled (trusted local network)
- ⚠️ Root access used (consider dedicated mount user for production)

### Permissions

- Mount options include `default_permissions` for proper permission checks
- `allow_other` permits other users to access mounted shares
- Original server permissions are preserved

---

## 📈 Performance Expectations

### Network Transfer Speeds

| Access Type | Expected Speed | Actual Use Case |
|-------------|----------------|-----------------|
| **Local file reads** | 50-200 MB/s | Opening files, browsing |
| **Large file transfers** | 100-200 MB/s | Copying large files |
| **Small file operations** | Variable | Many small files = slower |
| **Cached reads** | Up to 500 MB/s | Recently accessed files |

### Latency

- **Local network**: <1ms
- **File operations**: 5-20ms (SSHFS overhead)
- **Directory listings**: 10-50ms (depends on file count)

### Comparison to Native NFS

| Metric | SSHFS | NFS | Winner |
|--------|-------|-----|--------|
| **WSL Compatibility** | ✅ Excellent | ❌ Timeouts | SSHFS |
| **Raw Performance** | 50-200 MB/s | 250-300 MB/s | NFS |
| **Encryption** | ✅ SSH | ❌ None | SSHFS |
| **Auto-reconnect** | ✅ Built-in | ⚠️ Requires NFS4 | SSHFS |
| **Setup Complexity** | Easy | Complex | SSHFS |

**Recommendation**: SSHFS is the better choice for WSL despite slightly lower performance

---

## 🎬 Next Steps

### Immediate
- ✅ Mounts configured and working
- ✅ Auto-mount on boot enabled
- ✅ Logging configured
- ✅ SSH keys set up

### Optional Enhancements

1. **Create dedicated mount user** (instead of root):
   ```bash
   # On aglfs1
   useradd -m -s /bin/bash sshfs-mount
   # Copy SSH keys to new user
   # Update mount script to use new user
   ```

2. **Add monitoring/alerts**:
   ```bash
   # Create health check script
   # Alert if mounts fail
   # Monitor log for errors
   ```

3. **Performance optimization**:
   ```bash
   # Adjust SSHFS cache settings
   # Enable compression for slow links
   # Tune SSH cipher selection
   ```

4. **Add backup validation**:
   ```bash
   # Verify both mounts are accessible
   # Check available space
   # Alert on capacity issues
   ```

---

## 📋 Summary Checklist

- ✅ aglfs1 identified (192.168.0.178, CT178 on AGLSRV1)
- ✅ Mount points created (`/mnt/nfs-overpower-base`, `/mnt/nfs-spark-base`)
- ✅ SSHFS mounts configured (NFS unavailable in WSL)
- ✅ Auto-mount script created and tested
- ✅ WSL boot configuration updated (`/etc/wsl.conf`)
- ✅ SSH key authentication verified
- ✅ Logging configured (`/var/log/wsl-mount-nfs.log`)
- ✅ Manual mount/unmount procedures documented
- ✅ Troubleshooting guide created
- ✅ Performance expectations documented

---

## 🔗 Related Documentation

- **CT178 Performance Report**: `/root/host-admin/claudedocs/CT178_COMPREHENSIVE_PERFORMANCE_TESTS.md`
- **Tailscale Distributed Storage**: `/root/host-admin/claudedocs/TAILSCALE_DISTRIBUTED_STORAGE.md`
- **AGLSRV1 Recovery**: `/root/host-admin/claudedocs/AGLSRV1_Recovery_Complete_Final_Report.md`

---

## 📞 Quick Reference

**Mount Points**:
- overpower: `/mnt/nfs-overpower-base`
- spark: `/mnt/nfs-spark-base`

**Server**: `192.168.0.178` (aglfs1/CT178)

**Auto-mount Script**: `/usr/local/bin/wsl-mount-nfs-shares.sh`

**Log File**: `/var/log/wsl-mount-nfs.log`

**Test Mounts**:
```bash
/usr/local/bin/wsl-mount-nfs-shares.sh
```

**Check Status**:
```bash
df -h | grep 192.168.0.178
```

---

*Configuration Complete - 2025-10-21*
*SSHFS mounts from WSL to aglfs1 (CT178)*
*Auto-mount on Windows boot enabled*
*Status: ✅ Production Ready*
