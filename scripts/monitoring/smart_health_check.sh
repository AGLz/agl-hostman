#!/bin/bash
################################################################################
# SMART Health Check Script
# Purpose: Collect and analyze SMART data from all storage devices
# Output: JSON formatted health reports with severity assessment
################################################################################

set -euo pipefail

# Configuration
REPORT_DIR="/root/forensic-reports"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
SMART_REPORT="${REPORT_DIR}/smart_analysis_${TIMESTAMP}.json"
SMART_RAW="${REPORT_DIR}/smart_raw_${TIMESTAMP}.txt"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

mkdir -p "${REPORT_DIR}"

################################################################################
# Check Dependencies
################################################################################

check_dependencies() {
    local missing_deps=0

    if ! command -v smartctl >/dev/null 2>&1; then
        echo -e "${RED}ERROR: smartctl not installed. Install with: apt-get install smartmontools${NC}"
        ((missing_deps++))
    fi

    if ! command -v jq >/dev/null 2>&1; then
        echo -e "${YELLOW}WARNING: jq not installed. JSON output may be less formatted.${NC}"
    fi

    if [[ $missing_deps -gt 0 ]]; then
        exit 1
    fi
}

################################################################################
# Disk Discovery
################################################################################

discover_disks() {
    echo -e "${GREEN}Discovering storage devices...${NC}"

    # Find all block devices
    local devices=()

    # Method 1: SATA/SAS devices
    for dev in /dev/sd[a-z] /dev/sd[a-z][a-z]; do
        [[ -b "$dev" ]] && devices+=("$dev")
    done

    # Method 2: NVMe devices
    for dev in /dev/nvme[0-9]n[0-9]; do
        [[ -b "$dev" ]] && devices+=("$dev")
    done

    # Method 3: virtio devices (for VMs)
    for dev in /dev/vd[a-z]; do
        [[ -b "$dev" ]] && devices+=("$dev")
    done

    echo "${devices[@]}"
}

################################################################################
# SMART Data Collection
################################################################################

collect_smart_data() {
    local device=$1
    local output_file=$2

    echo "Collecting SMART data for: ${device}"

    {
        echo "=========================================="
        echo "Device: ${device}"
        echo "Timestamp: $(date -Iseconds)"
        echo "=========================================="
        echo ""

        # Basic device info
        echo "--- Device Information ---"
        smartctl -i "${device}" 2>/dev/null || echo "Failed to get device info"
        echo ""

        # Health status
        echo "--- Overall Health Status ---"
        smartctl -H "${device}" 2>/dev/null || echo "Failed to get health status"
        echo ""

        # All SMART attributes
        echo "--- SMART Attributes ---"
        smartctl -A "${device}" 2>/dev/null || echo "Failed to get SMART attributes"
        echo ""

        # Error log
        echo "--- Error Log ---"
        smartctl -l error "${device}" 2>/dev/null || echo "Failed to get error log"
        echo ""

        # Self-test log
        echo "--- Self-Test Log ---"
        smartctl -l selftest "${device}" 2>/dev/null || echo "Failed to get self-test log"
        echo ""

        echo "=========================================="
        echo ""
    } >> "${output_file}"
}

################################################################################
# SMART Analysis
################################################################################

analyze_smart_attribute() {
    local attr_id=$1
    local attr_name=$2
    local raw_value=$3
    local threshold=$4
    local worst=$5

    local severity="OK"
    local message=""

    case $attr_id in
        5)  # Reallocated Sectors Count
            if [[ $raw_value -gt 0 ]]; then
                severity="CRITICAL"
                message="Reallocated sectors detected: ${raw_value}"
            fi
            ;;
        10) # Spin Retry Count
            if [[ $raw_value -gt 0 ]]; then
                severity="WARNING"
                message="Spin retry events: ${raw_value}"
            fi
            ;;
        187|188|197|198) # Uncorrectable errors
            if [[ $raw_value -gt 0 ]]; then
                severity="CRITICAL"
                message="Uncorrectable errors detected: ${raw_value}"
            fi
            ;;
        196) # Reallocation Event Count
            if [[ $raw_value -gt 0 ]]; then
                severity="WARNING"
                message="Reallocation events: ${raw_value}"
            fi
            ;;
        199) # UDMA CRC Error Count
            if [[ $raw_value -gt 100 ]]; then
                severity="WARNING"
                message="Cable/connection issues suspected: ${raw_value} errors"
            fi
            ;;
    esac

    # Threshold check
    if [[ -n "$threshold" && "$worst" -lt "$threshold" ]]; then
        severity="CRITICAL"
        message="${message} | Worst value (${worst}) below threshold (${threshold})"
    fi

    echo "${severity}|${message}"
}

################################################################################
# Parse SMART Data to JSON
################################################################################

parse_smart_to_json() {
    local device=$1
    local raw_data=$2

    local health_status="UNKNOWN"
    local model="Unknown"
    local serial="Unknown"
    local capacity="Unknown"

    # Extract device info
    if grep -q "Model Family:" "${raw_data}"; then
        model=$(grep "Model Family:" "${raw_data}" | head -1 | cut -d: -f2- | xargs)
    elif grep -q "Device Model:" "${raw_data}"; then
        model=$(grep "Device Model:" "${raw_data}" | head -1 | cut -d: -f2- | xargs)
    fi

    if grep -q "Serial Number:" "${raw_data}"; then
        serial=$(grep "Serial Number:" "${raw_data}" | head -1 | cut -d: -f2- | xargs)
    fi

    if grep -q "User Capacity:" "${raw_data}"; then
        capacity=$(grep "User Capacity:" "${raw_data}" | head -1 | cut -d: -f2- | cut -d[ -f1 | xargs)
    fi

    # Extract health status
    if grep -q "PASSED" "${raw_data}"; then
        health_status="PASSED"
    elif grep -q "FAILED" "${raw_data}"; then
        health_status="FAILED"
    fi

    # Start JSON output
    cat <<EOF
{
    "device": "${device}",
    "model": "${model}",
    "serial": "${serial}",
    "capacity": "${capacity}",
    "health_status": "${health_status}",
    "timestamp": "$(date -Iseconds)",
    "critical_attributes": [],
    "warnings": []
}
EOF
}

################################################################################
# Main Execution
################################################################################

main() {
    echo "=========================================="
    echo "SMART Health Check Analysis"
    echo "=========================================="
    echo ""

    check_dependencies

    local devices=($(discover_disks))

    if [[ ${#devices[@]} -eq 0 ]]; then
        echo -e "${YELLOW}No storage devices found${NC}"
        exit 0
    fi

    echo -e "${GREEN}Found ${#devices[@]} device(s):${NC}"
    printf '%s\n' "${devices[@]}"
    echo ""

    # Initialize JSON report
    echo "{" > "${SMART_REPORT}"
    echo '  "analysis_timestamp": "'"$(date -Iseconds)"'",' >> "${SMART_REPORT}"
    echo '  "hostname": "'"$(hostname)"'",' >> "${SMART_REPORT}"
    echo '  "devices": [' >> "${SMART_REPORT}"

    local first=true
    local critical_count=0
    local warning_count=0

    for device in "${devices[@]}"; do
        # Collect raw SMART data
        collect_smart_data "${device}" "${SMART_RAW}"

        # Check if SMART is available
        if ! smartctl -i "${device}" &>/dev/null; then
            echo -e "${YELLOW}SMART not available for ${device}${NC}"
            continue
        fi

        # Add comma for JSON array
        [[ "$first" = false ]] && echo "    ," >> "${SMART_REPORT}"
        first=false

        # Get health status
        local health_result=$(smartctl -H "${device}" 2>/dev/null | grep -i "SMART overall-health" || echo "UNKNOWN")

        # Get SMART attributes
        echo "    {" >> "${SMART_REPORT}"
        echo '      "device": "'"${device}"'",' >> "${SMART_REPORT}"

        if smartctl -i "${device}" &>/dev/null; then
            local model=$(smartctl -i "${device}" | grep "Device Model:" | cut -d: -f2- | xargs || echo "Unknown")
            local serial=$(smartctl -i "${device}" | grep "Serial Number:" | cut -d: -f2- | xargs || echo "Unknown")

            echo '      "model": "'"${model}"'",' >> "${SMART_REPORT}"
            echo '      "serial": "'"${serial}"'",' >> "${SMART_REPORT}"
        fi

        # Health status
        if echo "${health_result}" | grep -qi "PASSED"; then
            echo '      "health_status": "PASSED",' >> "${SMART_REPORT}"
            echo -e "${GREEN}✓ ${device}: PASSED${NC}"
        elif echo "${health_result}" | grep -qi "FAILED"; then
            echo '      "health_status": "FAILED",' >> "${SMART_REPORT}"
            echo -e "${RED}✗ ${device}: FAILED${NC}"
            ((critical_count++))
        else
            echo '      "health_status": "UNKNOWN",' >> "${SMART_REPORT}"
            echo -e "${YELLOW}? ${device}: UNKNOWN${NC}"
        fi

        # Check critical SMART attributes
        echo '      "critical_attributes": [' >> "${SMART_REPORT}"

        local critical_attrs=""
        if smartctl -A "${device}" &>/dev/null; then
            # Check for reallocated sectors (ID 5)
            local reallocated=$(smartctl -A "${device}" | grep "^  5" | awk '{print $10}' || echo "0")
            if [[ "${reallocated}" != "0" && -n "${reallocated}" ]]; then
                critical_attrs+='        {"id": 5, "name": "Reallocated_Sector_Ct", "raw_value": '"${reallocated}"'},'
                ((critical_count++))
            fi

            # Check for pending sectors (ID 197)
            local pending=$(smartctl -A "${device}" | grep "^ 197" | awk '{print $10}' || echo "0")
            if [[ "${pending}" != "0" && -n "${pending}" ]]; then
                critical_attrs+='        {"id": 197, "name": "Current_Pending_Sector", "raw_value": '"${pending}"'},'
                ((critical_count++))
            fi

            # Check for uncorrectable errors (ID 187, 188, 198)
            for attr_id in 187 188 198; do
                local uncorr=$(smartctl -A "${device}" | grep "^ ${attr_id}" | awk '{print $10}' || echo "0")
                if [[ "${uncorr}" != "0" && -n "${uncorr}" ]]; then
                    critical_attrs+='        {"id": '"${attr_id}"', "name": "Uncorrectable_Error", "raw_value": '"${uncorr}"'},'
                    ((critical_count++))
                fi
            done
        fi

        # Remove trailing comma if exists
        critical_attrs=$(echo "${critical_attrs}" | sed 's/,$//')
        echo "${critical_attrs}" >> "${SMART_REPORT}"

        echo '      ]' >> "${SMART_REPORT}"
        echo "    }" >> "${SMART_REPORT}"
    done

    # Close JSON
    echo "  ]," >> "${SMART_REPORT}"
    echo '  "summary": {' >> "${SMART_REPORT}"
    echo '    "total_devices": '"${#devices[@]}"',' >> "${SMART_REPORT}"
    echo '    "critical_issues": '"${critical_count}"',' >> "${SMART_REPORT}"
    echo '    "warnings": '"${warning_count}"',' >> "${SMART_REPORT}"
    echo '    "overall_status": "'"$([ $critical_count -eq 0 ] && echo "HEALTHY" || echo "CRITICAL")"'"' >> "${SMART_REPORT}"
    echo '  }' >> "${SMART_REPORT}"
    echo "}" >> "${SMART_REPORT}"

    echo ""
    echo "=========================================="
    echo "Analysis Complete"
    echo "=========================================="
    echo -e "${GREEN}JSON Report:${NC} ${SMART_REPORT}"
    echo -e "${GREEN}Raw Data:${NC} ${SMART_RAW}"
    echo ""

    if [[ $critical_count -gt 0 ]]; then
        echo -e "${RED}CRITICAL: ${critical_count} issue(s) detected${NC}"
        exit 1
    elif [[ $warning_count -gt 0 ]]; then
        echo -e "${YELLOW}WARNING: ${warning_count} issue(s) detected${NC}"
        exit 0
    else
        echo -e "${GREEN}All devices appear healthy${NC}"
        exit 0
    fi
}

main "$@"
