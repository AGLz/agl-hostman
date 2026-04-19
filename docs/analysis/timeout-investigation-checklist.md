# Timeout Investigation Checklist
**Date:** 2025-10-22
**Analyst:** Hive Mind Analyst Agent
**Hosts:** fgsrv3, fgsrv4, fgsrv5

---

## Pre-Investigation Setup

### [ ] Phase 0: Environment Preparation
- [ ] Verify SSH access to all three hosts (fgsrv3, fgsrv4, fgsrv5)
- [ ] Confirm Tailscale connectivity and latency
- [ ] Document timezone configuration on all hosts
- [ ] Establish baseline timestamp for correlation
- [ ] Create temporary workspace: `/tmp/timeout-investigation-$(date +%Y%m%d)`
- [ ] Install required diagnostic tools if missing:
  ```bash
  apt-get install -y sysstat iotop htop atop mysql-client curl netcat-openbsd mtr
  ```

---

## Investigation Phase 1: Cron Job Analysis

### [ ] Task 1.1: Inventory All Cron Jobs
**Host: fgsrv3 (MySQL)**
- [ ] List root crontab: `crontab -l`
- [ ] List mysql user crontab: `crontab -u mysql -l 2>/dev/null`
- [ ] Check /etc/cron.d/: `ls -la /etc/cron.d/`
- [ ] Check /etc/cron.{hourly,daily,weekly,monthly}
- [ ] Document all scheduled times

**Host: fgsrv4 (nginx/PHP5)**
- [ ] List root crontab
- [ ] List www-data crontab: `crontab -u www-data -l 2>/dev/null`
- [ ] Check application-specific cron jobs
- [ ] Identify Laravel scheduler: `grep -r "artisan schedule" /etc/cron*`

**Host: fgsrv5 (nginx/Laravel)**
- [ ] List root crontab
- [ ] List www-data crontab
- [ ] Check Laravel cron: `* * * * * cd /path/to/laravel && php artisan schedule:run`
- [ ] Verify cron job paths and permissions

### [ ] Task 1.2: Analyze Cron Execution History
- [ ] Extract cron execution logs: `grep CRON /var/log/syslog | tail -500`
- [ ] Identify cron jobs running during timeout periods
- [ ] Check for long-running cron processes: `ps aux | grep cron`
- [ ] Review cron job exit codes and errors
- [ ] Document suspected problematic jobs

### [ ] Task 1.3: Timing Correlation
- [ ] Compare timeout timestamps with cron schedules
- [ ] Create timeline of cron executions vs. timeouts
- [ ] Identify overlapping execution windows
- [ ] Check for cascading job failures

**Findings:**
```
[Document findings here]
- Cron job: _________________
- Execution time: ___________
- Correlation: _____________
```

---

## Investigation Phase 2: MySQL Slow Query Analysis

### [ ] Task 2.1: Enable Slow Query Logging (fgsrv3)
- [ ] Check current status:
  ```sql
  SHOW VARIABLES LIKE 'slow_query%';
  SHOW VARIABLES LIKE 'long_query_time';
  ```
- [ ] Enable if disabled:
  ```sql
  SET GLOBAL slow_query_log = 'ON';
  SET GLOBAL long_query_time = 2;
  SET GLOBAL log_queries_not_using_indexes = 'ON';
  ```
- [ ] Verify log file location: `SHOW VARIABLES LIKE 'slow_query_log_file';`
- [ ] Check log file permissions: `ls -la /var/log/mysql/mysql-slow.log`

### [ ] Task 2.2: Parse Existing Slow Queries
- [ ] Run mysqldumpslow: `mysqldumpslow -s t -t 20 /var/log/mysql/mysql-slow.log`
- [ ] Identify queries taking >5 seconds
- [ ] Check for queries without indexes
- [ ] Document lock wait times
- [ ] Extract query patterns during timeout periods

### [ ] Task 2.3: Real-Time Connection Monitoring
- [ ] Check current connections: `SHOW FULL PROCESSLIST;`
- [ ] Monitor connection count:
  ```sql
  SHOW STATUS LIKE 'Threads_connected';
  SHOW VARIABLES LIKE 'max_connections';
  ```
- [ ] Identify locked tables: `SHOW OPEN TABLES WHERE In_use > 0;`
- [ ] Check for long-running queries:
  ```sql
  SELECT * FROM information_schema.processlist
  WHERE command != 'Sleep' AND time > 10
  ORDER BY time DESC;
  ```

### [ ] Task 2.4: Database Performance Metrics
- [ ] Query cache hit ratio:
  ```sql
  SHOW STATUS LIKE 'Qcache%';
  ```
- [ ] InnoDB buffer pool usage:
  ```sql
  SHOW STATUS LIKE 'Innodb_buffer_pool%';
  ```
- [ ] Table lock contention:
  ```sql
  SHOW STATUS LIKE 'Table_locks%';
  ```
- [ ] Temporary table creation rate:
  ```sql
  SHOW STATUS LIKE 'Created_tmp%';
  ```

**Top Slow Queries Found:**
```
1. Query: _______________________
   Execution time: ______________
   Lock time: ___________________
   Rows examined: _______________

2. Query: _______________________
   [continue...]
```

---

## Investigation Phase 3: Nginx Log Analysis

### [ ] Task 3.1: Locate and Verify Logs (fgsrv4 & fgsrv5)
- [ ] Find access logs: `grep -r "access_log" /etc/nginx/sites-enabled/`
- [ ] Find error logs: `grep -r "error_log" /etc/nginx/sites-enabled/`
- [ ] Verify log rotation: `ls -lh /var/log/nginx/*.log*`
- [ ] Check disk space for logs: `du -sh /var/log/nginx/`

### [ ] Task 3.2: Error Log Analysis
**fgsrv4 (falg.com.br):**
- [ ] Extract timeout errors:
  ```bash
  grep -E "timeout|timed out|upstream timed out" /var/log/nginx/error.log | tail -100
  ```
- [ ] Count error types: `awk '{print $9, $10, $11}' /var/log/nginx/error.log | sort | uniq -c | sort -rn`
- [ ] Find upstream failures: `grep "upstream" /var/log/nginx/error.log | grep -E "failed|timeout"`
- [ ] Check connection errors: `grep -E "connect\(\) failed|broken pipe" /var/log/nginx/error.log`

**fgsrv5 (api.falg.com.br):**
- [ ] Same analysis as fgsrv4
- [ ] Check for PHP-FPM socket errors
- [ ] Verify Laravel application errors
- [ ] Document API-specific error patterns

### [ ] Task 3.3: Access Log Pattern Analysis
- [ ] Request rate per minute:
  ```bash
  awk '{print $4}' /var/log/nginx/access.log | cut -d: -f1-3 | sort | uniq -c | sort -rn | head -30
  ```
- [ ] Status code distribution: `awk '{print $9}' /var/log/nginx/access.log | sort | uniq -c | sort -rn`
- [ ] Top requesting IPs: `awk '{print $1}' /var/log/nginx/access.log | sort | uniq -c | sort -rn | head -20`
- [ ] Most requested URLs: `awk '{print $7}' /var/log/nginx/access.log | sort | uniq -c | sort -rn | head -30`
- [ ] Identify slow requests (if request_time is logged)

### [ ] Task 3.4: Timeout Period Deep Dive
- [ ] Extract logs from specific timeout window:
  ```bash
  # Replace with actual timeout timestamp
  awk '/22\/Oct\/2025:HH:MM:/,/22\/Oct\/2025:HH:MM:/' /var/log/nginx/access.log > /tmp/timeout-window.log
  ```
- [ ] Analyze request patterns during incident
- [ ] Check for traffic spikes or DDoS patterns
- [ ] Correlate with backend errors

**Nginx Findings:**
```
Error pattern: _________________
Frequency: ____________________
Affected endpoints: ___________
```

---

## Investigation Phase 4: PHP-FPM Process Analysis

### [ ] Task 4.1: PHP-FPM Configuration Review (fgsrv4)
- [ ] Locate pool configuration: `ls -la /etc/php/*/fpm/pool.d/`
- [ ] Check process manager settings:
  ```bash
  grep -E "^pm\.|^pm " /etc/php/*/fpm/pool.d/www.conf
  ```
- [ ] Document key settings:
  - [ ] pm = dynamic/static/ondemand
  - [ ] pm.max_children = ?
  - [ ] pm.start_servers = ?
  - [ ] pm.min_spare_servers = ?
  - [ ] pm.max_spare_servers = ?
  - [ ] pm.max_requests = ?

### [ ] Task 4.2: Enable and Check Status Page
- [ ] Enable status in pool config: `pm.status_path = /status`
- [ ] Reload PHP-FPM: `systemctl reload php*-fpm`
- [ ] Access status: `curl http://localhost/status?full`
- [ ] Monitor key metrics:
  - [ ] pool: process pool name
  - [ ] process manager: dynamic/static/ondemand
  - [ ] accepted conn: total connections
  - [ ] listen queue: pending requests (should be 0)
  - [ ] idle processes: available workers
  - [ ] active processes: currently processing

### [ ] Task 4.3: Process Monitoring
- [ ] Count PHP-FPM processes: `ps aux | grep php-fpm | wc -l`
- [ ] Check memory per process:
  ```bash
  ps aux | grep php-fpm | awk '{sum+=$6} END {print "Total Memory (KB):", sum}'
  ```
- [ ] Find long-running PHP processes:
  ```bash
  ps aux | grep php-fpm | awk '{if($10 > 60) print $0}'
  ```
- [ ] Check PHP-FPM error log: `tail -100 /var/log/php*-fpm.log`

### [ ] Task 4.4: Identify Resource Exhaustion
- [ ] Check for "max_children reached" warnings:
  ```bash
  grep "max_children" /var/log/php*-fpm.log | tail -50
  ```
- [ ] Look for memory limit errors:
  ```bash
  grep "Allowed memory size" /var/log/php*-fpm.log
  ```
- [ ] Check for script timeouts:
  ```bash
  grep -E "max_execution_time|execution timeout" /var/log/php*-fpm.log
  ```

**PHP-FPM Status:**
```
Pool: _______________________
Process manager: ____________
Max children: _______________
Active processes: ___________
Idle processes: _____________
Listen queue: _______________
Max children reached: _______
```

---

## Investigation Phase 5: Network Latency Testing

### [ ] Task 5.1: Inter-Server Latency Baseline
**From fgsrv4 to fgsrv3 (MySQL):**
- [ ] ICMP ping test: `ping -c 100 fgsrv3 | tail -3`
- [ ] TCP port test: `time nc -zv fgsrv3 3306`
- [ ] MTU discovery: `tracepath fgsrv3`
- [ ] Document baseline latency: min/avg/max/mdev

**From fgsrv5 to fgsrv3 (MySQL):**
- [ ] Same tests as above
- [ ] Compare latency differences between fgsrv4 and fgsrv5

### [ ] Task 5.2: MySQL Connection Timing
- [ ] Test connection establishment time:
  ```bash
  time mysql -h fgsrv3 -u testuser -p -e "SELECT 1;"
  ```
- [ ] Run multiple iterations (10x) and document variance
- [ ] Test during different times of day
- [ ] Correlate slow connection times with timeout events

### [ ] Task 5.3: Route and Network Path Analysis
- [ ] Trace route to MySQL server: `mtr --report --report-cycles 100 fgsrv3`
- [ ] Check for packet loss: `netstat -s | grep -E "segments retransmitted|packets lost"`
- [ ] Monitor TCP connection states: `ss -tan | awk '{print $1}' | sort | uniq -c`
- [ ] Verify network interface errors: `ip -s link`

### [ ] Task 5.4: DNS Resolution Performance
- [ ] Test DNS lookup time:
  ```bash
  time dig falg.com.br
  time dig api.falg.com.br
  time dig fgsrv3
  ```
- [ ] Check DNS configuration: `cat /etc/resolv.conf`
- [ ] Verify Tailscale DNS: `resolvectl status`

**Network Metrics:**
```
fgsrv4 → fgsrv3:
  Ping latency: min/avg/max = ___/___/___ms
  MySQL connection: _________ms
  Packet loss: ______________%

fgsrv5 → fgsrv3:
  Ping latency: min/avg/max = ___/___/___ms
  MySQL connection: _________ms
  Packet loss: ______________%
```

---

## Investigation Phase 6: Resource Utilization Baselines

### [ ] Task 6.1: Deploy Baseline Collection Scripts
- [ ] Copy baseline script to all hosts
- [ ] Execute on fgsrv3: `bash /tmp/collect-baseline.sh`
- [ ] Execute on fgsrv4: `bash /tmp/collect-baseline.sh`
- [ ] Execute on fgsrv5: `bash /tmp/collect-baseline.sh`
- [ ] Verify output directories created
- [ ] Download metrics to central location for analysis

### [ ] Task 6.2: CPU and Load Analysis
**All hosts:**
- [ ] Current load: `uptime`
- [ ] CPU usage: `top -bn1 | head -20`
- [ ] Process CPU hogs: `ps aux --sort=-%cpu | head -20`
- [ ] Load average trends: `sar -q 1 60`
- [ ] Document CPU steal time (VM overhead): `sar -u 1 60 | grep steal`

### [ ] Task 6.3: Memory Analysis
**All hosts:**
- [ ] Memory usage: `free -h`
- [ ] Swap usage: `swapon --show`
- [ ] Memory-heavy processes: `ps aux --sort=-%mem | head -20`
- [ ] Check for OOM killer events: `grep -i "out of memory" /var/log/syslog`
- [ ] Virtual memory stats: `vmstat 1 60`

### [ ] Task 6.4: Disk I/O Analysis
**All hosts:**
- [ ] Disk usage: `df -h`
- [ ] Inode usage: `df -i`
- [ ] Disk I/O stats: `iostat -x 1 60`
- [ ] Identify high I/O processes: `iotop -b -n 10`
- [ ] Check for disk errors: `dmesg | grep -i "i/o error"`

### [ ] Task 6.5: Network Connection Analysis
**All hosts:**
- [ ] Connection summary: `ss -s`
- [ ] Established connections: `ss -tan | grep ESTAB | wc -l`
- [ ] TIME-WAIT connections: `ss -tan | grep TIME-WAIT | wc -l`
- [ ] Per-state distribution: `ss -tan | awk '{print $1}' | sort | uniq -c`
- [ ] Open file descriptors: `lsof | wc -l`
- [ ] System limits: `ulimit -a`

**Resource Summary:**
```
fgsrv3 (MySQL):
  Load: 1/5/15 min = ___/___/___
  Memory: _____% used, _____% swap
  Disk I/O: await = _____ms
  Connections: _____ total

fgsrv4 (nginx/PHP5):
  Load: 1/5/15 min = ___/___/___
  Memory: _____% used, _____% swap
  Disk I/O: await = _____ms
  Connections: _____ total

fgsrv5 (nginx/Laravel):
  Load: 1/5/15 min = ___/___/___
  Memory: _____% used, _____% swap
  Disk I/O: await = _____ms
  Connections: _____ total
```

---

## Investigation Phase 7: Correlation and Pattern Analysis

### [ ] Task 7.1: Build Timeout Timeline
- [ ] List all timeout incidents with timestamps
- [ ] Create chronological event sequence
- [ ] Document duration of each timeout
- [ ] Identify pattern: daily, hourly, random?
- [ ] Note affected services during each timeout

**Timeline:**
```
Incident 1: [Date Time] - Duration: ___min - Affected: ___________
Incident 2: [Date Time] - Duration: ___min - Affected: ___________
[continue...]
```

### [ ] Task 7.2: Cross-Reference Events
- [ ] Overlay cron job execution times on timeline
- [ ] Overlay MySQL slow query times on timeline
- [ ] Overlay nginx error spikes on timeline
- [ ] Overlay resource spikes (CPU/memory/I/O) on timeline
- [ ] Overlay network latency increases on timeline

### [ ] Task 7.3: Identify Correlations
- [ ] Calculate correlation coefficient for each potential cause
- [ ] Rank causes by correlation strength
- [ ] Document coincidences vs. causations
- [ ] Identify primary, secondary, and tertiary factors

**Correlation Matrix:**
```
Event Type         | Correlation | Strength | Notes
-------------------|-------------|----------|------------------
Cron job X         | 95%         | High     | Always precedes timeout
MySQL query Y      | 80%         | High     | Occurs during timeout
Nginx error Z      | 60%         | Medium   | Coincidental?
Network spike      | 30%         | Low      | Unrelated
[continue...]
```

### [ ] Task 7.4: Formulate Hypotheses
Based on correlations, list top 3 hypotheses:

1. **Hypothesis 1:**
   - Suspected cause: _________________
   - Supporting evidence: _____________
   - Test method: ____________________

2. **Hypothesis 2:**
   - Suspected cause: _________________
   - Supporting evidence: _____________
   - Test method: ____________________

3. **Hypothesis 3:**
   - Suspected cause: _________________
   - Supporting evidence: _____________
   - Test method: ____________________

---

## Investigation Phase 8: Hypothesis Testing

### [ ] Task 8.1: Controlled Testing Environment
- [ ] Identify safe testing window (low traffic period)
- [ ] Create rollback plan for each test
- [ ] Document baseline metrics before testing
- [ ] Notify stakeholders of testing schedule

### [ ] Task 8.2: Test Hypothesis 1
- [ ] Execute test scenario
- [ ] Monitor for timeout occurrence
- [ ] Collect metrics during test
- [ ] Compare with baseline
- [ ] Document results: Confirmed / Refuted / Inconclusive

### [ ] Task 8.3: Test Hypothesis 2
- [ ] Same process as Task 8.2

### [ ] Task 8.4: Test Hypothesis 3
- [ ] Same process as Task 8.2

**Test Results:**
```
Hypothesis 1: [Confirmed/Refuted/Inconclusive]
Evidence: _______________________________

Hypothesis 2: [Confirmed/Refuted/Inconclusive]
Evidence: _______________________________

Hypothesis 3: [Confirmed/Refuted/Inconclusive]
Evidence: _______________________________
```

---

## Investigation Phase 9: Root Cause Confirmation

### [ ] Task 9.1: Reproduce Timeout
- [ ] Recreate conditions that trigger timeout
- [ ] Monitor all metrics during reproduction
- [ ] Capture detailed logs and traces
- [ ] Confirm timeout occurs predictably

### [ ] Task 9.2: Verify Causation Chain
- [ ] Document step-by-step causation:
  1. Initial trigger: _________________
  2. Cascading effect: _______________
  3. System response: ________________
  4. Timeout manifestation: __________
- [ ] Verify each step with evidence
- [ ] Eliminate alternative explanations

### [ ] Task 9.3: Quantify Impact
- [ ] Timeout frequency: _____ per day/week
- [ ] Average duration: _____ minutes
- [ ] Affected users: _____ concurrent users
- [ ] Business impact: revenue/reputation
- [ ] Urgency rating: Critical/High/Medium/Low

**Root Cause Statement:**
```
The timeout issues are caused by:
_____________________________________________
_____________________________________________

This occurs when:
_____________________________________________

The impact is:
_____________________________________________

Confidence level: _____% (based on evidence)
```

---

## Investigation Phase 10: Solution Recommendations

### [ ] Task 10.1: Immediate Fixes (within 24 hours)
1. [ ] Fix 1: _______________________
   - Implementation steps: __________
   - Expected result: _______________
   - Rollback plan: _________________

2. [ ] Fix 2: _______________________
   [continue...]

### [ ] Task 10.2: Short-Term Improvements (within 1 week)
1. [ ] Improvement 1: _______________
2. [ ] Improvement 2: _______________
3. [ ] Improvement 3: _______________

### [ ] Task 10.3: Long-Term Solutions (within 1 month)
1. [ ] Solution 1: __________________
2. [ ] Solution 2: __________________
3. [ ] Solution 3: __________________

### [ ] Task 10.4: Monitoring and Alerting
- [ ] Define SLO/SLA thresholds
- [ ] Set up proactive monitoring:
  - [ ] MySQL slow query alerts
  - [ ] Nginx error rate alerts
  - [ ] PHP-FPM process pool alerts
  - [ ] Network latency alerts
  - [ ] Resource utilization alerts
- [ ] Create runbook for future incidents
- [ ] Document escalation procedures

---

## Post-Investigation Tasks

### [ ] Documentation
- [ ] Complete analysis report (see diagnostic-framework.md)
- [ ] Update runbook with findings
- [ ] Document all scripts and commands used
- [ ] Create knowledge base article
- [ ] Share findings with team

### [ ] Knowledge Transfer
- [ ] Present findings to stakeholders
- [ ] Train team on monitoring procedures
- [ ] Update incident response playbook
- [ ] Schedule post-mortem meeting

### [ ] Continuous Improvement
- [ ] Implement automated monitoring
- [ ] Set up recurring health checks
- [ ] Schedule quarterly reviews
- [ ] Track metrics over time

---

## Checklist Summary

**Total Tasks:** ~100
**Estimated Time:** 24-48 hours (depending on complexity)

**Phase Completion Status:**
- [ ] Phase 0: Pre-Investigation (0/6 tasks)
- [ ] Phase 1: Cron Jobs (0/12 tasks)
- [ ] Phase 2: MySQL (0/16 tasks)
- [ ] Phase 3: Nginx (0/12 tasks)
- [ ] Phase 4: PHP-FPM (0/16 tasks)
- [ ] Phase 5: Network (0/12 tasks)
- [ ] Phase 6: Resources (0/15 tasks)
- [ ] Phase 7: Correlation (0/12 tasks)
- [ ] Phase 8: Testing (0/8 tasks)
- [ ] Phase 9: Confirmation (0/9 tasks)
- [ ] Phase 10: Solutions (0/12 tasks)
- [ ] Post-Investigation (0/8 tasks)

**Overall Progress: 0% (0/138 tasks completed)**

---

**Next Steps:**
1. Begin Phase 0: Environment Preparation
2. Execute Phase 1: Cron Job Analysis
3. Update checklist as tasks are completed
4. Store findings in shared memory: `hive/analyst/*`

---

*Checklist created: 2025-10-22*
*Analyst: Hive Mind Analyst Agent*
*Status: Ready for execution*
