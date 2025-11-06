# VPS Timeout Testing - Quick Start Guide

## 🚀 5-Minute Setup

### Step 1: Install Prerequisites (2 minutes)

```bash
# Install all testing tools at once
sudo apt-get update && sudo apt-get install -y \
    apache2-utils dstat iftop iotop mtr nethogs netcat tcpdump sysstat

# Create results directory
mkdir -p /mnt/overpower/apps/dev/agl/agl-hostman/tests/vps-timeout-testing/results
cd /mnt/overpower/apps/dev/agl/agl-hostman/tests/vps-timeout-testing
```

### Step 2: Collect Baseline (3 minutes)

```bash
# Quick baseline collection
cat > /tmp/quick-baseline.sh << 'EOF'
#!/bin/bash
echo "=== Quick Baseline Collection ==="
echo "System: $(hostname) at $(date)"

# System stats
uptime
free -h
df -h

# Application response (10 samples)
echo -e "\n=== Response Times ==="
for i in {1..10}; do
    curl -w "Time: %{time_total}s\n" -o /dev/null -s http://localhost/
    sleep 2
done

# PHP-FPM status
echo -e "\n=== PHP-FPM Status ==="
curl -s http://localhost/fpm-status 2>/dev/null || echo "FPM status not available"

# MySQL quick check
echo -e "\n=== MySQL Status ==="
mysql -e "SHOW GLOBAL STATUS LIKE 'Threads_connected';" 2>/dev/null || echo "MySQL not accessible"
EOF

chmod +x /tmp/quick-baseline.sh
/tmp/quick-baseline.sh | tee results/quick-baseline-$(date +%Y%m%d).txt
```

## 🎯 Critical Tests (Run These First)

### Test 1: Backup Impact Analysis (10 minutes)

```bash
# BT-003: Database Backup I/O Impact
cat > /tmp/test-backup-impact.sh << 'EOF'
#!/bin/bash
echo "=== Testing Backup Impact ==="

# Baseline query time
echo "Baseline query performance:"
time mysql -e "SELECT COUNT(*) FROM information_schema.tables;"

# Start backup
echo "Starting backup..."
mysqldump --all-databases --single-transaction > /tmp/test-backup.sql 2>&1 &
BACKUP_PID=$!

# Test during backup
sleep 10
echo "Query performance DURING backup:"
time mysql -e "SELECT COUNT(*) FROM information_schema.tables;"

# Cleanup
wait $BACKUP_PID
rm -f /tmp/test-backup.sql
echo "Test complete"
EOF

chmod +x /tmp/test-backup-impact.sh
sudo /tmp/test-backup-impact.sh
```

**Expected Result:** Query time should increase <50% during backup

### Test 2: PHP-FPM Capacity (5 minutes)

```bash
# ST-001: PHP-FPM Pool Exhaustion Test (light version)
# Check current pool size
sudo grep "pm.max_children" /etc/php/*/fpm/pool.d/www.conf

# Test with 50 concurrent users
ab -n 500 -c 50 http://localhost/ > /tmp/phpfpm-capacity-test.txt 2>&1

# Check results
echo "=== PHP-FPM Capacity Test Results ==="
grep "Failed requests" /tmp/phpfpm-capacity-test.txt
grep "Requests per second" /tmp/phpfpm-capacity-test.txt
grep "Time per request" /tmp/phpfpm-capacity-test.txt

# Check PHP-FPM status
curl -s http://localhost/fpm-status
```

**Expected Result:** Zero failed requests, response time <500ms

### Test 3: Morning Window Simulation (15 minutes)

```bash
# VT-002: Simulate morning backup window
cat > /tmp/morning-window-test.sh << 'EOF'
#!/bin/bash
DURATION=900  # 15 minutes
INTERVAL=30

echo "=== Morning Window Simulation ==="
echo "Start: $(date)"

# Monitor application health
while [ $(date +%s) -lt $(($(date +%s) + $DURATION)) ]; do
    # Test response time
    RESPONSE=$(curl -w "%{http_code}|%{time_total}" -o /dev/null -s http://localhost/)
    HTTP_CODE="${RESPONSE%%|*}"
    TIME="${RESPONSE##*|}"

    echo "$(date +%H:%M:%S) | HTTP $HTTP_CODE | ${TIME}s"

    # Alert on issues
    if [ "$HTTP_CODE" != "200" ] || (( $(echo "$TIME > 1.0" | bc -l) )); then
        echo "⚠️  WARNING: Potential issue detected!"
    fi

    sleep $INTERVAL
done

echo "Test complete: $(date)"
EOF

chmod +x /tmp/morning-window-test.sh

# Run in background or during actual morning window
/tmp/morning-window-test.sh | tee results/morning-window-test-$(date +%Y%m%d).log
```

**Expected Result:** All responses <1s, no HTTP errors

## 🔍 Quick Diagnosis Commands

### Check for Active Timeouts
```bash
# Check recent timeout errors
sudo grep -i "504\|timeout" /var/log/nginx/error.log | tail -20
sudo grep -i "timeout" /var/log/php*-fpm.log | tail -20
```

### Check Current Resource Usage
```bash
# One-line system status
echo "CPU: $(top -bn1 | grep "Cpu(s)" | awk '{print $2}')% | Memory: $(free | grep Mem | awk '{printf("%.1f%%", $3/$2 * 100.0)}') | Disk I/O: $(iostat -x 1 2 | tail -1 | awk '{print $14}')%"
```

### Check PHP-FPM Pool Status
```bash
# Current pool utilization
curl -s http://localhost/fpm-status | grep -E "(active|idle|total) processes"
```

### Check MySQL Performance
```bash
# Quick MySQL health check
mysql -e "SHOW GLOBAL STATUS LIKE 'Threads_connected';"
mysql -e "SHOW GLOBAL STATUS LIKE 'Slow_queries';"
mysql -e "SELECT COUNT(*) FROM information_schema.PROCESSLIST WHERE TIME > 5;"
```

### Check Network Status
```bash
# Connection states
ss -s

# Active connections
netstat -an | grep ESTABLISHED | wc -l

# Network errors
cat /proc/net/dev | grep -v "Inter-|face" | awk '{print $1, "RX_ERR:", $4, "TX_ERR:", $12}'
```

## 📊 Quick Metrics Dashboard

```bash
# Create live monitoring dashboard
watch -n 2 'printf "=== VPS Health Dashboard ===\n\n";
printf "Time: $(date)\n\n";
printf "=== System ===\n";
uptime;
free -h | grep Mem;
printf "\n=== PHP-FPM ===\n";
curl -s http://localhost/fpm-status 2>/dev/null | head -5;
printf "\n=== MySQL ===\n";
mysql -e "SHOW GLOBAL STATUS LIKE \"Threads_connected\";" 2>/dev/null | tail -1;
printf "\n=== Network ===\n";
ss -s | grep TCP;
printf "\n=== Recent Errors ===\n";
sudo tail -3 /var/log/nginx/error.log 2>/dev/null;'
```

## 🚨 Emergency Quick Checks

### If Experiencing Timeout RIGHT NOW:

```bash
# 1. Check what's consuming resources
sudo ps aux | sort -nrk 3,3 | head -10  # CPU hogs
sudo ps aux | sort -nrk 4,4 | head -10  # Memory hogs

# 2. Check active connections
sudo ss -tupan | grep ESTABLISHED | wc -l

# 3. Check for backup processes
ps aux | grep -iE "(backup|mysqldump|rsync|tar)" | grep -v grep

# 4. Check disk I/O
sudo iotop -b -n 1 | head -20

# 5. Check PHP-FPM
sudo systemctl status php*-fpm
curl -s http://localhost/fpm-status

# 6. Check MySQL
mysql -e "SHOW PROCESSLIST;" | head -20

# 7. Quick restart (last resort)
# sudo systemctl restart php*-fpm
# sudo systemctl restart nginx
```

## 📋 Test Execution Checklist

### Before Starting Tests
- [ ] Backup current configuration
- [ ] Document baseline metrics
- [ ] Schedule during low-traffic period
- [ ] Notify relevant stakeholders
- [ ] Prepare rollback plan

### During Testing
- [ ] Monitor system resources continuously
- [ ] Document any anomalies immediately
- [ ] Take snapshots before major changes
- [ ] Keep error logs open for review
- [ ] Have SSH sessions ready for quick response

### After Testing
- [ ] Compare results with baseline
- [ ] Document findings in results/
- [ ] Update test parameters if needed
- [ ] Archive logs and metrics
- [ ] Share results with team

## 🎓 Test Priority Matrix

| Priority | Test ID | Test Name | Impact | Duration |
|----------|---------|-----------|--------|----------|
| 🔴 Critical | BT-003 | Database Backup I/O Impact | High | 10 min |
| 🔴 Critical | ST-001 | PHP-FPM Pool Exhaustion | High | 15 min |
| 🔴 Critical | VT-002 | Morning Window Stress | High | 15 min |
| 🟡 High | DT-001 | Slow Query Identification | Medium | 20 min |
| 🟡 High | NT-002 | Bandwidth Saturation | Medium | 10 min |
| 🟢 Medium | BT-002 | Backup Window Overlap | Low | 5 min |

## 💡 Pro Tips

1. **Always run baseline first** - You can't measure improvement without knowing where you started
2. **Test one thing at a time** - Isolate variables for accurate diagnosis
3. **Document everything** - Future you will thank present you
4. **Use version control** - Track configuration changes with git
5. **Schedule wisely** - Run invasive tests during maintenance windows
6. **Monitor continuously** - Set up persistent monitoring, not just test-time
7. **Compare apples to apples** - Ensure test conditions are consistent
8. **Keep stakeholders informed** - Communicate before, during, and after testing

## 🔗 Next Steps

After completing quick tests:

1. **If problems found:**
   - Review detailed test documentation in respective .md files
   - Implement fixes based on test results
   - Run validation suite

2. **If no problems found:**
   - Expand to full test suite
   - Collect extended baseline (24-48 hours)
   - Schedule automated monitoring

3. **For ongoing monitoring:**
   - Set up uptime-monitor service (validation-tests.md VT-004)
   - Schedule daily health checks
   - Create alerting for critical metrics

## 📚 Documentation Reference

- **Master Plan:** `test-plan.md`
- **Backup Tests:** `backup-tests.md` (6 tests)
- **Stress Tests:** `stress-tests.md` (6 tests)
- **Database Tests:** `db-tests.md` (6 tests)
- **Network Tests:** `network-tests.md` (6 tests)
- **Validation Tests:** `validation-tests.md` (6 tests)
- **Full Guide:** `README.md`

---

**Remember: Good testing is boring.** If tests are exciting, something has gone wrong. The goal is systematic, reproducible validation—not heroics.

**Test Mantra:** "Measure, don't guess. Validate, don't assume. Document, don't forget."
