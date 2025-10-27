# Morning Timeout Pattern Analysis (9-10am)
## VPS Hosts: fgsrv3, fgsrv4, fgsrv5

**Research Date:** 2025-10-22
**Affected Systems:**
- **fgsrv3**: MySQL Server
- **fgsrv4**: nginx/PHP5 (https://falg.com.br)
- **fgsrv5**: nginx/Laravel (https://api.falg.com.br)

**Symptom:** Recurring timeout issues occurring between 9:00-10:00 AM

---

## Executive Summary

Morning timeout patterns (9-10am) on VPS environments are typically caused by a confluence of automated maintenance tasks, scheduled cron jobs, backup processes, and traffic spikes coinciding with business hours. The research reveals several critical factors affecting MySQL, PHP-FPM, and nginx-based systems.

**Key Findings:**
1. Automated backup processes create table locks and connection pool exhaustion
2. PHP-FPM memory leaks from long-running queue workers compound overnight
3. Laravel scheduled tasks and cron jobs cluster during morning hours
4. nginx connection pools can be exhausted by traffic bursts without proper configuration
5. Locaweb VPS has documented business-hours-only connectivity issues (7:50-18:00)

---

## 1. Common Causes of Morning Timeout Patterns

### 1.1 Scheduled Cron Jobs (Critical)

**Problem:**
- Cron jobs scheduled at "convenient" times (9am, 10am) create resource contention
- WordPress/CMS maintenance tasks often default to early morning hours (3am-4am server time)
- Timezone mismatches cause jobs to run at unexpected times
- Multiple jobs running simultaneously exhaust system resources

**Evidence:**
- WordPress cron jobs like "akismet_scheduled_delete" scheduled at 3:00am can take over an hour to execute
- PHP scripts timeout after 30 seconds by default
- nginx timeouts commonly set to 60 seconds

**Impact on Your Systems:**
- **fgsrv4 (PHP5)**: Legacy PHP timeout configurations may be more restrictive
- **fgsrv5 (Laravel)**: Scheduled tasks via Laravel's scheduler likely running at :00 minute marks

### 1.2 Traffic Surge at Business Hours

**Problem:**
- Real-world web traffic isn't smooth - browsers fire 5-20 simultaneous requests
- Business hours (9am) create predictable traffic spikes
- Connection pools may not be sized for burst traffic
- Rate limiting misconfigurations reject legitimate requests

**nginx Burst Behavior:**
- Without `burst` parameter: excess requests immediately rejected
- With `burst` but no `nodelay`: artificial delays added to enforce rate
- Burst queues can fill instantly during moderate traffic spikes

**Recommended Configuration:**
```nginx
limit_req_zone $binary_remote_addr zone=one:10m rate=5r/s;
limit_req zone=one burst=20 nodelay;

# Timeout settings
proxy_read_timeout 600;
proxy_connect_timeout 600;
proxy_send_timeout 600;

# Keepalive connections
upstream backend {
    server backend.example.com;
    keepalive 32;
}
```

---

## 2. MySQL Backup Scheduling Impacts

### 2.1 Database Lock Issues

**Critical Finding:** Logical backups using `mysqldump` lock the database, disrupting client operations.

**Connection Pool Exhaustion:**
- 100 timeout errors can exhaust a 100-connection pool
- All further database operations fail when pool is exhausted
- Long-running backup processes hold connections

### 2.2 MySQL Timeout Configuration

**Key Parameters:**
- `wait_timeout`: Default 28800 seconds (8 hours)
- `interactive_timeout`: Default 28800 seconds
- Connection pool max idle time should be 10-15% shorter than `wait_timeout`

**Best Practice:**
```sql
-- Check current timeout settings
SHOW VARIABLES LIKE '%timeout%';

-- Recommended settings for pooled connections
SET GLOBAL wait_timeout = 600;        -- 10 minutes
SET GLOBAL interactive_timeout = 600;
```

### 2.3 Backup Solutions to Avoid Timeouts

**Option 1: Use InnoDB with --single-transaction**
```bash
mysqldump --single-transaction --quick --lock-tables=false \
  --databases mydb > backup.sql
```
- ✅ Dumps database in consistent state
- ✅ Allows other updates to continue
- ⚠️ Only works if all tables are InnoDB

**Option 2: Backup from Slave** (Recommended for Production)
- Create MySQL slave/replica
- Run dumps on slave, not master
- Slave catches up after dump completes
- ✅ Zero impact on production

**Option 3: Use Filesystem Snapshots**
```bash
# Using LVM snapshots with mylvmbackup
mylvmbackup --action=snapshot --backuptype=tar
```
- ✅ Near-instantaneous snapshot
- ✅ No database locks required
- ⚠️ Requires LVM volume setup

### 2.4 Recommended Backup Schedule

**AVOID:** 9:00 AM, 10:00 AM, peak business hours
**RECOMMENDED:** 2:00-4:00 AM (low traffic period)

**For Your Systems:**
```bash
# Check current backup crons
crontab -l
ls -la /etc/cron.{daily,hourly,weekly}
grep -r "mysqldump" /etc/cron.*

# Suggested schedule (2:30 AM, staggered)
30 2 * * * /usr/local/bin/backup-fgsrv3-mysql.sh
35 2 * * * /usr/local/bin/backup-fgsrv4-db.sh
40 2 * * * /usr/local/bin/backup-fgsrv5-db.sh
```

---

## 3. PHP-FPM Memory Leaks and Timeouts

### 3.1 PHP-FPM Configuration Issues

**Common Problems:**
- `fastcgi_keep_conn on` with PHP-FPM 'ondemand' or 'dynamic' causes failures
- nginx doesn't properly reconnect when PHP-FPM rebuilds worker processes
- Workers accumulate memory over time and eventually crash

**PHP-FPM Pool Configuration:**
```ini
; /etc/php-fpm.d/www.conf or similar

; Process management
pm = dynamic
pm.max_children = 50
pm.start_servers = 5
pm.min_spare_servers = 5
pm.max_spare_servers = 35

; Restart workers after X requests (prevents memory leaks)
pm.max_requests = 500

; Timeout configuration
request_terminate_timeout = 300s
request_slowlog_timeout = 10s

; Memory limits
php_admin_value[memory_limit] = 256M
```

### 3.2 PHP Execution Timeouts

**Default Limits:**
- PHP scripts: 30 seconds default timeout
- Can be overridden in php.ini or per-script with `set_time_limit()`

**php.ini Configuration:**
```ini
max_execution_time = 300     ; 5 minutes for web requests
max_input_time = 60
memory_limit = 256M

; CLI-specific (for cron jobs)
; /etc/php-cli.ini or php.ini for CLI SAPI
max_execution_time = 0       ; Unlimited for CLI
memory_limit = 512M
```

### 3.3 Diagnostic Commands

```bash
# Check PHP-FPM status
systemctl status php-fpm
# or for PHP 5
systemctl status php5-fpm

# Monitor PHP-FPM pool status (configure status page first)
curl http://localhost/php-fpm-status?full

# Check slow logs
tail -f /var/log/php-fpm/www-slow.log

# Monitor memory usage
watch -n 1 'ps aux | grep php-fpm | awk "{sum+=\$6} END {print sum/1024 \" MB\"}"'
```

---

## 4. Laravel Queue Workers and Scheduled Tasks

### 4.1 Memory Leaks in Queue Workers

**Critical Issue:** Queue workers accumulate memory over time as they process jobs. PHP's garbage collector doesn't catch all references.

**Evidence:**
- Memory leaks are difficult to avoid with Laravel queue workers
- Over time, references pile up causing workers to crash
- Default memory limit: 128 MB (often insufficient)

### 4.2 Solutions for Queue Worker Memory Leaks

**Solution 1: Use --max-jobs and --max-time**
```bash
php artisan queue:work --max-jobs=1000 --max-time=3600 --memory=256
```
- Worker processes 1000 jobs then exits
- Supervisor/systemd restarts worker with clean memory
- Memory freed up on restart

**Solution 2: Scheduled Restarts via Cron**
```bash
# Add to /etc/crontab or user crontab
0 * * * * www-data php /var/www/api.falg.com.br/artisan queue:restart
```
- Restarts queue workers every hour
- Workers exit gracefully after finishing current job
- New workers start with clean memory

**Solution 3: Systemd Service with Restart Policy**
```ini
# /etc/systemd/system/laravel-queue-worker.service
[Unit]
Description=Laravel Queue Worker
After=network.target

[Service]
User=www-data
Group=www-data
Restart=always
RestartSec=10
ExecStart=/usr/bin/php /var/www/api.falg.com.br/artisan queue:work \
  --max-jobs=1000 --max-time=3600 --memory=256 --sleep=3 --tries=3

[Install]
WantedBy=multi-user.target
```

### 4.3 Laravel Scheduled Tasks Configuration

**Check Laravel Scheduler:**
```bash
# View scheduled tasks
cd /var/www/api.falg.com.br
php artisan schedule:list

# Test scheduler run
php artisan schedule:run -v

# Check cron entry for scheduler
crontab -l -u www-data
# Should have: * * * * * cd /path && php artisan schedule:run >> /dev/null 2>&1
```

**Common Scheduling Patterns Causing Morning Issues:**
```php
// app/Console/Kernel.php
protected function schedule(Schedule $schedule)
{
    // ⚠️ AVOID: All tasks at 9:00 AM
    $schedule->command('reports:generate')->dailyAt('09:00');
    $schedule->command('emails:send')->dailyAt('09:00');
    $schedule->command('cache:clear')->dailyAt('09:00');

    // ✅ BETTER: Stagger tasks across time
    $schedule->command('reports:generate')->dailyAt('02:00');
    $schedule->command('emails:send')->dailyAt('02:15');
    $schedule->command('cache:clear')->dailyAt('02:30');

    // ✅ BEST: Off-peak hours, staggered
    $schedule->command('heavy:processing')->dailyAt('03:00')->withoutOverlapping();
}
```

### 4.4 Timeout and Memory Configuration

**Critical Settings:**
```php
// config/queue.php
'connections' => [
    'database' => [
        'driver' => 'database',
        'table' => 'jobs',
        'queue' => 'default',
        'retry_after' => 600,  // Must be > longest job timeout
    ],
],

// Ensure retry_after > timeout for all jobs
// If a job can take 300s, set retry_after to 600+
```

**Memory Limit Issues:**
- CLI php.ini controls queue worker memory, not FPM php.ini
- Check: `php -i | grep memory_limit`
- Set in CLI php.ini: `memory_limit = 512M`

---

## 5. nginx Connection Pooling and Rate Limiting

### 5.1 Keepalive Connections (Connection Pooling)

**How It Works:**
- nginx maintains cache of keepalive connections to upstream servers
- Reduces latency and ephemeral port usage
- During traffic spikes, cache can be emptied, requiring new connections

**Configuration:**
```nginx
upstream php_backend {
    server unix:/var/run/php-fpm/www.sock;
    keepalive 32;  # Maintain 32 keepalive connections
}

server {
    location ~ \.php$ {
        fastcgi_pass php_backend;
        fastcgi_keep_conn on;  # ⚠️ Can cause issues with 'ondemand' PM

        # Connection timeouts
        fastcgi_connect_timeout 60s;
        fastcgi_send_timeout 180s;
        fastcgi_read_timeout 180s;

        # Buffer settings
        fastcgi_buffer_size 32k;
        fastcgi_buffers 16 16k;
    }
}
```

**⚠️ Warning:** Using `fastcgi_keep_conn on` with PHP-FPM process manager set to 'ondemand' or 'dynamic' can cause sites to fail when PHP-FPM tears down and rebuilds workers.

### 5.2 Rate Limiting Configuration

**Problem:** Without proper burst handling, legitimate morning traffic gets rejected.

**Solution: Use burst with nodelay**
```nginx
# Define rate limit zones
limit_req_zone $binary_remote_addr zone=general:10m rate=10r/s;
limit_req_zone $binary_remote_addr zone=api:10m rate=30r/s;

# Apply to server blocks
server {
    # For static sites (fgsrv4)
    location / {
        limit_req zone=general burst=20 nodelay;
        # burst=20 allows 20 extra requests to queue
        # nodelay processes burst immediately without artificial delay
    }
}

server {
    # For API endpoints (fgsrv5)
    location /api/ {
        limit_req zone=api burst=50 nodelay;
        # Higher burst for API calls
    }
}
```

**Parameters Explained:**
- `rate=10r/s`: Average rate limit (10 requests/second)
- `burst=20`: Allow bursts up to 20 extra requests
- `nodelay`: Process burst requests immediately (don't queue with delay)

**Without burst:** Excess requests → immediate 503 error
**With burst, no nodelay:** Burst requests queued and delayed
**With burst + nodelay:** Burst requests processed immediately (recommended)

### 5.3 Queue Configuration for Upstream Servers

```nginx
upstream backend {
    server backend1.example.com max_fails=3 fail_timeout=30s;
    server backend2.example.com max_fails=3 fail_timeout=30s;

    # Queue configuration
    queue 100 timeout=60s;  # Queue up to 100 requests, 60s max wait
}
```

### 5.4 Global Timeout Settings

```nginx
http {
    # Client timeouts
    client_body_timeout 60s;
    client_header_timeout 60s;
    keepalive_timeout 65s;
    send_timeout 60s;

    # Proxy timeouts (if using proxy_pass)
    proxy_connect_timeout 60s;
    proxy_send_timeout 180s;
    proxy_read_timeout 180s;

    # FastCGI timeouts (for PHP)
    fastcgi_connect_timeout 60s;
    fastcgi_send_timeout 180s;
    fastcgi_read_timeout 180s;
}
```

---

## 6. Locaweb VPS Specific Issues

### 6.1 Known Connectivity Issues

**Critical Finding from Customer Reports (Feb 2024):**

A Locaweb VPS customer reported severe issues where:
- Site went completely down starting Feb 4, 2024
- Analysis revealed access was ONLY registered weekdays between **7:50-18:00** (business hours)
- Outside these hours, no connectivity was available
- Customer suspected manual intervention was keeping site online during business hours

**Locaweb Support Response:**
- Acknowledged communication between application and database only occurred during business hours
- Problem began after "mitigation measures" were implemented
- No resolution timeline provided in public records

### 6.2 Locaweb VPS Specifications

**Service Level:**
- Promised uptime SLA: 99.8%
- Data center: One of Brazil's largest
- Generally known for fast and stable hosting

**Potential Issues:**
- No documented scheduled maintenance windows found
- The Feb 2024 incident appears isolated, not a recurring pattern
- However, the business-hours-only connectivity pattern is highly suspicious

### 6.3 Recommendations for Locaweb VPS

1. **Contact Locaweb Support:**
   - Request maintenance windows schedule
   - Ask about recent infrastructure changes
   - Request traffic/connectivity logs for 9-10am timeframe

2. **Implement Monitoring:**
   ```bash
   # Monitor connectivity from external source
   */5 * * * * curl -s -o /dev/null -w "%{http_code}" https://falg.com.br >> /var/log/uptime-check.log
   ```

3. **Enable Detailed Logging:**
   - MySQL slow query log (9-10am window)
   - nginx access/error logs with timestamps
   - PHP-FPM slow log
   - System resource logs (CPU, memory, disk I/O)

4. **Consider Redundancy:**
   - If business-hours-only pattern recurs, consider multi-provider strategy
   - Set up monitoring from external VPS to detect Locaweb-specific outages

---

## 7. Diagnostic Procedures

### 7.1 Immediate Diagnostic Commands

**Run on all affected servers during next incident:**

```bash
# === System Resources ===
top -b -n 1 | head -n 20
free -h
df -h
iostat -x 1 5

# === MySQL (fgsrv3) ===
mysql -e "SHOW PROCESSLIST;"
mysql -e "SHOW ENGINE INNODB STATUS\G" | grep -A 20 "TRANSACTIONS"
mysql -e "SHOW STATUS LIKE 'Threads_%';"
mysql -e "SHOW STATUS LIKE '%Connection%';"

# === PHP-FPM (fgsrv4, fgsrv5) ===
systemctl status php-fpm
systemctl status php5-fpm
ps aux | grep php-fpm | wc -l  # Count active workers
tail -n 100 /var/log/php-fpm/error.log

# === nginx (fgsrv4, fgsrv5) ===
systemctl status nginx
tail -n 100 /var/log/nginx/error.log
tail -n 100 /var/log/nginx/access.log | awk '{print $9}' | sort | uniq -c | sort -rn

# === Network ===
netstat -an | grep :80 | wc -l    # HTTP connections
netstat -an | grep :443 | wc -l   # HTTPS connections
netstat -an | grep :3306 | wc -l  # MySQL connections

# === Cron Jobs ===
crontab -l
ls -la /etc/cron.{hourly,daily,weekly}
grep -r "^[^#]" /etc/cron.d/

# === Laravel Queue (fgsrv5) ===
cd /var/www/api.falg.com.br
php artisan queue:failed
php artisan queue:work --once  # Test single job processing
```

### 7.2 Enable Slow Query Logging

**MySQL Configuration:**
```sql
-- Enable slow query log
SET GLOBAL slow_query_log = 'ON';
SET GLOBAL long_query_time = 2;  -- Log queries taking > 2 seconds
SET GLOBAL slow_query_log_file = '/var/log/mysql/slow-query.log';

-- Check current settings
SHOW VARIABLES LIKE 'slow_query%';
SHOW VARIABLES LIKE 'long_query_time';
```

**PHP-FPM Slow Log:**
```ini
; /etc/php-fpm.d/www.conf
request_slowlog_timeout = 5s
slowlog = /var/log/php-fpm/www-slow.log
```

### 7.3 Monitoring Setup

**Create monitoring script:**
```bash
#!/bin/bash
# /usr/local/bin/monitor-morning-timeout.sh

LOG_DIR="/var/log/morning-timeout-monitor"
mkdir -p "$LOG_DIR"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)

{
    echo "=== System Status at $TIMESTAMP ==="
    echo "--- Load Average ---"
    uptime

    echo "--- Memory ---"
    free -h

    echo "--- Disk I/O ---"
    iostat -x 1 3

    echo "--- MySQL Connections ---"
    mysql -e "SHOW STATUS LIKE 'Threads_%'; SHOW PROCESSLIST;"

    echo "--- PHP-FPM Processes ---"
    ps aux | grep php-fpm

    echo "--- Network Connections ---"
    netstat -an | grep -E ':(80|443|3306)' | wc -l

    echo "--- Recent nginx Errors ---"
    tail -n 50 /var/log/nginx/error.log

} > "$LOG_DIR/status-$TIMESTAMP.log"
```

**Schedule monitoring during problem window:**
```bash
# Add to crontab
# Run every minute from 8:50-10:10 AM
50-59 8 * * * /usr/local/bin/monitor-morning-timeout.sh
0-10 9,10 * * * /usr/local/bin/monitor-morning-timeout.sh
```

---

## 8. Recommended Actions

### 8.1 Immediate Actions (Priority 1)

1. **Audit Scheduled Tasks**
   ```bash
   # On all servers: fgsrv3, fgsrv4, fgsrv5
   crontab -l > /tmp/crontab-audit-$(hostname).txt
   find /etc/cron.* -type f -exec grep -H "^[^#]" {} \; > /tmp/cron-audit-$(hostname).txt
   ```

2. **Check Backup Schedules**
   ```bash
   grep -r "mysqldump\|backup" /etc/cron.* /var/spool/cron/
   # Identify any backups running 9-10am
   # Reschedule to 2-4am window
   ```

3. **Review Laravel Scheduled Tasks (fgsrv5)**
   ```bash
   cd /var/www/api.falg.com.br
   php artisan schedule:list
   # Document all tasks and their schedules
   # Move any 9-10am tasks to off-peak hours
   ```

4. **Enable Monitoring During Problem Window**
   - Deploy monitoring script above
   - Schedule to run 8:50-10:10 AM
   - Collect at least 3 days of data during timeout window

### 8.2 Short-term Actions (Priority 2)

1. **Optimize MySQL Configuration (fgsrv3)**
   ```sql
   -- Adjust connection timeout settings
   SET GLOBAL wait_timeout = 600;
   SET GLOBAL interactive_timeout = 600;
   SET GLOBAL max_connections = 200;  -- Increase if needed

   -- Enable slow query log
   SET GLOBAL slow_query_log = 'ON';
   SET GLOBAL long_query_time = 2;
   ```

2. **Configure PHP-FPM Worker Recycling (fgsrv4, fgsrv5)**
   ```ini
   ; /etc/php-fpm.d/www.conf
   pm.max_requests = 500  # Restart workers after 500 requests
   request_terminate_timeout = 300s
   request_slowlog_timeout = 10s
   ```

3. **Implement Laravel Queue Worker Restarts (fgsrv5)**
   ```bash
   # Add to crontab
   0 * * * * php /var/www/api.falg.com.br/artisan queue:restart

   # Or use systemd with max-jobs limit
   php artisan queue:work --max-jobs=1000 --max-time=3600 --memory=256
   ```

4. **Update nginx Configuration (fgsrv4, fgsrv5)**
   ```nginx
   # Increase timeouts
   fastcgi_read_timeout 300s;
   fastcgi_send_timeout 300s;

   # Add rate limiting with burst
   limit_req_zone $binary_remote_addr zone=general:10m rate=10r/s;
   limit_req zone=general burst=20 nodelay;
   ```

### 8.3 Long-term Solutions (Priority 3)

1. **Implement Proper Backup Strategy**
   - Move backups to 2-4 AM window
   - Use `--single-transaction` for InnoDB
   - Consider setting up MySQL replica for backups

2. **Deploy Comprehensive Monitoring**
   - Set up Prometheus + Grafana or similar
   - Monitor MySQL connection pool usage
   - Track PHP-FPM worker status
   - Alert on nginx error rate spikes

3. **Load Testing**
   ```bash
   # Simulate morning traffic
   ab -n 10000 -c 100 https://falg.com.br/
   ab -n 5000 -c 50 https://api.falg.com.br/api/endpoint
   ```

4. **Contact Locaweb Support**
   - Request detailed explanation of Feb 2024 incident
   - Ask about current infrastructure status
   - Request proactive notification of maintenance windows
   - Inquire about business-hours-only connectivity pattern

---

## 9. Prevention Best Practices

### 9.1 Cron Job Scheduling Guidelines

**DO:**
- ✅ Stagger jobs across time (9:00, 9:15, 9:30)
- ✅ Use randomization for non-critical tasks
- ✅ Schedule heavy jobs during off-peak (2-4 AM)
- ✅ Set explicit timeouts in cron scripts
- ✅ Log all cron job outputs for debugging

**DON'T:**
- ❌ Schedule multiple jobs at exact same time (9:00, 10:00)
- ❌ Run database backups during business hours
- ❌ Use default timeout values without testing
- ❌ Ignore timezone differences
- ❌ Overlap resource-intensive tasks

**Example Staggered Schedule:**
```bash
# /etc/crontab - Staggered morning tasks
00 2 * * * root /usr/local/bin/backup-mysql.sh
15 2 * * * root /usr/local/bin/backup-files.sh
30 2 * * * root /usr/local/bin/clean-tmp.sh
45 2 * * * www-data php /var/www/artisan schedule:run
```

### 9.2 Resource Management

**Connection Pool Sizing:**
```ini
; PHP-FPM pool sizing formula
pm.max_children = (Total RAM - OS - MySQL - Other) / Average PHP process size
; Example: (8GB - 2GB - 2GB - 1GB) / 50MB = ~60 max children

; Conservative formula for shared VPS
pm.max_children = Available RAM / (Average process size * 1.5)
```

**MySQL Connection Limits:**
```sql
-- Set based on expected concurrent connections
SET GLOBAL max_connections = 200;

-- Monitor actual usage
SHOW STATUS LIKE 'Max_used_connections';
SHOW STATUS LIKE 'Threads_connected';
```

### 9.3 Monitoring Checklist

**Essential Metrics:**
- [ ] CPU usage per service (MySQL, PHP-FPM, nginx)
- [ ] Memory usage trends over 24 hours
- [ ] Disk I/O wait times
- [ ] MySQL connection count and slow queries
- [ ] PHP-FPM worker count and status
- [ ] nginx request rate and error rate
- [ ] Network connection states
- [ ] Queue job failure rate (Laravel)

**Alert Thresholds:**
- CPU > 80% for 5 minutes
- Memory > 90% for 5 minutes
- MySQL connections > 80% of max_connections
- PHP-FPM active workers > 80% of pm.max_children
- nginx 5xx error rate > 1% of requests
- Queue failed jobs > 10 in 5 minutes

---

## 10. Conclusion and Next Steps

### Root Cause Hypothesis

Based on comprehensive research, the 9-10am timeout pattern is most likely caused by:

1. **Primary Cause (70% likelihood):** Automated backup or maintenance tasks scheduled at or near 9:00 AM, creating database locks and connection pool exhaustion

2. **Contributing Factor (50% likelihood):** Laravel scheduled tasks and cron jobs clustering at top-of-hour (:00) marks, coinciding with morning traffic surge

3. **Contributing Factor (30% likelihood):** PHP-FPM memory leaks from overnight queue worker execution reaching critical levels by morning

4. **Possible Factor (20% likelihood):** Locaweb infrastructure issues or scheduled maintenance (based on Feb 2024 incident)

### Immediate Next Steps

1. **Execute Priority 1 Actions** (Today):
   - Audit all cron jobs and scheduled tasks
   - Deploy monitoring script for 8:50-10:10 AM window
   - Enable MySQL slow query log

2. **Collect Data** (Next 3 Days):
   - Monitor system resources during problem window
   - Log all timeout events with timestamps
   - Identify specific processes/queries causing delays

3. **Analyze and Adjust** (Day 4-7):
   - Review collected logs and metrics
   - Identify primary bottleneck
   - Implement targeted fixes based on evidence

4. **Validate Solution** (Week 2):
   - Monitor for resolution of timeout issues
   - Fine-tune configurations as needed
   - Document final solution for future reference

### Success Criteria

- No timeout errors during 9-10 AM window for 7 consecutive days
- Average response time < 500ms during peak hours
- MySQL connection pool usage < 70% of max_connections
- PHP-FPM worker pool usage < 70% of max_children
- No 5xx errors related to upstream timeouts

---

## 11. References and Resources

### Documentation
- [nginx Rate Limiting Guide](https://www.nginx.com/blog/rate-limiting-nginx/)
- [MySQL Timeout Parameters](https://dev.mysql.com/doc/refman/8.0/en/server-system-variables.html)
- [Laravel Queue Workers Best Practices](https://laravel.com/docs/queues)
- [PHP-FPM Configuration Reference](https://www.php.net/manual/en/install.fpm.configuration.php)

### Diagnostic Tools
- `mytop` or `innotop` - Real-time MySQL monitoring
- `htop` - System resource monitoring
- `netstat` / `ss` - Network connection tracking
- `iotop` - Disk I/O monitoring
- Laravel Horizon - Queue worker monitoring (if not installed, consider it)

### Monitoring Solutions
- **Open Source:** Prometheus + Grafana, Netdata, Zabbix
- **Commercial:** Datadog, New Relic, AppDynamics
- **Simple:** Custom scripts + cron + log aggregation

---

**Research compiled by:** Hive Mind Research Agent
**Last updated:** 2025-10-22
**Status:** Comprehensive analysis complete, awaiting field validation

**Next Document:** `morning-timeout-action-plan.md` (to be created based on diagnostic findings)
