#!/bin/bash

################################################################################
# VPS Timeout Log Analysis Queries
# Purpose: Collection of pre-built queries for analyzing logs across fgsrv3/4/5
# Author: Hive Mind Analyst Agent
# Date: 2025-10-22
################################################################################

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
MYSQL_LOG="/var/log/mysql/mysql-slow.log"
NGINX_ACCESS="/var/log/nginx/access.log"
NGINX_ERROR="/var/log/nginx/error.log"
PHP_FPM_LOG="/var/log/php*-fpm.log"
SYSLOG="/var/log/syslog"

# Output directory
OUTPUT_DIR="/tmp/log-analysis-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$OUTPUT_DIR"

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}VPS Timeout Log Analysis${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "Output directory: ${BLUE}$OUTPUT_DIR${NC}"
echo ""

################################################################################
# CRON JOB ANALYSIS
################################################################################

echo -e "${YELLOW}[1/10] Analyzing Cron Jobs...${NC}"

# List all cron jobs for all users
echo "=== All User Crontabs ===" > "$OUTPUT_DIR/cron-inventory.txt"
for user in $(cut -f1 -d: /etc/passwd); do
  crontab -u "$user" -l 2>/dev/null && echo "--- User: $user ---" >> "$OUTPUT_DIR/cron-inventory.txt"
done

# System cron jobs
echo "" >> "$OUTPUT_DIR/cron-inventory.txt"
echo "=== System Crontabs ===" >> "$OUTPUT_DIR/cron-inventory.txt"
cat /etc/crontab 2>/dev/null >> "$OUTPUT_DIR/cron-inventory.txt"
ls -la /etc/cron.d/ 2>/dev/null >> "$OUTPUT_DIR/cron-inventory.txt"

# Cron execution history from syslog
echo "=== Recent Cron Executions ===" > "$OUTPUT_DIR/cron-execution-history.txt"
grep CRON "$SYSLOG" | tail -500 >> "$OUTPUT_DIR/cron-execution-history.txt" 2>/dev/null

# Currently running cron processes
echo "=== Running Cron Processes ===" > "$OUTPUT_DIR/cron-running-processes.txt"
ps aux | grep -E 'cron|CRON' | grep -v grep >> "$OUTPUT_DIR/cron-running-processes.txt"

echo -e "  ${GREEN}✓${NC} Cron analysis saved to $OUTPUT_DIR/cron-*.txt"

################################################################################
# MYSQL SLOW QUERY ANALYSIS
################################################################################

echo -e "${YELLOW}[2/10] Analyzing MySQL Slow Queries...${NC}"

if [ -f "$MYSQL_LOG" ]; then
  # Top 20 slowest queries by total time
  echo "=== Top 20 Slowest Queries ===" > "$OUTPUT_DIR/mysql-slow-queries.txt"
  mysqldumpslow -s t -t 20 "$MYSQL_LOG" >> "$OUTPUT_DIR/mysql-slow-queries.txt" 2>/dev/null

  # Queries by count
  echo "" >> "$OUTPUT_DIR/mysql-slow-queries.txt"
  echo "=== Top 20 Most Frequent Slow Queries ===" >> "$OUTPUT_DIR/mysql-slow-queries.txt"
  mysqldumpslow -s c -t 20 "$MYSQL_LOG" >> "$OUTPUT_DIR/mysql-slow-queries.txt" 2>/dev/null

  # Extract query patterns during last 24 hours
  echo "=== Slow Queries (Last 24 Hours) ===" > "$OUTPUT_DIR/mysql-slow-recent.txt"
  awk '/Query_time/ {qt=$3} /User@Host/ {user=$3} /^SET timestamp/ {ts=$4} /^SELECT|^UPDATE|^INSERT|^DELETE/ {print ts, qt, user, $0}' "$MYSQL_LOG" | \
    tail -100 >> "$OUTPUT_DIR/mysql-slow-recent.txt"

  # Count queries by type
  echo "=== Query Type Distribution ===" > "$OUTPUT_DIR/mysql-query-types.txt"
  grep -oE "^(SELECT|UPDATE|INSERT|DELETE)" "$MYSQL_LOG" | sort | uniq -c | sort -rn >> "$OUTPUT_DIR/mysql-query-types.txt"

  echo -e "  ${GREEN}✓${NC} MySQL slow query analysis saved"
else
  echo -e "  ${RED}✗${NC} MySQL slow query log not found: $MYSQL_LOG"
fi

################################################################################
# MYSQL CONNECTION ANALYSIS
################################################################################

echo -e "${YELLOW}[3/10] Analyzing MySQL Connection Status...${NC}"

if command -v mysql &> /dev/null; then
  # Current processlist
  echo "=== Current MySQL Processlist ===" > "$OUTPUT_DIR/mysql-processlist.txt"
  mysql -e "SHOW FULL PROCESSLIST;" >> "$OUTPUT_DIR/mysql-processlist.txt" 2>/dev/null || echo "MySQL connection failed" >> "$OUTPUT_DIR/mysql-processlist.txt"

  # Long-running queries
  echo "" >> "$OUTPUT_DIR/mysql-processlist.txt"
  echo "=== Queries Running >5 Seconds ===" >> "$OUTPUT_DIR/mysql-processlist.txt"
  mysql -e "SELECT * FROM information_schema.processlist WHERE command != 'Sleep' AND time > 5 ORDER BY time DESC;" >> "$OUTPUT_DIR/mysql-processlist.txt" 2>/dev/null

  # Connection statistics
  echo "=== MySQL Connection Statistics ===" > "$OUTPUT_DIR/mysql-connections.txt"
  mysql -e "SHOW STATUS LIKE 'Threads_connected';" >> "$OUTPUT_DIR/mysql-connections.txt" 2>/dev/null
  mysql -e "SHOW VARIABLES LIKE 'max_connections';" >> "$OUTPUT_DIR/mysql-connections.txt" 2>/dev/null
  mysql -e "SHOW STATUS LIKE 'Aborted_connects';" >> "$OUTPUT_DIR/mysql-connections.txt" 2>/dev/null

  # Locked tables
  echo "=== Locked Tables ===" >> "$OUTPUT_DIR/mysql-connections.txt"
  mysql -e "SHOW OPEN TABLES WHERE In_use > 0;" >> "$OUTPUT_DIR/mysql-connections.txt" 2>/dev/null

  echo -e "  ${GREEN}✓${NC} MySQL connection analysis saved"
else
  echo -e "  ${RED}✗${NC} MySQL client not available"
fi

################################################################################
# NGINX ERROR LOG ANALYSIS
################################################################################

echo -e "${YELLOW}[4/10] Analyzing Nginx Error Logs...${NC}"

if [ -f "$NGINX_ERROR" ]; then
  # Timeout-specific errors
  echo "=== Timeout Errors ===" > "$OUTPUT_DIR/nginx-timeout-errors.txt"
  grep -E "timeout|timed out|upstream timed out" "$NGINX_ERROR" | tail -200 >> "$OUTPUT_DIR/nginx-timeout-errors.txt"

  # Error type distribution
  echo "=== Error Type Distribution ===" > "$OUTPUT_DIR/nginx-error-types.txt"
  awk '{print $9, $10, $11}' "$NGINX_ERROR" | sort | uniq -c | sort -rn | head -30 >> "$OUTPUT_DIR/nginx-error-types.txt"

  # 5xx server errors
  echo "=== 5xx Server Errors ===" > "$OUTPUT_DIR/nginx-5xx-errors.txt"
  grep " 5[0-9][0-9] " "$NGINX_ERROR" | tail -100 >> "$OUTPUT_DIR/nginx-5xx-errors.txt"

  # Upstream failures
  echo "=== Upstream Failures ===" > "$OUTPUT_DIR/nginx-upstream-errors.txt"
  grep "upstream" "$NGINX_ERROR" | grep -E "failed|timeout|timed out" | tail -100 >> "$OUTPUT_DIR/nginx-upstream-errors.txt"

  # Connection issues
  echo "=== Connection Issues ===" > "$OUTPUT_DIR/nginx-connection-errors.txt"
  grep -E "connect\(\) failed|broken pipe|reset by peer" "$NGINX_ERROR" | tail -100 >> "$OUTPUT_DIR/nginx-connection-errors.txt"

  echo -e "  ${GREEN}✓${NC} Nginx error log analysis saved"
else
  echo -e "  ${RED}✗${NC} Nginx error log not found: $NGINX_ERROR"
fi

################################################################################
# NGINX ACCESS LOG ANALYSIS
################################################################################

echo -e "${YELLOW}[5/10] Analyzing Nginx Access Logs...${NC}"

if [ -f "$NGINX_ACCESS" ]; then
  # Request rate per minute
  echo "=== Request Rate Per Minute (Top 30) ===" > "$OUTPUT_DIR/nginx-request-rate.txt"
  awk '{print $4}' "$NGINX_ACCESS" | cut -d: -f1-3 | sort | uniq -c | sort -rn | head -30 >> "$OUTPUT_DIR/nginx-request-rate.txt"

  # Status code distribution
  echo "=== HTTP Status Code Distribution ===" > "$OUTPUT_DIR/nginx-status-codes.txt"
  awk '{print $9}' "$NGINX_ACCESS" | sort | uniq -c | sort -rn >> "$OUTPUT_DIR/nginx-status-codes.txt"

  # Top requesting IPs
  echo "=== Top 30 IP Addresses ===" > "$OUTPUT_DIR/nginx-top-ips.txt"
  awk '{print $1}' "$NGINX_ACCESS" | sort | uniq -c | sort -rn | head -30 >> "$OUTPUT_DIR/nginx-top-ips.txt"

  # Most requested URLs
  echo "=== Top 50 Requested URLs ===" > "$OUTPUT_DIR/nginx-top-urls.txt"
  awk '{print $7}' "$NGINX_ACCESS" | sort | uniq -c | sort -rn | head -50 >> "$OUTPUT_DIR/nginx-top-urls.txt"

  # Slow requests (if request_time is logged in $NF)
  echo "=== Slow Requests (>5 seconds) ===" > "$OUTPUT_DIR/nginx-slow-requests.txt"
  awk '$NF > 5 {print $0}' "$NGINX_ACCESS" 2>/dev/null | tail -100 >> "$OUTPUT_DIR/nginx-slow-requests.txt"

  # 4xx client errors
  echo "=== 4xx Client Errors ===" > "$OUTPUT_DIR/nginx-4xx-errors.txt"
  awk '$9 ~ /^4/ {print $9, $7}' "$NGINX_ACCESS" | sort | uniq -c | sort -rn | head -30 >> "$OUTPUT_DIR/nginx-4xx-errors.txt"

  # 5xx server errors from access log
  echo "=== 5xx Server Errors (from access log) ===" > "$OUTPUT_DIR/nginx-5xx-access.txt"
  awk '$9 ~ /^5/ {print $4, $9, $7}' "$NGINX_ACCESS" | tail -100 >> "$OUTPUT_DIR/nginx-5xx-access.txt"

  echo -e "  ${GREEN}✓${NC} Nginx access log analysis saved"
else
  echo -e "  ${RED}✗${NC} Nginx access log not found: $NGINX_ACCESS"
fi

################################################################################
# PHP-FPM LOG ANALYSIS
################################################################################

echo -e "${YELLOW}[6/10] Analyzing PHP-FPM Logs...${NC}"

PHP_FPM_LOGS=$(ls $PHP_FPM_LOG 2>/dev/null)

if [ -n "$PHP_FPM_LOGS" ]; then
  # Max children reached warnings
  echo "=== Max Children Warnings ===" > "$OUTPUT_DIR/phpfpm-max-children.txt"
  for log in $PHP_FPM_LOGS; do
    echo "--- Log: $log ---" >> "$OUTPUT_DIR/phpfpm-max-children.txt"
    grep "max_children" "$log" 2>/dev/null | tail -50 >> "$OUTPUT_DIR/phpfpm-max-children.txt"
  done

  # Memory limit errors
  echo "=== Memory Limit Errors ===" > "$OUTPUT_DIR/phpfpm-memory-errors.txt"
  for log in $PHP_FPM_LOGS; do
    echo "--- Log: $log ---" >> "$OUTPUT_DIR/phpfpm-memory-errors.txt"
    grep "Allowed memory size" "$log" 2>/dev/null | tail -50 >> "$OUTPUT_DIR/phpfpm-memory-errors.txt"
  done

  # Script timeouts
  echo "=== Script Timeouts ===" > "$OUTPUT_DIR/phpfpm-timeouts.txt"
  for log in $PHP_FPM_LOGS; do
    echo "--- Log: $log ---" >> "$OUTPUT_DIR/phpfpm-timeouts.txt"
    grep -E "max_execution_time|timeout" "$log" 2>/dev/null | tail -50 >> "$OUTPUT_DIR/phpfpm-timeouts.txt"
  done

  # Slow requests
  echo "=== PHP-FPM Slow Requests ===" > "$OUTPUT_DIR/phpfpm-slow-requests.txt"
  for log in $PHP_FPM_LOGS; do
    echo "--- Log: $log ---" >> "$OUTPUT_DIR/phpfpm-slow-requests.txt"
    grep "slow" "$log" 2>/dev/null | tail -50 >> "$OUTPUT_DIR/phpfpm-slow-requests.txt"
  done

  # Recent errors
  echo "=== Recent PHP-FPM Errors ===" > "$OUTPUT_DIR/phpfpm-recent-errors.txt"
  for log in $PHP_FPM_LOGS; do
    echo "--- Log: $log ---" >> "$OUTPUT_DIR/phpfpm-recent-errors.txt"
    tail -100 "$log" 2>/dev/null >> "$OUTPUT_DIR/phpfpm-recent-errors.txt"
  done

  echo -e "  ${GREEN}✓${NC} PHP-FPM log analysis saved"
else
  echo -e "  ${RED}✗${NC} PHP-FPM logs not found"
fi

################################################################################
# SYSTEM RESOURCE SNAPSHOT
################################################################################

echo -e "${YELLOW}[7/10] Capturing System Resource Snapshot...${NC}"

# CPU and load
echo "=== CPU and Load Average ===" > "$OUTPUT_DIR/system-resources.txt"
uptime >> "$OUTPUT_DIR/system-resources.txt"
echo "" >> "$OUTPUT_DIR/system-resources.txt"
top -bn1 | head -20 >> "$OUTPUT_DIR/system-resources.txt"

# Memory
echo "" >> "$OUTPUT_DIR/system-resources.txt"
echo "=== Memory Usage ===" >> "$OUTPUT_DIR/system-resources.txt"
free -h >> "$OUTPUT_DIR/system-resources.txt"

# Disk usage
echo "" >> "$OUTPUT_DIR/system-resources.txt"
echo "=== Disk Usage ===" >> "$OUTPUT_DIR/system-resources.txt"
df -h >> "$OUTPUT_DIR/system-resources.txt"

# Disk I/O
echo "" >> "$OUTPUT_DIR/system-resources.txt"
echo "=== Disk I/O Statistics ===" >> "$OUTPUT_DIR/system-resources.txt"
iostat -x 2>/dev/null | head -20 >> "$OUTPUT_DIR/system-resources.txt" || echo "iostat not available" >> "$OUTPUT_DIR/system-resources.txt"

# Top CPU processes
echo "=== Top 20 CPU-Consuming Processes ===" > "$OUTPUT_DIR/top-cpu-processes.txt"
ps aux --sort=-%cpu | head -21 >> "$OUTPUT_DIR/top-cpu-processes.txt"

# Top memory processes
echo "=== Top 20 Memory-Consuming Processes ===" > "$OUTPUT_DIR/top-mem-processes.txt"
ps aux --sort=-%mem | head -21 >> "$OUTPUT_DIR/top-mem-processes.txt"

echo -e "  ${GREEN}✓${NC} System resource snapshot saved"

################################################################################
# NETWORK ANALYSIS
################################################################################

echo -e "${YELLOW}[8/10] Analyzing Network Status...${NC}"

# Connection summary
echo "=== Network Connection Summary ===" > "$OUTPUT_DIR/network-status.txt"
ss -s >> "$OUTPUT_DIR/network-status.txt" 2>/dev/null || netstat -s >> "$OUTPUT_DIR/network-status.txt"

# Connection states
echo "" >> "$OUTPUT_DIR/network-status.txt"
echo "=== Connection State Distribution ===" >> "$OUTPUT_DIR/network-status.txt"
ss -tan 2>/dev/null | awk '{print $1}' | sort | uniq -c | sort -rn >> "$OUTPUT_DIR/network-status.txt" || \
  netstat -an | awk '{print $6}' | sort | uniq -c | sort -rn >> "$OUTPUT_DIR/network-status.txt"

# Established connections count
echo "" >> "$OUTPUT_DIR/network-status.txt"
echo "=== Established Connections ===" >> "$OUTPUT_DIR/network-status.txt"
ESTABLISHED_COUNT=$(ss -tan 2>/dev/null | grep ESTAB | wc -l || netstat -an | grep ESTABLISHED | wc -l)
echo "Total ESTABLISHED connections: $ESTABLISHED_COUNT" >> "$OUTPUT_DIR/network-status.txt"

# Interface statistics
echo "" >> "$OUTPUT_DIR/network-status.txt"
echo "=== Network Interface Statistics ===" >> "$OUTPUT_DIR/network-status.txt"
ip -s link >> "$OUTPUT_DIR/network-status.txt" 2>/dev/null || netstat -i >> "$OUTPUT_DIR/network-status.txt"

# Open file descriptors
echo "" >> "$OUTPUT_DIR/network-status.txt"
echo "=== Open File Descriptors ===" >> "$OUTPUT_DIR/network-status.txt"
OPEN_FDS=$(lsof 2>/dev/null | wc -l)
echo "Total open file descriptors: $OPEN_FDS" >> "$OUTPUT_DIR/network-status.txt"
echo "System limit: $(ulimit -n)" >> "$OUTPUT_DIR/network-status.txt"

echo -e "  ${GREEN}✓${NC} Network analysis saved"

################################################################################
# SYSTEM LOG ERRORS
################################################################################

echo -e "${YELLOW}[9/10] Extracting System Log Errors...${NC}"

# Recent critical errors
echo "=== Recent Critical Errors ===" > "$OUTPUT_DIR/syslog-critical.txt"
grep -iE "error|critical|fail|timeout" "$SYSLOG" | tail -200 >> "$OUTPUT_DIR/syslog-critical.txt"

# OOM killer events
echo "=== Out of Memory Events ===" > "$OUTPUT_DIR/syslog-oom.txt"
grep -i "out of memory" "$SYSLOG" >> "$OUTPUT_DIR/syslog-oom.txt"
if [ ! -s "$OUTPUT_DIR/syslog-oom.txt" ]; then
  echo "No OOM events found" > "$OUTPUT_DIR/syslog-oom.txt"
fi

# Kernel errors
echo "=== Kernel Errors ===" > "$OUTPUT_DIR/syslog-kernel.txt"
grep "kernel:" "$SYSLOG" | grep -iE "error|warn|fail" | tail -100 >> "$OUTPUT_DIR/syslog-kernel.txt"

# Service failures
echo "=== Service Start/Stop/Failures ===" > "$OUTPUT_DIR/syslog-services.txt"
grep -iE "systemd|service.*failed|service.*stopped" "$SYSLOG" | tail -100 >> "$OUTPUT_DIR/syslog-services.txt"

echo -e "  ${GREEN}✓${NC} System log errors extracted"

################################################################################
# GENERATE SUMMARY REPORT
################################################################################

echo -e "${YELLOW}[10/10] Generating Summary Report...${NC}"

SUMMARY_FILE="$OUTPUT_DIR/ANALYSIS_SUMMARY.txt"

cat > "$SUMMARY_FILE" << EOF
================================================================================
VPS TIMEOUT LOG ANALYSIS SUMMARY
================================================================================

Analysis Date: $(date)
Hostname: $(hostname)
Kernel: $(uname -r)
Uptime: $(uptime)

================================================================================
KEY FINDINGS
================================================================================

1. CRON JOBS
   - Total cron jobs inventoried: $(grep -c "^[^#]" "$OUTPUT_DIR/cron-inventory.txt" 2>/dev/null || echo "0")
   - Recent executions logged: $(wc -l < "$OUTPUT_DIR/cron-execution-history.txt" 2>/dev/null || echo "0")
   - Currently running: $(wc -l < "$OUTPUT_DIR/cron-running-processes.txt" 2>/dev/null || echo "0")

2. MYSQL PERFORMANCE
EOF

if [ -f "$OUTPUT_DIR/mysql-slow-queries.txt" ]; then
  SLOW_QUERY_COUNT=$(grep -c "Query_time" "$OUTPUT_DIR/mysql-slow-recent.txt" 2>/dev/null || echo "0")
  echo "   - Slow queries (last 24h): $SLOW_QUERY_COUNT" >> "$SUMMARY_FILE"
else
  echo "   - MySQL slow query log not available" >> "$SUMMARY_FILE"
fi

cat >> "$SUMMARY_FILE" << EOF

3. NGINX ERRORS
EOF

if [ -f "$OUTPUT_DIR/nginx-timeout-errors.txt" ]; then
  TIMEOUT_ERRORS=$(wc -l < "$OUTPUT_DIR/nginx-timeout-errors.txt")
  echo "   - Timeout errors found: $TIMEOUT_ERRORS" >> "$SUMMARY_FILE"
else
  echo "   - Nginx error log not available" >> "$SUMMARY_FILE"
fi

if [ -f "$OUTPUT_DIR/nginx-status-codes.txt" ]; then
  echo "   - Status code distribution:" >> "$SUMMARY_FILE"
  head -5 "$OUTPUT_DIR/nginx-status-codes.txt" | sed 's/^/     /' >> "$SUMMARY_FILE"
fi

cat >> "$SUMMARY_FILE" << EOF

4. PHP-FPM STATUS
EOF

if [ -f "$OUTPUT_DIR/phpfpm-max-children.txt" ]; then
  MAX_CHILDREN_WARNINGS=$(grep -c "max_children" "$OUTPUT_DIR/phpfpm-max-children.txt" 2>/dev/null || echo "0")
  MEMORY_ERRORS=$(grep -c "Allowed memory size" "$OUTPUT_DIR/phpfpm-memory-errors.txt" 2>/dev/null || echo "0")
  echo "   - Max children warnings: $MAX_CHILDREN_WARNINGS" >> "$SUMMARY_FILE"
  echo "   - Memory limit errors: $MEMORY_ERRORS" >> "$SUMMARY_FILE"
else
  echo "   - PHP-FPM logs not available" >> "$SUMMARY_FILE"
fi

cat >> "$SUMMARY_FILE" << EOF

5. SYSTEM RESOURCES
   - Load average: $(uptime | awk -F'load average:' '{print $2}')
   - Memory usage: $(free -h | grep Mem: | awk '{print $3 "/" $2}')
   - Disk usage: $(df -h / | tail -1 | awk '{print $5 " of " $2}')
   - Established connections: $ESTABLISHED_COUNT
   - Open file descriptors: $OPEN_FDS / $(ulimit -n)

6. CRITICAL SYSTEM EVENTS
   - OOM events: $(grep -c "out of memory" "$OUTPUT_DIR/syslog-oom.txt" 2>/dev/null || echo "0")
   - Kernel errors: $(wc -l < "$OUTPUT_DIR/syslog-kernel.txt" 2>/dev/null || echo "0")
   - Service failures: $(grep -c "failed" "$OUTPUT_DIR/syslog-services.txt" 2>/dev/null || echo "0")

================================================================================
TOP RECOMMENDATIONS
================================================================================

Based on the analysis, investigate the following areas for timeout root causes:

1. Check cron job timing correlation with timeout events
2. Review MySQL slow queries identified in mysql-slow-queries.txt
3. Analyze nginx timeout errors in nginx-timeout-errors.txt
4. Verify PHP-FPM pool configuration if max_children warnings exist
5. Monitor network connection states for connection exhaustion
6. Review system resource usage trends

================================================================================
OUTPUT FILES
================================================================================

All analysis results saved in: $OUTPUT_DIR

Key files:
  - cron-inventory.txt
  - mysql-slow-queries.txt
  - nginx-timeout-errors.txt
  - phpfpm-max-children.txt
  - system-resources.txt
  - network-status.txt
  - syslog-critical.txt
  - ANALYSIS_SUMMARY.txt (this file)

================================================================================
NEXT STEPS
================================================================================

1. Review all output files in $OUTPUT_DIR
2. Correlate findings with timeout incident timestamps
3. Execute hypothesis testing based on discovered patterns
4. Implement monitoring for identified risk areas
5. Document root cause and remediation plan

================================================================================
EOF

echo -e "  ${GREEN}✓${NC} Summary report generated: $SUMMARY_FILE"

################################################################################
# COMPLETION
################################################################################

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Analysis Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "All results saved in: ${BLUE}$OUTPUT_DIR${NC}"
echo ""
echo -e "Key files:"
echo -e "  - ${YELLOW}ANALYSIS_SUMMARY.txt${NC} - Executive summary"
echo -e "  - ${YELLOW}cron-*.txt${NC} - Cron job analysis"
echo -e "  - ${YELLOW}mysql-*.txt${NC} - MySQL performance data"
echo -e "  - ${YELLOW}nginx-*.txt${NC} - Nginx log analysis"
echo -e "  - ${YELLOW}phpfpm-*.txt${NC} - PHP-FPM diagnostics"
echo -e "  - ${YELLOW}system-resources.txt${NC} - Resource snapshot"
echo -e "  - ${YELLOW}network-status.txt${NC} - Network statistics"
echo -e "  - ${YELLOW}syslog-*.txt${NC} - System log errors"
echo ""
echo -e "Review the summary report:"
echo -e "  ${BLUE}cat $SUMMARY_FILE${NC}"
echo ""
echo -e "Share findings via Hive Mind:"
echo -e "  ${BLUE}npx claude-flow@alpha memory store --key 'hive/analyst/log-analysis' --value \"\$(cat $SUMMARY_FILE)\"${NC}"
echo ""

# Create tarball for easy transfer
TARBALL="$OUTPUT_DIR/../log-analysis-$(hostname)-$(date +%Y%m%d-%H%M%S).tar.gz"
tar -czf "$TARBALL" -C "$OUTPUT_DIR" . 2>/dev/null

if [ -f "$TARBALL" ]; then
  echo -e "Compressed archive created:"
  echo -e "  ${BLUE}$TARBALL${NC}"
  echo -e "  Size: $(du -h "$TARBALL" | cut -f1)"
  echo ""
fi

exit 0
