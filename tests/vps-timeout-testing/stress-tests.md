# Application Stress Testing Suite

## Overview

Comprehensive stress testing strategy to identify PHP-FPM process exhaustion, connection pool limits, and application-level bottlenecks that may cause timeout conditions.

## Test Scenarios

### ST-001: PHP-FPM Pool Exhaustion Test

**Objective:** Determine maximum concurrent request capacity before timeout

**Prerequisites:**
- PHP-FPM configuration documented
- Current pool settings known
- Monitoring tools ready

**Test Steps:**
```bash
# 1. Check current PHP-FPM pool configuration
sudo cat /etc/php/*/fpm/pool.d/www.conf | grep -E "(pm.max_children|pm.start_servers|pm.min_spare_servers|pm.max_spare_servers)"

# 2. Create stress test script
cat > /tmp/php-fpm-stress-test.sh << 'EOF'
#!/bin/bash
ENDPOINT="http://localhost/index.php"
CONCURRENT_USERS=(10 25 50 100 200 300)
DURATION=60  # seconds per test

for USERS in "${CONCURRENT_USERS[@]}"; do
    echo "Testing with $USERS concurrent users..."

    # Run Apache Bench
    ab -n $(($USERS * 100)) -c $USERS -g /tmp/ab-results-${USERS}.tsv \
        -e /tmp/ab-results-${USERS}.csv "$ENDPOINT" > /tmp/ab-output-${USERS}.txt 2>&1

    # Check PHP-FPM status
    curl -s http://localhost/fpm-status?full | tee /tmp/fpm-status-${USERS}.txt

    # Capture error logs
    sudo tail -50 /var/log/php*-fpm.log > /tmp/fpm-errors-${USERS}.log

    # Wait between tests
    echo "Waiting for system to stabilize..."
    sleep 30
done

echo "Stress test completed. Analyzing results..."

# Generate report
cat > /tmp/stress-test-report.txt << 'REPORT'
PHP-FPM Stress Test Results
============================
REPORT

for USERS in "${CONCURRENT_USERS[@]}"; do
    echo -e "\n=== $USERS Concurrent Users ===" >> /tmp/stress-test-report.txt
    grep "Requests per second" /tmp/ab-output-${USERS}.txt >> /tmp/stress-test-report.txt
    grep "Time per request" /tmp/ab-output-${USERS}.txt >> /tmp/stress-test-report.txt
    grep "Failed requests" /tmp/ab-output-${USERS}.txt >> /tmp/stress-test-report.txt
done

cat /tmp/stress-test-report.txt
EOF

chmod +x /tmp/php-fpm-stress-test.sh
sudo /tmp/php-fpm-stress-test.sh
```

**Success Criteria:**
- No 502/504 errors up to expected max users
- Graceful degradation beyond capacity
- Response time <1s at 80% capacity
- Error rate <1% at peak load

**Failure Indicators:**
- Sudden response time cliff
- PHP-FPM process spawn failures
- Socket connection errors
- "Resource temporarily unavailable" errors

**Remediation Options:**
1. Increase `pm.max_children`
2. Optimize `pm.start_servers` and `pm.min_spare_servers`
3. Enable `pm.max_requests` for process recycling
4. Implement connection pooling
5. Add load balancer with multiple PHP-FPM instances

---

### ST-002: Slow Script Execution Detection

**Objective:** Identify slow-running PHP scripts causing timeout cascades

**Test Steps:**
```bash
# 1. Enable PHP-FPM slow log if not already enabled
sudo tee -a /etc/php/*/fpm/pool.d/www.conf << 'EOF'
request_slowlog_timeout = 5s
slowlog = /var/log/php-fpm-slow.log
EOF

sudo systemctl restart php*-fpm

# 2. Create test endpoint with intentional delay
cat > /var/www/html/slow-test.php << 'EOF'
<?php
// Simulate slow database query
sleep(rand(3, 10));

// Simulate heavy computation
for ($i = 0; $i < 1000000; $i++) {
    $x = md5($i);
}

echo json_encode([
    'status' => 'completed',
    'execution_time' => microtime(true) - $_SERVER['REQUEST_TIME_FLOAT']
]);
?>
EOF

# 3. Generate load on slow endpoints
for i in {1..50}; do
    curl -s http://localhost/slow-test.php &
done

# Wait for requests to complete
wait

# 4. Analyze slow log
echo "=== PHP-FPM Slow Log Analysis ==="
sudo cat /var/log/php-fpm-slow.log | grep -A 20 "pool www"

# 5. Check for timeout patterns
echo -e "\n=== Timeout Error Patterns ==="
sudo grep -i timeout /var/log/nginx/error.log | tail -20
```

**Success Criteria:**
- Slow scripts identified with stack traces
- Timeout threshold appropriately set
- No cascading timeout effect
- Graceful timeout handling

**Remediation Options:**
1. Optimize identified slow queries
2. Implement caching for expensive operations
3. Move long-running tasks to background queue
4. Increase PHP `max_execution_time` selectively
5. Implement circuit breaker pattern

---

### ST-003: Memory Leak Detection

**Objective:** Detect PHP-FPM memory leaks causing process crashes

**Test Steps:**
```bash
# 1. Monitor PHP-FPM memory before test
cat > /tmp/memory-leak-test.sh << 'EOF'
#!/bin/bash
DURATION=3600  # 1 hour test
INTERVAL=30    # Sample every 30 seconds

echo "PHP-FPM Memory Leak Detection Test"
echo "===================================="
echo "Duration: ${DURATION}s, Sampling interval: ${INTERVAL}s"

# Create output file with headers
echo "Timestamp,PID,VSZ,RSS,CPU%,Command" > /tmp/php-fpm-memory.csv

# Function to capture memory usage
capture_memory() {
    ps aux | grep php-fpm | grep -v grep | \
        awk -v ts="$(date +%s)" '{print ts","$2","$5","$6","$3","$11" "$12}' \
        >> /tmp/php-fpm-memory.csv
}

# Initial capture
capture_memory

# Generate continuous load
ab -n 100000 -c 50 http://localhost/index.php > /dev/null 2>&1 &
AB_PID=$!

# Monitor for duration
END_TIME=$(($(date +%s) + DURATION))
while [ $(date +%s) -lt $END_TIME ]; do
    sleep $INTERVAL
    capture_memory

    # Check if ab is still running, restart if needed
    if ! kill -0 $AB_PID 2>/dev/null; then
        ab -n 100000 -c 50 http://localhost/index.php > /dev/null 2>&1 &
        AB_PID=$!
    fi
done

# Stop load generation
kill $AB_PID 2>/dev/null

# Analyze results
echo -e "\n=== Memory Usage Analysis ==="
python3 << 'PYTHON'
import csv
from collections import defaultdict

memory_by_pid = defaultdict(list)

with open('/tmp/php-fpm-memory.csv', 'r') as f:
    reader = csv.DictReader(f)
    for row in reader:
        pid = row['PID']
        rss = int(row['RSS'])
        memory_by_pid[pid].append(rss)

print("Memory Leak Detection Results:")
print("=" * 50)

for pid, rss_values in memory_by_pid.items():
    if len(rss_values) < 2:
        continue

    initial = rss_values[0]
    final = rss_values[-1]
    max_rss = max(rss_values)
    growth = final - initial
    growth_pct = (growth / initial * 100) if initial > 0 else 0

    print(f"\nPID {pid}:")
    print(f"  Initial RSS: {initial} KB")
    print(f"  Final RSS: {final} KB")
    print(f"  Max RSS: {max_rss} KB")
    print(f"  Growth: {growth} KB ({growth_pct:.2f}%)")

    if growth_pct > 50:
        print(f"  ⚠️  WARNING: Significant memory growth detected!")
PYTHON

EOF

chmod +x /tmp/memory-leak-test.sh
sudo /tmp/memory-leak-test.sh
```

**Success Criteria:**
- Memory growth <10% over test duration
- No OOM (Out of Memory) killer activations
- Stable RSS after warmup period
- `pm.max_requests` causing regular recycling

**Failure Indicators:**
- Steady memory increase (linear growth)
- Process killed by OOM killer
- Swap usage increasing
- Memory not freed after request completion

**Remediation Options:**
1. Set aggressive `pm.max_requests` (e.g., 500)
2. Audit PHP extensions for leaks
3. Update PHP to latest stable version
4. Review application code for circular references
5. Enable opcache to reduce memory pressure

---

### ST-004: Database Connection Pool Exhaustion

**Objective:** Test MySQL connection limits under heavy load

**Test Steps:**
```bash
# 1. Check current MySQL connection settings
mysql -e "SHOW VARIABLES LIKE 'max_connections';"
mysql -e "SHOW STATUS LIKE 'Threads_connected';"
mysql -e "SHOW STATUS LIKE 'Max_used_connections';"

# 2. Create connection stress test
cat > /tmp/mysql-connection-stress.php << 'EOF'
<?php
// Intentionally hold database connections
$connections = [];
$max_connections = 100;

for ($i = 0; $i < $max_connections; $i++) {
    try {
        $conn = new mysqli('localhost', 'dbuser', 'dbpass', 'dbname');
        if ($conn->connect_error) {
            echo "Connection $i failed: " . $conn->connect_error . "\n";
            break;
        }
        $connections[] = $conn;
        echo "Connection $i established\n";

        // Simulate active query
        $conn->query("SELECT SLEEP(0.1)");
    } catch (Exception $e) {
        echo "Exception at connection $i: " . $e->getMessage() . "\n";
        break;
    }
}

echo "Total connections established: " . count($connections) . "\n";

// Hold connections for analysis
sleep(30);

// Cleanup
foreach ($connections as $conn) {
    $conn->close();
}
?>
EOF

# 3. Run connection stress test
php /tmp/mysql-connection-stress.php &

# 4. Monitor MySQL during test
watch -n 1 'mysql -e "SHOW PROCESSLIST;" | head -30'

# 5. Check for connection errors in logs
sudo tail -f /var/log/mysql/error.log
```

**Success Criteria:**
- No "Too many connections" errors
- Connection pool scales to expected load
- Proper connection cleanup after use
- No connection leak

**Failure Indicators:**
- MySQL error: "Too many connections"
- Long-running SLEEP queries accumulating
- Connection timeouts
- Application hanging on database operations

**Remediation Options:**
1. Increase MySQL `max_connections`
2. Implement connection pooling (ProxySQL)
3. Optimize query execution time
4. Implement connection timeout in application
5. Use persistent connections wisely

---

### ST-005: Concurrent Write Lock Contention

**Objective:** Test application behavior under heavy write concurrency

**Test Steps:**
```bash
# 1. Create concurrent write test script
cat > /tmp/concurrent-write-test.php << 'EOF'
<?php
$conn = new mysqli('localhost', 'dbuser', 'dbpass', 'testdb');

// Simulate write-heavy operation
$start = microtime(true);

for ($i = 0; $i < 100; $i++) {
    $stmt = $conn->prepare("INSERT INTO test_table (data, timestamp) VALUES (?, NOW())");
    $data = md5(rand());
    $stmt->bind_param("s", $data);
    $stmt->execute();
}

$duration = microtime(true) - $start;
echo "Completed 100 writes in {$duration}s\n";

$conn->close();
?>
EOF

# 2. Run concurrent write tests
for i in {1..50}; do
    php /tmp/concurrent-write-test.php &
done

# 3. Monitor lock waits
mysql -e "SHOW ENGINE INNODB STATUS\G" | grep -A 20 "TRANSACTIONS"

# 4. Check for deadlocks
mysql -e "SHOW ENGINE INNODB STATUS\G" | grep -A 30 "LATEST DETECTED DEADLOCK"

# Wait for tests to complete
wait

# 5. Analyze results
echo "=== Lock Wait Analysis ==="
mysql -e "SELECT * FROM information_schema.INNODB_LOCKS;"
mysql -e "SELECT * FROM information_schema.INNODB_LOCK_WAITS;"
```

**Success Criteria:**
- No deadlocks detected
- Lock wait time <100ms
- Write throughput scales linearly
- No transaction rollbacks

**Failure Indicators:**
- Deadlock errors
- Lock wait timeout exceeded
- Transaction serialization failures
- Significant write latency increase

**Remediation Options:**
1. Optimize transaction isolation level
2. Reduce transaction scope
3. Implement optimistic locking
4. Use row-level locking instead of table locks
5. Batch write operations

---

### ST-006: Integrated Load Test (Peak Simulation)

**Objective:** Simulate peak morning load with all components stressed

**Test Steps:**
```bash
# 1. Create integrated load test
cat > /tmp/integrated-load-test.sh << 'EOF'
#!/bin/bash
DURATION=600  # 10 minutes
CONCURRENT_USERS=100

echo "Integrated Load Test - Peak Simulation"
echo "======================================"
echo "Duration: ${DURATION}s"
echo "Concurrent Users: ${CONCURRENT_USERS}"

# Start monitoring
dstat -tcmdn --output /tmp/integrated-load-dstat.csv 1 &
DSTAT_PID=$!

# Monitor PHP-FPM
watch -n 5 'curl -s http://localhost/fpm-status' > /tmp/fpm-status-integrated.log &
FPMWATCH_PID=$!

# Monitor MySQL
watch -n 5 'mysqladmin processlist' > /tmp/mysql-processlist-integrated.log &
MYSQLWATCH_PID=$!

# Generate mixed workload
echo "Starting mixed workload..."

# Read-heavy requests (70%)
ab -n 10000 -c 70 http://localhost/index.php > /tmp/ab-read-heavy.txt 2>&1 &

# Write requests (20%)
ab -n 3000 -c 20 -p /tmp/post-data.txt -T 'application/x-www-form-urlencoded' \
    http://localhost/api/write.php > /tmp/ab-write.txt 2>&1 &

# Heavy queries (10%)
ab -n 1000 -c 10 http://localhost/reports/heavy.php > /tmp/ab-heavy.txt 2>&1 &

# Wait for load test to complete
sleep $DURATION

# Stop monitoring
kill $DSTAT_PID $FPMWATCH_PID $MYSQLWATCH_PID 2>/dev/null

echo "Load test completed. Generating report..."

# Generate comprehensive report
cat > /tmp/integrated-load-report.txt << 'REPORT'
Integrated Load Test Report
============================

=== Read-Heavy Endpoint ===
REPORT
grep -E "(Requests per second|Time per request|Failed requests)" /tmp/ab-read-heavy.txt >> /tmp/integrated-load-report.txt

cat >> /tmp/integrated-load-report.txt << 'REPORT'

=== Write Endpoint ===
REPORT
grep -E "(Requests per second|Time per request|Failed requests)" /tmp/ab-write.txt >> /tmp/integrated-load-report.txt

cat >> /tmp/integrated-load-report.txt << 'REPORT'

=== Heavy Query Endpoint ===
REPORT
grep -E "(Requests per second|Time per request|Failed requests)" /tmp/ab-heavy.txt >> /tmp/integrated-load-report.txt

cat /tmp/integrated-load-report.txt
EOF

chmod +x /tmp/integrated-load-test.sh
sudo /tmp/integrated-load-test.sh
```

**Success Criteria:**
- Failed requests <1%
- Average response time <500ms
- 95th percentile <1000ms
- No component reaches 100% utilization
- System recovers within 60s after test

**Failure Indicators:**
- Cascading failures across components
- Unrecoverable error state
- Permanent performance degradation
- Resource exhaustion

**Remediation Summary:**
Results from this test inform overall system tuning and capacity planning.

---

## Test Execution Framework

```bash
#!/bin/bash
# Automated stress test suite runner

TESTS_DIR="/mnt/overpower/apps/dev/agl/agl-hostman/tests/vps-timeout-testing"
RESULTS_DIR="${TESTS_DIR}/results/stress-tests-$(date +%Y%m%d_%H%M%S)"

mkdir -p "$RESULTS_DIR"

echo "Starting Application Stress Test Suite - $(date)"
echo "Results directory: $RESULTS_DIR"

# Run tests in sequence (not parallel to avoid interference)
TESTS=("ST-001" "ST-002" "ST-003" "ST-004" "ST-005" "ST-006")

for TEST in "${TESTS[@]}"; do
    echo "====================================="
    echo "Running Test: $TEST"
    echo "====================================="

    # Execute test
    # (Test-specific execution logic)

    # Capture results
    echo "$TEST completed at $(date)" | tee -a "$RESULTS_DIR/execution.log"

    # Cooldown between tests
    echo "Cooldown period (60s)..."
    sleep 60
done

echo "Stress test suite completed - $(date)"
echo "Review results in: $RESULTS_DIR"
```

---

**Version:** 1.0
**Last Updated:** 2025-10-22
**Test Count:** 6 comprehensive stress scenarios
**Estimated Duration:** 1-2 days (staging), 3-4 hours (production monitoring)
