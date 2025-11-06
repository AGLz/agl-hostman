# Performance Testing Quick Start Guide

> **Framework Version**: 1.0.0
> **Last Updated**: 2025-11-02

---

## ⚡ Quick Start (5 Minutes)

### 1. Install Required Tools

```bash
# Update package list
apt-get update

# Install required tools
apt-get install -y bc jq curl iputils-ping coreutils

# Install recommended tools (optional but highly recommended)
apt-get install -y iperf3 fio parallel
```

### 2. Run Your First Test

```bash
# Navigate to performance tests
cd /mnt/overpower/apps/dev/agl/agl-hostman/tests/performance

# Run system baseline
./baseline/system-baseline.sh

# View results
cat /tmp/performance-results/system-baseline_*.json | jq '.'
```

### 3. Run Complete Suite

```bash
# Run all tests
./run-performance-suite.sh

# View report
cat docs/test-reports/performance/performance-suite-report_*.md
```

---

## 📋 Individual Test Scripts

### System Baseline
```bash
# Basic run
./baseline/system-baseline.sh

# Verbose output with JSON pretty print
VERBOSE=1 ./baseline/system-baseline.sh

# Custom results directory
RESULTS_DIR=/tmp/my-results ./baseline/system-baseline.sh
```

**What it tests**: CPU, Memory, Disk, Network, Processes

**Output**: `/tmp/performance-results/system-baseline_TIMESTAMP.json`

---

### Network Performance (WireGuard)
```bash
# Basic run
./network/wireguard-perf.sh

# Custom packet count and duration
PACKET_COUNT=200 DURATION=60 ./network/wireguard-perf.sh

# Test specific targets
TARGETS="10.6.0.5 10.6.0.10" ./network/wireguard-perf.sh

# Verbose output
VERBOSE=1 ./network/wireguard-perf.sh
```

**What it tests**: WireGuard latency, throughput, packet loss

**Output**: `/tmp/performance-results/wireguard-perf_TIMESTAMP.json`

---

### Storage Performance (NFS)
```bash
# Basic run
./storage/nfs-benchmark.sh

# Large test with more I/O depth
TEST_SIZE=5G IO_DEPTH=32 ./storage/nfs-benchmark.sh

# Custom block size
BLOCK_SIZE=64k ./storage/nfs-benchmark.sh

# Test specific mounts
NFS_MOUNTS="/mnt/pve/fgsrv6-wg" ./storage/nfs-benchmark.sh

# Verbose output
VERBOSE=1 ./storage/nfs-benchmark.sh
```

**What it tests**: NFS read/write performance, IOPS, latency

**Output**: `/tmp/performance-results/nfs-benchmark_TIMESTAMP.json`

---

### Service Performance (Archon MCP)
```bash
# Basic run
./services/archon-perf.sh

# High load test
REQUEST_COUNT=500 CONCURRENCY=50 ./services/archon-perf.sh

# Custom Archon URL
ARCHON_URL=http://10.6.0.21:8051 ./services/archon-perf.sh

# Verbose output
VERBOSE=1 ./services/archon-perf.sh
```

**What it tests**: Archon API response time, throughput, concurrency

**Output**: `/tmp/performance-results/archon-perf_TIMESTAMP.json`

---

## 🎯 Master Suite Runner

### Run All Tests
```bash
./run-performance-suite.sh
```

### Run Specific Categories
```bash
# Network tests only
./run-performance-suite.sh --category network

# Baseline and storage
./run-performance-suite.sh --category "baseline storage"

# All service tests
./run-performance-suite.sh --category services
```

### Custom Directories
```bash
# Custom results location
./run-performance-suite.sh --results-dir /tmp/perf-results

# Custom report location
./run-performance-suite.sh --report-dir /var/reports

# Both custom
./run-performance-suite.sh \
  --results-dir /tmp/perf-results \
  --report-dir /var/reports
```

---

## 📊 Understanding Results

### Status Levels

- **GOOD** ✅: Performance within baseline targets
  - Example: CPU load < number of cores
  - Example: Latency < 10ms

- **WARNING** ⚠️: Performance degraded but acceptable
  - Example: CPU load 1.0-1.5× cores
  - Example: Latency 10-20ms

- **CRITICAL** 🚨: Performance below acceptable thresholds
  - Example: CPU load > 1.5× cores
  - Example: Latency > 20ms

### Reading JSON Results

```bash
# Pretty print latest results
cat /tmp/performance-results/*.json | jq '.'

# Extract specific metrics
jq '.cpu.load_1m' /tmp/performance-results/system-baseline_*.json

# Filter by status
jq '.latency_tests[] | select(.status == "GOOD")' \
  /tmp/performance-results/wireguard-perf_*.json

# Get average latency
jq '[.latency_tests[].rtt_avg_ms] | add / length' \
  /tmp/performance-results/wireguard-perf_*.json
```

---

## 🔧 Troubleshooting

### Missing Dependencies

**Problem**: Script fails with "Missing dependencies"

**Solution**:
```bash
# Install all tools
apt-get update && apt-get install -y \
  bc jq curl iputils-ping coreutils iperf3 fio parallel
```

---

### Permission Errors

**Problem**: "Cannot write to /mnt/pve/..."

**Solution**:
```bash
# Check mount permissions
ls -la /mnt/pve/

# Run with appropriate user
sudo ./storage/nfs-benchmark.sh
```

---

### WireGuard Not Found

**Problem**: "WireGuard not running"

**Solution**:
```bash
# Check WireGuard status
wg show

# If not running, start it
systemctl start wg-quick@wg0

# Verify
wg show
```

---

### Archon Not Reachable

**Problem**: "Archon not reachable"

**Solution**:
```bash
# Check Archon service
curl http://10.6.0.21:8051/health

# Try Tailscale endpoint
ARCHON_URL=http://100.80.30.59:8051 ./services/archon-perf.sh

# Check container status
ssh root@192.168.0.245 pct status 183
```

---

### iperf3 Server Not Available

**Problem**: "iperf3 server not available"

**Solution**:
```bash
# Install iperf3 on target host
ssh root@10.6.0.12 'apt-get install -y iperf3'

# Start iperf3 server
ssh root@10.6.0.12 'iperf3 -s -D'

# Verify
ssh root@10.6.0.12 'pgrep iperf3'
```

---

## 📈 Performance Targets

### Network (WireGuard)
- ✅ Latency: < 5ms average
- ✅ Throughput: > 500 Mbps
- ✅ Packet Loss: < 0.1%

### Storage (NFS)
- ✅ Sequential Read: > 100 MB/s
- ✅ Sequential Write: > 80 MB/s
- ✅ Random IOPS: > 3000

### Service (Archon MCP)
- ✅ Response Time (p95): < 100ms
- ✅ Throughput: > 100 req/s
- ✅ Error Rate: < 0.1%

### System (CT179)
- ✅ CPU Load: < 4.0 (48 cores)
- ✅ Memory Usage: < 80%
- ✅ Disk I/O Wait: < 5%

---

## 🔄 Continuous Testing

### Daily Automated Tests

```bash
# Add to crontab
crontab -e

# Add this line (runs at 2 AM daily)
0 2 * * * cd /mnt/overpower/apps/dev/agl/agl-hostman/tests/performance && ./run-performance-suite.sh >> /var/log/perf-tests.log 2>&1
```

### Pre-Optimization Baseline

```bash
# Before making changes
./run-performance-suite.sh --results-dir /tmp/before-optimization

# Make your changes...

# After changes
./run-performance-suite.sh --results-dir /tmp/after-optimization

# Compare
diff <(jq . /tmp/before-optimization/*.json) \
     <(jq . /tmp/after-optimization/*.json)
```

---

## 🎯 Next Steps

1. **Run Initial Baseline**:
   ```bash
   ./run-performance-suite.sh
   ```

2. **Review Results**:
   ```bash
   cat docs/test-reports/performance/*.md
   ```

3. **Address Issues**: Check WARNING or CRITICAL statuses

4. **Schedule Continuous Testing**: Add to cron

5. **Monitor Trends**: Compare results over time

---

## 📚 Additional Resources

- **Framework Documentation**: `README.md`
- **Deliverable Summary**: `../../../docs/test-reports/performance/TESTER-DELIVERABLE-SUMMARY.md`
- **Infrastructure Map**: `../../../docs/INFRA.md`
- **Archon Integration**: `../../../docs/ARCHON.md`

---

## 🆘 Getting Help

**Common Issues**: See "Troubleshooting" section above

**Framework Help**:
```bash
./run-performance-suite.sh --help
```

**Contact**: Infrastructure team via #agl-performance

---

**Quick Start Version**: 1.0.0
**Last Updated**: 2025-11-02
**Maintained By**: Tester Agent (Hive Mind)
