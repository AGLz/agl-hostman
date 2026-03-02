# 📊 Complete Test Matrix - Multi-Host Storage Performance

**Updated:** 2025-10-15
**Test Platforms:** CT111 (AGLSRV6) + CT178 (AGLSRV1)
**Remote Hosts:** FGSRV5 + FGSRV6 (require NFS setup)

---

## 🌐 Complete Network Topology

```
┌─────────────────────────────────────────────────────────────┐
│                    AGLSRV1 (Primary)                        │
│  - CT178: SMB + NFS v4.2 (local test platform)             │
│  - Main storage server                                      │
└─────────────────────────────────────────────────────────────┘
                            │
              ┌─────────────┴─────────────┐
              │    Tailscale VPN          │
              │    WireGuard Mesh         │
              └─────────────┬─────────────┘
                            │
        ┌───────────────────┼───────────────────┐
        │                   │                   │
┌───────┴────────┐  ┌──────┴──────┐  ┌─────────┴────────┐
│   AGLSRV6      │  │   FGSRV5    │  │    FGSRV6        │
│ 100.98.108.66  │  │100.71.107.26│  │  100.83.51.9     │
│ - CT111: SMB + │  │ - Need NFS  │  │  - Need NFS      │
│   NFS v4.2     │  │   install   │  │    install       │
└────────┬───────┘  └─────────────┘  └──────────────────┘
         │
    ┌────┴────┐
    │AGLSRV6b │  ← Same Local Network
    │100.98.  │
    │119.51   │
    └─────────┘
```

---

## 🎯 Test Platforms Overview

### **Platform 1: CT111 @ AGLSRV6**
- **Tailscale IP:** 100.65.189.83
- **Services:** NFS v4.2 + SMB3 + SSHFS
- **Location:** AGLSRV6 (remote from AGLSRV1)
- **Use:** Test remote storage protocols via Tailscale

### **Platform 2: CT178 @ AGLSRV1**
- **Tailscale IP:** TBD (detect during setup)
- **Services:** NFS v4.2 + SMB3 + SSHFS
- **Location:** AGLSRV1 (local/primary server)
- **Use:** Test local performance + reverse direction tests

### **Remote Hosts: FGSRV5 + FGSRV6**
- **FGSRV5:** 100.71.107.26 (needs NFS setup)
- **FGSRV6:** 100.83.51.9 (needs NFS setup)
- **Purpose:** Test distributed storage across all nodes

---

## 📋 Complete Test Matrix

### **Test Scenario 1: Protocol Comparison (CT111)**
**From:** AGLSRV1
**To:** CT111 @ AGLSRV6 (100.65.189.83)

| Protocol | Expected Speed | CPU Usage | Test Priority |
|----------|---------------|-----------|---------------|
| **SSHFS** | 50-80 MB/s | 25-30% | HIGH (baseline) |
| **NFS v4.2** | 150-250 MB/s | 10-15% | CRITICAL |
| **SMB3** | 100-180 MB/s | 15-20% | MEDIUM |

**Test Commands:**
```bash
# SSHFS (baseline)
sshfs root@100.65.189.83:/export /mnt/ct111-sshfs
dd if=/dev/zero of=/mnt/ct111-sshfs/test.bin bs=1M count=2000 conv=fdatasync

# NFS v4.2 (recommended)
mount -t nfs -o vers=4.2,rsize=1048576,wsize=1048576,nconnect=4 \
    100.65.189.83:/export /mnt/ct111-nfs
dd if=/dev/zero of=/mnt/ct111-nfs/test.bin bs=1M count=2000 conv=fdatasync

# SMB3
mount -t cifs -o vers=3.1.1,user=root \
    //100.65.189.83/share /mnt/ct111-smb
dd if=/dev/zero of=/mnt/ct111-smb/test.bin bs=1M count=2000 conv=fdatasync
```

---

### **Test Scenario 2: Local Performance (CT178)**
**From:** AGLSRV1
**To:** CT178 @ AGLSRV1 (local container)

| Protocol | Expected Speed | Latency | Purpose |
|----------|---------------|---------|---------|
| **NFS v4.2** | 500-1000 MB/s | <0.5ms | Local baseline |
| **SMB3** | 400-800 MB/s | <1ms | Windows compat |
| **SSHFS** | 100-200 MB/s | <2ms | Legacy comparison |

**Purpose:** Establish maximum theoretical performance without network overhead

---

### **Test Scenario 3: Bidirectional Tests**
**Test both directions to identify asymmetric performance**

| Direction | From → To | Expected Throughput | Test Type |
|-----------|-----------|---------------------|-----------|
| **Push** | AGLSRV1 → CT111 | 150-250 MB/s | Write-heavy |
| **Pull** | CT111 → AGLSRV1 | 180-300 MB/s | Read-heavy |
| **Push** | AGLSRV1 → CT178 | 500-1000 MB/s | Local baseline |
| **Pull** | CT178 → AGLSRV1 | 600-1200 MB/s | Local baseline |

---

### **Test Scenario 4: Multi-Node Mesh (All Hosts)**
**After NFS setup on FGSRV5/FGSRV6**

```
AGLSRV1 ─┬─→ CT111 (AGLSRV6)
         ├─→ CT178 (AGLSRV1 local)
         ├─→ FGSRV5 NFS share
         └─→ FGSRV6 NFS share

FGSRV5  ─┬─→ AGLSRV1
         └─→ CT111

FGSRV6  ─┬─→ AGLSRV1
         └─→ CT111
```

**Purpose:** Test distributed storage access patterns

---

### **Test Scenario 5: Real-World Workloads**

| Workload | Test Host | Target | Protocol | Expected Time |
|----------|-----------|--------|----------|---------------|
| **Container Backup (10GB)** | AGLSRV1 | CT111 | NFS v4.2 | <2 min |
| **PBS Sync (50GB)** | AGLSRV6 | AGLSRV1 | NFS v4.2 | <5 min |
| **ISO Transfer (4GB)** | FGSRV5 | CT111 | NFS v4.2 | <30 sec |
| **Small Files (10k)** | AGLSRV1 | CT178 | NFS v4.2 | <15 sec |
| **VM Migration** | FGSRV6 | AGLSRV1 | NFS v4.2 | <1 min |

---

## 🔧 Setup Requirements

### **CT111 @ AGLSRV6** ✅ Already Configured
- NFS v4.2 server: ✅ Active
- SMB server: ✅ Active
- SSHFS access: ✅ Available
- Tailscale: ✅ Connected (100.65.189.83)

### **CT178 @ AGLSRV1** ⚠️ Needs Verification
```bash
# Verify CT178 exists and get Tailscale IP
pct list | grep 178
pct exec 178 -- tailscale status | grep -oP '\d+\.\d+\.\d+\.\d+' | head -1

# Check services
pct exec 178 -- systemctl status nfs-server
pct exec 178 -- systemctl status smbd

# If not configured, run:
/root/host-admin/scripts/setup-nfs-server.sh --container CT178
```

### **FGSRV5 (100.71.107.26)** ❌ Needs Full NFS Setup
```bash
# Will need:
1. Install nfs-kernel-server
2. Configure /etc/exports
3. Start NFS services
4. Open firewall ports
5. Test connectivity

# Automated script available:
/root/host-admin/scripts/deploy-nfs-to-fgsrv5.sh
```

### **FGSRV6 (100.83.51.9)** ❌ Needs Full NFS Setup
```bash
# Same as FGSRV5:
/root/host-admin/scripts/deploy-nfs-to-fgsrv6.sh
```

---

## 🚀 Execution Plan

### **Phase 1: Baseline (CT111 + CT178) - Day 1**
**Duration:** 1-2 hours

```bash
# Test 1: CT111 protocol comparison
/root/host-admin/scripts/quick-test-ct111.sh

# Test 2: CT111 SSHFS baseline
/root/host-admin/scripts/test-sshfs-baseline.sh --target 100.65.189.83

# Test 3: CT178 local performance
/root/host-admin/scripts/quick-test-ct178.sh

# Test 4: Bidirectional tests
/root/host-admin/scripts/test-bidirectional.sh \
    --host1 AGLSRV1 \
    --host2 100.65.189.83 \
    --protocol nfs4.2
```

**Expected Results:**
- CT111 NFS v4.2: 150-250 MB/s
- CT111 SSHFS: 50-80 MB/s (baseline)
- CT178 NFS v4.2: 500-1000 MB/s (local)
- Performance ratio validation

---

### **Phase 2: Deploy NFS to FGSRV5/FGSRV6 - Day 2**
**Duration:** 2-3 hours

```bash
# Step 1: Deploy to FGSRV5
/root/host-admin/scripts/deploy-nfs-to-remote.sh \
    --host 100.71.107.26 \
    --hostname FGSRV5 \
    --export-path /storage/nfs-share

# Step 2: Deploy to FGSRV6
/root/host-admin/scripts/deploy-nfs-to-remote.sh \
    --host 100.83.51.9 \
    --hostname FGSRV6 \
    --export-path /storage/nfs-share

# Step 3: Verify installations
/root/host-admin/scripts/verify-all-nfs-servers.sh
```

**Verification:**
```bash
# From AGLSRV1, test each server
for HOST in 100.65.189.83 100.71.107.26 100.83.51.9; do
    echo "Testing $HOST..."
    showmount -e $HOST
    timeout 5 mount -t nfs -o vers=4.2 $HOST:/export /mnt/test-$HOST
    df -h /mnt/test-$HOST
    umount /mnt/test-$HOST
done
```

---

### **Phase 3: Multi-Node Testing - Day 3**
**Duration:** 3-4 hours

```bash
# Run comprehensive cross-host tests
/root/host-admin/scripts/benchmarks/test-multi-node-mesh.sh \
    --hosts "100.65.189.83,100.71.107.26,100.83.51.9" \
    --protocol nfs4.2 \
    --test-matrix full

# Real-world scenario testing
/root/host-admin/scripts/benchmarks/test-real-world-scenarios.sh \
    --all-hosts \
    --scenarios "container-backup,pbs-sync,iso-transfer,vm-migration"
```

---

### **Phase 4: Performance Analysis - Day 4**
**Duration:** 2-3 hours

```bash
# Generate comprehensive report
/root/host-admin/scripts/benchmarks/generate-final-report.sh \
    --include-all-tests \
    --output /root/host-admin/docs/test-reports/final-analysis.html

# Compare all protocols across all hosts
/root/host-admin/scripts/benchmarks/compare-protocols-matrix.sh \
    --output-format html,csv,json
```

---

## 📊 Expected Performance Matrix

### **SSHFS Baseline (Current)**
| Source | Target | Throughput | Latency | CPU |
|--------|--------|-----------|---------|-----|
| AGLSRV1 | CT111 | 50-80 MB/s | 15-25ms | 25-30% |
| AGLSRV1 | CT178 | 100-150 MB/s | 2-5ms | 20-25% |
| AGLSRV1 | FGSRV5 | 40-70 MB/s | 20-30ms | 25-30% |
| AGLSRV1 | FGSRV6 | 40-70 MB/s | 20-30ms | 25-30% |

### **NFS v4.2 Target (After Deployment)**
| Source | Target | Throughput | Latency | CPU |
|--------|--------|-----------|---------|-----|
| AGLSRV1 | CT111 | 150-250 MB/s | 5-15ms | 10-15% |
| AGLSRV1 | CT178 | 500-1000 MB/s | <1ms | 8-12% |
| AGLSRV1 | FGSRV5 | 120-200 MB/s | 10-20ms | 10-15% |
| AGLSRV1 | FGSRV6 | 120-200 MB/s | 10-20ms | 10-15% |

**Expected Improvement:** 2-5x faster throughput, 50-60% lower CPU usage

---

## 🎯 Success Criteria

### **Protocol Performance**
- ✅ NFS v4.2 > 2x faster than SSHFS
- ✅ CPU overhead < 15% (vs 25-30% SSHFS)
- ✅ Latency p99 < 25ms
- ✅ Stable performance over 1+ hour tests

### **Deployment Success**
- ✅ All 4 hosts serving NFS v4.2
- ✅ Firewall rules correctly configured
- ✅ Automatic mount on boot (systemd)
- ✅ Health monitoring active

### **Operational Validation**
- ✅ Container backups < 2 min (10GB)
- ✅ PBS sync functional
- ✅ VM migration < 1 min
- ✅ No data corruption detected

---

## 📝 Test Execution Checklist

### **Pre-Testing** (Before Phase 1)
- [ ] CT111 accessible: `ping 100.65.189.83`
- [ ] CT111 NFS running: `ssh root@100.65.189.83 systemctl status nfs-server`
- [ ] CT111 SMB running: `ssh root@100.65.189.83 systemctl status smbd`
- [ ] CT178 exists: `pct status 178`
- [ ] CT178 configured: `pct exec 178 -- systemctl status nfs-server`
- [ ] Tailscale connected: `tailscale status`
- [ ] Sufficient disk space: `df -h`

### **Phase 1: Baseline Testing**
- [ ] CT111 SSHFS baseline established
- [ ] CT111 NFS v4.2 tested and validated
- [ ] CT111 SMB3 tested (optional)
- [ ] CT178 local performance baseline
- [ ] Bidirectional tests completed
- [ ] Results logged: `/var/log/storage-benchmarks/phase1/`

### **Phase 2: Remote NFS Deployment**
- [ ] FGSRV5 NFS packages installed
- [ ] FGSRV5 exports configured
- [ ] FGSRV5 firewall rules added
- [ ] FGSRV5 NFS service started
- [ ] FGSRV5 test mount successful
- [ ] FGSRV6 NFS packages installed
- [ ] FGSRV6 exports configured
- [ ] FGSRV6 firewall rules added
- [ ] FGSRV6 NFS service started
- [ ] FGSRV6 test mount successful

### **Phase 3: Multi-Node Testing**
- [ ] Mesh connectivity verified (all hosts)
- [ ] Cross-host performance tests
- [ ] Container backup scenarios
- [ ] PBS sync scenarios
- [ ] VM migration scenarios
- [ ] Concurrent access testing

### **Phase 4: Analysis & Reporting**
- [ ] All test logs collected
- [ ] Performance graphs generated
- [ ] Protocol comparison matrix
- [ ] Final recommendations documented
- [ ] Implementation plan updated

---

## 🛠️ Quick Reference Commands

### **Check All NFS Servers**
```bash
for HOST in 100.65.189.83 100.71.107.26 100.83.51.9; do
    echo "=== Checking $HOST ==="
    showmount -e $HOST 2>/dev/null || echo "NFS not available"
done
```

### **Mount All NFS Shares**
```bash
mkdir -p /mnt/{ct111,fgsrv5,fgsrv6}

mount -t nfs -o vers=4.2,rsize=1048576,wsize=1048576,nconnect=4 \
    100.65.189.83:/export /mnt/ct111

mount -t nfs -o vers=4.2,rsize=1048576,wsize=1048576,nconnect=4 \
    100.71.107.26:/export /mnt/fgsrv5

mount -t nfs -o vers=4.2,rsize=1048576,wsize=1048576,nconnect=4 \
    100.83.51.9:/export /mnt/fgsrv6

df -h | grep /mnt
```

### **Quick Performance Test (All Hosts)**
```bash
for MOUNT in /mnt/ct111 /mnt/fgsrv5 /mnt/fgsrv6; do
    echo "Testing $MOUNT..."
    dd if=/dev/zero of=${MOUNT}/test.bin bs=1M count=1000 conv=fdatasync
    rm ${MOUNT}/test.bin
done
```

### **Unmount All**
```bash
umount /mnt/{ct111,fgsrv5,fgsrv6}
```

---

## 📚 Documentation Index

- **Test Environment:** `/root/host-admin/docs/TEST_ENVIRONMENT.md`
- **Complete Matrix:** `/root/host-admin/docs/COMPLETE_TEST_MATRIX.md` (this file)
- **NFS Deployment Guide:** `/root/host-admin/docs/NFS_DEPLOYMENT_GUIDE.md` (to be created)
- **Test Results:** `/var/log/storage-benchmarks/`
- **Final Report:** `/root/host-admin/docs/test-reports/final-analysis.html`

---

**Status:** 🟡 Ready for Phase 1 | 🔴 FGSRV5/6 need NFS setup
**Next Action:** Deploy NFS to FGSRV5 and FGSRV6
**Scripts:** Creation in progress...
