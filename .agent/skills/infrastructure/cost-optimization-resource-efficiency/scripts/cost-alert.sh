#!/bin/bash
# cost-alert.sh - Send cost alerts when thresholds are exceeded
# Part of the cost-optimization-resource-efficiency skill

set -euo pipefail

# Configuration
ALERT_TYPE="${1:-check}"           # check, budget, spike, anomaly, report
THRESHOLD_TYPE="${2:-warning}"     # warning, critical
OUTPUT_FILE="${3:-}"               # For report type
LOG_FILE="/var/log/cost-alert.log"

# Alert thresholds
MONTHLY_BUDGET_WARNING="${MONTHLY_BUDGET_WARNING:-100}"
MONTHLY_BUDGET_CRITICAL="${MONTHLY_BUDGET_CRITICAL:-150}"
DAILY_SPIKE_THRESHOLD="${DAILY_SPIKE_THRESHOLD:-50}"    # % over baseline
CONTAINER_COST_THRESHOLD="${CONTAINER_COST_THRESHOLD:-20}"  # $/month
LOW_UTILIZATION_THRESHOLD="${LOW_UTILIZATION_THRESHOLD:-20}"  # %

# Notification settings
NOTIFICATION_METHOD="${NOTIFICATION_METHOD:-log}"  # log, email, webhook, slack
EMAIL_TO="${EMAIL_TO:-admin@example.com}"
WEBHOOK_URL="${WEBHOOK_URL:-}"
SLACK_WEBHOOK="${SLACK_WEBHOOK:-}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Logging
log() {
    local msg="[$(date +'%Y-%m-%d %H:%M:%S')] $1"
    echo -e "${BLUE}$msg${NC}"
    echo "$msg" >> "$LOG_FILE"
}

error() {
    local msg="[ERROR] $1"
    echo -e "${RED}$msg${NC}" >&2
    echo "$msg" >> "$LOG_FILE"
    exit 1
}

warn() {
    local msg="[WARN] $1"
    echo -e "${YELLOW}$msg${NC}" >&2
    echo "$msg" >> "$LOG_FILE"
}

# Calculate current monthly cost
calculate_monthly_cost() {
    local total_cost=0

    for vmid in $(pct list 2>/dev/null | awk 'NR>1 {print $1}'); do
        local config="/etc/pve/lxc/${vmid}.conf"
        [[ ! -f "$config" ]] && continue

        local cores=$(grep -oP '^cores:\s*\K\d+' "$config" || echo "2")
        local memory_mb=$(grep -oP '^memory:\s*\K\d+' "$config" || echo "4096")

        local cost=$(echo "scale=2; $cores * 7.30 + ($memory_mb / 1024) * 3.65" | bc)
        total_cost=$(echo "scale=2; $total_cost + $cost" | bc)
    done

    echo "$total_cost"
}

# Check budget alerts
check_budget_alerts() {
    log "Checking budget alerts"

    local current_cost=$(calculate_monthly_cost)
    local warning_threshold=$MONTHLY_BUDGET_WARNING
    local critical_threshold=$MONTHLY_BUDGET_CRITICAL

    local budget_status="ok"
    local severity=0
    local message=""

    # Check critical threshold
    if [[ $(echo "$current_cost > $critical_threshold" | bc) -eq 1 ]]; then
        budget_status="critical"
        severity=90
        message="CRITICAL: Monthly cost \$${current_cost} exceeds critical budget \$${critical_threshold}"
    # Check warning threshold
    elif [[ $(echo "$current_cost > $warning_threshold" | bc) -eq 1 ]]; then
        budget_status="warning"
        severity=70
        message="WARNING: Monthly cost \$${current_cost} exceeds warning budget \$${warning_threshold}"
    fi

    if [[ $severity -gt 0 ]]; then
        send_alert "budget_exceeded" "$severity" "$message" "{\"current_cost\":$current_cost,\"threshold\":$warning_threshold}"
    fi

    echo "$budget_status:\$${current_cost}"
}

# Get baseline cost (average of last 7 days)
get_baseline_cost() {
    local baseline_file="/tmp/cost-baseline.txt"
    local current_date=$(date +%s)
    local week_ago=$((current_date - 604800))

    if [[ ! -f "$baseline_file" ]]; then
        # Create baseline file with current cost
        calculate_monthly_cost > "$baseline_file"
        echo "100"  # Return 100% baseline for first run
        return
    fi

    # Read historical costs and calculate average
    local total=0
    local count=0

    while IFS= read -r line; do
        local timestamp=$(echo "$line" | cut -d',' -f1)
        local cost=$(echo "$line" | cut -d',' -f2)

        if [[ $timestamp -ge $week_ago ]]; then
            total=$(echo "scale=2; $total + $cost" | bc)
            count=$((count + 1))
        fi
    done < "$baseline_file"

    if [[ $count -gt 0 ]]; then
        echo "scale=0; $total / $count" | bc
    else
        echo "100"
    fi

    # Append current cost
    echo "${current_date},$(calculate_monthly_cost)" >> "$baseline_file"
}

# Check for daily cost spikes
check_daily_spike() {
    log "Checking for daily cost spikes"

    local current_cost=$(calculate_monthly_cost)
    local baseline=$(get_baseline_cost)
    local baseline_value=$(echo "$baseline" | cut -d'%' -f1)

    # Calculate percentage change
    local change=$(echo "scale=0; (($current_cost - $baseline_value) * 100) / $baseline_value" | bc)

    if [[ $change -gt $DAILY_SPIKE_THRESHOLD ]]; then
        local message="Cost spike detected: ${change}% increase over baseline (current: \$${current_cost}, baseline: \$${baseline_value})"
        send_alert "daily_spike" 75 "$message" "{\"current_cost\":$current_cost,\"baseline\":$baseline_value,\"change_percent\":$change}"
    fi

    echo "${change}%:\$${current_cost}"
}

# Check container cost threshold
check_container_costs() {
    log "Checking individual container costs"

    local threshold=$CONTAINER_COST_THRESHOLD
    local over_threshold=()

    for vmid in $(pct list 2>/dev/null | awk 'NR>1 {print $1}'); do
        local config="/etc/pve/lxc/${vmid}.conf"
        [[ ! -f "$config" ]] && continue

        local cores=$(grep -oP '^cores:\s*\K\d+' "$config" || echo "2")
        local memory_mb=$(grep -oP '^memory:\s*\K\d+' "$config" || echo "4096")

        local cost=$(echo "scale=2; $cores * 7.30 + ($memory_mb / 1024) * 3.65" | bc)

        if [[ $(echo "$cost > $threshold" | bc) -eq 1 ]]; then
            local name=$(pct config "$vmid" 2>/dev/null | grep -oP '^hostname:\s*\K.+' || echo "ct${vmid}")
            over_threshold+=("CT $vmid ($name): \$${cost}/month")
        fi
    done

    if [[ ${#over_threshold[@]} -gt 0 ]]; then
        local message="Containers exceeding cost threshold \$${threshold}/month:"
        for ct in "${over_threshold[@]}"; do
            message="$message\n  - $ct"
        done
        send_alert "container_cost_exceeded" 60 "$message" "{\"threshold\":$threshold,\"containers\":${#over_threshold[@]}}"
    fi

    echo "${#over_threshold[@]} containers over threshold"
}

# Check low utilization (rightsizing opportunity)
check_low_utilization() {
    log "Checking for low utilization (rightsizing opportunities)"

    local threshold=$LOW_UTILIZATION_THRESHOLD
    local low_util=()

    for vmid in $(pct list 2>/dev/null | awk 'NR>1 {print $1}'); do
        local status=$(pct status "$vmid" 2>/dev/null | awk '{print $2}')
        [[ "$status" != "running" ]] && continue

        # Get memory utilization
        local memory_info=$(pct exec "$vmid" -- free -m 2>/dev/null | awk '/^Mem:/ {print $2,$3}' || echo "0 0")
        local memory_total=$(echo "$memory_info" | awk '{print $1}')
        local memory_used=$(echo "$memory_info" | awk '{print $2}')

        if [[ $memory_total -gt 0 ]]; then
            local utilization=$(echo "scale=0; ($memory_used * 100) / $memory_total" | bc)

            if [[ $utilization -lt $threshold ]]; then
                local name=$(pct config "$vmid" 2>/dev/null | grep -oP '^hostname:\s*\K.+' || echo "ct${vmid}")
                low_util+=("CT $vmid ($name): ${utilization}% memory usage (allocated: ${memory_total}MB)")
            fi
        fi
    done

    if [[ ${#low_util[@]} -gt 0 ]]; then
        local message="Containers with low utilization (<${threshold}%): Consider rightsizing"
        for ct in "${low_util[@]}"; do
            message="$message\n  - $ct"
        done
        send_alert "low_utilization" 40 "$message" "{\"threshold\":$threshold,\"containers\":${#low_util[@]}}"
    fi

    echo "${#low_util[@]} containers with low utilization"
}

# Send alert notification
send_alert() {
    local alert_type=$1
    local severity=$2
    local message=$3
    local metadata=$4

    local timestamp=$(date -Iseconds)
    local alert_json="{\"type\":\"$alert_type\",\"severity\":$severity,\"message\":\"$message\",\"metadata\":$metadata,\"timestamp\":\"$timestamp\"}"

    log "ALERT [$alert_type] (severity: $severity): $message"

    case "$NOTIFICATION_METHOD" in
        email)
            send_email_alert "$alert_type" "$severity" "$message"
            ;;
        webhook)
            send_webhook_alert "$alert_json"
            ;;
        slack)
            send_slack_alert "$alert_type" "$severity" "$message"
            ;;
        *)
            # Default: log only
            echo "[$timestamp] ALERT: $message" >> "$LOG_FILE"
            ;;
    esac
}

# Send email alert
send_email_alert() {
    local alert_type=$1
    local severity=$2
    local message=$3

    local subject="[Cost Alert] $alert_type (Severity: $severity)"
    local body="Cost Alert Notification\n\nType: $alert_type\nSeverity: $severity\n\n$message\n\nTimestamp: $(date)"

    if command -v mail &> /dev/null; then
        echo -e "$body" | mail -s "$subject" "$EMAIL_TO"
        log "Email alert sent to $EMAIL_TO"
    else
        warn "mail command not found. Email notification skipped."
    fi
}

# Send webhook alert
send_webhook_alert() {
    local alert_json=$1

    if [[ -n "$WEBHOOK_URL" ]]; then
        if command -v curl &> /dev/null; then
            curl -X POST "$WEBHOOK_URL" \
                -H "Content-Type: application/json" \
                -d "$alert_json" \
                --silent --show-error
            log "Webhook alert sent"
        else
            warn "curl command not found. Webhook notification skipped."
        fi
    fi
}

# Send Slack alert
send_slack_alert() {
    local alert_type=$1
    local severity=$2
    local message=$3

    if [[ -n "$SLACK_WEBHOOK" ]]; then
        # Determine color based on severity
        local color="good"
        if [[ $severity -ge 80 ]]; then
            color="danger"
        elif [[ $severity -ge 50 ]]; then
            color="warning"
        fi

        local slack_json=$(cat <<EOF
{
  "attachments": [
    {
      "color": "$color",
      "title": "[Cost Alert] $alert_type",
      "text": "$message",
      "fields": [
        {
          "title": "Severity",
          "value": "$severity",
          "short": true
        },
        {
          "title": "Timestamp",
          "value": "$(date -Iseconds)",
          "short": true
        }
      ]
    }
  ]
}
EOF
)

        if command -v curl &> /dev/null; then
            curl -X POST "$SLACK_WEBHOOK" \
                -H "Content-Type: application/json" \
                -d "$slack_json" \
                --silent --show-error
            log "Slack alert sent"
        else
            warn "curl command not found. Slack notification skipped."
        fi
    fi
}

# Generate alert report
generate_alert_report() {
    local report_file="${1:-/tmp/cost-alert-report.txt}"

    log "Generating alert report: $report_file"

    {
        echo "================================================================================"
        echo "                    Cost Alert Report"
        echo "================================================================================"
        echo "Generated: $(date +'%Y-%m-%d %H:%M:%S')"
        echo "================================================================================"
        echo ""

        echo "=== Budget Status ==="
        local budget_status=$(check_budget_alerts)
        echo "Status: $budget_status"
        echo ""

        echo "=== Daily Spike Check ==="
        local spike_status=$(check_daily_spike)
        echo "Status: $spike_status"
        echo ""

        echo "=== Container Cost Threshold ==="
        local container_status=$(check_container_costs)
        echo "Status: $container_status"
        echo ""

        echo "=== Low Utilization ==="
        local util_status=$(check_low_utilization)
        echo "Status: $util_status"
        echo ""

        echo "================================================================================"
        echo "Recent Alerts:"
        echo "================================================================================"
        tail -20 "$LOG_FILE" | grep -E "\[ALERT\]" || echo "No recent alerts"
        echo ""

        echo "================================================================================"
    } > "$report_file"

    log "Alert report saved to $report_file"
}

# Show usage
show_usage() {
    cat <<EOF
Usage: $0 [alert_type] [threshold] [output_file]

Alert Types:
  check                  Run all alert checks (default)
  budget                 Check budget alerts only
  spike                  Check daily cost spikes
  container              Check container cost thresholds
  utilization            Check low utilization (rightsizing)
  report                 Generate alert report

Threshold:
  warning                Use warning thresholds (default)
  critical               Use critical thresholds

Options:
  NOTIFICATION_METHOD    How to send alerts (log, email, webhook, slack)
  EMAIL_TO               Email recipient (default: admin@example.com)
  WEBHOOK_URL            Webhook URL for alerts
  SLACK_WEBHOOK          Slack webhook URL for alerts

Environment Variables:
  MONTHLY_BUDGET_WARNING=100        Warning budget threshold
  MONTHLY_BUDGET_CRITICAL=150       Critical budget threshold
  DAILY_SPIKE_THRESHOLD=50          % spike threshold
  CONTAINER_COST_THRESHOLD=20       Container cost threshold
  LOW_UTILIZATION_THRESHOLD=20      Low utilization threshold

Examples:
  $0 check                        # Run all alert checks
  $0 budget                       # Check budget only
  $0 spike                        # Check for spikes
  $0 utilization                  # Check low utilization
  $0 report /tmp/alerts.txt       # Generate report

  NOTIFICATION_METHOD=email EMAIL_TO=team@example.com $0 check

Cron Setup:
  # Check costs every hour
  0 * * * * $0 check >> $LOG_FILE 2>&1

  # Daily budget check at 9 AM
  0 9 * * * $0 budget >> $LOG_FILE 2>&1
EOF
}

# Main execution
main() {
    case "$ALERT_TYPE" in
        check)
            log "Running all cost alert checks"
            check_budget_alerts
            check_daily_spike
            check_container_costs
            check_low_utilization
            ;;
        budget)
            check_budget_alerts
            ;;
        spike)
            check_daily_spike
            ;;
        container)
            check_container_costs
            ;;
        utilization)
            check_low_utilization
            ;;
        report)
            generate_alert_report "$OUTPUT_FILE"
            ;;
        help|--help|-h)
            show_usage
            ;;
        *)
            error "Unknown alert type: $ALERT_TYPE"
            ;;
    esac

    log "Cost alert check complete"
}

# Run main
main "$@"
