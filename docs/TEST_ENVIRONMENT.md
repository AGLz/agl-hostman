# 🧪 Test Environment Configuration

**Updated:** 2025-10-15
**Test Platform:** CT111 @ AGLSRV6 (100.65.189.83)

---

## 🌐 Network Topology Update

### **Local Network Cluster**
```
AGLSRV6 (100.98.108.66) ─────┐
    └─ CT111 (100.65.189.83)  │  Same Local Network
         - SMB share          │  (Low latency, high bandwidth)
         - NFS v4.2 server    │
                              │
AGLSRV6b (100.98.119.51) ────┘
    └─ PBS Container
```

### **Remote Hosts**
```
AGLSRV1 (Primary Storage) ────┐
                              │
FGSRV5 (100.71.107.26) ───────┤  Tailscale VPN
                              │  (Higher latency)
FGSRV6 (100.83.51.9) ─────────┘
```

### **Performance Implications**

| Connection | Latency | Bandwidth | Use Case |
|------------|---------|-----------|----------|
| AGLSRV6 ↔ AGLSRV6b | <1ms | 1-10 Gbps | **FAST** - Local replication |
| AGLSRV6 ↔ CT111 | <0.5ms | 1-10 Gbps | **FASTEST** - Same host |
| AGLSRV1 ↔ CT111 (Tailscale) | 5-20ms | 100-500 Mbps | **GOOD** - VPN overlay |
| FGSRV5/6 ↔ AGLSRV1 | 5-30ms | 100-500 Mbps | **GOOD** - VPN overlay |

---

## 🎯 CT111 Test Platform

**Container:** CT111 @ AGLSRV6
**Tailscale IP:** 100.65.189.83
**Services:** SMB + NFS v4.2

### **Why CT111 is Perfect for Testing**

✅ **Controlled Environment** - Dedicated test container
✅ **Both Protocols** - Can compare SMB vs NFS directly
✅ **Known Configuration** - Isolated from production
✅ **Tailscale Access** - Available from all hosts
✅ **Local Network Baseline** - Can test AGLSRV6b locally vs remotely

---

## 📊 Test Strategy with CT111

### **Phase 1: Baseline Tests (CT111 → AGLSRV1)**

Test NFS v4.2 performance over Tailscale VPN:

```bash
# On AGLSRV1
mkdir -p /mnt/ct111-nfs

# Mount NFS v4.2 from CT111
mount -t nfs -o vers=4.2,tcp,rsize=1048576,wsize=1048576,hard,intr,noatime \
    100.65.189.83:/export /mnt/ct111-nfs

# Verify mount
df -h /mnt/ct111-nfs
mount | grep ct111

# Run quick performance test
dd if=/dev/zero of=/mnt/ct111-nfs/test.bin bs=1M count=1000 conv=fdatasync
# This will show real-world write speed
```

### **Phase 2: Protocol Comparison**

Compare NFS v4.2 vs SMB3 vs SSHFS:

```bash
# Test 1: NFS v4.2 (already mounted)
time dd if=/dev/zero of=/mnt/ct111-nfs/test-nfs.bin bs=1M count=5000 conv=fdatasync

# Test 2: SMB3
mkdir -p /mnt/ct111-smb
mount -t cifs -o vers=3.1.1,user=root,password=XXX \
    //100.65.189.83/share /mnt/ct111-smb
time dd if=/dev/zero of=/mnt/ct111-smb/test-smb.bin bs=1M count=5000 conv=fdatasync

# Test 3: SSHFS (current baseline)
mkdir -p /mnt/ct111-sshfs
sshfs root@100.65.189.83:/export /mnt/ct111-sshfs
time dd if=/dev/zero of=/mnt/ct111-sshfs/test-sshfs.bin bs=1M count=5000 conv=fdatasync
```

### **Phase 3: Advanced NFS v4.2 Tests**

Use the benchmark suite with CT111:

```bash
# Run comprehensive NFS v4.2 tests
/root/host-admin/scripts/benchmarks/test-all-protocols.sh \
    --target 100.65.189.83 \
    --protocols nfs4.2 \
    --output /var/log/ct111-nfs-test.json

# Test with different mount options
/root/host-admin/scripts/benchmarks/benchmark-nfs-tuning.sh \
    --server 100.65.189.83 \
    --test-async \
    --test-nconnect
```

### **Phase 4: Real-World Scenarios**

Test actual use cases:

```bash
# Container backup simulation
time tar czf /mnt/ct111-nfs/container-backup.tar.gz /var/lib/lxc/100/

# Large file transfer (ISO)
time rsync -avP /var/lib/vz/template/iso/ubuntu-22.04.iso \
    /mnt/ct111-nfs/

# Small files (10,000 files)
time rsync -av /usr/share/doc/ /mnt/ct111-nfs/test-smallfiles/

# PBS-like chunk operations
/root/host-admin/scripts/benchmarks/test-real-world-scenarios.sh \
    --target /mnt/ct111-nfs \
    --scenario pbs-chunks
```

---

## 🚀 Quick Start: NFS v4.2 Testing on CT111

### **Step 1: Verify CT111 NFS Server**

First, check CT111 has NFS properly configured:

```bash
# SSH to CT111
ssh root@100.65.189.83

# Check NFS is running
systemctl status nfs-server

# Check exports
exportfs -v
# Should show: /export *(rw,sync,...)

# Check firewall allows NFS
ufw status | grep 2049
# Or: iptables -L | grep 2049

# Test local NFS mount on CT111
mount -t nfs -o vers=4.2 localhost:/export /mnt/test
df -h /mnt/test
umount /mnt/test
```

### **Step 2: Mount NFS v4.2 on AGLSRV1**

```bash
# On AGLSRV1
mkdir -p /mnt/ct111-nfs

# Mount with optimal NFS v4.2 settings
mount -t nfs -o \
    vers=4.2,\
    tcp,\
    rsize=1048576,\
    wsize=1048576,\
    hard,\
    intr,\
    noatime,\
    nodiratime,\
    nconnect=4 \
    100.65.189.83:/export /mnt/ct111-nfs

# Verify
mount | grep ct111
df -h /mnt/ct111-nfs
```

### **Step 3: Quick Performance Test**

```bash
# Write test (5GB file)
echo "Testing NFS v4.2 write performance..."
dd if=/dev/zero of=/mnt/ct111-nfs/test-write.bin bs=1M count=5000 conv=fdatasync

# Read test (5GB file)
echo "Testing NFS v4.2 read performance..."
dd if=/mnt/ct111-nfs/test-write.bin of=/dev/null bs=1M

# Cleanup
rm /mnt/ct111-nfs/test-write.bin
```

### **Step 4: Run Automated Benchmark**

```bash
# Use our benchmark script
/root/host-admin/scripts/benchmarks/test-all-protocols.sh \
    --target 100.65.189.83 \
    --mount-point /mnt/ct111-nfs \
    --protocols nfs4.2 \
    --quick

# Or run full suite
/root/host-admin/scripts/benchmarks/run-full-benchmark-suite.sh \
    --target 100.65.189.83 \
    --output-dir /root/host-admin/docs/test-reports/ct111
```

---

## 📊 Expected Performance: CT111 vs Production

### **CT111 Test Results (Expected)**

| Test | SSHFS | NFS v4.2 | Improvement |
|------|-------|----------|-------------|
| Sequential Write | 60-80 MB/s | **200-400 MB/s** | **+250-400%** |
| Sequential Read | 70-90 MB/s | **250-450 MB/s** | **+250-400%** |
| Random 4K IOPS | 1,500-2,500 | **8,000-15,000** | **+400-500%** |
| Metadata ops/sec | 50-100 | **800-1,500** | **+800-1,400%** |
| CPU overhead | 20-30% | **8-12%** | **-60-73%** |

**Note:** CT111 over Tailscale will be slightly slower than local network but still 2-5x faster than SSHFS.

### **Tailscale Overhead Estimate**

| Scenario | Local Network | Tailscale VPN | Overhead |
|----------|---------------|---------------|----------|
| AGLSRV6b → CT111 | 800-1000 MB/s | N/A | 0% (same host) |
| AGLSRV6 → AGLSRV6b | 800-1000 MB/s | 500-800 MB/s | ~20-30% |
| AGLSRV1 → CT111 | N/A | 200-400 MB/s | Tailscale limited |

---

## 🔧 Optimizations for CT111 Testing

### **CT111 NFS Server Tuning**

```bash
# SSH to CT111
ssh root@100.65.189.83

# Increase NFS threads
echo "RPCNFSDCOUNT=128" >> /etc/default/nfs-kernel-server
systemctl restart nfs-server

# Optimize network
echo "net.core.rmem_max = 134217728" >> /etc/sysctl.conf
echo "net.core.wmem_max = 134217728" >> /etc/sysctl.conf
echo "net.ipv4.tcp_rmem = 4096 87380 67108864" >> /etc/sysctl.conf
echo "net.ipv4.tcp_wmem = 4096 65536 67108864" >> /etc/sysctl.conf
sysctl -p

# Enable async mode for testing (CAREFUL - not for production!)
# Edit /etc/exports:
# /export *(rw,async,no_subtree_check,no_root_squash)
exportfs -ra
```

### **AGLSRV1 Client Tuning**

```bash
# On AGLSRV1

# Remount with async mode for maximum performance
umount /mnt/ct111-nfs
mount -t nfs -o \
    vers=4.2,\
    tcp,\
    rsize=1048576,\
    wsize=1048576,\
    async,\
    hard,\
    intr,\
    noatime,\
    nodiratime,\
    nconnect=16 \
    100.65.189.83:/export /mnt/ct111-nfs

# NOTE: async mode is FAST but less safe
# Use for testing only, not production data
```

---

## 📋 Test Execution Checklist

### **Pre-Test Verification**

- [ ] CT111 is running and accessible
- [ ] NFS server active on CT111: `systemctl status nfs-server`
- [ ] Tailscale connection active: `tailscale status | grep 100.65.189.83`
- [ ] Sufficient disk space on CT111: `df -h /export`
- [ ] No other heavy I/O operations running

### **NFS v4.2 Test Sequence**

- [ ] **Test 1:** Mount NFS v4.2 with optimal settings
- [ ] **Test 2:** Quick dd write/read test (5GB)
- [ ] **Test 3:** Run fio sequential I/O tests
- [ ] **Test 4:** Run fio random I/O tests
- [ ] **Test 5:** Metadata operations (create/delete 10k files)
- [ ] **Test 6:** Large file transfer (ISO image)
- [ ] **Test 7:** Small files transfer (kernel source)
- [ ] **Test 8:** Container backup simulation

### **Comparison Tests**

- [ ] **Test 9:** Same workload with SSHFS (baseline)
- [ ] **Test 10:** Same workload with SMB3 (if available)
- [ ] **Test 11:** Compare CPU usage across protocols
- [ ] **Test 12:** Compare network utilization

### **Advanced Testing**

- [ ] **Test 13:** Test with nconnect=4,8,16 (parallel connections)
- [ ] **Test 14:** Test async vs sync mount modes
- [ ] **Test 15:** Test with different rsize/wsize values
- [ ] **Test 16:** Concurrent multi-user simulation

---

## 📈 Data Collection

All test results will be logged to:

```bash
/var/log/storage-benchmarks/ct111/
├── nfs-v4.2-baseline.json
├── nfs-v4.2-optimized.json
├── sshfs-baseline.json
├── smb3-comparison.json
├── network-metrics.csv
├── cpu-usage.csv
└── final-report.html
```

---

## 🎯 Success Criteria for CT111 Tests

**Minimum acceptable (NFS v4.2 over Tailscale):**
- ✅ Sequential write: >150 MB/s
- ✅ Sequential read: >180 MB/s
- ✅ Random IOPS: >5,000
- ✅ CPU usage: <15%
- ✅ Stable performance over 30+ minutes

**Optimal targets:**
- 🎯 Sequential write: >250 MB/s
- 🎯 Sequential read: >300 MB/s
- 🎯 Random IOPS: >8,000
- 🎯 CPU usage: <10%
- 🎯 No performance degradation over time

---

## 🚀 Ready to Test!

Execute these commands to begin NFS v4.2 testing:

```bash
# Step 1: Verify CT111
ssh root@100.65.189.83 "systemctl status nfs-server && exportfs -v"

# Step 2: Mount NFS v4.2
mount -t nfs -o vers=4.2,tcp,rsize=1048576,wsize=1048576,hard,intr,noatime,nconnect=4 \
    100.65.189.83:/export /mnt/ct111-nfs

# Step 3: Quick test
dd if=/dev/zero of=/mnt/ct111-nfs/quicktest.bin bs=1M count=2000 conv=fdatasync

# Step 4: Run comprehensive benchmarks
/root/host-admin/scripts/benchmarks/run-full-benchmark-suite.sh \
    --target 100.65.189.83
```

---

**Test Platform:** CT111 (100.65.189.83) @ AGLSRV6
**Protocol:** NFS v4.2
**Status:** ✅ Ready for testing
**Next:** Execute mount and benchmark commands above
