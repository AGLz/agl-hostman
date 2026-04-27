#!/bin/bash
# cost-schedule.sh - Configure power schedules for dev/test environments
# Part of the cost-optimization-resource-efficiency skill

set -euo pipefail

# Configuration
SCHEDULE_CONFIG="${SCHEDULE_CONFIG:-/etc/cost-schedule.conf}"
TIMEZONE="${TIMEZONE:-America/New_York}"
DRY_RUN="${DRY_RUN:-true}"
LOG_FILE="/var/log/cost-schedule.log"

# Default schedules (cron format)
# Format: "vmid:start_time:stop_time:days"
# Days: comma-separated (1-7, where 1=Monday, 7=Sunday)
DEFAULT_SCHEDULES=(
    "179:08:00:20:00:1,2,3,4,5"    # agldv03 - Mon-Fri 8am-8pm
    "180:09:00:19:00:1,2,3,4,5"    # dokploy - Mon-Fri 9am-7pm
    "181:09:00:18:00:1,2,3,4,5"    # agldv04 - Mon-Fri 9am-6pm
)

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

# Parse schedule config
parse_schedules() {
    if [[ -f "$SCHEDULE_CONFIG" ]]; then
        source "$SCHEDULE_CONFIG"
    fi

    # Use default if no schedules defined
    if [[ ${#SCHEDULES[@]} -eq 0 ]]; then
        SCHEDULES=("${DEFAULT_SCHEDULES[@]}")
    fi
}

# Check if container should be running now
should_be_running() {
    local vmid=$1
    local current_hour=$(TZ="$TIMEZONE" date +%H)
    local current_minute=$(TZ="$TIMEZONE" date +%M)
    local current_day=$(TZ="$TIMEZONE" date +%u)  # 1-7 (Mon-Sun)
    local current_time=$((current_hour * 60 + current_minute))

    for schedule in "${SCHEDULES[@]}"; do
        IFS=':' read -r s_vmid s_start_hour s_start_min s_end_hour s_end_min s_days <<< "$schedule"

        if [[ "$s_vmid" != "$vmid" ]]; then
            continue
        fi

        # Check if today is in scheduled days
        if [[ ",$s_days," != *",$current_day,"* ]]; then
            echo "false"
            return
        fi

        # Calculate schedule times in minutes
        local start_time=$((s_start_hour * 60 + s_start_min))
        local end_time=$((s_end_hour * 60 + s_end_min))

        # Check if current time is within schedule
        if [[ $current_time -ge $start_time ]] && [[ $current_time -lt $end_time ]]; then
            echo "true"
        else
            echo "false"
        fi
        return
    done

    # No schedule found - assume should be running
    echo "true"
}

# Get schedule for a container
get_schedule() {
    local vmid=$1

    for schedule in "${SCHEDULES[@]}"; do
        IFS=':' read -r s_vmid s_start_hour s_start_min s_end_hour s_end_min s_days <<< "$schedule"

        if [[ "$s_vmid" == "$vmid" ]]; then
            local day_names=("Mon" "Tue" "Wed" "Thu" "Fri" "Sat" "Sun")
            local schedule_days=""
            IFS=',' read -ra days <<< "$s_days"
            for day in "${days[@]}"; do
                schedule_days="${schedule_days}${day_names[$((day-1))]} "
            done

            echo "Schedule: ${s_start_hour}:${s_start_min} - ${s_end_hour}:${s_end_min} on $schedule_days"
            return
        fi
    done

    echo "No schedule (24/7)"
}

# List all schedules
list_schedules() {
    log "Current power schedules (timezone: $TIMEZONE)"
    echo ""

    for schedule in "${SCHEDULES[@]}"; do
        IFS=':' read -r vmid s_start_hour s_start_min s_end_hour s_end_min s_days <<< "$schedule"

        local name=$(pct config "$vmid" 2>/dev/null | grep -oP '^hostname:\s*\K.+' || echo "ct${vmid}")
        local status=$(pct status "$vmid" 2>/dev/null | awk '{print $2}' || echo "unknown")
        local should_run=$(should_be_running "$vmid")

        local day_names=("Mon" "Tue" "Wed" "Thu" "Fri" "Sat" "Sun")
        local schedule_days=""
        IFS=',' read -ra days <<< "$s_days"
        for day in "${days[@]}"; do
            schedule_days="${schedule_days}${day_names[$((day-1))]},"
        done
        schedule_days=${schedule_days%,}

        printf "CT %3d (%-20s) %8s | ${s_start_hour}:${s_start_min}-${s_end_hour}:${s_end_min} [%s] | Should be: %s\n" \
            "$vmid" "$name" "$status" "$schedule_days" "$should_run"
    done
}

# Apply power schedules
apply_schedules() {
    local action="${1:-sync}"

    log "Applying power schedules (action: $action, timezone: $TIMEZONE)"

    local started=0
    local stopped=0
    local skipped=0

    for schedule in "${SCHEDULES[@]}"; do
        IFS=':' read -r vmid s_start_hour s_start_min s_end_hour s_end_min s_days <<< "$schedule"

        local name=$(pct config "$vmid" 2>/dev/null | grep -oP '^hostname:\s*\K.+' || echo "ct${vmid}")
        local status=$(pct status "$vmid" 2>/dev/null | awk '{print $2}' || echo "unknown")
        local should_run=$(should_be_running "$vmid")

        case "$action" in
            sync)
                # Sync to current state
                if [[ "$should_run" == "true" ]] && [[ "$status" == "stopped" ]]; then
                    log "Starting CT $vmid ($name) - within scheduled hours"
                    if [[ "$DRY_RUN" != "true" ]]; then
                        pct start "$vmid" && started=$((started + 1))
                    else
                        log "[DRY RUN] Would start CT $vmid"
                        started=$((started + 1))
                    fi
                elif [[ "$should_run" == "false" ]] && [[ "$status" == "running" ]]; then
                    log "Stopping CT $vmid ($name) - outside scheduled hours"
                    if [[ "$DRY_RUN" != "true" ]]; then
                        pct shutdown "$vmid" --timeout 60 && stopped=$((stopped + 1))
                    else
                        log "[DRY RUN] Would stop CT $vmid"
                        stopped=$((stopped + 1))
                    fi
                else
                    skipped=$((skipped + 1))
                fi
                ;;

            power-on)
                if [[ "$should_run" == "true" ]]; then
                    log "Starting CT $vmid ($name)"
                    if [[ "$DRY_RUN" != "true" ]]; then
                        pct start "$vmid" && started=$((started + 1))
                    else
                        log "[DRY RUN] Would start CT $vmid"
                        started=$((started + 1))
                    fi
                fi
                ;;

            power-off)
                if [[ "$status" == "running" ]]; then
                    log "Stopping CT $vmid ($name)"
                    if [[ "$DRY_RUN" != "true" ]]; then
                        pct shutdown "$vmid" --timeout 60 && stopped=$((stopped + 1))
                    else
                        log "[DRY RUN] Would stop CT $vmid"
                        stopped=$((stopped + 1))
                    fi
                fi
                ;;
        esac
    done

    log "Schedule application complete: $started started, $stopped stopped, $skipped skipped"
}

# Generate cron entries
generate_cron() {
    log "Generating cron entries for schedule automation"
    echo ""

    for schedule in "${SCHEDULES[@]}"; do
        IFS=':' read -r vmid s_start_hour s_start_min s_end_hour s_end_min s_days <<< "$schedule"

        local name=$(pct config "$vmid" 2>/dev/null | grep -oP '^hostname:\s*\K.+' || echo "ct${vmid}")
        local day_range=${s_days//,/}

        # Power on cron
        echo "# Power on CT $vmid ($name) at ${s_start_hour}:${s_start_min}"
        echo "${s_start_min} ${s_start_hour} * * ${day_range} $0 power-on \$vmid >> $LOG_FILE 2>&1"

        # Power off cron
        echo "# Power off CT $vmid ($name) at ${s_end_hour}:${s_end_min}"
        echo "${s_end_min} ${s_end_hour} * * ${day_range} $0 power-off \$vmid >> $LOG_FILE 2>&1"
        echo ""
    done
}

# Calculate cost savings
calculate_savings() {
    log "Calculating cost savings from power scheduling"
    echo ""

    local total_savings=0
    local hours_per_month=730

    for schedule in "${SCHEDULES[@]}"; do
        IFS=':' read -r vmid s_start_hour s_start_min s_end_hour s_end_min s_days <<< "$schedule"

        local name=$(pct config "$vmid" 2>/dev/null | grep -oP '^hostname:\s*\K.+' || echo "ct${vmid}")

        # Get container config
        local config="/etc/pve/lxc/${vmid}.conf"
        if [[ ! -f "$config" ]]; then
            continue
        fi

        local cores=$(grep -oP '^cores:\s*\K\d+' "$config" || echo "2")
        local memory_mb=$(grep -oP '^memory:\s*\K\d+' "$config" || echo "4096")

        # Calculate hourly cost
        local cost_per_vcpu_hour=0.01
        local cost_per_gb_ram_hour=0.005
        local hourly_cost=$(echo "scale=4; $cores * $cost_per_vcpu_hour + ($memory_mb / 1024) * $cost_per_gb_ram_hour" | bc)

        # Calculate scheduled hours per week
        IFS=',' read -ra days <<< "$s_days"
        local days_per_week=${#days[@]}
        local scheduled_hours_per_day=$((s_end_hour - s_start_hour))
        local scheduled_hours_per_week=$((days_per_week * scheduled_hours_per_day))

        # Calculate savings (hours NOT running)
        local total_hours_per_week=168
        local unscheduled_hours_per_week=$((total_hours_per_week - scheduled_hours_per_week))
        local unscheduled_hours_per_month=$((unscheduled_hours_per_week * 4))
        local monthly_savings=$(echo "scale=2; $hourly_cost * $unscheduled_hours_per_month" | bc)

        total_savings=$(echo "scale=2; $total_savings + $monthly_savings" | bc)

        printf "CT %3d (%-20s): \$%6.2f/month saved (%d hours/day, %d days/week)\n" \
            "$vmid" "$name" "$monthly_savings" "$scheduled_hours_per_day" "$days_per_week"
    done

    echo ""
    echo "Total monthly savings: \$${total_savings}"
    echo "Annual savings: \$$(echo "scale=2; $total_savings * 12" | bc)"
}

# Add schedule for a container
add_schedule() {
    local vmid=$1
    local start_time=$2
    local end_time=$3
    local days=$4

    IFS=':' read -r start_hour start_min <<< "$start_time"
    IFS=':' read -r end_hour end_min <<< "$end_time"

    log "Adding schedule for CT $vmid: ${start_time}-${end_time} on $days"

    # Add to schedules
    SCHEDULES+=("$vmid:${start_hour}:${start_min}:${end_hour}:${end_min}:${days}")

    # Save to config
    save_config
}

# Remove schedule for a container
remove_schedule() {
    local vmid=$1

    log "Removing schedule for CT $vmid"

    # Filter out the schedule
    local new_schedules=()
    for schedule in "${SCHEDULES[@]}"; do
        IFS=':' read -r s_vmid _ <<< "$schedule"
        if [[ "$s_vmid" != "$vmid" ]]; then
            new_schedules+=("$schedule")
        fi
    done

    SCHEDULES=("${new_schedules[@]}")
    save_config
}

# Save schedule configuration
save_config() {
    log "Saving schedule configuration to $SCHEDULE_CONFIG"

    cat > "$SCHEDULE_CONFIG" <<EOF
# Power schedule configuration
# Generated by cost-schedule.sh on $(date)
# Format: "vmid:start_hour:start_min:end_hour:end_min:days"
# Days: comma-separated 1-7 (1=Monday, 7=Sunday)

SCHEDULES=(
EOF

    for schedule in "${SCHEDULES[@]}"; do
        echo "    \"$schedule\"" >> "$SCHEDULE_CONFIG"
    done

    echo ")" >> "$SCHEDULE_CONFIG"
}

# Show usage
show_usage() {
    cat <<EOF
Usage: $0 [action] [options]

Actions:
  list                    List all power schedules
  sync                    Sync containers to their schedules
  power-on                Power on scheduled containers
  power-off               Power off scheduled containers
  add <vmid> <start> <end> <days>   Add schedule
  remove <vmid>           Remove schedule
  generate-cron           Generate cron entries
  calculate-savings       Calculate cost savings

Options:
  DRY_RUN=false           Apply changes (default: true)
  TIMEZONE=zone           Timezone (default: America/New_York)
  SCHEDULE_CONFIG=path    Config file (default: /etc/cost-schedule.conf)

Examples:
  $0 list                                    # List schedules
  $0 sync                                    # Sync to schedules
  DRY_RUN=false $0 sync                      # Apply for real
  $0 add 179 08:00 20:00 1,2,3,4,5          # Add schedule
  $0 remove 179                              # Remove schedule
  $0 generate-cron                           # Generate cron entries
  $0 calculate-savings                       # Show savings

Cron Setup:
  # Add to crontab for automatic scheduling:
  $0 sync | crontab -

  # Or manually add:
  */15 * * * * $0 sync >> $LOG_FILE 2>&1
EOF
}

# Main execution
main() {
    parse_schedules

    local action="${1:-list}"

    case "$action" in
        list)
            list_schedules
            ;;
        sync|power-on|power-off)
            apply_schedules "$action"
            ;;
        add)
            [[ $# -lt 5 ]] && error "Usage: $0 add <vmid> <start_time> <end_time> <days>"
            add_schedule "$2" "$3" "$4" "$5"
            ;;
        remove)
            [[ $# -lt 2 ]] && error "Usage: $0 remove <vmid>"
            remove_schedule "$2"
            ;;
        generate-cron)
            generate_cron
            ;;
        calculate-savings)
            calculate_savings
            ;;
        help|--help|-h)
            show_usage
            ;;
        *)
            error "Unknown action: $action"
            ;;
    esac
}

# Run main
main "$@"
