# Quick Diagnostic Checklist - Morning Timeout Issue
## For fgsrv3, fgsrv4, fgsrv5 (9-10am timeouts)

**Run this checklist during the next timeout event**

---

## 🚨 During Active Timeout (Run immediately)

### 1. System Resources (All Servers)
```bash
# Quick system check
uptime && free -h && df -h
top -b -n 1 | head -n 20
iostat -x 1 3
```

### 2. MySQL Status (fgsrv3)
```bash
mysql -e "SHOW PROCESSLIST;"
mysql -e "SHOW STATUS LIKE 'Threads_%';"
mysql -e "SHOW STATUS LIKE '%Connection%';"
mysql -e "SHOW STATUS LIKE 'Slow_queries';"
```

### 3. PHP-FPM Status (fgsrv4, fgsrv5)
```bash
systemctl status php-fpm
ps aux | grep php-fpm | wc -l
tail -n 50 /var/log/php-fpm/error.log
```

### 4. nginx Status (fgsrv4, fgsrv5)
```bash
systemctl status nginx
tail -n 50 /var/log/nginx/error.log
netstat -an | grep -E ':(80|443)' | wc -l
```

### 5. Network Connections
```bash
netstat -an | grep :3306 | wc -l  # MySQL
netstat -an | grep ESTABLISHED | wc -l  # Total
```

---

## 📋 Post-Incident Analysis

### 1. Identify Active Cron Jobs
```bash
# Check what ran during timeout window
grep "CRON" /var/log/syslog | grep -E "09:[0-5][0-9]"
grep "CMD" /var/log/cron | grep -E "09:[0-5][0-9]"
```

### 2. Review MySQL Slow Queries
```bash
tail -n 100 /var/log/mysql/slow-query.log
```

### 3. Check PHP-FPM Slow Log
```bash
tail -n 100 /var/log/php-fpm/www-slow.log
```

### 4. Laravel Queue Status (fgsrv5)
```bash
cd /var/www/api.falg.com.br
php artisan queue:failed
tail -n 100 storage/logs/laravel.log | grep -i "timeout\|error"
```

---

## 🔍 Common Patterns to Look For

### Cron Job Clustering
- [ ] Multiple jobs at 9:00 AM
- [ ] Database backup during timeout window
- [ ] Heavy processing tasks at morning hours

### Resource Exhaustion
- [ ] MySQL connections > 80% of max_connections
- [ ] PHP-FPM workers > 80% of pm.max_children
- [ ] Memory usage > 90%
- [ ] Disk I/O wait > 20%

### Configuration Issues
- [ ] PHP-FPM fastcgi_keep_conn with 'ondemand' mode
- [ ] nginx rate limiting rejecting requests
- [ ] MySQL wait_timeout too short
- [ ] Missing burst configuration in nginx

---

## ✅ Quick Fixes to Try

### If MySQL Connection Pool Exhausted
```sql
mysql -e "SET GLOBAL wait_timeout = 600;"
mysql -e "SET GLOBAL interactive_timeout = 600;"
systemctl restart mysql
```

### If PHP-FPM Workers Exhausted
```bash
# Edit /etc/php-fpm.d/www.conf
# Increase: pm.max_children, pm.max_requests
systemctl restart php-fpm
```

### If Queue Workers Stuck (fgsrv5)
```bash
php artisan queue:restart
systemctl restart laravel-queue-worker  # If using systemd
```

### If nginx Rate Limiting
```bash
# Check nginx config for limit_req
grep -r "limit_req" /etc/nginx/
# Add burst=20 nodelay to rate limit zones
nginx -t && systemctl reload nginx
```

---

## 📊 Metrics to Collect

Create `/usr/local/bin/collect-metrics.sh`:
```bash
#!/bin/bash
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
LOG_DIR="/var/log/timeout-diagnostics"
mkdir -p "$LOG_DIR"

{
    echo "=== $TIMESTAMP ==="
    echo "Load: $(uptime | awk -F'load average:' '{print $2}')"
    echo "Memory: $(free | grep Mem | awk '{printf "%.1f%%", $3/$2 * 100}')"
    echo "MySQL Conn: $(mysql -e 'SHOW STATUS LIKE "Threads_connected"' -sN | awk '{print $2}')"
    echo "PHP-FPM: $(ps aux | grep php-fpm | wc -l)"
    echo "nginx 5xx: $(tail -n 1000 /var/log/nginx/access.log | grep -E '" 5[0-9]{2} "' | wc -l)"
} >> "$LOG_DIR/metrics-$(date +%Y%m%d).log"
```

Schedule for 8:50-10:10 AM:
```bash
50-59 8 * * * /usr/local/bin/collect-metrics.sh
0-10 9,10 * * * /usr/local/bin/collect-metrics.sh
```

---

## 🎯 Priority Action Items

1. **Enable slow query logging** (if not already enabled)
2. **Deploy metrics collection script**
3. **Audit cron jobs** for 9-10am window
4. **Check Laravel scheduler** `php artisan schedule:list`
5. **Review backup schedules** and move to 2-4am
6. **Increase timeout values** in nginx, PHP-FPM, MySQL
7. **Add nginx burst handling** for rate limits

---

**Run during next timeout:** Save all command outputs to `/tmp/timeout-debug-$(date +%Y%m%d-%H%M).txt`
