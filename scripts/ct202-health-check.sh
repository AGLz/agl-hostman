#!/bin/bash
# CT202 (n8n) Health Check and Auto-Recovery Script
# Monitors CT202 container and n8n service health
# Implements automatic recovery on failure
# Created: 2025-10-14 (Post-incident automation)

# Configuration
LOG_FILE="/var/log/ct202-health.log"
RECOVERY_LOG="/var/log/ct202-recovery.log"
STATE_FILE="/var/run/ct202-health.state"

CT_ID="202"
CT_IP="192.168.0.202"
N8N_PORT="5678"

# Recovery limits
MAX_RESTART_ATTEMPTS=3
RESTART_COOLDOWN=300  # 5 minutes between restart attempts

# Alert configuration
ENABLE_WEBHOOK_ALERTS=false
WEBHOOK_URL="http://192.168.0.202:5678/webhook/ct202-health"

# Timestamp
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

# Initialize state file
if [ ! -f "$STATE_FILE" ]; then
    echo "last_restart=0" > "$STATE_FILE"
    echo "restart_count=0" >> "$STATE_FILE"
fi

# Load state
source "$STATE_FILE"

# Function to send alert
send_alert() {
    local SEVERITY=$1
    local MESSAGE=$2
    local ACTION=$3

    echo "[$TIMESTAMP] [$SEVERITY] $MESSAGE | Action: $ACTION" >> "$LOG_FILE"

    if [ "$ENABLE_WEBHOOK_ALERTS" = true ]; then
        curl -X POST "$WEBHOOK_URL" \
            -H "Content-Type: application/json" \
            -d "{\"severity\":\"$SEVERITY\",\"message\":\"$MESSAGE\",\"action\":\"$ACTION\",\"timestamp\":\"$TIMESTAMP\"}" \
            --max-time 5 2>/dev/null
    fi
}

# Function to update state
update_state() {
    local KEY=$1
    local VALUE=$2

    if grep -q "^${KEY}=" "$STATE_FILE"; then
        sed -i "s/^${KEY}=.*/${KEY}=${VALUE}/" "$STATE_FILE"
    else
        echo "${KEY}=${VALUE}" >> "$STATE_FILE"
    fi
}

# Function to reset restart counter
reset_restart_counter() {
    update_state "restart_count" "0"
    update_state "last_restart" "0"
}

# Check 1: Container Status
check_container_status() {
    if pct status "$CT_ID" 2>/dev/null | grep -q "running"; then
        return 0
    else
        return 1
    fi
}

# Check 2: Docker Service
check_docker_service() {
    if pct exec "$CT_ID" -- systemctl is-active docker 2>/dev/null | grep -q "active"; then
        return 0
    else
        return 1
    fi
}

# Check 3: N8N Container
check_n8n_container() {
    if pct exec "$CT_ID" -- docker ps 2>/dev/null | grep -q "n8n"; then
        return 0
    else
        return 1
    fi
}

# Check 4: N8N API Health
check_n8n_api() {
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "http://${CT_IP}:${N8N_PORT}/healthz" --max-time 10 2>/dev/null)

    if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "301" ] || [ "$HTTP_CODE" = "302" ]; then
        return 0
    else
        return 1
    fi
}

# Recovery function: Restart container
recover_container() {
    local CURRENT_TIME=$(date +%s)
    local TIME_SINCE_LAST_RESTART=$((CURRENT_TIME - last_restart))

    # Check cooldown period
    if [ "$TIME_SINCE_LAST_RESTART" -lt "$RESTART_COOLDOWN" ]; then
        send_alert "WARNING" "Container restart needed but in cooldown period (${TIME_SINCE_LAST_RESTART}s < ${RESTART_COOLDOWN}s)" "DELAYED"
        return 1
    fi

    # Check restart limit
    if [ "$restart_count" -ge "$MAX_RESTART_ATTEMPTS" ]; then
        send_alert "CRITICAL" "Maximum restart attempts ($MAX_RESTART_ATTEMPTS) reached. Manual intervention required." "NONE"
        return 1
    fi

    # Attempt restart
    send_alert "WARNING" "Attempting container restart (attempt $((restart_count + 1))/$MAX_RESTART_ATTEMPTS)" "RESTARTING"

    echo "[$TIMESTAMP] Starting container restart procedure..." >> "$RECOVERY_LOG"

    # Stop container
    pct stop "$CT_ID" >> "$RECOVERY_LOG" 2>&1
    sleep 5

    # Start container
    pct start "$CT_ID" >> "$RECOVERY_LOG" 2>&1
    sleep 20

    # Update state
    update_state "last_restart" "$CURRENT_TIME"
    update_state "restart_count" "$((restart_count + 1))"

    # Verify recovery
    if check_container_status && check_n8n_api; then
        send_alert "INFO" "Container restart successful" "RECOVERED"
        echo "[$TIMESTAMP] Container restart successful" >> "$RECOVERY_LOG"

        # Reset counter after successful recovery
        reset_restart_counter
        return 0
    else
        send_alert "ERROR" "Container restart failed verification" "FAILED"
        echo "[$TIMESTAMP] Container restart failed verification" >> "$RECOVERY_LOG"
        return 1
    fi
}

# Recovery function: Restart N8N service
recover_n8n_service() {
    send_alert "WARNING" "Attempting N8N service restart" "RESTARTING_N8N"

    echo "[$TIMESTAMP] Starting N8N service restart..." >> "$RECOVERY_LOG"

    # Restart n8n container
    pct exec "$CT_ID" -- docker compose restart n8n >> "$RECOVERY_LOG" 2>&1 || \
    pct exec "$CT_ID" -- bash -c "cd /root && docker compose restart n8n" >> "$RECOVERY_LOG" 2>&1

    sleep 15

    # Verify
    if check_n8n_api; then
        send_alert "INFO" "N8N service restart successful" "RECOVERED"
        echo "[$TIMESTAMP] N8N service restart successful" >> "$RECOVERY_LOG"
        return 0
    else
        send_alert "ERROR" "N8N service restart failed" "FAILED"
        echo "[$TIMESTAMP] N8N service restart failed" >> "$RECOVERY_LOG"
        return 1
    fi
}

# Main health check logic
HEALTH_STATUS="HEALTHY"
FAILED_CHECKS=()

# Execute checks
if ! check_container_status; then
    HEALTH_STATUS="CRITICAL"
    FAILED_CHECKS+=("container_stopped")
fi

if check_container_status; then
    if ! check_docker_service; then
        HEALTH_STATUS="CRITICAL"
        FAILED_CHECKS+=("docker_service")
    fi

    if ! check_n8n_container; then
        HEALTH_STATUS="WARNING"
        FAILED_CHECKS+=("n8n_container")
    fi

    if ! check_n8n_api; then
        HEALTH_STATUS="WARNING"
        FAILED_CHECKS+=("n8n_api")
    fi
fi

# Handle failures
if [ "$HEALTH_STATUS" != "HEALTHY" ]; then
    FAILED_LIST=$(IFS=, ; echo "${FAILED_CHECKS[*]}")

    case "$HEALTH_STATUS" in
        "CRITICAL")
            send_alert "CRITICAL" "CT202 health check CRITICAL: ${FAILED_LIST}" "RECOVERY_NEEDED"

            # Attempt container recovery
            if recover_container; then
                echo "[$TIMESTAMP] Recovery successful via container restart" >> "$LOG_FILE"
            else
                echo "[$TIMESTAMP] Recovery failed - manual intervention required" >> "$LOG_FILE"
            fi
            ;;
        "WARNING")
            send_alert "WARNING" "CT202 health check WARNING: ${FAILED_LIST}" "INVESTIGATING"

            # Try N8N service recovery first
            if [[ " ${FAILED_CHECKS[*]} " =~ " n8n_api " ]] || [[ " ${FAILED_CHECKS[*]} " =~ " n8n_container " ]]; then
                if recover_n8n_service; then
                    echo "[$TIMESTAMP] Recovery successful via N8N service restart" >> "$LOG_FILE"
                else
                    # Escalate to container restart
                    if recover_container; then
                        echo "[$TIMESTAMP] Recovery successful via container restart (escalated)" >> "$LOG_FILE"
                    else
                        echo "[$TIMESTAMP] Recovery failed - manual intervention required" >> "$LOG_FILE"
                    fi
                fi
            fi
            ;;
    esac
else
    # All checks passed
    echo "[$TIMESTAMP] All health checks passed" >> "$LOG_FILE"

    # Reset restart counter on successful health check
    if [ "$restart_count" -gt 0 ]; then
        echo "[$TIMESTAMP] Resetting restart counter after sustained health" >> "$LOG_FILE"
        reset_restart_counter
    fi
fi

# Console output (for manual runs)
if [ -t 1 ]; then
    echo "======================================"
    echo " CT202 Health Check - $TIMESTAMP"
    echo "======================================"
    echo "Container Status:  $(check_container_status && echo 'OK' || echo 'FAILED')"
    echo "Docker Service:    $(check_docker_service && echo 'OK' || echo 'FAILED')"
    echo "N8N Container:     $(check_n8n_container && echo 'OK' || echo 'FAILED')"
    echo "N8N API:           $(check_n8n_api && echo 'OK' || echo 'FAILED')"
    echo "Overall Status:    $HEALTH_STATUS"
    echo "Restart Count:     $restart_count / $MAX_RESTART_ATTEMPTS"
    echo "======================================"
fi

# Return appropriate exit code
case "$HEALTH_STATUS" in
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
