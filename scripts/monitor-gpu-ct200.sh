#!/bin/bash
# GPU Monitoring Script for CT200 (ollama)
# Monitors temperature, memory usage, and alerts on high temps

set -euo pipefail

# Configuration
CT_ID=200
HOST="192.168.0.245"
TEMP_WARN=85
TEMP_CRIT=90
LOG_FILE="/var/log/ct200-gpu-monitor.log"
ALERT_EMAIL="${ALERT_EMAIL:-root@localhost}"

# Colors
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Function to get GPU metrics
get_gpu_metrics() {
    ssh root@${HOST} "pct exec ${CT_ID} -- nvidia-smi --query-gpu=temperature.gpu,utilization.gpu,utilization.memory,memory.used,memory.total,power.draw,fan.speed --format=csv,noheader,nounits" 2>/dev/null
}

# Function to log message
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a ${LOG_FILE}
}

# Function to send alert
send_alert() {
    local subject="$1"
    local message="$2"
    echo "${message}" | mail -s "${subject}" ${ALERT_EMAIL} 2>/dev/null || true
    log_message "ALERT: ${subject} - ${message}"
}

# Main monitoring loop
monitor_once() {
    local metrics=$(get_gpu_metrics)

    if [[ -z "${metrics}" ]]; then
        echo -e "${RED}ERROR: Failed to get GPU metrics${NC}"
        return 1
    fi

    IFS=',' read -r temp gpu_util mem_util mem_used mem_total power fan <<< "${metrics}"

    # Remove any whitespace
    temp=$(echo ${temp} | xargs)
    gpu_util=$(echo ${gpu_util} | xargs)
    mem_util=$(echo ${mem_util} | xargs)
    mem_used=$(echo ${mem_used} | xargs)
    mem_total=$(echo ${mem_total} | xargs)
    power=$(echo ${power} | xargs)
    fan=$(echo ${fan} | xargs)

    # Determine temperature status
    local temp_status="${GREEN}OK${NC}"
    if (( $(echo "${temp} >= ${TEMP_CRIT}" | bc -l) )); then
        temp_status="${RED}CRITICAL${NC}"
        send_alert "GPU Temperature Critical" "GPU temperature at ${temp}°C (Critical: >=${TEMP_CRIT}°C)"
    elif (( $(echo "${temp} >= ${TEMP_WARN}" | bc -l) )); then
        temp_status="${YELLOW}WARNING${NC}"
        send_alert "GPU Temperature Warning" "GPU temperature at ${temp}°C (Warning: >=${TEMP_WARN}°C)"
    fi

    # Display metrics
    echo -e "\n╔══════════════════════════════════════════════════════════╗"
    echo -e "║  CT200 GPU Monitor - $(date '+%Y-%m-%d %H:%M:%S')        ║"
    echo -e "╚══════════════════════════════════════════════════════════╝"
    echo ""
    echo -e "Temperature:    ${temp}°C [${temp_status}]"
    echo -e "GPU Usage:      ${gpu_util}%"
    echo -e "Memory Usage:   ${mem_util}% (${mem_used} / ${mem_total} MiB)"
    echo -e "Power Draw:     ${power} W"
    echo -e "Fan Speed:      ${fan}%"
    echo ""

    # Log to file
    log_message "Temp:${temp}°C GPU:${gpu_util}% MemUse:${mem_used}MB Fan:${fan}%"
}

# Watch mode
watch_mode() {
    local interval=${1:-5}
    echo "Starting GPU monitoring (interval: ${interval}s, Ctrl+C to stop)"
    echo "Logging to: ${LOG_FILE}"
    echo ""

    while true; do
        clear
        monitor_once
        sleep ${interval}
    done
}

# Usage
case "${1:-once}" in
    once)
        monitor_once
        ;;
    watch)
        watch_mode ${2:-5}
        ;;
    continuous)
        echo "Starting continuous monitoring (logging only)..."
        while true; do
            monitor_once > /dev/null
            sleep 60
        done
        ;;
    *)
        echo "Usage: $0 {once|watch [interval]|continuous}"
        echo ""
        echo "  once        - Show metrics once and exit"
        echo "  watch [N]   - Continuously display metrics (refresh every N seconds, default: 5)"
        echo "  continuous  - Run in background, log only (1 min interval)"
        exit 1
        ;;
esac
