#!/bin/bash
################################################################################
# ZFS Pool Analyzer
# Purpose: Comprehensive ZFS pool health diagnostics and error detection
# Output: JSON formatted analysis with actionable recommendations
################################################################################

set -euo pipefail

# Configuration
REPORT_DIR="/root/forensic-reports"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
ZFS_REPORT="${REPORT_DIR}/zfs_analysis_${TIMESTAMP}.json"
ZFS_RAW="${REPORT_DIR}/zfs_raw_${TIMESTAMP}.txt"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

mkdir -p "${REPORT_DIR}"

################################################################################
# Dependency Check
################################################################################

check_zfs_available() {
    if ! command -v zpool >/dev/null 2>&1; then
        echo -e "${RED}ERROR: ZFS not installed or not in PATH${NC}"
        exit 1
    fi

    if ! lsmod | grep -q zfs; then
        echo -e "${YELLOW}WARNING: ZFS module not loaded${NC}"
        if ! modprobe zfs 2>/dev/null; then
            echo -e "${RED}ERROR: Cannot load ZFS module${NC}"
            exit 1
        fi
    fi
}

################################################################################
# Pool Discovery
################################################################################

discover_pools() {
    echo -e "${GREEN}Discovering ZFS pools...${NC}"

    local pools=()

    # Get active pools
    while IFS= read -r pool; do
        pools+=("$pool")
    done < <(zpool list -H -o name 2>/dev/null)

    # Check for importable pools
    local importable=$(zpool import 2>/dev/null | grep "pool:" | awk '{print $2}' || true)
    if [[ -n "$importable" ]]; then
        echo -e "${YELLOW}Found importable pools: ${importable}${NC}"
    fi

    echo "${pools[@]}"
}

################################################################################
# Pool Health Analysis
################################################################################

analyze_pool_health() {
    local pool=$1

    echo "Analyzing pool: ${pool}"

    local health=$(zpool list -H -o health "${pool}" 2>/dev/null)
    local size=$(zpool list -H -o size "${pool}" 2>/dev/null)
    local allocated=$(zpool list -H -o allocated "${pool}" 2>/dev/null)
    local free=$(zpool list -H -o free "${pool}" 2>/dev/null)
    local capacity=$(zpool list -H -o capacity "${pool}" 2>/dev/null)
    local fragmentation=$(zpool list -H -o frag "${pool}" 2>/dev/null)

    # Get detailed status
    local status_output=$(zpool status -v "${pool}" 2>/dev/null)

    # Check for errors
    local read_errors=0
    local write_errors=0
    local cksum_errors=0

    if echo "${status_output}" | grep -q "errors:"; then
        read_errors=$(echo "${status_output}" | grep "errors:" | head -1 | awk '{print $2}' || echo "0")
        write_errors=$(echo "${status_output}" | grep "errors:" | head -1 | awk '{print $3}' || echo "0")
        cksum_errors=$(echo "${status_output}" | grep "errors:" | head -1 | awk '{print $4}' || echo "0")
    fi

    # Assess severity
    local severity="OK"
    local issues=()

    case "$health" in
        ONLINE)
            severity="OK"
            ;;
        DEGRADED)
            severity="WARNING"
            issues+=("Pool is degraded")
            ;;
        FAULTED|UNAVAIL)
            severity="CRITICAL"
            issues+=("Pool is faulted or unavailable")
            ;;
    esac

    # Check capacity
    local cap_num=${capacity%\%}
    if [[ $cap_num -ge 90 ]]; then
        severity="CRITICAL"
        issues+=("Capacity critical: ${capacity}")
    elif [[ $cap_num -ge 80 ]]; then
        [[ "$severity" != "CRITICAL" ]] && severity="WARNING"
        issues+=("Capacity high: ${capacity}")
    fi

    # Check fragmentation
    local frag_num=${fragmentation%\%}
    if [[ "$frag_num" != "-" && $frag_num -ge 50 ]]; then
        [[ "$severity" == "OK" ]] && severity="WARNING"
        issues+=("High fragmentation: ${fragmentation}")
    fi

    # Check for errors
    if [[ "$read_errors" != "0" || "$write_errors" != "0" || "$cksum_errors" != "0" ]]; then
        severity="CRITICAL"
        issues+=("I/O errors detected: R:${read_errors} W:${write_errors} C:${cksum_errors}")
    fi

    # Output JSON
    cat <<EOF
{
    "pool": "${pool}",
    "health": "${health}",
    "severity": "${severity}",
    "size": "${size}",
    "allocated": "${allocated}",
    "free": "${free}",
    "capacity": "${capacity}",
    "fragmentation": "${fragmentation}",
    "errors": {
        "read": ${read_errors},
        "write": ${write_errors},
        "checksum": ${cksum_errors}
    },
    "issues": [$(printf '"%s",' "${issues[@]}" | sed 's/,$//')],
    "timestamp": "$(date -Iseconds)"
}
EOF
}

################################################################################
# Dataset Analysis
################################################################################

analyze_datasets() {
    local pool=$1

    echo "Analyzing datasets in pool: ${pool}"

    echo "["
    local first=true

    while IFS=$'\t' read -r name used avail refer mountpoint; do
        [[ "$first" = false ]] && echo ","
        first=false

        # Get compression ratio
        local compress_ratio=$(zfs get -H -o value compressratio "${name}" 2>/dev/null || echo "1.00x")

        # Get quota if set
        local quota=$(zfs get -H -o value quota "${name}" 2>/dev/null || echo "none")

        cat <<EOF
    {
        "name": "${name}",
        "used": "${used}",
        "available": "${avail}",
        "referenced": "${refer}",
        "mountpoint": "${mountpoint}",
        "compression_ratio": "${compress_ratio}",
        "quota": "${quota}"
    }
EOF
    done < <(zfs list -H -o name,used,avail,refer,mountpoint -r "${pool}" 2>/dev/null)

    echo "]"
}

################################################################################
# Snapshot Analysis
################################################################################

analyze_snapshots() {
    local pool=$1

    echo "Analyzing snapshots in pool: ${pool}"

    local snapshot_count=$(zfs list -t snapshot -H -r "${pool}" 2>/dev/null | wc -l)
    local snapshot_space=$(zfs list -t snapshot -H -o used -r "${pool}" 2>/dev/null | \
                          awk '{sum+=$1} END {print sum}' || echo "0")

    cat <<EOF
{
    "count": ${snapshot_count},
    "total_space_estimate": "${snapshot_space}",
    "recent_snapshots": [
EOF

    local first=true
    while IFS=$'\t' read -r name used refer; do
        [[ "$first" = false ]] && echo ","
        first=false

        cat <<EOF
        {
            "name": "${name}",
            "used": "${used}",
            "referenced": "${refer}"
        }
EOF
    done < <(zfs list -t snapshot -H -o name,used,refer -r "${pool}" 2>/dev/null | head -10)

    echo "    ]"
    echo "}"
}

################################################################################
# ZFS ARC Stats
################################################################################

analyze_arc_stats() {
    echo "Analyzing ARC statistics..."

    if [[ -f /proc/spl/kstat/zfs/arcstats ]]; then
        local arc_size=$(grep "^size" /proc/spl/kstat/zfs/arcstats | awk '{print $3}')
        local arc_max=$(grep "^c_max" /proc/spl/kstat/zfs/arcstats | awk '{print $3}')
        local arc_hits=$(grep "^hits" /proc/spl/kstat/zfs/arcstats | awk '{print $3}')
        local arc_misses=$(grep "^misses" /proc/spl/kstat/zfs/arcstats | awk '{print $3}')

        local hit_rate=0
        if [[ $((arc_hits + arc_misses)) -gt 0 ]]; then
            hit_rate=$(awk "BEGIN {printf \"%.2f\", ($arc_hits / ($arc_hits + $arc_misses)) * 100}")
        fi

        cat <<EOF
{
    "arc_size_bytes": ${arc_size},
    "arc_max_bytes": ${arc_max},
    "hits": ${arc_hits},
    "misses": ${arc_misses},
    "hit_rate_percent": ${hit_rate}
}
EOF
    else
        echo '{"available": false}'
    fi
}

################################################################################
# Scrub Status
################################################################################

check_scrub_status() {
    local pool=$1

    echo "Checking scrub status for: ${pool}"

    local scrub_status=$(zpool status "${pool}" | grep -A 2 "scan:" || echo "none in progress")

    local last_scrub="never"
    local scrub_errors=0

    if echo "${scrub_status}" | grep -q "scrub repaired"; then
        last_scrub=$(echo "${scrub_status}" | grep "scrub repaired" | sed 's/.*on //' | sed 's/with.*//')
        scrub_errors=$(echo "${scrub_status}" | grep -o "[0-9]* errors" | awk '{print $1}' || echo "0")
    fi

    cat <<EOF
{
    "last_scrub": "${last_scrub}",
    "errors_found": ${scrub_errors},
    "status": "${scrub_status}"
}
EOF
}

################################################################################
# Generate Recommendations
################################################################################

generate_recommendations() {
    local pool=$1
    local health=$2
    local capacity=$3
    local fragmentation=$4
    local errors=$5

    local recommendations=()

    # Health-based recommendations
    if [[ "$health" == "DEGRADED" ]]; then
        recommendations+=("URGENT: Replace failed disk and resilver pool")
        recommendations+=("Check zpool status -v for device details")
    fi

    if [[ "$health" == "FAULTED" ]]; then
        recommendations+=("CRITICAL: Pool is faulted - immediate attention required")
        recommendations+=("Do not make changes without backup")
    fi

    # Capacity recommendations
    local cap_num=${capacity%\%}
    if [[ $cap_num -ge 90 ]]; then
        recommendations+=("URGENT: Free up space immediately (>90% full)")
        recommendations+=("Consider: Delete old snapshots, remove unused datasets")
    elif [[ $cap_num -ge 80 ]]; then
        recommendations+=("WARNING: Plan for capacity expansion (>80% full)")
    fi

    # Fragmentation recommendations
    local frag_num=${fragmentation%\%}
    if [[ "$frag_num" != "-" && $frag_num -ge 50 ]]; then
        recommendations+=("Consider pool defragmentation or recreation")
    fi

    # Error recommendations
    if [[ "$errors" != "0" ]]; then
        recommendations+=("CRITICAL: I/O errors detected - check disk health immediately")
        recommendations+=("Run: zpool scrub ${pool}")
        recommendations+=("Review: zpool status -v ${pool}")
    fi

    # Output JSON array
    printf '%s\n' "${recommendations[@]}" | jq -R . | jq -s .
}

################################################################################
# Main Execution
################################################################################

main() {
    echo "=========================================="
    echo "ZFS Pool Health Analyzer"
    echo "=========================================="
    echo ""

    check_zfs_available

    local pools=($(discover_pools))

    if [[ ${#pools[@]} -eq 0 ]]; then
        echo -e "${YELLOW}No ZFS pools found${NC}"
        echo '{"pools": [], "timestamp": "'"$(date -Iseconds)"'"}' > "${ZFS_REPORT}"
        exit 0
    fi

    echo -e "${GREEN}Found ${#pools[@]} pool(s):${NC}"
    printf '%s\n' "${pools[@]}"
    echo ""

    # Initialize JSON report
    {
        echo "{"
        echo '  "analysis_timestamp": "'"$(date -Iseconds)"'",'
        echo '  "hostname": "'"$(hostname)"'",'
        echo '  "pools": ['
    } > "${ZFS_REPORT}"

    # Collect raw ZFS data
    {
        echo "=========================================="
        echo "ZFS Pool Status - Full Output"
        echo "Timestamp: $(date -Iseconds)"
        echo "=========================================="
        echo ""

        for pool in "${pools[@]}"; do
            echo "========== Pool: ${pool} =========="
            zpool status -v "${pool}" 2>/dev/null || echo "Failed to get status"
            echo ""
            zpool list -v "${pool}" 2>/dev/null || echo "Failed to get list"
            echo ""
            zfs list -r "${pool}" 2>/dev/null || echo "Failed to list datasets"
            echo ""
        done
    } > "${ZFS_RAW}"

    local first=true
    local critical_count=0
    local warning_count=0

    for pool in "${pools[@]}"; do
        [[ "$first" = false ]] && echo "    ," >> "${ZFS_REPORT}"
        first=false

        echo "    {" >> "${ZFS_REPORT}"

        # Pool health analysis
        local pool_health=$(zpool list -H -o health "${pool}")
        local capacity=$(zpool list -H -o capacity "${pool}")
        local fragmentation=$(zpool list -H -o frag "${pool}")

        # Get error counts
        local errors=$(zpool status "${pool}" | grep -c "errors:" || echo "0")

        echo '      "analysis": ' >> "${ZFS_REPORT}"
        analyze_pool_health "${pool}" >> "${ZFS_REPORT}"
        echo "      ," >> "${ZFS_REPORT}"

        echo '      "datasets": ' >> "${ZFS_REPORT}"
        analyze_datasets "${pool}" >> "${ZFS_REPORT}"
        echo "      ," >> "${ZFS_REPORT}"

        echo '      "snapshots": ' >> "${ZFS_REPORT}"
        analyze_snapshots "${pool}" >> "${ZFS_REPORT}"
        echo "      ," >> "${ZFS_REPORT}"

        echo '      "scrub": ' >> "${ZFS_REPORT}"
        check_scrub_status "${pool}" >> "${ZFS_REPORT}"
        echo "      ," >> "${ZFS_REPORT}"

        echo '      "recommendations": ' >> "${ZFS_REPORT}"
        generate_recommendations "${pool}" "${pool_health}" "${capacity}" "${fragmentation}" "${errors}" >> "${ZFS_REPORT}"

        echo "    }" >> "${ZFS_REPORT}"

        # Count issues
        case "$pool_health" in
            DEGRADED|FAULTED|UNAVAIL)
                ((critical_count++))
                echo -e "${RED}✗ ${pool}: ${pool_health}${NC}"
                ;;
            ONLINE)
                echo -e "${GREEN}✓ ${pool}: ONLINE${NC}"
                ;;
        esac
    done

    # Add ARC stats
    echo "    ]," >> "${ZFS_REPORT}"
    echo '  "arc_statistics": ' >> "${ZFS_REPORT}"
    analyze_arc_stats >> "${ZFS_REPORT}"
    echo "," >> "${ZFS_REPORT}"

    # Summary
    echo '  "summary": {' >> "${ZFS_REPORT}"
    echo '    "total_pools": '"${#pools[@]}"',' >> "${ZFS_REPORT}"
    echo '    "critical_issues": '"${critical_count}"',' >> "${ZFS_REPORT}"
    echo '    "warnings": '"${warning_count}"',' >> "${ZFS_REPORT}"
    echo '    "overall_status": "'"$([ $critical_count -eq 0 ] && echo "HEALTHY" || echo "CRITICAL")"'"' >> "${ZFS_REPORT}"
    echo '  }' >> "${ZFS_REPORT}"
    echo "}" >> "${ZFS_REPORT}"

    echo ""
    echo "=========================================="
    echo "Analysis Complete"
    echo "=========================================="
    echo -e "${GREEN}JSON Report:${NC} ${ZFS_REPORT}"
    echo -e "${GREEN}Raw Data:${NC} ${ZFS_RAW}"
    echo ""

    if [[ $critical_count -gt 0 ]]; then
        echo -e "${RED}CRITICAL: ${critical_count} pool(s) require attention${NC}"
        exit 1
    else
        echo -e "${GREEN}All pools appear healthy${NC}"
        exit 0
    fi
}

main "$@"
