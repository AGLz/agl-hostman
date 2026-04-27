#!/bin/bash

#############################################################################
# Emergency One-Liners - VPS Timeout Diagnostics
#############################################################################
#
# Copy-paste these commands during the 9-10am timeout window
# Each section can be executed independently
#
#############################################################################

cat <<'EOF'

=============================================================================
EMERGENCY ONE-LINERS - VPS TIMEOUT DIAGNOSTICS
=============================================================================

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
1. CRON JOB AUDIT (All Hosts - 30 seconds)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

{ echo "=== Cron Audit $(hostname) $(date) ==="; crontab -l 2>/dev/null || echo "No user crontab"; echo ""; sudo crontab -l 2>/dev/null || echo "No root crontab"; echo ""; sudo cat /etc/crontab; echo ""; sudo grep -r "0 9\|9 \*" /etc/cron* 2>/dev/null; } | tee /tmp/cron-audit-$(hostname).txt

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
2. MYSQL BACKUP CHECK (fgsrv3 only - 20 seconds)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

{ echo "=== MySQL Backup Audit $(date) ==="; echo "Backup scripts:"; sudo find /etc /opt /usr/local /var /root /home -name "*backup*" -o -name "*dump*" 2>/dev/null | head -20; echo ""; echo "Active backup processes:"; ps aux | grep -i "backup\|dump\|mysqldump" | grep -v grep; } | tee /tmp/backup-audit.txt

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
3. MYSQL REAL-TIME MONITOR (fgsrv3 - Run at 08:55, stop at 10:05)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# Background monitoring (recommended):
nohup sh -c 'while true; do echo "=== $(date +%Y-%m-%d_%H:%M:%S) ===" >> /tmp/mysql-monitor.log; mysql -e "SHOW STATUS LIKE \"Threads_connected\"; SHOW PROCESSLIST;" >> /tmp/mysql-monitor.log 2>&1; sleep 5; done' > /tmp/mysql-monitor.out 2>&1 &

# To stop: kill $(ps aux | grep "mysql-monitor" | grep -v grep | awk '{print $2}')

# OR watch mode (foreground):
watch -n 5 'mysql -e "SHOW STATUS LIKE \"Threads_connected\"; SELECT COUNT(*) as active_queries FROM information_schema.PROCESSLIST WHERE COMMAND != \"Sleep\"; SHOW PROCESSLIST;" | head -25'

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
4. NGINX CONNECTION MONITOR (fgsrv4 & fgsrv5 - Run at 08:55)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# Background monitoring:
nohup sh -c 'while true; do echo "=== $(date +%Y-%m-%d_%H:%M:%S) ===" >> /tmp/nginx-monitor.log; echo "Active connections: $(netstat -an | grep :80 | wc -l)" >> /tmp/nginx-monitor.log; echo "PHP-FPM processes: $(ps aux | grep php-fpm | grep -v grep | wc -l)" >> /tmp/nginx-monitor.log; sleep 5; done' > /tmp/nginx-monitor.out 2>&1 &

# To stop: kill $(ps aux | grep "nginx-monitor" | grep -v grep | awk '{print $2}')

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
5. EMERGENCY SNAPSHOT (When timeout starts - 10 seconds)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# MySQL (fgsrv3):
{ echo "=== MySQL Emergency $(date) ==="; mysql -e "SHOW FULL PROCESSLIST; SHOW ENGINE INNODB STATUS\G; SHOW STATUS LIKE 'Threads%'; SHOW OPEN TABLES WHERE In_use > 0;"; } | tee /tmp/mysql-emergency-$(date +%H%M).txt

# nginx (fgsrv4 & fgsrv5):
{ echo "=== nginx Emergency $(date) ==="; sudo tail -50 /var/log/nginx/error.log; netstat -an | grep :80 | head -20; sudo systemctl status php-fpm; } | tee /tmp/nginx-emergency-$(date +%H%M).txt

# System resources (all hosts):
{ echo "=== System Emergency $(date) ==="; echo "CPU:"; top -bn1 | head -15; echo ""; echo "Memory:"; free -h; echo ""; echo "Disk I/O:"; iostat -x 1 2; } | tee /tmp/system-emergency-$(date +%H%M).txt

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
6. QUICK FIXES (If root cause identified)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# If MySQL backup is running and causing issues:
sudo killall -9 mysqldump  # CAUTION: Only if backup is stuck

# If PHP-FPM is exhausted:
sudo systemctl restart php-fpm

# If too many connections to MySQL:
mysql -e "SHOW PROCESSLIST;" | grep Sleep | awk '{print $1}' | while read id; do mysql -e "KILL $id;"; done

# Temporarily increase MySQL connections (until restart):
mysql -e "SET GLOBAL max_connections = 500;"

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
7. ENABLE DETAILED LOGGING (Run once - persists)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# MySQL slow query log (fgsrv3):
mysql -e "SET GLOBAL slow_query_log = 'ON'; SET GLOBAL long_query_time = 2; SET GLOBAL log_queries_not_using_indexes = 'ON';"

# Check slow query log location:
mysql -e "SHOW VARIABLES LIKE 'slow_query_log_file';"

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
8. COLLECT ALL EVIDENCE (After 10:00 - 2 minutes)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

mkdir -p /tmp/evidence-$(date +%Y%m%d) && cp /tmp/*-monitor*.log /tmp/*-audit*.txt /tmp/*-emergency*.txt /tmp/evidence-$(date +%Y%m%d)/ 2>/dev/null && tar -czf /tmp/evidence-$(hostname)-$(date +%Y%m%d).tar.gz -C /tmp evidence-$(date +%Y%m%d)/ && ls -lh /tmp/evidence-*.tar.gz

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
9. COMPREHENSIVE DIAGNOSTIC (Runs all checks - 60 seconds)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

{ echo "=== COMPREHENSIVE DIAGNOSTIC - $(hostname) - $(date) ==="; echo ""; echo "1. CRON JOBS:"; crontab -l 2>/dev/null; sudo crontab -l 2>/dev/null; sudo cat /etc/crontab; echo ""; echo "2. PROCESSES AT 9AM:"; sudo grep -r "0 9" /etc/cron* 2>/dev/null; echo ""; echo "3. MYSQL STATUS:"; mysql -e "SHOW STATUS LIKE 'Threads%'; SHOW PROCESSLIST;" 2>/dev/null; echo ""; echo "4. NGINX CONNECTIONS:"; netstat -an | grep :80 | wc -l; echo ""; echo "5. PHP-FPM PROCESSES:"; ps aux | grep php-fpm | wc -l; echo ""; echo "6. SYSTEM RESOURCES:"; free -h; echo ""; top -bn1 | head -10; echo ""; echo "7. DISK USAGE:"; df -h; echo ""; echo "8. NETWORK:"; netstat -s | grep -i error; } | tee /tmp/comprehensive-diagnostic-$(hostname)-$(date +%Y%m%d-%H%M).txt

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
10. STOP ALL MONITORS (After problem ends)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

killall -9 sh; ps aux | grep monitor | grep -v grep | awk '{print $2}' | xargs kill 2>/dev/null

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

USAGE TIPS:
-----------
1. Open 3 terminal tabs (one per host)
2. Run section 1 (cron audit) on all hosts FIRST
3. Run section 2 (backup check) on fgsrv3
4. At 08:55, start section 3 (mysql monitor) on fgsrv3
5. At 08:55, start section 4 (nginx monitor) on fgsrv4 & fgsrv5
6. When timeouts start (≈09:00), run section 5 (emergency snapshot)
7. After 10:00, run section 8 (collect evidence)
8. Run section 10 to stop all monitors

=============================================================================

EOF
