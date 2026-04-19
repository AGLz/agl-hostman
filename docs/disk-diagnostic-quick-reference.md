# Disk Diagnostic Framework - Quick Reference Guide

**Target System**: Proxmox Host 100.98.119.51
**Framework Version**: 1.0
**Last Updated**: 2025-10-04

---

## Quick Start (5 Minutes)

### Step 1: Run Complete Diagnostic Suite
```bash
# Execute comprehensive analysis
ssh root@100.98.119.51 "/root/host-admin/disk-diagnostic-suite.sh"

# Output: Full diagnostic report in /var/log/disk-diagnostics/
```

### Step 2: Interpret Risk Score
```
Risk Score    Level        Action Required           Timeline
──────────────────────────────────────────────────────────────
0-20          Minimal      Monitor only              30-90 days
21-40         Low          Plan replacement          7-30 days
41-60         Moderate     Schedule maintenance      24-48 hours
61-80         High         Urgent intervention       2-6 hours
81-100        Critical     EMERGENCY response        0-2 hours
```

### Step 3: Execute Recommended Actions
See Phase 6 output for prioritized action list.

---

## Error Classification Quick Reference

### Tier 1: I/O Errors (Hardware)
```bash
# Detection command
dmesg -T | grep -iE "(I/O error|failed command|Medium Error)" | tail -50

# Common patterns
- "I/O error.*reading"     → Bad sectors (30-60% recovery)
- "I/O error.*writing"     → Media failure (20-40% recovery)
- "timeout.*nvme"          → Cable/controller (70-85% recovery)
```

### Tier 2: SMART Failures (Predictive)
```bash
# Critical SMART attributes
smartctl -A /dev/sdX | grep -E "(Reallocated|Pending|Uncorrectable)"

# Critical thresholds
Attribute                    Warning    Critical    Action
────────────────────────────────────────────────────────────
Reallocated Sectors          >0         >10         Monitor → Replace
Current Pending Sectors      >0         >5          Immediate backup
Offline Uncorrectable        >0         >0          CRITICAL - Replace now
Temperature                  >55°C      >65°C       Cooling check
```

### Tier 3: ZFS Corruption (Data Integrity)
```bash
# Health check
zpool status -v

# Error patterns
- "cksum.*[1-9]"              → Scrub + verify
- "corrupted data"            → Stop writes, backup
- "UNAVAIL|FAULTED"           → Pool degraded mode
- "permanent.*error"          → Data loss confirmed
```

---

## Risk Calculation Formulas

### Overall Risk Score
```
Risk = (Hardware × 0.4) + (Data_Integrity × 0.3) + (Redundancy × 0.2) + (Age × 0.1)
```

### Hardware Score (0-100)
- Reallocated sectors: count × 5 (max 30 points)
- Pending sectors: count × 10 (max 40 points)
- Uncorrectable sectors: 50 points if >0
- Temperature: (temp - 55°C) × 2 if >55°C

### Data Integrity Score (0-100)
- Checksum errors: count × 10 (max 40 points)
- Read errors: count × 5 (max 30 points)
- Write errors: count × 8 (max 40 points)
- Permanent errors: 100 points (critical)

### Redundancy Score (0-100)
- ONLINE: 0 points
- DEGRADED: 50 points
- FAULTED: 90 points
- UNAVAIL: 100 points

---

## Decision Matrix

### Recovery vs Replacement

**Attempt Recovery If:**
- ✅ Error count < 10 in 24 hours
- ✅ SMART values recoverable
- ✅ No physical damage
- ✅ System stable under light load
- ✅ Redundancy provides safety

**Replace Immediately If:**
- ❌ Reallocated sectors > 10
- ❌ Pending sectors > 5
- ❌ Uncorrectable > 0
- ❌ Physical damage (clicking sounds)
- ❌ Multiple I/O errors per hour
- ❌ No redundancy + critical data

### Action Timeline by Risk Score

| Risk Score | Redundant Pool | Non-Redundant Pool | Action |
|------------|----------------|--------------------|-----------------------------------------|
| 0-20       | Monitor        | Monitor            | Schedule replacement (30-90 days) |
| 21-40      | 7-30 days      | 48-72 hours        | Backup + plan replacement |
| 41-60      | 24-48 hours    | 6-24 hours         | Emergency backup + schedule replacement |
| 61-80      | 2-6 hours      | 0-2 hours          | Stop non-critical VMs + replace |
| 81-100     | IMMEDIATE      | IMMEDIATE          | Emergency data extraction |

---

## Diagnostic Command Sequences

### Phase 1: Initial Triage (2 min)
```bash
# System status
zpool list -o name,health,size
lsblk -o NAME,SIZE,TYPE,STATE

# Recent errors
dmesg -T -l err | tail -20
```

### Phase 2: SMART Analysis (5 min)
```bash
# All disks
for disk in /dev/sd?; do
    echo "=== $disk ==="
    smartctl -H $disk
    smartctl -A $disk | grep -E "(5|197|198)"
done
```

### Phase 3: ZFS Integrity (10 min)
```bash
# Pool health
for pool in $(zpool list -H -o name); do
    zpool status -v $pool
    zpool events | grep $pool | tail -20
done
```

### Phase 4: Performance Impact (5 min)
```bash
# I/O statistics
iostat -xm 1 3

# Disk latency
for disk in /dev/sd?; do
    iostat -dx $disk 1 3 | tail -2
done
```

### Phase 5: Data Loss Risk (5 min)
```bash
# Snapshot inventory
zfs list -t snapshot | wc -l

# Backup status
ls -lth /var/lib/vz/dump/*.vma* | head -5

# Redundancy check
zpool status | grep -E "(mirror|raidz|state:)"
```

---

## Emergency Response Procedures

### Critical Failure Detected (Risk > 80)

**Immediate Actions (0-30 min):**
```bash
# 1. Create emergency snapshots
for pool in $(zpool list -H -o name); do
    zfs snapshot -r ${pool}@emergency-$(date +%Y%m%d-%H%M%S)
done

# 2. Stop non-critical VMs
pvesh get /cluster/resources --type vm | jq -r '.[] | select(.status=="running" and .name!="critical") | .vmid' | \
    xargs -I {} qm stop {}

# 3. Reduce I/O load
echo 1 > /sys/module/zfs/parameters/zfs_prefetch_disable
```

**Urgent Actions (30-120 min):**
```bash
# 4. Backup critical data
vzdump <critical-vmid> --storage <backup-storage> --mode snapshot

# 5. Prepare replacement disk
# - Order hardware (same model/capacity)
# - Verify compatibility
# - Schedule maintenance window

# 6. Test backup integrity
qmrestore <backup-file> <test-vmid> --storage <storage>
```

### Degraded Pool Recovery

**DEGRADED state (1 failed disk in mirror/raidz):**
```bash
# 1. Identify failed disk
zpool status <pool> | grep -E "(UNAVAIL|FAULTED)"

# 2. Replace disk (if hot-swappable)
zpool replace <pool> <old-disk> <new-disk>

# 3. Monitor resilver
watch -n 10 'zpool status <pool> | grep -A 2 resilver'
```

**FAULTED state (multiple failures):**
```bash
# 1. DO NOT attempt online repair
# 2. Boot from rescue media if needed
# 3. Attempt pool import with missing devices:
zpool import -m -N <pool>

# 4. Extract data to safe location
zfs send <pool>@snapshot | ssh <backup-host> zfs recv <safe-pool>
```

---

## Monitoring Dashboard Setup

### Install Continuous Monitoring
```bash
# Deploy monitoring script
wget -O /usr/local/bin/disk-health-monitor.sh \
    https://raw.githubusercontent.com/yourusername/disk-health-monitor.sh

chmod +x /usr/local/bin/disk-health-monitor.sh

# Add to crontab (every 5 minutes)
echo "*/5 * * * * /usr/local/bin/disk-health-monitor.sh" | crontab -

# Enable systemd service
systemctl enable disk-health-monitor.service
systemctl start disk-health-monitor.service
```

### Configure Alerting
```bash
# Edit configuration
vim /etc/disk-health-monitor.conf

# Set thresholds
alerting:
  email: admin@example.com
  thresholds:
    reallocated_sectors: 1
    pending_sectors: 1
    temperature: 55
    pool_degraded: true
```

### View Live Dashboard
```bash
# Terminal dashboard
watch -n 5 '/usr/local/bin/disk-health-monitor.sh'

# Web dashboard (if available)
http://100.98.119.51:9090/disk-health
```

---

## Common Scenarios & Solutions

### Scenario 1: Single Disk Showing Reallocated Sectors
```
Risk Score: 25-35 (LOW to MODERATE)
Redundancy: Mirror or RAIDZ
Timeline: 7-30 days

Actions:
1. Monitor daily with: smartctl -A /dev/sdX | grep Reallocated
2. Verify backups are current
3. Order replacement disk
4. Schedule maintenance window
5. Replace during low-usage period
```

### Scenario 2: ZFS Checksum Errors Detected
```
Risk Score: 40-60 (MODERATE)
Data Integrity: Compromised
Timeline: 24-48 hours

Actions:
1. Identify affected files: zpool status -v <pool>
2. Restore from backup if critical
3. Run scrub: zpool scrub <pool>
4. Monitor: watch -n 10 'zpool status'
5. Investigate root cause (disk vs. memory)
```

### Scenario 3: Pool DEGRADED After Disk Failure
```
Risk Score: 50-70 (MODERATE to HIGH)
Redundancy: Reduced
Timeline: 2-24 hours

Actions:
1. Assess remaining redundancy
2. Stop non-critical VMs immediately
3. Create emergency snapshots
4. Replace failed disk ASAP
5. Monitor resilver progress
6. Verify scrub after resilver completes
```

### Scenario 4: Multiple Disks Failing (FAULTED Pool)
```
Risk Score: 90-100 (CRITICAL)
Data Loss Risk: IMMINENT
Timeline: IMMEDIATE (0-2 hours)

Actions:
1. DO NOT reboot or write to pool
2. Attempt read-only import: zpool import -o readonly=on <pool>
3. Extract critical data immediately
4. Prepare for complete rebuild
5. Restore from backups
6. Investigate root cause (controller, power, etc.)
```

---

## Maintenance Best Practices

### Proactive Monitoring
- [ ] Daily: Review dashboard for alerts
- [ ] Weekly: Check SMART trends
- [ ] Monthly: Run full diagnostic suite
- [ ] Quarterly: Test disaster recovery
- [ ] Annually: Replace disks >4 years old

### Backup Verification
- [ ] Daily: Verify backup completion
- [ ] Weekly: Test restore of 1 VM
- [ ] Monthly: Full disaster recovery test
- [ ] Quarterly: Offsite backup verification

### Capacity Planning
- [ ] Monitor disk usage trends
- [ ] Plan for 20% free space minimum
- [ ] Replace before 80% capacity
- [ ] Consider expansion at 70% usage

---

## Critical Files & Locations

### Framework Files
```
/root/host-admin/claudedocs/disk-failure-diagnostic-framework.md  # Main framework
/root/host-admin/disk-diagnostic-suite.sh                         # Diagnostic tool
/usr/local/bin/disk-health-monitor.sh                             # Monitoring daemon
/etc/disk-health-monitor.conf                                     # Configuration
```

### Report Locations
```
/var/log/disk-diagnostics/diagnostic-report-*.txt                 # Diagnostic reports
/var/log/disk-health-alerts.log                                   # Alert history
/var/lib/disk-metrics/health-trend.csv                            # Trend data
```

### Emergency Scripts
```
/root/emergency-backup.sh          # Quick backup script
/root/pool-recovery.sh             # Pool recovery procedures
/root/disk-replacement.sh          # Disk replacement guide
```

---

## Support & Escalation

### Level 1: Automated Response (Risk 0-40)
- Monitoring system generates alerts
- Follow standard procedures
- Document in ticket system

### Level 2: Manual Intervention (Risk 41-60)
- On-call engineer assessment
- Schedule maintenance window
- Coordinate with team

### Level 3: Emergency Response (Risk 61-100)
- Immediate escalation to senior team
- Execute emergency procedures
- Notify stakeholders
- All-hands response if data loss risk

### Contacts
- **Primary**: Infrastructure Team (infrastructure@example.com)
- **Secondary**: Senior SysAdmin (admin@example.com)
- **Emergency**: On-call phone line
- **Vendor Support**: Proxmox Forum, Disk Manufacturer

---

## Appendix: One-Line Commands

### Quick Health Check
```bash
# All-in-one status
zpool list && zpool status && smartctl --scan && for d in /dev/sd?; do smartctl -H $d | grep -E "(overall-health|PASSED|FAILED)"; done
```

### Emergency Snapshot All Pools
```bash
# Create emergency recovery points
for p in $(zpool list -H -o name); do zfs snapshot -r ${p}@emergency-$(date +%Y%m%d-%H%M%S); done
```

### List All Errors
```bash
# Comprehensive error summary
dmesg -T | grep -iE "(error|fail|warn)" | grep -iE "(disk|scsi|ata|nvme|zfs)" | tail -50
```

### Export Full Diagnostic
```bash
# Generate complete system report
/root/host-admin/disk-diagnostic-suite.sh 2>&1 | tee /tmp/full-diagnostic-$(date +%Y%m%d).txt
```

---

**Document Version**: 1.0
**Last Review**: 2025-10-04
**Next Review**: 2026-01-04

**For detailed information, refer to the complete framework:**
`/root/host-admin/claudedocs/disk-failure-diagnostic-framework.md`
