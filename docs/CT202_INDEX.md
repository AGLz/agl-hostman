# CT202 (n8n) Diagnostic Framework - Navigation Index

**Generated**: 2025-10-14
**Target**: CT202 (n8n) Container on AGLSRV1 Proxmox Host
**Framework Version**: 1.0

---

## Quick Access

### Emergency Response
**START HERE** if CT202 has an active issue:
- **File**: `/root/host-admin/claudedocs/CT202_QUICK_REFERENCE.md`
- **Purpose**: Immediate response commands and fast-track troubleshooting
- **Time**: 2-5 minutes to initial assessment

### Run Diagnostic Now
```bash
/root/host-admin/scripts/ct202-diagnostic.sh
```

---

## Documentation Structure

### 1. Quick Reference Card
**File**: `/root/host-admin/claudedocs/CT202_QUICK_REFERENCE.md` (7 KB)

**Best For**:
- Emergency response
- First-time responders
- Routine health checks
- Command lookups

**Contains**:
- Big 5 emergency commands
- Health threshold matrix
- Common issue fast-tracks
- Log analysis shortcuts
- Real-time monitoring
- Command aliases

**Reading Time**: 10 minutes
**Reference Time**: < 30 seconds per lookup

---

### 2. Comprehensive Diagnostic Strategy
**File**: `/root/host-admin/claudedocs/CT202_N8N_DIAGNOSTIC_STRATEGY.md` (26 KB)

**Best For**:
- Complex investigations
- Training new team members
- Understanding methodology
- Deep troubleshooting

**Contains**:
- 6-phase diagnostic checklist
- Detailed health indicators
- Log pattern analysis
- Troubleshooting decision tree
- Symptom-based procedures
- Escalation matrix
- Preventive maintenance
- Common issues appendix

**Reading Time**: 45-60 minutes (comprehensive)
**Reference Time**: 5-10 minutes per section

---

### 3. Implementation Summary
**File**: `/root/host-admin/claudedocs/CT202_DIAGNOSTIC_SUMMARY.md` (19 KB)

**Best For**:
- Understanding framework design
- Management overview
- Integration planning
- Knowledge transfer

**Contains**:
- Deliverables overview
- Tool capabilities
- Technical implementation
- Success metrics
- Testing procedures
- Continuous improvement

**Reading Time**: 30-40 minutes
**Audience**: Technical leads, managers, architects

---

### 4. This Index
**File**: `/root/host-admin/claudedocs/CT202_INDEX.md`

**Purpose**: Navigation hub for all CT202 diagnostic resources

---

## Automated Tools

### Tool 1: Comprehensive Diagnostic
**Script**: `/root/host-admin/scripts/ct202-diagnostic.sh` (4.1 KB)
**Permissions**: Executable (755)

**Purpose**: Full system diagnostic with 7-phase analysis

**Usage**:
```bash
/root/host-admin/scripts/ct202-diagnostic.sh
```

**Output**: `/root/host-admin/claudedocs/CT202_diagnostic_YYYYMMDD_HHMMSS.txt`

**Runtime**: 3-5 minutes
**Report Size**: 100-200 KB

**Phases Covered**:
1. Container status
2. Resource utilization (CPU, memory, disk, network)
3. n8n application health
4. Storage analysis
5. Network diagnostics
6. System error analysis
7. Proxmox host context

---

### Tool 2: Baseline Performance Monitor
**Script**: `/root/host-admin/scripts/ct202-baseline-monitor.sh` (1.4 KB)
**Permissions**: Executable (755)

**Purpose**: Periodic metric collection for baseline establishment

**Usage**:
```bash
# Manual execution
/root/host-admin/scripts/ct202-baseline-monitor.sh

# Automated setup (recommended)
(crontab -l 2>/dev/null; echo "*/15 * * * * /root/host-admin/scripts/ct202-baseline-monitor.sh") | crontab -
```

**Output**: `/root/host-admin/claudedocs/ct202_baseline_YYYYMMDD.log`

**Runtime**: < 10 seconds
**Frequency**: Every 15 minutes (recommended)
**Retention**: 30 days (automatic)

**Metrics Collected**:
- Load average (1m, 5m, 15m)
- Memory usage percentage
- Disk usage percentage
- Service status

---

### Tool 3: Support Bundle Creator
**Script**: `/root/host-admin/scripts/ct202-support-bundle.sh` (3.4 KB)
**Permissions**: Executable (755)

**Purpose**: Comprehensive data package for escalation

**Usage**:
```bash
/root/host-admin/scripts/ct202-support-bundle.sh
```

**Output**:
- Directory: `/root/host-admin/claudedocs/ct202_support_YYYYMMDD_HHMMSS/`
- Archive: `/root/host-admin/claudedocs/ct202_support_YYYYMMDD_HHMMSS.tar.gz`

**Runtime**: 5-7 minutes
**Bundle Size**: 1-10 MB (varies)

**Bundle Contents**:
- Full diagnostic report
- Container/LXC configuration
- Service and system logs
- Current system state
- Baseline metrics
- Proxmox host context
- Bundle metadata

---

## Common Scenarios - Where to Start

### Scenario: "CT202 is completely down"
1. **Start**: Quick Reference → Emergency Response section
2. **Run**: `pct status 202` and `pct exec 202 -- systemctl status n8n`
3. **If needed**: Run diagnostic script
4. **Escalate**: Create support bundle if Level 2+ required

**Estimated Time to Initial Assessment**: 2-5 minutes

---

### Scenario: "n8n is slow/unresponsive"
1. **Start**: Quick Reference → Common Issues → Performance
2. **Check**: Health thresholds (CPU, memory, disk)
3. **Analyze**: Run diagnostic script for detailed view
4. **Review**: Comprehensive Strategy → Phase 2 & 3

**Estimated Time to Root Cause**: 10-20 minutes

---

### Scenario: "Workflows are failing intermittently"
1. **Start**: Quick Reference → Log Analysis
2. **Pattern**: Review error frequency and types
3. **Deep Dive**: Comprehensive Strategy → Phase 3 (n8n Application)
4. **Context**: Check network and resource metrics

**Estimated Time to Pattern Identification**: 15-30 minutes

---

### Scenario: "Need to establish baseline metrics"
1. **Setup**: Tool 2 (Baseline Monitor) with cron
2. **Wait**: Collect data for 7 days minimum
3. **Analyze**: Review baseline logs for patterns
4. **Document**: Update health thresholds if needed

**Timeline**: 7-30 days for meaningful baseline

---

### Scenario: "Training new team member"
1. **Day 1**: Quick Reference walkthrough (1 hour)
2. **Week 1**: Comprehensive Strategy reading (self-paced)
3. **Week 2**: Hands-on diagnostic script execution
4. **Week 3**: Shadow real incident response
5. **Week 4**: Lead investigation with supervision

**Training Duration**: 4 weeks to competency

---

### Scenario: "Need to escalate to senior engineer"
1. **Prepare**: Run comprehensive diagnostic
2. **Create**: Execute support bundle script
3. **Brief**: Use Implementation Summary as context
4. **Handoff**: Provide bundle archive + initial findings

**Preparation Time**: 10-15 minutes

---

## File Locations Quick Reference

### Documentation Directory
```
/root/host-admin/claudedocs/
├── CT202_INDEX.md                     (This file)
├── CT202_QUICK_REFERENCE.md           (Emergency response)
├── CT202_N8N_DIAGNOSTIC_STRATEGY.md   (Comprehensive guide)
├── CT202_DIAGNOSTIC_SUMMARY.md        (Implementation details)
├── CT202_diagnostic_*.txt             (Generated reports)
├── ct202_baseline_*.log               (Baseline metrics)
└── ct202_support_*.tar.gz             (Support bundles)
```

### Scripts Directory
```
/root/host-admin/scripts/
├── ct202-diagnostic.sh          (Full diagnostic)
├── ct202-baseline-monitor.sh    (Periodic monitoring)
└── ct202-support-bundle.sh      (Escalation package)
```

---

## Quick Command Reference

### Most Common Commands

```bash
# Emergency status check
pct status 202 && pct exec 202 -- systemctl status n8n --no-pager

# Run full diagnostic
/root/host-admin/scripts/ct202-diagnostic.sh

# Check recent errors
pct exec 202 -- journalctl -u n8n -n 50 -p err --no-pager

# Resource overview
pct exec 202 -- free -m && pct exec 202 -- df -h

# Live monitoring
watch -n 5 'pct exec 202 -- uptime && pct exec 202 -- free -m | grep Mem'

# Create support bundle (for escalation)
/root/host-admin/scripts/ct202-support-bundle.sh
```

---

## Version Information

**Framework Version**: 1.0
**Release Date**: 2025-10-14
**Target System**: CT202 (n8n) on AGLSRV1 Proxmox
**Created By**: Hive Mind Analyst Agent
**Swarm ID**: swarm-1760460937973-ir3itqrv5

### Documentation Sizes
- Quick Reference: 7.1 KB
- Comprehensive Strategy: 26 KB
- Implementation Summary: 19 KB
- This Index: < 5 KB
- **Total**: ~57 KB (text-based, highly portable)

### Script Sizes
- Diagnostic Script: 4.1 KB
- Baseline Monitor: 1.4 KB
- Support Bundle Creator: 3.4 KB
- **Total**: 8.9 KB

---

## Next Steps

### Immediate (Within 24 hours)
1. [ ] Review Quick Reference document
2. [ ] Test diagnostic script execution
3. [ ] Verify CT202 container accessibility
4. [ ] Familiarize with emergency commands

### Short-term (Within 1 week)
1. [ ] Setup baseline monitoring (cron job)
2. [ ] Read Comprehensive Strategy (sections relevant to your role)
3. [ ] Create command aliases for quick access
4. [ ] Test support bundle creation

### Ongoing
1. [ ] Review baseline metrics weekly
2. [ ] Update documentation based on incidents
3. [ ] Conduct quarterly framework review
4. [ ] Provide feedback for continuous improvement

---

## Support and Feedback

### For Questions
- Review appropriate documentation section first
- Check common scenarios in this index
- Escalate per matrix in Comprehensive Strategy

### For Documentation Updates
- Note discrepancies or missing information
- Suggest improvements based on real-world usage
- Contribute incident learnings

### For Tool Enhancement
- Report bugs or unexpected behavior
- Suggest new diagnostic checks
- Share optimization ideas

---

## License and Usage

**Intended Audience**: AGLSRV1 system administrators and support team

**Usage Rights**: Internal use for CT202 container management and troubleshooting

**Modification**: Encouraged - adapt to specific needs and environment

**Distribution**: Share with team members and stakeholders as needed

---

**Last Updated**: 2025-10-14
**Maintained By**: Infrastructure Team
**Review Schedule**: Quarterly or post-incident
