#!/bin/bash
#
# ZFS Health Monitor - Continuous monitoring for ZFS pools
# Detects degradation, errors, and potential corruption early
#

set -euo pipefail

CONFIG_FILE="/etc/zfs-protection/monitor-config.conf"
LOG_FILE="/var/log/zfs-protection/health-monitor.log"
ALERT_SCRIPT="/opt/zfs-protection/scripts/send-alert.sh"
METRICS_FILE="/var/log/zfs-protection/metrics.json"

# Load configuration
source "$CONFIG_FILE" 2>/dev/null || {
    echo "❌ Configuration file not found: $CONFIG_FILE"
    exit 1
}

# Logging function
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [$$] $1" | tee -a "$LOG_FILE"
}

# Alert function
send_alert() {
    local severity="$1"
    local message="$2"
    local pool="${3:-unknown}"

    log "🚨 ALERT [$severity] Pool: $pool - $message"

    if [[ -x "$ALERT_SCRIPT" ]]; then
        "$ALERT_SCRIPT" "$severity" "$pool" "$message"
    fi

    # Write to metrics for Grafana
    {
        echo "{"
        echo "  \"timestamp\": $(date +%s),"
        echo "  \"severity\": \"$severity\","
        echo "  \"pool\": \"$pool\","
        echo "  \"message\": \"$message\","
        echo "  \"hostname\": \"$(hostname)\""
        echo "},"
    } >> "$METRICS_FILE"
}

# Check ZFS pool health
check_pool_health() {
    local pool="$1"
    local health status

    health=$(zpool get -H -o value health "$pool")
    status=$(zpool status "$pool")

    case "$health" in
        "ONLINE")
            log "✅ Pool $pool: HEALTHY"
            ;;
        "DEGRADED")
            send_alert "CRITICAL" "Pool is DEGRADED - reduced redundancy" "$pool"
            ;;
        "FAULTED")
            send_alert "CRITICAL" "Pool is FAULTED - data unavailable" "$pool"
            ;;
        "OFFLINE")
            send_alert "CRITICAL" "Pool is OFFLINE" "$pool"
            ;;
        "UNAVAIL")
            send_alert "CRITICAL" "Pool is UNAVAILABLE" "$pool"
            ;;
        *)
            send_alert "WARNING" "Unknown pool health status: $health" "$pool"
            ;;
    esac

    # Check for errors
    local read_errors write_errors cksum_errors
    read_errors=$(echo "$status" | awk '/errors:/ {getline; print $3}' | head -1)
    write_errors=$(echo "$status" | awk '/errors:/ {getline; print $4}' | head -1)
    cksum_errors=$(echo "$status" | awk '/errors:/ {getline; print $5}' | head -1)

    if [[ "$read_errors" != "0" ]] || [[ "$write_errors" != "0" ]] || [[ "$cksum_errors" != "0" ]]; then
        send_alert "WARNING" "Errors detected - Read: $read_errors, Write: $write_errors, Checksum: $cksum_errors" "$pool"
    fi

    # Check scrub status
    if echo "$status" | grep -q "scrub in progress"; then
        log "🔄 Pool $pool: Scrub in progress"
    elif echo "$status" | grep -q "scrub completed"; then
        local scrub_date
        scrub_date=$(echo "$status" | grep "scrub repaired" | awk '{print $4, $5, $6, $7, $8}')
        log "✅ Pool $pool: Last scrub completed on $scrub_date"
    elif echo "$status" | grep -q "none requested"; then
        log "⚠️ Pool $pool: No scrub has been performed"
    fi
}

# Check individual drive health via SMART
check_drive_health() {
    local device="$1"
    local smart_status temp reallocated_sectors

    if ! smartctl -a "$device" >/dev/null 2>&1; then
        log "⚠️ Cannot read SMART data for $device"
        return
    fi

    smart_status=$(smartctl -H "$device" | grep "SMART overall-health" | awk '{print $6}')
    temp=$(smartctl -A "$device" | grep Temperature_Celsius | awk '{print $10}')
    reallocated_sectors=$(smartctl -A "$device" | grep Reallocated_Sector_Ct | awk '{print $10}')

    if [[ "$smart_status" != "PASSED" ]]; then
        send_alert "CRITICAL" "SMART health check FAILED for $device" "system"
    fi

    if [[ -n "$temp" ]] && [[ "$temp" -gt "${TEMP_WARNING_THRESHOLD:-50}" ]]; then
        send_alert "WARNING" "High temperature on $device: ${temp}°C" "system"
    fi

    if [[ -n "$reallocated_sectors" ]] && [[ "$reallocated_sectors" -gt "${REALLOCATED_THRESHOLD:-5}" ]]; then
        send_alert "WARNING" "High reallocated sectors on $device: $reallocated_sectors" "system"
    fi
}

# Check ZFS memory usage
check_zfs_memory() {
    local arc_size arc_max arc_hit_ratio

    arc_size=$(awk '/^size/ {print $3}' /proc/spl/kstat/zfs/arcstats)
    arc_max=$(awk '/^c_max/ {print $3}' /proc/spl/kstat/zfs/arcstats)

    # Calculate hit ratio
    local arc_hits arc_misses
    arc_hits=$(awk '/^hits/ {print $3}' /proc/spl/kstat/zfs/arcstats)
    arc_misses=$(awk '/^misses/ {print $3}' /proc/spl/kstat/zfs/arcstats)

    if [[ "$arc_hits" -gt 0 ]] && [[ "$arc_misses" -gt 0 ]]; then
        arc_hit_ratio=$(echo "scale=2; $arc_hits * 100 / ($arc_hits + $arc_misses)" | bc)

        if (( $(echo "$arc_hit_ratio < ${ARC_HIT_RATIO_THRESHOLD:-85}" | bc -l) )); then
            send_alert "WARNING" "Low ARC hit ratio: ${arc_hit_ratio}%" "system"
        fi
    fi

    # Check if ARC is getting too close to max
    local arc_usage_percent
    arc_usage_percent=$(echo "scale=2; $arc_size * 100 / $arc_max" | bc)

    if (( $(echo "$arc_usage_percent > ${ARC_USAGE_THRESHOLD:-90}" | bc -l) )); then
        send_alert "WARNING" "High ARC memory usage: ${arc_usage_percent}%" "system"
    fi
}

# Check pool capacity
check_pool_capacity() {
    local pool="$1"
    local capacity

    capacity=$(zpool get -H -o value capacity "$pool" | tr -d '%')

    if [[ "$capacity" -gt "${CAPACITY_CRITICAL_THRESHOLD:-90}" ]]; then
        send_alert "CRITICAL" "Pool capacity critical: ${capacity}%" "$pool"
    elif [[ "$capacity" -gt "${CAPACITY_WARNING_THRESHOLD:-80}" ]]; then
        send_alert "WARNING" "Pool capacity high: ${capacity}%" "$pool"
    fi
}

# Check for recent resilver operations
check_resilver_status() {
    local pool="$1"
    local status

    status=$(zpool status "$pool")

    if echo "$status" | grep -q "resilver in progress"; then
        log "🔄 Pool $pool: Resilver in progress"
    elif echo "$status" | grep -q "resilvered"; then
        local resilver_info
        resilver_info=$(echo "$status" | grep "resilvered" | head -1)
        log "✅ Pool $pool: Recent resilver completed - $resilver_info"
    fi
}

# Generate health metrics for monitoring
generate_metrics() {
    local metrics_temp="/tmp/zfs-metrics-$$"

    {
        echo "{"
        echo "  \"timestamp\": $(date +%s),"
        echo "  \"hostname\": \"$(hostname)\","
        echo "  \"pools\": {"

        local first_pool=true
        for pool in $(zpool list -H -o name); do
            [[ "$first_pool" == "true" ]] && first_pool=false || echo ","

            local health capacity
            health=$(zpool get -H -o value health "$pool")
            capacity=$(zpool get -H -o value capacity "$pool" | tr -d '%')

            echo "    \"$pool\": {"
            echo "      \"health\": \"$health\","
            echo "      \"capacity\": $capacity"
            echo -n "    }"
        done

        echo ""
        echo "  },"

        # ARC stats
        local arc_size arc_max arc_hits arc_misses
        arc_size=$(awk '/^size/ {print $3}' /proc/spl/kstat/zfs/arcstats)
        arc_max=$(awk '/^c_max/ {print $3}' /proc/spl/kstat/zfs/arcstats)
        arc_hits=$(awk '/^hits/ {print $3}' /proc/spl/kstat/zfs/arcstats)
        arc_misses=$(awk '/^misses/ {print $3}' /proc/spl/kstat/zfs/arcstats)

        echo "  \"arc\": {"
        echo "    \"size\": $arc_size,"
        echo "    \"max\": $arc_max,"
        echo "    \"hits\": $arc_hits,"
        echo "    \"misses\": $arc_misses"
        echo "  }"
        echo "}"
    } > "$metrics_temp"

    mv "$metrics_temp" "$METRICS_FILE"
}

# Main monitoring loop
main() {
    local check_interval="${CHECK_INTERVAL:-300}"  # 5 minutes default

    log "🚀 ZFS Health Monitor started (PID: $$)"
    log "📊 Check interval: ${check_interval} seconds"
    log "📧 Alerts enabled: ${ALERTS_ENABLED:-true}"

    while true; do
        log "🔍 Starting health check cycle..."

        # Check all pools
        for pool in $(zpool list -H -o name 2>/dev/null || echo ""); do
            if [[ -n "$pool" ]]; then
                check_pool_health "$pool"
                check_pool_capacity "$pool"
                check_resilver_status "$pool"
            fi
        done

        # Check ZFS memory usage
        check_zfs_memory

        # Check drive health for all drives in pools
        for device in $(lsblk -nd -o NAME | grep -E '^(sd|nvme)'); do
            check_drive_health "/dev/$device"
        done

        # Generate metrics
        generate_metrics

        log "✅ Health check cycle completed"

        sleep "$check_interval"
    done
}

# Handle signals
trap 'log "🛑 ZFS Health Monitor stopping..."; exit 0' SIGTERM SIGINT

# Run health check if called with --check flag
if [[ "${1:-}" == "--check" ]]; then
    echo "🔍 Running one-time health check..."
    for pool in $(zpool list -H -o name 2>/dev/null || echo ""); do
        if [[ -n "$pool" ]]; then
            check_pool_health "$pool"
            check_pool_capacity "$pool"
        fi
    done
    check_zfs_memory
    generate_metrics
    echo "✅ Health check completed"
    exit 0
fi

# Start monitoring
main