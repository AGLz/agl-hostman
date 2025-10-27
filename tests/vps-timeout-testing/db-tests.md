# Database Performance Testing Suite

## Overview

Comprehensive MySQL performance testing to identify query bottlenecks, lock contention, and database-related timeout issues during high-load periods.

## Test Scenarios

### DT-001: Slow Query Identification

**Objective:** Identify queries exceeding acceptable response time thresholds

**Prerequisites:**
- MySQL slow query log enabled
- Performance Schema enabled
- Baseline metrics collected

**Test Steps:**
```bash
# 1. Enable slow query log with aggressive threshold
sudo tee -a /etc/mysql/my.cnf << 'EOF'
[mysqld]
slow_query_log = 1
slow_query_log_file = /var/log/mysql/slow-query.log
long_query_time = 0.5
log_queries_not_using_indexes = 1
log_slow_admin_statements = 1
EOF

sudo systemctl restart mysql

# 2. Generate application load
ab -n 10000 -c 50 http://localhost/

# 3. Analyze slow query log
sudo mysqldumpslow -s t -t 20 /var/log/mysql/slow-query.log

# 4. Parse slow query details
cat > /tmp/analyze-slow-queries.sh << 'EOF'
#!/bin/bash

echo "Slow Query Analysis Report"
echo "=========================="
echo "Generated: $(date)"
echo ""

# Summary statistics
echo "=== Top 20 Slowest Queries ==="
sudo mysqldumpslow -s t -t 20 /var/log/mysql/slow-query.log

echo -e "\n=== Most Frequent Slow Queries ==="
sudo mysqldumpslow -s c -t 20 /var/log/mysql/slow-query.log

echo -e "\n=== Queries Not Using Indexes ==="
sudo grep "Query_time" /var/log/mysql/slow-query.log | grep -A 5 "not using indexes"

# Detailed analysis with pt-query-digest (if available)
if command -v pt-query-digest &> /dev/null; then
    echo -e "\n=== Percona Toolkit Analysis ==="
    sudo pt-query-digest /var/log/mysql/slow-query.log | head -100
fi

echo -e "\n=== Performance Schema Query Analysis ==="
mysql << 'SQL'
SELECT
    DIGEST_TEXT,
    COUNT_STAR as exec_count,
    ROUND(AVG_TIMER_WAIT / 1000000000, 2) as avg_time_ms,
    ROUND(MAX_TIMER_WAIT / 1000000000, 2) as max_time_ms,
    ROUND(SUM_LOCK_TIME / 1000000000, 2) as total_lock_time_ms,
    SUM_ROWS_EXAMINED as total_rows_examined,
    SUM_ROWS_SENT as total_rows_sent
FROM
    performance_schema.events_statements_summary_by_digest
ORDER BY
    AVG_TIMER_WAIT DESC
LIMIT 20;
SQL

EOF

chmod +x /tmp/analyze-slow-queries.sh
/tmp/analyze-slow-queries.sh > /tmp/slow-query-report.txt

cat /tmp/slow-query-report.txt
```

**Success Criteria:**
- <5% of queries exceed 500ms threshold
- No queries consistently >2s
- All common queries use indexes
- Lock time <10% of execution time

**Failure Indicators:**
- Frequent full table scans
- High lock wait times
- Temp table creation on disk
- Large rows examined vs. rows sent ratio

**Remediation Actions:**
1. Add missing indexes
2. Optimize JOIN operations
3. Rewrite queries with proper indexes
4. Partition large tables
5. Implement query caching

---

### DT-002: Index Usage Analysis

**Objective:** Validate proper index utilization across critical queries

**Test Steps:**
```bash
# 1. Check existing indexes
mysql << 'SQL'
SELECT
    TABLE_SCHEMA,
    TABLE_NAME,
    INDEX_NAME,
    COLUMN_NAME,
    SEQ_IN_INDEX,
    CARDINALITY
FROM
    information_schema.STATISTICS
WHERE
    TABLE_SCHEMA NOT IN ('information_schema', 'mysql', 'performance_schema', 'sys')
ORDER BY
    TABLE_SCHEMA, TABLE_NAME, INDEX_NAME, SEQ_IN_INDEX;
SQL

# 2. Analyze index usage statistics
mysql << 'SQL'
SELECT
    OBJECT_SCHEMA,
    OBJECT_NAME,
    INDEX_NAME,
    COUNT_STAR as queries_using_index,
    COUNT_READ,
    COUNT_WRITE,
    COUNT_FETCH
FROM
    performance_schema.table_io_waits_summary_by_index_usage
WHERE
    OBJECT_SCHEMA NOT IN ('information_schema', 'mysql', 'performance_schema', 'sys')
    AND INDEX_NAME IS NOT NULL
ORDER BY
    COUNT_STAR DESC
LIMIT 50;
SQL

# 3. Find unused indexes
mysql << 'SQL'
SELECT
    t.TABLE_SCHEMA,
    t.TABLE_NAME,
    s.INDEX_NAME,
    GROUP_CONCAT(s.COLUMN_NAME ORDER BY s.SEQ_IN_INDEX) as index_columns
FROM
    information_schema.TABLES t
    INNER JOIN information_schema.STATISTICS s ON t.TABLE_SCHEMA = s.TABLE_SCHEMA
        AND t.TABLE_NAME = s.TABLE_NAME
    LEFT JOIN performance_schema.table_io_waits_summary_by_index_usage i
        ON i.OBJECT_SCHEMA = s.TABLE_SCHEMA
        AND i.OBJECT_NAME = s.TABLE_NAME
        AND i.INDEX_NAME = s.INDEX_NAME
WHERE
    t.TABLE_SCHEMA NOT IN ('information_schema', 'mysql', 'performance_schema', 'sys')
    AND s.INDEX_NAME != 'PRIMARY'
    AND (i.INDEX_NAME IS NULL OR i.COUNT_STAR = 0)
GROUP BY
    t.TABLE_SCHEMA, t.TABLE_NAME, s.INDEX_NAME
ORDER BY
    t.TABLE_SCHEMA, t.TABLE_NAME;
SQL

# 4. EXPLAIN analysis of critical queries
cat > /tmp/explain-analysis.sh << 'EOF'
#!/bin/bash

# Extract common queries from slow log
QUERIES=(
    "SELECT * FROM users WHERE email = 'test@example.com'"
    "SELECT p.*, c.name FROM posts p JOIN categories c ON p.category_id = c.id WHERE p.status = 'published' ORDER BY p.created_at DESC LIMIT 20"
    # Add your application's critical queries here
)

echo "EXPLAIN Analysis of Critical Queries"
echo "====================================="

for QUERY in "${QUERIES[@]}"; do
    echo -e "\n=== Query: $QUERY ==="
    mysql -e "EXPLAIN $QUERY;" 2>&1
    echo ""
    mysql -e "EXPLAIN FORMAT=JSON $QUERY;" 2>&1 | python3 -m json.tool
done
EOF

chmod +x /tmp/explain-analysis.sh
/tmp/explain-analysis.sh
```

**Success Criteria:**
- All queries use indexes (type: ref, eq_ref, range)
- No full table scans (type: ALL) on large tables
- Rows examined close to rows returned
- No filesort or temporary tables for common queries

**Failure Indicators:**
- type: ALL on tables >1000 rows
- Using filesort
- Using temporary
- High rows examined/sent ratio

**Remediation Actions:**
1. Create composite indexes for multi-column WHERE clauses
2. Add covering indexes to avoid table lookups
3. Remove unused indexes (reduce write overhead)
4. Optimize ORDER BY with appropriate indexes

---

### DT-003: Connection Pool Performance

**Objective:** Test database connection handling under load

**Test Steps:**
```bash
# 1. Monitor current connection statistics
mysql -e "SHOW STATUS LIKE 'Connections';"
mysql -e "SHOW STATUS LIKE 'Max_used_connections';"
mysql -e "SHOW STATUS LIKE 'Threads_connected';"
mysql -e "SHOW STATUS LIKE 'Aborted_connects';"

# 2. Create connection pool test
cat > /tmp/connection-pool-test.php << 'EOF'
<?php
$config = [
    'host' => 'localhost',
    'user' => 'dbuser',
    'pass' => 'dbpass',
    'db' => 'testdb'
];

$start_time = microtime(true);
$connections = [];
$max_connections = 200;
$successful = 0;
$failed = 0;

echo "Connection Pool Performance Test\n";
echo "================================\n\n";

// Rapidly create connections
for ($i = 0; $i < $max_connections; $i++) {
    $conn_start = microtime(true);

    try {
        $conn = new mysqli(
            $config['host'],
            $config['user'],
            $config['pass'],
            $config['db']
        );

        if ($conn->connect_error) {
            $failed++;
            echo "Connection $i FAILED: {$conn->connect_error}\n";
            continue;
        }

        $conn_time = (microtime(true) - $conn_start) * 1000;
        $connections[] = $conn;
        $successful++;

        if ($conn_time > 100) {
            echo "Connection $i SLOW: {$conn_time}ms\n";
        }

        // Execute simple query
        $result = $conn->query("SELECT 1");
        if (!$result) {
            echo "Query failed on connection $i\n";
        }

    } catch (Exception $e) {
        $failed++;
        echo "Exception at connection $i: {$e->getMessage()}\n";
    }

    // Brief pause
    usleep(10000); // 10ms
}

$total_time = microtime(true) - $start_time;

echo "\n=== Results ===\n";
echo "Successful connections: $successful\n";
echo "Failed connections: $failed\n";
echo "Total time: " . round($total_time, 2) . "s\n";
echo "Avg time per connection: " . round(($total_time / $max_connections) * 1000, 2) . "ms\n";

// Cleanup
foreach ($connections as $conn) {
    $conn->close();
}

// Check for connection leaks
sleep(2);
$leaked = exec("mysql -e \"SHOW PROCESSLIST\" | grep -c 'Sleep'");
echo "Sleeping connections after cleanup: $leaked\n";
?>
EOF

php /tmp/connection-pool-test.php

# 3. Monitor connection states during test
watch -n 1 'mysql -e "SHOW PROCESSLIST" | awk "{print \$5}" | sort | uniq -c'

# 4. Check for connection errors in MySQL log
sudo grep -i "connection" /var/log/mysql/error.log | tail -20
```

**Success Criteria:**
- All connections established successfully
- Average connection time <50ms
- No connection leaks after cleanup
- Graceful handling of max_connections limit

**Failure Indicators:**
- "Too many connections" errors
- Connection time >100ms
- Sleeping connections not cleaned up
- Aborted connections increasing

**Remediation Actions:**
1. Implement connection pooling (ProxySQL/MaxScale)
2. Tune MySQL `max_connections`
3. Implement connection timeout in application
4. Use persistent connections appropriately
5. Add connection retry logic with exponential backoff

---

### DT-004: Query Cache Effectiveness

**Objective:** Measure query cache hit rate and performance impact

**Test Steps:**
```bash
# 1. Check query cache configuration
mysql -e "SHOW VARIABLES LIKE 'query_cache%';"

# 2. Monitor query cache statistics
cat > /tmp/query-cache-stats.sh << 'EOF'
#!/bin/bash

echo "Query Cache Performance Analysis"
echo "================================"
echo "Timestamp: $(date)"
echo ""

mysql << 'SQL'
SHOW STATUS LIKE 'Qcache%';
SQL

echo -e "\n=== Calculated Metrics ==="

# Calculate hit rate
mysql << 'SQL'
SELECT
    CONCAT(ROUND(
        (SELECT VARIABLE_VALUE FROM information_schema.GLOBAL_STATUS WHERE VARIABLE_NAME='Qcache_hits') /
        ((SELECT VARIABLE_VALUE FROM information_schema.GLOBAL_STATUS WHERE VARIABLE_NAME='Qcache_hits') +
         (SELECT VARIABLE_VALUE FROM information_schema.GLOBAL_STATUS WHERE VARIABLE_NAME='Com_select'))
        * 100, 2
    ), '%') as query_cache_hit_rate;
SQL

# Memory utilization
mysql << 'SQL'
SELECT
    CONCAT(ROUND(
        (SELECT VARIABLE_VALUE FROM information_schema.GLOBAL_STATUS WHERE VARIABLE_NAME='Qcache_free_memory') /
        (SELECT VARIABLE_VALUE FROM information_schema.GLOBAL_VARIABLES WHERE VARIABLE_NAME='query_cache_size')
        * 100, 2
    ), '%') as query_cache_free_pct;
SQL

# Fragmentation
mysql << 'SQL'
SELECT
    VARIABLE_VALUE as free_blocks
FROM
    information_schema.GLOBAL_STATUS
WHERE
    VARIABLE_NAME='Qcache_free_blocks';
SQL

EOF

chmod +x /tmp/query-cache-stats.sh

# 3. Capture before metrics
/tmp/query-cache-stats.sh > /tmp/qcache-before.txt

# 4. Generate load
ab -n 10000 -c 50 http://localhost/

# 5. Capture after metrics
/tmp/query-cache-stats.sh > /tmp/qcache-after.txt

# 6. Compare
diff /tmp/qcache-before.txt /tmp/qcache-after.txt
```

**Success Criteria:**
- Query cache hit rate >80% for read-heavy workloads
- Low cache fragmentation (<50 free blocks)
- Query cache memory efficiently used (>50% utilization)
- Qcache_lowmem_prunes growth <1/sec

**Failure Indicators:**
- Hit rate <50%
- High Qcache_lowmem_prunes (cache too small)
- High Qcache_inserts with low hits (ineffective caching)
- Excessive fragmentation

**Remediation Actions:**
1. Increase query_cache_size if memory allows
2. Tune query_cache_min_res_unit to reduce fragmentation
3. Disable query cache for write-heavy workloads (MySQL 8.0+)
4. Implement application-level caching (Redis/Memcached)

---

### DT-005: Lock Contention Analysis

**Objective:** Identify and measure database lock wait times

**Test Steps:**
```bash
# 1. Enable InnoDB monitor
mysql -e "SET GLOBAL innodb_status_output=ON;"
mysql -e "SET GLOBAL innodb_status_output_locks=ON;"

# 2. Create lock contention test
cat > /tmp/lock-contention-test.sql << 'SQL'
-- Test table setup
CREATE TABLE IF NOT EXISTS lock_test (
    id INT PRIMARY KEY AUTO_INCREMENT,
    value VARCHAR(255),
    counter INT DEFAULT 0
);

-- Insert test data
INSERT INTO lock_test (value) VALUES ('test1'), ('test2'), ('test3');

-- Transaction 1 (will hold lock)
START TRANSACTION;
UPDATE lock_test SET counter = counter + 1 WHERE id = 1;
-- Don't commit yet, hold the lock

SQL

# 3. Monitor locks in separate terminal
mysql << 'SQL' > /tmp/lock-monitor.log &
SELECT
    r.trx_id waiting_trx_id,
    r.trx_mysql_thread_id waiting_thread,
    r.trx_query waiting_query,
    b.trx_id blocking_trx_id,
    b.trx_mysql_thread_id blocking_thread,
    b.trx_query blocking_query,
    l.lock_mode,
    l.lock_type,
    l.lock_table
FROM
    information_schema.innodb_lock_waits w
    JOIN information_schema.innodb_trx b ON b.trx_id = w.blocking_trx_id
    JOIN information_schema.innodb_trx r ON r.trx_id = w.requesting_trx_id
    JOIN information_schema.innodb_locks l ON l.lock_trx_id = w.blocking_trx_id;
SQL

# 4. Simulate lock contention
cat > /tmp/generate-lock-contention.php << 'EOF'
<?php
$conn = new mysqli('localhost', 'dbuser', 'dbpass', 'testdb');

// Start multiple transactions trying to update same row
for ($i = 0; $i < 10; $i++) {
    $pid = pcntl_fork();

    if ($pid == 0) {
        // Child process
        $conn->begin_transaction();
        $result = $conn->query("UPDATE lock_test SET counter = counter + 1 WHERE id = 1");
        sleep(2); // Hold lock
        $conn->commit();
        exit(0);
    }
}

// Wait for children
while (pcntl_waitpid(0, $status) != -1);
?>
EOF

php /tmp/generate-lock-contention.php

# 5. Analyze InnoDB status
mysql -e "SHOW ENGINE INNODB STATUS\G" | grep -A 50 "TRANSACTIONS"

# 6. Check for deadlocks
mysql -e "SHOW ENGINE INNODB STATUS\G" | grep -A 30 "LATEST DETECTED DEADLOCK"

# 7. Performance schema lock analysis
mysql << 'SQL'
SELECT
    object_schema,
    object_name,
    index_name,
    lock_type,
    lock_mode,
    lock_status,
    COUNT(*) as lock_count
FROM
    performance_schema.data_locks
GROUP BY
    object_schema, object_name, index_name, lock_type, lock_mode, lock_status
ORDER BY
    lock_count DESC;
SQL
```

**Success Criteria:**
- Lock wait time <50ms average
- No deadlocks detected
- Lock contention on <1% of transactions
- Row-level locking (not table-level)

**Failure Indicators:**
- Frequent deadlocks
- Lock wait timeout exceeded errors
- Long lock wait times (>1s)
- Table-level locks on active tables

**Remediation Actions:**
1. Reduce transaction scope
2. Use optimistic locking where appropriate
3. Optimize transaction isolation level
4. Reorder operations to acquire locks consistently
5. Implement retry logic for deadlock victims

---

### DT-006: Backup Impact on Query Performance

**Objective:** Measure query degradation during backup operations

**Test Steps:**
```bash
# 1. Establish baseline query performance
cat > /tmp/baseline-query-perf.sh << 'EOF'
#!/bin/bash

echo "Baseline Query Performance Measurement"
echo "======================================"

# Sample queries (adjust to your schema)
QUERIES=(
    "SELECT COUNT(*) FROM users;"
    "SELECT * FROM posts ORDER BY created_at DESC LIMIT 20;"
    "SELECT u.*, COUNT(p.id) as post_count FROM users u LEFT JOIN posts p ON u.id = p.user_id GROUP BY u.id;"
)

for QUERY in "${QUERIES[@]}"; do
    echo -e "\n=== Testing: $QUERY ==="

    # Run query 10 times and measure
    for i in {1..10}; do
        START=$(date +%s%N)
        mysql -e "$QUERY" > /dev/null 2>&1
        END=$(date +%s%N)
        DURATION=$(( (END - START) / 1000000 ))
        echo "Iteration $i: ${DURATION}ms"
    done
done
EOF

chmod +x /tmp/baseline-query-perf.sh

# 2. Run baseline
/tmp/baseline-query-perf.sh > /tmp/query-perf-baseline.txt

# 3. Start backup process
mysqldump --all-databases --single-transaction --quick \
    > /tmp/backup-test.sql 2>&1 &
BACKUP_PID=$!

# 4. Run queries during backup
sleep 5  # Let backup start
/tmp/baseline-query-perf.sh > /tmp/query-perf-during-backup.txt

# 5. Wait for backup to complete
wait $BACKUP_PID

# 6. Run queries after backup
/tmp/baseline-query-perf.sh > /tmp/query-perf-after-backup.txt

# 7. Compare results
echo "=== Performance Comparison ==="
echo "Baseline:"
grep "Iteration" /tmp/query-perf-baseline.txt | awk '{sum+=$3} END {print "Average: " sum/NR "ms"}'

echo "During Backup:"
grep "Iteration" /tmp/query-perf-during-backup.txt | awk '{sum+=$3} END {print "Average: " sum/NR "ms"}'

echo "After Backup:"
grep "Iteration" /tmp/query-perf-after-backup.txt | awk '{sum+=$3} END {print "Average: " sum/NR "ms"}'

# 8. Check InnoDB buffer pool during backup
mysql -e "SHOW ENGINE INNODB STATUS\G" | grep -A 10 "BUFFER POOL"

# Cleanup
rm -f /tmp/backup-test.sql
```

**Success Criteria:**
- Query performance degradation <25% during backup
- No query timeouts during backup
- Buffer pool hit rate remains >95%
- I/O wait time increase <50%

**Failure Indicators:**
- Query timeouts during backup
- Performance degradation >50%
- Buffer pool thrashing (low hit rate)
- Excessive disk I/O wait

**Remediation Actions:**
1. Use `--single-transaction` for InnoDB consistency
2. Back up from MySQL replica (read-only slave)
3. Schedule backups during lowest traffic periods
4. Implement incremental backups instead of full dumps
5. Use binary log streaming for point-in-time recovery

---

## Automated Test Suite

```bash
#!/bin/bash
# Database performance test suite runner

TESTS_DIR="/mnt/overpower/apps/dev/agl/agl-hostman/tests/vps-timeout-testing"
RESULTS_DIR="${TESTS_DIR}/results/db-tests-$(date +%Y%m%d_%H%M%S)"

mkdir -p "$RESULTS_DIR"

echo "Starting Database Performance Test Suite - $(date)"
echo "Results directory: $RESULTS_DIR"

# Enable Performance Schema if not already enabled
mysql -e "UPDATE performance_schema.setup_instruments SET ENABLED = 'YES', TIMED = 'YES';"
mysql -e "UPDATE performance_schema.setup_consumers SET ENABLED = 'YES';"

# Run tests sequentially
TESTS=("DT-001" "DT-002" "DT-003" "DT-004" "DT-005" "DT-006")

for TEST in "${TESTS[@]}"; do
    echo "====================================="
    echo "Running Test: $TEST"
    echo "====================================="

    # Execute test-specific logic
    # (Implementation details here)

    echo "$TEST completed at $(date)" | tee -a "$RESULTS_DIR/execution.log"

    # Cooldown
    sleep 30
done

echo "Database test suite completed - $(date)"
echo "Review results in: $RESULTS_DIR"
```

---

**Version:** 1.0
**Last Updated:** 2025-10-22
**Test Count:** 6 comprehensive database scenarios
**Estimated Duration:** 4-6 hours
