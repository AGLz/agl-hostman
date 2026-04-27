# Backup Process Validation Tests

## Overview

Comprehensive test suite to validate backup process impact on VPS performance and identify resource contention issues during backup windows.

## Test Scenarios

### BT-001: Backup Process Resource Monitoring

**Objective:** Measure resource consumption during backup execution

**Prerequisites:**
- Monitoring tools installed (htop, iotop, nethogs)
- Backup schedule documented
- Baseline metrics collected

**Test Steps:**
```bash
# 1. Enable comprehensive monitoring before backup window
sudo dstat -tcmdn --output /tmp/backup-metrics-$(date +%Y%m%d).csv 1 3600 &

# 2. Monitor specific backup process
sudo watch -n 1 'ps aux | grep -E "(backup|rsync|tar|mysqldump)" | grep -v grep'

# 3. Track disk I/O during backup
sudo iotop -b -o -t -a -d 5 > /tmp/backup-io-$(date +%Y%m%d).log &

# 4. Monitor network transfer if remote backup
sudo nethogs -t > /tmp/backup-network-$(date +%Y%m%d).log &
```

**Success Criteria:**
- CPU usage <70% during backup
- Disk I/O wait <15%
- Network bandwidth <80% capacity
- Memory pressure <10% swap usage

**Failure Actions:**
1. Document peak resource consumption
2. Identify specific backup command causing spike
3. Calculate required resource headroom

---

### BT-002: Backup Window Overlap Detection

**Objective:** Identify conflicting backup jobs running simultaneously

**Test Steps:**
```bash
# 1. List all scheduled backup jobs
sudo crontab -l -u root
sudo crontab -l -u www-data
sudo systemctl list-timers --all | grep -i backup

# 2. Create backup schedule matrix
cat > /tmp/backup-schedule-check.sh << 'EOF'
#!/bin/bash
echo "Backup Schedule Analysis - $(date)"
echo "=================================="

# Check cron jobs
echo -e "\n=== Root Cron Jobs ==="
sudo crontab -l -u root 2>/dev/null | grep -v '^#' | grep -v '^$'

echo -e "\n=== WWW-Data Cron Jobs ==="
sudo crontab -l -u www-data 2>/dev/null | grep -v '^#' | grep -v '^$'

# Check systemd timers
echo -e "\n=== Systemd Backup Timers ==="
systemctl list-timers --all | grep -iE "(backup|dump|sync)"

# Check for backup processes currently running
echo -e "\n=== Currently Running Backup Processes ==="
ps aux | grep -iE "(backup|rsync|mysqldump|tar|duplicity)" | grep -v grep
EOF

chmod +x /tmp/backup-schedule-check.sh
/tmp/backup-schedule-check.sh
```

**Success Criteria:**
- No overlapping backup windows identified
- Total backup duration <60 minutes
- Minimum 30-minute gap between backup jobs

**Failure Actions:**
1. Create backup job dependency chart
2. Stagger conflicting backup schedules
3. Implement backup job locking mechanism

---

### BT-003: Database Backup I/O Impact

**Objective:** Measure MySQL performance degradation during backup

**Test Steps:**
```bash
# 1. Create pre-backup performance baseline
cat > /tmp/mysql-backup-impact.sh << 'EOF'
#!/bin/bash
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOGFILE="/tmp/mysql-backup-impact-${TIMESTAMP}.log"

echo "MySQL Backup Impact Test - $(date)" | tee -a "$LOGFILE"
echo "====================================" | tee -a "$LOGFILE"

# Baseline query performance
echo -e "\n=== Baseline Performance (Before Backup) ===" | tee -a "$LOGFILE"
mysql -e "SHOW GLOBAL STATUS LIKE 'Questions';" | tee -a "$LOGFILE"
mysql -e "SHOW GLOBAL STATUS LIKE 'Slow_queries';" | tee -a "$LOGFILE"
mysql -e "SELECT COUNT(*) as active_connections FROM information_schema.processlist;" | tee -a "$LOGFILE"

# Test query response time
START=$(date +%s%N)
mysql -e "SELECT SLEEP(0); SELECT NOW();" > /dev/null
END=$(date +%s%N)
BASELINE_LATENCY=$(( (END - START) / 1000000 ))
echo "Baseline query latency: ${BASELINE_LATENCY}ms" | tee -a "$LOGFILE"

# Trigger backup (or wait for scheduled backup)
echo -e "\n=== Starting Backup Process ===" | tee -a "$LOGFILE"
# Simulate backup with mysqldump
sudo mysqldump --all-databases --single-transaction --quick --lock-tables=false \
    > /tmp/backup-test-${TIMESTAMP}.sql 2>&1 &
BACKUP_PID=$!

# Monitor during backup
sleep 5
while kill -0 $BACKUP_PID 2>/dev/null; do
    echo -e "\n--- During Backup: $(date) ---" | tee -a "$LOGFILE"
    mysql -e "SHOW GLOBAL STATUS LIKE 'Threads_running';" | tee -a "$LOGFILE"
    mysql -e "SHOW PROCESSLIST;" | tee -a "$LOGFILE"

    # Measure query latency during backup
    START=$(date +%s%N)
    mysql -e "SELECT SLEEP(0); SELECT NOW();" > /dev/null 2>&1
    END=$(date +%s%N)
    BACKUP_LATENCY=$(( (END - START) / 1000000 ))
    echo "Query latency during backup: ${BACKUP_LATENCY}ms" | tee -a "$LOGFILE"

    sleep 10
done

# Post-backup metrics
echo -e "\n=== Post-Backup Performance ===" | tee -a "$LOGFILE"
mysql -e "SHOW GLOBAL STATUS LIKE 'Slow_queries';" | tee -a "$LOGFILE"

# Cleanup test backup
rm -f /tmp/backup-test-${TIMESTAMP}.sql

echo -e "\n=== Summary ===" | tee -a "$LOGFILE"
echo "Baseline latency: ${BASELINE_LATENCY}ms" | tee -a "$LOGFILE"
echo "Backup latency: ${BACKUP_LATENCY}ms" | tee -a "$LOGFILE"
DEGRADATION=$(( (BACKUP_LATENCY * 100 / BASELINE_LATENCY) - 100 ))
echo "Performance degradation: ${DEGRADATION}%" | tee -a "$LOGFILE"
EOF

chmod +x /tmp/mysql-backup-impact.sh
sudo /tmp/mysql-backup-impact.sh
```

**Success Criteria:**
- Query latency increase <50% during backup
- No query timeouts (max_execution_time)
- Slow query count unchanged
- Connection pool not exhausted

**Failure Actions:**
1. Switch to --single-transaction for InnoDB tables
2. Reduce mysqldump threads/parallelism
3. Use MySQL replication for backup (read from replica)
4. Schedule backups during lowest traffic periods

---

### BT-004: File System Backup Lock Detection

**Objective:** Identify file locking issues during web application backup

**Test Steps:**
```bash
# 1. Monitor file locks during backup
sudo lsof +D /var/www/html > /tmp/pre-backup-locks.txt

# 2. Trigger file backup
sudo tar czf /tmp/webroot-backup-test.tar.gz /var/www/html 2>&1 | tee /tmp/backup-tar-output.log

# 3. Check for lock conflicts
sudo lsof +D /var/www/html > /tmp/during-backup-locks.txt

# 4. Compare lock states
diff /tmp/pre-backup-locks.txt /tmp/during-backup-locks.txt

# 5. Test application access during backup
curl -w "@/tmp/curl-timing-format.txt" -o /dev/null -s http://localhost/

# Create curl timing format if not exists
cat > /tmp/curl-timing-format.txt << 'EOF'
time_namelookup:  %{time_namelookup}s\n
time_connect:  %{time_connect}s\n
time_appconnect:  %{time_appconnect}s\n
time_pretransfer:  %{time_pretransfer}s\n
time_redirect:  %{time_redirect}s\n
time_starttransfer:  %{time_starttransfer}s\n
----------\n
time_total:  %{time_total}s\n
EOF
```

**Success Criteria:**
- No exclusive file locks during backup
- Application remains accessible
- HTTP response time <500ms during backup
- No "Resource temporarily unavailable" errors

**Failure Actions:**
1. Implement copy-on-write snapshots (LVM/ZFS)
2. Use rsync with --no-blocking-io
3. Create backup from read-only snapshot
4. Exclude cache/temp directories from backup

---

### BT-005: Remote Backup Transfer Impact

**Objective:** Measure network saturation during remote backup transfers

**Test Steps:**
```bash
# 1. Monitor network before backup
sudo iftop -t -s 60 > /tmp/network-baseline.txt 2>&1 &
IFTOP_PID=$!

# 2. Simulate large file transfer (or monitor real backup)
# If using rsync to remote backup:
sudo rsync -avz --progress --bwlimit=10000 /backup/source/ user@remote:/backup/dest/ \
    2>&1 | tee /tmp/rsync-backup-test.log

# 3. Monitor bandwidth during transfer
sudo kill $IFTOP_PID
sudo iftop -t -s 60 > /tmp/network-during-backup.txt 2>&1

# 4. Test application response during transfer
for i in {1..10}; do
    curl -w "Response time: %{time_total}s\n" -o /dev/null -s http://localhost/
    sleep 5
done
```

**Success Criteria:**
- Bandwidth utilization <80% of available
- No packet loss during backup transfer
- Application response time degradation <20%
- No TCP retransmissions spike

**Failure Actions:**
1. Implement bandwidth throttling (--bwlimit)
2. Use QoS to prioritize application traffic
3. Schedule transfers during off-peak hours
4. Use compression to reduce transfer size

---

### BT-006: Backup Process Timeout Correlation

**Objective:** Correlate backup execution with timeout incidents

**Test Steps:**
```bash
# 1. Extract backup execution times from logs
cat > /tmp/analyze-backup-correlation.sh << 'EOF'
#!/bin/bash

echo "Backup-Timeout Correlation Analysis"
echo "===================================="

# Parse backup execution times
echo -e "\n=== Backup Execution Windows ==="
grep -i backup /var/log/syslog | grep -E "(started|completed|finished)" | tail -20

# Check for 504 errors during backup windows
echo -e "\n=== Web Server 504 Errors ==="
grep "504" /var/log/nginx/error.log | tail -20

# Check PHP-FPM timeout errors
echo -e "\n=== PHP-FPM Timeout Errors ==="
grep -i "timeout" /var/log/php*-fpm.log | tail -20

# System load during backup times
echo -e "\n=== System Load Analysis ==="
last | head -20  # Check for system reboots
uptime

# Generate timeline correlation
echo -e "\n=== Timeline Correlation ==="
echo "Cross-reference backup start times with 504 error times"
# This would ideally parse timestamps and calculate overlap
EOF

chmod +x /tmp/analyze-backup-correlation.sh
/tmp/analyze-backup-correlation.sh
```

**Success Criteria:**
- Clear timeline correlation identified
- Statistical significance (p < 0.05)
- Consistent pattern across multiple days

**Failure Actions:**
1. Expand data collection period
2. Check for other scheduled tasks
3. Review application-specific logs
4. Interview users for anecdotal correlation

---

## Automated Test Suite

```bash
#!/bin/bash
# Run all backup validation tests

TESTS_DIR="/mnt/overpower/apps/dev/agl/agl-hostman/tests/vps-timeout-testing"
RESULTS_DIR="${TESTS_DIR}/results/backup-tests-$(date +%Y%m%d)"

mkdir -p "$RESULTS_DIR"

echo "Starting Backup Validation Test Suite - $(date)"
echo "Results directory: $RESULTS_DIR"

# Run each test
for test in BT-001 BT-002 BT-003 BT-004 BT-005 BT-006; do
    echo "Running test: $test"
    # Execute test and capture results
    # (Test execution logic here)
    echo "$test completed" >> "$RESULTS_DIR/execution.log"
done

echo "Test suite completed - $(date)"
echo "Review results in: $RESULTS_DIR"
```

---

**Version:** 1.0
**Last Updated:** 2025-10-22
**Test Count:** 6 comprehensive scenarios
**Estimated Duration:** 3-5 days
