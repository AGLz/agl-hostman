#!/bin/bash
################################################################################
# Disk Forensic Analyzer - Main Diagnostic Orchestrator
# Target: Proxmox Host 100.98.119.51
# Purpose: Master script coordinating all diagnostic operations
# Mode: READ-ONLY by default, requires explicit confirmation for any changes
################################################################################

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="/var/log/disk-forensics"
REPORT_DIR="/root/forensic-reports"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_FILE="${LOG_DIR}/forensic_analyzer_${TIMESTAMP}.log"
REPORT_FILE="${REPORT_DIR}/diagnostic_report_${TIMESTAMP}.json"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Ensure directories exist
mkdir -p "${LOG_DIR}" "${REPORT_DIR}"

################################################################################
# Logging Functions
################################################################################

log() {
    local level=$1
    shift
    local message="$*"
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] [${level}] ${message}" | tee -a "${LOG_FILE}"
}

log_info() { log "INFO" "$@"; }
log_warn() { log "WARN" "$@"; }
log_error() { log "ERROR" "$@"; }
log_success() { log "SUCCESS" "$@"; }

print_header() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
}

print_section() {
    echo -e "\n${GREEN}>>> $1${NC}\n"
}

################################################################################
# System Information Collection
################################################################################

collect_system_info() {
    print_section "Collecting System Information"

    cat > "${REPORT_DIR}/system_info_${TIMESTAMP}.json" <<EOF
{
    "timestamp": "$(date -Iseconds)",
    "hostname": "$(hostname)",
    "kernel": "$(uname -r)",
    "os_version": "$(cat /etc/os-release | grep PRETTY_NAME | cut -d= -f2 | tr -d '\"')",
    "uptime": "$(uptime -p)",
    "boot_time": "$(who -b | awk '{print $3, $4}')",
    "current_user": "$(whoami)",
    "load_average": "$(uptime | awk -F'load average:' '{print $2}')"
}
EOF

    log_info "System info collected: ${REPORT_DIR}/system_info_${TIMESTAMP}.json"
}

################################################################################
# Disk Enumeration
################################################################################

enumerate_disks() {
    print_section "Enumerating All Disks"

    log_info "Collecting block device information..."
    lsblk -J -o NAME,SIZE,TYPE,MOUNTPOINT,FSTYPE,MODEL,SERIAL,STATE,PHY-SEC > \
        "${REPORT_DIR}/block_devices_${TIMESTAMP}.json"

    log_info "Collecting disk by-id information..."
    ls -la /dev/disk/by-id/ 2>/dev/null > "${REPORT_DIR}/disk_by_id_${TIMESTAMP}.txt" || \
        log_warn "Could not access /dev/disk/by-id/"

    log_info "Detecting NVMe devices..."
    if ls /dev/nvme* >/dev/null 2>&1; then
        nvme list -o json > "${REPORT_DIR}/nvme_devices_${TIMESTAMP}.json" 2>/dev/null || \
            log_warn "nvme-cli not installed or nvme list failed"
    else
        log_info "No NVMe devices detected"
    fi

    log_success "Disk enumeration complete"
}

################################################################################
# Execute Diagnostic Scripts
################################################################################

run_smart_diagnostics() {
    print_section "Running SMART Health Checks"

    if [[ -x "${SCRIPT_DIR}/smart_health_check.sh" ]]; then
        log_info "Executing SMART diagnostics..."
        "${SCRIPT_DIR}/smart_health_check.sh" || log_error "SMART diagnostics failed"
    else
        log_warn "SMART health check script not found or not executable"
    fi
}

run_zfs_diagnostics() {
    print_section "Running ZFS Pool Analysis"

    if command -v zpool >/dev/null 2>&1; then
        if [[ -x "${SCRIPT_DIR}/zfs_pool_analyzer.sh" ]]; then
            log_info "Executing ZFS pool analysis..."
            "${SCRIPT_DIR}/zfs_pool_analyzer.sh" || log_error "ZFS analysis failed"
        else
            log_warn "ZFS pool analyzer script not found or not executable"
        fi
    else
        log_info "ZFS not installed, skipping ZFS diagnostics"
    fi
}

run_forensic_collection() {
    print_section "Running Forensic Data Collection"

    if [[ -x "${SCRIPT_DIR}/forensic_collector.sh" ]]; then
        log_info "Executing forensic data collection..."
        "${SCRIPT_DIR}/forensic_collector.sh" || log_error "Forensic collection failed"
    else
        log_warn "Forensic collector script not found or not executable"
    fi
}

################################################################################
# Health Status Assessment
################################################################################

assess_overall_health() {
    print_section "Assessing Overall System Health"

    local health_status="UNKNOWN"
    local critical_issues=0
    local warnings=0

    # Check for failed services
    if systemctl is-system-running | grep -qE "(degraded|maintenance)"; then
        ((critical_issues++))
        log_warn "System is in degraded state"
    fi

    # Check disk space
    while IFS= read -r line; do
        usage=$(echo "$line" | awk '{print $5}' | sed 's/%//')
        if [[ $usage -gt 90 ]]; then
            ((critical_issues++))
            log_warn "Disk usage critical: $line"
        elif [[ $usage -gt 80 ]]; then
            ((warnings++))
            log_warn "Disk usage high: $line"
        fi
    done < <(df -h | grep -vE "(tmpfs|devtmpfs|Filesystem)")

    # Determine overall status
    if [[ $critical_issues -gt 0 ]]; then
        health_status="CRITICAL"
    elif [[ $warnings -gt 0 ]]; then
        health_status="WARNING"
    else
        health_status="HEALTHY"
    fi

    cat > "${REPORT_DIR}/health_assessment_${TIMESTAMP}.json" <<EOF
{
    "timestamp": "$(date -Iseconds)",
    "overall_status": "${health_status}",
    "critical_issues": ${critical_issues},
    "warnings": ${warnings},
    "diagnostics_completed": true
}
EOF

    case $health_status in
        CRITICAL)
            echo -e "${RED}OVERALL HEALTH: CRITICAL${NC}"
            ;;
        WARNING)
            echo -e "${YELLOW}OVERALL HEALTH: WARNING${NC}"
            ;;
        HEALTHY)
            echo -e "${GREEN}OVERALL HEALTH: HEALTHY${NC}"
            ;;
    esac

    log_info "Health assessment: ${health_status} (Critical: ${critical_issues}, Warnings: ${warnings})"
}

################################################################################
# Generate Recovery Plan
################################################################################

generate_recovery_plan() {
    print_section "Generating Recovery Action Plan"

    if [[ -x "${SCRIPT_DIR}/recovery_planner.sh" ]]; then
        log_info "Executing recovery planner..."
        "${SCRIPT_DIR}/recovery_planner.sh" || log_error "Recovery planning failed"
    else
        log_warn "Recovery planner script not found or not executable"
    fi
}

################################################################################
# Report Generation
################################################################################

generate_consolidated_report() {
    print_section "Generating Consolidated Report"

    local report_html="${REPORT_DIR}/forensic_report_${TIMESTAMP}.html"

    cat > "${report_html}" <<'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Disk Forensic Analysis Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        h1 { color: #2c3e50; }
        h2 { color: #34495e; border-bottom: 2px solid #3498db; padding-bottom: 5px; }
        .critical { color: #e74c3c; font-weight: bold; }
        .warning { color: #f39c12; font-weight: bold; }
        .success { color: #27ae60; font-weight: bold; }
        .info-box { background: #ecf0f1; padding: 10px; margin: 10px 0; border-radius: 5px; }
        pre { background: #2c3e50; color: #ecf0f1; padding: 10px; border-radius: 5px; overflow-x: auto; }
        table { border-collapse: collapse; width: 100%; margin: 10px 0; }
        th, td { border: 1px solid #bdc3c7; padding: 8px; text-align: left; }
        th { background: #34495e; color: white; }
    </style>
</head>
<body>
EOF

    cat >> "${report_html}" <<EOF
    <h1>Disk Forensic Analysis Report</h1>
    <div class="info-box">
        <strong>Generated:</strong> $(date)<br>
        <strong>Host:</strong> $(hostname)<br>
        <strong>Report ID:</strong> ${TIMESTAMP}
    </div>

    <h2>Executive Summary</h2>
    <p>This report contains comprehensive disk forensic analysis for Proxmox host 100.98.119.51.</p>

    <h2>Available Reports</h2>
    <ul>
        <li><a href="system_info_${TIMESTAMP}.json">System Information (JSON)</a></li>
        <li><a href="block_devices_${TIMESTAMP}.json">Block Devices (JSON)</a></li>
        <li><a href="health_assessment_${TIMESTAMP}.json">Health Assessment (JSON)</a></li>
    </ul>

    <h2>Log Files</h2>
    <p>Detailed execution log: <code>${LOG_FILE}</code></p>

    <h2>Next Steps</h2>
    <ol>
        <li>Review health assessment for critical issues</li>
        <li>Examine SMART data for disk failures</li>
        <li>Check ZFS pool status if applicable</li>
        <li>Execute recovery plan if issues detected</li>
    </ol>
</body>
</html>
EOF

    log_success "HTML report generated: ${report_html}"
    echo -e "\n${GREEN}Consolidated report available at:${NC}"
    echo -e "${BLUE}${report_html}${NC}"
}

################################################################################
# Main Execution Flow
################################################################################

main() {
    print_header "DISK FORENSIC ANALYZER v1.0"

    log_info "Starting forensic analysis session: ${TIMESTAMP}"
    log_info "Log file: ${LOG_FILE}"
    log_info "Report directory: ${REPORT_DIR}"

    echo -e "${YELLOW}Mode: READ-ONLY (No modifications will be made)${NC}\n"

    # Execute diagnostic phases
    collect_system_info
    enumerate_disks
    run_smart_diagnostics
    run_zfs_diagnostics
    run_forensic_collection
    assess_overall_health
    generate_recovery_plan
    generate_consolidated_report

    print_header "FORENSIC ANALYSIS COMPLETE"

    log_success "All diagnostics completed successfully"
    echo -e "\n${GREEN}All reports saved to:${NC} ${REPORT_DIR}"
    echo -e "${GREEN}Execution log:${NC} ${LOG_FILE}"

    # Summary
    echo -e "\n${BLUE}Quick Access Commands:${NC}"
    echo "  View log:    tail -f ${LOG_FILE}"
    echo "  List reports: ls -lh ${REPORT_DIR}/*${TIMESTAMP}*"
    echo "  View health:  cat ${REPORT_DIR}/health_assessment_${TIMESTAMP}.json | jq ."
}

# Execute main function
main "$@"
