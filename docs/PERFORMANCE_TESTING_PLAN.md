# 📊 Comprehensive Storage Performance Testing Plan

**Objective:** Execute complete performance testing across local storage, remote hosts, and multiple protocols to establish baselines and validate optimization strategies.

---

## 🎯 Testing Scope

### Local Storage Testing (Per Host)
**Hosts to test:**
- ✅ AGLSRV1 (primary storage server)
- ✅ AGLSRV6 (100.98.108.66) + PBS
- ✅ AGLSRV6b (100.98.119.51) + PBS
- ✅ FGSRV5 (100.71.107.26)
- ✅ FGSRV6 (100.83.51.9)

**Storage technologies:**
- ZFS pools (if present)
- LVM volumes
- Raw block devices
- Different filesystem types (ext4, xfs, zfs)

### Remote Network Testing
**Test paths:**
- AGLSRV6 ↔ AGLSRV1
- AGLSRV6b ↔ AGLSRV1
- FGSRV5 ↔ AGLSRV1
- FGSRV6 ↔ AGLSRV1

**Network characteristics:**
- Tailscale direct P2P performance
- DERP relay fallback (if applicable)
- Bandwidth (TCP/UDP)
- Latency, jitter, packet loss
- MTU optimization impact

### Protocol Comparison Matrix

| Protocol | Version | Test Priority | Expected Performance |
|----------|---------|--------------|---------------------|
| **SSHFS** | Current | HIGH (baseline) | 50-80 MB/s |
| **NFS** | v3 | MEDIUM | 100-150 MB/s |
| **NFS** | v4.0 | HIGH | 120-180 MB/s |
| **NFS** | v4.2 | CRITICAL | 150-250 MB/s |
| **SMB3** | 3.1.1 | MEDIUM | 80-150 MB/s |
| **iSCSI** | - | LOW | 100-200 MB/s (high latency) |
| **rsync/rclone** | - | HIGH (backup) | 60-120 MB/s |

---

## 📋 Test Scenarios

### 1. Sequential I/O Performance
**Tools:** fio, dd
```bash
# Sequential read
fio --name=seq-read --rw=read --bs=1M --size=10G --numjobs=1

# Sequential write
fio --name=seq-write --rw=write --bs=1M --size=10G --numjobs=1
```

**Metrics:**
- Throughput (MB/s)
- CPU usage (%)
- Network utilization (%)

**Target:** >150 MB/s for NFS v4.2

---

### 2. Random I/O Performance
**Tools:** fio
```bash
# Random read IOPS
fio --name=rand-read --rw=randread --bs=4k --size=10G --iodepth=32

# Random write IOPS
fio --name=rand-write --rw=randwrite --bs=4k --size=10G --iodepth=32

# Mixed workload (70% read, 30% write)
fio --name=mixed --rw=randrw --rwmixread=70 --bs=4k --size=10G
```

**Metrics:**
- IOPS (operations/sec)
- Latency (ms) - p50, p95, p99
- Queue depth impact

**Target:** >5,000 IOPS for NFS v4.2

---

### 3. Metadata Operations
**Tools:** Custom scripts
```bash
# Create 10,000 small files
time for i in {1..10000}; do touch file_$i; done

# List directory
time ls -l > /dev/null

# Delete files
time rm -f file_*
```

**Metrics:**
- Operations per second
- Total time for batch operations
- Protocol overhead

**Target:** <30 seconds for 10,000 files (NFS v4.2)

---

### 4. Real-World Workloads

#### Container Backups (LXC/CT)
```bash
# Backup 10GB container
time pct backup 100 /mnt/remote/backups/

# Restore container
time pct restore 100 /mnt/remote/backups/vzdump-lxc-100.tar.zst
```

**Metrics:**
- Backup speed (MB/s)
- Compression ratio
- CPU overhead
- Network utilization

**Target:** <10 minutes for 10GB container

---

#### PBS Backup Operations
```bash
# Run PBS backup via sync script
time /root/host-admin/scripts/sync-pbs-backups.sh

# Measure deduplication efficiency
proxmox-backup-client benchmark
```

**Metrics:**
- Chunk throughput (chunks/sec)
- Deduplication ratio
- Network bandwidth
- Verify speed

**Target:** >100 MB/s for initial backups, >200 MB/s for incrementals

---

#### Large File Transfers
```bash
# Transfer 5GB ISO file
time rsync -avP ubuntu-22.04.iso remote:/mnt/storage/
time cp ubuntu-22.04.iso /mnt/nfs/
time scp ubuntu-22.04.iso remote:/mnt/storage/
```

**Metrics:**
- Transfer speed (MB/s)
- CPU usage
- Protocol efficiency

**Target:** >150 MB/s for NFS, >100 MB/s for rsync

---

#### Small File Operations (Thousands of Files)
```bash
# Extract kernel source (60,000+ files)
time tar -xf linux-6.1.tar.xz -C /mnt/remote/

# Sync directory tree
time rsync -av linux-6.1/ /mnt/remote/linux-6.1/
```

**Metrics:**
- Files per second
- Total time
- Network round-trips

**Target:** >500 files/sec for NFS v4.2

---

## 🔧 Test Execution Plan

### Phase 1: Local Baseline (Day 1 - 2 hours)
**Execute on each host:**
```bash
# Run on AGLSRV1
/root/host-admin/scripts/benchmarks/test-local-storage.sh

# SSH to each remote host and run
ssh root@100.98.108.66 "bash -s" < test-local-storage.sh
ssh root@100.98.119.51 "bash -s" < test-local-storage.sh
ssh root@100.71.107.26 "bash -s" < test-local-storage.sh
ssh root@100.83.51.9 "bash -s" < test-local-storage.sh
```

**Deliverable:** Local storage baseline report for all 5 hosts

---

### Phase 2: Network Baseline (Day 1 - 1 hour)
**Test from AGLSRV1 to each remote:**
```bash
/root/host-admin/scripts/benchmarks/test-remote-network.sh \
  --hosts "100.98.108.66 100.98.119.51 100.71.107.26 100.83.51.9"
```

**Deliverable:** Network performance matrix (bandwidth, latency, MTU)

---

### Phase 3: Protocol Comparison (Day 2 - 4 hours)
**Test all protocols sequentially:**
```bash
/root/host-admin/scripts/benchmarks/test-all-protocols.sh \
  --protocols "sshfs,nfs3,nfs4,nfs4.2,smb3" \
  --remote-host 100.98.108.66 \
  --iterations 3
```

**Repeat for each remote host**

**Deliverable:** Protocol comparison matrix with recommendations

---

### Phase 4: Real-World Scenarios (Day 3 - 3 hours)
**Execute realistic workloads:**
```bash
/root/host-admin/scripts/benchmarks/test-real-world-scenarios.sh \
  --protocol nfs4.2 \
  --scenarios "container,pbs,iso,smallfiles"
```

**Deliverable:** Use-case specific performance profiles

---

### Phase 5: Full Suite Execution (Day 4 - 8 hours)
**Automated end-to-end testing:**
```bash
/root/host-admin/scripts/benchmarks/run-full-benchmark-suite.sh \
  --output-dir /root/host-admin/docs/test-reports \
  --generate-report html,pdf,csv
```

**Deliverable:** Comprehensive performance report with graphs and recommendations

---

## 📊 Expected Results

### Performance Improvement Matrix

| Metric | SSHFS (Current) | NFS v4.2 (Target) | Improvement |
|--------|-----------------|-------------------|-------------|
| Sequential R/W | 60 MB/s | 150-200 MB/s | **+150%** |
| Random IOPS | 2,000 | 6,000-8,000 | **+300%** |
| Metadata ops | 50 ops/s | 500 ops/s | **+900%** |
| Container backup | 45 MB/s | 95 MB/s | **+110%** |
| CPU overhead | 25% | 12% | **-52%** |
| Latency (p99) | 50ms | 15ms | **-70%** |

---

## 🎯 Success Criteria

**Minimum acceptable performance (NFS v4.2):**
- ✅ Sequential throughput: >120 MB/s
- ✅ Random IOPS: >5,000
- ✅ Latency p99: <25ms
- ✅ CPU usage: <20%
- ✅ Container backup: >80 MB/s
- ✅ PBS throughput: >100 MB/s

**Optimal performance targets:**
- 🎯 Sequential throughput: >180 MB/s
- 🎯 Random IOPS: >8,000
- 🎯 Latency p99: <15ms
- 🎯 CPU usage: <15%
- 🎯 Container backup: >120 MB/s
- 🎯 PBS throughput: >150 MB/s

---

## 📈 Monitoring During Tests

**System metrics to collect:**
```bash
# CPU usage
mpstat -P ALL 1

# Memory usage
vmstat 1

# Disk I/O
iostat -x 1

# Network throughput
iftop -i tailscale0

# Process monitoring
pidstat -u -r -d 1
```

**Automated collection:**
- sysstat (sar)
- Prometheus node_exporter (optional)
- Grafana dashboards (optional)

---

## 🔍 Analysis Framework

### Performance Regression Detection
Compare results against baselines:
```bash
# Generate comparison report
./compare-benchmark-results.sh \
  --baseline results-2025-01-01.json \
  --current results-2025-01-15.json \
  --threshold 10%  # Alert if >10% regression
```

### Bottleneck Identification
```bash
# Identify limiting factor
if [ "$cpu_usage" -gt 80 ]; then
  echo "CPU-bound workload"
elif [ "$network_util" -gt 80 ]; then
  echo "Network-bound workload"
elif [ "$disk_iops" -gt 80 ]; then
  echo "Disk I/O-bound workload"
fi
```

---

## 📝 Reporting

### Deliverables

1. **Executive Summary (1 page)**
   - Key findings
   - Protocol recommendation
   - ROI analysis
   - Next steps

2. **Technical Report (10-15 pages)**
   - Detailed test results
   - Performance graphs
   - Bottleneck analysis
   - Optimization recommendations

3. **Raw Data (CSV/JSON)**
   - All benchmark results
   - System metrics
   - Reproducible test commands

4. **Implementation Guide**
   - Deploy recommended protocol
   - Apply optimizations
   - Monitoring setup
   - Maintenance procedures

---

## ⏱️ Timeline

| Phase | Duration | When | Deliverable |
|-------|----------|------|-------------|
| **Phase 1** | 2 hours | Day 1 AM | Local baselines |
| **Phase 2** | 1 hour | Day 1 PM | Network baselines |
| **Phase 3** | 4 hours | Day 2 | Protocol comparison |
| **Phase 4** | 3 hours | Day 3 | Real-world scenarios |
| **Phase 5** | 8 hours | Day 4 | Full automated suite |
| **Analysis** | 2 hours | Day 5 | Final report |

**Total:** ~20 hours over 5 days

---

## 🚀 Quick Start

### Immediate Next Steps

```bash
# 1. Review this plan
cat /root/host-admin/docs/PERFORMANCE_TESTING_PLAN.md

# 2. Wait for Performance Engineer to deliver test scripts
ls -lah /root/host-admin/scripts/benchmarks/

# 3. Start with local baseline
/root/host-admin/scripts/benchmarks/test-local-storage.sh

# 4. Progress to network testing
/root/host-admin/scripts/benchmarks/test-remote-network.sh

# 5. Run full suite when ready
/root/host-admin/scripts/benchmarks/run-full-benchmark-suite.sh
```

---

## 📞 Support

**Test script issues:** Check `/var/log/storage-benchmarks/`
**Performance questions:** Review `/root/host-admin/docs/performance-optimization.md`
**Implementation help:** See `/root/host-admin/docs/README.md`

---

**Document Version:** 1.0
**Last Updated:** 2025-10-15
**Status:** 🟡 Awaiting test script delivery
**Next Action:** Wait for Performance Engineer agent to create benchmark scripts
