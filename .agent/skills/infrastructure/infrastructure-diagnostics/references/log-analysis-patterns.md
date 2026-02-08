# Log Analysis Patterns

This guide covers patterns and techniques for analyzing logs to identify issues, troubleshoot problems, and detect anomalies in the AGL infrastructure.

## Table of Contents

1. [Quick Reference](#quick-reference)
2. [Log Sources](#log-sources)
3. [Analysis Techniques](#analysis-techniques)
4. [Common Patterns](#common-patterns)
5. [Error Detection](#error-detection)
6. [Performance Analysis](#performance-analysis)
7. [Security Analysis](#security-analysis)
8. [Automated Analysis](#automated-analysis)

---

## Quick Reference

### Essential Commands

```bash
# View logs in real-time
tail -f storage/logs/laravel.log
tail -f /var/log/nginx/error.log
docker logs <container> -f

# Search for errors
grep -i "error" storage/logs/laravel.log
grep -i "exception" storage/logs/laravel.log
grep -i "critical" storage/logs/laravel.log

# Find recent entries
grep "$(date +%Y-%m-%d)" storage/logs/laravel.log

# Count occurrences
grep -c "error" storage/logs/laravel.log

# Extract specific fields
grep -oP '"type":"\K[^"]+' storage/logs/laravel.log | sort | uniq -c
```

---

## Log Sources

### Application Logs

**Location:** `storage/logs/laravel.log`

**Format:** JSON (if configured) or text

**Key Information:**
- Timestamp
- Log level (INFO, WARNING, ERROR, CRITICAL)
- Message
- Context (user, request ID, etc.)
- Stack trace (for exceptions)

**Example:**
```json
{
  "timestamp": "2025-01-20T10:30:45Z",
  "level": "ERROR",
  "message": "Database connection failed",
  "context": {
    "user_id": "123",
    "request_id": "abc-123",
    "exception": "Illuminate\\Database\\QueryException"
  },
  "stack_trace": "..."
}
```

### Nginx Logs

**Access Log:** `/var/log/nginx/access.log`

**Error Log:** `/var/log/nginx/error.log`

**Format:** Combined log format

**Key Information:**
- IP address
- Timestamp
- HTTP method and path
- Status code
- Response size
- Referrer
- User agent

**Example:**
```
192.168.1.100 - - [20/Jan/2025:10:30:45 +0000] "GET /api/health HTTP/1.1" 200 1234 "-" "Mozilla/5.0"
```

### Docker Container Logs

**Access:** `docker logs <container>`

**View specific time range:**
```bash
docker logs <container> --since 1h
docker logs <container> --until 2025-01-20T10:00:00
docker logs <container> --since 2025-01-20T09:00:00 --until 2025-01-20T10:00:00
```

### System Logs

**Journalctl:**
```bash
# View all logs
journalctl -f

# View specific service
journalctl -u nginx -f

# View logs from last hour
journalctl --since "1 hour ago"

# View logs with error priority
journalctl -p err
```

---

## Analysis Techniques

### Time-Based Analysis

**Identify patterns over time:**

```bash
# Extract timestamps and count per hour
grep -oP '\d{4}-\d{2}-\d{2}T\d{2}:' storage/logs/laravel.log | \
  sort | uniq -c | sort -nr

# Plot errors over time (requires gnuplot)
grep -i "error" storage/logs/laravel.log | \
  grep -oP '\d{4}-\d{2}-\d{2}T\d{2}:' | \
  sort | uniq -c > errors_per_hour.txt
```

### Frequency Analysis

**Find most common log entries:**

```bash
# Extract unique log messages and count
grep -oP '"message":"\K[^"]+' storage/logs/laravel.log | \
  sort | uniq -c | sort -nr | head -20

# Find most common error types
grep -oP '"type":"\K[^"]+' storage/logs/laravel.log | \
  sort | uniq -c | sort -nr

# Find most common sources
grep -oP '"source":"\K[^"]+' storage/logs/laravel.log | \
  sort | uniq -c | sort -nr
```

### Pattern Matching

**Regex patterns for common issues:**

```bash
# Connection errors
grep -P "Connection refused|Connection timeout|Could not connect" storage/logs/laravel.log

# Memory issues
grep -P "Out of memory|OOM|Memory exhausted" storage/logs/laravel.log

# Database errors
grep -P "SQLSTATE|QueryException|Database connection" storage/logs/laravel.log

# Authentication errors
grep -P "Authentication failed|Unauthorized|401|403" storage/logs/laravel.log
```

### Correlation Analysis

**Find related events:**

```bash
# Find events around a specific time
grep "2025-01-20T10:30:" storage/logs/laravel.log

# Trace a request through logs
grep "request-id-abc-123" storage/logs/laravel.log

# Find errors after a deployment
grep "2025-01-20T1[0-2]:" storage/logs/laravel.log | grep -i error
```

---

## Common Patterns

### Startup Issues

**Pattern:** Multiple errors at application start

**Example:**
```bash
# Find startup errors
grep "Local[*]." storage/logs/laravel.log | grep -i error
```

**Look for:**
- Configuration errors
- Missing environment variables
- Failed service connections
- Missing migrations

### Memory Leaks

**Pattern:** Memory usage increasing over time

**Detection:**
```bash
# Find OOM killer messages
grep -i "out of memory\|OOM\|killed process" /var/log/syslog

# Monitor container restarts
docker ps -a | grep "Restarting"

# Find memory patterns in logs
grep -i "memory.*exceeded\|allocation.*failed" storage/logs/laravel.log
```

### Database Connection Pool Exhaustion

**Pattern:** "Too many connections" errors

**Detection:**
```bash
# Find connection errors
grep -i "too many connections\|connection pool" storage/logs/laravel.log

# Correlate with database logs
mysql -e "SELECT * FROM mysql.slow_log ORDER BY start_time DESC LIMIT 10;"
```

### Queue Processing Delays

**Pattern:** Jobs taking longer than expected

**Detection:**
```bash
# Find slow jobs
grep -oP '"duration":\d+' storage/logs/laravel.log | \
  awk -F: '$2 > 60000 {print "Slow job: " $2 "ms"}'

# Monitor queue depth over time
redis-cli -n 1 llen queues:default
```

---

## Error Detection

### Critical Error Patterns

```bash
# Database errors
grep -E "SQLSTATE|QueryException|PDOException" storage/logs/laravel.log

# HTTP errors
grep -E "HTTP 5[0-9]{2}|Connection refused|Timeout" storage/logs/laravel.log

# File system errors
grep -E "No such file|Permission denied|Disk full" storage/logs/laravel.log

# Service errors
grep -E "Service unavailable|503|502|504" storage/logs/laravel.log
```

### Exception Tracking

```bash
# Extract exception types
grep -oP '"exception":"[^"]+' storage/logs/laravel.log | \
  cut -d: -f2 | sort | uniq -c | sort -nr

# Find unhandled exceptions
grep -i "unhandled exception" storage/logs/laravel.log

# Trace exception frequency
grep -oP '"exception":"\K[^"]+' storage/logs/laravel.log | \
  sort | uniq -c | sort -nr
```

### Error Rate Calculation

```bash
# Calculate errors per minute
for i in {0..59}; do
  count=$(grep "2025-01-20T10:${i}:" storage/logs/laravel.log | grep -c "ERROR")
  echo "10:${i}: $count errors"
done

# Find error spikes
grep -oP '\d{4}-\d{2}-\d{2}T\d{2}:' storage/logs/laravel.log | \
  sort | uniq -c | awk '$1 > 100 {print "High error count: " $0}'
```

---

## Performance Analysis

### Slow Query Detection

```bash
# Find slow query logs
grep -i "slow query" /var/log/mysql/slow.log

# Extract query duration
grep -oP '"duration":\d+' storage/logs/laravel.log | \
  awk -F: '$2 > 1000 {print "Slow query: " $2 "ms"}'

# Find N+1 query patterns
grep -c "SELECT * FROM" storage/logs/laravel.log
```

### Response Time Analysis

```bash
# Extract response times from Nginx logs
awk '{print $NF}' /var/log/nginx/access.log | \
  awk '{total+=$1; count++} END {print "Avg:", total/count, "ms"}'

# Find slow requests
awk '$NF > 5000 {print "Slow request:", $0}' /var/log/nginx/access.log

# Response time distribution
awk '{print int($NF/1000)}' /var/log/nginx/access.log | \
  sort | uniq -c | sort -n
```

### Throughput Analysis

```bash
# Requests per second
awk '{print $4}' /var/log/nginx/access.log | \
  cut -d: -f2 | cut -d] -f1 | sort | uniq -c

# Calculate RPS for last minute
grep "$(date +%d/%b/%Y:%H:%M)" /var/log/nginx/access.log | wc -l
```

---

## Security Analysis

### Brute Force Detection

```bash
# Find many failed auth attempts from same IP
awk '$9 == 401 {print $1}' /var/log/nginx/access.log | \
  sort | uniq -c | sort -nr | awk '$1 > 10 {print "Potential brute force: " $0}'

# Find repeated login failures
grep -i "login failed" storage/logs/laravel.log | \
  grep -oP '"ip":"\K[^"]+' | sort | uniq -c | sort -nr
```

### SQL Injection Attempts

```bash
# Find suspicious query patterns
grep -iE "union.*select|or.*1=1|drop.*table|' OR '1'='1" /var/log/nginx/access.log

# Find encoded injection attempts
grep -iE "%27%20OR|union%20select|%20OR%201%3D1" /var/log/nginx/access.log
```

### Anomaly Detection

```bash
# Find unusual user agents
grep -oP '"user_agent":"\K[^"]+' storage/logs/laravel.log | \
  sort | uniq -c | sort -nr | awk '$1 < 5 {print "Unusual UA: " $0}'

# Find requests from unusual IPs
awk '{print $1}' /var/log/nginx/access.log | \
  sort | uniq -c | sort -nr | awk '$1 < 10 {print "Unusual IP: " $0}'
```

---

## Automated Analysis

### Log Analysis Scripts

**Create analysis reports:**

```bash
#!/bin/bash
# analyze_logs.sh

LOG_FILE="storage/logs/laravel.log"
REPORT_FILE="log_analysis_$(date +%Y%m%d_%H%M%S).txt"

echo "Log Analysis Report - $(date)" > "$REPORT_FILE"
echo "================================" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

# Error summary
echo "=== Error Summary ===" >> "$REPORT_FILE"
grep -c "ERROR" "$LOG_FILE" >> "$REPORT_FILE"
grep -c "CRITICAL" "$LOG_FILE" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

# Top errors
echo "=== Top Errors ===" >> "$REPORT_FILE"
grep -oP '"message":"\K[^"]+' "$LOG_FILE" | \
  sort | uniq -c | sort -nr | head -10 >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

# Error types
echo "=== Error Types ===" >> "$REPORT_FILE"
grep -oP '"type":"\K[^"]+' "$LOG_FILE" | \
  sort | uniq -c | sort -nr >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

# Error sources
echo "=== Error Sources ===" >> "$REPORT_FILE"
grep -oP '"source":"\K[^"]+' "$LOG_FILE" | \
  sort | uniq -c | sort -nr >> "$REPORT_FILE"

echo "Report saved to: $REPORT_FILE"
```

### Real-time Monitoring

**Monitor for specific patterns:**

```bash
#!/bin/bash
# monitor_logs.sh

tail -f storage/logs/laravel.log | while read -r line; do
  if echo "$line" | grep -q "ERROR\|CRITICAL"; then
    echo "ALERT: $line"
    # Send notification
    # curl -X POST "$WEBHOOK_URL" -d "message=$line"
  fi
done
```

### Periodic Health Check

```bash
#!/bin/bash
# log_health_check.sh

# Check for critical errors in last hour
CRITICAL_COUNT=$(grep "$(date +%Y-%m-%d-%H)" storage/logs/laravel.log | grep -c "CRITICAL")

if [ "$CRITICAL_COUNT" -gt 10 ]; then
  echo "ALERT: High critical error count: $CRITICAL_COUNT"
  # Send alert
fi

# Check for new error types
NEW_ERRORS=$(grep "$(date +%Y-%m-%d)" storage/logs/laravel.log | \
  grep -oP '"type":"\K[^"]+' | sort -u | wc -l)

echo "Error types today: $NEW_ERRORS"
```

---

## Alert Integration

### Using Alert Model Patterns

Based on `app/Models/Alert.php`:

```php
// Create alerts from log analysis
$alert = Alert::create([
    'type' => 'critical',
    'title' => 'High Error Rate Detected',
    'message' => "Found {$errorCount} errors in the last hour",
    'source' => 'logs',
    'severity' => 90,
    'status' => 'active',
    'metadata' => [
        'error_types' => $errorTypes,
        'time_range' => 'last_hour',
    ],
]);

// Auto-resolve if condition improves
if ($alert->shouldAutoResolve()) {
    $alert->resolve('Error rate normalized');
}
```

### Thresholds from Monitoring Config

```php
use Illuminate\Support\Facades\Config;

$thresholds = Config::get('monitoring.thresholds.server');

if ($cpuUsage > $thresholds['cpu']['critical']) {
    // Create critical alert
    Alert::create([
        'type' => 'critical',
        'title' => 'CPU Critical',
        'message' => "CPU usage: {$cpuUsage}%",
        'severity' => 90,
    ]);
}
```

---

## Best Practices

1. **Centralize Logs** - Use ELK stack or similar for aggregation
2. **Standardize Format** - Use JSON logs for easy parsing
3. **Include Context** - Add request IDs, user IDs to logs
4. **Rotate Logs** - Prevent disk space issues
5. **Monitor Log Growth** - Alert on excessive logging
6. **Archive Old Logs** - Keep for compliance and analysis
7. **Use Log Levels** - DEBUG, INFO, WARNING, ERROR, CRITICAL
8. **Don't Log Sensitive Data** - Exclude passwords, tokens
9. **Review Logs Regularly** - Daily health checks
10. **Automate Analysis** - Use scripts and monitoring tools
