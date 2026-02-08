#!/bin/bash
# Database High Availability Test Script
# Simulates failures and tests failover for MySQL, PostgreSQL, and Redis
#
# Usage:
#   ./db-ha-test.sh --db=mysql|postgres|redis --test=failure|lag|partition|recovery
#
# Environment Variables:
#   DB_HOST                  Database host (default: localhost)
#   DB_PORT                  Database port
#   DB_USER                  Database user
#   DB_PASSWORD              Database password
#   TEST_DURATION            Test duration in seconds (default: 60)
#   RECOVERY_WAIT            Wait time for recovery (default: 30)
#
# Dependencies:
#   - mysql-client or postgresql-client or redis-tools
#   - netem (for network simulation)
#   - iperf3 (for network testing)
#
# Author: Database High Availability Skill
# Version: 1.0.0

set -euo pipefail

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
DB_HOST="${DB_HOST:-localhost}"
DB_PORT="${DB_PORT:-}"
DB_USER="${DB_USER:-root}"
DB_PASSWORD="${DB_PASSWORD:-}"
TEST_DURATION="${TEST_DURATION:-60}"
RECOVERY_WAIT="${RECOVERY_WAIT:-30}"
TEST_RESULTS_DIR="/var/lib/db-ha-test-results"

# Test state
TEST_START_TIME=""
TEST_END_TIME=""
TEST_PASSED=0
TEST_FAILED=0

# Functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $(date '+%Y-%m-%d %H:%M:%S') $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $(date '+%Y-%m-%d %H:%M:%S') $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $(date '+%Y-%m-%d %H:%M:%S') $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $(date '+%Y-%m-%d %H:%M:%S') $1"
}

start_test() {
    local test_name="$1"

    TEST_START_TIME=$(date +%s)

    log_info "=========================================="
    log_info "Starting test: $test_name"
    log_info "=========================================="
}

end_test() {
    local test_name="$1"
    local status="$2"

    TEST_END_TIME=$(date +%s)
    local duration=$((TEST_END_TIME - TEST_START_TIME))

    if [[ "$status" == "PASS" ]]; then
        TEST_PASSED=$((TEST_PASSED + 1))
        log_success "Test $test_name PASSED (duration: ${duration}s)"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        log_error "Test $test_name FAILED (duration: ${duration}s)"
    fi

    echo ""
}

# MySQL Tests
test_mysql_connection() {
    local host="$1"

    if mysqladmin -h "$host" -u "$DB_USER" -p"$DB_PASSWORD" ping &>/dev/null; then
        return 0
    else
        return 1
    fi
}

test_mysql_replication_status() {
    local host="$1"

    local status=$(mysql -h "$host" -u "$DB_USER" -p"$DB_PASSWORD" -e "SHOW SLAVE STATUS\G" 2>/dev/null)

    local io_running=$(echo "$status" | grep "Slave_IO_Running:" | awk '{print $2}')
    local sql_running=$(echo "$status" | grep "Slave_SQL_Running:" | awk '{print $2}')
    local lag=$(echo "$status" | grep "Seconds_Behind_Master:" | awk '{print $2}')

    echo "IO_Running=$io_running,SQL_Running=$sql_running,Lag=$lag"
}

test_mysql_failover() {
    start_test "MySQL Master Failover"

    local master_host="$DB_HOST"
    local slave_hosts="${SLAVE_HOSTS:-}"

    if [[ -z "$slave_hosts" ]]; then
        log_error "SLAVE_HOSTS environment variable required"
        end_test "MySQL Master Failover" "FAIL"
        return 1
    fi

    # Check initial state
    log_info "Checking initial state..."

    if ! test_mysql_connection "$master_host"; then
        log_error "Master is already down"
        end_test "MySQL Master Failover" "FAIL"
        return 1
    fi

    log_info "Master is up: $master_host"

    IFS=',' read -ra HOSTS <<< "$slave_hosts"
    for host in "${HOSTS[@]}"; do
        host=$(echo "$host" | xargs)
        local status=$(test_mysql_replication_status "$host")
        log_info "Slave $host: $status"
    done

    # Simulate master failure
    log_warning "Simulating master failure (stopping MySQL)..."

    if [[ "$DRY_RUN" != "true" ]]; then
        ssh "$master_host" "systemctl stop mysql" || {
            log_error "Failed to stop MySQL on master"
            end_test "MySQL Master Failover" "FAIL"
            return 1
        }
    else
        log_info "[DRY RUN] Would stop MySQL on $master_host"
    fi

    sleep 5

    # Verify master is down
    if test_mysql_connection "$master_host"; then
        log_error "Master is still responding"
        end_test "MySQL Master Failover" "FAIL"
        return 1
    fi

    log_success "Master is confirmed down"

    # Wait for failover (automatic or manual)
    log_info "Waiting for failover to complete..."
    sleep 10

    # Check if a slave has been promoted
    local promoted_host=""
    for host in "${HOSTS[@]}"; do
        host=$(echo "$host" | xargs)

        local read_only=$(mysql -h "$host" -u "$DB_USER" -p"$DB_PASSWORD" \
            -e "SELECT @@read_only" -s -N 2>/dev/null || echo "1")

        if [[ "$read_only" == "0" ]]; then
            promoted_host="$host"
            break
        fi
    done

    if [[ -z "$promoted_host" ]]; then
        log_error "No slave was promoted to master"

        # Restore master
        log_warning "Restoring master..."
        if [[ "$DRY_RUN" != "true" ]]; then
            ssh "$master_host" "systemctl start mysql"
        fi

        end_test "MySQL Master Failover" "FAIL"
        return 1
    fi

    log_success "Slave promoted to master: $promoted_host"

    # Test write operation on new master
    log_info "Testing write operation on new master..."

    local test_db="ha_test_$(date +%s)"

    if mysql -h "$promoted_host" -u "$DB_USER" -p"$DB_PASSWORD" \
        -e "CREATE DATABASE $test_db;" &>/dev/null; then

        mysql -h "$promoted_host" -u "$DB_USER" -p"$DB_PASSWORD" \
            -e "DROP DATABASE $test_db;" &>/dev/null

        log_success "Write operation successful on new master"
    else
        log_error "Write operation failed on new master"

        # Restore master
        if [[ "$DRY_RUN" != "true" ]]; then
            ssh "$master_host" "systemctl start mysql"
        fi

        end_test "MySQL Master Failover" "FAIL"
        return 1
    fi

    # Restore original master
    log_warning "Restoring original master..."

    if [[ "$DRY_RUN" != "true" ]]; then
        ssh "$master_host" "systemctl start mysql"
        sleep 5

        # Configure as slave
        mysql -h "$master_host" -u "$DB_USER" -p"$DB_PASSWORD" <<SQL
STOP SLAVE;
CHANGE MASTER TO
  MASTER_HOST='$promoted_host',
  MASTER_USER='replicator',
  MASTER_PASSWORD='$REPLICATOR_PASSWORD',
  MASTER_AUTO_POSITION=1;
START SLAVE;
SQL
    fi

    log_success "Original master restored as slave"

    end_test "MySQL Master Failover" "PASS"
    return 0
}

test_mysql_replication_lag() {
    start_test "MySQL Replication Lag"

    local slave_hosts="${SLAVE_HOSTS:-}"

    if [[ -z "$slave_hosts" ]]; then
        log_error "SLAVE_HOSTS environment variable required"
        end_test "MySQL Replication Lag" "FAIL"
        return 1
    fi

    # Insert test data on master
    log_info "Inserting test data on master..."

    local test_table="ha_lag_test_$(date +%s)"

    mysql -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASSWORD" <<SQL
CREATE DATABASE IF NOT EXISTS ha_test;
USE ha_test;
CREATE TABLE $test_table (id INT PRIMARY KEY, data VARCHAR(255));
INSERT INTO $test_table SELECT generate_series, 'test data' FROM generate_series(1, 1000);
SQL

    # Measure replication lag
    log_info "Measuring replication lag..."

    local max_lag=0

    IFS=',' read -ra HOSTS <<< "$slave_hosts"
    for host in "${HOSTS[@]}"; do
        host=$(echo "$host" | xargs)

        # Wait for replication
        sleep 2

        local lag=$(mysql -h "$host" -u "$DB_USER" -p"$DB_PASSWORD" \
            -e "SHOW SLAVE STATUS\G" 2>/dev/null | \
            grep "Seconds_Behind_Master:" | awk '{print $2}')

        if [[ "$lag" == "NULL" ]]; then
            log_error "Replication not running on $host"
            end_test "MySQL Replication Lag" "FAIL"
            return 1
        fi

        log_info "Slave $host lag: ${lag}s"

        if (( $(echo "$lag > $max_lag" | bc -l) )); then
            max_lag=$lag
        fi
    done

    # Verify data on all slaves
    log_info "Verifying data on slaves..."

    for host in "${HOSTS[@]}"; do
        host=$(echo "$host" | xargs)

        local count=$(mysql -h "$host" -u "$DB_USER" -p"$DB_PASSWORD" \
            -e "SELECT COUNT(*) FROM ha_test.$test_table" -s -N 2>/dev/null || echo "0")

        if [[ "$count" == "1000" ]]; then
            log_success "Data verified on $host"
        else
            log_error "Data mismatch on $host: expected 1000, got $count"

            mysql -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASSWORD" \
                -e "DROP TABLE ha_test.$test_table;"

            end_test "MySQL Replication Lag" "FAIL"
            return 1
        fi
    done

    # Cleanup
    mysql -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASSWORD" \
        -e "DROP TABLE ha_test.$test_table;"

    # Check lag threshold
    if (( $(echo "$max_lag < 5" | bc -l) )); then
        log_success "Replication lag within threshold: ${max_lag}s"
        end_test "MySQL Replication Lag" "PASS"
        return 0
    else
        log_warning "Replication lag above threshold: ${max_lag}s"
        end_test "MySQL Replication Lag" "FAIL"
        return 1
    fi
}

# PostgreSQL Tests
test_postgresql_replication_status() {
    local host="$1"

    psql -h "$host" -U "$DB_USER" -c "SELECT now() - pg_last_xact_replay_timestamp() AS lag;" -t 2>/dev/null | xargs
}

test_postgresql_failover() {
    start_test "PostgreSQL Master Failover"

    local master_host="$DB_HOST"

    # Similar to MySQL failover test
    # Implementation depends on using Patroni or manual failover

    log_info "PostgreSQL failover test requires Patroni configuration"
    log_info "Test skipped - configure Patroni first"

    end_test "PostgreSQL Master Failover" "SKIP"
    return 0
}

# Redis Tests
test_redis_connection() {
    local host="$1"
    local port="${2:-6379}"

    if redis-cli -h "$host" -p "$port" ${DB_PASSWORD:+-a "$DB_PASSWORD"} ping &>/dev/null; then
        return 0
    else
        return 1
    fi
}

test_redis_sentinel_failover() {
    start_test "Redis Sentinel Failover"

    local sentinel_port="${DB_PORT:-26379}"

    # Check initial master
    log_info "Checking initial master..."

    local initial_master=$(redis-cli -p "$sentinel_port" SENTINEL get-master-addr-by-name mymaster 2>/dev/null | head -n1)

    if [[ -z "$initial_master" ]]; then
        log_error "Could not determine initial master"
        end_test "Redis Sentinel Failover" "FAIL"
        return 1
    fi

    log_info "Initial master: $initial_master"

    # Simulate master failure
    log_warning "Simulating master failure..."

    if [[ "$DRY_RUN" != "true" ]]; then
        redis-cli -h "$initial_master" ${DB_PASSWORD:+-a "$DB_PASSWORD"} DEBUG SLEEP "$TEST_DURATION" &

        sleep 5
    else
        log_info "[DRY RUN] Would simulate master failure"
    fi

    # Wait for sentinel failover
    log_info "Waiting for sentinel failover..."
    sleep 10

    # Check new master
    local new_master=$(redis-cli -p "$sentinel_port" SENTINEL get-master-addr-by-name mymaster 2>/dev/null | head -n1)

    if [[ "$new_master" == "$initial_master" ]]; then
        log_error "Failover did not occur"
        end_test "Redis Sentinel Failover" "FAIL"
        return 1
    fi

    log_success "New master: $new_master"

    # Test write operation
    log_info "Testing write operation..."

    if redis-cli -h "$new_master" ${DB_PASSWORD:+-a "$DB_PASSWORD"} SET ha_test_key "test_value" &>/dev/null; then
        local value=$(redis-cli -h "$new_master" ${DB_PASSWORD:+-a "$DB_PASSWORD"} GET ha_test_key)

        if [[ "$value" == "test_value" ]]; then
            log_success "Write operation successful"
            redis-cli -h "$new_master" ${DB_PASSWORD:+-a "$DB_PASSWORD"} DEL ha_test_key &>/dev/null
        else
            log_error "Read operation failed"
            end_test "Redis Sentinel Failover" "FAIL"
            return 1
        fi
    else
        log_error "Write operation failed"
        end_test "Redis Sentinel Failover" "FAIL"
        return 1
    fi

    end_test "Redis Sentinel Failover" "PASS"
    return 0
}

test_redis_cluster_partition() {
    start_test "Redis Cluster Network Partition"

    log_info "Redis cluster partition test requires network simulation"
    log_info "Install with: sudo apt install iperf3 netem"

    # Simulate network partition
    # This requires root access and network configuration

    log_info "Test skipped - requires network simulation tools"

    end_test "Redis Cluster Network Partition" "SKIP"
    return 0
}

# Network Tests
test_network_partition() {
    local target_host="$1"
    local duration="${2:-30}"

    log_warning "Simulating network partition to $target_host for ${duration}s..."

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would simulate network partition"
        return 0
    fi

    # Use tc to simulate network failure
    sudo tc qdisc add dev eth0 root netem loss 100%

    sleep "$duration"

    # Restore network
    sudo tc qdisc del dev eth0 root netem

    log_success "Network partition restored"
}

test_network_latency() {
    local target_host="$1"
    local latency="${2:-100ms}"

    log_info "Testing network with ${latency} latency..."

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would simulate network latency"
        return 0
    fi

    # Add latency
    sudo tc qdisc add dev eth0 root netem delay "$latency"

    # Run replication test
    sleep 10

    # Remove latency
    sudo tc qdisc del dev eth0 root netem

    log_success "Network latency test complete"
}

# Performance Tests
test_write_throughput() {
    local host="$1"
    local num_writes="${2:-1000}"

    log_info "Testing write throughput ($num_writes operations)..."

    local start_time=$(date +%s)

    for ((i = 1; i <= num_writes; i++)); do
        mysql -h "$host" -u "$DB_USER" -p"$DB_PASSWORD" \
            -e "INSERT INTO ha_test.throughput (value) VALUES ($i);" &>/dev/null
    done

    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    local ops_per_sec=$((num_writes / duration))

    log_success "Write throughput: $ops_per_sec ops/sec"
}

test_read_latency() {
    local host="$1"
    local num_reads="${2:-1000}"

    log_info "Testing read latency..."

    local total_latency=0

    for ((i = 1; i <= num_reads; i++)); do
        local start=$(date +%s%N)
        mysql -h "$host" -u "$DB_USER" -p"$DB_PASSWORD" \
            -e "SELECT * FROM ha_test.throughput LIMIT 1;" &>/dev/null
        local end=$(date +%s%N)

        local latency=$(( (end - start) / 1000000 ))
        total_latency=$((total_latency + latency))
    done

    local avg_latency=$((total_latency / num_reads))

    log_success "Average read latency: ${avg_latency}ms"
}

# Recovery Tests
test_backup_restore() {
    start_test "Backup and Restore"

    local backup_file="/tmp/ha_test_backup_$(date +%Y%m%d_%H%M%S).sql"

    # Take backup
    log_info "Taking backup..."

    if mysqldump -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASSWORD" \
        --all-databases --single-transaction > "$backup_file" 2>/dev/null; then

        log_success "Backup created: $backup_file"
    else
        log_error "Backup failed"
        end_test "Backup and Restore" "FAIL"
        return 1
    fi

    # Simulate data loss
    log_warning "Simulating data loss..."

    mysql -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASSWORD" \
        -e "DROP DATABASE IF EXISTS ha_test;"

    # Restore backup
    log_info "Restoring from backup..."

    if mysql -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASSWORD" < "$backup_file" 2>/dev/null; then
        log_success "Backup restored successfully"

        rm -f "$backup_file"
        end_test "Backup and Restore" "PASS"
        return 0
    else
        log_error "Restore failed"
        rm -f "$backup_file"
        end_test "Backup and Restore" "FAIL"
        return 1
    fi
}

# Report Generation
generate_report() {
    local report_file="$TEST_RESULTS_DIR/test_report_$(date +%Y%m%d_%H%M%S).html"

    mkdir -p "$TEST_RESULTS_DIR"

    cat > "$report_file" <<EOF
<!DOCTYPE html>
<html>
<head>
    <title>Database HA Test Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .pass { color: green; }
        .fail { color: red; }
        .skip { color: orange; }
        table { border-collapse: collapse; width: 100%; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #4CAF50; color: white; }
    </style>
</head>
<body>
    <h1>Database High Availability Test Report</h1>
    <p>Generated: $(date)</p>

    <h2>Summary</h2>
    <table>
        <tr>
            <th>Metric</th>
            <th>Value</th>
        </tr>
        <tr>
            <td>Total Tests</td>
            <td>$((TEST_PASSED + TEST_FAILED))</td>
        </tr>
        <tr>
            <td>Passed</td>
            <td class="pass">$TEST_PASSED</td>
        </tr>
        <tr>
            <td>Failed</td>
            <td class="fail">$TEST_FAILED</td>
        </tr>
        <tr>
            <td>Success Rate</td>
            <td>$(awk "BEGIN {printf \"%.1f%%\", ($TEST_PASSED / ($TEST_PASSED + $TEST_FAILED)) * 100}")</td>
        </tr>
    </table>

    <h2>Recommendations</h2>
    <ul>
EOF

    if [[ $TEST_FAILED -gt 0 ]]; then
        cat >> "$report_file" <<EOF
        <li>Review failed tests and fix configuration issues</li>
        <li>Consider increasing failover timeout thresholds</li>
        <li>Verify network connectivity between nodes</li>
        <li>Check replication lag metrics</li>
EOF
    else
        cat >> "$report_file" <<EOF
        <li>All tests passed - HA configuration is healthy</li>
        <li>Schedule regular test runs (weekly recommended)</li>
        <li>Continue monitoring replication lag</li>
EOF
    fi

    cat >> "$report_file" <<EOF
    </ul>
</body>
</html>
EOF

    log_success "Test report generated: $report_file"
}

# Main script logic
main() {
    local db=""
    local test=""

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --db=*)
                db="${1#*=}"
                shift
                ;;
            --test=*)
                test="${1#*=}"
                shift
                ;;
            --all)
                test="all"
                shift
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            -h|--help)
                echo "Database High Availability Test Script"
                echo ""
                echo "Usage:"
                echo "  $0 --db=mysql|postgres|redis --test=<test_type>"
                echo "  $0 --db=mysql --test=all"
                echo ""
                echo "Test Types:"
                echo "  failure      Test failover to replica"
                echo "  lag          Test replication lag"
                echo "  partition    Test network partition"
                echo "  recovery     Test backup/restore"
                echo "  all          Run all tests"
                echo ""
                echo "Environment Variables:"
                echo "  DB_HOST          Database host (default: localhost)"
                echo "  DB_PORT          Database port"
                echo "  DB_USER          Database user"
                echo "  DB_PASSWORD      Database password"
                echo "  SLAVE_HOSTS      Comma-separated list of slaves"
                echo "  TEST_DURATION    Test duration in seconds"
                echo "  RECOVERY_WAIT    Wait time for recovery"
                echo ""
                echo "Examples:"
                echo "  DB_PASSWORD=secret SLAVE_HOSTS=192.168.1.11,192.168.1.12 $0 --db=mysql --test=failure"
                echo "  $0 --db=redis --test=failure"
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                exit 1
                ;;
        esac
    done

    # Validate arguments
    if [[ -z "$db" ]]; then
        log_error "Database type required. Use --db=mysql|postgres|redis"
        exit 1
    fi

    if [[ -z "$test" ]]; then
        log_error "Test type required. Use --test=<test_type>"
        exit 1
    fi

    log_info "Starting database HA tests..."
    log_info "Database: $db"
    log_info "Test: $test"

    # Run tests based on database type
    case "$db" in
        mysql)
            case "$test" in
                failure)
                    test_mysql_failover
                    ;;
                lag)
                    test_mysql_replication_lag
                    ;;
                all)
                    test_mysql_replication_lag
                    test_mysql_failover
                    test_backup_restore
                    ;;
                *)
                    log_error "Unknown test type: $test"
                    exit 1
                    ;;
            esac
            ;;
        postgres)
            case "$test" in
                failure)
                    test_postgresql_failover
                    ;;
                *)
                    log_error "Test not implemented for PostgreSQL: $test"
                    exit 1
                    ;;
            esac
            ;;
        redis)
            case "$test" in
                failure)
                    test_redis_sentinel_failover
                    ;;
                partition)
                    test_redis_cluster_partition
                    ;;
                *)
                    log_error "Unknown test type: $test"
                    exit 1
                    ;;
            esac
            ;;
        *)
            log_error "Unknown database type: $db"
            exit 1
            ;;
    esac

    # Generate report
    generate_report

    # Exit with appropriate code
    if [[ $TEST_FAILED -gt 0 ]]; then
        exit 1
    else
        exit 0
    fi
}

main "$@"
