#!/bin/bash

#############################################################################
# Statusline Deployment Verification Script
#############################################################################
#
# Purpose: Verify statusline deployment across infrastructure hosts
# Task ID: 756e6dca-7b1a-4d99-a640-bd6a5568f643
#
# Features:
# - Check statusline existence and version
# - Verify dependencies (jq, bash, git)
# - Test statusline execution
# - Generate verification report
#
#############################################################################

set -euo pipefail

# Color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configuration
IDENTITY_FILE="${IDENTITY_FILE:-$HOME/.ssh/fg_srv.pem}"
TARGET_USER="${TARGET_USER:-root}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
REPORT_FILE="/mnt/overpower/apps/dev/agl/agl-hostman/docs/statusline-verification-report-${TIMESTAMP}.md"

# Hosts to verify
HOSTS=(
    "aglsrv1:192.168.0.245"
    "aglsrv6-ts:100.98.108.66"
    "ct179-ts:100.94.221.87"
    "ct180-ts:100.80.30.60"
    "ct183-ts:100.80.30.59"
    "fgsrv6-ts:100.83.51.9"
)

#############################################################################
# Functions
#############################################################################

log() {
    local level=$1
    shift
    local message="$@"

    case $level in
        INFO) echo -e "${BLUE}[INFO]${NC} ${message}" ;;
        SUCCESS) echo -e "${GREEN}[✓]${NC} ${message}" ;;
        WARNING) echo -e "${YELLOW}[!]${NC} ${message}" ;;
        ERROR) echo -e "${RED}[✗]${NC} ${message}" ;;
        HEADER) echo -e "${CYAN}${message}${NC}" ;;
    esac
}

parse_host_spec() {
    local host_spec=$1
    local hostname=$(echo "$host_spec" | cut -d: -f1)
    local ip=$(echo "$host_spec" | cut -d: -f2)
    echo "$hostname|$ip"
}

check_statusline_exists() {
    local hostname=$1
    local ip=$2
    local target_dir="${3:-/root/.claude}"

    if ssh -i "$IDENTITY_FILE" -o ConnectTimeout=5 -o BatchMode=yes \
        "${TARGET_USER}@${ip}" "test -f ${target_dir}/statusline-command.sh" 2>/dev/null; then
        return 0
    else
        return 1
    fi
}

get_statusline_info() {
    local hostname=$1
    local ip=$2
    local target_dir="${3:-/root/.claude}"

    local info
    info=$(ssh -i "$IDENTITY_FILE" -o ConnectTimeout=10 "${TARGET_USER}@${ip}" "
        # File info
        if [ -f ${target_dir}/statusline-command.sh ]; then
            echo 'EXISTS'
            stat -c 'Size: %s bytes, Modified: %y' ${target_dir}/statusline-command.sh 2>/dev/null || \
            stat -f 'Size: %z bytes, Modified: %Sm' ${target_dir}/statusline-command.sh 2>/dev/null
            test -x ${target_dir}/statusline-command.sh && echo 'Executable: YES' || echo 'Executable: NO'
            head -5 ${target_dir}/statusline-command.sh | grep -oP 'Version \K[\d.]+' || echo 'Version: UNKNOWN'
        else
            echo 'NOT_FOUND'
        fi
    " 2>/dev/null)

    echo "$info"
}

check_dependencies() {
    local hostname=$1
    local ip=$2

    local deps
    deps=$(ssh -i "$IDENTITY_FILE" -o ConnectTimeout=10 "${TARGET_USER}@${ip}" "
        echo 'Dependencies:'
        which jq >/dev/null 2>&1 && echo '  jq: INSTALLED' || echo '  jq: MISSING'
        which bash >/dev/null 2>&1 && echo '  bash: INSTALLED' || echo '  bash: MISSING'
        which git >/dev/null 2>&1 && echo '  git: INSTALLED (optional)' || echo '  git: MISSING (optional)'
        which bc >/dev/null 2>&1 && echo '  bc: INSTALLED (optional)' || echo '  bc: MISSING (optional)'
    " 2>/dev/null)

    echo "$deps"
}

test_statusline_execution() {
    local hostname=$1
    local ip=$2
    local target_dir="${3:-/root/.claude}"

    local test_result
    test_result=$(ssh -i "$IDENTITY_FILE" -o ConnectTimeout=10 "${TARGET_USER}@${ip}" "
        if [ -x ${target_dir}/statusline-command.sh ]; then
            echo '{\"model\": {\"display_name\": \"Test\"}, \"workspace\": {\"current_dir\": \"/tmp\"}}' | ${target_dir}/statusline-command.sh 2>&1 | head -c 200
            echo ''
            echo 'EXIT_CODE: \$?'
        else
            echo 'NOT_EXECUTABLE'
        fi
    " 2>/dev/null)

    echo "$test_result"
}

verify_host() {
    local host_spec=$1
    local host_info=$(parse_host_spec "$host_spec")
    local hostname=$(echo "$host_info" | cut -d| -f1)
    local ip=$(echo "$host_info" | cut -d| -f2)
    local target_dir="/root/.claude"

    log HEADER "=========================================="
    log HEADER "Verifying ${hostname} (${ip})"
    log HEADER "=========================================="

    # Check if statusline exists
    if check_statusline_exists "$hostname" "$ip" "$target_dir"; then
        log SUCCESS "Statusline script found on ${hostname}"

        # Get file info
        local info=$(get_statusline_info "$hostname" "$ip" "$target_dir")
        echo "$info"

        # Check dependencies
        echo ""
        log INFO "Checking dependencies..."
        check_dependencies "$hostname" "$ip"

        # Test execution
        echo ""
        log INFO "Testing execution..."
        local test_result=$(test_statusline_execution "$hostname" "$ip" "$target_dir")
        if echo "$test_result" | grep -q "NOT_EXECUTABLE"; then
            log ERROR "Statusline script is not executable"
            return 1
        elif echo "$test_result" | grep -q "EXIT_CODE: 0"; then
            log SUCCESS "Statusline executes successfully"
            echo "Sample output:"
            echo "$test_result" | grep -v "EXIT_CODE" | head -3
        else
            log WARNING "Statusline execution returned non-zero exit code"
            echo "$test_result"
        fi

        return 0
    else
        log ERROR "Statusline script NOT found on ${hostname}"
        return 1
    fi
}

generate_verification_report() {
    local total_hosts=${#HOSTS[@]}
    local success_count=$1
    local fail_count=$((total_hosts - success_count))

    cat > "$REPORT_FILE" <<EOF
# Statusline Deployment Verification Report

**Generated**: $(date)
**Task ID**: 756e6dca-7b1a-4d99-a640-bd6a5568f643
**Project**: FGSRV6 Statusline Deployment (e61f909a-bfee-486c-8f11-22a2fd9cbf6f)

---

## Executive Summary

- **Total Hosts Verified**: ${total_hosts}
- **Successful**: ${success_count}
- **Failed**: ${fail_count}
- **Success Rate**: $(( success_count * 100 / total_hosts ))%

---

## Detailed Results

EOF

    for host_spec in "${HOSTS[@]}"; do
        local host_info=$(parse_host_spec "$host_spec")
        local hostname=$(echo "$host_info" | cut -d| -f1)
        local ip=$(echo "$host_info" | cut -d| -f2)

        echo "### ${hostname} (${ip})" >> "$REPORT_FILE"

        if check_statusline_exists "$hostname" "$ip"; then
            echo "**Status**: ✓ Deployed" >> "$REPORT_FILE"
            echo "" >> "$REPORT_FILE"

            local info=$(get_statusline_info "$hostname" "$ip")
            echo "\`\`\`" >> "$REPORT_FILE"
            echo "$info" >> "$REPORT_FILE"
            echo "\`\`\`" >> "$REPORT_FILE"
            echo "" >> "$REPORT_FILE"

            local deps=$(check_dependencies "$hostname" "$ip")
            echo "**Dependencies**:" >> "$REPORT_FILE"
            echo "\`\`\`" >> "$REPORT_FILE"
            echo "$deps" >> "$REPORT_FILE"
            echo "\`\`\`" >> "$REPORT_FILE"
        else
            echo "**Status**: ✗ Not Found" >> "$REPORT_FILE"
            echo "" >> "$REPORT_FILE"
            echo "**Action Required**: Deploy statusline to this host" >> "$REPORT_FILE"
        fi

        echo "" >> "$REPORT_FILE"
        echo "---" >> "$REPORT_FILE"
        echo "" >> "$REPORT_FILE"
    done

    cat >> "$REPORT_FILE" <<EOF

## Recommendations

### For Failed Hosts:
1. Run deployment script: \`./scripts/deploy-statusline-to-hosts.sh --hosts <hostname>\`
2. Verify SSH access: \`ssh ${TARGET_USER}@<ip> hostname\`
3. Check dependencies: \`ssh ${TARGET_USER}@<ip> 'which jq bash git'\`

### For Successful Hosts:
1. Restart Claude Code to see statusline in action
2. Verify settings.json configuration
3. Test with actual workflows

---

**Next Steps**:
- Deploy to missing hosts using deployment script
- Monitor statusline performance
- Report any issues to deployment team

---

**Report Generated**: $(date)
**Verification Script**: scripts/verify-statusline-hosts.sh
EOF

    log SUCCESS "Verification report generated: ${REPORT_FILE}"
}

#############################################################################
# Main Execution
#############################################################################

main() {
    log HEADER "=========================================="
    log HEADER "  Statusline Deployment Verification"
    log HEADER "=========================================="
    echo ""

    local success_count=0
    local fail_count=0

    for host_spec in "${HOSTS[@]}"; do
        if verify_host "$host_spec"; then
            ((success_count++))
        else
            ((fail_count++))
        fi
        echo ""
    done

    # Summary
    log HEADER "=========================================="
    log HEADER "  Verification Summary"
    log HEADER "=========================================="
    log SUCCESS "Successful: ${success_count}/${#HOSTS[@]}"
    if [ $fail_count -gt 0 ]; then
        log ERROR "Failed: ${fail_count}/${#HOSTS[@]}"
    fi
    echo ""

    # Generate report
    generate_verification_report "$success_count"

    # Exit with appropriate code
    if [ $fail_count -eq 0 ]; then
        log SUCCESS "All hosts verified successfully!"
        exit 0
    else
        log WARNING "Some hosts failed verification. Review the report for details."
        exit 1
    fi
}

# Run main
main
