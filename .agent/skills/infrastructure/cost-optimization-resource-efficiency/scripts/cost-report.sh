#!/bin/bash
# cost-report.sh - Generate detailed cost reports
# Part of the cost-optimization-resource-efficiency skill

set -euo pipefail

# Configuration
REPORT_PERIOD="${1:-30d}"     # Report period
OUTPUT_FORMAT="${2:-text}"    # text, csv, json, html
OUTPUT_FILE="${3:-}"          # Optional output file
BREAKDOWN_BY="${4:-container}" # container, type, team

# Cost constants (monthly)
COST_PER_VCPU_MONTHLY="${COST_PER_VCPU_MONTHLY:-7.30}"     # ~$0.01/hour
COST_PER_GB_RAM_MONTHLY="${COST_PER_GB_RAM_MONTHLY:-3.65}" # ~$0.005/hour
COST_PER_GB_STORAGE_MONTHLY="${COST_PER_GB_STORAGE_MONTHLY:-0.073}" # ~$0.0001/hour

# Budget allocations (optional)
BUDGET_DEV="${BUDGET_DEV:-30}"
BUDGET_INFRA="${BUDGET_INFRA:-50}"
BUDGET_PROD="${BUDGET_PROD:-100}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Logging
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
    exit 1
}

# Get period in days
get_period_days() {
    local period=$1
    local value=${period%[a-z]*}
    local unit=${period#$value}

    case $unit in
        d) echo "$value" ;;
        w) echo $((value * 7)) ;;
        m) echo $((value * 30)) ;;
        *) echo "30" ;;
    esac
}

# Get container cost allocation
get_container_allocation() {
    local vmid=$1

    # Get tags from container config
    local tags=$(pct config "$vmid" 2>/dev/null | grep -oP '^tags:\s*\K.+' || echo "")

    if [[ "$tags" == *"cost-center:dev"* ]]; then
        echo "development"
    elif [[ "$tags" == *"cost-center:prod"* ]]; then
        echo "production"
    else
        echo "infrastructure"
    fi
}

# Calculate container monthly cost
calculate_container_monthly_cost() {
    local vmid=$1
    local config="/etc/pve/lxc/${vmid}.conf"

    if [[ ! -f "$config" ]]; then
        echo "0.00"
        return
    fi

    local cores=$(grep -oP '^cores:\s*\K\d+' "$config" || echo "2")
    local memory_mb=$(grep -oP '^memory:\s*\K\d+' "$config" || echo "4096")
    local storage_gb=$(grep -oP '^rootfs:\s*\K[\d.]+' "$config" || echo "32")

    local cpu_cost=$(echo "scale=2; $cores * $COST_PER_VCPU_MONTHLY" | bc)
    local memory_cost=$(echo "scale=2; ($memory_mb / 1024) * $COST_PER_GB_RAM_MONTHLY" | bc)
    local storage_cost=$(echo "scale=2; $storage_gb * $COST_PER_GB_STORAGE_MONTHLY" | bc)
    local total=$(echo "scale=2; $cpu_cost + $memory_cost + $storage_cost" | bc)

    echo "$total"
}

# Calculate VM monthly cost
calculate_vm_monthly_cost() {
    local vmid=$1
    local config="/etc/pve/qemu-server/${vmid}.conf"

    if [[ ! -f "$config" ]]; then
        echo "0.00"
        return
    fi

    local cores=$(grep -oP '^cores:\s*\K\d+' "$config" || echo "2")
    local memory_mb=$(grep -oP '^memory:\s*\K\d+' "$config" || echo "4096")

    # Sum all disks
    local disk_gb=0
    while read -r disk; do
        disk_gb=$(echo "$disk_gb + $disk" | bc)
    done < <(grep -oP '^[^0]+:\s*\K[\d.]+' "$config" 2>/dev/null | head -10)

    local cpu_cost=$(echo "scale=2; $cores * $COST_PER_VCPU_MONTHLY" | bc)
    local memory_cost=$(echo "scale=2; ($memory_mb / 1024) * $COST_PER_GB_RAM_MONTHLY" | bc)
    local storage_cost=$(echo "scale=2; $disk_gb * $COST_PER_GB_STORAGE_MONTHLY" | bc)
    local total=$(echo "scale=2; $cpu_cost + $memory_cost + $storage_cost" | bc)

    echo "$total"
}

# Generate text report
generate_text_report() {
    local period_days=$(get_period_days "$REPORT_PERIOD")

    echo "================================================================================"
    echo "                    Infrastructure Cost Report"
    echo "================================================================================"
    echo "Period: $(date +'%Y-%m-%d') - Last $period_days days"
    echo "Generated: $(date +'%Y-%m-%d %H:%M:%S')"
    echo "================================================================================"
    echo ""

    # Summary
    echo "=== Cost Summary ==="
    echo ""

    local total_cost=0
    local total_containers=0
    local total_vms=0

    # Container costs
    echo "Containers:"
    for vmid in $(pct list 2>/dev/null | awk 'NR>1 {print $1}'); do
        local name=$(pct config "$vmid" 2>/dev/null | grep -oP '^hostname:\s*\K.+' || echo "ct${vmid}")
        local cost=$(calculate_container_monthly_cost "$vmid")
        local allocation=$(get_container_allocation "$vmid")

        printf "  CT %3d (%-20s) \$%7.2f/month [%s]\n" "$vmid" "$name" "$cost" "$allocation"

        total_cost=$(echo "scale=2; $total_cost + $cost" | bc)
        total_containers=$((total_containers + 1))
    done

    echo ""
    echo "Virtual Machines:"
    for vmid in $(qm list 2>/dev/null | awk 'NR>1 {print $1}'); do
        local name=$(qm config "$vmid" 2>/dev/null | grep -oP '^name:\s*\K.+' || echo "vm${vmid}")
        local cost=$(calculate_vm_monthly_cost "$vmid")

        printf "  VM %3d (%-20s) \$%7.2f/month\n" "$vmid" "$name" "$cost"

        total_cost=$(echo "scale=2; $total_cost + $cost" | bc)
        total_vms=$((total_vms + 1))
    done

    echo ""
    echo "────────────────────────────────────────────────────────────────────────────────"
    printf "Total (%d containers + %d VMs):                 \$%7.2f/month\n" \
        "$total_containers" "$total_vms" "$total_cost"
    echo ""

    # Breakdown by type
    echo "=== Cost Breakdown by Resource Type ==="
    echo ""

    local total_cpu=0
    local total_memory=0
    local total_storage=0

    for vmid in $(pct list 2>/dev/null | awk 'NR>1 {print $1}'); do
        local config="/etc/pve/lxc/${vmid}.conf"
        [[ ! -f "$config" ]] && continue

        local cores=$(grep -oP '^cores:\s*\K\d+' "$config" || echo "2")
        local memory_mb=$(grep -oP '^memory:\s*\K\d+' "$config" || echo "4096")
        local storage_gb=$(grep -oP '^rootfs:\s*\K[\d.]+' "$config" || echo "32")

        total_cpu=$((total_cpu + cores))
        total_memory=$((total_memory + memory_mb))
        total_storage=$(echo "scale=2; $total_storage + $storage_gb" | bc)
    done

    local cpu_cost=$(echo "scale=2; $total_cpu * $COST_PER_VCPU_MONTHLY" | bc)
    local memory_cost=$(echo "scale=2; ($total_memory / 1024) * $COST_PER_GB_RAM_MONTHLY" | bc)
    local storage_cost=$(echo "scale=2; $total_storage * $COST_PER_GB_STORAGE_MONTHLY" | bc)

    printf "  CPU (%d cores):                    \$%7.2f/month\n" "$total_cpu" "$cpu_cost"
    printf "  Memory (%.1f GB):                  \$%7.2f/month\n" "$(echo "scale=1; $total_memory / 1024" | bc)" "$memory_cost"
    printf "  Storage (%.0f GB):                  \$%7.2f/month\n" "$total_storage" "$storage_cost"
    echo "────────────────────────────────────────────────────────────────────────────────"
    printf "  Total:                             \$%7.2f/month\n" "$total_cost"
    echo ""

    # Budget comparison
    echo "=== Budget Comparison ==="
    echo ""

    local cost_dev=0
    local cost_infra=0
    local cost_prod=0

    for vmid in $(pct list 2>/dev/null | awk 'NR>1 {print $1}'); do
        local cost=$(calculate_container_monthly_cost "$vmid")
        local allocation=$(get_container_allocation "$vmid")

        case "$allocation" in
            development) cost_dev=$(echo "scale=2; $cost_dev + $cost" | bc) ;;
            production)  cost_prod=$(echo "scale=2; $cost_prod + $cost" | bc) ;;
            *)           cost_infra=$(echo "scale=2; $cost_infra + $cost" | bc) ;;
        esac
    done

    printf "  Development:     \$%7.2f / \$%5.0f budget (%3.0f%%)\n" "$cost_dev" "$BUDGET_DEV" "$(echo "scale=0; ($cost_dev * 100) / $BUDGET_DEV" | bc)"
    printf "  Infrastructure: \$%7.2f / \$%5.0f budget (%3.0f%%)\n" "$cost_infra" "$BUDGET_INFRA" "$(echo "scale=0; ($cost_infra * 100) / $BUDGET_INFRA" | bc)"
    printf "  Production:     \$%7.2f / \$%5.0f budget (%3.0f%%)\n" "$cost_prod" "$BUDGET_PROD" "$(echo "scale=0; ($cost_prod * 100) / $BUDGET_PROD" | bc)"
    echo ""

    local total_budget=$((BUDGET_DEV + BUDGET_INFRA + BUDGET_PROD))
    local budget_variance=$(echo "scale=2; $total_cost - $total_budget" | bc)

    if [[ $(echo "$budget_variance < 0" | bc) -eq 1 ]]; then
        printf -e "${GREEN}Under budget by \$%.2f${NC}\n" "$(echo "$budget_variance * -1" | bc)"
    else
        printf -e "${RED}Over budget by \$%.2f${NC}\n" "$budget_variance"
    fi

    echo ""
    echo "================================================================================"
}

# Generate CSV report
generate_csv_report() {
    echo "vmid,name,type,cpu_cores,memory_mb,storage_gb,cost_monthly,allocation"

    for vmid in $(pct list 2>/dev/null | awk 'NR>1 {print $1}'); do
        local name=$(pct config "$vmid" 2>/dev/null | grep -oP '^hostname:\s*\K.+' || echo "ct${vmid}")
        local config="/etc/pve/lxc/${vmid}.conf"
        [[ ! -f "$config" ]] && continue

        local cores=$(grep -oP '^cores:\s*\K\d+' "$config" || echo "2")
        local memory_mb=$(grep -oP '^memory:\s*\K\d+' "$config" || echo "4096")
        local storage_gb=$(grep -oP '^rootfs:\s*\K[\d.]+' "$config" || echo "32")
        local cost=$(calculate_container_monthly_cost "$vmid")
        local allocation=$(get_container_allocation "$vmid")

        echo "$vmid,$name,container,$cores,$memory_mb,$storage_gb,$cost,$allocation"
    done

    for vmid in $(qm list 2>/dev/null | awk 'NR>1 {print $1}'); do
        local name=$(qm config "$vmid" 2>/dev/null | grep -oP '^name:\s*\K.+' || echo "vm${vmid}")
        local config="/etc/pve/qemu-server/${vmid}.conf"
        [[ ! -f "$config" ]] && continue

        local cores=$(grep -oP '^cores:\s*\K\d+' "$config" || echo "2")
        local memory_mb=$(grep -oP '^memory:\s*\K\d+' "$config" || echo "4096")
        local storage_gb=0
        while read -r disk; do
            storage_gb=$(echo "$storage_gb + $disk" | bc)
        done < <(grep -oP '^[^0]+:\s*\K[\d.]+' "$config" 2>/dev/null | head -10)
        local cost=$(calculate_vm_monthly_cost "$vmid")

        echo "$vmid,$name,vm,$cores,$memory_mb,$storage_gb,$cost,infrastructure"
    done
}

# Generate JSON report
generate_json_report() {
    local period_days=$(get_period_days "$REPORT_PERIOD")

    echo "{"
    echo "  \"report_metadata\": {"
    echo "    \"period\": \"$REPORT_PERIOD\","
    echo "    \"period_days\": $period_days,"
    echo "    \"generated_at\": \"$(date -Iseconds)\","
    echo "    \"timezone\": \"$(date +%Z)\""
    echo "  },"
    echo "  \"containers\": ["

    local first=true
    for vmid in $(pct list 2>/dev/null | awk 'NR>1 {print $1}'); do
        local name=$(pct config "$vmid" 2>/dev/null | grep -oP '^hostname:\s*\K.+' || echo "ct${vmid}")
        local config="/etc/pve/lxc/${vmid}.conf"
        [[ ! -f "$config" ]] && continue

        local cores=$(grep -oP '^cores:\s*\K\d+' "$config" || echo "2")
        local memory_mb=$(grep -oP '^memory:\s*\K\d+' "$config" || echo "4096")
        local storage_gb=$(grep -oP '^rootfs:\s*\K[\d.]+' "$config" || echo "32")
        local cost=$(calculate_container_monthly_cost "$vmid")
        local allocation=$(get_container_allocation "$vmid")
        local status=$(pct status "$vmid" 2>/dev/null | awk '{print $2}')

        [[ "$first" == "false" ]] && echo ","
        first=false

        echo "    {\"vmid\":$vmid,\"name\":\"$name\",\"type\":\"container\",\"cores\":$cores,\"memory_mb\":$memory_mb,\"storage_gb\":$storage_gb,\"cost_monthly\":$cost,\"allocation\":\"$allocation\",\"status\":\"$status\"}" | tr -d '\n'
    done

    echo ""
    echo "  ],"
    echo "  \"vms\": ["

    first=true
    for vmid in $(qm list 2>/dev/null | awk 'NR>1 {print $1}'); do
        local name=$(qm config "$vmid" 2>/dev/null | grep -oP '^name:\s*\K.+' || echo "vm${vmid}")
        local config="/etc/pve/qemu-server/${vmid}.conf"
        [[ ! -f "$config" ]] && continue

        local cores=$(grep -oP '^cores:\s*\K\d+' "$config" || echo "2")
        local memory_mb=$(grep -oP '^memory:\s*\K\d+' "$config" || echo "4096")
        local storage_gb=0
        while read -r disk; do
            storage_gb=$(echo "$storage_gb + $disk" | bc)
        done < <(grep -oP '^[^0]+:\s*\K[\d.]+' "$config" 2>/dev/null | head -10)
        local cost=$(calculate_vm_monthly_cost "$vmid")
        local status=$(qm status "$vmid" 2>/dev/null | awk '{print $2}')

        [[ "$first" == "false" ]] && echo ","
        first=false

        echo "    {\"vmid\":$vmid,\"name\":\"$name\",\"type\":\"vm\",\"cores\":$cores,\"memory_mb\":$memory_mb,\"storage_gb\":$storage_gb,\"cost_monthly\":$cost,\"allocation\":\"infrastructure\",\"status\":\"$status\"}" | tr -d '\n'
    done

    echo ""
    echo "  ],"
    echo "  \"budget\": {"
    echo "    \"development\": {\"budget\":$BUDGET_DEV,\"spent\":$cost_dev},"
    echo "    \"infrastructure\": {\"budget\":$BUDGET_INFRA,\"spent\":$cost_infra},"
    echo "    \"production\": {\"budget\":$BUDGET_PROD,\"spent\":$cost_prod}"
    echo "  }"
    echo "}"
}

# Compare against budget
compare_budget() {
    local budget=${1:-180}

    log "Comparing costs against budget: \$${budget}"

    local total_cost=0

    for vmid in $(pct list 2>/dev/null | awk 'NR>1 {print $1}'); do
        local cost=$(calculate_container_monthly_cost "$vmid")
        total_cost=$(echo "scale=2; $total_cost + $cost" | bc)
    done

    for vmid in $(qm list 2>/dev/null | awk 'NR>1 {print $1}'); do
        local cost=$(calculate_vm_monthly_cost "$vmid")
        total_cost=$(echo "scale=2; $total_cost + $cost" | bc)
    done

    echo ""
    echo "Budget Comparison:"
    echo "  Budget:      \$${budget}"
    echo "  Spent:       \$$(echo "scale=2; $total_cost" | bc)"
    echo "  Remaining:   \$$(echo "scale=2; $budget - $total_cost" | bc)"
    echo "  Percentage:  $(echo "scale=1; ($total_cost * 100) / $budget" | bc)%"

    if [[ $(echo "$total_cost > $budget" | bc) -eq 1 ]]; then
        local over=$(echo "scale=2; $total_cost - $budget" | bc)
        echo -e "${RED}  Status: OVER BUDGET by \$$over${NC}"
        return 1
    else
        echo -e "${GREEN}  Status: Within budget${NC}"
        return 0
    fi
}

# Reallocate budget
reallocate_budget() {
    local team=$1
    local new_budget=$2

    log "Reallocating budget for $team: \$${new_budget}"

    case "$team" in
        development)
            BUDGET_DEV=$new_budget
            ;;
        infrastructure)
            BUDGET_INFRA=$new_budget
            ;;
        production)
            BUDGET_PROD=$new_budget
            ;;
        *)
            error "Unknown team: $team. Use: development, infrastructure, or production"
            ;;
    esac

    log "Budget reallocated: $team = \$${new_budget}"
}

# Show usage
show_usage() {
    cat <<EOF
Usage: $0 [period] [format] [output_file] [breakdown]

Arguments:
  period      Report period (default: 30d)
              Examples: 7d, 1w, 1m, 90d

  format      Output format (default: text)
              Options: text, csv, json, html

  output_file Optional file path for output

  breakdown   Group by (default: container)
              Options: container, type, team

Actions:
  --compare-budget <amount>   Compare against budget
  --reallocate <team> <amt>   Reallocate budget

Examples:
  $0 30d text                        # Text report for last 30 days
  $0 90d csv report.csv              # CSV report saved to file
  $0 30d json cost-report.json       # JSON report
  $0 --compare-budget 180            # Compare against $180 budget
  $0 --reallocate development 40     # Set dev budget to $40

Environment Variables:
  BUDGET_DEV=30                      Development team budget
  BUDGET_INFRA=50                    Infrastructure budget
  BUDGET_PROD=100                    Production budget
EOF
}

# Main execution
main() {
    # Parse special actions
    if [[ "$1" == "--compare-budget" ]]; then
        compare_budget "$2"
        exit 0
    elif [[ "$1" == "--reallocate" ]]; then
        reallocate_budget "$2" "$3"
        exit 0
    elif [[ "$1" == "--help" ]] || [[ "$1" == "-h" ]]; then
        show_usage
        exit 0
    fi

    log "Generating cost report for period: $REPORT_PERIOD (format: $OUTPUT_FORMAT)"

    case "$OUTPUT_FORMAT" in
        csv)
            generate_csv_report
            ;;
        json)
            generate_json_report
            ;;
        text)
            generate_text_report
            ;;
        *)
            error "Unknown format: $OUTPUT_FORMAT. Use: text, csv, or json"
            ;;
    esac

    # Save to file if specified
    if [[ -n "$OUTPUT_FILE" ]]; then
        log "Saving report to $OUTPUT_FILE"
        main > "$OUTPUT_FILE"
    fi

    log "Cost report complete"
}

# Run main
main "$@"
