# Disk Forensic & Recovery Suite

Comprehensive diagnostic and recovery toolkit for Proxmox host 100.98.119.51

## Overview

This suite provides production-ready forensic analysis and recovery planning tools for disk and storage issues. All scripts operate in **READ-ONLY mode by default** with explicit safety confirmations required for any destructive actions.

## Scripts

### 1. disk_forensic_analyzer.sh (Master Orchestrator)

**Purpose:** Main coordinator that executes all diagnostic scripts and generates consolidated reports

**Usage:**
```bash
/root/host-admin/disk_forensic_analyzer.sh
```

**What it does:**
- Collects system information
- Enumerates all storage devices
- Executes SMART diagnostics
- Runs ZFS pool analysis
- Performs forensic data collection
- Generates health assessment
- Creates recovery plan
- Produces HTML/JSON reports

**Output Locations:**
- Reports: `/root/forensic-reports/`
- Logs: `/var/log/disk-forensics/`

---

### 2. smart_health_check.sh

**Purpose:** Collect and analyze SMART data from all storage devices

**Usage:**
```bash
/root/host-admin/smart_health_check.sh
```

**Dependencies:**
- smartmontools (`apt-get install smartmontools`)
- jq (optional, for formatted JSON)

**What it analyzes:**
- Overall disk health status
- Reallocated sectors (ID 5)
- Pending sectors (ID 197)
- Uncorrectable errors (ID 187, 188, 198)
- UDMA CRC errors (ID 199)

**Exit Codes:**
- 0: All devices healthy
- 1: Critical issues detected

**Output Files:**
- `smart_analysis_TIMESTAMP.json` - Structured analysis
- `smart_raw_TIMESTAMP.txt` - Raw SMART data

---

### 3. zfs_pool_analyzer.sh

**Purpose:** Comprehensive ZFS pool health diagnostics and error detection

**Usage:**
```bash
/root/host-admin/zfs_pool_analyzer.sh
```

**Prerequisites:**
- ZFS installed and module loaded

**What it analyzes:**
- Pool health status (ONLINE/DEGRADED/FAULTED)
- Capacity usage and warnings
- Fragmentation levels
- I/O errors (read/write/checksum)
- Dataset properties and compression
- Snapshot analysis
- ARC statistics
- Scrub status and history

**Output Files:**
- `zfs_analysis_TIMESTAMP.json` - Structured analysis
- `zfs_raw_TIMESTAMP.txt` - Raw ZFS data

---

### 4. forensic_collector.sh

**Purpose:** Non-destructive collection of complete system state for recovery analysis

**Usage:**
```bash
/root/host-admin/forensic_collector.sh
```

**What it collects:**
- System state (uptime, kernel, processes)
- Storage topology (block devices, partitions)
- ZFS pool states and properties
- Boot configuration (GRUB, initramfs)
- System logs (journalctl, dmesg, syslog)
- Hardware information (PCI, USB, DMI)
- Network configuration
- Service states (systemd units)

**Output Structure:**
```
/root/forensic-data/collection_TIMESTAMP/
├── system_state/
├── storage_topology/
├── zfs_state/
├── boot_state/
├── logs/
├── hardware/
├── network/
├── services/
├── manifest.json
└── SUMMARY.txt
```

**Archive:** Creates `forensic_collection_TIMESTAMP.tar.gz` for easy transfer

---

### 5. recovery_planner.sh

**Purpose:** Analyze diagnostic data and generate actionable recovery plans

**Usage:**
```bash
/root/host-admin/recovery_planner.sh
```

**What it does:**
- Analyzes SMART health data
- Evaluates ZFS pool status
- Checks disk space utilization
- Assesses system state
- Generates risk-prioritized action plan
- Creates executable recovery script
- Produces HTML report

**Risk Levels:**
- **CRITICAL**: Immediate action required (disk failure, pool faulted)
- **HIGH**: Urgent attention needed (degraded pools, >90% full)
- **MEDIUM**: Plan corrective action (high fragmentation, warnings)
- **LOW**: Preventive maintenance recommended

**Output Files:**
- `recovery_plan_TIMESTAMP.json` - Structured plan
- `recovery_actions_TIMESTAMP.sh` - Executable script (with confirmations)
- `recovery_plan_TIMESTAMP.html` - HTML report

---

## Quick Start

### Full Diagnostic Run

```bash
# Run complete diagnostic suite
/root/host-admin/disk_forensic_analyzer.sh

# View results
ls -lh /root/forensic-reports/
cat /root/forensic-reports/health_assessment_*.json | jq .
```

### Individual Component Analysis

```bash
# SMART health only
/root/host-admin/smart_health_check.sh

# ZFS pools only
/root/host-admin/zfs_pool_analyzer.sh

# System state collection only
/root/host-admin/forensic_collector.sh

# Generate recovery plan from existing data
/root/host-admin/recovery_planner.sh
```

### Execute Recovery Actions

```bash
# Review the generated recovery plan
cat /root/forensic-reports/recovery_plan_*.html

# Execute recovery script (requires confirmation for each action)
/root/forensic-reports/recovery_actions_*.sh
```

---

## Safety Features

### Read-Only by Default
All diagnostic scripts operate in read-only mode. No system modifications are made during analysis.

### Explicit Confirmations
Recovery scripts require explicit "yes" confirmation for each action before execution.

### Comprehensive Logging
All operations are logged with timestamps for audit trail:
- Diagnostic logs: `/var/log/disk-forensics/`
- Recovery logs: `/var/log/recovery_execution_*.log`

### Risk Assessment
Every action is classified by risk level (CRITICAL/HIGH/MEDIUM/LOW) with clear warnings.

---

## Common Scenarios

### Scenario 1: Disk Health Check

```bash
# Run SMART diagnostics
/root/host-admin/smart_health_check.sh

# Check for critical issues
jq '.summary' /root/forensic-reports/smart_analysis_*.json
```

### Scenario 2: ZFS Pool Degraded

```bash
# Analyze ZFS health
/root/host-admin/zfs_pool_analyzer.sh

# View pool status
jq '.pools[].analysis' /root/forensic-reports/zfs_analysis_*.json

# Generate recovery plan
/root/host-admin/recovery_planner.sh
```

### Scenario 3: Full System Forensics

```bash
# Collect complete system state
/root/host-admin/forensic_collector.sh

# Transfer archive for offline analysis
scp /root/forensic-data/forensic_collection_*.tar.gz user@backup:/path/
```

### Scenario 4: Scheduled Monitoring

```bash
# Add to cron for weekly checks
cat >> /etc/cron.weekly/disk-diagnostics <<'EOF'
#!/bin/bash
/root/host-admin/smart_health_check.sh
/root/host-admin/zfs_pool_analyzer.sh
EOF
chmod +x /etc/cron.weekly/disk-diagnostics
```

---

## Output Interpretation

### SMART Status

**PASSED** - Disk is healthy
**FAILED** - Disk failure imminent, replace immediately
**UNKNOWN** - SMART not supported or unavailable

**Critical Attributes:**
- Reallocated_Sector_Ct (5): Should be 0
- Current_Pending_Sector (197): Should be 0
- Uncorrectable errors (187/188/198): Should be 0

### ZFS Pool Status

**ONLINE** - Pool is healthy and operational
**DEGRADED** - One or more devices failed, pool operational with reduced redundancy
**FAULTED** - Pool is not operational, immediate recovery required
**UNAVAIL** - Pool cannot be imported

**Capacity Guidelines:**
- <80%: Normal operation
- 80-90%: Plan expansion
- >90%: Immediate action required

### Risk Levels

**CRITICAL**: System stability at risk, data loss possible
- Action required: Within hours
- Examples: Disk failure, pool faulted, >95% full

**HIGH**: Degraded operation, potential issues
- Action required: Within days
- Examples: Pool degraded, >90% full, multiple errors

**MEDIUM**: Suboptimal but functional
- Action required: Within weeks
- Examples: High fragmentation, 80-90% full

**LOW**: Preventive maintenance
- Action required: Next maintenance window
- Examples: Monitoring setup, documentation

---

## Troubleshooting

### SMART Data Not Available

```bash
# Install smartmontools
apt-get update && apt-get install -y smartmontools

# Enable SMART on device
smartctl -s on /dev/sda
```

### ZFS Module Not Loaded

```bash
# Load ZFS module
modprobe zfs

# Enable on boot
echo "zfs" >> /etc/modules
```

### Permission Denied

```bash
# Run with root privileges
sudo -i
/root/host-admin/disk_forensic_analyzer.sh
```

### No Output Files

```bash
# Check directories exist
mkdir -p /root/forensic-reports /var/log/disk-forensics /root/forensic-data

# Verify script permissions
chmod +x /root/host-admin/*.sh
```

---

## Integration with Monitoring

### Prometheus Exporter

```bash
# Create metrics endpoint
cat > /usr/local/bin/disk_metrics.sh <<'EOF'
#!/bin/bash
echo "# HELP disk_smart_status SMART health status (0=OK, 1=FAILED)"
for dev in /dev/sd? /dev/nvme?n?; do
    [[ -b "$dev" ]] || continue
    status=$(smartctl -H "$dev" | grep -c PASSED)
    echo "disk_smart_status{device=\"$dev\"} $((1-status))"
done
EOF
chmod +x /usr/local/bin/disk_metrics.sh
```

### Email Alerts

```bash
# Configure email on critical issues
cat > /usr/local/bin/disk_alert.sh <<'EOF'
#!/bin/bash
if /root/host-admin/smart_health_check.sh; then
    exit 0
else
    echo "Critical disk issues detected" | mail -s "ALERT: Disk Health" admin@example.com
fi
EOF
```

---

## File Locations Reference

| Type | Location | Description |
|------|----------|-------------|
| Scripts | `/root/host-admin/` | Executable diagnostic scripts |
| Reports | `/root/forensic-reports/` | JSON/HTML analysis reports |
| Forensic Data | `/root/forensic-data/` | Complete system state collections |
| Logs | `/var/log/disk-forensics/` | Diagnostic execution logs |
| Recovery Logs | `/var/log/recovery_execution_*.log` | Recovery action audit trail |

---

## Support Information

**Version:** 1.0
**Target System:** Proxmox Host 100.98.119.51
**Last Updated:** 2025-10-04

### Getting Help

1. Review script logs in `/var/log/disk-forensics/`
2. Check output files in `/root/forensic-reports/`
3. Examine raw data files for detailed information
4. Run individual scripts for targeted diagnostics

### Reporting Issues

When reporting issues, include:
- Output from `/root/host-admin/disk_forensic_analyzer.sh`
- Contents of latest forensic collection
- Relevant log files from `/var/log/disk-forensics/`
- System information: `uname -a`, `zpool --version`, `smartctl --version`

---

## Best Practices

1. **Run diagnostics before making changes**
   - Always collect baseline data first
   - Create forensic collection for rollback reference

2. **Review before executing**
   - Carefully review recovery plans
   - Understand each action before confirmation

3. **Backup first**
   - Ensure backups exist before recovery actions
   - Test restore procedures regularly

4. **Document changes**
   - Keep audit trail of all actions
   - Update runbooks with lessons learned

5. **Schedule preventive maintenance**
   - Weekly SMART checks
   - Monthly ZFS scrubs
   - Quarterly capacity planning reviews

---

## License & Warranty

These scripts are provided as-is for diagnostic and recovery purposes. Always test in non-production environments when possible and ensure backups exist before making system changes.
