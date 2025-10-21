# Storage Connectivity Performance Benchmarking Methodology

## Executive Summary
This document outlines comprehensive benchmarking methodology for evaluating storage connectivity protocols (SSHFS, NFS v3, NFS v4, SMB3) over Tailscale network between Proxmox host and containers.

## Testing Environment

### Hardware Specifications
- **Host**: Proxmox VE on physical server
- **Containers**: LXC containers with varying resource allocations
- **Network**: Tailscale mesh network (WireGuard-based)
- **Storage Backend**: ZFS pools on Proxmox host

### Network Configuration
- **Tailscale MTU**: 1280 (default) / 1420 (optimized)
- **Network Latency**: < 1ms (local) / variable (remote)
- **Bandwidth**: 1 Gbps physical, ~900 Mbps effective through Tailscale

## Benchmarking Protocols

### 1. SSHFS (Baseline)
**Configuration**:
```bash
sshfs user@host:/path /mnt/sshfs \
  -o Compression=no \
  -o Ciphers=aes128-ctr \
  -o ServerAliveInterval=15 \
  -o reconnect \
  -o cache=yes \
  -o kernel_cache \
  -o entry_timeout=30 \
  -o attr_timeout=30
```

**Test Parameters**:
- Cipher impact: aes128-ctr vs chacha20-poly1305
- Compression: enabled vs disabled
- Cache settings impact
- Connection pooling effects

### 2. NFS v3
**Configuration**:
```bash
mount -t nfs -o vers=3,tcp,rsize=1048576,wsize=1048576,async,noatime \
  host:/export /mnt/nfsv3
```

**Test Parameters**:
- TCP vs UDP (though TCP recommended)
- Read/write buffer sizes: 64KB to 1MB
- Async vs sync operations
- Hard vs soft mounts
- Number of NFS threads (nfsd)

### 3. NFS v4.2
**Configuration**:
```bash
mount -t nfs -o vers=4.2,tcp,rsize=1048576,wsize=1048576,async,noatime \
  host:/export /mnt/nfsv4
```

**Test Parameters**:
- Delegation effects
- pNFS layouts (if supported)
- Security models (sys, krb5)
- Compound operations efficiency
- Copy offload features

### 4. SMB3
**Configuration**:
```bash
mount -t cifs //host/share /mnt/smb3 \
  -o vers=3.1.1,cache=loose,rsize=1048576,wsize=1048576,echo_interval=5
```

**Test Parameters**:
- SMB version comparison (3.0, 3.1.1)
- Multichannel performance
- Cache modes (none, strict, loose)
- Compression support
- Encryption overhead

## Test Scenarios

### 1. Sequential Read/Write Tests
**Tool**: `fio`
```bash
# Sequential Write
fio --name=seqwrite --ioengine=libaio --rw=write --bs=1M --size=10G \
    --numjobs=1 --runtime=60 --group_reporting --directory=/mnt/test

# Sequential Read
fio --name=seqread --ioengine=libaio --rw=read --bs=1M --size=10G \
    --numjobs=1 --runtime=60 --group_reporting --directory=/mnt/test
```

**Metrics**:
- Throughput (MB/s)
- IOPS
- Latency (avg, p95, p99)
- CPU utilization

### 2. Random I/O Tests
**Tool**: `fio`
```bash
# Random 4K Read/Write (Database workload)
fio --name=randrw --ioengine=libaio --rw=randrw --bs=4k --size=1G \
    --numjobs=4 --runtime=60 --group_reporting --directory=/mnt/test \
    --rwmixread=70 --iodepth=32
```

**Workload Profiles**:
- Database (4K random, 70% read)
- Virtual machines (64K random, mixed)
- Web server (small files, read-heavy)
- Backup (sequential, write-heavy)

### 3. Container Migration Tests
**Scenario**: LXC container backup and restore
```bash
# Backup test
time vzdump <vmid> --mode snapshot --storage <storage> --compress zstd

# Restore test
time pct restore <vmid> <backup-file> --storage <storage>
```

**Metrics**:
- Total transfer time
- Average throughput
- Peak throughput
- Network utilization
- Compression ratio effect

### 4. Real-World Application Tests

#### Docker Image Operations
```bash
# Pull large image
time docker pull nvidia/cuda:12.0.0-devel-ubuntu22.04

# Build from Dockerfile with multiple layers
time docker build -t test-app .

# Push to registry
time docker push registry/test-app
```

#### Database Operations
```bash
# PostgreSQL pgbench
pgbench -i -s 100 testdb  # Initialize
pgbench -c 10 -j 2 -T 60 testdb  # Run benchmark

# MySQL sysbench
sysbench oltp_read_write --table-size=1000000 prepare
sysbench oltp_read_write --threads=16 --time=60 run
```

#### File Operations Mix
```bash
# Bonnie++ comprehensive I/O test
bonnie++ -d /mnt/test -s 16G -n 256 -m test-server -f -b

# IOzone full spectrum test
iozone -a -g 16G -i 0 -i 1 -i 2 -f /mnt/test/iozone.tmp
```

### 5. Network Overhead Analysis
**Tool**: `iperf3`
```bash
# Baseline network performance (no storage protocol)
iperf3 -c tailscale-ip -t 60 -P 4

# With storage protocol active
# Compare throughput difference
```

**Measurements**:
- Raw Tailscale throughput
- Protocol overhead percentage
- Packet size efficiency
- Retransmission rates

## Performance Metrics Collection

### Primary Metrics
1. **Throughput**
   - Sequential read/write (MB/s)
   - Random read/write IOPS
   - Mixed workload performance

2. **Latency**
   - Average response time
   - 95th percentile
   - 99th percentile
   - Maximum latency

3. **Resource Utilization**
   - CPU usage (host and container)
   - Memory consumption
   - Network bandwidth utilization
   - Disk I/O wait time

4. **Scalability**
   - Performance with concurrent connections
   - Multi-container access patterns
   - Lock contention metrics

### Secondary Metrics
1. **Protocol Efficiency**
   - Packet overhead ratio
   - Metadata operations/second
   - Connection establishment time
   - Reconnection behavior

2. **Cache Effectiveness**
   - Cache hit ratio
   - Cache memory usage
   - Cache invalidation frequency

3. **Error Handling**
   - Retry frequency
   - Timeout occurrences
   - Data integrity verification

## Testing Tools

### Core Benchmarking Tools
1. **fio** - Flexible I/O tester
   - Version: 3.30+
   - Purpose: Detailed I/O pattern testing

2. **iperf3** - Network performance
   - Version: 3.9+
   - Purpose: Network baseline and overhead

3. **dd** - Basic throughput
   - Purpose: Simple sequential I/O tests

4. **rsync** - Real-world file transfer
   - Purpose: Practical file synchronization

### Specialized Tools
1. **nfsstat** - NFS statistics
2. **smbstatus** - SMB connection monitoring
3. **iostat** - I/O statistics
4. **sar** - System activity reporter
5. **tcpdump/Wireshark** - Protocol analysis

### Monitoring Stack
1. **Prometheus** - Metrics collection
2. **Grafana** - Visualization
3. **node_exporter** - System metrics
4. **netdata** - Real-time monitoring

## Test Execution Framework

### Test Phases
1. **Baseline Establishment** (Day 1)
   - Raw disk performance
   - Network performance
   - System capabilities

2. **Protocol Testing** (Day 2-3)
   - Individual protocol benchmarks
   - Parameter optimization
   - Stability testing

3. **Comparative Analysis** (Day 4)
   - Side-by-side comparison
   - Workload-specific results
   - Recommendation matrix

4. **Optimization Validation** (Day 5)
   - Tuned configuration testing
   - Long-term stability
   - Edge case handling

### Test Matrix

| Test Case | SSHFS | NFS v3 | NFS v4 | SMB3 | Duration |
|-----------|-------|---------|---------|------|----------|
| Sequential Write 1GB | ✓ | ✓ | ✓ | ✓ | 5 min |
| Sequential Read 1GB | ✓ | ✓ | ✓ | ✓ | 5 min |
| Random 4K Mixed | ✓ | ✓ | ✓ | ✓ | 10 min |
| Large File Transfer | ✓ | ✓ | ✓ | ✓ | 15 min |
| Small Files (10K×1KB) | ✓ | ✓ | ✓ | ✓ | 10 min |
| Container Backup | ✓ | ✓ | ✓ | ✓ | 20 min |
| Concurrent Access | ✓ | ✓ | ✓ | ✓ | 15 min |
| Failure Recovery | ✓ | ✓ | ✓ | ✓ | 10 min |

## Results Documentation

### Performance Report Structure
1. **Executive Summary**
   - Winner per workload type
   - Overall recommendation
   - Critical findings

2. **Detailed Results**
   - Protocol-by-protocol analysis
   - Graphs and charts
   - Raw data tables

3. **Optimization Impact**
   - Before/after comparisons
   - Tuning parameter effects
   - Cost-benefit analysis

4. **Recommendations**
   - Use case mapping
   - Configuration templates
   - Migration strategy

### Key Performance Indicators (KPIs)

1. **Throughput Targets**
   - Sequential: > 100 MB/s
   - Random 4K: > 5000 IOPS
   - Container backup: > 50 MB/s

2. **Latency Targets**
   - Average: < 10ms
   - 99th percentile: < 100ms
   - Metadata ops: < 5ms

3. **Efficiency Targets**
   - Protocol overhead: < 10%
   - CPU usage: < 25%
   - Memory overhead: < 1GB

## Automation and Repeatability

### Automated Test Execution
```bash
# Run complete benchmark suite
./scripts/benchmarks/benchmark-all-protocols.sh

# Generate performance report
./scripts/benchmarks/generate-performance-report.sh
```

### Results Validation
- Run each test 3 times minimum
- Calculate standard deviation
- Identify and investigate outliers
- Document environmental factors

### Continuous Benchmarking
- Weekly performance regression tests
- Automated alerting on degradation
- Historical trend analysis
- Capacity planning data

## Expected Outcomes

### Performance Improvements vs SSHFS
| Protocol | Sequential R/W | Random I/O | Metadata Ops | CPU Usage |
|----------|---------------|------------|--------------|-----------|
| NFS v3 | +40-60% | +100-150% | +200% | -50% |
| NFS v4 | +50-70% | +120-180% | +250% | -45% |
| SMB3 | +30-50% | +80-120% | +150% | -40% |

### Recommended Configurations
1. **General Purpose**: NFS v4.2 with async, 1MB buffers
2. **Database Workloads**: NFS v4.2 with sync, delegation
3. **Media Streaming**: SMB3 with multichannel
4. **Development**: NFS v3 for simplicity
5. **Windows Compatibility**: SMB3 required

## Conclusion
This benchmarking methodology provides comprehensive evaluation of storage protocols over Tailscale, enabling data-driven decisions for production deployment. Regular execution ensures optimal performance as workloads evolve.