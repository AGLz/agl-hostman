# AGLSRV1 Proxmox Service Diagnostics Report

**Date**: 2025-10-21 23:00:19 -03
**Host**: algsrv1 (192.168.0.245)
**Kernel**: Linux 6.11.0-2-pve
**Uptime**: 1 day 21h 33min
**Diagnostician**: Service Diagnostics Agent

---

## Executive Summary

**VERDICT**: Proxmox WebUI is **OPERATIONAL** but system is experiencing **CRITICAL RESOURCE EXHAUSTION**

### Critical Issues Identified

1. **SEVERE**: /tmp filesystem at 100% capacity (63GB full)
2. **HIGH**: Memory pressure (99GB/125GB used, 30GB/31GB swap used)
3. **HIGH**: System load average 8.21/8.70/8.86 (sustained high load)
4. **MEDIUM**: Multiple failed mount services (NFS, rclone)
5. **MEDIUM**: Failed container services (CT200, CT999)
6. **LOW**: Remote PBS storage connection timeouts

---

## Core Proxmox Services Status

### WebUI Services - ALL OPERATIONAL ✅

| Service | Status | PID | Uptime | Workers | Issue |
|---------|--------|-----|--------|---------|-------|
| **pveproxy** | ✅ Running | 6908 | 1d 21h | 3 workers | None |
| **pvedaemon** | ✅ Running | 5405 | 1d 21h | 3 workers | None |
| **pvestatd** | ✅ Running | 5352 | 1d 21h | 2 tasks | ⚠️ PBS timeout warnings |
| **pve-cluster** | ✅ Running | 4518 | 1d 21h | 7 tasks | None |
| **pvescheduler** | ✅ Running | 66726 | 1d 21h | 2 tasks | ⚠️ Vzdump lock timeout |

### Network Ports - LISTENING ✅

```
Port 8006: pveproxy (WebUI) - ACTIVE with 3 workers
Port 85:   pvedaemon (API)  - ACTIVE with 3 workers (localhost only)
```

### WebUI HTTP Response - WORKING ✅

```html
<!DOCTYPE html>
<html>
  <head>
    <title>algsrv1 - Proxmox Virtual Environment</title>
```

**Conclusion**: WebUI is accessible and responding correctly on https://192.168.0.245:8006

---

## Critical System Issues

### 1. FILESYSTEM EXHAUSTION (CRITICAL) 🔴

```
tmpfs  63G  63G  0  100% /tmp
```

**Impact**:
- ALL temporary file operations blocked
- Container startup failures possible
- Service degradation likely
- Log rotation may fail
- Backup operations impacted

**Immediate Action Required**:
```bash
# Find large files consuming /tmp
du -sh /tmp/* 2>/dev/null | sort -rh | head -20

# Emergency cleanup (be cautious)
find /tmp -type f -atime +7 -size +100M -delete
```

---

### 2. MEMORY EXHAUSTION (CRITICAL) 🔴

```
Total Memory: 125GB
Used Memory:  99GB (79%)
Swap Used:    30GB/31GB (97%)
Load Average: 8.21, 8.70, 8.86
```

**Analysis**:
- System heavily swapping (97% swap utilization)
- Load average >8 indicates sustained CPU/IO bottleneck
- 7 users connected (possible runaway processes)

**Top Memory Consumers** (from service metrics):
- pvestatd: 147MB (peak 166MB, swap 7.4MB)
- pvedaemon: 179MB (peak 211MB, swap 628KB)
- pveproxy: 177MB (peak 371MB, swap 11.7MB)
- pvescheduler: 124MB (peak 187MB, swap 36.2MB)

**Recommended Actions**:
```bash
# Identify top memory consumers
ps aux --sort=-%mem | head -20

# Check for zombie processes
ps aux | grep -E 'Z|defunct'

# Check running containers consuming memory
pct list | grep running
```

---

### 3. FAILED MOUNT SERVICES (HIGH) 🟠

```
● mnt-pve-fgsrv5\x2dnfs.mount  - FAILED (FGSRV5 NFS)
● mnt-pve-fgsrv6\x2dnfs.mount  - FAILED (FGSRV6 NFS)
● rclone-wg.service            - FAILED (rclone WebGui)
```

**Impact**:
- Legacy NFS mounts failing (likely obsolete after WireGuard migration)
- No impact on current infrastructure (using -wg mounts)

**Remediation**:
```bash
# Disable obsolete mount units
systemctl disable mnt-pve-fgsrv5\\x2dnfs.mount
systemctl disable mnt-pve-fgsrv6\\x2dnfs.mount
systemctl reset-failed
```

---

### 4. FAILED CONTAINER SERVICES (HIGH) 🟠

```
● pve-container@200.service - FAILED (LXC Container 200)
● pve-container@999.service - FAILED (LXC Container 999)
```

**Container 200 (ollama)**:
- Status: Should be running (per infrastructure map)
- Tailscale: 100.116.57.111
- Purpose: LLM GPU compute
- **Action**: Manual restart required

**Container 999**:
- Status: Unknown container (not in documented inventory)
- **Action**: Investigate or remove orphaned service

---

### 5. FAILED USER SESSIONS (MEDIUM) 🟡

```
● session-c19.scope  - FAILED
● session-c6.scope   - FAILED
● session-c82.scope  - FAILED
```

**Impact**: Minor - stale SSH/console sessions
**Action**: No action needed (auto-cleanup on reboot)

---

### 6. ZFS SNAPSHOT MANAGER (MEDIUM) 🟡

```
● zfs-snapshot-manager.service - FAILED
```

**Impact**: Automated ZFS snapshots may not be running
**Recommended**:
```bash
systemctl status zfs-snapshot-manager.service -l
journalctl -u zfs-snapshot-manager.service --since today
```

---

### 7. PBS STORAGE TIMEOUTS (LOW) 🟡

**pvestatd warnings**:
```
aglsrv6b-pbs: Can't connect to 10.6.0.15:8007 (Connection timed out)
aglsrv6-pbs:  Can't connect to 10.6.0.14:8007 (Connection timed out)
```

**Analysis**:
- CT113 (10.6.0.14): PBS backup server on AGLSRV6
- CT172 (10.6.0.15): PBS backup server on AGLSRV6B
- Both accessible via WireGuard but timing out on PBS API port 8007

**Impact**: Backup status monitoring impacted, backups may be functional but not reported

---

## Storage Subsystem Analysis

### pvesm Status Output (CORRUPT DATA WARNING) ⚠️

```
400 Result verification failed
[5].used: type check ('integer') failed - got '-1.84467190920302e+19'
```

**Interpretation**:
- One storage backend returning corrupted metrics (negative exponent)
- Likely related to failed NFS mounts (fgsrv5-nfs, fgsrv6-nfs)
- Current WireGuard-based storage unaffected

**Remediation**:
```bash
# Remove obsolete storage configs
pvesm remove fgsrv5-nfs
pvesm remove fgsrv6-nfs
pvesm status  # Verify clean output
```

---

## Recent Task Failures

### Active Backup Task (LOCKED) ⚠️

```
UPID:algsrv1:00078F80:000B3A20:68F5D6E9:vzdump::root@pam: 0 (running)
ERROR: can't acquire lock '/var/run/vzdump.lock' - got timeout
```

**Timeline**:
- Backup started: Oct 21 03:15:04
- Lock timeout: Oct 21 06:15:04 (3 hours later)
- Status: Still running (task 0)

**Analysis**: Long-running backup holding global vzdump lock, preventing new backups

**Recommended Action**:
```bash
# Check if backup actually running or stale lock
ps aux | grep vzdump
ls -lh /var/run/vzdump.lock

# If stale, remove lock (CAUTION)
rm /var/run/vzdump.lock  # Only if no backup process active
```

---

### Container 181 Failures (RESOLVED)

Multiple startup failures for CT181 between 68F5BB3D - 68F7F9F7 (resolved at 68F7FA4C)

**Final Status**: Container 181 now operational (successful start/stop cycle)

---

### Container 179 (agldv03) - Development Container

**Recent Activity**:
- Multiple startup failures (68F5BB26 - 68F5BC21)
- Successfully started at 68F5BC86
- Start/stop cycle at 68F6C4FF/68F6C513
- **Current Status**: Running ✅

---

### VM 300 (nobara-gaming) - FAILED START ❌

**Error**: KVM startup timeout with GPU passthrough (VFIO)

**Configuration**:
- GPU: PCI 0000:05:00.0, 0000:05:00.1 (dual function)
- RAM: 16GB
- Status: Stopped (startup timeout)

**Possible Causes**:
- GPU driver conflict
- IOMMU misconfiguration
- VFIO device busy
- Insufficient memory (system at 99% utilization)

---

## Remediation Priority Matrix

### Immediate (Within 1 hour) 🔴

1. **Clear /tmp filesystem** - 100% full, blocking operations
   ```bash
   du -sh /tmp/* 2>/dev/null | sort -rh | head -20
   find /tmp -type f -atime +3 -delete  # Remove files >3 days old
   ```

2. **Investigate memory pressure** - 97% swap utilization
   ```bash
   ps aux --sort=-%mem | head -20
   free -h
   ```

3. **Check vzdump lock** - Preventing backups
   ```bash
   ps aux | grep vzdump
   rm /var/run/vzdump.lock  # If no backup running
   ```

### High Priority (Within 24 hours) 🟠

4. **Clean up failed mount services**
   ```bash
   systemctl disable mnt-pve-fgsrv5\\x2dnfs.mount mnt-pve-fgsrv6\\x2dnfs.mount
   systemctl reset-failed
   ```

5. **Remove corrupted storage configs**
   ```bash
   pvesm remove fgsrv5-nfs
   pvesm remove fgsrv6-nfs
   ```

6. **Restart Container 200 (ollama)**
   ```bash
   pct start 200
   pct status 200
   ```

7. **Investigate Container 999**
   ```bash
   pct config 999 || echo "Container doesn't exist, remove service"
   systemctl disable pve-container@999.service
   ```

### Medium Priority (Within 1 week) 🟡

8. **Fix ZFS snapshot manager**
9. **Investigate PBS connection timeouts**
10. **Optimize VM 300 GPU passthrough config**
11. **Review and reduce system load average**

---

## Monitoring Recommendations

### Add Continuous Monitoring

```bash
# Watch system resources
watch -n 5 'free -h; df -h /tmp; uptime'

# Monitor Proxmox services
watch -n 10 'systemctl status pveproxy pvedaemon pvestatd --no-pager | grep Active'

# Track failed services
watch -n 60 'systemctl --failed --no-pager'
```

### Set Up Alerts

Consider implementing:
- Disk space alerts at 90% threshold
- Memory pressure alerts at 85% RAM + 80% swap
- Load average alerts when >4.0 sustained
- Service restart alerts for critical services

---

## Conclusion

**Proxmox WebUI Status**: ✅ **OPERATIONAL**

**System Health**: 🔴 **CRITICAL** - Immediate intervention required

The WebUI is working correctly, but the host is experiencing severe resource exhaustion that will impact performance and reliability if not addressed immediately. Priority should be given to clearing /tmp filesystem and investigating memory pressure.

---

**Report Generated**: 2025-10-21 23:00 by Service Diagnostics Agent
**Next Review**: After remediation actions completed
**Escalation**: If /tmp cannot be cleared or memory pressure persists after process cleanup

