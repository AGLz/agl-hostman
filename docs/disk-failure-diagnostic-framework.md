# Disk Failure Diagnostic Framework for Proxmox Host 100.98.119.51

**Framework Version**: 1.0
**Target System**: Proxmox VE @ 100.98.119.51
**Created**: 2025-10-04
**Purpose**: Systematic approach to diagnosing, assessing, and responding to disk failures

---

## Executive Summary

This framework provides a systematic, evidence-based methodology for diagnosing disk failures on Proxmox infrastructure. It integrates error classification, risk scoring, decision matrices, and monitoring strategies to guide recovery decisions while minimizing data loss risk.

**Key Components**:
- 5-tier error classification system
- Quantitative risk scoring methodology (0-100 scale)
- Decision matrix for recovery vs replacement
- 6-phase diagnostic command sequence
- Real-time health monitoring dashboard

---

## 1. Error Classification System

### 1.1 Classification Taxonomy

#### Tier 1: I/O Errors (Hardware Level)
**Severity Range**: Medium to Critical
**Detection Sources**: dmesg, kernel logs, block device statistics

| Error Type | Pattern | Severity | Typical Cause | Recovery Probability |
|------------|---------|----------|---------------|---------------------|
| Read Error | `I/O error.*reading` | High | Bad sectors, head crash | 30-60% |
| Write Error | `I/O error.*writing` | Critical | Media failure, controller | 20-40% |
| Timeout Error | `timeout.*scsi\|nvme` | Medium | Cable, controller, firmware | 70-85% |
| DMA Error | `DMA.*error\|transfer` | High | Bus issues, controller | 50-70% |
| Sense Error | `Sense Key.*Medium Error` | High | Physical media damage | 20-50% |

**Detection Command**:
```bash
# I/O error detection
dmesg -T | grep -iE "(I/O error|failed command|Medium Error)" | tail -50
```

#### Tier 2: SMART Failures (Predictive)
**Severity Range**: Low to Critical
**Detection Sources**: smartctl, smartd daemon

| SMART Attribute | ID | Threshold Alert | Critical Value | Action Required |
|-----------------|----|--------------------|----------------|-----------------|
| Reallocated Sectors | 5 | >0 | >10 | Monitor → Replace |
| Current Pending Sectors | 197 | >0 | >5 | Immediate attention |
| Offline Uncorrectable | 198 | >0 | >0 | Critical backup |
| UDMA CRC Errors | 199 | >100 | >1000 | Cable/controller check |
| Temperature | 194 | >55°C | >65°C | Cooling intervention |
| Spin Retry Count | 10 | >0 | >3 | Imminent failure |
| Command Timeout | 188 | >0 | >100 | Replace immediately |

**Detection Command**:
```bash
# SMART comprehensive check
for disk in $(lsblk -d -o NAME -n | grep -E "sd|nvme"); do
    echo "=== /dev/$disk ==="
    smartctl -A /dev/$disk | grep -E "(Reallocated|Pending|Uncorrectable|Temperature|Error)"
    smartctl -l error /dev/$disk | head -20
done
```

#### Tier 3: ZFS Corruption (Data Integrity)
**Severity Range**: Medium to Critical
**Detection Sources**: zpool status, zpool events, checksum verification

| ZFS Event Type | Pattern | Data Loss Risk | Immediate Action |
|----------------|---------|----------------|------------------|
| Checksum Error | `cksum.*[1-9]` | Medium | Scrub + verify |
| Data Corruption | `corrupted data` | High | Stop writes, backup |
| Metadata Corruption | `metadata.*corrupt` | Critical | Immediate backup |
| Device Unavailable | `UNAVAIL\|FAULTED` | Critical | Pool degraded mode |
| Permanent Error | `permanent.*error` | Critical | Data loss confirmed |

**Detection Command**:
```bash
# ZFS comprehensive health check
zpool status -v
zpool list -v
zpool events | grep -E "(checksum|corrupt|DEGRADED|UNAVAIL)"
zfs get all | grep -E "(error|corruption)"
```

#### Tier 4: Filesystem Errors (Logical)
**Severity Range**: Low to High
**Detection Sources**: fsck, filesystem logs, mount errors

| Filesystem Error | Detection Pattern | Data Risk | Recovery Method |
|------------------|-------------------|-----------|-----------------|
| Superblock Corruption | `bad superblock` | High | Alternate superblock |
| Inode Corruption | `bad inode\|inode.*error` | Medium | fsck repair |
| Journal Errors | `journal.*error\|abort` | Medium | Journal replay |
| Mount Failures | `mount.*failed` | Variable | fsck + mount analysis |

**Detection Command**:
```bash
# Filesystem error detection
journalctl -k -p err | grep -E "(ext4|xfs|zfs|filesystem)"
dmesg -T | grep -E "(EXT4-fs|XFS|filesystem)"
```

#### Tier 5: Controller/Interface Errors
**Severity Range**: Low to Critical
**Detection Sources**: PCIe logs, controller firmware logs, system messages

| Controller Issue | Symptom Pattern | Scope | Diagnosis Method |
|------------------|-----------------|-------|------------------|
| PCIe Link Error | `AER.*error\|link.*down` | All devices on bus | lspci -vv analysis |
| SAS/SATA Timeout | `ata.*timeout\|sas.*error` | Single channel | Cable + controller |
| NVMe Timeout | `nvme.*timeout\|controller` | NVMe devices | nvme-cli diagnostics |
| RAID Controller | `megaraid\|hpsa.*error` | All array disks | Controller logs |

**Detection Command**:
```bash
# Controller diagnostics
lspci -vv | grep -A 10 "RAID\|SATA\|SAS\|NVMe"
dmesg -T | grep -iE "(ata[0-9]|nvme[0-9]|ahci|controller)"
nvme list && nvme smart-log /dev/nvme0 2>/dev/null || echo "NVMe not present"
```

### 1.2 Error Severity Matrix

| Classification Level | Severity Score | Urgency | Typical Response Time |
|---------------------|----------------|---------|----------------------|
| Level 0: Informational | 0-20 | None | Monitor only |
| Level 1: Warning | 21-40 | Low | 7-30 days |
| Level 2: Degraded | 41-60 | Medium | 24-72 hours |
| Level 3: Critical | 61-80 | High | 2-24 hours |
| Level 4: Emergency | 81-100 | Immediate | 0-2 hours |

---

## 2. Risk Scoring Methodology

### 2.1 Risk Score Calculation

**Risk Score Formula**:
```
Risk Score = (Hardware_Score × 0.4) + (Data_Integrity_Score × 0.3) +
             (Redundancy_Score × 0.2) + (Age_Score × 0.1)
```

### 2.2 Component Scoring Metrics

#### Hardware Health Score (0-100)
```python
def calculate_hardware_score(disk_stats):
    score = 0

    # SMART attribute evaluation
    if disk_stats['reallocated_sectors'] > 0:
        score += min(disk_stats['reallocated_sectors'] * 5, 30)

    if disk_stats['pending_sectors'] > 0:
        score += min(disk_stats['pending_sectors'] * 10, 40)

    if disk_stats['offline_uncorrectable'] > 0:
        score += 50  # Critical indicator

    # I/O error rate (per 1000 operations)
    io_error_rate = disk_stats['io_errors'] / max(disk_stats['total_io'], 1) * 1000
    score += min(io_error_rate * 2, 20)

    # Temperature penalty
    if disk_stats['temperature'] > 55:
        score += (disk_stats['temperature'] - 55) * 2

    return min(score, 100)
```

#### Data Integrity Score (0-100)
```python
def calculate_data_integrity_score(zfs_stats):
    score = 0

    # Checksum errors
    if zfs_stats['checksum_errors'] > 0:
        score += min(zfs_stats['checksum_errors'] * 10, 40)

    # Read/Write errors
    score += min(zfs_stats['read_errors'] * 5, 30)
    score += min(zfs_stats['write_errors'] * 8, 40)

    # Permanent errors (critical)
    if zfs_stats['permanent_errors'] > 0:
        score = 100  # Automatic critical

    return min(score, 100)
```

#### Redundancy Score (0-100)
```python
def calculate_redundancy_score(pool_config):
    score = 0

    # Pool health state
    if pool_config['state'] == 'DEGRADED':
        score += 50
    elif pool_config['state'] == 'FAULTED':
        score += 90
    elif pool_config['state'] == 'UNAVAIL':
        score = 100

    # Device redundancy level
    if pool_config['raid_type'] == 'mirror':
        available_mirrors = pool_config['available_devices'] / 2
        if available_mirrors < pool_config['required_mirrors']:
            score += 40

    elif pool_config['raid_type'] == 'raidz1':
        # Can tolerate 1 disk failure
        failed_devices = pool_config['total_devices'] - pool_config['available_devices']
        if failed_devices >= 1:
            score += 60

    elif pool_config['raid_type'] == 'raidz2':
        # Can tolerate 2 disk failures
        failed_devices = pool_config['total_devices'] - pool_config['available_devices']
        if failed_devices >= 2:
            score += 70

    # No redundancy (stripe/single disk)
    if pool_config['raid_type'] == 'stripe':
        score = 90  # Any failure is critical

    return min(score, 100)
```

#### Age/Wear Score (0-100)
```python
def calculate_age_score(disk_metadata):
    score = 0

    # Power-on hours (assuming 5-year lifespan = 43800 hours)
    age_ratio = disk_metadata['power_on_hours'] / 43800
    score += min(age_ratio * 30, 30)

    # Write endurance for SSDs (TBW - Total Bytes Written)
    if disk_metadata['disk_type'] == 'SSD':
        wear_ratio = disk_metadata['total_writes_tb'] / disk_metadata['rated_tbw']
        score += min(wear_ratio * 50, 50)

    # Load cycle count for HDDs
    if disk_metadata['disk_type'] == 'HDD':
        if disk_metadata['load_cycles'] > 300000:
            score += 20

    return min(score, 100)
```

### 2.3 Risk Categories

| Risk Score Range | Category | Description | Business Impact |
|------------------|----------|-------------|-----------------|
| 0-20 | Minimal | Normal operation | None |
| 21-40 | Low | Early warning signs | Plan replacement |
| 41-60 | Moderate | Degraded performance | Schedule maintenance |
| 61-80 | High | Failure imminent | Urgent backup + replace |
| 81-100 | Critical | Failure in progress | Emergency response |

---

## 3. Decision Matrix for Recovery Actions

### 3.1 Decision Tree

```
START: Disk Issue Detected
│
├─ Is system bootable?
│  ├─ YES: Continue to health assessment
│  └─ NO: Emergency recovery mode
│     ├─ Boot from rescue media
│     ├─ Assess pool import capability
│     └─ Determine data extraction method
│
├─ Risk Score Calculation
│  ├─ Score 0-40: Monitoring path
│  ├─ Score 41-60: Degraded operation path
│  ├─ Score 61-80: Urgent intervention path
│  └─ Score 81-100: Emergency path
│
├─ Data Redundancy Status?
│  ├─ Redundant (RAID/Mirror): Graceful degradation
│  ├─ Non-redundant: Immediate backup
│  └─ Already degraded: Critical backup
│
├─ Data Criticality Assessment
│  ├─ Production VMs: High priority
│  ├─ Development/Test: Medium priority
│  └─ Archival/Backup: Low priority
│
└─ Action Decision
   ├─ MONITOR: Schedule replacement
   ├─ BACKUP: Emergency backup → Replace
   ├─ MIGRATE: Live migration → Replace
   └─ RECOVER: Data extraction → Rebuild
```

### 3.2 Action Decision Matrix

| Risk Score | Redundancy | Data Loss Risk | Recommended Action | Timeline |
|------------|------------|----------------|-------------------|----------|
| 0-20 | Any | Minimal | Monitor + plan replacement | 30-90 days |
| 21-40 | Redundant | Low | Schedule maintenance window | 7-30 days |
| 21-40 | None | Medium | Immediate backup + replace | 48-72 hours |
| 41-60 | Redundant | Medium | Backup + replace during window | 24-48 hours |
| 41-60 | None | High | Emergency backup + replace | 6-24 hours |
| 61-80 | Redundant | High | Stop non-critical VMs + replace | 2-6 hours |
| 61-80 | None | Critical | Immediate backup + migrate | 0-2 hours |
| 81-100 | Any | Critical | Emergency data extraction | Immediate |

### 3.3 Recovery vs Replacement Decision Criteria

#### Attempt Recovery If:
- ✅ Error count < 10 in 24 hours
- ✅ SMART values within recoverable range
- ✅ No physical damage indicators
- ✅ Filesystem corruption is logical only
- ✅ System remains stable under light load
- ✅ Data redundancy provides safety net

#### Replace Immediately If:
- ❌ Reallocated sectors > 10
- ❌ Current pending sectors > 5
- ❌ Offline uncorrectable > 0
- ❌ Physical damage (clicking, grinding sounds)
- ❌ Multiple I/O errors per hour
- ❌ No redundancy and critical data
- ❌ Device showing UNAVAIL/FAULTED in ZFS

---

## 4. Diagnostic Command Sequence

### Phase 1: Initial Assessment (2-5 minutes)

**Objective**: Rapid triage to determine severity and system stability

```bash
#!/bin/bash
# Phase 1: Initial disk failure assessment
# Run on: 100.98.119.51

echo "=== PHASE 1: INITIAL ASSESSMENT ==="
date

# 1.1 System availability check
echo -e "\n[1.1] System Status:"
uptime
systemctl is-system-running 2>/dev/null || echo "DEGRADED MODE"

# 1.2 Quick disk overview
echo -e "\n[1.2] Block Device Overview:"
lsblk -o NAME,SIZE,TYPE,MOUNTPOINT,MODEL,STATE,PHY-SEC,LOG-SEC

# 1.3 ZFS pool quick status
echo -e "\n[1.3] ZFS Pool Health:"
zpool list -H -o name,health,size,allocated,free
for pool in $(zpool list -H -o name); do
    echo "Pool: $pool"
    zpool status $pool | grep -E "(state:|errors:|READ|WRITE|CKSUM)"
done

# 1.4 Recent kernel errors
echo -e "\n[1.4] Recent Critical Errors (last 50):"
dmesg -T -l err,crit,alert,emerg | tail -50

# 1.5 I/O error summary
echo -e "\n[1.5] I/O Error Summary:"
grep -r "" /sys/block/*/device/ioerr_cnt 2>/dev/null || echo "No I/O error counters"

echo -e "\n=== PHASE 1 COMPLETE ==="
echo "Next: Review output and proceed to Phase 2 if issues detected"
```

### Phase 2: Detailed Hardware Analysis (5-10 minutes)

**Objective**: Comprehensive hardware health assessment

```bash
#!/bin/bash
# Phase 2: Detailed hardware diagnostics
# Run on: 100.98.119.51

echo "=== PHASE 2: HARDWARE DIAGNOSTICS ==="
date

# 2.1 SMART health check for all disks
echo -e "\n[2.1] SMART Health Check:"
for disk in $(lsblk -d -o NAME -n | grep -E "^sd|^nvme"); do
    echo -e "\n--- /dev/$disk ---"
    smartctl -H /dev/$disk
    smartctl -A /dev/$disk | grep -E "(^  5|^ 10|^188|^194|^197|^198|^199)"
    smartctl -l error /dev/$disk | grep -E "(Error [0-9]|Error Count)" | head -5

    # NVMe specific
    if [[ $disk == nvme* ]]; then
        nvme smart-log /dev/$disk 2>/dev/null | grep -E "(percentage_used|available_spare|critical_warning)"
    fi
done

# 2.2 Disk I/O statistics
echo -e "\n[2.2] Disk I/O Statistics:"
iostat -x 2 3 | grep -E "(Device|sd|nvme)"

# 2.3 Controller and interface health
echo -e "\n[2.3] Storage Controller Status:"
lspci -vv | grep -A 15 "RAID\|SATA\|SAS\|NVMe controller"

# 2.4 PCIe AER errors
echo -e "\n[2.4] PCIe Advanced Error Reporting:"
dmesg | grep -i "AER" | tail -20

# 2.5 Temperature monitoring
echo -e "\n[2.5] Temperature Status:"
sensors 2>/dev/null || echo "lm-sensors not configured"
for disk in /dev/sd? /dev/nvme?; do
    [ -e "$disk" ] && smartctl -A $disk | grep -i temperature
done

echo -e "\n=== PHASE 2 COMPLETE ==="
```

### Phase 3: ZFS Data Integrity Analysis (10-15 minutes)

**Objective**: Assess ZFS-specific health and data integrity

```bash
#!/bin/bash
# Phase 3: ZFS data integrity analysis
# Run on: 100.98.119.51

echo "=== PHASE 3: ZFS INTEGRITY ANALYSIS ==="
date

# 3.1 Detailed pool status
echo -e "\n[3.1] Detailed Pool Status:"
for pool in $(zpool list -H -o name); do
    echo -e "\n╔═══ Pool: $pool ═══╗"
    zpool status -v $pool
    echo -e "\n--- Pool Properties ---"
    zpool get all $pool | grep -E "(health|allocated|fragmentation|dedupratio)"
done

# 3.2 ZFS error counters
echo -e "\n[3.2] ZFS Error Statistics:"
zpool status | grep -E "errors:|READ|WRITE|CKSUM" | grep -v "errors: No known"

# 3.3 ZFS event log analysis
echo -e "\n[3.3] Recent ZFS Events (last 50):"
zpool events | tail -50 | grep -E "(ereport|checksum|io|raid)"

# 3.4 Dataset health
echo -e "\n[3.4] Dataset Integrity:"
zfs list -t filesystem -o name,used,available,referenced,mountpoint,compression,checksum

# 3.5 Scrub history
echo -e "\n[3.5] Scrub History:"
for pool in $(zpool list -H -o name); do
    echo "Pool: $pool"
    zpool history $pool | grep scrub | tail -5
done

# 3.6 Check for pool degradation
echo -e "\n[3.6] Pool Degradation Check:"
zpool list -H -o name,health | while read pool health; do
    if [ "$health" != "ONLINE" ]; then
        echo "⚠️  WARNING: Pool $pool is $health"
        zpool status $pool | grep -A 5 "state:"
    fi
done

echo -e "\n=== PHASE 3 COMPLETE ==="
```

### Phase 4: Performance Impact Assessment (5-10 minutes)

**Objective**: Measure impact on system performance

```bash
#!/bin/bash
# Phase 4: Performance impact assessment
# Run on: 100.98.119.51

echo "=== PHASE 4: PERFORMANCE ASSESSMENT ==="
date

# 4.1 Current I/O load
echo -e "\n[4.1] Current I/O Load:"
iostat -xm 1 5

# 4.2 Disk latency analysis
echo -e "\n[4.2] Disk Latency (ms):"
for disk in $(lsblk -d -o NAME -n | grep -E "^sd|^nvme"); do
    echo "Device: /dev/$disk"
    iostat -dx /dev/$disk 1 3 | grep $disk | awk '{print "  Avg Wait: " $10 "ms | Service Time: " $11 "ms"}'
done

# 4.3 ZFS ARC statistics
echo -e "\n[4.3] ZFS ARC Performance:"
arcstat 1 5 2>/dev/null || echo "arcstat not available, using arc_summary"
arc_summary 2>/dev/null | grep -E "(Hit Rate|Miss Rate|ARC Size)" || echo "arc_summary not available"

# 4.4 VM/CT impact analysis
echo -e "\n[4.4] VM/Container I/O Impact:"
pvesh get /cluster/resources --type vm --output-format json | \
    jq -r '.[] | select(.status=="running") | "\(.vmid): \(.name) - Disk: \(.disk/1073741824)GB"'

# 4.5 Slow I/O operations
echo -e "\n[4.5] Slow I/O Operations (>100ms):"
cat /sys/kernel/debug/block/*/hd*/dispatch 2>/dev/null || echo "Debug interface not available"

echo -e "\n=== PHASE 4 COMPLETE ==="
```

### Phase 5: Data Loss Risk Evaluation (5 minutes)

**Objective**: Quantify potential data loss scenarios

```bash
#!/bin/bash
# Phase 5: Data loss risk evaluation
# Run on: 100.98.119.51

echo "=== PHASE 5: DATA LOSS RISK EVALUATION ==="
date

# 5.1 Identify unprotected data
echo -e "\n[5.1] Redundancy Status:"
for pool in $(zpool list -H -o name); do
    echo -e "\n--- Pool: $pool ---"
    zpool status $pool | grep -E "mirror|raidz|stripe"

    # Count failed/degraded devices
    failed_count=$(zpool status $pool | grep -c "UNAVAIL\|FAULTED\|DEGRADED")
    if [ $failed_count -gt 0 ]; then
        echo "⚠️  $failed_count device(s) in failed/degraded state"
    fi
done

# 5.2 Critical VM/CT identification
echo -e "\n[5.2] Critical Workloads on Affected Storage:"
pvesh get /cluster/resources --type vm --output-format json | \
    jq -r '.[] | select(.status=="running") | "VMID \(.vmid): \(.name) - Storage: \(.storage)"'

# 5.3 Backup status verification
echo -e "\n[5.3] Recent Backup Status:"
vzdump query-backup 2>/dev/null || echo "Checking PBS backups..."
pvesh get /nodes/$(hostname)/storage --output-format json | \
    jq -r '.[] | select(.type=="pbs") | .storage'

# 5.4 Snapshot inventory
echo -e "\n[5.4] Available ZFS Snapshots (Recovery Points):"
for pool in $(zpool list -H -o name); do
    snap_count=$(zfs list -t snapshot -o name | grep "^$pool" | wc -l)
    echo "Pool $pool: $snap_count snapshots"
    zfs list -t snapshot -o name,creation,used | grep "^$pool" | tail -10
done

# 5.5 Calculate exposure window
echo -e "\n[5.5] Data Exposure Analysis:"
for pool in $(zpool list -H -o name); do
    last_scrub=$(zpool history $pool | grep "scrub" | tail -1 | awk '{print $1, $2}')
    last_snap=$(zfs list -t snapshot -r $pool -o creation -s creation | tail -1)
    echo "Pool $pool:"
    echo "  Last scrub: $last_scrub"
    echo "  Latest snapshot: $last_snap"
done

echo -e "\n=== PHASE 5 COMPLETE ==="
```

### Phase 6: Comprehensive Reporting (2-3 minutes)

**Objective**: Generate actionable diagnostic report

```bash
#!/bin/bash
# Phase 6: Comprehensive diagnostic report
# Run on: 100.98.119.51

REPORT_FILE="/root/disk-diagnostic-report-$(date +%Y%m%d-%H%M%S).txt"

echo "=== PHASE 6: GENERATING COMPREHENSIVE REPORT ==="
date

{
    echo "╔═══════════════════════════════════════════════════════════════╗"
    echo "║  DISK FAILURE DIAGNOSTIC REPORT - Proxmox 100.98.119.51      ║"
    echo "║  Generated: $(date)                              ║"
    echo "╚═══════════════════════════════════════════════════════════════╝"
    echo ""

    # Executive Summary
    echo "EXECUTIVE SUMMARY"
    echo "================="

    # System health score calculation
    echo -e "\n[Overall System Health]"
    total_pools=$(zpool list -H | wc -l)
    healthy_pools=$(zpool list -H -o health | grep -c "ONLINE")
    echo "ZFS Pools: $healthy_pools/$total_pools healthy"

    failed_disks=$(lsblk -d -o NAME | while read disk; do
        smartctl -H /dev/$disk 2>/dev/null | grep -q "PASSED" || echo $disk
    done | wc -l)
    total_disks=$(lsblk -d | grep -c "disk")
    echo "Physical Disks: $(($total_disks - $failed_disks))/$total_disks healthy"

    # Critical issues
    echo -e "\n[Critical Issues Detected]"
    critical_count=0

    # Check for SMART failures
    for disk in $(lsblk -d -o NAME -n | grep -E "^sd|^nvme"); do
        smartctl -A /dev/$disk 2>/dev/null | grep -E "Reallocated_Sector|Current_Pending_Sector" | \
            awk '$NF > 0 {print "⚠️  /dev/'$disk': " $2 " = " $NF; critical++}'
    done

    # Check for ZFS errors
    zpool status | grep -E "state: DEGRADED|state: FAULTED" && ((critical_count++))

    if [ $critical_count -eq 0 ]; then
        echo "✅ No critical issues detected"
    else
        echo "❌ $critical_count critical issue(s) require immediate attention"
    fi

    # Risk score (simplified calculation)
    echo -e "\n[Risk Assessment]"
    risk_score=0
    [ $failed_disks -gt 0 ] && ((risk_score+=30))
    [ $healthy_pools -lt $total_pools ] && ((risk_score+=40))
    [ $critical_count -gt 0 ] && ((risk_score+=30))

    echo "Overall Risk Score: $risk_score/100"
    if [ $risk_score -lt 20 ]; then
        echo "Risk Level: MINIMAL - Monitor only"
    elif [ $risk_score -lt 40 ]; then
        echo "Risk Level: LOW - Plan replacement"
    elif [ $risk_score -lt 60 ]; then
        echo "Risk Level: MODERATE - Schedule maintenance"
    elif [ $risk_score -lt 80 ]; then
        echo "Risk Level: HIGH - Urgent intervention required"
    else
        echo "Risk Level: CRITICAL - Emergency response required"
    fi

    # Recommendations
    echo -e "\n[Recommended Actions]"
    if [ $risk_score -ge 60 ]; then
        echo "1. ⚠️  IMMEDIATE: Create emergency backup/snapshot"
        echo "2. ⚠️  URGENT: Schedule replacement within 24-48 hours"
        echo "3. ⚠️  Stop non-critical VMs to reduce I/O load"
    elif [ $risk_score -ge 40 ]; then
        echo "1. Schedule maintenance window within 7 days"
        echo "2. Verify backup integrity"
        echo "3. Order replacement hardware"
    else
        echo "1. Continue monitoring"
        echo "2. Plan proactive replacement"
        echo "3. Verify backup schedules"
    fi

    echo -e "\n═══════════════════════════════════════════════════════════════"
    echo "Full diagnostic data collected in phases 1-5"
    echo "Report saved to: $REPORT_FILE"
    echo "═══════════════════════════════════════════════════════════════"

} | tee "$REPORT_FILE"

echo ""
echo "✅ Comprehensive diagnostic report generated: $REPORT_FILE"
echo "=== PHASE 6 COMPLETE ==="
```

---

## 5. Health Monitoring Dashboard Design

### 5.1 Real-Time Monitoring Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                  DISK HEALTH MONITORING DASHBOARD            │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌────────────────┐  ┌────────────────┐  ┌────────────────┐ │
│  │  HARDWARE      │  │  ZFS POOLS     │  │  PERFORMANCE   │ │
│  │  HEALTH        │  │  STATUS        │  │  METRICS       │ │
│  ├────────────────┤  ├────────────────┤  ├────────────────┤ │
│  │ • SMART Status │  │ • Pool Health  │  │ • IOPS         │ │
│  │ • Temperature  │  │ • Scrub Status │  │ • Latency      │ │
│  │ • I/O Errors   │  │ • Checksum Err │  │ • Throughput   │ │
│  │ • Reallocated  │  │ • Resilver %   │  │ • Queue Depth  │ │
│  └────────────────┘  └────────────────┘  └────────────────┘ │
│                                                              │
│  ┌───────────────────────────────────────────────────────┐  │
│  │                   ALERT SUMMARY                        │  │
│  ├───────────────────────────────────────────────────────┤  │
│  │  🔴 Critical (0)  🟡 Warnings (2)  🟢 Healthy (12)     │  │
│  └───────────────────────────────────────────────────────┘  │
│                                                              │
│  ┌───────────────────────────────────────────────────────┐  │
│  │                 RECENT EVENTS (Last 24h)               │  │
│  ├───────────────────────────────────────────────────────┤  │
│  │ 14:32 - sda: 1 reallocated sector detected            │  │
│  │ 12:15 - rpool: scrub completed, 0 errors              │  │
│  │ 09:47 - nvme0: temperature 58°C (warning threshold)   │  │
│  └───────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

### 5.2 Monitoring Script Implementation

```bash
#!/bin/bash
# Disk Health Monitoring Dashboard
# Location: /usr/local/bin/disk-health-monitor.sh
# Cron: */5 * * * * /usr/local/bin/disk-health-monitor.sh

ALERT_LOG="/var/log/disk-health-alerts.log"
METRICS_DIR="/var/lib/disk-metrics"
ALERT_EMAIL="admin@example.com"
WEBHOOK_URL=""  # Optional: Slack/Teams webhook

# Color codes for terminal output
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Initialize metrics directory
mkdir -p "$METRICS_DIR"

# Function: Check SMART health
check_smart_health() {
    local disk=$1
    local critical=0
    local warnings=0

    # Reallocated sectors
    reallocated=$(smartctl -A /dev/$disk | grep "Reallocated_Sector" | awk '{print $NF}')
    if [ "$reallocated" -gt 10 ]; then
        critical=1
        log_alert "CRITICAL" "$disk" "Reallocated sectors: $reallocated (>10)"
    elif [ "$reallocated" -gt 0 ]; then
        warnings=1
        log_alert "WARNING" "$disk" "Reallocated sectors: $reallocated"
    fi

    # Pending sectors
    pending=$(smartctl -A /dev/$disk | grep "Current_Pending_Sector" | awk '{print $NF}')
    if [ "$pending" -gt 5 ]; then
        critical=1
        log_alert "CRITICAL" "$disk" "Pending sectors: $pending (>5)"
    elif [ "$pending" -gt 0 ]; then
        warnings=1
        log_alert "WARNING" "$disk" "Pending sectors: $pending"
    fi

    # Temperature
    temp=$(smartctl -A /dev/$disk | grep "Temperature_Celsius" | awk '{print $NF}')
    if [ "$temp" -gt 65 ]; then
        critical=1
        log_alert "CRITICAL" "$disk" "Temperature: ${temp}°C (>65°C)"
    elif [ "$temp" -gt 55 ]; then
        warnings=1
        log_alert "WARNING" "$disk" "Temperature: ${temp}°C (>55°C)"
    fi

    echo "$critical:$warnings"
}

# Function: Check ZFS pool health
check_zfs_health() {
    local pool=$1
    local critical=0
    local warnings=0

    # Pool state
    state=$(zpool list -H -o health $pool)
    if [[ "$state" == "DEGRADED" ]]; then
        warnings=1
        log_alert "WARNING" "ZFS-$pool" "Pool is DEGRADED"
    elif [[ "$state" == "FAULTED" ]] || [[ "$state" == "UNAVAIL" ]]; then
        critical=1
        log_alert "CRITICAL" "ZFS-$pool" "Pool is $state"
    fi

    # Checksum errors
    cksum_errors=$(zpool status $pool | grep -E "^[[:space:]]*[0-9]+" | awk '{sum+=$5} END {print sum}')
    if [ "$cksum_errors" -gt 0 ]; then
        critical=1
        log_alert "CRITICAL" "ZFS-$pool" "Checksum errors detected: $cksum_errors"
    fi

    echo "$critical:$warnings"
}

# Function: Log alert
log_alert() {
    local severity=$1
    local device=$2
    local message=$3
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    echo "[$timestamp] [$severity] $device: $message" >> "$ALERT_LOG"

    # Send notification for critical alerts
    if [ "$severity" == "CRITICAL" ]; then
        send_notification "CRITICAL DISK ALERT" "$device: $message"
    fi
}

# Function: Send notification
send_notification() {
    local subject=$1
    local message=$2

    # Email notification
    if [ -n "$ALERT_EMAIL" ]; then
        echo "$message" | mail -s "$subject - Proxmox $(hostname)" "$ALERT_EMAIL"
    fi

    # Webhook notification (Slack/Teams)
    if [ -n "$WEBHOOK_URL" ]; then
        curl -X POST "$WEBHOOK_URL" -H 'Content-Type: application/json' \
            -d "{\"text\":\"$subject: $message\"}" 2>/dev/null
    fi
}

# Function: Display dashboard
display_dashboard() {
    clear
    echo "╔═══════════════════════════════════════════════════════════════╗"
    echo "║        DISK HEALTH MONITORING - $(hostname -f)        ║"
    echo "║                 $(date '+%Y-%m-%d %H:%M:%S')                  ║"
    echo "╚═══════════════════════════════════════════════════════════════╝"
    echo ""

    # Hardware Health Section
    echo "┌─────────────── HARDWARE HEALTH ───────────────┐"
    printf "%-15s %-10s %-10s %-12s %-10s\n" "Device" "SMART" "Temp" "Reallocated" "Pending"
    echo "├───────────────────────────────────────────────┤"

    total_critical=0
    total_warnings=0

    for disk in $(lsblk -d -o NAME -n | grep -E "^sd|^nvme"); do
        smart_health=$(smartctl -H /dev/$disk 2>/dev/null | grep -o "PASSED\|FAILED")
        temp=$(smartctl -A /dev/$disk 2>/dev/null | grep "Temperature_Celsius" | awk '{print $NF}')
        reallocated=$(smartctl -A /dev/$disk 2>/dev/null | grep "Reallocated_Sector" | awk '{print $NF}')
        pending=$(smartctl -A /dev/$disk 2>/dev/null | grep "Current_Pending_Sector" | awk '{print $NF}')

        # Health status with colors
        if [ "$smart_health" == "FAILED" ] || [ "$reallocated" -gt 10 ] || [ "$pending" -gt 5 ]; then
            status="${RED}CRITICAL${NC}"
            ((total_critical++))
        elif [ "$reallocated" -gt 0 ] || [ "$pending" -gt 0 ] || [ "$temp" -gt 55 ]; then
            status="${YELLOW}WARNING${NC}"
            ((total_warnings++))
        else
            status="${GREEN}HEALTHY${NC}"
        fi

        printf "%-15s %-10s %-10s %-12s %-10s %b\n" \
            "/dev/$disk" "$smart_health" "${temp}°C" "$reallocated" "$pending" "$status"
    done

    echo "└───────────────────────────────────────────────┘"
    echo ""

    # ZFS Pools Section
    echo "┌─────────────── ZFS POOL STATUS ───────────────┐"
    printf "%-15s %-10s %-12s %-10s\n" "Pool" "Health" "Capacity" "Scrub Age"
    echo "├───────────────────────────────────────────────┤"

    for pool in $(zpool list -H -o name); do
        health=$(zpool list -H -o health $pool)
        capacity=$(zpool list -H -o capacity $pool)
        scrub_age=$(zpool history $pool | grep scrub | tail -1 | awk '{print $1}')

        if [[ "$health" == "ONLINE" ]]; then
            health_color="${GREEN}$health${NC}"
        elif [[ "$health" == "DEGRADED" ]]; then
            health_color="${YELLOW}$health${NC}"
            ((total_warnings++))
        else
            health_color="${RED}$health${NC}"
            ((total_critical++))
        fi

        printf "%-15s %b %-12s %-10s\n" "$pool" "$health_color" "$capacity" "$scrub_age"
    done

    echo "└───────────────────────────────────────────────┘"
    echo ""

    # Alert Summary
    echo "┌─────────────── ALERT SUMMARY ─────────────────┐"
    printf "  🔴 Critical: %-3d   🟡 Warnings: %-3d   🟢 Healthy\n" $total_critical $total_warnings
    echo "└───────────────────────────────────────────────┘"
    echo ""

    # Recent Events
    echo "┌─────────────── RECENT EVENTS (Last 10) ───────────────┐"
    tail -10 "$ALERT_LOG" 2>/dev/null || echo "No recent alerts"
    echo "└────────────────────────────────────────────────────────┘"
}

# Main execution
main() {
    # Run health checks
    for disk in $(lsblk -d -o NAME -n | grep -E "^sd|^nvme"); do
        check_smart_health $disk > /dev/null
    done

    for pool in $(zpool list -H -o name); do
        check_zfs_health $pool > /dev/null
    done

    # Display dashboard
    display_dashboard

    # Store metrics for trending
    echo "$(date +%s),$(zpool list -H -o health | grep -c ONLINE),$(smartctl --scan | wc -l)" \
        >> "$METRICS_DIR/health-trend.csv"
}

# Run main function
main
```

### 5.3 Dashboard Installation

```bash
# Install monitoring dashboard
cat > /usr/local/bin/disk-health-monitor.sh << 'EOF'
[Script content from section 5.2]
EOF

chmod +x /usr/local/bin/disk-health-monitor.sh

# Add to crontab for automatic monitoring
(crontab -l 2>/dev/null; echo "*/5 * * * * /usr/local/bin/disk-health-monitor.sh >> /var/log/disk-health-monitor.log 2>&1") | crontab -

# Create systemd service for continuous monitoring
cat > /etc/systemd/system/disk-health-monitor.service << 'EOF'
[Unit]
Description=Disk Health Monitoring Service
After=zfs.target

[Service]
Type=simple
ExecStart=/usr/local/bin/disk-health-monitor.sh
Restart=always
RestartSec=300

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable disk-health-monitor.service
systemctl start disk-health-monitor.service
```

### 5.4 Alerting Thresholds Configuration

```yaml
# /etc/disk-health-monitor.conf
alerting:
  email:
    enabled: true
    recipients:
      - admin@example.com
      - ops-team@example.com
    smtp_server: localhost

  webhook:
    enabled: false
    url: "https://hooks.slack.com/services/YOUR/WEBHOOK/URL"

  thresholds:
    smart:
      reallocated_sectors:
        warning: 1
        critical: 10
      pending_sectors:
        warning: 1
        critical: 5
      temperature:
        warning: 55
        critical: 65
      offline_uncorrectable:
        warning: 0
        critical: 1

    zfs:
      pool_health:
        degraded: warning
        faulted: critical
      checksum_errors:
        warning: 1
        critical: 10
      scrub_age_days:
        warning: 30
        critical: 60

    performance:
      io_errors_per_hour:
        warning: 10
        critical: 50
      average_latency_ms:
        warning: 100
        critical: 500

  monitoring_interval: 300  # seconds
  retention_days: 90
```

---

## 6. Implementation Checklist

### Initial Setup (Day 1)
- [ ] Deploy diagnostic framework to `/root/host-admin/claudedocs/`
- [ ] Install monitoring dashboard script to `/usr/local/bin/`
- [ ] Configure alerting thresholds in `/etc/disk-health-monitor.conf`
- [ ] Set up email/webhook notifications
- [ ] Run Phase 1-6 diagnostics to establish baseline

### Ongoing Operations (Daily/Weekly)
- [ ] Review dashboard alerts daily
- [ ] Analyze weekly trend reports
- [ ] Verify backup integrity weekly
- [ ] Schedule scrubs for low-usage periods
- [ ] Update SMART baseline metrics monthly

### Emergency Response Procedures
- [ ] Maintain emergency contact list
- [ ] Keep replacement hardware specifications documented
- [ ] Test recovery procedures quarterly
- [ ] Update runbooks based on incidents
- [ ] Conduct disaster recovery drills biannually

---

## 7. Appendices

### Appendix A: Quick Reference Commands

```bash
# Quick health check (30 seconds)
zpool status && smartctl -a /dev/sda | grep -E "(SMART|Reallocated|Pending)"

# Emergency backup
zfs snapshot -r rpool@emergency-$(date +%Y%m%d-%H%M%S)

# Check for I/O errors
dmesg -T | grep -i "I/O error" | tail -20

# Monitor live disk activity
watch -n 2 'iostat -x 1 1'

# Export diagnostic data
/usr/local/bin/disk-health-monitor.sh > /tmp/disk-health-$(date +%Y%m%d).txt
```

### Appendix B: Risk Score Calculation Examples

**Example 1: Healthy System**
- Hardware Score: 5 (minimal wear)
- Data Integrity: 0 (no errors)
- Redundancy: 10 (mirror, all healthy)
- Age: 15 (2 years old)
- **Total Risk**: 5×0.4 + 0×0.3 + 10×0.2 + 15×0.1 = **5.5/100** (Minimal)

**Example 2: Warning State**
- Hardware Score: 35 (5 reallocated sectors)
- Data Integrity: 10 (2 checksum errors)
- Redundancy: 20 (mirror, healthy)
- Age: 25 (3.5 years old)
- **Total Risk**: 35×0.4 + 10×0.3 + 20×0.2 + 25×0.1 = **20.5/100** (Low)

**Example 3: Critical State**
- Hardware Score: 85 (pending sectors, high errors)
- Data Integrity: 60 (multiple checksum errors)
- Redundancy: 70 (degraded, 1 failed drive)
- Age: 40 (5 years old)
- **Total Risk**: 85×0.4 + 60×0.3 + 70×0.2 + 40×0.1 = **76/100** (High)

### Appendix C: Recovery Decision Flowchart

```
                     ┌─────────────────┐
                     │  Disk Error     │
                     │   Detected      │
                     └────────┬────────┘
                              │
                              ▼
                     ┌─────────────────┐
                     │ Run Phase 1-3   │
                     │  Diagnostics    │
                     └────────┬────────┘
                              │
                              ▼
                     ┌─────────────────┐
                     │ Calculate Risk  │
                     │     Score       │
                     └────────┬────────┘
                              │
                 ┌────────────┼────────────┐
                 │            │            │
                 ▼            ▼            ▼
         ┌───────────┐ ┌──────────┐ ┌──────────┐
         │ Score<40  │ │ 40-60    │ │ Score>60 │
         └─────┬─────┘ └────┬─────┘ └────┬─────┘
               │            │            │
               ▼            ▼            ▼
         ┌──────────┐ ┌──────────┐ ┌──────────┐
         │ Monitor  │ │ Backup + │ │Emergency │
         │ Schedule │ │ Schedule │ │ Backup + │
         │ Replace  │ │ Replace  │ │ Replace  │
         └──────────┘ └──────────┘ └────┬─────┘
                                         │
                                         ▼
                                  ┌──────────┐
                                  │  Verify  │
                                  │ Recovery │
                                  └──────────┘
```

---

## Document Control

**Version**: 1.0
**Last Updated**: 2025-10-04
**Next Review**: 2026-01-04
**Owner**: Infrastructure Team
**Classification**: Internal Use

**Revision History**:
- 1.0 (2025-10-04): Initial framework creation

---

**END OF FRAMEWORK**
