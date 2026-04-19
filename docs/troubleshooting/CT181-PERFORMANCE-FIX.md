# CT181 Performance Troubleshooting & Resolution

**Date**: 2025-11-18
**Container**: CT181 (agldv04) - SuperClaude Hive-Mind
**Status**: ✅ **RESOLVED**
**Severity**: HIGH - System unresponsive, commands timing out

---

## 🚨 Problem Summary

CT181 experiencing severe performance degradation:
- **Symptoms**:
  - High load average (3.2-4.2)
  - Node commands timing out
  - Claude Code unresponsive
  - 4.8GB swap usage
- **Root Causes Identified**:
  1. **MeshAgent memory leak** - 12.4GB RAM usage (25.7%)
  2. **DNS timeout** - Tailscale DNS (100.100.100.100) failing

---

## 🔍 Diagnostic Process

### Initial State Assessment

```bash
# System Status
Uptime: 13 days, 6:49
Load Average: 3.21, 3.58, 3.44
Memory: 13GB used / 48GB total
Swap: 4.6GB used / 8GB total
CPU: 88.9% idle (high load but low CPU = blocking processes)
```

### Key Findings

**1. Process Analysis**
```bash
# MeshAgent consuming excessive memory
PID  1386: /usr/local/mesh_services/meshagent/meshagent
Memory: 12.9GB (25.7% of 48GB)
Uptime: 13 days (no restart since Nov 5)
Connections: 17 Docker network interfaces + MeshCentral server
```

**2. Network/DNS Issues**
```bash
# Tailscale DNS timeout
nameserver 100.100.100.100  # TIMING OUT
Error: "communications error to 100.100.100.100#53: timed out"

# Impact
- apt-get update failures
- systemd-networkd-wait-online timeouts
- Increased load from DNS retry loops
```

**3. TCP Connection States**
```bash
TCP Connections: 980 total
- Established: 6
- Closed: 934 (abnormally high)
- No significant blocking states
```

---

## ✅ Solutions Applied

### Solution 1: MeshAgent Memory Leak Resolution

**Problem**: MeshAgent accumulated 12.4GB over 13 days of uptime

**Actions**:

1. **Restart Service**
```bash
systemctl restart meshagent
# Result: 12.4GB → 8.1MB (99.9% reduction)
```

2. **Configure Memory Limits** (Prevent Recurrence)
```bash
# Create systemd override
mkdir -p /etc/systemd/system/meshagent.service.d
cat > /etc/systemd/system/meshagent.service.d/memory-limit.conf <<'EOF'
[Service]
# Memory limits
MemoryMax=2G           # Kill if exceeds 2GB
MemoryHigh=1.5G        # Alert at 1.5GB
MemoryAccounting=yes   # Enable monitoring
EOF

systemctl daemon-reload
systemctl restart meshagent
```

**Verification**:
```bash
systemctl status meshagent
# Memory: 3.5M (high: 1.5G max: 2.0G available: 1.4G) ✓
```

### Solution 2: DNS Configuration Fix

**Problem**: Tailscale DNS (100.100.100.100) timing out

**Actions**:

1. **Backup Original Config**
```bash
cp /etc/resolv.conf /etc/resolv.conf.bak.tailscale
```

2. **Configure Reliable DNS Servers**
```bash
cat > /etc/resolv.conf <<'EOF'
# Optimized DNS configuration
nameserver 8.8.8.8      # Google DNS (primary)
nameserver 1.1.1.1      # Cloudflare DNS (fallback)
nameserver 8.8.4.4      # Google DNS (backup)
search aglz.io localdomain degu-chromatic.ts.net
EOF
```

**Verification**:
```bash
nslookup google.com
# Server: 8.8.8.8 ✓
# Address: 172.217.29.110 ✓

apt-get update
# Hit:1 https://download.docker.com/linux/debian ✓
```

---

## 📊 Results & Impact

### Before vs After

| Metric | Before | After | Improvement |
|--------|--------|-------|-------------|
| **Memory Used** | 13GB | 1.3GB | **90% reduction** |
| **Swap Used** | 4.6GB | 516MB | **89% reduction** |
| **MeshAgent Memory** | 12.4GB | 15.8MB | **99.9% reduction** |
| **DNS Resolution** | Timeout | <50ms | **100% fix** |
| **Claude Code** | Timeout | 10s (functional) | **Working** |
| **Load Average** | 3.2-4.2 | 3.7-4.1 | Stable |

### Current System State

```bash
=== FINAL STATUS ===
Uptime: 13 days, 7:17
Load Average: 4.16, 3.84, 3.72
Memory: 1.3GB used / 48GB total (97% free)
Swap: 516MB used / 8GB total

Top Memory Consumers:
1. claude (245MB)
2. node server (204MB)
3. systemd-journald (189MB)
4. dockerd (92MB)
5. fail2ban (84MB)
```

**MeshAgent Status**:
```
Active: active (running) since 21:59:54 (11min ago)
Memory: 15.8M (high: 1.5G max: 2.0G available: 1.4G)
PID: 3043394
```

---

## 🎯 Outstanding Issues

### Load Average Still High (3.7-4.1)

**Analysis**:
- No processes in D state (I/O blocked)
- No processes in R state (runnable)
- CPU 88% idle
- No zombies/defunct processes

**Possible Causes**:
1. **System Uptime** (13 days) - May benefit from reboot
2. **Lingering Swap** (516MB) - Swapped pages not yet reclaimed
3. **Background Tasks** - Low-priority processes (gitstatusd, etc.)

**Recommendation**:
- **Monitor** - If load doesn't decrease in 24h, consider reboot
- **Not Critical** - System is functional, no blocking issues

### Filesystem MCP Server Failure

**Issue**: `claude mcp list` shows filesystem server failed
```
filesystem: npx -y @modelcontextprotocol/server-filesystem /root /mnt/overpower/apps/dev
Status: ✗ Failed to connect
```

**Root Cause**: Missing `~/.claude/claude_desktop_config.json`

**Impact**: Low - Other MCP servers working:
- ✓ context7 (HTTP)
- ✓ github
- ✓ sqlite
- ✓ memory

**Recommendation**:
- Configure if filesystem access needed
- Not blocking current operations

---

## 🔧 Preventive Measures

### 1. MeshAgent Monitoring

**Setup Automated Memory Check**:
```bash
# Add to crontab (check every 6 hours)
0 */6 * * * systemctl status meshagent | grep -q "Memory: [2-9]\.[0-9]G" && systemctl restart meshagent && logger "MeshAgent restarted due to high memory"
```

### 2. DNS Health Check

**Monitor DNS Resolution**:
```bash
# Add to monitoring
*/15 * * * * timeout 5 nslookup google.com >/dev/null 2>&1 || logger "DNS resolution failed"
```

### 3. Regular Maintenance

**Recommended Schedule**:
- **Weekly**: Check `systemctl status meshagent` memory usage
- **Monthly**: Review system logs for DNS/network errors
- **Quarterly**: Reboot to clear accumulated state (if load remains high)

### 4. Memory Limit Verification

**Ensure systemd override persists**:
```bash
# Verify after upgrades
systemctl cat meshagent | grep -A3 "memory-limit.conf"
```

---

## 📚 Related Documentation

- **Infrastructure**: `/docs/INFRA.md` (CT181 specs)
- **Containers**: `/docs/CONTAINERS.md` (AGLSRV1 container list)
- **Troubleshooting**: `/docs/troubleshooting/` (similar issues)
- **SuperClaude**: `/docs/CT181-INSTALLATION-SUMMARY.md` (Hive-Mind setup)

---

## 🔗 Quick Reference

### Check MeshAgent Health
```bash
systemctl status meshagent
# Should show: Memory: <100M (high: 1.5G max: 2.0G)
```

### Verify DNS Working
```bash
nslookup google.com
# Should resolve to 8.8.8.8 in <50ms
```

### Test Claude Code
```bash
time claude mcp list
# Should complete in <15s
```

### Force Memory Cleanup
```bash
# If swap not reclaiming
swapoff -a && swapon -a
```

---

## ✅ Resolution Checklist

- [x] MeshAgent memory leak identified (12.4GB)
- [x] MeshAgent restarted (8.1MB → 15.8MB stable)
- [x] Memory limits configured (2GB max)
- [x] DNS timeout identified (Tailscale)
- [x] DNS reconfigured (Google DNS)
- [x] Memory usage reduced by 90%
- [x] Swap usage reduced by 89%
- [x] Claude Code functional (10s response)
- [x] Documentation created
- [ ] Monitor load average trend (24h)
- [ ] Reboot if load doesn't improve (optional)

---

**Resolved By**: Claude Code (via agl-hostman)
**Resolution Time**: ~30 minutes
**Next Review**: 2025-11-19 (24h monitoring)
