# AGLSRV1 Investigation Quick Start Guide

**For Hive Mind Agents**: Analyst, Coder, Tester
**Target System**: AGLSRV1 Proxmox @ 192.168.0.245
**Mission**: Collect live system data and diagnose backup issues

---

## 🚀 Immediate Action Commands

### Quick Diagnostic (Run First)
```bash
# Complete system status in ONE command
ssh AGLSRV1 "echo '=== PROXMOX ===' && pveversion -v && echo && echo '=== STORAGE ===' && pvesm status && echo && echo '=== BACKUPS ===' && pvesh get /cluster/tasks --running 1 && echo && echo '=== PROCESSES ===' && ps auxwf | grep vzdump | grep -v grep"
```

### Quick Storage Check
```bash
ssh AGLSRV1 "echo '=== SPARK STORAGE ===' && df -h | grep spark && echo && zfs list | grep spark && echo && echo '=== SNAPSHOTS ===' && zfs list -t snapshot | grep spark | wc -l"
```

### Quick Error Check
```bash
ssh AGLSRV1 "echo '=== RECENT ERRORS ===' && grep -i 'error\|fail' /var/log/vzdump/*.log | tail -20"
```

### Quick Process Check
```bash
ssh AGLSRV1 "echo '=== BACKUP PROCESSES ===' && ps aux | grep vzdump | grep -v grep && echo && echo '=== STUCK PROCESSES (Ds state) ===' && ps aux | awk '\$8 ~ /D/ {print \$0}'"
```

---

## 📋 Comprehensive Data Collection Script

Copy and run this complete diagnostic:

```bash
#!/bin/bash
# AGLSRV1 Complete Diagnostic Collection
# Run this to get ALL data needed for analysis

HOST="AGLSRV1"
OUTPUT_FILE="/root/host-admin/claudedocs/AGLSRV1_diagnostic_$(date +%Y%m%d_%H%M%S).log"

echo "Starting AGLSRV1 diagnostic collection..."
echo "Output: $OUTPUT_FILE"

{
  echo "=========================================="
  echo "AGLSRV1 DIAGNOSTIC REPORT"
  echo "Collected: $(date)"
  echo "=========================================="
  echo

  echo "=== SYSTEM INFO ==="
  ssh $HOST "pveversion -v"
  echo
  ssh $HOST "uptime"
  echo
  ssh $HOST "free -h"
  echo

  echo "=== STORAGE STATUS ==="
  ssh $HOST "pvesm status"
  echo
  ssh $HOST "zpool list"
  echo
  ssh $HOST "zpool status"
  echo
  ssh $HOST "df -h"
  echo

  echo "=== SPARK STORAGE DETAIL ==="
  ssh $HOST "zfs list | grep spark"
  echo
  ssh $HOST "zfs list -t snapshot | grep spark | head -20"
  echo
  ssh $HOST "zfs list -t snapshot | grep spark | wc -l"
  echo

  echo "=== VM/CT INVENTORY ==="
  ssh $HOST "qm list"
  echo
  ssh $HOST "pct list"
  echo

  echo "=== BACKUP CONFIGURATION ==="
  ssh $HOST "cat /etc/pve/jobs.cfg 2>/dev/null || echo 'No jobs.cfg found'"
  echo
  ssh $HOST "cat /etc/vzdump.conf 2>/dev/null || echo 'No vzdump.conf found'"
  echo
  ssh $HOST "pvesh get /cluster/backup --output-format json-pretty 2>/dev/null"
  echo

  echo "=== RUNNING TASKS ==="
  ssh $HOST "pvesh get /cluster/tasks --running 1"
  echo

  echo "=== RECENT TASKS ==="
  ssh $HOST "pvesh get /cluster/tasks --limit 20 --output-format json-pretty"
  echo

  echo "=== BACKUP PROCESSES ==="
  ssh $HOST "ps auxwf | grep -E '(vzdump|backup)' | grep -v grep"
  echo

  echo "=== STUCK PROCESSES (Ds state) ==="
  ssh $HOST "ps aux | awk '\$8 ~ /D/ {print \$0}'"
  echo

  echo "=== RECENT BACKUP LOGS ==="
  ssh $HOST "ls -lh /var/log/vzdump/ | tail -20"
  echo

  echo "=== BACKUP ERRORS ==="
  ssh $HOST "grep -i 'error\|fail\|abort' /var/log/vzdump/*.log 2>/dev/null | tail -50"
  echo

  echo "=== SYSTEM ERRORS ==="
  ssh $HOST "dmesg | grep -i 'error\|fail' | tail -30"
  echo

  echo "=== LOCK FILES ==="
  ssh $HOST "find /var/lock -name '*vzdump*' -ls 2>/dev/null"
  ssh $HOST "find /run/lock -name '*vzdump*' -ls 2>/dev/null"
  echo

  echo "=== NFS MOUNTS ==="
  ssh $HOST "mount | grep nfs || echo 'No NFS mounts found'"
  echo

  echo "=========================================="
  echo "DIAGNOSTIC COLLECTION COMPLETE"
  echo "=========================================="

} | tee "$OUTPUT_FILE"

echo
echo "Diagnostic complete! Output saved to:"
echo "$OUTPUT_FILE"
echo
echo "Review the report and analyze for:"
echo "  - Stuck processes in 'Ds' state"
echo "  - Storage capacity issues on spark"
echo "  - Error messages in backup logs"
echo "  - Stale vzdump snapshots"
echo "  - NFS mount problems"
```

---

## 🎯 What to Look For

### 🔴 CRITICAL ISSUES

1. **Stuck Process in "Ds" State**
   - Look for: `ps aux` output showing processes with state "Ds"
   - Meaning: Uninterruptible sleep, waiting for I/O
   - Action: Cannot kill, must fix storage or reboot

2. **Spark Storage <20% Free**
   - Look for: `df -h` showing spark near capacity
   - Meaning: Insufficient space for backups
   - Action: Clean old backups or expand storage

3. **Error Messages in Logs**
   - Look for: "error", "fail", "abort" in /var/log/vzdump/*.log
   - Meaning: Backup failures with specific causes
   - Action: Address specific error (storage, permission, I/O)

### 🟡 IMPORTANT CHECKS

4. **Stale Vzdump Snapshots**
   - Look for: `zfs list -t snapshot | grep vzdump`
   - Meaning: Failed cleanup from previous backups
   - Action: Manually remove old vzdump snapshots

5. **NFS Mount Issues**
   - Look for: `mount | grep nfs` with unusual options
   - Meaning: Remote storage connectivity problems
   - Action: Verify NFS server, consider soft mount

6. **High Snapshot Count**
   - Look for: Many snapshots consuming space
   - Meaning: Retention policy too aggressive
   - Action: Reduce retention or clean old snapshots

---

## 📊 Analysis Calculations

### Capacity Assessment
```bash
# Calculate required vs available space
# Manual calculation from diagnostic output:

Total_Spark_Space = [from zpool list]
Used_Spark_Space = [from zpool list]
Available_Space = Total - Used

VM_Disk_Sizes = [sum from qm list]
Retention_Count = [from backup config]
Required_Space = VM_Disk_Sizes × Retention_Count × 1.2  # 20% overhead

# Decision
if Required_Space > Available_Space:
    echo "CAPACITY ISSUE - Need to expand or optimize"
else:
    echo "Capacity OK"
fi
```

### Stuck Process Assessment
```bash
# From ps output, check state column
# State "Ds" = Uninterruptible sleep (CRITICAL)
# State "S" = Sleeping (OK)
# State "R" = Running (OK)
# State "Z" = Zombie (needs cleanup)
```

---

## 🔧 Common Remediation Commands

### Kill Stuck Backup (if not in Ds state)
```bash
ssh AGLSRV1 "pkill -9 vzdump"
# Wait 2 minutes, verify with: ps aux | grep vzdump
```

### Remove Stale Vzdump Snapshots
```bash
ssh AGLSRV1 "zfs list -t snapshot | grep vzdump | awk '{print \$1}' | xargs -I {} zfs destroy {}"
```

### Clean Lock Files
```bash
ssh AGLSRV1 "rm -f /var/lock/vzdump* /run/lock/vzdump*"
```

### Check Backup Job Status
```bash
ssh AGLSRV1 "systemctl status pve-daily-backup.service"
ssh AGLSRV1 "journalctl -u pve-daily-backup -n 50"
```

### Restart Proxmox Daemons (if needed)
```bash
ssh AGLSRV1 "systemctl restart pvedaemon pveproxy"
```

---

## 📝 Report Template

After collecting data, report findings in this format:

```markdown
## AGLSRV1 Diagnostic Findings

**Investigation Date**: [DATE]
**Analyst**: [AGENT_NAME]

### System Status
- Proxmox Version: [VERSION]
- Uptime: [UPTIME]
- Load: [LOAD_AVG]

### Storage Status
- Spark Total: [SIZE]
- Spark Used: [USED] ([PERCENT]%)
- Spark Available: [AVAIL] ([PERCENT]%)
- Assessment: [OK / WARNING / CRITICAL]

### Backup Status
- Running Tasks: [COUNT]
- Stuck Processes: [YES/NO] - PIDs: [LIST]
- Recent Failures: [COUNT]
- Error Pattern: [DESCRIPTION]

### Root Cause
[Identify primary issue]

### Recommended Actions
1. [Priority 1 action]
2. [Priority 2 action]
3. [Priority 3 action]

### Implementation Ready
[YES/NO] - [Scripts or commands ready to execute]
```

---

## 🚨 Emergency Actions

If system is completely stuck:

```bash
# 1. Save diagnostic data first
ssh AGLSRV1 "ps auxwf > /root/processes_backup.txt"
ssh AGLSRV1 "pvesh get /cluster/tasks > /root/tasks_backup.txt"
ssh AGLSRV1 "zpool status > /root/zpool_backup.txt"

# 2. Try graceful stop
ssh AGLSRV1 "pvesh set /cluster/tasks/UPID:XXXX --endtime 1"

# 3. Force kill (if not in Ds state)
ssh AGLSRV1 "pkill -9 vzdump"

# 4. Clean up
ssh AGLSRV1 "rm -f /var/lock/vzdump* /run/lock/vzdump*"
ssh AGLSRV1 "zfs destroy $(zfs list -t snapshot | grep vzdump | awk '{print \$1}')"

# 5. Restart services
ssh AGLSRV1 "systemctl restart pvedaemon pveproxy pve-cluster"
```

---

**Ready for immediate execution**
**Full report**: `/root/host-admin/claudedocs/AGLSRV1_BACKUP_RESEARCH_REPORT.md`
**Contact**: Research Agent for methodology questions
