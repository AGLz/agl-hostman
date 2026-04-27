#!/bin/bash
################################################################################
# Queue Diagnostics
#
# Description: Check Laravel Horizon queue status
# Output: JSON report with findings and recommendations
# Usage: ./diag-queues.sh [--queue name]
################################################################################

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
QUEUE_FILTER="${1:-}"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
LARAVEL_PATH="${LARAVEL_PATH:-/mnt/overpower/apps/dev/agl/agl-hostman/src}"

# JSON output structure
json_output='{
  "scan_info": {
    "timestamp": "'"$TIMESTAMP"'",
    "scan_version": "1.0.0",
    "laravel_path": "'"$LARAVEL_PATH"'"
  },
  "checks": {}
}'

# Helper functions
add_finding() {
    local category="$1"
    local check="$2"
    local status="$3"
    local message="$4"
    local recommendation="${5:-}"

    json_output=$(echo "$json_output" | jq --arg cat "$category" --arg chk "$check" --arg st "$status" --arg msg "$message" --arg rec "$recommendation" '
        .checks[$cat] |= . + {
            $chk: {
                "status": $st,
                "message": $msg,
                "recommendation": $rec
            }
        }
    ')
}

# Change to Laravel directory
cd "$LARAVEL_PATH" 2>/dev/null || {
    echo "ERROR: Cannot change to Laravel directory: $LARAVEL_PATH" >&2
    exit 1
}

################################################################################
# Redis Connection Check
################################################################################
check_redis_connection() {
    echo "Checking Redis connection..."

    if ! command -v redis-cli &> /dev/null; then
        echo "  ERROR: redis-cli not found"
        add_finding "redis" "cli" "critical" "redis-cli not found" "Install Redis client tools"
        return 1
    fi

    if ! redis-cli ping &>/dev/null; then
        echo "  ERROR: Cannot connect to Redis"
        add_finding "redis" "connection" "critical" "Cannot connect to Redis" "Start Redis service"
        return 1
    fi

    echo "  Redis is responding"
    add_finding "redis" "connection" "pass" "Redis connection working" ""

    # Get Redis info
    local redis_version=$(redis-cli info server 2>/dev/null | grep "redis_version" | cut -d: -f2 | tr -d '\r' || echo "unknown")
    local connected_clients=$(redis-cli info clients 2>/dev/null | grep "connected_clients" | cut -d: -f2 | tr -d '\r' || echo "0")
    local used_memory=$(redis-cli info memory 2>/dev/null | grep "used_memory_human" | cut -d: -f2 | tr -d '\r' || echo "unknown")

    echo "  Version: $redis_version"
    echo "  Connected clients: $connected_clients"
    echo "  Memory: $used_memory"

    add_finding "redis" "version" "pass" "Redis version: $redis_version" ""
}

################################################################################
# Horizon Status Check
################################################################################
check_horizon_status() {
    echo "Checking Horizon status..."

    # Check if Horizon is running via systemctl
    if systemctl is-active --quiet horizon 2>/dev/null; then
        echo "  Horizon service is running"
        add_finding "horizon" "service" "pass" "Horizon service is running" ""
    else
        echo "  WARNING: Horizon service is not running"
        add_finding "horizon" "service" "critical" "Horizon service is not running" "Start Horizon: systemctl start horizon"
        return 1
    fi

    # Check Horizon status via Artisan
    if php artisan horizon:status &>/dev/null; then
        echo "  Horizon is active"
        add_finding "horizon" "status" "pass" "Horizon is active" ""
    else
        echo "  WARNING: Horizon is not active"
        add_finding "horizon" "status" "warning" "Horizon is not active" "Check Horizon logs"
    fi

    # Get Horizon stats if available
    local horizon_stats=$(php artisan horizon:stats 2>/dev/null || echo "")
    if [ -n "$horizon_stats" ]; then
        echo "$horizon_stats" | while read -r line; do
            echo "  $line"
        done
    fi
}

################################################################################
# Queue Size Check
################################################################################
check_queue_sizes() {
    echo "Checking queue sizes..."

    local queues=("default" "high" "low")
    local total_pending=0
    local queue_status="pass"
    local queue_message=""
    local queue_recommendation=""

    for queue in "${queues[@]}"; do
        if [ -n "$QUEUE_FILTER" ] && [ "$queue" != "$QUEUE_FILTER" ]; then
            continue
        fi

        local size=$(redis-cli -n 1 llen "queues:$queue" 2>/dev/null || echo "0")
        total_pending=$((total_pending + size))

        echo "  Queue $queue: $size pending"

        if [ "$size" -gt 1000 ]; then
            queue_status="warning"
            queue_message="Queue $queue has $size pending jobs"
            queue_recommendation="Check if workers are processing efficiently"
            add_finding "queues" "${queue}_size" "warning" "$size pending jobs in $queue" "$queue_recommendation"
        elif [ "$size" -gt 100 ]; then
            add_finding "queues" "${queue}_size" "pass" "$size pending jobs in $queue (monitoring)" ""
        else
            add_finding "queues" "${queue}_size" "pass" "$size pending jobs in $queue" ""
        fi
    done

    if [ "$queue_status" = "pass" ]; then
        queue_message="Queues healthy: $total_pending total pending jobs"
        add_finding "queues" "total_pending" "pass" "$queue_message" ""
    fi
}

################################################################################
# Failed Jobs Check
################################################################################
check_failed_jobs() {
    echo "Checking failed jobs..."

    # Check failed queue
    local failed_jobs=$(redis-cli -n 1 llen "queues:failed" 2>/dev/null || echo "0")

    echo "  Failed jobs in queue: $failed_jobs"

    if [ "$failed_jobs" -gt 100 ]; then
        add_finding "jobs" "failed" "critical" "$failed_jobs failed jobs" "Review and retry failed jobs urgently"
    elif [ "$failed_jobs" -gt 10 ]; then
        add_finding "jobs" "failed" "warning" "$failed_jobs failed jobs" "Review and retry failed jobs"
    elif [ "$failed_jobs" -gt 0 ]; then
        add_finding "jobs" "failed" "info" "$failed_jobs failed jobs" "Monitor failed jobs"
    else
        add_finding "jobs" "failed" "pass" "No failed jobs" ""
    fi

    # Check failed jobs database table if available
    if php artisan queue:failed &>/dev/null; then
        local db_failed=$(php artisan queue:failed 2>/dev/null | grep -c "ID:" || echo "0")
        echo "  Failed jobs in database: $db_failed"

        if [ "$db_failed" -gt 0 ]; then
            # Get recent failed job IDs
            local recent_failed=$(php artisan queue:failed 2>/dev/null | head -5 | grep -oP 'ID: \K\d+' || echo "")
            if [ -n "$recent_failed" ]; then
                echo "  Recent failed job IDs: $recent_failed"
            fi
        fi
    fi
}

################################################################################
# Worker Status Check
################################################################################
check_worker_status() {
    echo "Checking worker status..."

    # Get supervisor status
    if command -v supervisorctl &>/dev/null; then
        local workers=$(supervisorctl status | grep "horizon" || echo "")

        if [ -n "$workers" ]; then
            local running_workers=$(echo "$workers" | grep -c "RUNNING" || echo "0")
            local total_workers=$(echo "$workers" | wc -l)

            echo "  Workers: $running_workers/$total_workers running"

            if [ "$running_workers" -eq "$total_workers" ]; then
                add_finding "workers" "status" "pass" "All workers running ($running_workers/$total_workers)" ""
            else
                add_finding "workers" "status" "warning" "$((total_workers - running_workers)) worker(s) not running" "Check supervisor status"
            fi

            # Show worker details
            echo "$workers" | while read -r worker; do
                echo "    $worker"
            done
        else
            echo "  WARNING: No Horizon workers found in supervisor"
            add_finding "workers" "status" "warning" "No Horizon workers found" "Check Horizon supervisor configuration"
        fi
    else
        echo "  WARNING: supervisorctl not found"
        add_finding "workers" "supervisor" "info" "supervisorctl not available" ""
    fi
}

################################################################################
# Recent Job Analysis
################################################################################
check_recent_jobs() {
    echo "Checking recent job activity..."

    # Check for recent jobs in queues
    local queues=("default" "high" "low")

    for queue in "${queues[@]}"; do
        if [ -n "$QUEUE_FILTER" ] && [ "$queue" != "$QUEUE_FILTER" ]; then
            continue
        fi

        # Get recent jobs (first 10)
        local recent_jobs=$(redis-cli -n 1 lrange "queues:$queue" 0 9 2>/dev/null || echo "")

        if [ -n "$recent_jobs" ]; then
            local job_count=$(echo "$recent_jobs" | wc -l)
            echo "  Queue $queue: $job_count recent jobs"
        fi
    done

    # Check for reserved jobs
    local reserved_count=$(redis-cli -n 1 keys "queues:*:reserved" 2>/dev/null | wc -l || echo "0")
    echo "  Reserved job sets: $reserved_count"
}

################################################################################
# Memory and Performance Check
################################################################################
check_performance() {
    echo "Checking queue performance..."

    # Get Redis memory usage
    local redis_memory=$(redis-cli info memory 2>/dev/null | grep "used_memory_human" | cut -d: -f2 | tr -d '\r' || echo "unknown")
    local redis_peak=$(redis-cli info memory 2>/dev/null | grep "used_memory_peak_human" | cut -d: -f2 | tr -d '\r' || echo "unknown")

    echo "  Redis memory: $redis_memory"
    echo "  Redis peak memory: $redis_peak"

    # Check for slow operations
    local slowlog=$(redis-cli slowlog get 5 2>/dev/null || echo "")
    if [ -n "$slowlog" ] && [ "$slowlog" != "Empty slowlog" ]; then
        echo "  Recent slow operations detected"
        add_finding "performance" "slowlog" "warning" "Slow Redis operations detected" "Review slow operations"
    else
        add_finding "performance" "slowlog" "pass" "No slow operations" ""
    fi
}

################################################################################
# Main Execution
################################################################################
main() {
    echo "=== Queue Diagnostic Scan ==="
    echo "Timestamp: $TIMESTAMP"
    echo "Laravel path: $LARAVEL_PATH"
    if [ -n "$QUEUE_FILTER" ]; then
        echo "Queue filter: $QUEUE_FILTER"
    fi
    echo ""

    # Run all checks
    check_redis_connection || exit 1
    check_horizon_status
    check_queue_sizes
    check_failed_jobs
    check_worker_status
    check_recent_jobs
    check_performance

    # Output JSON report
    echo ""
    echo "=== JSON Report ==="
    echo "$json_output" | jq '.'

    # Check for critical issues
    local critical=$(echo "$json_output" | jq '[.checks[][] | select(.status == "critical")] | length')
    if [ "$critical" -gt 0 ]; then
        exit 1
    fi

    exit 0
}

main "$@"
