# Disk Failure Diagnostic Framework - Documentation Index

**Target System**: Proxmox Host 100.98.119.51
**Created By**: ANALYST Agent (Hive Mind Swarm)
**Version**: 1.0
**Date**: 2025-10-04

---

## Quick Navigation

### For Immediate Action (Emergency)
👉 **START HERE**: [Quick Reference Guide](./disk-diagnostic-quick-reference.md)
- Emergency procedures
- One-line commands
- Common scenarios
- Critical thresholds

### For Comprehensive Understanding
📚 **MAIN FRAMEWORK**: [Complete Diagnostic Framework](./disk-failure-diagnostic-framework.md)
- Full error classification (5 tiers)
- Risk scoring methodology
- Decision matrices
- 6-phase diagnostic sequence
- Monitoring dashboard design

### For Execution
⚙️ **DIAGNOSTIC TOOL**: `/root/host-admin/disk-diagnostic-suite.sh`
- Production-ready bash script
- Automated 6-phase diagnostics
- Risk score calculation
- Report generation

### For Project Overview
📋 **DELIVERABLE SUMMARY**: [ANALYST-DELIVERABLE-SUMMARY.md](./ANALYST-DELIVERABLE-SUMMARY.md)
- Complete mission objectives
- All deliverables explained
- Implementation guide
- Success metrics

### For Visual Overview
📊 **VISUAL SUMMARY**: [ANALYST-FRAMEWORK-VISUAL-SUMMARY.txt](./ANALYST-FRAMEWORK-VISUAL-SUMMARY.txt)
- Framework components diagram
- Quick decision trees
- Threshold tables
- File locations

---

## File Inventory

```
/root/host-admin/
├── claudedocs/
│   ├── disk-failure-diagnostic-framework.md      (42KB) - Main framework
│   ├── disk-diagnostic-quick-reference.md        (12KB) - Quick reference
│   ├── ANALYST-DELIVERABLE-SUMMARY.md            (19KB) - Project summary
│   ├── ANALYST-FRAMEWORK-VISUAL-SUMMARY.txt      (19KB) - Visual guide
│   └── README-DISK-DIAGNOSTICS.md                (this file)
│
└── disk-diagnostic-suite.sh                      (21KB) - Executable tool
```

---

## Quick Start (5 Minutes)

### Step 1: Run Initial Diagnostic
```bash
ssh root@100.98.119.51 "/root/host-admin/disk-diagnostic-suite.sh"
```

### Step 2: Review Output
- Report location: `/var/log/disk-diagnostics/diagnostic-report-TIMESTAMP.txt`
- Look for **Overall Risk Assessment** in Phase 6

### Step 3: Take Action Based on Risk Score
| Risk Score | What to Do |
|------------|-----------|
| 0-20 | Continue monitoring, no immediate action |
| 21-40 | Plan replacement within 7-30 days |
| 41-60 | Schedule maintenance within 24-48 hours |
| 61-80 | Urgent intervention within 2-6 hours |
| 81-100 | **EMERGENCY** - Follow critical procedures immediately |

---

## Framework Components at a Glance

### 1. Error Classification System (5 Tiers)
- **Tier 1**: I/O Errors (Hardware)
- **Tier 2**: SMART Failures (Predictive)
- **Tier 3**: ZFS Corruption (Data Integrity)
- **Tier 4**: Filesystem Errors (Logical)
- **Tier 5**: Controller/Interface Errors

### 2. Risk Scoring (0-100 Scale)
```
Risk = (Hardware × 0.4) + (Integrity × 0.3) + (Redundancy × 0.2) + (Age × 0.1)
```

### 3. Decision Matrix
- **Attempt Recovery If**: Errors <10/24h, SMART recoverable, redundancy exists
- **Replace Immediately If**: Reallocated >10, Pending >5, Uncorrectable >0

### 4. Diagnostic Phases (29-48 min total)
1. Initial Assessment (2-5 min)
2. Hardware Diagnostics (5-10 min)
3. ZFS Integrity (10-15 min)
4. Performance Assessment (5-10 min)
5. Data Loss Risk (5 min)
6. Comprehensive Report (2-3 min)

### 5. Monitoring Dashboard
- SMART checks every 5 minutes
- ZFS events in real-time
- Alert thresholds configurable
- Email/webhook notifications

---

## Common Use Cases

### Scenario 1: Proactive Monitoring
**When**: Daily operations
**Tool**: Monitoring dashboard (when deployed)
**Action**: Review alerts, track trends

### Scenario 2: Suspected Disk Issue
**When**: Performance degradation, errors in logs
**Tool**: Run diagnostic suite
**Action**: Follow Phase 1-6, review risk score

### Scenario 3: Emergency Response
**When**: Disk failure, pool degraded
**Tool**: Quick reference emergency procedures
**Action**: Create snapshots, stop VMs, replace disk

### Scenario 4: Capacity Planning
**When**: Quarterly reviews
**Tool**: Full diagnostic suite + trend analysis
**Action**: Plan upgrades, replacements

---

## Key Thresholds & Metrics

### SMART Attributes (Critical)
| Attribute | Warning | Critical | Action |
|-----------|---------|----------|--------|
| Reallocated Sectors | >0 | >10 | Replace |
| Pending Sectors | >0 | >5 | Immediate backup |
| Uncorrectable | >0 | >0 | CRITICAL - Replace now |
| Temperature | >55°C | >65°C | Check cooling |

### ZFS Pool States
| State | Risk | Action |
|-------|------|--------|
| ONLINE | Low | Monitor |
| DEGRADED | Medium-High | Replace failed disk within 24-48h |
| FAULTED | Critical | Emergency data extraction |
| UNAVAIL | Critical | Offline recovery procedures |

---

## Emergency Procedures

### Critical Failure (Risk >80)

**IMMEDIATE (0-30 min)**:
```bash
# 1. Emergency snapshots
for pool in $(zpool list -H -o name); do
    zfs snapshot -r ${pool}@emergency-$(date +%Y%m%d-%H%M%S)
done

# 2. Stop non-critical VMs
pvesh get /cluster/resources --type vm | \
    jq -r '.[] | select(.status=="running" and .name!="critical") | .vmid' | \
    xargs -I {} qm stop {}

# 3. Reduce I/O load
echo 1 > /sys/module/zfs/parameters/zfs_prefetch_disable
```

**URGENT (30-120 min)**:
- Backup critical data
- Order replacement hardware
- Test backup integrity
- Prepare recovery plan

---

## Implementation Checklist

### Initial Setup
- [ ] Review main framework document
- [ ] Deploy diagnostic suite to target host
- [ ] Run baseline diagnostic
- [ ] Configure alerting thresholds
- [ ] Set up monitoring (optional)

### Ongoing Operations
- [ ] Daily: Review monitoring dashboard
- [ ] Weekly: Run diagnostic suite
- [ ] Monthly: Trend analysis
- [ ] Quarterly: Full framework review

### Emergency Preparedness
- [ ] Emergency contact list ready
- [ ] Replacement hardware specs documented
- [ ] Backup procedures tested
- [ ] Recovery playbooks accessible

---

## Support & Resources

### Documentation
- Main Framework: [disk-failure-diagnostic-framework.md](./disk-failure-diagnostic-framework.md)
- Quick Reference: [disk-diagnostic-quick-reference.md](./disk-diagnostic-quick-reference.md)
- Visual Summary: [ANALYST-FRAMEWORK-VISUAL-SUMMARY.txt](./ANALYST-FRAMEWORK-VISUAL-SUMMARY.txt)

### Tools
- Diagnostic Suite: `/root/host-admin/disk-diagnostic-suite.sh`
- Monitoring Dashboard: `/usr/local/bin/disk-health-monitor.sh` (to be deployed)

### Logs & Reports
- Diagnostic Reports: `/var/log/disk-diagnostics/`
- Alert History: `/var/log/disk-health-alerts.log`
- Metrics Trending: `/var/lib/disk-metrics/`

---

## Success Metrics (6-Month Targets)

- ✅ Zero unplanned downtime from disk failures
- ✅ 100% of failures detected >24h in advance
- ✅ <30min average diagnostic time
- ✅ >90% team adoption of framework
- ✅ 50% reduction in escalations

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2025-10-04 | Initial framework release |

---

## Contact & Escalation

### Level 1: Automated Response (Risk 0-40)
- Monitoring alerts
- Standard procedures
- Ticket system

### Level 2: Manual Intervention (Risk 41-60)
- On-call engineer
- Scheduled maintenance
- Team coordination

### Level 3: Emergency Response (Risk 61-100)
- Senior team escalation
- Emergency procedures
- Stakeholder notification

---

**Framework Status**: ✅ Production Ready
**Last Updated**: 2025-10-04
**Next Review**: 2026-01-04

---

## Getting Started Workflow

```
1. Review this README
   ↓
2. Read Quick Reference Guide (10 min)
   ↓
3. Run Diagnostic Suite on target host
   ↓
4. Review risk score and recommendations
   ↓
5. Follow action plan based on severity
   ↓
6. Set up continuous monitoring (optional)
   ↓
7. Schedule regular framework reviews
```

**Need help?** Refer to the appropriate document:
- **Emergency**: Quick Reference Guide
- **How-to**: Main Framework Document
- **Overview**: Deliverable Summary
- **Commands**: Visual Summary

---

*Created by ANALYST Agent as part of Hive Mind Swarm (swarm-1759591536035-r3bboibim)*
*Mission: Systematic disk failure diagnostic framework for Proxmox infrastructure*
