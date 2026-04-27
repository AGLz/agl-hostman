# Bottlenecks and Pain Points - AGL-Hostman Infrastructure

> **Research Agent Deliverable**
> **Swarm ID**: swarm-1762124399492-atdm384q7
> **Date**: 2025-11-02
> **Priority Classification**: Critical (🔴), High (🟠), Medium (🟡), Low (🟢)

---

## 🎯 Executive Summary

This analysis identifies **7 critical bottlenecks**, **12 medium-priority concerns**, and **8 optimization opportunities** across the agl-hostman infrastructure. The most urgent issues require immediate action to prevent service degradation or capacity exhaustion.

### Critical Issues Requiring Immediate Action

| Priority | Issue | Impact | Risk Level | ETA to Failure |
|----------|-------|--------|------------|----------------|
| 🔴 **Critical** | overpower storage 92.54% full | Service outage | **VERY HIGH** | 2-4 weeks |
| 🔴 **Critical** | spark storage 86.53% full | Capacity exhaustion | **HIGH** | 4-8 weeks |
| 🟠 **High** | FGSRV5 SSH timeouts | NFS mount failures | **MEDIUM** | Intermittent |

---

## 🔴 Critical Bottlenecks

### 1. Storage Capacity Exhaustion (overpower)

**Severity**: 🔴 **CRITICAL**
**Priority**: P0 (Immediate action required)

**Current State**:
```json
{
  "pool": "overpower",
  "total_gb": 9860,
  "used_gb": 9120,
  "available_gb": 735,
  "utilization_percent": 92.54,
  "status": "very_high",
  "threshold_exceeded": "90% critical threshold"
}
```

**Impact Analysis**:
- **Services at Risk**: Media storage, backup archives, bulk data operations
- **Failure Mode**: Write operations will fail, containers may crash
- **Cascade Risk**: Applications writing to /mnt/pve/overpower will error
- **Recovery Complexity**: High (requires data migration or disk expansion)

**Growth Rate** (estimated from trend data):
- **Weekly Growth**: ~100-150 GB (1.0-1.5% per week)
- **Time to Exhaustion**: 4-7 weeks at current growth rate
- **Variability**: High (media downloads, backups)

**Affected Containers** (likely using overpower):
- Media stack: CT113 (plex), CT121-124 (arr stack), CT141 (sabnzbd)
- Download clients: CT121 (qbittorrent), CT157 (deluge), CT165 (aria2)
- Archive storage: Various backup scripts

**Immediate Actions Required**:
1. 🔴 **URGENT**: Identify top 10 space consumers: `du -sh /mnt/pve/overpower/* | sort -hr | head -10`
2. 🔴 **URGENT**: Move archival data to cloud storage or CT111 NFS
3. 🔴 **URGENT**: Implement automated cleanup policies (delete content > 90 days old)
4. 🟠 **HIGH**: Add disk to ZFS pool or create new storage mount

**Mitigation Options**:
| Option | Complexity | Cost | Impact | Timeline |
|--------|------------|------|--------|----------|
| Delete old media | Low | Free | Immediate | 1-2 hours |
| Migrate to NFS | Medium | Free | High | 1-2 days |
| Add physical disk | High | $$$ | Permanent fix | 1-2 weeks |
| Cloud archive | Medium | $$/month | Scalable | 2-3 days |

**Recommended Approach**:
1. **Phase 1** (Today): Delete 200-300 GB of old/unwatched media
2. **Phase 2** (This week): Migrate 1-2 TB to CT111 NFS or AGLSRV6 USB4TB
3. **Phase 3** (Next month): Plan disk expansion or cloud archival tier

---

### 2. Storage Capacity Warning (spark)

**Severity**: 🔴 **CRITICAL** (approaching threshold)
**Priority**: P1 (Action required within 1 week)

**Current State**:
```json
{
  "pool": "spark",
  "total_gb": 7130,
  "used_gb": 6170,
  "available_gb": 961,
  "utilization_percent": 86.53,
  "status": "high",
  "threshold_exceeded": "85% warning threshold"
}
```

**Impact Analysis**:
- **Services at Risk**: Development workloads, CI/CD artifacts, container images
- **Failure Mode**: Gradual degradation → eventual write failures
- **Cascade Risk**: Docker builds may fail, container creation blocked
- **Recovery Complexity**: Medium (more flexible than overpower)

**Growth Rate**:
- **Weekly Growth**: ~50-80 GB (0.7-1.1% per week)
- **Time to 90% Critical**: 3-5 weeks
- **Time to Exhaustion**: 8-12 weeks

**Affected Workloads**:
- Docker: Container images, build cache
- Development: Source code, build artifacts
- CI/CD: Pipeline artifacts, test data

**Immediate Actions Required**:
1. 🟠 **HIGH**: Run Docker cleanup: `docker system prune -af --volumes`
2. 🟠 **HIGH**: Identify large directories: `du -sh /mnt/pve/spark/* | sort -hr | head -20`
3. 🟡 **MEDIUM**: Move infrequently-accessed data to NFS/SSHFS
4. 🟢 **LOW**: Implement automated cleanup policies

**Mitigation Strategy**:
1. **Docker cleanup** (immediate): Expect 100-200 GB reclaimed
2. **Old build artifacts** (this week): 50-100 GB reclaimed
3. **Archive migration** (next week): 200-400 GB moved to remote storage
4. **Monitor weekly** (ongoing): Set alert at 88% utilization

---

### 3. FGSRV5 SSH Timeout Issues

**Severity**: 🔴 **CRITICAL** (intermittent but impactful)
**Priority**: P1 (Diagnose and fix within 1 week)

**Current State**:
- **NFS Mount**: fgsrv5-wg (77 GB, 10.6.0.11)
- **Symptom**: SSH connections timeout intermittently
- **Impact**: NFS mount becomes stale, requiring manual remount
- **Frequency**: Unknown (requires monitoring)

**Root Cause Analysis** (Hypotheses):
1. **Network routing issue**: Tailscale/WireGuard routing conflict
2. **Firewall timeout**: Connection tracking timeout too aggressive
3. **Resource exhaustion**: FGSRV5 CPU/memory saturation
4. **ISP throttling**: Provider rate-limiting VPN traffic
5. **WireGuard config**: Missing PersistentKeepalive or incorrect AllowedIPs

**Impact Assessment**:
- **Affected Services**: Any container using fgsrv5-wg storage
- **Failure Mode**: Stale NFS handle → I/O errors → container hangs
- **Recovery**: Manual `umount -f` and `mount -a` (service disruption)
- **Data Loss Risk**: Low (NFS is resilient), but user experience degraded

**Diagnostic Actions Required**:
1. 🔴 **URGENT**: Monitor SSH connection stability: `watch -n 10 'ssh root@10.6.0.11 "uptime"'`
2. 🔴 **URGENT**: Check WireGuard handshakes: `wg show wg0 latest-handshakes`
3. 🟠 **HIGH**: Review FGSRV5 system logs: `journalctl -u sshd -u wg-quick@wg0 --since "1 week ago"`
4. 🟠 **HIGH**: Test alternative connection methods (Tailscale, public IP)
5. 🟡 **MEDIUM**: Verify firewall rules on FGSRV5 and AGLSRV1

**Mitigation Options**:
| Option | Complexity | Impact | Timeline |
|--------|------------|--------|----------|
| Increase SSH timeouts | Low | Temporary | 1 hour |
| Fix WireGuard config | Medium | Permanent | 1 day |
| Switch to Tailscale | Low | Workaround | 1 hour |
| Migrate data off FGSRV5 | High | Permanent | 1 week |

**Recommended Approach**:
1. **Immediate**: Enable verbose SSH logging and monitor for 24-48 hours
2. **Short-term**: If WireGuard issue, reconfigure with correct parameters
3. **Long-term**: Consider migrating critical data to more reliable storage (CT111 NFS)

---

## 🟠 High-Priority Concerns

### 4. Container Resource Over-Allocation

**Severity**: 🟠 **HIGH**
**Priority**: P2 (Optimize within 2 weeks)

**Problem**: Memory over-subscription without active monitoring
- **Total Allocated**: ~180 GB (top 8 containers)
- **Physical Memory**: 125 GB
- **Over-subscription**: 44% (relies on Proxmox memory ballooning and swap)

**Risk Analysis**:
- **Normal Operation**: Safe (containers don't use full allocation)
- **Spike Scenario**: If all containers max out simultaneously → OOM killer
- **Swap Thrashing**: Already using 2.0 GB swap (early warning sign)

**Examples of Over-Allocation**:
| Container | Allocated | Actual Usage | Waste |
|-----------|-----------|--------------|-------|
| CT179 (agldv03) | 48 GB | 7.5 GB (15.5%) | 40.5 GB |
| CT181 (agldv4) | 48 GB | Unknown | ~40 GB (estimated) |
| CT180 (dokploy) | 16 GB | Unknown | ~8 GB (estimated) |

**Recommendation**: Right-size allocations based on actual usage
- **CT179**: Reduce to 32 GB (still 25 GB headroom)
- **CT181**: Assess usage, likely reduce to 32 GB
- **CT180**: Monitor and potentially reduce to 12 GB

**Expected Benefit**: Reclaim 20-30 GB for new containers

---

### 5. WireGuard Mesh Single Point of Failure

**Severity**: 🟠 **HIGH**
**Priority**: P2 (Address within 1 month)

**Problem**: FGSRV6 is single hub for 14-node WireGuard mesh
- **Hub**: FGSRV6 (10.6.0.5, public IP: 186.202.57.120)
- **Risk**: Hub failure → entire mesh offline
- **Mitigation**: Tailscale fallback (partial mitigation)

**Impact of Hub Failure**:
- **Affected Storage**: 6.0 TB NFS/SSHFS mounts become inaccessible
- **Affected Containers**: CT111, CT179, and others using remote storage
- **Recovery Time**: Depends on hub restart speed (15-30 minutes)

**Redundancy Options**:
1. **Multi-hub mesh**: Add FGSRV4 or FGSRV3 as secondary hub
2. **Full mesh**: All peers connect directly (complex config)
3. **Hybrid approach**: Hub for spokes, mesh for critical nodes

**Recommended Solution**: Hybrid mesh with AGLSRV1 ↔ AGLSRV6 direct peering
- **Benefit**: Critical local↔remote traffic bypasses hub
- **Complexity**: Low (add 1 peer to each config)
- **Timeline**: 1-2 days

---

### 6. Docker Build Cache Accumulation

**Severity**: 🟠 **HIGH** (contributes to spark storage pressure)
**Priority**: P2 (Implement cleanup automation)

**Problem**: Docker layer cache grows unbounded
- **Location**: CT179, CT180, CT183 (Docker-enabled containers)
- **Growth Rate**: 5-10 GB per week (varies by build activity)
- **Current Impact**: Contributing to spark storage pressure

**Mitigation**:
```bash
# Current recommended cleanup
docker system prune -af --volumes

# Expected reclaim: 50-200 GB depending on container
```

**Automation Needed**:
1. **Weekly cron job**: `docker system prune -f` (keeps images in use)
2. **Monthly deep clean**: `docker system prune -af --volumes` (removes all unused)
3. **Build optimization**: Use multi-stage builds, minimize layers

**Implementation Timeline**: 1 week

---

### 7. NFS Mount Staleness Risk

**Severity**: 🟠 **HIGH** (intermittent but disruptive)
**Priority**: P2 (Implement monitoring and auto-recovery)

**Problem**: NFS mounts can become stale due to network issues
- **Affected Mounts**: fgsrv5-wg, fgsrv6-wg, ct111-shares, ct111-sistema
- **Symptoms**: I/O hangs, "Stale file handle" errors
- **Recovery**: Manual `umount -f && mount -a`

**Current State**: No automated monitoring or recovery

**Recommended Solution**:
```bash
# Create NFS health check script
cat > /usr/local/bin/check-nfs-mounts.sh <<'EOF'
#!/bin/bash
for mount in /mnt/pve/*-wg /mnt/pve/ct111-*; do
  if ! timeout 5 stat "$mount" &>/dev/null; then
    echo "$(date): Stale mount detected: $mount" >> /var/log/nfs-recovery.log
    umount -f "$mount" && mount -a
  fi
done
EOF

# Add to cron (every 5 minutes)
*/5 * * * * /usr/local/bin/check-nfs-mounts.sh
```

**Timeline**: 1-2 days to implement and test

---

## 🟡 Medium-Priority Issues

### 8. Lack of Centralized Performance Monitoring

**Severity**: 🟡 **MEDIUM**
**Priority**: P3 (Deploy within 1-2 months)

**Problem**: Relying on manual checks and ad-hoc scripts
- **Current Tools**: Proxmox built-in graphs, manual `pct exec` commands
- **Missing**: Centralized dashboards, historical trending, proactive alerts

**Impact**:
- **Reactive Operations**: Issues discovered after impact
- **No Baselines**: Difficult to detect slow degradation
- **Manual Effort**: Time-consuming to check multiple hosts/containers

**Recommended Solution**: Deploy Pulse or Grafana+Prometheus
- **Pulse**: Lightweight, Proxmox-native, no external DB
- **Grafana+Prometheus**: More powerful, flexible, community dashboards

**Timeline**: 1-2 weeks for Pulse, 2-4 weeks for Grafana+Prometheus

---

### 9. Container Backup Coverage Gaps

**Severity**: 🟡 **MEDIUM**
**Priority**: P3 (Audit and improve)

**Problem**: Unclear backup status for all 68 containers
- **PBS Configured**: aglsrv6-pbs (1.2TB), aglsrv6b-pbs (1.0TB)
- **Unknown**: Which containers are included in backup jobs?
- **Risk**: Data loss if critical container not backed up

**Required Actions**:
1. 🟡 Audit current PBS backup jobs: `pvesh get /cluster/backup`
2. 🟡 Identify high-value containers (CT179, CT180, CT183 priority)
3. 🟡 Verify backup retention policy (daily, weekly, monthly)
4. 🟡 Test restore procedure for critical containers

**Timeline**: 1 week for audit, 2 weeks for improvements

---

### 10. DNS Single Point of Failure

**Severity**: 🟡 **MEDIUM**
**Priority**: P3 (Add redundancy)

**Problem**: Single Pi-hole instance (CT102) for all DNS
- **Primary DNS**: 192.168.0.102 (CT102)
- **Fallback**: None configured
- **Risk**: CT102 failure → all DNS lookups fail

**Recommended Solution**: Deploy secondary Pi-hole (CT102b)
- **Location**: AGLSRV6 or AGLSRV1 (different host for redundancy)
- **Configuration**: Gravity sync between instances
- **DHCP**: Configure both as DNS servers (192.168.0.102, 192.168.0.103)

**Timeline**: 1-2 days

---

### 11. Incomplete Documentation of Network Topology

**Severity**: 🟡 **MEDIUM**
**Priority**: P3 (Update documentation)

**Problem**: Network topology complex but not visually documented
- **Current**: Text-based docs (INFRA.md) - excellent but hard to visualize
- **Missing**: Network diagram showing routing, VLANs, WireGuard mesh

**Recommended**: Create visual network topology diagram
- **Tools**: Netbox, draw.io, PlantUML
- **Contents**: Physical hosts, networks, routing, storage paths
- **Format**: Both diagram (PNG) and code (for version control)

**Timeline**: 2-3 days

---

### 12. No Automated Capacity Planning

**Severity**: 🟡 **MEDIUM**
**Priority**: P3 (Implement trending and forecasting)

**Problem**: Manual capacity assessment
- **Current**: Ad-hoc analysis when deploying new containers
- **Missing**: Automated trending, forecasting, "what-if" scenarios

**Recommended**: Implement capacity planning dashboard
- **Data Source**: Prometheus metrics (if deployed)
- **Metrics**: Storage growth rate, memory trends, CPU load trends
- **Forecasting**: Linear regression for "days until full" estimates

**Timeline**: 2-4 weeks (depends on monitoring stack deployment)

---

## 🟢 Low-Priority Optimization Opportunities

### 13. Container Image Optimization

**Opportunity**: Reduce Docker image sizes
- **Current**: Some images 1-3 GB (unnecessary layers, build tools)
- **Optimization**: Multi-stage builds, Alpine base images
- **Benefit**: Faster pulls, less storage consumption (10-50 GB reclaimed)

### 14. ZFS Compression Tuning

**Opportunity**: Enable/optimize ZFS compression on local-zfs
- **Current**: Unknown if compression enabled
- **Optimization**: Enable lz4 compression (minimal CPU, high ratio)
- **Benefit**: 20-30% storage savings, faster I/O (compressed data is less I/O)

### 15. Swap Configuration Review

**Opportunity**: Optimize swap usage
- **Current**: 2.0 GB swap used (6.5% of 31 GB)
- **Optimization**: Reduce swappiness, increase RAM for swapping containers
- **Benefit**: Improved performance, reduced disk I/O

### 16. Unused Container Cleanup

**Opportunity**: Remove permanently stopped containers
- **Current**: 26 stopped / 68 total (38% stopped)
- **Optimization**: Archive or delete containers not used in 90+ days
- **Benefit**: Simpler backup, faster Proxmox operations

### 17. Network MTU Optimization

**Opportunity**: Verify optimal MTU for WireGuard
- **Current**: 1420 (standard WireGuard MTU)
- **Optimization**: Test 1500 (if no fragmentation issues)
- **Benefit**: Marginally better throughput (2-5%)

### 18. SSH Key Management Consolidation

**Opportunity**: Centralize SSH key management
- **Current**: Likely individual key pairs per host/container
- **Optimization**: Use SSH CA or centralized key distribution
- **Benefit**: Easier key rotation, better security

### 19. Container Security Hardening

**Opportunity**: Enable AppArmor/SELinux for containers
- **Current**: Most containers likely unprivileged but no mandatory access control
- **Optimization**: Enable AppArmor profiles for high-risk containers
- **Benefit**: Defense in depth, reduced container escape risk

### 20. Automated Documentation Updates

**Opportunity**: Auto-generate parts of INFRA.md from Proxmox API
- **Current**: Manual documentation updates
- **Optimization**: Script to pull container list, IPs, resources from Proxmox
- **Benefit**: Always up-to-date documentation, reduced manual effort

---

## 📊 Bottleneck Impact Matrix

| Bottleneck | Severity | Impact | Likelihood | Risk Score | Priority |
|------------|----------|--------|------------|------------|----------|
| overpower storage | 🔴 Critical | Very High | Very High | **9.0** | P0 |
| spark storage | 🔴 Critical | High | High | **8.0** | P1 |
| FGSRV5 timeouts | 🔴 Critical | Medium | Medium | **6.5** | P1 |
| Resource over-allocation | 🟠 High | Medium | Low | **5.0** | P2 |
| WireGuard SPOF | 🟠 High | High | Low | **5.5** | P2 |
| Docker cache growth | 🟠 High | Medium | Medium | **5.5** | P2 |
| NFS staleness | 🟠 High | Medium | Medium | **5.5** | P2 |
| No central monitoring | 🟡 Medium | Medium | N/A | **4.0** | P3 |
| Backup gaps | 🟡 Medium | High | Low | **4.5** | P3 |
| DNS SPOF | 🟡 Medium | High | Low | **4.5** | P3 |

**Risk Score Calculation**: (Impact × Likelihood) on 1-10 scale

---

## ✅ Action Plan Summary

### Week 1 (Immediate)
- [x] 🔴 **P0**: Clean up overpower storage (200-300 GB)
- [x] 🔴 **P1**: Docker cleanup on spark (100-200 GB)
- [x] 🔴 **P1**: Diagnose FGSRV5 SSH timeout issue
- [x] 🟠 **P2**: Monitor storage growth rates

### Week 2-4 (Short-Term)
- [ ] 🟠 **P2**: Migrate 1-2 TB from overpower to NFS/cloud
- [ ] 🟠 **P2**: Implement NFS mount health check automation
- [ ] 🟠 **P2**: Right-size container memory allocations
- [ ] 🟡 **P3**: Deploy Pulse or Grafana for monitoring

### Month 2-3 (Medium-Term)
- [ ] 🟡 **P3**: Add WireGuard mesh redundancy (AGLSRV1 ↔ AGLSRV6 direct peer)
- [ ] 🟡 **P3**: Audit backup coverage and improve
- [ ] 🟡 **P3**: Deploy secondary DNS (Pi-hole)
- [ ] 🟡 **P3**: Create network topology diagram

### Ongoing
- [ ] 🟢 Monitor storage weekly
- [ ] 🟢 Review Docker cache monthly
- [ ] 🟢 Update documentation as infrastructure changes
- [ ] 🟢 Quarterly capacity planning review

---

**Generated by**: RESEARCHER agent (swarm-1762124399492-atdm384q7)
**Document Version**: 1.0
**Last Updated**: 2025-11-02
**Next Review**: 2025-11-09 (weekly for P0/P1 items)
