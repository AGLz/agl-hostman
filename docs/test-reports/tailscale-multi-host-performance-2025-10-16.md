# Multi-Host Performance Test Report via Tailscale
**Date**: October 16, 2025
**Test Origin**: CT179 (agldv03) @ AGLSRV1
**Network**: Tailscale VPN (100.x.x.x subnet)
**Test Method**: Sequential testing with 50MB file transfers

## Executive Summary

✅ **All 5 hosts tested successfully via Tailscale**

### Key Findings
- **Best Performance**: FGSRV6 (13.11 MB/s) - 3.7x faster than slowest
- **Latency Range**: 17.9ms - 31.7ms average
- **NFS Available**: FGSRV5, FGSRV6 only
- **100% Uptime**: All hosts responsive via Tailscale

---

## Detailed Test Results

### 1. AGLSRV5 (100.119.223.113)
**Location**: Cloud VPS
**Test Date**: Oct 16, 2025 23:14:03

| Metric | Result | Status |
|--------|--------|--------|
| **Latency (avg)** | 22.1ms | ✅ Good |
| **Latency (range)** | 15.0 - 38.8ms | ✅ Stable |
| **Packet Loss** | 0% | ✅ Perfect |
| **SSH** | Working | ✅ |
| **Uptime** | 7 days | ✅ |
| **Load Average** | 0.36 | ✅ Low |
| **Transfer Speed** | 4.99 MB/s | ⚠️ Moderate |
| **NFS** | Not available | ❌ |

**Analysis**: Moderate performance, stable latency. No NFS service available.

---

### 2. AGLSRV6/man6 (100.98.108.66)
**Location**: Proxmox host (man6)
**Test Date**: Oct 16, 2025 23:14:36

| Metric | Result | Status |
|--------|--------|--------|
| **Latency (avg)** | 31.7ms | ⚠️ Highest |
| **Latency (range)** | 24.0 - 62.2ms | ⚠️ Variable |
| **Packet Loss** | 0% | ✅ Perfect |
| **SSH** | Working | ✅ |
| **Uptime** | 24 days | ✅ |
| **Load Average** | 5.03 | ⚠️ **High** |
| **Transfer Speed** | 3.85 MB/s | ⚠️ Slowest |
| **NFS** | Not on host (CT111) | ℹ️ |

**Analysis**: Highest latency and slowest transfer speed. High system load (5.03) may be impacting performance. NFS service runs in CT111, not on host.

**Recommendation**: Investigate high load average on man6 host.

---

### 3. FGSRV4 (100.111.79.2)
**Location**: Cloud VPS (vps22826.publiccloud.com.br)
**Test Date**: Oct 16, 2025 23:15:14

| Metric | Result | Status |
|--------|--------|--------|
| **Latency (avg)** | 17.9ms | ✅ **Best** |
| **Latency (range)** | 12.2 - 40.1ms | ✅ Good |
| **Packet Loss** | 0% | ✅ Perfect |
| **SSH** | Working | ✅ |
| **Uptime** | 22 days | ✅ |
| **Load Average** | 0.07 | ✅ Very low |
| **Transfer Speed** | 4.99 MB/s | ✅ Good |
| **NFS** | Not available | ❌ |

**Analysis**: Best latency, good transfer speed, very low system load. Excellent overall performance.

---

### 4. FGSRV5 (100.71.107.26)
**Location**: Cloud VPS (vps24136.publiccloud.com.br)
**Test Date**: Oct 16, 2025 23:15:47

| Metric | Result | Status |
|--------|--------|--------|
| **Latency (avg)** | 22.4ms | ✅ Good |
| **Latency (range)** | 12.6 - 64.1ms | ⚠️ Variable |
| **Packet Loss** | 0% | ✅ Perfect |
| **SSH** | Working | ✅ |
| **Uptime** | 22 days | ✅ |
| **Load Average** | 1.53 | ✅ Moderate |
| **Transfer Speed** | 3.51 MB/s | ⚠️ Below avg |
| **NFS** | /storage/nfs-export | ✅ **Available** |

**Analysis**: NFS service available. Transfer speed below average but acceptable. Some latency spikes (64ms).

---

### 5. FGSRV6 (100.83.51.9) ⭐
**Location**: Cloud VPS (vps41772) - Hub
**Test Date**: Oct 16, 2025 23:16:25

| Metric | Result | Status |
|--------|--------|--------|
| **Latency (avg)** | 18.2ms | ✅ Excellent |
| **Latency (range)** | 13.2 - 36.7ms | ✅ Stable |
| **Packet Loss** | 0% | ✅ Perfect |
| **SSH** | Working | ✅ |
| **Uptime** | 527 days | 🏆 **Outstanding** |
| **Load Average** | 0.07 | ✅ Very low |
| **Transfer Speed** | 13.11 MB/s | 🚀 **Best** |
| **NFS** | /storage/nfs-export | ✅ **Available** |

**Analysis**: **BEST OVERALL PERFORMANCE**. Fastest transfer speed (3.7x better than slowest), excellent uptime (527 days), low latency, NFS available. This host should be prioritized for storage workloads.

---

## Performance Comparison

### Transfer Speed Ranking
1. 🥇 **FGSRV6**: 13.11 MB/s (340% faster than baseline)
2. 🥈 **AGLSRV5**: 4.99 MB/s
3. 🥈 **FGSRV4**: 4.99 MB/s (tied)
4. 🥉 **FGSRV5**: 3.51 MB/s
5. 📉 **AGLSRV6**: 3.85 MB/s

### Latency Ranking
1. 🥇 **FGSRV4**: 17.9ms
2. 🥈 **FGSRV6**: 18.2ms
3. 🥉 **AGLSRV5**: 22.1ms
4. **FGSRV5**: 22.4ms
5. 📉 **AGLSRV6**: 31.7ms

### NFS Availability
- ✅ **FGSRV5**: /storage/nfs-export
- ✅ **FGSRV6**: /storage/nfs-export
- ❌ **AGLSRV5**: Not available
- ❌ **FGSRV4**: Not available
- ℹ️ **AGLSRV6**: Available in CT111 (not host)

---

## Network Topology Analysis

### Tailscale vs WireGuard
**Issue Identified**: WireGuard mesh (10.6.0.x) not accessible from CT179 (test origin).

| Network | Accessibility | Performance | Use Case |
|---------|---------------|-------------|----------|
| **WireGuard** | ❌ Not from CT179 | 1.7 GB/s NFS (when accessible) | Host-to-host only |
| **Tailscale** | ✅ From CT179 | 3.5-13.1 MB/s | Container-friendly |

**Implication**: For containers like CT179, Tailscale is the only option. For host-to-host storage, WireGuard is 129-484x faster.

---

## Recommendations

### Priority 1: Use FGSRV6 for Storage
- **Fastest transfer speeds** (13.11 MB/s via Tailscale)
- **Excellent uptime** (527 days)
- **NFS available**
- **Low system load**

**Action**: Prioritize FGSRV6 for Tailscale-based storage mounts from containers.

### Priority 2: Investigate AGLSRV6/man6
- **High load average** (5.03) affecting performance
- **Slowest transfer speed** (3.85 MB/s)
- **Highest latency** (31.7ms avg, 62.2ms peak)

**Action**:
1. Check running processes on man6
2. Review CT111 resource allocation
3. Monitor load over time

### Priority 3: WireGuard Access from Containers
**Current Issue**: CT179 cannot access WireGuard mesh.

**Options**:
1. Configure WireGuard interface in CT179 (add to mesh)
2. Use Tailscale for container workloads (current workaround)
3. Route traffic through AGLSRV1 host (performance overhead)

**Recommendation**: Add CT179 to WireGuard mesh for 129-484x performance gain on NFS.

### Priority 4: NFS Deployment
**Current**: Only FGSRV5 and FGSRV6 have NFS.

**Recommended**:
- Deploy NFS in containers on AGLSRV5 and FGSRV4 (following CT111 pattern)
- Use container-based NFS for better isolation and management
- Never install NFS on physical Proxmox hosts (per requirements)

---

## Performance Baselines

### Tailscale Performance
- **Average Speed**: 6.09 MB/s (across all hosts)
- **Best Case**: 13.11 MB/s (FGSRV6)
- **Worst Case**: 3.51 MB/s (FGSRV5)
- **Latency**: 17.9-31.7ms average

### Comparison to Documentation
From previous testing:
- **WireGuard NFS**: 1.7 GB/s (277x faster than Tailscale avg)
- **Tailscale SSHFS baseline**: 10 MB/s
- **Current Tailscale average**: 6.09 MB/s (39% slower than documented baseline)

**Note**: Current speeds are 39% slower than documented 10 MB/s Tailscale baseline. This may be due to:
1. Network congestion
2. Container overhead (CT179)
3. VPS bandwidth limits
4. Time of day / load

---

## Test Environment

### Source
- **Host**: AGLSRV1 (Proxmox)
- **Container**: CT179 (agldv03)
- **IP**: 192.168.0.179 (local), 100.94.221.87 (Tailscale)
- **Network**: Tailscale only (WireGuard not accessible)

### Test Parameters
- **File Size**: 50 MB (zeros)
- **Transfer Method**: SCP without compression
- **Timeout**: 60 seconds per test
- **Ping Count**: 10 packets per host
- **SSH Timeout**: 5 seconds

### Test Script
`/tmp/test-host-tailscale.sh` - Custom multi-protocol tester

**Tests Performed**:
1. Network latency (ping -c 10)
2. SSH connectivity and uptime
3. File transfer speed (SCP 50MB)
4. NFS availability (showmount -e)

---

## Next Steps

1. ✅ **Deploy CT179 to WireGuard mesh** for 129-484x performance gain
2. ⚠️ **Investigate AGLSRV6 high load** - performance bottleneck
3. 📊 **Benchmark WireGuard from CT179** after mesh integration
4. 🔄 **Deploy NFS containers** on AGLSRV5 and FGSRV4
5. 📈 **Monitor FGSRV6** as primary storage host for Tailscale workloads

---

## Appendix: Raw Test Logs

All test logs stored in: `/var/log/multi-host-tests/`

- `AGLSRV5-tailscale.log`
- `AGLSRV6-tailscale.log`
- `FGSRV4-tailscale.log`
- `FGSRV5-tailscale.log`
- `FGSRV6-tailscale.log`

---

*Report generated: October 16, 2025*
*Test duration: ~4 minutes*
*Total data transferred: 250 MB (50MB × 5 hosts)*
