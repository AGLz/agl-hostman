#!/bin/bash
#
# ZFS Scrub Manager - Automated scrub scheduling and monitoring
# Ensures data integrity through regular scrub operations
#

set -euo pipefail

CONFIG_FILE="/etc/zfs-protection/scrub-config.conf"
LOG_FILE="/var/log/zfs-protection/scrub.log"
LOCK_FILE="/var/run/zfs-scrub.lock"

# Load configuration
source "$CONFIG_FILE" 2>/dev/null || {
    echo "❌ Configuration file not found: $CONFIG_FILE"
    exit 1
}

# Logging function
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [$$] $1" | tee -a "$LOG_FILE"
}

# Lock management
acquire_lock() {
    if [[ -f "$LOCK_FILE" ]]; then
        local pid
        pid=$(cat "$LOCK_FILE" 2>/dev/null || echo "")
        if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
            log "❌ Another scrub process is running (PID: $pid)"
            exit 1
        else
            log "🧹 Removing stale lock file"
            rm -f "$LOCK_FILE"
        fi
    fi
    echo $$ > "$LOCK_FILE"
    trap 'rm -f "$LOCK_FILE"' EXIT
}

# Check if pool needs scrubbing
needs_scrub() {
    local pool="$1"
    local max_age_days="${SCRUB_MAX_AGE_DAYS:-7}"
    local status

    status=$(zpool status "$pool")

    # Check if scrub is already in progress
    if echo "$status" | grep -q "scrub in progress"; then
        log "🔄 Pool $pool: Scrub already in progress"
        return 1
    fi

    # Check if scrub was never performed
    if echo "$status" | grep -q "none requested"; then
        log "⚠️ Pool $pool: No scrub has been performed"
        return 0
    fi

    # Check last scrub date
    if echo "$status" | grep -q "scrub completed"; then
        local scrub_date_str
        scrub_date_str=$(echo "$status" | grep "scrub" | head -1 | awk '{for(i=4;i<=8;i++) printf "%s ", $i}' | sed 's/ $//')

        # Convert scrub date to epoch
        local scrub_epoch
        scrub_epoch=$(date -d "$scrub_date_str" +%s 2>/dev/null || echo "0")

        if [[ "$scrub_epoch" -eq 0 ]]; then
            log "⚠️ Pool $pool: Cannot parse last scrub date, forcing scrub"
            return 0
        fi

        local current_epoch
        current_epoch=$(date +%s)
        local age_days=$(( (current_epoch - scrub_epoch) / 86400 ))

        if [[ "$age_days" -gt "$max_age_days" ]]; then
            log "⚠️ Pool $pool: Last scrub was $age_days days ago (max: $max_age_days)"
            return 0
        else
            log "✅ Pool $pool: Last scrub was $age_days days ago (within limit)"
            return 1
        fi
    fi

    # Default to needing scrub if status is unclear
    log "⚠️ Pool $pool: Unclear scrub status, forcing scrub"
    return 0
}

# Start scrub on pool
start_scrub() {
    local pool="$1"

    log "🔍 Starting scrub on pool: $pool"

    if zpool scrub "$pool"; then
        log "✅ Scrub started successfully on pool: $pool"
        return 0
    else
        log "❌ Failed to start scrub on pool: $pool"
        return 1
    fi
}

# Monitor scrub progress
monitor_scrub_progress() {
    local pool="$1"
    local max_wait_hours="${SCRUB_MAX_WAIT_HOURS:-24}"
    local check_interval="${SCRUB_CHECK_INTERVAL:-300}"  # 5 minutes
    local start_time
    start_time=$(date +%s)

    log "📊 Monitoring scrub progress for pool: $pool"

    while true; do
        local status
        status=$(zpool status "$pool")

        if echo "$status" | grep -q "scrub completed"; then
            local scrub_info
            scrub_info=$(echo "$status" | grep "scrub" | head -1)
            log "✅ Scrub completed on pool $pool: $scrub_info"

            # Check for errors found during scrub
            if echo "$scrub_info" | grep -q "with 0 errors"; then
                log "✅ No errors found during scrub of pool: $pool"
            else
                local error_info
                error_info=$(echo "$scrub_info" | grep -o "[0-9]* errors" || echo "unknown errors")
                log "⚠️ Scrub found issues on pool $pool: $error_info"

                # Send alert for scrub errors
                if [[ -x "/opt/zfs-protection/scripts/send-alert.sh" ]]; then
                    "/opt/zfs-protection/scripts/send-alert.sh" "WARNING" "$pool" "Scrub completed with errors: $error_info"
                fi
            fi
            return 0

        elif echo "$status" | grep -q "scrub in progress"; then
            # Extract progress information
            local progress_line
            progress_line=$(echo "$status" | grep "scanned\|scrub")

            local scanned issued
            scanned=$(echo "$progress_line" | grep -o "scanned [^,]*" | awk '{print $2}' || echo "unknown")
            issued=$(echo "$progress_line" | grep -o "issued [^,]*" | awk '{print $2}' || echo "unknown")

            log "📈 Pool $pool scrub progress - Scanned: $scanned, Issued: $issued"

        elif echo "$status" | grep -q "scrub canceled"; then
            log "⚠️ Scrub was canceled on pool: $pool"
            return 1

        else
            log "❓ Unknown scrub status for pool: $pool"
        fi

        # Check timeout
        local current_time
        current_time=$(date +%s)
        local elapsed_hours=$(( (current_time - start_time) / 3600 ))

        if [[ "$elapsed_hours" -gt "$max_wait_hours" ]]; then
            log "⏰ Scrub monitoring timeout for pool $pool after ${elapsed_hours} hours"
            return 1
        fi

        sleep "$check_interval"
    done
}

# Get pool performance impact during scrub
check_scrub_impact() {
    local pool="$1"

    # Check pool I/O stats during scrub
    local read_ops write_ops bandwidth
    read_ops=$(zpool iostat "$pool" 1 2 | tail -1 | awk '{print $4}')
    write_ops=$(zpool iostat "$pool" 1 2 | tail -1 | awk '{print $5}')
    bandwidth=$(zpool iostat "$pool" 1 2 | tail -1 | awk '{print $6 + $7}')

    log "📊 Pool $pool I/O during scrub - Read ops: $read_ops, Write ops: $write_ops, Bandwidth: ${bandwidth}K"

    # Check if scrub is causing high load
    local load_avg
    load_avg=$(uptime | awk '{print $10}' | tr -d ',')

    if (( $(echo "$load_avg > ${SCRUB_LOAD_THRESHOLD:-2.0}" | bc -l) )); then
        log "⚠️ High system load during scrub: $load_avg"

        # Optionally pause scrub if system load is too high
        if [[ "${SCRUB_PAUSE_ON_HIGH_LOAD:-false}" == "true" ]]; then
            log "⏸️ Pausing scrub due to high system load"
            zpool scrub -p "$pool"

            # Wait for load to decrease
            while (( $(echo "$(uptime | awk '{print $10}' | tr -d ',') > ${SCRUB_LOAD_THRESHOLD:-2.0}" | bc -l) )); do
                log "⏳ Waiting for system load to decrease..."
                sleep 300  # Wait 5 minutes
            done

            log "▶️ Resuming scrub as system load decreased"
            zpool scrub "$pool"
        fi
    fi
}

# Generate scrub report
generate_scrub_report() {
    local pool="$1"
    local start_time="$2"
    local end_time="$3"
    local success="$4"

    local duration=$((end_time - start_time))
    local duration_hours=$((duration / 3600))
    local duration_mins=$(((duration % 3600) / 60))

    local report_file="/var/log/zfs-protection/scrub-report-${pool}-$(date +%Y%m%d_%H%M%S).txt"

    {
        echo "🔍 ZFS Scrub Report - $(date)"
        echo "=================================="
        echo "Pool: $pool"
        echo "Start Time: $(date -d "@$start_time")"
        echo "End Time: $(date -d "@$end_time")"
        echo "Duration: ${duration_hours}h ${duration_mins}m"
        echo "Status: $([[ "$success" == "true" ]] && echo "SUCCESS" || echo "FAILED")"
        echo ""
        echo "Pool Status After Scrub:"
        zpool status "$pool"
        echo ""
        echo "Pool I/O Statistics:"
        zpool iostat "$pool"
        echo ""
        echo "Error Summary:"
        zpool status "$pool" | grep -A10 "errors:" || echo "No error section found"
    } > "$report_file"

    log "📄 Scrub report generated: $report_file"
}

# Scrub single pool
scrub_pool() {
    local pool="$1"
    local force="${2:-false}"

    log "🎯 Evaluating scrub for pool: $pool"

    # Check if scrub is needed (unless forced)
    if [[ "$force" != "true" ]] && ! needs_scrub "$pool"; then
        log "✅ Pool $pool does not need scrubbing at this time"
        return 0
    fi

    local start_time
    start_time=$(date +%s)

    # Start the scrub
    if ! start_scrub "$pool"; then
        return 1
    fi

    # Monitor scrub progress
    local success=true
    if [[ "${SCRUB_MONITOR_PROGRESS:-true}" == "true" ]]; then
        if ! monitor_scrub_progress "$pool"; then
            success=false
        fi

        # Check performance impact periodically
        if [[ "${SCRUB_CHECK_IMPACT:-true}" == "true" ]]; then
            check_scrub_impact "$pool" &
        fi
    fi

    local end_time
    end_time=$(date +%s)

    # Generate report
    generate_scrub_report "$pool" "$start_time" "$end_time" "$success"

    if [[ "$success" == "true" ]]; then
        log "✅ Scrub completed successfully for pool: $pool"
        return 0
    else
        log "❌ Scrub had issues for pool: $pool"
        return 1
    fi
}

# Check scrub schedule
check_schedule() {
    local pool="$1"
    local schedule="${SCRUB_SCHEDULE:-weekly}"
    local current_day current_hour
    current_day=$(date +%u)  # 1=Monday, 7=Sunday
    current_hour=$(date +%H)

    case "$schedule" in
        "daily")
            # Daily at configured hour
            local target_hour="${SCRUB_HOUR:-02}"
            if [[ "$current_hour" == "$target_hour" ]]; then
                return 0
            fi
            ;;
        "weekly")
            # Weekly on configured day and hour
            local target_day="${SCRUB_DAY:-7}"  # Sunday by default
            local target_hour="${SCRUB_HOUR:-02}"
            if [[ "$current_day" == "$target_day" ]] && [[ "$current_hour" == "$target_hour" ]]; then
                return 0
            fi
            ;;
        "monthly")
            # Monthly on first Sunday
            local target_hour="${SCRUB_HOUR:-02}"
            local day_of_month=$(date +%d)
            if [[ "$current_day" == "7" ]] && [[ "$day_of_month" -le 7 ]] && [[ "$current_hour" == "$target_hour" ]]; then
                return 0
            fi
            ;;
        *)
            log "⚠️ Unknown scrub schedule: $schedule"
            return 1
            ;;
    esac

    return 1
}

# Main scrub function
main() {
    local operation="${1:-auto}"
    local specific_pool="${2:-}"
    local force="${3:-false}"

    case "$operation" in
        "auto")
            acquire_lock
            log "🚀 Starting automatic scrub evaluation"

            local pools_to_check
            if [[ -n "$specific_pool" ]]; then
                pools_to_check="$specific_pool"
            else
                pools_to_check=$(zpool list -H -o name)
            fi

            local total_success=true
            for pool in $pools_to_check; do
                if [[ -n "$specific_pool" ]] || check_schedule "$pool"; then
                    log "📅 Pool $pool is scheduled for scrub"
                    if ! scrub_pool "$pool" "$force"; then
                        total_success=false
                    fi
                else
                    log "⏭️ Pool $pool not scheduled for scrub at this time"
                fi
            done

            if [[ "$total_success" == "true" ]]; then
                log "✅ All scheduled scrubs completed successfully"
                exit 0
            else
                log "⚠️ Some scrubs failed"
                exit 1
            fi
            ;;

        "force")
            acquire_lock
            log "🔧 Starting forced scrub"

            if [[ -z "$specific_pool" ]]; then
                log "❌ Pool name required for forced scrub"
                exit 1
            fi

            if scrub_pool "$specific_pool" "true"; then
                log "✅ Forced scrub completed successfully"
                exit 0
            else
                log "❌ Forced scrub failed"
                exit 1
            fi
            ;;

        "status")
            log "📊 Checking scrub status for all pools"
            for pool in $(zpool list -H -o name); do
                echo "Pool: $pool"
                zpool status "$pool" | grep -A5 "scrub\|scan"
                echo ""
            done
            ;;

        "cancel")
            if [[ -z "$specific_pool" ]]; then
                log "❌ Pool name required for cancel operation"
                exit 1
            fi

            log "🛑 Canceling scrub for pool: $specific_pool"
            if zpool scrub -s "$specific_pool"; then
                log "✅ Scrub canceled successfully for pool: $specific_pool"
            else
                log "❌ Failed to cancel scrub for pool: $specific_pool"
                exit 1
            fi
            ;;

        *)
            echo "Usage: $0 [auto|force|status|cancel] [pool_name] [force]"
            echo ""
            echo "Operations:"
            echo "  auto     Run automatic scrub based on schedule (default)"
            echo "  force    Force scrub on specified pool regardless of schedule"
            echo "  status   Show scrub status for all pools"
            echo "  cancel   Cancel running scrub on specified pool"
            echo ""
            echo "Examples:"
            echo "  $0 auto                # Run scheduled scrubs"
            echo "  $0 force tank          # Force scrub on 'tank' pool"
            echo "  $0 status              # Show scrub status"
            echo "  $0 cancel tank         # Cancel scrub on 'tank' pool"
            echo "  $0 auto tank true      # Force scrub on 'tank' even if not scheduled"
            exit 1
            ;;
    esac
}