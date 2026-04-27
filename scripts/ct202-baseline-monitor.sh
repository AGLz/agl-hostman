#!/bin/bash
# CT202 Baseline Performance Monitoring Script
# Collects periodic metrics for baseline establishment
# Usage: Run via cron every 15 minutes

CTID=202
LOGFILE="/root/host-admin/claudedocs/ct202_baseline_$(date +%Y%m%d).log"

# Create log header if file doesn't exist
if [ ! -f "$LOGFILE" ]; then
    echo "timestamp,load_avg_1m,load_avg_5m,load_avg_15m,mem_usage_pct,disk_usage_pct,service_status" > "$LOGFILE"
fi

# Collect metrics
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

# Load averages (handle multiline output)
LOAD_AVG=$(pct exec $CTID -- uptime | awk -F'load average:' '{print $2}' | sed 's/^ //' | tr -d '\n' | tr ',' ' ')
LOAD_1M=$(echo "$LOAD_AVG" | awk '{print $1}')
LOAD_5M=$(echo "$LOAD_AVG" | awk '{print $2}')
LOAD_15M=$(echo "$LOAD_AVG" | awk '{print $3}')

# Memory usage percentage
MEM_USAGE=$(pct exec $CTID -- free -m 2>/dev/null | grep Mem | awk '{printf "%.1f", ($3/$2)*100}')

# Disk usage percentage
DISK_USAGE=$(pct exec $CTID -- df -h / 2>/dev/null | tail -1 | awk '{print $5}' | tr -d '%')

# Service status
SERVICE_STATUS=$(pct exec $CTID -- systemctl is-active n8n 2>/dev/null || echo "unknown")

# Append to log
echo "$TIMESTAMP,$LOAD_1M,$LOAD_5M,$LOAD_15M,$MEM_USAGE,$DISK_USAGE,$SERVICE_STATUS" >> "$LOGFILE"

# Optional: Rotate logs older than 30 days
find /root/host-admin/claudedocs/ -name "ct202_baseline_*.log" -mtime +30 -delete 2>/dev/null
