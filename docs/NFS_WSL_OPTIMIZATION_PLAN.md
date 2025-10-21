# NFS Server Optimization for WSL Compatibility

**Date:** 2025-10-21
**Server:** aglfs1 (CT178) @ 192.168.0.178
**Client:** WSL2 @ AGLHQ11
**Objective:** Optimize NFS server configuration to work with WSL2 limitations

---

## 🔍 Current Configuration Analysis

### NFS Server Status
```
✅ Service: active (exited)
✅ Versions: NFSv3, NFSv4, NFSv4.1, NFSv4.2
✅ Daemons running:
   - nfsdcld (NFSv4 client tracking)
   - rpc.statd (NFSv3 locking)
   - rpc.idmapd (NFSv4 ID mapping)
   - rpc.mountd (mount protocol)
```

### Current Exports (/etc/exports)
```bash
# WSL-compatible exports
/mnt/overpower  *(rw,no_root_squash,insecure,no_subtree_check,fsid=10)
/mnt/power      *(rw,no_root_squash,insecure,no_subtree_check,fsid=11)
/mnt/storage    *(rw,no_root_squash,insecure,no_subtree_check,fsid=12)
/mnt/shares     *(rw,no_root_squash,insecure,no_subtree_check,fsid=13)
/mnt/spark      *(rw,no_root_squash,insecure,no_subtree_check,fsid=14)
```

**Current options:**
- `rw` - Read/write access
- `no_root_squash` - Root on client = root on server
- `insecure` - Allow connections from ports > 1024 (WSL requirement)
- `no_subtree_check` - Disable subtree checking (performance)
- `fsid=X` - Unique filesystem ID

---

## ⚠️ WSL2 NFS Limitations (From Research)

Based on `NFS_WSL2_INVESTIGATION_REPORT.md` and `NFS_MOUNT_WSL_INVESTIGATION.md`:

### Known Issues
1. **Mount negotiation timeout** - WSL2 kernel hangs during mountd negotiation
2. **NFSv4 TCP issues** - Connection established but mount hangs
3. **NFSv3 UDP unsupported** - WSL2 kernel doesn't support UDP mounts
4. **Network virtualization** - Hyper-V NAT adds latency and causes timeouts

### Root Cause
**WSL2 kernel has incomplete NFS client implementation**
- RPC communication works (can query exports via `showmount`)
- Mount protocol negotiation fails (hangs indefinitely)
- Microsoft confirmed limitation in WSL GitHub issues

---

## 🎯 Optimization Strategy

Given WSL2 kernel limitations, we'll optimize the server to:
1. **Maximize compatibility** with WSL2's partial NFS implementation
2. **Enable fallback options** for better timeout handling
3. **Add TCP-specific optimizations** (since UDP doesn't work)
4. **Configure for low-latency/virtualized networks**

### Optimizations to Apply

#### 1. Add WSL-Specific Mount Options
```bash
# Enhanced exports for WSL2
/mnt/overpower *(rw,async,no_root_squash,insecure,no_subtree_check,fsid=10,nohide)
/mnt/power     *(rw,async,no_root_squash,insecure,no_subtree_check,fsid=11,nohide)
```

**New options:**
- `async` - Asynchronous writes (better performance, slight risk)
- `nohide` - Show nested filesystems (if any)

#### 2. Configure NFS Server for TCP Optimization

**File:** `/etc/nfs.conf`

Add WSL-specific settings:
```ini
[nfsd]
# Increase threads for better handling of virtualized clients
threads=16

# TCP-only mode (WSL2 doesn't support UDP)
udp=n
tcp=y

# Increase grace period for WSL2 reconnections
grace-time=90

[mountd]
# More threads for mount protocol
threads=8

# Manage TCP connections better
manage-gids=y

[statd]
# Port for rpc.statd (optional, for troubleshooting)
port=32765
```

#### 3. Kernel NFS Tuning

**File:** `/etc/modprobe.d/nfs-server.conf`

```bash
# Increase NFS server slots (max simultaneous operations)
options nfsd nfsd_max_threads=16

# TCP window sizes for better performance
options sunrpc tcp_slot_table_entries=128
options sunrpc tcp_max_slot_table_entries=256
```

#### 4. sysctl Network Tuning

**File:** `/etc/sysctl.d/90-nfs-wsl-tuning.conf`

```ini
# TCP keepalive for long-running connections
net.ipv4.tcp_keepalive_time = 600
net.ipv4.tcp_keepalive_intvl = 60
net.ipv4.tcp_keepalive_probes = 3

# Increase TCP buffer sizes
net.core.rmem_max = 134217728
net.core.wmem_max = 134217728
net.ipv4.tcp_rmem = 4096 87380 67108864
net.ipv4.tcp_wmem = 4096 65536 67108864

# Reduce TIME_WAIT for faster port reuse
net.ipv4.tcp_fin_timeout = 30

# Enable TCP window scaling
net.ipv4.tcp_window_scaling = 1
```

---

## 🚀 Implementation Plan

### Step 1: Backup Current Configuration
```bash
ssh root@192.168.0.178 << 'EOF'
# Backup exports
cp /etc/exports /etc/exports.backup.$(date +%Y%m%d)

# Backup nfs.conf if exists
if [ -f /etc/nfs.conf ]; then
    cp /etc/nfs.conf /etc/nfs.conf.backup.$(date +%Y%m%d)
fi
EOF
```

### Step 2: Apply Export Optimizations
```bash
ssh root@192.168.0.178 << 'EOF'
cat > /etc/exports << 'EXPORTS'
# Standard exports for local networks
/srv 10.0.0.0/8(rw,fsid=0,no_subtree_check) 172.16.0.0/12(rw,fsid=0,no_subtree_check) 192.168.0.0/16(rw,fsid=0,no_subtree_check)
/srv/storage 10.0.0.0/8(rw,fsid=1,no_subtree_check) 172.16.0.0/12(rw,fsid=1,no_subtree_check) 192.168.0.0/16(rw,fsid=1,no_subtree_check)
/srv/homes 10.0.0.0/8(rw,fsid=2,no_subtree_check) 172.16.0.0/12(rw,fsid=2,no_subtree_check) 192.168.0.0/16(rw,fsid=2,no_subtree_check)

# WSL2-optimized exports
# Options: async for performance, insecure for WSL2 ports, no_wdelay for responsiveness
/mnt/overpower *(rw,async,no_wdelay,no_root_squash,insecure,no_subtree_check,fsid=10,nohide)
/mnt/power     *(rw,async,no_wdelay,no_root_squash,insecure,no_subtree_check,fsid=11,nohide)
/mnt/storage   *(rw,async,no_wdelay,no_root_squash,insecure,no_subtree_check,fsid=12,nohide)
/mnt/shares    *(rw,async,no_wdelay,no_root_squash,insecure,no_subtree_check,fsid=13,nohide)
/mnt/spark     *(rw,async,no_wdelay,no_root_squash,insecure,no_subtree_check,fsid=14,nohide)
EXPORTS

# Reload exports
exportfs -ra
exportfs -v
EOF
```

### Step 3: Configure NFS Daemon
```bash
ssh root@192.168.0.178 << 'EOF'
cat > /etc/nfs.conf << 'NFSCONF'
[general]
# pipefs-directory=/run/rpc_pipefs

[nfsd]
# Number of server threads (increase for virtualized clients)
threads=16

# Versions to support
vers3=y
vers4=y
vers4.0=y
vers4.1=y
vers4.2=y

# TCP only (WSL2 doesn't support UDP)
udp=n
tcp=y

# Grace period for client recovery
grace-time=90

[mountd]
# Mount daemon threads
threads=8
manage-gids=y

[statd]
# NLM port (optional, for firewall rules)
port=32765
outgoing-port=32766

[lockd]
# NLM UDP/TCP ports
udp-port=32768
tcp-port=32768
NFSCONF
EOF
```

### Step 4: Apply Kernel Tuning
```bash
ssh root@192.168.0.178 << 'EOF'
cat > /etc/sysctl.d/90-nfs-wsl-tuning.conf << 'SYSCTL'
# NFS WSL2 Network Tuning

# TCP keepalive (detect dead connections faster)
net.ipv4.tcp_keepalive_time = 600
net.ipv4.tcp_keepalive_intvl = 60
net.ipv4.tcp_keepalive_probes = 3

# TCP buffer sizes (accommodate large transfers)
net.core.rmem_max = 134217728
net.core.wmem_max = 134217728
net.ipv4.tcp_rmem = 4096 87380 67108864
net.ipv4.tcp_wmem = 4096 65536 67108864

# Connection handling
net.ipv4.tcp_fin_timeout = 30
net.ipv4.tcp_max_syn_backlog = 8192
net.core.somaxconn = 4096

# Enable TCP optimizations
net.ipv4.tcp_window_scaling = 1
net.ipv4.tcp_timestamps = 1
net.ipv4.tcp_sack = 1

# Reduce swappiness (keep NFS in memory)
vm.swappiness = 10
SYSCTL

# Apply sysctl settings
sysctl -p /etc/sysctl.d/90-nfs-wsl-tuning.conf
EOF
```

### Step 5: Restart NFS Services
```bash
ssh root@192.168.0.178 << 'EOF'
# Restart NFS server with new configuration
systemctl restart nfs-server
systemctl restart nfs-idmapd
systemctl restart rpc-statd

# Verify services
systemctl status nfs-server
systemctl status nfs-idmapd

# Show active exports
exportfs -v
EOF
```

---

## 🧪 Testing from WSL

### Test 1: Basic Connectivity
```bash
# Verify server is reachable
ping -c 3 192.168.0.178

# Check RPC services
rpcinfo -p 192.168.0.178

# List exports
showmount -e 192.168.0.178
```

### Test 2: NFSv3 Mount with Optimized Options
```bash
# Create mount point
sudo mkdir -p /mnt/test-nfs-optimized

# Try NFSv3 with WSL-friendly options
sudo mount -t nfs -o vers=3,tcp,soft,timeo=600,retrans=3,rsize=32768,wsize=32768,nolock \
    192.168.0.178:/mnt/overpower /mnt/test-nfs-optimized

# If successful, test I/O
ls -lah /mnt/test-nfs-optimized
df -h /mnt/test-nfs-optimized
```

### Test 3: NFSv4 Mount (if v3 fails)
```bash
# Try NFSv4.2 with optimizations
sudo mount -t nfs4 -o vers=4.2,tcp,soft,timeo=600,retrans=3,rsize=131072,wsize=131072 \
    192.168.0.178:/mnt/overpower /mnt/test-nfs-optimized

# Verify
mount | grep test-nfs-optimized
```

### Test 4: Performance Test
```bash
# If mount succeeds, test performance
# Write test
dd if=/dev/zero of=/mnt/test-nfs-optimized/test-1gb.bin bs=1M count=1024 conv=fdatasync

# Read test
dd if=/mnt/test-nfs-optimized/test-1gb.bin of=/dev/null bs=1M

# Cleanup
rm /mnt/test-nfs-optimized/test-1gb.bin
```

---

## 📊 Expected Outcomes

### Scenario A: Still Fails (High Probability)
Based on research, WSL2 kernel limitations likely remain.

**Fallback:** Continue using SSHFS (current working solution)

### Scenario B: Partial Success (Medium Probability)
Mount succeeds but with timeouts or instability.

**Options:**
- Use for read-only operations
- Keep SSHFS for critical workloads

### Scenario C: Full Success (Low Probability)
Mount works reliably with good performance.

**Next steps:**
- Add to auto-mount script
- Performance tuning
- Documentation

---

## 🎯 Realistic Assessment

### Why This Might Not Work
1. **WSL2 kernel limitation** - Server can't fix client kernel bugs
2. **Mount negotiation hangs** - Happens before server options apply
3. **Hyper-V network stack** - Virtualization layer causes issues
4. **Microsoft confirmed limitation** - Not a configuration issue

### What These Optimizations DO Help
1. **Better timeout handling** - If mount succeeds
2. **Improved performance** - For clients that CAN connect (Linux VMs, Proxmox)
3. **More resilient** - Better reconnection handling
4. **Future-proof** - Ready if WSL3 fixes NFS

---

## 📋 Implementation Checklist

- [ ] Backup current `/etc/exports`
- [ ] Apply new exports with WSL optimizations
- [ ] Configure `/etc/nfs.conf`
- [ ] Apply sysctl network tuning
- [ ] Restart NFS services
- [ ] Verify services running
- [ ] Test from WSL with multiple mount options
- [ ] Document results
- [ ] If fails: Confirm SSHFS as primary solution
- [ ] If succeeds: Update auto-mount scripts

---

## 🔚 Conclusion

These optimizations make the NFS server **as compatible as possible** with WSL2, but they **cannot fix WSL2 kernel limitations**.

**Most likely outcome:** NFS still won't work from WSL2 due to kernel issues.

**Benefit:** Server is now optimized for:
- Linux VMs
- Proxmox hosts
- Future WSL versions
- Better performance overall

**Recommendation:** Implement these optimizations but **keep SSHFS as the primary WSL solution**.
