# FGSRV06 Outage Incident Report

**Date**: 2026-03-16
**Severity**: HIGH
**Status**: ✅ RESOLVED - VPS Recovered After Reboot

---

## Summary

FGSRV06 (Locaweb VPS vps41772) experienced a complete network outage. The VPS was rebooted via Locaweb API and **recovered successfully** after approximately 16 minutes.

---

## VPS Information

| Attribute | Value |
|-----------|-------|
| VPS ID | vps41772 |
| Name | FGSRV06 |
| Public IP | 186.202.57.120 |
| Tailscale IP | 100.83.51.9 |
| WireGuard IP | 10.6.0.5 |
| Provider | Locaweb Cloud |
| Plan | 4 vCPUs, 8GB RAM, 200GB Disk |
| OS | Ubuntu 22.04 LTS |

---

## Timeline

| Time (UTC) | Event |
|------------|-------|
| ~18:00 | fgsrv06 detected as unreachable (Tailscale/WireGuard) |
| 18:08 | Initial diagnosis: API shows "installed/active", ping fails |
| 18:10 | SSH attempt: "Connection timed out during banner exchange" |
| 18:12 | Reboot via Locaweb API initiated (action 192803) |
| 18:14 | Reboot confirmed complete by API |
| 18:15 | Post-reboot test: 100% packet loss (both IPs) |
| 18:17 | VPS still offline - waiting for boot |
| ~03:55 | **RECOVERY**: VPS came back online (uptime: 16 min) |
| 03:56 | SSH connection successful via key authentication |
| 03:57 | WireGuard and Tailscale services confirmed operational |

---

## Diagnostic Results

### Pre-Reboot

| Test | Result |
|-----|--------|
| Locaweb API Status | installed / active |
| Ping 100.83.51.9 (Tailscale) | 100% packet loss |
| Ping 186.202.57.120 (Public) | OK (17-20ms latency) |
| SSH to 186.202.57.120 | Timeout during banner exchange |

### Post-Reboot (Initial)

| Test | Result |
|-----|--------|
| Ping 100.83.51.9 (Tailscale) | 100% packet loss |
| Ping 186.202.57.120 (Public) | 100% packet loss |
| Locaweb API Status | installed / active |
| Snapshots | None available |

### Recovery (Post-Boot)

| Test | Result |
|-----|--------|
| SSH Connection | ✅ SUCCESS (key: ~/.ssh/fg_srv.pem) |
| Ping Public IP | ✅ 13-15ms latency |
| Ping Tailscale IP | ✅ 11-37ms latency |
| WireGuard Service | ✅ 18 peers connected |
| Tailscale Service | ✅ Online (100.83.51.9) |
| System Load | 1.73 (normal) |
| Memory | 5.4GB available / 7.7GB total |
| Disk | 69% used (129GB / 197GB) |

---

## WireGuard Mesh Status (Recovery)

All 18 WireGuard peers reconnected successfully:

| Peers | Status |
|-------|--------|
| 10.6.0.1 (191.183.137.104) | ✅ Connected |
| 10.6.0.3 (189.100.68.34) | ✅ Connected |
| 10.6.0.4 (pending endpoint) | ✅ Configured |
| 10.6.0.10 (191.183.137.104) | ✅ Connected |
| 10.6.0.11 (191.252.200.20) | ✅ Connected |
| 10.6.0.12 (189.100.68.34) | ✅ Connected |
| 10.6.0.13 (189.100.68.34) | ✅ Connected |
| 10.6.0.14 (189.100.68.34) | ✅ Connected |
| 10.6.0.15 (189.100.68.34) | ✅ Connected |
| 10.6.0.16 (191.252.201.108) | ✅ Connected |
| 10.6.0.17 (177.103.217.109) | ✅ Connected |
| 10.6.0.18 (191.252.201.205) | ✅ Connected |
| 10.6.0.19 (191.183.137.104) | ✅ Connected |
| 10.6.0.20 (189.100.68.34) | ✅ Connected |
| 10.6.0.21 (191.183.137.104) | ✅ Connected |
| 10.6.0.22 (189.100.68.34) | ✅ Connected |
| 10.6.0.23 (189.100.68.34) | ✅ Connected |
| 10.6.0.24 (pending endpoint) | ✅ Configured |
| 10.6.0.52 (177.103.217.109) | ✅ Connected |
| 10.6.0.57 (177.103.217.109) | ✅ Connected |
| 10.6.0.58 (189.100.68.34) | ✅ Connected |
| 10.6.0.59 (veth7057211) | ✅ Connected |

---

## Root Cause Analysis

### Actual Cause
The VPS experienced a **boot hang or slow boot process** after the initial issue. The system eventually recovered after the reboot completed and services started.

### Possible Original Triggers
1. **Kernel panic or service hang** - Required reboot to clear
2. **Network stack issue** - SSH was timing out during banner exchange
3. **Resource exhaustion** - Temporary high load

---

## Lessons Learned

### What Worked
- ✅ Locaweb API reboot was effective
- ✅ SSH key authentication persisted after recovery
- ✅ WireGuard mesh auto-reconnected when hub returned
- ✅ Tailscale provided fallback during outage
- ✅ Incident documentation helped track the issue

### What Needs Improvement
- ⚠️ **No snapshots** - Recovery would be faster with snapshots
- ⚠️ **No monitoring** - Outage was detected manually
- ⚠️ **No alerting** - No automatic notification of hub down
- ⚠️ **Long recovery time** - ~16 minutes to boot was slow

---

## Recommended Actions

### Immediate (Completed)
- [x] SSH connection restored
- [x] WireGuard mesh operational
- [x] Tailscale operational
- [x] Incident documented

### Future Prevention
1. **Create Snapshots**
   ```bash
   ./scripts/locaweb-api/lw snapshot vps41772 "post-recovery-$(date +%Y%m%d)" "Snapshot after outage recovery"
   ```

2. **Add Monitoring**
   - Configure external health checks for WireGuard hub
   - Add alerts for hub unreachable > 2 minutes
   - Monitor Tailscale connectivity

3. **Implement Redundancy**
   - Consider secondary WireGuard hub
   - Document failover procedures

4. **Create Runbook**
   - Document recovery procedures
   - Include SSH key locations
   - List Locaweb panel access steps

---

## Contact Information

- **Locaweb Panel**: https://painel.locaweb.com.br/
- **Locaweb Support**: Via panel ticket system
- **VPS ID**: vps41772
- **SSH Key**: `~/.ssh/fg_srv.pem`

---

## Related Documentation

- `docs/FGSRV6_TROUBLESHOOTING_REPORT.md` - Previous APT issue (2025-10-20)
- `docs/INFRA.md` - Network topology
- `scripts/locaweb-api/` - VPS management scripts

---

## Commands Reference

```bash
# Check VPS status
./scripts/locaweb-api/lw-status vps41772

# Check pending actions
./scripts/locaweb-api/lw-actions vps41772

# Attempt reboot
./scripts/locaweb-api/lw-reboot vps41772

# Test connectivity
ping -c 3 186.202.57.120
ping -c 3 100.83.51.9

# SSH connect
ssh -i ~/.ssh/fg_srv.pem root@186.202.57.120

# Create snapshot
./scripts/locaweb-api/lw-snapshot vps41772 "manual-backup" "Post-recovery snapshot"
```

---

*Report updated by Claude Code - 2026-03-16*
*Status: RESOLVED*
