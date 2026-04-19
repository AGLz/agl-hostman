#!/bin/bash
# Solution 5: QMP Timeout Detection and Recovery Script
# Advanced QMP timeout detection and automated recovery for VM100

# Configuration
VM_ID="100"
PROXMOX_HOST="100.98.108.66"
LOG_FILE="/var/log/vm100-qmp-recovery.log"
ALERT_EMAIL="admin@yourdomain.com"
QMP_TIMEOUT=30
MAX_RECOVERY_ATTEMPTS=3
RECOVERY_DELAY=60

# Recovery status tracking
RECOVERY_STATE_FILE="/var/run/vm100-recovery-state"
METRICS_FILE="/var/lib/prometheus/node-exporter/vm100-qmp.prom"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging function with severity levels
log_message() {
    local severity=$1
    local message=$2
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    echo "[$timestamp] [$severity] $message" >> "$LOG_FILE"

    case $severity in
        "ERROR"|"CRITICAL")
            echo -e "${RED}[$timestamp] [$severity] $message${NC}" >&2
            ;;
        "WARNING")
            echo -e "${YELLOW}[$timestamp] [$severity] $message${NC}" >&2
            ;;
        "INFO"|"SUCCESS")
            echo -e "${GREEN}[$timestamp] [$severity] $message${NC}"
            ;;
        *)
            echo "[$timestamp] [$severity] $message"
            ;;
    esac
}

# Prometheus metrics logging
log_metric() {
    local metric_name=$1
    local metric_value=$2
    local timestamp=$(date +%s)

    echo "vm100_qmp_${metric_name} ${metric_value} ${timestamp}000" >> "$METRICS_FILE"
}

# Initialize metrics file
init_metrics() {
    cat > "$METRICS_FILE" << EOF
# VM100 QMP Recovery Metrics
# TYPE vm100_qmp_responsive gauge
# TYPE vm100_qmp_recovery_attempts counter
# TYPE vm100_qmp_recovery_success counter
# TYPE vm100_qmp_last_timeout_duration gauge
EOF
}

# Check if VM exists and get basic info
verify_vm() {
    if ! qm config "$VM_ID" >/dev/null 2>&1; then
        log_message "ERROR" "VM$VM_ID does not exist or is not accessible"
        return 1
    fi

    local vm_status=$(qm status "$VM_ID" | grep -o 'status: [a-z]*' | cut -d' ' -f2)
    log_message "INFO" "VM$VM_ID current status: $vm_status"

    if [ "$vm_status" != "running" ]; then
        log_message "WARNING" "VM$VM_ID is not running (status: $vm_status)"
        return 2
    fi

    return 0
}

# Enhanced QMP connectivity test with multiple methods
test_qmp_connectivity() {
    local method=$1
    local timeout=${2:-$QMP_TIMEOUT}
    local start_time=$(date +%s)

    case $method in
        "info_status")
            timeout "$timeout" qm monitor "$VM_ID" --command "info status" >/dev/null 2>&1
            ;;
        "info_version")
            timeout "$timeout" qm monitor "$VM_ID" --command "info version" >/dev/null 2>&1
            ;;
        "query_cpus")
            timeout "$timeout" qm monitor "$VM_ID" --command "info cpus" >/dev/null 2>&1
            ;;
        "ping")
            timeout "$timeout" qm monitor "$VM_ID" --command "info balloon" >/dev/null 2>&1
            ;;
        *)
            log_message "ERROR" "Unknown QMP test method: $method"
            return 1
            ;;
    esac

    local result=$?
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))

    log_metric "last_${method}_duration" "$duration"

    if [ $result -eq 0 ]; then
        log_message "INFO" "QMP test '$method' successful (${duration}s)"
        return 0
    elif [ $result -eq 124 ]; then
        log_message "WARNING" "QMP test '$method' timed out after ${timeout}s"
        log_metric "last_timeout_duration" "$timeout"
        return 124
    else
        log_message "ERROR" "QMP test '$method' failed with exit code $result"
        return $result
    fi
}

# Comprehensive QMP health assessment
assess_qmp_health() {
    local overall_health=0
    local tests=("info_status" "info_version" "query_cpus" "ping")
    local success_count=0
    local timeout_count=0
    local failure_count=0

    log_message "INFO" "Starting comprehensive QMP health assessment"

    for test in "${tests[@]}"; do
        if test_qmp_connectivity "$test" 15; then
            ((success_count++))
        elif [ $? -eq 124 ]; then
            ((timeout_count++))
        else
            ((failure_count++))
        fi
        sleep 2  # Brief pause between tests
    done

    log_message "INFO" "QMP Assessment Results: Success=$success_count, Timeout=$timeout_count, Failed=$failure_count"

    # Calculate health score (0-100)
    local total_tests=${#tests[@]}
    local health_score=$(( (success_count * 100) / total_tests ))

    log_metric "health_score" "$health_score"
    log_metric "test_success_count" "$success_count"
    log_metric "test_timeout_count" "$timeout_count"
    log_metric "test_failure_count" "$failure_count"

    # Determine overall health status
    if [ $success_count -eq $total_tests ]; then
        log_message "SUCCESS" "QMP interface is healthy (100% success rate)"
        log_metric "responsive" 1
        return 0
    elif [ $timeout_count -gt 0 ] || [ $success_count -lt $((total_tests / 2)) ]; then
        log_message "ERROR" "QMP interface is unresponsive (Health: ${health_score}%)"
        log_metric "responsive" 0
        return 1
    else
        log_message "WARNING" "QMP interface is degraded (Health: ${health_score}%)"
        log_metric "responsive" 0.5
        return 2
    fi
}

# Get recovery state information
get_recovery_state() {
    if [ -f "$RECOVERY_STATE_FILE" ]; then
        source "$RECOVERY_STATE_FILE"
    else
        RECOVERY_ATTEMPTS=0
        LAST_RECOVERY_TIME=0
        RECOVERY_IN_PROGRESS=false
    fi
}

# Update recovery state
update_recovery_state() {
    cat > "$RECOVERY_STATE_FILE" << EOF
RECOVERY_ATTEMPTS=$RECOVERY_ATTEMPTS
LAST_RECOVERY_TIME=$(date +%s)
RECOVERY_IN_PROGRESS=$RECOVERY_IN_PROGRESS
EOF
}

# Send alert notifications
send_alert() {
    local alert_type=$1
    local message=$2
    local severity=${3:-"WARNING"}

    # Log the alert
    log_message "$severity" "ALERT[$alert_type]: $message"

    # Send email if configured
    if command -v mail >/dev/null 2>&1 && [ -n "$ALERT_EMAIL" ]; then
        echo "$message" | mail -s "Proxmox VM100 Alert: $alert_type" "$ALERT_EMAIL"
    fi

    # Send to syslog
    logger -t "VM100-QMP-Recovery" -p daemon.error "$alert_type: $message"

    # Optional webhook notification
    if [ -n "$WEBHOOK_URL" ]; then
        curl -s -X POST "$WEBHOOK_URL" \
             -H "Content-Type: application/json" \
             -d "{\"alert\":\"$alert_type\",\"message\":\"$message\",\"vm_id\":\"$VM_ID\",\"severity\":\"$severity\"}" || true
    fi
}

# Level 1: Soft recovery attempts
soft_recovery() {
    log_message "INFO" "Attempting soft QMP recovery for VM$VM_ID"

    # Method 1: QMP system_reset command
    log_message "INFO" "Trying QMP system_reset command"
    if timeout 30 qm monitor "$VM_ID" --command "system_reset" >/dev/null 2>&1; then
        log_message "INFO" "QMP system_reset command sent successfully"
        sleep 30
        if assess_qmp_health; then
            log_message "SUCCESS" "Soft recovery successful via system_reset"
            return 0
        fi
    fi

    # Method 2: QMP cont command (in case VM is paused)
    log_message "INFO" "Trying QMP cont command"
    if timeout 30 qm monitor "$VM_ID" --command "cont" >/dev/null 2>&1; then
        log_message "INFO" "QMP cont command sent successfully"
        sleep 15
        if assess_qmp_health; then
            log_message "SUCCESS" "Soft recovery successful via cont command"
            return 0
        fi
    fi

    # Method 3: Guest agent ping
    log_message "INFO" "Trying QEMU guest agent communication"
    if timeout 20 qm agent "$VM_ID" ping >/dev/null 2>&1; then
        log_message "INFO" "Guest agent responsive, trying guest shutdown/restart"
        if timeout 60 qm agent "$VM_ID" shutdown; then
            sleep 30
            qm start "$VM_ID"
            sleep 60
            if assess_qmp_health; then
                log_message "SUCCESS" "Soft recovery successful via guest agent restart"
                return 0
            fi
        fi
    fi

    log_message "WARNING" "All soft recovery methods failed"
    return 1
}

# Level 2: Medium recovery attempts
medium_recovery() {
    log_message "INFO" "Attempting medium QMP recovery for VM$VM_ID"

    # Method 1: VM stop and start
    log_message "INFO" "Stopping VM$VM_ID forcefully"
    if qm stop "$VM_ID" --timeout 60; then
        log_message "INFO" "VM$VM_ID stopped successfully"
        sleep 10

        log_message "INFO" "Starting VM$VM_ID"
        if qm start "$VM_ID"; then
            log_message "INFO" "VM$VM_ID started successfully"
            sleep 60  # Allow time for boot

            if assess_qmp_health; then
                log_message "SUCCESS" "Medium recovery successful via stop/start"
                return 0
            fi
        fi
    else
        log_message "WARNING" "Failed to stop VM$VM_ID gracefully"
    fi

    # Method 2: Force stop and start
    log_message "INFO" "Force stopping VM$VM_ID"
    if qm stop "$VM_ID" --skiplock --timeout 30; then
        log_message "INFO" "VM$VM_ID force stopped"
        sleep 15

        if qm start "$VM_ID"; then
            log_message "INFO" "VM$VM_ID restarted after force stop"
            sleep 60

            if assess_qmp_health; then
                log_message "SUCCESS" "Medium recovery successful via force stop/start"
                return 0
            fi
        fi
    fi

    log_message "WARNING" "All medium recovery methods failed"
    return 1
}

# Level 3: Hard recovery attempts
hard_recovery() {
    log_message "INFO" "Attempting hard QMP recovery for VM$VM_ID"

    # Method 1: Kill QEMU process and restart
    local qemu_pid=$(pgrep -f "qemu.*$VM_ID")
    if [ -n "$qemu_pid" ]; then
        log_message "WARNING" "Killing QEMU process $qemu_pid for VM$VM_ID"
        kill -TERM "$qemu_pid"
        sleep 10

        # Force kill if still running
        if kill -0 "$qemu_pid" 2>/dev/null; then
            log_message "WARNING" "Force killing QEMU process $qemu_pid"
            kill -KILL "$qemu_pid"
            sleep 5
        fi

        # Start VM again
        log_message "INFO" "Restarting VM$VM_ID after process kill"
        if qm start "$VM_ID"; then
            sleep 60
            if assess_qmp_health; then
                log_message "SUCCESS" "Hard recovery successful via process kill/restart"
                return 0
            fi
        fi
    fi

    # Method 2: Reset VM configuration and restart
    log_message "INFO" "Attempting VM configuration reset"
    if qm stop "$VM_ID" --skiplock >/dev/null 2>&1; then
        # Backup current config
        cp "/etc/pve/qemu-server/$VM_ID.conf" "/etc/pve/qemu-server/$VM_ID.conf.recovery.$(date +%s)"

        # Reset any problematic settings
        sed -i '/^lock:/d' "/etc/pve/qemu-server/$VM_ID.conf"

        if qm start "$VM_ID"; then
            sleep 60
            if assess_qmp_health; then
                log_message "SUCCESS" "Hard recovery successful via config reset"
                return 0
            fi
        fi
    fi

    log_message "ERROR" "All hard recovery methods failed"
    return 1
}

# Main recovery orchestration
perform_recovery() {
    get_recovery_state

    # Check if recovery is already in progress
    if [ "$RECOVERY_IN_PROGRESS" = "true" ]; then
        local current_time=$(date +%s)
        local time_since_last=$((current_time - LAST_RECOVERY_TIME))

        if [ $time_since_last -lt 300 ]; then  # 5 minutes
            log_message "INFO" "Recovery already in progress, skipping"
            return 0
        else
            log_message "WARNING" "Recovery seems stuck, resetting state"
            RECOVERY_IN_PROGRESS=false
        fi
    fi

    # Check recovery attempt limits
    if [ $RECOVERY_ATTEMPTS -ge $MAX_RECOVERY_ATTEMPTS ]; then
        local current_time=$(date +%s)
        local time_since_last=$((current_time - LAST_RECOVERY_TIME))

        if [ $time_since_last -lt 3600 ]; then  # 1 hour
            log_message "ERROR" "Maximum recovery attempts ($MAX_RECOVERY_ATTEMPTS) reached within 1 hour"
            send_alert "Recovery Limit Reached" "VM$VM_ID has reached maximum recovery attempts. Manual intervention required." "CRITICAL"
            return 1
        else
            log_message "INFO" "Resetting recovery attempt counter after 1 hour cooldown"
            RECOVERY_ATTEMPTS=0
        fi
    fi

    # Start recovery process
    RECOVERY_IN_PROGRESS=true
    ((RECOVERY_ATTEMPTS++))
    update_recovery_state

    log_message "INFO" "Starting QMP recovery attempt $RECOVERY_ATTEMPTS for VM$VM_ID"
    log_metric "recovery_attempts" "$RECOVERY_ATTEMPTS"

    send_alert "Recovery Started" "Starting QMP recovery attempt $RECOVERY_ATTEMPTS for VM$VM_ID" "WARNING"

    # Try recovery levels progressively
    local recovery_success=false

    # Level 1: Soft recovery
    if soft_recovery; then
        recovery_success=true
        log_message "SUCCESS" "Recovery completed at soft level"
        send_alert "Recovery Successful" "VM$VM_ID QMP interface recovered using soft methods" "INFO"

    # Level 2: Medium recovery
    elif medium_recovery; then
        recovery_success=true
        log_message "SUCCESS" "Recovery completed at medium level"
        send_alert "Recovery Successful" "VM$VM_ID QMP interface recovered using medium methods" "WARNING"

    # Level 3: Hard recovery
    elif hard_recovery; then
        recovery_success=true
        log_message "SUCCESS" "Recovery completed at hard level"
        send_alert "Recovery Successful" "VM$VM_ID QMP interface recovered using hard methods" "CRITICAL"

    else
        log_message "ERROR" "All recovery attempts failed"
        send_alert "Recovery Failed" "All recovery attempts failed for VM$VM_ID. Manual intervention required." "CRITICAL"
    fi

    # Update recovery state
    RECOVERY_IN_PROGRESS=false
    if [ "$recovery_success" = "true" ]; then
        log_metric "recovery_success" 1
        RECOVERY_ATTEMPTS=0  # Reset on successful recovery
    else
        log_metric "recovery_success" 0
    fi

    update_recovery_state

    # Wait before next potential recovery
    if [ "$recovery_success" = "true" ]; then
        log_message "INFO" "Recovery successful, waiting ${RECOVERY_DELAY}s before next monitoring cycle"
        sleep $RECOVERY_DELAY
    fi

    return $([ "$recovery_success" = "true" ] && echo 0 || echo 1)
}

# Continuous monitoring mode
continuous_monitor() {
    log_message "INFO" "Starting continuous QMP monitoring for VM$VM_ID"
    init_metrics

    while true; do
        if verify_vm; then
            if ! assess_qmp_health; then
                log_message "WARNING" "QMP health check failed, initiating recovery"
                perform_recovery
            else
                log_message "INFO" "QMP health check passed"
            fi
        else
            log_message "WARNING" "VM verification failed, skipping health check"
        fi

        sleep 60  # Monitor every minute
    done
}

# Generate diagnostic report
generate_diagnostic_report() {
    local report_file="/tmp/vm100-qmp-diagnostic-$(date +%Y%m%d-%H%M%S).txt"

    cat > "$report_file" << EOF
VM100 QMP Diagnostic Report
Generated: $(date)
=========================

VM Configuration:
$(qm config $VM_ID 2>/dev/null || echo "Failed to get VM config")

VM Status:
$(qm status $VM_ID 2>/dev/null || echo "Failed to get VM status")

QEMU Process Information:
$(ps aux | grep -E "qemu.*$VM_ID" | grep -v grep || echo "No QEMU process found")

System Resources:
Memory: $(free -h | grep Mem)
Disk Space: $(df -h | grep -E "(vz|local)")
Load Average: $(uptime)

Recent Log Entries:
$(tail -50 "$LOG_FILE" 2>/dev/null || echo "No log file found")

Recovery State:
$(cat "$RECOVERY_STATE_FILE" 2>/dev/null || echo "No recovery state file")

QMP Socket Information:
$(ls -la /var/run/qemu-server/$VM_ID.* 2>/dev/null || echo "No QMP sockets found")
EOF

    echo "Diagnostic report generated: $report_file"
    log_message "INFO" "Diagnostic report generated: $report_file"
}

# Main script execution
main() {
    case "${1:-monitor}" in
        "monitor"|"check")
            verify_vm && assess_qmp_health
            ;;
        "recover")
            verify_vm && perform_recovery
            ;;
        "continuous")
            continuous_monitor
            ;;
        "test")
            echo "Testing QMP connectivity methods:"
            for method in info_status info_version query_cpus ping; do
                echo -n "Testing $method: "
                if test_qmp_connectivity "$method" 10; then
                    echo "OK"
                else
                    echo "FAILED"
                fi
            done
            ;;
        "diagnostic"|"diag")
            generate_diagnostic_report
            ;;
        "reset-state")
            rm -f "$RECOVERY_STATE_FILE"
            log_message "INFO" "Recovery state reset"
            ;;
        "status")
            get_recovery_state
            echo "Recovery Attempts: $RECOVERY_ATTEMPTS"
            echo "Last Recovery: $(date -d @$LAST_RECOVERY_TIME 2>/dev/null || echo 'Never')"
            echo "Recovery In Progress: $RECOVERY_IN_PROGRESS"
            ;;
        *)
            echo "Usage: $0 {monitor|recover|continuous|test|diagnostic|reset-state|status}"
            echo ""
            echo "Commands:"
            echo "  monitor     - Perform single QMP health check"
            echo "  recover     - Perform recovery if needed"
            echo "  continuous  - Run continuous monitoring"
            echo "  test        - Test all QMP connectivity methods"
            echo "  diagnostic  - Generate diagnostic report"
            echo "  reset-state - Reset recovery state"
            echo "  status      - Show recovery status"
            exit 1
            ;;
    esac
}

# Script initialization
if [ ! -d "$(dirname "$LOG_FILE")" ]; then
    mkdir -p "$(dirname "$LOG_FILE")"
fi

if [ ! -d "$(dirname "$METRICS_FILE")" ]; then
    mkdir -p "$(dirname "$METRICS_FILE")"
fi

# Execute main function
main "$@"