#!/bin/bash
################################################################################
# Disk Failure Diagnostic Suite for Proxmox
# Host: 100.98.119.51
# Version: 1.0
# Description: Comprehensive disk failure analysis and monitoring framework
################################################################################

set -euo pipefail

# Configuration
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly REPORT_DIR="/var/log/disk-diagnostics"
readonly TIMESTAMP=$(date +%Y%m%d-%H%M%S)
readonly REPORT_FILE="${REPORT_DIR}/diagnostic-report-${TIMESTAMP}.txt"
readonly HOST_IP="100.98.119.51"

# Color codes
readonly RED='\033[0;31m'
readonly YELLOW='\033[1;33m'
readonly GREEN='\033[0;32m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m' # No Color

# Ensure report directory exists
mkdir -p "$REPORT_DIR"

################################################################################
# Utility Functions
################################################################################

print_header() {
    local title=$1
    echo -e "\n${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║$(printf "%62s" | tr ' ' ' ')║${NC}"
    echo -e "${CYAN}║  ${title}$(printf "%$((58-${#title}))s" | tr ' ' ' ')║${NC}"
    echo -e "${CYAN}║$(printf "%62s" | tr ' ' ' ')║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}\n"
}

print_section() {
    local section=$1
    echo -e "\n${BLUE}┌─── ${section} ───┐${NC}"
}

print_status() {
    local status=$1
    local message=$2
    case $status in
        "ok")
            echo -e "${GREEN}✓${NC} $message"
            ;;
        "warn")
            echo -e "${YELLOW}⚠${NC} $message"
            ;;
        "error")
            echo -e "${RED}✗${NC} $message"
            ;;
        "info")
            echo -e "${BLUE}ℹ${NC} $message"
            ;;
    esac
}

log_output() {
    tee -a "$REPORT_FILE"
}

################################################################################
# Risk Calculation Functions
################################################################################

calculate_hardware_score() {
    local disk=$1
    local score=0

    # Check if disk exists
    if [ ! -e "/dev/$disk" ]; then
        echo "100"  # Critical - disk not found
        return
    fi

    # SMART attribute evaluation
    local reallocated=$(smartctl -A /dev/$disk 2>/dev/null | grep "Reallocated_Sector" | awk '{print $NF}' || echo "0")
    local pending=$(smartctl -A /dev/$disk 2>/dev/null | grep "Current_Pending_Sector" | awk '{print $NF}' || echo "0")
    local uncorrectable=$(smartctl -A /dev/$disk 2>/dev/null | grep "Offline_Uncorrectable" | awk '{print $NF}' || echo "0")
    local temp=$(smartctl -A /dev/$disk 2>/dev/null | grep "Temperature_Celsius" | awk '{print $NF}' || echo "0")

    # Score calculation
    score=$((score + reallocated * 5))
    score=$((score + pending * 10))
    [ "$uncorrectable" -gt 0 ] && score=100  # Critical if any uncorrectable

    # Temperature penalty
    [ "$temp" -gt 55 ] && score=$((score + (temp - 55) * 2))

    # Cap at 100
    [ $score -gt 100 ] && score=100

    echo "$score"
}

calculate_zfs_integrity_score() {
    local pool=$1
    local score=0

    # Check pool exists
    if ! zpool list "$pool" &>/dev/null; then
        echo "100"
        return
    fi

    # Get error counts
    local cksum_errors=$(zpool status "$pool" | grep -oP '\d+(?=\s+\d+\s+\d+$)' | awk '{sum+=$1} END {print sum+0}')
    local read_errors=$(zpool status "$pool" | grep -oP '\d+(?=\s+\d+$)' | awk '{sum+=$1} END {print sum+0}')
    local write_errors=$(zpool status "$pool" | grep -oP '(?<=\s)\d+(?=\s+\d+\s*$)' | awk '{sum+=$1} END {print sum+0}')

    # Score calculation
    score=$((score + cksum_errors * 10))
    score=$((score + read_errors * 5))
    score=$((score + write_errors * 8))

    # Cap at 100
    [ $score -gt 100 ] && score=100

    echo "$score"
}

calculate_redundancy_score() {
    local pool=$1
    local score=0

    # Get pool health
    local health=$(zpool list -H -o health "$pool" 2>/dev/null || echo "UNAVAIL")

    case $health in
        "ONLINE")
            score=0
            ;;
        "DEGRADED")
            score=50
            ;;
        "FAULTED")
            score=90
            ;;
        "UNAVAIL")
            score=100
            ;;
    esac

    echo "$score"
}

calculate_overall_risk() {
    local hw_score=$1
    local integrity_score=$2
    local redundancy_score=$3
    local age_score=${4:-20}

    # Weighted calculation: HW(40%) + Integrity(30%) + Redundancy(20%) + Age(10%)
    local risk=$(awk "BEGIN {printf \"%.0f\", ($hw_score * 0.4) + ($integrity_score * 0.3) + ($redundancy_score * 0.2) + ($age_score * 0.1)}")

    echo "$risk"
}

################################################################################
# Diagnostic Phases
################################################################################

phase1_initial_assessment() {
    print_header "PHASE 1: INITIAL ASSESSMENT"

    print_section "System Status"
    echo "Hostname: $(hostname -f)"
    echo "Date: $(date)"
    echo "Uptime: $(uptime -p)"
    echo "System State: $(systemctl is-system-running 2>/dev/null || echo 'DEGRADED')"

    print_section "Block Device Overview"
    lsblk -o NAME,SIZE,TYPE,MOUNTPOINT,MODEL,STATE,PHY-SEC,LOG-SEC

    print_section "ZFS Pool Quick Status"
    if command -v zpool &>/dev/null; then
        zpool list -o name,health,size,allocated,free,fragmentation
        echo ""
        for pool in $(zpool list -H -o name 2>/dev/null); do
            echo "Pool: $pool"
            zpool status "$pool" | grep -E "(state:|errors:|READ|WRITE|CKSUM)" | head -10
            echo ""
        done
    else
        print_status "warn" "ZFS not available on this system"
    fi

    print_section "Recent Critical Kernel Errors"
    dmesg -T -l err,crit,alert,emerg 2>/dev/null | tail -20 || echo "No recent critical errors"

    print_section "I/O Error Summary"
    for disk in $(lsblk -d -o NAME -n | grep -E "^sd|^nvme"); do
        local error_count=$(dmesg | grep -c "/dev/$disk.*error" || echo "0")
        if [ "$error_count" -gt 0 ]; then
            print_status "warn" "/dev/$disk: $error_count I/O errors detected"
        fi
    done
}

phase2_hardware_diagnostics() {
    print_header "PHASE 2: HARDWARE DIAGNOSTICS"

    print_section "SMART Health Assessment"

    for disk in $(lsblk -d -o NAME -n | grep -E "^sd|^nvme"); do
        echo -e "\n${BLUE}━━━ /dev/$disk ━━━${NC}"

        # Overall health
        local health_status=$(smartctl -H /dev/$disk 2>/dev/null | grep "SMART overall-health" | awk '{print $NF}' || echo "UNKNOWN")
        if [ "$health_status" == "PASSED" ]; then
            print_status "ok" "SMART Health: PASSED"
        else
            print_status "error" "SMART Health: $health_status"
        fi

        # Key SMART attributes
        echo "Key Attributes:"
        smartctl -A /dev/$disk 2>/dev/null | grep -E "(^  5|^ 10|^188|^194|^197|^198|^199)" | \
            awk '{printf "  %-30s: %s\n", $2, $NF}' || echo "  No SMART data available"

        # Error log summary
        local error_count=$(smartctl -l error /dev/$disk 2>/dev/null | grep -c "Error " || echo "0")
        if [ "$error_count" -gt 0 ]; then
            print_status "warn" "Error log entries: $error_count"
            smartctl -l error /dev/$disk 2>/dev/null | head -10
        fi

        # NVMe specific checks
        if [[ $disk == nvme* ]]; then
            echo "NVMe Specific:"
            nvme smart-log /dev/$disk 2>/dev/null | grep -E "(percentage_used|available_spare|critical_warning)" || echo "  NVMe data unavailable"
        fi
    done

    print_section "Disk I/O Statistics"
    iostat -x 2 3 2>/dev/null | grep -E "(Device|sd|nvme)" || echo "iostat not available"

    print_section "Temperature Monitoring"
    for disk in $(lsblk -d -o NAME -n | grep -E "^sd|^nvme"); do
        local temp=$(smartctl -A /dev/$disk 2>/dev/null | grep "Temperature_Celsius" | awk '{print $NF}' || echo "N/A")
        if [ "$temp" != "N/A" ]; then
            if [ "$temp" -gt 65 ]; then
                print_status "error" "/dev/$disk: ${temp}°C (CRITICAL)"
            elif [ "$temp" -gt 55 ]; then
                print_status "warn" "/dev/$disk: ${temp}°C (WARNING)"
            else
                print_status "ok" "/dev/$disk: ${temp}°C"
            fi
        fi
    done
}

phase3_zfs_integrity() {
    print_header "PHASE 3: ZFS DATA INTEGRITY ANALYSIS"

    if ! command -v zpool &>/dev/null; then
        print_status "warn" "ZFS not installed, skipping phase 3"
        return
    fi

    print_section "Detailed Pool Status"

    for pool in $(zpool list -H -o name 2>/dev/null); do
        echo -e "\n${BLUE}╔═══ Pool: $pool ═══╗${NC}"
        zpool status -v "$pool"

        echo -e "\n${BLUE}Pool Properties:${NC}"
        zpool get health,allocated,fragmentation,dedupratio "$pool" | column -t

        # Check for errors
        local total_errors=$(zpool status "$pool" | grep "errors:" | grep -v "No known data errors" | wc -l)
        if [ "$total_errors" -gt 0 ]; then
            print_status "error" "Pool $pool has data errors!"
            zpool status "$pool" | grep -A 5 "errors:"
        fi
    done

    print_section "ZFS Event Log Analysis"
    echo "Recent ZFS events (last 50):"
    zpool events 2>/dev/null | tail -50 | grep -E "(ereport|checksum|io|raid)" || echo "No significant events"

    print_section "Scrub History"
    for pool in $(zpool list -H -o name 2>/dev/null); do
        echo "Pool: $pool"
        zpool history "$pool" 2>/dev/null | grep scrub | tail -3 || echo "  No scrub history"
    done
}

phase4_performance_assessment() {
    print_header "PHASE 4: PERFORMANCE IMPACT ASSESSMENT"

    print_section "Current I/O Load"
    iostat -xm 1 3 2>/dev/null || echo "iostat not available"

    print_section "Disk Latency Analysis"
    for disk in $(lsblk -d -o NAME -n | grep -E "^sd|^nvme"); do
        echo "Device: /dev/$disk"
        iostat -dx /dev/$disk 1 3 2>/dev/null | grep "$disk" | \
            awk '{sum+=$10} END {if(NR>0) printf "  Average await: %.2f ms\n", sum/NR}'
    done

    print_section "VM/Container Storage Impact"
    if command -v pvesh &>/dev/null; then
        pvesh get /cluster/resources --type vm --output-format json 2>/dev/null | \
            jq -r '.[] | select(.status=="running") | "VMID \(.vmid): \(.name) - Disk: \(.disk/1073741824)GB"' || \
            echo "Unable to query VM resources"
    else
        echo "Proxmox API not available"
    fi
}

phase5_data_loss_risk() {
    print_header "PHASE 5: DATA LOSS RISK EVALUATION"

    print_section "Redundancy Status Assessment"

    if command -v zpool &>/dev/null; then
        for pool in $(zpool list -H -o name 2>/dev/null); do
            echo -e "\n${BLUE}Pool: $pool${NC}"

            # Determine RAID type
            local raid_type=$(zpool status "$pool" | grep -oE "(mirror|raidz[0-9]?|stripe)" | head -1 || echo "unknown")
            echo "RAID Type: $raid_type"

            # Check health
            local health=$(zpool list -H -o health "$pool")
            echo "Health: $health"

            # Count failed devices
            local failed_count=$(zpool status "$pool" | grep -c "UNAVAIL\|FAULTED\|DEGRADED" || echo "0")
            if [ "$failed_count" -gt 0 ]; then
                print_status "error" "$failed_count device(s) in failed/degraded state"
            else
                print_status "ok" "All devices healthy"
            fi

            # Calculate fault tolerance
            case $raid_type in
                "mirror")
                    print_status "info" "Fault tolerance: Can lose 1 disk per mirror"
                    ;;
                "raidz1")
                    print_status "info" "Fault tolerance: Can lose 1 disk"
                    ;;
                "raidz2")
                    print_status "info" "Fault tolerance: Can lose 2 disks"
                    ;;
                "raidz3")
                    print_status "info" "Fault tolerance: Can lose 3 disks"
                    ;;
                "stripe")
                    print_status "error" "NO FAULT TOLERANCE - Any disk failure causes data loss"
                    ;;
            esac
        done
    fi

    print_section "Snapshot Inventory (Recovery Points)"
    if command -v zfs &>/dev/null; then
        for pool in $(zpool list -H -o name 2>/dev/null); do
            local snap_count=$(zfs list -t snapshot -o name 2>/dev/null | grep "^$pool" | wc -l)
            echo "Pool $pool: $snap_count snapshots"
            if [ "$snap_count" -gt 0 ]; then
                echo "Most recent snapshots:"
                zfs list -t snapshot -o name,creation,used 2>/dev/null | grep "^$pool" | tail -5
            fi
        done
    fi

    print_section "Backup Verification Status"
    if [ -d "/var/lib/vz/dump" ]; then
        echo "Recent VM backups:"
        ls -lth /var/lib/vz/dump/*.{vma,tar}* 2>/dev/null | head -10 || echo "No backups found in default location"
    fi
}

phase6_comprehensive_report() {
    print_header "PHASE 6: COMPREHENSIVE DIAGNOSTIC REPORT"

    local total_risk=0
    local critical_count=0
    local warning_count=0
    local healthy_count=0

    print_section "Executive Summary"

    # System health calculation
    if command -v zpool &>/dev/null; then
        local total_pools=$(zpool list -H 2>/dev/null | wc -l)
        local healthy_pools=$(zpool list -H -o health 2>/dev/null | grep -c "ONLINE" || echo "0")
        echo "ZFS Pools: $healthy_pools/$total_pools healthy"
    fi

    local total_disks=$(lsblk -d 2>/dev/null | grep -c "disk" || echo "0")
    local failed_disks=0

    print_section "Per-Disk Risk Analysis"
    printf "%-15s %-12s %-12s %-12s %-15s\n" "Device" "HW Score" "Risk Level" "SMART" "Recommendation"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    for disk in $(lsblk -d -o NAME -n 2>/dev/null | grep -E "^sd|^nvme"); do
        local hw_score=$(calculate_hardware_score "$disk")
        local smart_status=$(smartctl -H /dev/$disk 2>/dev/null | grep "SMART overall-health" | awk '{print $NF}' || echo "UNKNOWN")

        local risk_level recommendation
        if [ "$hw_score" -lt 20 ]; then
            risk_level="${GREEN}MINIMAL${NC}"
            recommendation="Monitor"
            ((healthy_count++))
        elif [ "$hw_score" -lt 40 ]; then
            risk_level="${GREEN}LOW${NC}"
            recommendation="Plan replacement"
            ((healthy_count++))
        elif [ "$hw_score" -lt 60 ]; then
            risk_level="${YELLOW}MODERATE${NC}"
            recommendation="Schedule maintenance"
            ((warning_count++))
        elif [ "$hw_score" -lt 80 ]; then
            risk_level="${RED}HIGH${NC}"
            recommendation="Urgent replacement"
            ((critical_count++))
        else
            risk_level="${RED}CRITICAL${NC}"
            recommendation="EMERGENCY - Replace NOW"
            ((critical_count++))
            ((failed_disks++))
        fi

        printf "%-15s %-12s %b %-12s %-15s\n" "/dev/$disk" "$hw_score" "$risk_level" "$smart_status" "$recommendation"
        total_risk=$((total_risk + hw_score))
    done

    # Calculate average risk
    if [ "$total_disks" -gt 0 ]; then
        local avg_risk=$((total_risk / total_disks))
    else
        local avg_risk=0
    fi

    print_section "Overall Risk Assessment"
    echo "Total Disks: $total_disks"
    echo "Failed/Critical: $failed_disks"
    echo "Warnings: $warning_count"
    echo "Healthy: $healthy_count"
    echo ""
    echo "Average Risk Score: $avg_risk/100"

    if [ "$avg_risk" -lt 20 ]; then
        print_status "ok" "Risk Level: MINIMAL - Continue monitoring"
    elif [ "$avg_risk" -lt 40 ]; then
        print_status "info" "Risk Level: LOW - Plan proactive replacement"
    elif [ "$avg_risk" -lt 60 ]; then
        print_status "warn" "Risk Level: MODERATE - Schedule maintenance window"
    elif [ "$avg_risk" -lt 80 ]; then
        print_status "error" "Risk Level: HIGH - Urgent intervention required"
    else
        print_status "error" "Risk Level: CRITICAL - Emergency response required"
    fi

    print_section "Recommended Actions (Priority Order)"

    if [ "$avg_risk" -ge 60 ] || [ "$critical_count" -gt 0 ]; then
        echo "🔴 IMMEDIATE (0-2 hours):"
        echo "   1. Create emergency ZFS snapshots"
        echo "   2. Verify backup integrity"
        echo "   3. Stop non-critical VMs/containers"
        echo "   4. Order replacement hardware"
        echo ""
        echo "🟡 URGENT (2-24 hours):"
        echo "   1. Schedule emergency maintenance window"
        echo "   2. Prepare for disk replacement"
        echo "   3. Notify affected users"
        echo "   4. Test recovery procedures"
    elif [ "$avg_risk" -ge 40 ]; then
        echo "🟡 HIGH PRIORITY (24-72 hours):"
        echo "   1. Schedule maintenance window"
        echo "   2. Order replacement disks"
        echo "   3. Verify backups"
        echo "   4. Plan migration if needed"
    else
        echo "🟢 ROUTINE (7-30 days):"
        echo "   1. Continue monitoring"
        echo "   2. Plan proactive replacement"
        echo "   3. Verify backup schedules"
        echo "   4. Review capacity planning"
    fi

    print_section "Report Summary"
    echo "Full diagnostic report saved to: $REPORT_FILE"
    echo "Generated on: $(date)"
    echo "Next recommended check: $(date -d '+7 days' '+%Y-%m-%d')"
}

################################################################################
# Main Execution
################################################################################

main() {
    # Check if running as root
    if [ "$EUID" -ne 0 ]; then
        echo -e "${RED}ERROR: This script must be run as root${NC}"
        exit 1
    fi

    # Check for required commands
    local missing_cmds=()
    for cmd in smartctl lsblk iostat; do
        if ! command -v "$cmd" &>/dev/null; then
            missing_cmds+=("$cmd")
        fi
    done

    if [ ${#missing_cmds[@]} -gt 0 ]; then
        echo -e "${YELLOW}WARNING: Missing commands: ${missing_cmds[*]}${NC}"
        echo "Install with: apt-get install smartmontools sysstat"
    fi

    # Banner
    clear
    cat << "EOF"
╔══════════════════════════════════════════════════════════════════╗
║                                                                  ║
║          DISK FAILURE DIAGNOSTIC SUITE v1.0                      ║
║          Proxmox Infrastructure Analysis                         ║
║                                                                  ║
║          Target Host: 100.98.119.51                              ║
║                                                                  ║
╚══════════════════════════════════════════════════════════════════╝
EOF

    echo ""
    print_status "info" "Starting comprehensive disk diagnostics..."
    print_status "info" "Report will be saved to: $REPORT_FILE"
    echo ""

    # Execute diagnostic phases
    {
        phase1_initial_assessment
        phase2_hardware_diagnostics
        phase3_zfs_integrity
        phase4_performance_assessment
        phase5_data_loss_risk
        phase6_comprehensive_report
    } | tee "$REPORT_FILE"

    # Final summary
    echo ""
    print_header "DIAGNOSTIC SUITE COMPLETE"
    print_status "ok" "Full report available at: $REPORT_FILE"
    print_status "info" "Review the report and follow recommended actions"
    echo ""
}

# Script entry point
if [ "${BASH_SOURCE[0]}" == "${0}" ]; then
    main "$@"
fi
