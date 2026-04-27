# Disk Forensic Suite - Quick Reference Card

## One-Line Commands

### Complete Diagnostics
```bash
/root/host-admin/disk_forensic_analyzer.sh
```

### Individual Checks
```bash
# SMART health check
/root/host-admin/smart_health_check.sh

# ZFS pool analysis
/root/host-admin/zfs_pool_analyzer.sh

# Forensic data collection
/root/host-admin/forensic_collector.sh

# Generate recovery plan
/root/host-admin/recovery_planner.sh
```

### View Results
```bash
# List all reports
ls -lht /root/forensic-reports/ | head -20

# View health assessment
cat /root/forensic-reports/health_assessment_*.json | jq .

# View recovery plan
cat /root/forensic-reports/recovery_plan_*.json | jq .

# Open HTML report
firefox /root/forensic-reports/forensic_report_*.html
```

---

## Emergency Response

### Critical Disk Failure
```bash
# 1. Run diagnostics immediately
/root/host-admin/smart_health_check.sh

# 2. Identify failed disk
jq '.devices[] | select(.health_status=="FAILED")' /root/forensic-reports/smart_analysis_*.json

# 3. Check ZFS pool impact
zpool status -v

# 4. Generate recovery plan
/root/host-admin/recovery_planner.sh
```

### ZFS Pool Degraded
```bash
# 1. Check pool status
/root/host-admin/zfs_pool_analyzer.sh

# 2. View pool details
zpool status -v <pool_name>

# 3. Generate recovery actions
/root/host-admin/recovery_planner.sh

# 4. Execute recovery (with confirmations)
/root/forensic-reports/recovery_actions_*.sh
```

### Disk Space Critical
```bash
# 1. Check disk usage
df -h

# 2. Run full diagnostics
/root/host-admin/disk_forensic_analyzer.sh

# 3. Find space consumers
du -sh /* | sort -h | tail -10

# 4. ZFS snapshot cleanup (if applicable)
zfs list -t snapshot | tail -20
zfs destroy <pool/dataset@snapshot>
```

---

## Status Checks

### Quick Health Check
```bash
# All-in-one status
{
  echo "=== SMART Status ==="
  smartctl -H /dev/sda /dev/sdb 2>/dev/null | grep -E "(Device Model|SMART overall-health)"
  echo -e "\n=== ZFS Pools ==="
  zpool list
  echo -e "\n=== Disk Space ==="
  df -h | grep -vE "(tmpfs|devtmpfs)"
}
```

### Detailed Diagnostics
```bash
# Full system scan
/root/host-admin/disk_forensic_analyzer.sh 2>&1 | tee /tmp/diagnostic_run.log

# Check for critical issues
grep -i "critical\|failed\|error" /tmp/diagnostic_run.log
```

---

## Report Locations

| Report Type | Location | Format |
|-------------|----------|--------|
| Health Assessment | `/root/forensic-reports/health_assessment_*.json` | JSON |
| SMART Analysis | `/root/forensic-reports/smart_analysis_*.json` | JSON |
| ZFS Analysis | `/root/forensic-reports/zfs_analysis_*.json` | JSON |
| Recovery Plan | `/root/forensic-reports/recovery_plan_*.json` | JSON |
| HTML Summary | `/root/forensic-reports/forensic_report_*.html` | HTML |
| Forensic Collection | `/root/forensic-data/collection_*/*.txt` | Text |
| Execution Logs | `/var/log/disk-forensics/*.log` | Log |

---

## Common jq Queries

### View Critical Issues
```bash
# SMART critical issues
jq '.devices[] | select(.critical_attributes | length > 0)' /root/forensic-reports/smart_analysis_*.json

# ZFS pool problems
jq '.pools[] | select(.analysis.severity != "OK")' /root/forensic-reports/zfs_analysis_*.json

# Overall health summary
jq '.summary' /root/forensic-reports/health_assessment_*.json
```

### Extract Specific Data
```bash
# List all disks with health status
jq -r '.devices[] | "\(.device): \(.health_status)"' /root/forensic-reports/smart_analysis_*.json

# ZFS pool capacities
jq -r '.pools[] | "\(.analysis.pool): \(.analysis.capacity)"' /root/forensic-reports/zfs_analysis_*.json

# Recovery action count by priority
jq '.critical_actions | length' /root/forensic-reports/recovery_plan_*.json
```

---

## Recovery Actions

### Safe Execution Pattern
```bash
# 1. Review plan first
cat /root/forensic-reports/recovery_plan_*.html

# 2. Backup current state
/root/host-admin/forensic_collector.sh

# 3. Execute with confirmations
/root/forensic-reports/recovery_actions_*.sh

# 4. Verify success
/root/host-admin/disk_forensic_analyzer.sh
```

### Manual Recovery Steps

#### Replace Failed Disk (ZFS)
```bash
# 1. Identify failed disk
zpool status -v <pool>

# 2. Offline the disk
zpool offline <pool> <failed_disk>

# 3. Physical replacement (shutdown required)
shutdown -h now

# 4. After replacement, replace in pool
zpool replace <pool> <old_disk_id> <new_disk_id>

# 5. Monitor resilver
zpool status -v <pool>
```

#### Free Disk Space (ZFS)
```bash
# 1. List snapshots by space
zfs list -t snapshot -o name,used -s used | tail -20

# 2. Delete old snapshots
zfs destroy <pool/dataset@snapshot>

# 3. List large datasets
zfs list -o name,used,refer -s used | head -20

# 4. Verify space freed
zpool list <pool>
```

---

## Automation & Monitoring

### Cron Schedules

#### Daily SMART Check
```bash
cat > /etc/cron.daily/smart-check <<'EOF'
#!/bin/bash
/root/host-admin/smart_health_check.sh || \
  echo "SMART check failed on $(hostname)" | \
  mail -s "ALERT: Disk Health Issue" admin@example.com
EOF
chmod +x /etc/cron.daily/smart-check
```

#### Weekly Full Diagnostic
```bash
cat > /etc/cron.weekly/disk-forensics <<'EOF'
#!/bin/bash
/root/host-admin/disk_forensic_analyzer.sh > /var/log/weekly-disk-diagnostic.log 2>&1
EOF
chmod +x /etc/cron.weekly/disk-forensics
```

#### Monthly ZFS Scrub
```bash
cat > /etc/cron.monthly/zfs-scrub <<'EOF'
#!/bin/bash
for pool in $(zpool list -H -o name); do
  zpool scrub $pool
done
EOF
chmod +x /etc/cron.monthly/zfs-scrub
```

### Alert Integration

#### Prometheus Node Exporter Custom Metrics
```bash
cat > /usr/local/bin/disk_forensic_metrics.sh <<'EOF'
#!/bin/bash
LATEST_REPORT=$(ls -t /root/forensic-reports/health_assessment_*.json | head -1)
if [[ -f "$LATEST_REPORT" ]]; then
  jq -r '"disk_critical_issues " + (.critical_issues|tostring)' "$LATEST_REPORT"
  jq -r '"disk_warnings " + (.warnings|tostring)' "$LATEST_REPORT"
  jq -r '"disk_health_status " + (if .overall_status == "HEALTHY" then "0" elif .overall_status == "WARNING" then "1" else "2" end)' "$LATEST_REPORT"
fi
EOF
chmod +x /usr/local/bin/disk_forensic_metrics.sh
```

---

## Troubleshooting

### Script Fails

#### Permission Issues
```bash
# Fix permissions
sudo chown root:root /root/host-admin/*.sh
sudo chmod 755 /root/host-admin/*.sh
```

#### Missing Dependencies
```bash
# Install required packages
apt-get update
apt-get install -y smartmontools jq nvme-cli lsscsi pciutils usbutils dmidecode
```

#### ZFS Not Available
```bash
# Load ZFS module
modprobe zfs

# Verify loaded
lsmod | grep zfs

# Install if missing
apt-get install -y zfsutils-linux
```

### Output Issues

#### No Reports Generated
```bash
# Create directories
mkdir -p /root/forensic-reports /var/log/disk-forensics /root/forensic-data

# Check disk space
df -h /root

# Run with verbose output
bash -x /root/host-admin/disk_forensic_analyzer.sh
```

#### JSON Parsing Errors
```bash
# Install jq
apt-get install -y jq

# Validate JSON
jq empty /root/forensic-reports/*.json
```

---

## Performance Tips

### Large Systems (>20 disks)
```bash
# Run components in parallel
/root/host-admin/smart_health_check.sh &
/root/host-admin/zfs_pool_analyzer.sh &
wait

# Then generate plan
/root/host-admin/recovery_planner.sh
```

### Low Memory Systems
```bash
# Run one script at a time
for script in smart_health_check.sh zfs_pool_analyzer.sh forensic_collector.sh; do
  /root/host-admin/$script
done
```

### Slow Storage
```bash
# Limit concurrent SMART queries
export SMART_MAX_PARALLEL=2
/root/host-admin/smart_health_check.sh
```

---

## Data Retention

### Cleanup Old Reports
```bash
# Keep last 30 days of reports
find /root/forensic-reports -name "*.json" -mtime +30 -delete
find /root/forensic-reports -name "*.html" -mtime +30 -delete

# Keep last 7 forensic collections
ls -t /root/forensic-data/collection_* | tail -n +8 | xargs rm -rf
```

### Archive Important Data
```bash
# Create dated archive
tar -czf /backup/forensic-archive-$(date +%Y%m).tar.gz \
  /root/forensic-reports \
  /root/forensic-data \
  /var/log/disk-forensics

# Transfer to backup server
scp /backup/forensic-archive-*.tar.gz backup-server:/archives/
```

---

## Exit Codes

| Code | Meaning | Action |
|------|---------|--------|
| 0 | Success, no issues | Continue normal operation |
| 1 | Critical issues found | Review reports, execute recovery |
| 2 | Script error | Check logs, verify dependencies |

---

## Support Contacts

**Documentation:** `/root/host-admin/FORENSIC_SUITE_README.md`

**Log Files:**
- Diagnostic: `/var/log/disk-forensics/`
- Recovery: `/var/log/recovery_execution_*.log`

**Quick Help:**
```bash
# View script header documentation
head -20 /root/host-admin/disk_forensic_analyzer.sh
```

---

**Version:** 1.0 | **System:** Proxmox 100.98.119.51 | **Updated:** 2025-10-04
