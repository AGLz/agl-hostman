#!/bin/bash
################################################################################
# Recovery Action Planner
# Purpose: Analyze diagnostic data and generate recovery action plans
# Safety: Generates plans only, requires explicit confirmation for execution
################################################################################

set -euo pipefail

# Configuration
REPORT_DIR="/root/forensic-reports"
FORENSIC_DIR="/root/forensic-data"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
PLAN_FILE="${REPORT_DIR}/recovery_plan_${TIMESTAMP}.json"
SCRIPT_FILE="${REPORT_DIR}/recovery_actions_${TIMESTAMP}.sh"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
NC='\033[0m'

mkdir -p "${REPORT_DIR}"

################################################################################
# Recovery Plan Structure
################################################################################

RECOVERY_ACTIONS=()
CRITICAL_ACTIONS=()
PREVENTIVE_ACTIONS=()
RISK_LEVEL="UNKNOWN"

################################################################################
# Analysis Functions
################################################################################

analyze_smart_data() {
    echo -e "${BLUE}Analyzing SMART data...${NC}"

    local latest_smart=$(ls -t "${REPORT_DIR}"/smart_analysis_*.json 2>/dev/null | head -1)

    if [[ -z "$latest_smart" ]]; then
        echo -e "${YELLOW}No SMART data found${NC}"
        return
    fi

    if command -v jq >/dev/null 2>&1; then
        local critical_count=$(jq -r '.summary.critical_issues // 0' "$latest_smart" 2>/dev/null || echo "0")

        if [[ "$critical_count" -gt 0 ]]; then
            CRITICAL_ACTIONS+=("SMART_CRITICAL: ${critical_count} disk(s) with critical SMART issues")
            CRITICAL_ACTIONS+=("ACTION: Identify failed disks and plan replacement")
            CRITICAL_ACTIONS+=("ACTION: Backup critical data immediately before disk failure")
            RISK_LEVEL="CRITICAL"
        fi

        # Extract specific issues
        while IFS= read -r device; do
            local health=$(jq -r ".devices[] | select(.device==\"$device\") | .health_status" "$latest_smart" 2>/dev/null || echo "UNKNOWN")

            if [[ "$health" == "FAILED" ]]; then
                CRITICAL_ACTIONS+=("DISK_FAILURE: $device has FAILED SMART status")
                CRITICAL_ACTIONS+=("ACTION: Replace $device immediately")
            fi
        done < <(jq -r '.devices[].device' "$latest_smart" 2>/dev/null || true)
    fi

    echo -e "${GREEN}SMART analysis complete${NC}"
}

analyze_zfs_health() {
    echo -e "${BLUE}Analyzing ZFS health...${NC}"

    local latest_zfs=$(ls -t "${REPORT_DIR}"/zfs_analysis_*.json 2>/dev/null | head -1)

    if [[ -z "$latest_zfs" ]]; then
        echo -e "${YELLOW}No ZFS data found${NC}"
        return
    fi

    if command -v jq >/dev/null 2>&1; then
        local critical_count=$(jq -r '.summary.critical_issues // 0' "$latest_zfs" 2>/dev/null || echo "0")

        if [[ "$critical_count" -gt 0 ]]; then
            CRITICAL_ACTIONS+=("ZFS_CRITICAL: ${critical_count} pool(s) require attention")

            # Extract pool-specific issues
            while IFS= read -r pool; do
                local health=$(jq -r ".pools[] | select(.analysis.pool==\"$pool\") | .analysis.health" "$latest_zfs" 2>/dev/null || echo "UNKNOWN")
                local capacity=$(jq -r ".pools[] | select(.analysis.pool==\"$pool\") | .analysis.capacity" "$latest_zfs" 2>/dev/null || echo "0%")

                case "$health" in
                    DEGRADED)
                        CRITICAL_ACTIONS+=("ZFS_DEGRADED: Pool '$pool' is degraded")
                        CRITICAL_ACTIONS+=("ACTION: Check 'zpool status -v $pool' for failed devices")
                        CRITICAL_ACTIONS+=("ACTION: Replace failed device and resilver: zpool replace $pool <old_device> <new_device>")
                        [[ "$RISK_LEVEL" != "CRITICAL" ]] && RISK_LEVEL="HIGH"
                        ;;
                    FAULTED|UNAVAIL)
                        CRITICAL_ACTIONS+=("ZFS_FAULTED: Pool '$pool' is faulted or unavailable")
                        CRITICAL_ACTIONS+=("ACTION: Attempt import: zpool import -f $pool")
                        CRITICAL_ACTIONS+=("ACTION: If import fails, restore from backup")
                        RISK_LEVEL="CRITICAL"
                        ;;
                esac

                # Check capacity
                local cap_num=${capacity%\%}
                if [[ "$cap_num" -ge 90 ]]; then
                    CRITICAL_ACTIONS+=("ZFS_CAPACITY: Pool '$pool' at ${capacity} capacity")
                    CRITICAL_ACTIONS+=("ACTION: Free space immediately - delete snapshots or old data")
                    CRITICAL_ACTIONS+=("ACTION: Consider: zfs destroy $pool/dataset@old_snapshot")
                    [[ "$RISK_LEVEL" != "CRITICAL" ]] && RISK_LEVEL="HIGH"
                fi
            done < <(jq -r '.pools[].analysis.pool' "$latest_zfs" 2>/dev/null || true)
        fi
    fi

    echo -e "${GREEN}ZFS analysis complete${NC}"
}

analyze_disk_space() {
    echo -e "${BLUE}Analyzing disk space...${NC}"

    while IFS= read -r line; do
        local usage=$(echo "$line" | awk '{print $5}' | sed 's/%//')
        local mount=$(echo "$line" | awk '{print $6}')
        local size=$(echo "$line" | awk '{print $2}')

        if [[ "$usage" -ge 95 ]]; then
            CRITICAL_ACTIONS+=("DISK_FULL: ${mount} at ${usage}% (${size} total)")
            CRITICAL_ACTIONS+=("ACTION: Free space immediately on ${mount}")
            [[ "$RISK_LEVEL" != "CRITICAL" ]] && RISK_LEVEL="HIGH"
        elif [[ "$usage" -ge 85 ]]; then
            RECOVERY_ACTIONS+=("DISK_HIGH: ${mount} at ${usage}% (${size} total)")
            RECOVERY_ACTIONS+=("ACTION: Plan cleanup for ${mount}")
        fi
    done < <(df -h | grep -vE "(tmpfs|devtmpfs|Filesystem)" || true)

    echo -e "${GREEN}Disk space analysis complete${NC}"
}

analyze_system_state() {
    echo -e "${BLUE}Analyzing system state...${NC}"

    # Check for degraded services
    if systemctl is-system-running 2>/dev/null | grep -qE "(degraded|maintenance)"; then
        RECOVERY_ACTIONS+=("SYSTEM_DEGRADED: System is in degraded state")
        RECOVERY_ACTIONS+=("ACTION: Check failed services: systemctl --failed")
    fi

    # Check for failed services
    local failed_services=$(systemctl --failed --no-legend 2>/dev/null | wc -l)
    if [[ "$failed_services" -gt 0 ]]; then
        RECOVERY_ACTIONS+=("SERVICES_FAILED: ${failed_services} service(s) failed")
        RECOVERY_ACTIONS+=("ACTION: Review and restart failed services")
    fi

    echo -e "${GREEN}System state analysis complete${NC}"
}

generate_preventive_actions() {
    echo -e "${BLUE}Generating preventive recommendations...${NC}"

    PREVENTIVE_ACTIONS+=(
        "BACKUP: Verify backup strategy is in place"
        "BACKUP: Test restore procedures regularly"
        "MONITORING: Set up disk space alerts (80% threshold)"
        "MONITORING: Configure SMART monitoring with email alerts"
        "MONITORING: Enable ZFS scrub scheduling (monthly recommended)"
        "MAINTENANCE: Schedule regular ZFS scrubs: zpool scrub <pool>"
        "MAINTENANCE: Review and clean old snapshots quarterly"
        "MAINTENANCE: Monitor disk health trends weekly"
        "DOCUMENTATION: Document current system configuration"
        "DOCUMENTATION: Create runbooks for common recovery scenarios"
    )

    echo -e "${GREEN}Preventive recommendations generated${NC}"
}

################################################################################
# Plan Generation
################################################################################

generate_json_plan() {
    echo -e "${BLUE}Generating JSON recovery plan...${NC}"

    cat > "${PLAN_FILE}" <<EOF
{
    "plan_timestamp": "$(date -Iseconds)",
    "hostname": "$(hostname)",
    "risk_level": "${RISK_LEVEL}",
    "critical_actions": [
$(printf '        "%s",\n' "${CRITICAL_ACTIONS[@]}" | sed '$ s/,$//')
    ],
    "recovery_actions": [
$(printf '        "%s",\n' "${RECOVERY_ACTIONS[@]}" | sed '$ s/,$//')
    ],
    "preventive_actions": [
$(printf '        "%s",\n' "${PREVENTIVE_ACTIONS[@]}" | sed '$ s/,$//')
    ],
    "execution_notes": {
        "safety": "All actions require explicit confirmation before execution",
        "priority": "Address critical actions first, then recovery, then preventive",
        "validation": "Verify each action success before proceeding to next",
        "backup": "Ensure backups exist before making any changes",
        "documentation": "Document all actions taken and results"
    }
}
EOF

    echo -e "${GREEN}JSON plan created: ${PLAN_FILE}${NC}"
}

generate_executable_script() {
    echo -e "${BLUE}Generating executable recovery script...${NC}"

    cat > "${SCRIPT_FILE}" <<'SCRIPT_HEADER'
#!/bin/bash
################################################################################
# AUTO-GENERATED RECOVERY ACTION SCRIPT
# WARNING: Review carefully before execution
# Generated by: recovery_planner.sh
################################################################################

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

LOG_FILE="/var/log/recovery_execution_$(date +%Y%m%d_%H%M%S).log"

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*" | tee -a "${LOG_FILE}"
}

confirm() {
    local action=$1
    echo -e "${YELLOW}About to execute: ${action}${NC}"
    read -p "Confirm execution? (yes/no): " response
    if [[ "$response" != "yes" ]]; then
        log "ACTION SKIPPED: ${action}"
        return 1
    fi
    log "ACTION CONFIRMED: ${action}"
    return 0
}

execute_safe() {
    local description=$1
    shift
    local command="$*"

    if confirm "${description}"; then
        log "EXECUTING: ${command}"
        if eval "${command}"; then
            log "SUCCESS: ${description}"
            echo -e "${GREEN}✓ ${description}${NC}"
        else
            log "FAILED: ${description}"
            echo -e "${RED}✗ ${description} - FAILED${NC}"
            return 1
        fi
    fi
}

SCRIPT_HEADER

    cat >> "${SCRIPT_FILE}" <<EOF

echo "=========================================="
echo "RECOVERY ACTION EXECUTION"
echo "Generated: $(date)"
echo "Risk Level: ${RISK_LEVEL}"
echo "=========================================="
echo ""
echo -e "\${YELLOW}This script contains ${#CRITICAL_ACTIONS[@]} critical action(s)\${NC}"
echo -e "\${YELLOW}Each action requires explicit confirmation\${NC}"
echo ""

log "Recovery execution started"

EOF

    # Add critical actions
    if [[ ${#CRITICAL_ACTIONS[@]} -gt 0 ]]; then
        cat >> "${SCRIPT_FILE}" <<'EOF'
echo "=========================================="
echo "CRITICAL ACTIONS"
echo "=========================================="
echo ""

EOF

        for action in "${CRITICAL_ACTIONS[@]}"; do
            if [[ "$action" =~ ^ACTION: ]]; then
                local cmd=${action#ACTION: }
                cat >> "${SCRIPT_FILE}" <<EOF
# ${action}
execute_safe "${cmd}" "${cmd}" || true
echo ""

EOF
            else
                cat >> "${SCRIPT_FILE}" <<EOF
echo -e "\${RED}${action}\${NC}"

EOF
            fi
        done
    fi

    # Add recovery actions
    if [[ ${#RECOVERY_ACTIONS[@]} -gt 0 ]]; then
        cat >> "${SCRIPT_FILE}" <<'EOF'
echo "=========================================="
echo "RECOVERY ACTIONS"
echo "=========================================="
echo ""

EOF

        for action in "${RECOVERY_ACTIONS[@]}"; do
            if [[ "$action" =~ ^ACTION: ]]; then
                local cmd=${action#ACTION: }
                cat >> "${SCRIPT_FILE}" <<EOF
# ${action}
execute_safe "${cmd}" "${cmd}" || true
echo ""

EOF
            else
                cat >> "${SCRIPT_FILE}" <<EOF
echo -e "\${YELLOW}${action}\${NC}"

EOF
            fi
        done
    fi

    cat >> "${SCRIPT_FILE}" <<'EOF'

echo "=========================================="
echo "RECOVERY EXECUTION COMPLETE"
echo "=========================================="
echo ""
log "Recovery execution completed"
echo -e "${GREEN}Execution log: ${LOG_FILE}${NC}"
EOF

    chmod +x "${SCRIPT_FILE}"
    echo -e "${GREEN}Executable script created: ${SCRIPT_FILE}${NC}"
}

generate_html_report() {
    local html_file="${REPORT_DIR}/recovery_plan_${TIMESTAMP}.html"

    cat > "${html_file}" <<'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Recovery Action Plan</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; background: #f5f5f5; }
        .container { max-width: 1200px; margin: 0 auto; background: white; padding: 20px; border-radius: 8px; }
        h1 { color: #2c3e50; border-bottom: 3px solid #3498db; padding-bottom: 10px; }
        h2 { color: #34495e; margin-top: 30px; }
        .risk-critical { color: #e74c3c; font-weight: bold; font-size: 1.2em; }
        .risk-high { color: #e67e22; font-weight: bold; }
        .risk-medium { color: #f39c12; font-weight: bold; }
        .risk-low { color: #27ae60; font-weight: bold; }
        .action-box { background: #ecf0f1; padding: 15px; margin: 10px 0; border-left: 4px solid #3498db; border-radius: 4px; }
        .critical-box { background: #fadbd8; border-left-color: #e74c3c; }
        .warning-box { background: #fdebd0; border-left-color: #f39c12; }
        .info-box { background: #d6eaf8; border-left-color: #3498db; }
        .action-item { margin: 8px 0; padding: 8px; background: white; border-radius: 4px; }
        .command { font-family: monospace; background: #2c3e50; color: #ecf0f1; padding: 10px; border-radius: 4px; margin: 5px 0; }
        .timestamp { color: #7f8c8d; font-size: 0.9em; }
        ul { list-style-type: none; padding: 0; }
        li:before { content: "▶ "; color: #3498db; font-weight: bold; }
    </style>
</head>
<body>
    <div class="container">
EOF

    cat >> "${html_file}" <<EOF
        <h1>Recovery Action Plan</h1>
        <div class="info-box">
            <strong>Generated:</strong> $(date)<br>
            <strong>Hostname:</strong> $(hostname)<br>
            <strong>Plan ID:</strong> ${TIMESTAMP}<br>
            <strong>Risk Level:</strong> <span class="risk-${RISK_LEVEL,,}">${RISK_LEVEL}</span>
        </div>

        <h2>Critical Actions (${#CRITICAL_ACTIONS[@]})</h2>
        <div class="critical-box action-box">
EOF

    for action in "${CRITICAL_ACTIONS[@]}"; do
        if [[ "$action" =~ ^ACTION: ]]; then
            echo "            <div class=\"action-item\"><strong>→</strong> ${action#ACTION: }</div>" >> "${html_file}"
        else
            echo "            <div class=\"action-item\"><strong>⚠</strong> ${action}</div>" >> "${html_file}"
        fi
    done

    cat >> "${html_file}" <<EOF
        </div>

        <h2>Recovery Actions (${#RECOVERY_ACTIONS[@]})</h2>
        <div class="warning-box action-box">
EOF

    for action in "${RECOVERY_ACTIONS[@]}"; do
        if [[ "$action" =~ ^ACTION: ]]; then
            echo "            <div class=\"action-item\"><strong>→</strong> ${action#ACTION: }</div>" >> "${html_file}"
        else
            echo "            <div class=\"action-item\">${action}</div>" >> "${html_file}"
        fi
    done

    cat >> "${html_file}" <<EOF
        </div>

        <h2>Preventive Recommendations (${#PREVENTIVE_ACTIONS[@]})</h2>
        <div class="info-box action-box">
            <ul>
EOF

    for action in "${PREVENTIVE_ACTIONS[@]}"; do
        echo "                <li>${action}</li>" >> "${html_file}"
    done

    cat >> "${html_file}" <<'EOF'
            </ul>
        </div>

        <h2>Execution Instructions</h2>
        <div class="action-box">
            <ol>
                <li><strong>Review Plan:</strong> Carefully review all actions before execution</li>
                <li><strong>Backup First:</strong> Ensure backups exist before making changes</li>
                <li><strong>Execute Critical:</strong> Address critical actions first</li>
                <li><strong>Validate Each Step:</strong> Verify success before proceeding</li>
                <li><strong>Document Actions:</strong> Record all changes made</li>
            </ol>
        </div>

        <h2>Available Files</h2>
        <ul>
EOF

    echo "            <li>JSON Plan: <code>${PLAN_FILE}</code></li>" >> "${html_file}"
    echo "            <li>Executable Script: <code>${SCRIPT_FILE}</code></li>" >> "${html_file}"

    cat >> "${html_file}" <<'EOF'
        </ul>
    </div>
</body>
</html>
EOF

    echo -e "${GREEN}HTML report created: ${html_file}${NC}"
}

################################################################################
# Main Execution
################################################################################

main() {
    echo "=========================================="
    echo "RECOVERY ACTION PLANNER v1.0"
    echo "=========================================="
    echo ""

    # Run analysis
    analyze_smart_data
    analyze_zfs_health
    analyze_disk_space
    analyze_system_state
    generate_preventive_actions

    echo ""
    echo "=========================================="
    echo "ANALYSIS SUMMARY"
    echo "=========================================="
    echo ""
    echo -e "Risk Level: ${RISK_LEVEL}"
    echo -e "Critical Actions: ${#CRITICAL_ACTIONS[@]}"
    echo -e "Recovery Actions: ${#RECOVERY_ACTIONS[@]}"
    echo -e "Preventive Actions: ${#PREVENTIVE_ACTIONS[@]}"
    echo ""

    # Generate outputs
    generate_json_plan
    generate_executable_script
    generate_html_report

    echo ""
    echo "=========================================="
    echo "RECOVERY PLAN COMPLETE"
    echo "=========================================="
    echo ""
    echo -e "${GREEN}JSON Plan:${NC} ${PLAN_FILE}"
    echo -e "${GREEN}Executable Script:${NC} ${SCRIPT_FILE}"
    echo -e "${GREEN}HTML Report:${NC} ${REPORT_DIR}/recovery_plan_${TIMESTAMP}.html"
    echo ""

    if [[ ${#CRITICAL_ACTIONS[@]} -gt 0 ]]; then
        echo -e "${RED}⚠ CRITICAL: ${#CRITICAL_ACTIONS[@]} action(s) require immediate attention${NC}"
        echo ""
        echo -e "${YELLOW}To execute recovery actions:${NC}"
        echo -e "  ${SCRIPT_FILE}"
        echo ""
        echo -e "${RED}WARNING: Review the script carefully before execution${NC}"
    else
        echo -e "${GREEN}No critical issues detected${NC}"
    fi
}

main "$@"
