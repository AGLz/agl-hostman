# Performance Testing Framework

> **Created**: 2025-11-02
> **Agent**: Tester (Hive Mind Swarm)
> **Status**: ✅ Active

---

## 📋 Overview

Comprehensive performance testing framework for AGL infrastructure to establish baselines, validate optimizations, and ensure system reliability under load.

## 🎯 Testing Objectives

1. **Baseline Performance**: Establish current performance metrics
2. **Load Testing**: Validate system under realistic workloads
3. **Stress Testing**: Identify breaking points and limits
4. **Network Performance**: Test WireGuard, Tailscale, and LAN connectivity
5. **Storage I/O**: Benchmark NFS and local storage performance
6. **Service Performance**: Test Archon MCP, Dokploy, Docker services
7. **Optimization Validation**: Verify effectiveness of optimizations
8. **Continuous Monitoring**: Track performance trends over time

## 📁 Test Organization

```
tests/performance/
├── README.md                    # This file
├── baseline/                    # Baseline benchmarks
│   ├── system-baseline.sh      # System resource baselines
│   ├── network-baseline.sh     # Network performance baselines
│   └── storage-baseline.sh     # Storage I/O baselines
├── load/                        # Load testing scenarios
│   ├── http-load-test.sh       # HTTP service load tests
│   ├── api-load-test.sh        # API endpoint load tests
│   └── concurrent-ops-test.sh  # Concurrent operations
├── stress/                      # Stress testing
│   ├── cpu-stress-test.sh      # CPU stress tests
│   ├── memory-stress-test.sh   # Memory stress tests
│   └── network-stress-test.sh  # Network saturation tests
├── network/                     # Network performance tests
│   ├── wireguard-perf.sh       # WireGuard mesh performance
│   ├── tailscale-perf.sh       # Tailscale performance
│   └── lan-perf.sh             # LAN performance
├── storage/                     # Storage I/O tests
│   ├── nfs-benchmark.sh        # NFS performance tests
│   ├── local-io-test.sh        # Local storage I/O
│   └── disk-benchmark.sh       # Comprehensive disk tests
└── services/                    # Service-level tests
    ├── archon-perf.sh          # Archon MCP performance
    ├── dokploy-perf.sh         # Dokploy performance
    └── docker-perf.sh          # Docker operations performance
```

## 📊 Performance Metrics

### System Metrics
- **CPU**: Utilization %, load average, core saturation
- **Memory**: Usage %, available, swap usage
- **Disk**: I/O operations, throughput, latency
- **Network**: Bandwidth, latency, packet loss

### Service Metrics
- **Response Time**: avg, p50, p95, p99, max
- **Throughput**: requests/sec, operations/sec
- **Concurrency**: max concurrent connections
- **Error Rate**: failures per 1000 requests

### Network Metrics
- **Latency**: RTT, jitter
- **Throughput**: upload/download bandwidth
- **Packet Loss**: percentage
- **Connection Stability**: uptime, reconnections

### Storage Metrics
- **IOPS**: Read/write operations per second
- **Throughput**: MB/s read/write
- **Latency**: ms per operation
- **Concurrency**: simultaneous operations

## 🛠️ Testing Tools

### Required Tools
```bash
# Install performance testing tools
apt-get update && apt-get install -y \
  apache2-utils \    # ab (Apache Bench)
  wrk \             # HTTP benchmarking
  iperf3 \          # Network performance
  fio \             # Storage I/O
  sysbench \        # System benchmarking
  stress-ng \       # Stress testing
  nethogs \         # Network monitoring
  iotop \           # I/O monitoring
  htop              # System monitoring
```

### Optional Tools
- **locust**: Python-based load testing
- **vegeta**: HTTP load testing
- **nuttcp**: Network performance
- **ioping**: Disk latency measurement

## 🚀 Quick Start

### Run All Baseline Tests
```bash
cd /mnt/overpower/apps/dev/agl/agl-hostman/tests/performance

# Run baseline suite
./baseline/system-baseline.sh
./baseline/network-baseline.sh
./baseline/storage-baseline.sh

# Generate baseline report
./generate-baseline-report.sh
```

### Run Network Performance Suite
```bash
# Test WireGuard mesh
./network/wireguard-perf.sh

# Test Tailscale
./network/tailscale-perf.sh

# Compare results
./network/compare-results.sh
```

### Run Load Tests
```bash
# HTTP load testing
./load/http-load-test.sh --target http://10.6.0.21:8051

# API load testing
./load/api-load-test.sh --endpoint /mcp

# Concurrent operations
./load/concurrent-ops-test.sh --workers 100
```

### Run Stress Tests
```bash
# CPU stress (all cores, 60 seconds)
./stress/cpu-stress-test.sh --duration 60

# Memory stress (80% of available)
./stress/memory-stress-test.sh --percentage 80

# Network stress (saturate link)
./stress/network-stress-test.sh --target 10.6.0.12
```

## 📈 Performance Baselines

### Expected Performance (Baseline Targets)

#### Network Performance
| Metric | WireGuard | Tailscale | LAN | Unit |
|--------|-----------|-----------|-----|------|
| Latency (RTT) | <5 | <15 | <1 | ms |
| Throughput | >500 | >300 | >900 | Mbps |
| Packet Loss | <0.1 | <0.5 | <0.01 | % |

#### Storage Performance
| Metric | NFS (WG) | NFS (LAN) | Local | Unit |
|--------|----------|-----------|-------|------|
| Read IOPS | >5000 | >8000 | >50000 | ops/s |
| Write IOPS | >3000 | >5000 | >30000 | ops/s |
| Read BW | >100 | >200 | >500 | MB/s |
| Write BW | >80 | >150 | >400 | MB/s |
| Latency | <5 | <2 | <1 | ms |

#### Service Performance
| Service | Response Time (p95) | Throughput | Error Rate |
|---------|---------------------|------------|------------|
| Archon MCP | <100ms | >100 req/s | <0.1% |
| Dokploy API | <200ms | >50 req/s | <0.5% |
| Docker Ops | <500ms | >20 ops/s | <1% |

#### System Performance
| Metric | CT179 | AGLSRV1 | AGLSRV6 | Unit |
|--------|-------|---------|---------|------|
| CPU Load | <4.0 | <16.0 | <8.0 | load avg |
| Memory Usage | <80% | <75% | <70% | % |
| Disk I/O Wait | <5% | <10% | <10% | % |

## 📋 Test Execution

### Running Tests Manually
```bash
# Single test
./baseline/system-baseline.sh

# With options
./network/wireguard-perf.sh --duration 60 --target 10.6.0.12

# Save results
./storage/nfs-benchmark.sh --output /tmp/results.json
```

### Automated Test Suite
```bash
# Run complete performance suite
./run-performance-suite.sh

# Run specific category
./run-performance-suite.sh --category network

# Run with reporting
./run-performance-suite.sh --report --email admin@aglz.io
```

### CI/CD Integration
```bash
# GitHub Actions workflow
.github/workflows/performance-tests.yml

# Schedule: Daily at 02:00 UTC
# Triggers: Manual, on performance-related changes
# Reports: Slack, email, GitHub artifacts
```

## 📊 Result Analysis

### Understanding Results

**Good Performance**:
- ✅ Metrics within baseline targets
- ✅ Low variance between runs
- ✅ No degradation over time
- ✅ Scales linearly with load

**Warning Signs**:
- ⚠️ Metrics 10-20% below baseline
- ⚠️ High variance (>15%)
- ⚠️ Gradual degradation trend
- ⚠️ Non-linear scaling issues

**Critical Issues**:
- 🚨 Metrics >20% below baseline
- 🚨 Extreme variance (>30%)
- 🚨 Rapid degradation
- 🚨 System instability under load

### Trending and Monitoring
```bash
# Generate trend report
./analyze-trends.sh --period 30days

# Compare periods
./compare-periods.sh --before 2025-10-01 --after 2025-11-01

# Identify regressions
./detect-regressions.sh --threshold 10%
```

## 🔧 Troubleshooting

### Common Issues

**High Latency**:
```bash
# Check network path
traceroute 10.6.0.12

# Check WireGuard status
wg show

# Monitor network
iftop -i wg0
```

**Low Throughput**:
```bash
# Check CPU throttling
cat /proc/cpuinfo | grep MHz

# Check bandwidth limits
tc qdisc show

# Monitor network saturation
nload wg0
```

**High I/O Wait**:
```bash
# Check disk operations
iotop -o

# Check mount options
mount | grep nfs

# Monitor NFS
nfsstat -c
```

**Service Timeouts**:
```bash
# Check service status
systemctl status archon-mcp

# Check resource limits
ulimit -a

# Monitor connections
netstat -ant | grep ESTABLISHED | wc -l
```

## 📚 Best Practices

### Test Design
1. **Isolate Variables**: Test one component at a time
2. **Warm-Up Period**: Allow 30s warm-up before measurements
3. **Multiple Runs**: Run tests 3-5 times for consistency
4. **Realistic Load**: Use production-like workloads
5. **Document Conditions**: Record system state, time, load

### Test Execution
1. **Clean Environment**: No other tests running
2. **Consistent Timing**: Same time of day for comparisons
3. **Monitor Resources**: Track CPU, memory, disk, network
4. **Capture Logs**: Save detailed logs for analysis
5. **Verify Results**: Sanity check all measurements

### Result Reporting
1. **Statistical Analysis**: Include mean, median, percentiles
2. **Variance Reporting**: Show standard deviation, range
3. **Trend Analysis**: Compare to historical baselines
4. **Visual Presentation**: Use graphs and charts
5. **Actionable Insights**: Provide recommendations

## 🎯 Performance Goals

### Short-term (Month 1)
- ✅ Establish baseline for all infrastructure components
- ✅ Create automated test suite
- ✅ Implement continuous monitoring
- ✅ Document performance characteristics

### Medium-term (Quarter 1)
- 📊 Reduce WireGuard latency by 20%
- 📊 Improve NFS throughput by 30%
- 📊 Optimize Archon MCP response time by 25%
- 📊 Increase overall system efficiency by 15%

### Long-term (Year 1)
- 🎯 Achieve 99.9% service uptime
- 🎯 Sub-millisecond local network latency
- 🎯 10Gbps+ storage throughput
- 🎯 Linear scalability to 10x current load

## 📞 Support

**Documentation**: `/docs/test-reports/performance/`
**Tools Help**: `./tools/help.sh`
**Issue Tracking**: GitHub Issues with label `performance`
**Contact**: Infrastructure team via #agl-performance

---

**Framework Version**: 1.0.0
**Last Updated**: 2025-11-02
**Maintained By**: Tester Agent (Hive Mind)
