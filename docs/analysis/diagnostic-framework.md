# VPS Timeout Diagnostic Framework
**Analysis Date:** 2025-10-22
**Analyst:** Hive Mind Analyst Agent
**Scope:** fgsrv3, fgsrv4, fgsrv5 timeout root cause investigation

---

## Executive Summary

This framework provides systematic investigation methodology for identifying timeout root causes across three production VPS hosts experiencing intermittent connectivity issues.

### Target Hosts
- **fgsrv3**: MySQL database server
- **fgsrv4**: nginx/PHP5 web server (https://falg.com.br)
- **fgsrv5**: nginx/Laravel API server (https://api.falg.com.br)

---

## 1. Cron Jobs Analysis Checklist

### 1.1 Initial Investigation
```bash
# List all cron jobs for all users
for user in $(cut -f1 -d: /etc/passwd); do
  echo "=== Cron jobs for $user ==="
  crontab -u $user -l 2>/dev/null || echo "No crontab for $user"
done

# Check system-wide cron jobs
ls -la /etc/cron.{hourly,daily,weekly,monthly}
cat /etc/crontab
ls -la /etc/cron.d/
```

### 1.2 Timing Correlation Matrix
| Check | Command | Purpose |
|-------|---------|---------|
| Execution logs | `grep CRON /var/log/syslog` | Identify cron execution patterns |
| Timing conflicts | Compare cron schedules with timeout timestamps | Find correlation |
| Resource spikes | Cross-reference with system metrics during cron runs | Detect resource exhaustion |
| Lock contention | Check for database locks during scheduled jobs | MySQL blocking queries |

### 1.3 High-Risk Cron Patterns
- **Database backups** during peak hours
- **Log rotation** without rate limiting
- **Batch processing** jobs without timeout controls
- **Email queue processing** that could overwhelm SMTP
- **File cleanup** operations on mounted volumes

### 1.4 Diagnostic Queries
```bash
# Find resource-intensive cron jobs
ps aux | grep cron | grep -v grep

# Check cron job execution history
journalctl -u cron --since "24 hours ago" --no-pager

# Identify long-running cron processes
ps -eo pid,etime,cmd | grep -E 'cron|CRON' | awk '$2 ~ /-/ || $2 ~ /[0-9]{2}:[0-9]{2}:[0-9]{2}/'
```

---

## 2. MySQL Slow Query Log Analysis

### 2.1 Enable Slow Query Logging (fgsrv3)
```sql
-- Check current slow query log status
SHOW VARIABLES LIKE 'slow_query%';
SHOW VARIABLES LIKE 'long_query_time';

-- Enable if not active
SET GLOBAL slow_query_log = 'ON';
SET GLOBAL long_query_time = 2;  -- queries taking >2 seconds
SET GLOBAL log_queries_not_using_indexes = 'ON';
```

### 2.2 Analysis Commands
```bash
# Location of slow query log
mysql -e "SHOW VARIABLES LIKE 'slow_query_log_file';"

# Parse slow query log
mysqldumpslow -s t -t 10 /var/log/mysql/mysql-slow.log

# Detailed analysis with pt-query-digest (Percona Toolkit)
pt-query-digest /var/log/mysql/mysql-slow.log > /tmp/slow-query-analysis.txt
```

### 2.3 Critical Metrics to Track
| Metric | Threshold | Investigation Trigger |
|--------|-----------|----------------------|
| Query execution time | >5 seconds | Immediate optimization required |
| Lock wait time | >2 seconds | Check for table lock contention |
| Rows examined | >100,000 | Missing or inefficient indexes |
| Queries not using indexes | Any | Index optimization needed |
| Temporary table creation | >10% of queries | Schema/query optimization |

### 2.4 Real-Time Monitoring
```sql
-- Show currently running queries
SHOW FULL PROCESSLIST;

-- Show queries running longer than 5 seconds
SELECT * FROM information_schema.processlist
WHERE command != 'Sleep' AND time > 5
ORDER BY time DESC;

-- Show locked tables
SHOW OPEN TABLES WHERE In_use > 0;

-- Check connection count
SHOW STATUS LIKE 'Threads_connected';
SHOW VARIABLES LIKE 'max_connections';
```

### 2.5 Query Pattern Analysis
```bash
# Extract unique query patterns
awk '/Query_time/ {qt=$3} /User@Host/ {user=$3} /^SET timestamp/ {ts=$4} /^SELECT|^UPDATE|^INSERT|^DELETE/ {print ts, qt, user, $0}' /var/log/mysql/mysql-slow.log | sort -k2 -rn | head -20

# Count queries by type
grep -oE "^(SELECT|UPDATE|INSERT|DELETE)" /var/log/mysql/mysql-slow.log | sort | uniq -c | sort -rn
```

---

## 3. Nginx Access/Error Log Investigation Strategy

### 3.1 Log File Locations
```bash
# Default nginx log locations
/var/log/nginx/access.log
/var/log/nginx/error.log

# Virtual host specific logs (check nginx config)
grep -r "access_log\|error_log" /etc/nginx/sites-enabled/
```

### 3.2 Error Log Analysis (fgsrv4, fgsrv5)
```bash
# Identify timeout errors
grep -E "timeout|timed out|upstream timed out" /var/log/nginx/error.log

# Count error types
awk '{print $9, $10, $11}' /var/log/nginx/error.log | sort | uniq -c | sort -rn | head -20

# Find 5xx errors
grep " 5[0-9][0-9] " /var/log/nginx/error.log

# Upstream failures
grep "upstream" /var/log/nginx/error.log | grep -E "failed|timeout|timed out"

# Connection issues
grep -E "connect\(\) failed|broken pipe|reset by peer" /var/log/nginx/error.log
```

### 3.3 Access Log Patterns
```bash
# Request rate per minute (detect spikes)
awk '{print $4}' /var/log/nginx/access.log | cut -d: -f1-3 | sort | uniq -c | sort -rn | head -20

# Slowest requests (if $request_time is logged)
awk '$NF > 5 {print $0}' /var/log/nginx/access.log | tail -50

# Status code distribution
awk '{print $9}' /var/log/nginx/access.log | sort | uniq -c | sort -rn

# Top IP addresses (potential DDoS/attacks)
awk '{print $1}' /var/log/nginx/access.log | sort | uniq -c | sort -rn | head -20

# Top requested URLs during timeout periods
awk '{print $7}' /var/log/nginx/access.log | sort | uniq -c | sort -rn | head -30
```

### 3.4 Correlation with Timeout Events
```bash
# Extract logs during specific timeout period
awk '/16\/Oct\/2025:14:30:/,/16\/Oct\/2025:15:00:/' /var/log/nginx/access.log > /tmp/timeout-period.log

# Analyze request patterns during incident
cat /tmp/timeout-period.log | awk '{print $7}' | sort | uniq -c | sort -rn
```

---

## 4. PHP-FPM Process Monitoring Methodology

### 4.1 PHP-FPM Status Page (fgsrv4)
```bash
# Enable status page in PHP-FPM pool config
# /etc/php/7.x/fpm/pool.d/www.conf
# pm.status_path = /status

# Access status via nginx
curl http://localhost/status?full&json

# Key metrics to monitor
curl http://localhost/status | grep -E "idle processes|active processes|total processes"
```

### 4.2 Process Pool Analysis
```bash
# Check PHP-FPM process count
ps aux | grep php-fpm | wc -l

# Identify long-running PHP processes
ps aux | grep php-fpm | awk '{if($10 > 60) print $0}'

# Check PHP-FPM error log
tail -f /var/log/php7.x-fpm.log

# Monitor pool configuration
grep -E "pm\.|php_admin" /etc/php/7.x/fpm/pool.d/*.conf
```

### 4.3 Critical PHP-FPM Metrics
| Metric | Command | Alert Threshold |
|--------|---------|----------------|
| Active processes | `systemctl status php-fpm` | >80% of pm.max_children |
| Slow requests | Check slow log | Any >5 seconds |
| Queue length | Status page `listen queue` | >0 indicates saturation |
| Memory usage | `ps aux \| grep php-fpm` | >90% of available RAM |
| Max children reached | PHP-FPM log | Repeated warnings |

### 4.4 Resource Exhaustion Detection
```bash
# Check if PHP-FPM is hitting process limits
grep "max_children" /var/log/php*-fpm.log

# Memory usage per PHP process
ps aux | grep php-fpm | awk '{sum+=$6} END {print "Total PHP-FPM Memory (KB):", sum}'

# Identify memory-hungry scripts
grep "Allowed memory size" /var/log/php*-fpm.log

# Check for script timeouts
grep "max_execution_time\|timeout" /var/log/php*-fpm.log
```

---

## 5. Network Latency Measurement Strategy

### 5.1 Baseline Latency Testing
```bash
# Test latency to database server (from fgsrv4/fgsrv5 to fgsrv3)
ping -c 100 fgsrv3 | tail -1

# Continuous monitoring with timestamps
ping fgsrv3 | while read line; do echo "$(date '+%Y-%m-%d %H:%M:%S') $line"; done

# MTU path discovery
tracepath fgsrv3

# TCP connection time to MySQL port
time nc -zv fgsrv3 3306
```

### 5.2 Network Performance Metrics
```bash
# Install mtr for continuous route analysis
mtr --report --report-cycles 100 fgsrv3 > /tmp/mtr-fgsrv3.txt

# Check network interface statistics
netstat -i
ip -s link

# Monitor packet loss
watch -n 1 'netstat -s | grep -E "segments retransmitted|segments send out"'

# TCP connection states
ss -s
ss -tan | awk '{print $1}' | sort | uniq -c
```

### 5.3 DNS Resolution Analysis
```bash
# Test DNS resolution time
time dig falg.com.br
time dig api.falg.com.br

# Check DNS configuration
cat /etc/resolv.conf

# Monitor DNS query performance
tcpdump -i any port 53 -n
```

### 5.4 Inter-Server Communication
```bash
# Test MySQL connection latency
time mysql -h fgsrv3 -u user -p -e "SELECT 1;"

# HTTP request timing
curl -w "@curl-format.txt" -o /dev/null -s http://api.falg.com.br/health

# Create curl-format.txt
cat > /tmp/curl-format.txt << 'EOF'
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

---

## 6. Resource Utilization Baseline Metrics

### 6.1 System Resource Collection
```bash
# CPU usage over time
sar -u 1 60

# Memory utilization
free -h
vmstat 1 10

# Disk I/O statistics
iostat -x 1 10

# Disk usage
df -h
du -sh /var/log/* | sort -rh

# Open file descriptors
lsof | wc -l
ulimit -n

# Network connections
ss -s
netstat -an | wc -l
```

### 6.2 Continuous Monitoring Setup
```bash
# Install monitoring tools if not present
apt-get install -y sysstat iotop htop atop

# Enable sysstat data collection
systemctl enable sysstat
systemctl start sysstat

# Collect baseline metrics
atop -w /tmp/atop-baseline.log 60 1440  # 24 hours, 60-second intervals
```

### 6.3 Critical Thresholds
| Resource | Metric | Warning | Critical |
|----------|--------|---------|----------|
| CPU | Load average | >2.0 (1min) | >4.0 |
| Memory | Used % | >80% | >95% |
| Swap | Usage | >10% | >50% |
| Disk I/O | Await time | >20ms | >100ms |
| Disk Space | Used % | >80% | >95% |
| Network | Dropped packets | >0.1% | >1% |
| Connections | ESTABLISHED | >5000 | >10000 |

### 6.4 Automated Baseline Collection Script
```bash
#!/bin/bash
# Save as /tmp/collect-baseline.sh

OUTPUT_DIR="/tmp/baseline-metrics-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$OUTPUT_DIR"

echo "Collecting baseline metrics to $OUTPUT_DIR"

# System info
uname -a > "$OUTPUT_DIR/system-info.txt"
uptime > "$OUTPUT_DIR/uptime.txt"

# CPU
top -bn1 > "$OUTPUT_DIR/top-snapshot.txt"
sar -u 1 60 > "$OUTPUT_DIR/cpu-usage.txt" &

# Memory
free -h > "$OUTPUT_DIR/memory-snapshot.txt"
vmstat 1 60 > "$OUTPUT_DIR/vmstat.txt" &

# Disk
df -h > "$OUTPUT_DIR/disk-usage.txt"
iostat -x 1 60 > "$OUTPUT_DIR/disk-io.txt" &

# Network
ss -s > "$OUTPUT_DIR/network-summary.txt"
netstat -s > "$OUTPUT_DIR/network-stats.txt"
ip -s link > "$OUTPUT_DIR/interface-stats.txt"

# Processes
ps aux --sort=-%cpu | head -50 > "$OUTPUT_DIR/top-cpu-processes.txt"
ps aux --sort=-%mem | head -50 > "$OUTPUT_DIR/top-mem-processes.txt"

# Services
systemctl list-units --type=service --state=running > "$OUTPUT_DIR/running-services.txt"

echo "Waiting for metric collection to complete (60 seconds)..."
wait

echo "Baseline metrics collected in $OUTPUT_DIR"
```

---

## 7. Root Cause Analysis Workflow

### Phase 1: Data Collection (Hours 0-2)
1. Deploy baseline collection script on all three hosts
2. Enable MySQL slow query logging
3. Configure nginx detailed logging with request_time
4. Set up PHP-FPM status monitoring
5. Document current cron schedules

### Phase 2: Pattern Identification (Hours 2-6)
1. Correlate timeout timestamps with:
   - Cron job execution times
   - MySQL slow queries
   - Nginx error spikes
   - PHP-FPM process saturation
   - Network latency increases
2. Identify recurring patterns (daily, hourly, specific times)
3. Map dependencies between hosts

### Phase 3: Hypothesis Testing (Hours 6-12)
1. Test identified patterns:
   - Disable suspected cron jobs temporarily
   - Optimize identified slow queries
   - Adjust PHP-FPM pool configuration
   - Implement connection pooling if needed
2. Monitor for timeout recurrence
3. Validate or refute hypotheses

### Phase 4: Root Cause Confirmation (Hours 12-24)
1. Reproduce timeout conditions in controlled manner
2. Confirm correlation between identified cause and timeouts
3. Document causation chain
4. Propose remediation strategy

### Phase 5: Resolution Implementation (Hours 24-48)
1. Implement permanent fixes based on confirmed root cause
2. Deploy monitoring for early warning
3. Create runbook for future incidents
4. Document lessons learned

---

## 8. Shared Memory Coordination Keys

For Hive Mind worker coordination:

```
hive/analyst/baseline-collected      - Timestamp when baseline metrics collected
hive/analyst/mysql-slow-queries      - List of identified slow queries
hive/analyst/nginx-error-patterns    - Categorized nginx error patterns
hive/analyst/cron-schedule           - Complete cron job inventory
hive/analyst/timeout-timeline        - Chronological timeout event log
hive/analyst/correlation-matrix      - Event correlation findings
hive/analyst/hypotheses              - Current working hypotheses
hive/analyst/root-cause-confirmed    - Final root cause determination
```

---

## 9. Investigation Commands Quick Reference

### Immediate Triage (First 5 minutes)
```bash
# Check if hosts are responsive
ping -c 5 fgsrv3 && ping -c 5 fgsrv4 && ping -c 5 fgsrv5

# Check service status
ssh fgsrv3 "systemctl status mysql"
ssh fgsrv4 "systemctl status nginx php7.*-fpm"
ssh fgsrv5 "systemctl status nginx"

# Quick load check
ssh fgsrv3 "uptime && free -h"
ssh fgsrv4 "uptime && free -h"
ssh fgsrv5 "uptime && free -h"

# Recent errors
ssh fgsrv3 "tail -50 /var/log/mysql/error.log"
ssh fgsrv4 "tail -50 /var/log/nginx/error.log"
ssh fgsrv5 "tail -50 /var/log/nginx/error.log"
```

### Deep Dive Analysis (Next 30 minutes)
```bash
# Deploy baseline collection
for host in fgsrv3 fgsrv4 fgsrv5; do
  scp /tmp/collect-baseline.sh $host:/tmp/
  ssh $host "bash /tmp/collect-baseline.sh"
done

# Collect logs during last timeout
# (Replace timestamp with actual timeout time)
ssh fgsrv4 "awk '/21\/Oct\/2025:14:30:/,/21\/Oct\/2025:15:00:/' /var/log/nginx/access.log"

# Check database connections during timeout
ssh fgsrv3 "grep 'connect' /var/log/mysql/mysql.log | tail -100"
```

---

## 10. Expected Deliverables

### Analysis Report Structure
1. **Executive Summary**: One-paragraph root cause statement
2. **Timeline**: Chronological event sequence during timeout
3. **Evidence**: Log excerpts, metrics, and correlation data
4. **Root Cause Analysis**: Detailed causation explanation
5. **Impact Assessment**: Affected services and user impact
6. **Remediation Plan**: Short-term fixes and long-term solutions
7. **Prevention Strategy**: Monitoring and alerting recommendations
8. **Appendices**: Raw data, full logs, configuration files

### Metrics Dashboard
- Timeout frequency and duration trends
- Resource utilization graphs (CPU, memory, I/O, network)
- Service response time distributions
- Error rate patterns
- Database query performance trends

### Action Items
- Immediate fixes (within 24 hours)
- Short-term improvements (within 1 week)
- Long-term architecture changes (within 1 month)
- Monitoring enhancements
- Documentation updates

---

## Contact & Coordination

**Primary Analyst**: Hive Mind Analyst Agent
**Memory Namespace**: `hive/analyst/*`
**Status Updates**: Via `npx claude-flow@alpha hooks notify`
**Findings Repository**: `/docs/analysis/findings/`

---

**Framework Version**: 1.0
**Last Updated**: 2025-10-22
**Next Review**: Upon root cause confirmation
