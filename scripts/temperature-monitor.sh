#!/bin/bash
# Temperature Monitoring Script for AGLSRV1
# Monitors critical temperatures and sends alerts
# Created: 2025-10-14 (Post-incident monitoring)

# Configuration
LOG_FILE="/var/log/temperature-monitor.log"
ALERT_FILE="/var/log/temperature-alerts.log"
METRICS_DIR="/var/log/temperature-metrics"

# Thresholds
CPU_WARN_THRESHOLD=80
CPU_CRIT_THRESHOLD=85
NETWORK_WARN_THRESHOLD=85
NETWORK_CRIT_THRESHOLD=90
NVME_WARN_THRESHOLD=70
NVME_CRIT_THRESHOLD=75

# Alert configuration
ENABLE_EMAIL_ALERTS=false
EMAIL_TO="admin@example.com"
ENABLE_WEBHOOK_ALERTS=false
WEBHOOK_URL="http://192.168.0.202:5678/webhook/temperature-alert"

# Create metrics directory
mkdir -p "$METRICS_DIR"

# Timestamp
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
METRIC_FILE="$METRICS_DIR/temp_$(date '+%Y%m%d').csv"

# Initialize CSV if needed
if [ ! -f "$METRIC_FILE" ]; then
    echo "timestamp,cpu0_package,cpu1_package,network1,network2,nvme_max,alert_level" > "$METRIC_FILE"
fi

# Function to send alert
send_alert() {
    local SEVERITY=$1
    local MESSAGE=$2

    # Log alert
    echo "[$TIMESTAMP] [$SEVERITY] $MESSAGE" >> "$ALERT_FILE"

    # Email alert
    if [ "$ENABLE_EMAIL_ALERTS" = true ]; then
        echo "$MESSAGE" | mail -s "[$SEVERITY] AGLSRV1 Temperature Alert" "$EMAIL_TO"
    fi

    # Webhook alert (n8n)
    if [ "$ENABLE_WEBHOOK_ALERTS" = true ]; then
        curl -X POST "$WEBHOOK_URL" \
            -H "Content-Type: application/json" \
            -d "{\"severity\":\"$SEVERITY\",\"message\":\"$MESSAGE\",\"timestamp\":\"$TIMESTAMP\"}" \
            --max-time 5 2>/dev/null
    fi
}

# Function to get temperature safely
get_temp() {
    local SENSOR=$1
    local FIELD=$2
    sensors "$SENSOR" 2>/dev/null | grep "$FIELD" | awk '{print $3}' | tr -d '+°C'
}

# Get temperatures
CPU0_PACKAGE=$(get_temp "coretemp-isa-0000" "Package id 0")
CPU1_PACKAGE=$(get_temp "coretemp-isa-0001" "Package id 1")
NETWORK1=$(get_temp "be2net-pci-0400" "temp1")
NETWORK2=$(get_temp "be2net-pci-0401" "temp1")

# Get max NVMe temperature
NVME_MAX=0
for nvme in $(sensors | grep "nvme-pci" | cut -d'-' -f1 | uniq); do
    TEMP=$(get_temp "$nvme" "Composite")
    if (( $(echo "$TEMP > $NVME_MAX" | bc -l) )); then
        NVME_MAX=$TEMP
    fi
done

# Default alert level
ALERT_LEVEL="OK"

# Check CPU temperatures
if (( $(echo "$CPU0_PACKAGE > $CPU_CRIT_THRESHOLD" | bc -l) )) || (( $(echo "$CPU1_PACKAGE > $CPU_CRIT_THRESHOLD" | bc -l) )); then
    ALERT_LEVEL="CRITICAL"
    send_alert "CRITICAL" "CPU temperature critical! CPU0: ${CPU0_PACKAGE}°C, CPU1: ${CPU1_PACKAGE}°C (threshold: ${CPU_CRIT_THRESHOLD}°C)"
elif (( $(echo "$CPU0_PACKAGE > $CPU_WARN_THRESHOLD" | bc -l) )) || (( $(echo "$CPU1_PACKAGE > $CPU_WARN_THRESHOLD" | bc -l) )); then
    ALERT_LEVEL="WARNING"
    send_alert "WARNING" "CPU temperature high! CPU0: ${CPU0_PACKAGE}°C, CPU1: ${CPU1_PACKAGE}°C (threshold: ${CPU_WARN_THRESHOLD}°C)"
fi

# Check Network temperatures (CRITICAL AREA)
if (( $(echo "$NETWORK1 > $NETWORK_CRIT_THRESHOLD" | bc -l) )) || (( $(echo "$NETWORK2 > $NETWORK_CRIT_THRESHOLD" | bc -l) )); then
    ALERT_LEVEL="CRITICAL"
    send_alert "CRITICAL" "Network card temperature CRITICAL! Network1: ${NETWORK1}°C, Network2: ${NETWORK2}°C (threshold: ${NETWORK_CRIT_THRESHOLD}°C)"
elif (( $(echo "$NETWORK1 > $NETWORK_WARN_THRESHOLD" | bc -l) )) || (( $(echo "$NETWORK2 > $NETWORK_WARN_THRESHOLD" | bc -l) )); then
    if [ "$ALERT_LEVEL" != "CRITICAL" ]; then
        ALERT_LEVEL="WARNING"
    fi
    send_alert "WARNING" "Network card temperature high! Network1: ${NETWORK1}°C, Network2: ${NETWORK2}°C (threshold: ${NETWORK_WARN_THRESHOLD}°C)"
fi

# Check NVMe temperatures
if (( $(echo "$NVME_MAX > $NVME_CRIT_THRESHOLD" | bc -l) )); then
    if [ "$ALERT_LEVEL" = "OK" ]; then
        ALERT_LEVEL="WARNING"
    fi
    send_alert "WARNING" "NVMe temperature high! Max: ${NVME_MAX}°C (threshold: ${NVME_CRIT_THRESHOLD}°C)"
fi

# Log metrics
echo "$TIMESTAMP,$CPU0_PACKAGE,$CPU1_PACKAGE,$NETWORK1,$NETWORK2,$NVME_MAX,$ALERT_LEVEL" >> "$METRIC_FILE"

# Log to main log
echo "[$TIMESTAMP] CPU0: ${CPU0_PACKAGE}°C | CPU1: ${CPU1_PACKAGE}°C | Net1: ${NETWORK1}°C | Net2: ${NETWORK2}°C | NVMe: ${NVME_MAX}°C | Status: $ALERT_LEVEL" >> "$LOG_FILE"

# Console output (for manual runs)
if [ -t 1 ]; then
    echo "======================================"
    echo " Temperature Monitoring - $TIMESTAMP"
    echo "======================================"
    echo "CPU Package 0:  ${CPU0_PACKAGE}°C"
    echo "CPU Package 1:  ${CPU1_PACKAGE}°C"
    echo "Network Card 1: ${NETWORK1}°C"
    echo "Network Card 2: ${NETWORK2}°C"
    echo "NVMe Max:       ${NVME_MAX}°C"
    echo "Status:         $ALERT_LEVEL"
    echo "======================================"
fi

# Return exit code based on alert level
case "$ALERT_LEVEL" in
    "CRITICAL")
        exit 2
        ;;
    "WARNING")
        exit 1
        ;;
    *)
        exit 0
        ;;
esac
