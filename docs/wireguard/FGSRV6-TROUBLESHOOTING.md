# FGSRV6 Performance Troubleshooting
**Date**: 2025-10-16
**Issue**: FGSRV6 NFS performance slower via WireGuard than Tailscale
**Goal**: Improve FGSRV6 performance without compromising architecture

## 🔍 Problem Analysis

### Current Situation

**FGSRV6 Role**: Dual purpose
1. WireGuard Hub (10.6.0.5:51823)
2. NFS Server (exported at /)

**Performance Issue**:
```
FGSRV6 via Tailscale: 6.4 MB/s  ✅
FGSRV6 via WireGuard: 1.9 MB/s  ❌ (3.4x slower!)
FGSRV6 via Public IP:  4.6 MB/s  ⚠️
```

### Root Cause

**Loopback Problem**:
```
AGLSRV1 → mount 10.6.0.5:/
         ↓
    WireGuard encrypt
         ↓
FGSRV6 receives on wg0 (10.6.0.5)
         ↓
    WireGuard decrypt
         ↓
    NFS server (local)
```

**Why this is slow**:
1. Encryption overhead for local filesystem
2. Network stack traversal instead of direct access
3. WireGuard processing on same machine

## 💡 Solution Options

### Option 1: Use Local NFS Export (RECOMMENDED)

**Concept**: AGLSRV1 connects to FGSRV6's actual filesystem interface, not WireGuard

**Implementation**:
```bash
# On FGSRV6: Export NFS on main interface too
/storage/nfs-export 10.6.0.0/24(rw,sync,no_subtree_check,no_root_squash)

# On AGLSRV1: Use Tailscale or dedicated interface
mount -t nfs 100.83.51.9:/ /mnt/pve/fgsrv6-nfs
```

**Pros**:
- No encryption overhead
- Direct filesystem access
- Maintains WireGuard for other purposes

**Cons**:
- Mixed network approach
- FGSRV6 accessible via multiple IPs

### Option 2: Separate NFS from Hub

**Concept**: Move NFS to different interface or port

**Implementation**:
```bash
# Bind NFS to non-WireGuard interface
# /etc/nfs.conf
[nfsd]
host = 186.202.57.120  # Public IP

# AGLSRV1 connects via public IP
mount -t nfs 186.202.57.120:/ /mnt/pve/fgsrv6-nfs
```

**Pros**:
- Clear separation
- No WireGuard overhead

**Cons**:
- Slower than Tailscale (4.6 MB/s vs 6.4 MB/s)
- Public IP exposure

### Option 3: Enable Loopback Optimization

**Concept**: Short-circuit WireGuard for local traffic

**Implementation**:
```bash
# iptables rule to bypass WireGuard for local traffic
iptables -t nat -A PREROUTING -s 10.6.0.0/24 -d 10.6.0.5 -p tcp --dport 2049 -j DNAT --to-destination 186.202.57.120
```

**Pros**:
- Maintains single IP scheme
- Bypasses encryption

**Cons**:
- Complex iptables rules
- May break routing

### Option 4: Move NFS to FGSRV5 (LONG-TERM)

**Concept**: Consolidate NFS on FGSRV5 which has superior WireGuard performance

**Current**:
- FGSRV5: 1.9 GB/s via WireGuard ✅
- FGSRV6: 1.9 MB/s via WireGuard ❌

**Implementation**:
- Migrate FGSRV6 data to FGSRV5
- Use FGSRV5 (10.6.0.11) for all NFS
- Keep FGSRV6 as pure hub

**Pros**:
- Best performance (1.9 GB/s)
- Simplifies architecture
- FGSRV6 becomes pure hub

**Cons**:
- Storage migration required
- FGSRV6 storage unused

## 🧪 Testing Each Option

### Test 1: Current Baseline
```bash
# Tailscale (current best)
mount -t nfs 100.83.51.9:/ /mnt/pve/fgsrv6-nfs
dd if=/dev/zero of=/mnt/pve/fgsrv6-nfs/test bs=1M count=200 oflag=direct
# Result: 6.4 MB/s ✅
```

### Test 2: Via Hub (problematic)
```bash
mount -t nfs 10.6.0.5:/ /mnt/pve/fgsrv6-nfs
dd if=/dev/zero of=/mnt/pve/fgsrv6-nfs/test bs=1M count=200 oflag=direct
# Result: 1.9 MB/s ❌
```

### Test 3: Public IP Direct
```bash
mount -t nfs 186.202.57.120:/ /mnt/pve/fgsrv6-nfs
dd if=/dev/zero of=/mnt/pve/fgsrv6-nfs/test bs=1M count=200 oflag=direct
# Result: 4.6 MB/s ⚠️
```

### Test 4: Local Interface (if accessible)
```bash
# Check FGSRV6 local IP
ssh root@100.83.51.9 "ip addr | grep 'inet ' | grep -v 127 | grep -v tailscale | grep -v wg"
# Try mount via local IP if AGLSRV1 has route
```

## 📊 Solution Comparison

| Solution | Speed | Security | Complexity | Recommended |
|----------|-------|----------|------------|-------------|
| **Tailscale** | 6.4 MB/s | ✅ Excellent | ✅ Simple | ✅ YES |
| WireGuard loopback | 1.9 MB/s | ✅ Excellent | ✅ Simple | ❌ NO |
| Public IP | 4.6 MB/s | ⚠️ Firewall needed | ✅ Simple | ⚠️ Maybe |
| Separate NFS | TBD | ✅ Good | ⚠️ Medium | 🔍 Test |
| Move to FGSRV5 | 1.9 GB/s | ✅ Excellent | ❌ Complex | 🎯 Future |

## ✅ Recommended Implementation

### Immediate: Keep Tailscale for FGSRV6

**Rationale**:
- Best current performance (6.4 MB/s)
- Already working and stable
- No risk of breaking existing setup

**Configuration**:
```bash
# /etc/fstab on AGLSRV1
10.6.0.11:/  /mnt/pve/fgsrv5-nfs  nfs  ... (WireGuard - 1.9 GB/s)
100.83.51.9:/  /mnt/pve/fgsrv6-nfs  nfs  ... (Tailscale - 6.4 MB/s)
```

### Short-term: Test Local Interface

**If FGSRV6 has LAN IP accessible from AGLSRV1**:
```bash
# Test connectivity first
ping <FGSRV6_LAN_IP>

# If reachable, test NFS
mount -t nfs <FGSRV6_LAN_IP>:/ /mnt/pve/fgsrv6-nfs-test
dd if=/dev/zero of=/mnt/pve/fgsrv6-nfs-test/test bs=1M count=200 oflag=direct

# Expected: 100+ MB/s (LAN speed)
```

### Long-term: Consolidate on FGSRV5

**When storage permits**:
1. Evaluate FGSRV5 capacity (currently 77GB used)
2. Migrate critical FGSRV6 data to FGSRV5
3. Use FGSRV5 for all high-throughput NFS
4. Keep FGSRV6 as pure WireGuard hub

**Benefits**:
- Single NFS server at 1.9 GB/s
- Simplified architecture
- FGSRV6 becomes dedicated hub

## 🔧 Alternate Approach: Enable Peer Routing

**Current limitation**: Peers can't talk to each other directly

**Solution**: Enable routing on FGSRV6 hub
```bash
# On FGSRV6 hub
iptables -A FORWARD -i wg0 -o wg0 -j ACCEPT
iptables -t nat -A POSTROUTING -s 10.6.0.0/24 -o wg0 -j MASQUERADE

# Save rules
iptables-save > /etc/iptables/rules.v4
```

**This enables**:
- AGLSRV1 (10.6.0.10) → FGSRV5 (10.6.0.11) direct routing
- All peers can communicate via hub relay

**Benefit for FGSRV6 NFS**:
- Potentially allows direct spoke-to-hub optimizations
- May improve routing efficiency

## 🎯 Action Plan

### Phase 1: Immediate (Today)
- [x] Keep FGSRV6 on Tailscale (6.4 MB/s)
- [x] Document why WireGuard loopback is slow
- [ ] Enable peer routing on hub (improves mesh)

### Phase 2: Testing (This Week)
- [ ] Test FGSRV6 local IP if accessible
- [ ] Benchmark different interfaces
- [ ] Evaluate migration to FGSRV5

### Phase 3: Optimization (Next Week)
- [ ] Implement best performing solution
- [ ] Monitor for 48 hours
- [ ] Document final configuration

## 📝 Conclusions

**Why FGSRV6 is slow via WireGuard**:
- Hub-to-hub loopback creates encryption overhead
- Network stack traversal instead of direct FS access
- Not a WireGuard problem - architectural issue

**Best solution**:
- **Now**: Tailscale (6.4 MB/s, works perfectly)
- **Future**: Migrate to FGSRV5 (1.9 GB/s, optimal)

**Key Learning**:
- Don't use WireGuard interface for local services
- Separate control plane (WireGuard) from data plane (NFS)
- Hub location matters for performance

---

**Status**: Analysis complete ✅
**Decision**: Keep Tailscale for FGSRV6 NFS
**Next**: Enable peer routing for mesh improvement
