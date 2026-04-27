#!/bin/bash
# Disaster Recovery Test Script
# Purpose: Test backup restoration procedures for DR validation
#
# Usage:
#   ./test-dr-restoration.sh                         # Full test suite
#   ./test-dr-restoration.sh --quick                 # Quick smoke test
#   ./test-dr-restoration.sh --database              # Test database restore only
#   ./test-dr-restoration.sh --offsite               # Test offsite restore
#   ./test-dr-restoration.sh --report                # Generate test report
#
# Recommended: Run quarterly as part of DR testing
# Schedule: First Sunday of each quarter at 02:00

set -euo pipefail

# ============================================================================
# CONFIGURATION
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/replication-config.env"
TEST_LOG_DIR="/var/log/dr-tests"
TEST_REPORT="${TEST_LOG_DIR}/dr-test-report-$(date +%Y%m%d-%H%M%S).md"
TEST_TEMP="/tmp/dr-test-$$"

# Test thresholds
MAX_DB_RESTORE_TIME_MINUTES=30
MAX_VM_RESTORE_TIME_MINUTES=60
MAX_OFFSITE_DOWNLOAD_TIME_MINUTES=30

# Load configuration
if [[ -f "${CONFIG_FILE}" ]]; then
    # shellcheck source=/dev/null
    source "${CONFIG_FILE}"
fi

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Test results
declare -A TEST_RESULTS
declare -a TEST_MESSAGES

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

log_test() {
    local test_name="$1"
    local status="$2"
    local message="$3"

    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [${status}] ${test_name}: ${message}" | tee -a "${TEST_LOG_DIR}/test-execution.log"

    TEST_RESULTS["${test_name}"]="${status}"
    TEST_MESSAGES+=("${test_name}: ${message}")

    if [[ "${status}" == "PASS" ]]; then
        echo -e "${GREEN}[PASS]${NC} ${test_name}: ${message}"
    elif [[ "${status}" == "FAIL" ]]; then
        echo -e "${RED}[FAIL]${NC} ${test_name}: ${message}"
    else
        echo -e "${YELLOW}[WARN]${NC} ${test_name}: ${message}"
    fi
}

start_test() {
    local test_name="$1"
    echo -e "${BLUE}>>> Testing: ${test_name}${NC}"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting: ${test_name}" >> "${TEST_LOG_DIR}/test-execution.log"
}

measure_time() {
    local start_time=$1
    local end_time=$2
    echo $((end_time - start_time))
}

format_seconds() {
    local seconds=$1
    local minutes=$((seconds / 60))
    local secs=$((seconds % 60))
    printf "%02d:%02d" ${minutes} ${secs}
}

create_test_environment() {
    mkdir -p "${TEST_TEMP}"
    mkdir -p "${TEST_LOG_DIR}"
}

cleanup_test_environment() {
    rm -rf "${TEST_TEMP}"
}

# ============================================================================
# TEST FUNCTIONS
# ============================================================================

# Test 1: Backup Integrity Check
test_backup_integrity() {
    start_test "Backup Integrity Check"

    local test_start=$(date +%s)
    local total_backups=0
    local corrupt_backups=0

    # Check Proxmox backups
    if [[ -d "/spark/base/dump" ]]; then
        while IFS= read -r backup; do
            if [[ -f "${backup}" ]]; then
                ((total_backups++))

                local file_type
                file_type=$(file "${backup}")

                if [[ "${backup}" == *.gz ]]; then
                    if gzip -t "${backup}" 2>/dev/null; then
                        : # File is valid
                    else
                        ((corrupt_backups++))
                    fi
                elif [[ "${backup}" == *.zst ]]; then
                    if zstd -t "${backup}" 2>/dev/null; then
                        : # File is valid
                    else
                        ((corrupt_backups++))
                    fi
                fi
            fi
        done < <(find /spark/base/dump -type f \( -name "*.vma.zst" -o -name "*.tar.zst" \) | head -10)
    fi

    # Check application backups
    if [[ -d "/mnt/shares/agl-hostman-backups/daily" ]]; then
        while IFS= read -r backup; do
            if [[ -f "${backup}" ]]; then
                ((total_backups++))

                if gzip -t "${backup}" 2>/dev/null; then
                    : # File is valid
                else
                    ((corrupt_backups++))
                fi
            fi
        done < <(find /mnt/shares/agl-hostman-backups/daily -type f -name "*.gz" | head -10)
    fi

    local test_end=$(date +%s)
    local duration=$(measure_time ${test_start} ${test_end})

    if [[ ${corrupt_backups} -eq 0 ]]; then
        log_test "Backup Integrity Check" "PASS" \
            "All ${total_backups} backups verified in $(format_seconds ${duration})"
        return 0
    else
        log_test "Backup Integrity Check" "FAIL" \
            "Found ${corrupt_backups} corrupt backups out of ${total_backups}"
        return 1
    fi
}

# Test 2: Offsite Connectivity
test_offsite_connectivity() {
    start_test "Offsite Connectivity"

    local test_start=$(date +%s)
    local connected=0
    local total=0

    # Test B2 connectivity
    if command -v rclone >/dev/null 2>&1 && [[ -n "${B2_BUCKET:-}" ]]; then
        ((total++))
        if timeout 30 rclone lsd "${B2_BUCKET}:" >/dev/null 2>&1; then
            ((connected++))
            log_test "B2 Connectivity" "PASS" "Backblaze B2 accessible"
        else
            log_test "B2 Connectivity" "FAIL" "Backblaze B2 not accessible"
        fi
    fi

    # Test Hetzner connectivity
    if [[ -n "${HETZNER_HOST:-}" ]]; then
        ((total++))
        if timeout 10 ssh -o ConnectTimeout=5 -p ${HETZNER_PORT:-23} \
            ${HETZNER_USER}@${HETZNER_HOST} "echo 'OK'" >/dev/null 2>&1; then
            ((connected++))
            log_test "Hetzner Connectivity" "PASS" "Hetzner Storage accessible"
        else
            log_test "Hetzner Connectivity" "FAIL" "Hetzner Storage not accessible"
        fi
    fi

    local test_end=$(date +%s)
    local duration=$(measure_time ${test_start} ${test_end})

    if [[ ${connected} -eq ${total} ]] && [[ ${total} -gt 0 ]]; then
        log_test "Offsite Connectivity" "PASS" \
            "All ${total} offsite locations reachable in $(format_seconds ${duration})"
        return 0
    elif [[ ${connected} -gt 0 ]]; then
        log_test "Offsite Connectivity" "WARN" \
            "${connected}/${total} offsite locations reachable"
        return 0
    else
        log_test "Offsite Connectivity" "FAIL" "No offsite locations reachable"
        return 1
    fi
}

# Test 3: Database Restoration Test
test_database_restoration() {
    start_test "Database Restoration"

    local test_start=$(date +%s)

    # Find latest database backup
    local postgres_backup
    postgres_backup=$(find /mnt/shares/agl-hostman-backups/daily -name "*postgres*.sql.gz" -type f 2>/dev/null | head -1)

    if [[ -z "${postgres_backup}" ]]; then
        log_test "Database Restoration" "SKIP" "No PostgreSQL backup found"
        return 0
    fi

    log_test "Database Restoration" "INFO" "Testing with: ${postgres_backup}"

    # Create temporary test container
    local test_container="dr-test-postgres-$$"

    if ! docker run -d --name "${test_container}" \
        -e POSTGRES_PASSWORD="test_password_123" \
        -e POSTGRES_DB="dr_test" \
        postgres:16-alpine >/dev/null 2>&1; then
        log_test "Database Restoration" "FAIL" "Failed to create test container"
        return 1
    fi

    # Wait for container to be ready
    local max_wait=30
    local waited=0
    while [[ ${waited} -lt ${max_wait} ]]; do
        if docker exec "${test_container}" pg_isready >/dev/null 2>&1; then
            break
        fi
        sleep 1
        ((waited++))
    done

    if [[ ${waited} -ge ${max_wait} ]]; then
        log_test "Database Restoration" "FAIL" "Test container did not become ready"
        docker rm -f "${test_container}" >/dev/null 2>&1
        return 1
    fi

    # Restore backup
    log_test "Database Restoration" "INFO" "Restoring backup to test container..."

    if ! gunzip -c "${postgres_backup}" | \
        docker exec -i "${test_container}" psql -U postgres -d dr_test >/dev/null 2>&1; then

        log_test "Database Restoration" "FAIL" "Failed to restore backup"
        docker rm -f "${test_container}" >/dev/null 2>&1
        return 1
    fi

    # Verify restored data
    local table_count=0
    table_count=$(docker exec "${test_container}" psql -U postgres -d dr_test -tAc \
        "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public'" 2>/dev/null || echo "0")

    # Cleanup
    docker rm -f "${test_container}" >/dev/null 2>&1

    local test_end=$(date +%s)
    local duration=$(measure_time ${test_start} ${test_end})
    local duration_minutes=$((duration / 60))

    if [[ ${table_count} -gt 0 ]]; then
        if [[ ${duration_minutes} -le ${MAX_DB_RESTORE_TIME_MINUTES} ]]; then
            log_test "Database Restoration" "PASS" \
                "Restored ${table_count} tables in $(format_seconds ${duration})"
            return 0
        else
            log_test "Database Restoration" "WARN" \
                "Restore exceeded target time: $(format_seconds ${duration}) (target: ${MAX_DB_RESTORE_TIME_MINUTES}m)"
            return 0
        fi
    else
        log_test "Database Restoration" "FAIL" \
            "No tables found after restore (backup may be empty)"
        return 1
    fi
}

# Test 4: Offsite Download Test
test_offsite_download() {
    start_test "Offsite Download"

    local test_start=$(date +%s)

    if ! command -v rclone >/dev/null 2>&1 || [[ -z "${B2_BUCKET:-}" ]]; then
        log_test "Offsite Download" "SKIP" "rclone or B2_BUCKET not configured"
        return 0
    fi

    # Find a test file to download
    local test_file
    test_file=$(rclone ls "${B2_BUCKET}:daily/" 2>/dev/null | head -1 | awk '{print $2}')

    if [[ -z "${test_file}" ]]; then
        log_test "Offsite Download" "SKIP" "No files found in offsite storage"
        return 0
    fi

    log_test "Offsite Download" "INFO" "Downloading test file: ${test_file}"

    # Download file
    local download_path="${TEST_TEMP}/test-download"

    if ! rclone copy "${B2_BUCKET}:daily/${test_file}" "${download_path}" \
        --log-file="${TEST_LOG_DIR}/rclone-test.log" >/dev/null 2>&1; then

        log_test "Offsite Download" "FAIL" "Failed to download from offsite storage"
        return 1
    fi

    local downloaded_file="${download_path}/${test_file}"

    # Verify download
    if [[ ! -f "${downloaded_file}" ]]; then
        log_test "Offsite Download" "FAIL" "Downloaded file not found"
        return 1
    fi

    local file_size
    file_size=$(stat -f%z "${downloaded_file}" 2>/dev/null || stat -c%s "${downloaded_file}" 2>/dev/null)

    # Verify integrity if compressed
    if [[ "${test_file}" == *.gz ]]; then
        if ! gzip -t "${downloaded_file}" 2>/dev/null; then
            log_test "Offsite Download" "FAIL" "Downloaded file is corrupt"
            return 1
        fi
    fi

    local test_end=$(date +%s)
    local duration=$(measure_time ${test_start} ${test_end})
    local duration_minutes=$((duration / 60))

    if [[ ${duration_minutes} -le ${MAX_OFFSITE_DOWNLOAD_TIME_MINUTES} ]]; then
        log_test "Offsite Download" "PASS" \
            "Downloaded $((${file_size} / 1024))KB in $(format_seconds ${duration})"
        return 0
    else
        log_test "Offsite Download" "WARN" \
            "Download exceeded target time: $(format_seconds ${duration}) (target: ${MAX_OFFSITE_DOWNLOAD_TIME_MINUTES}m)"
        return 0
    fi
}

# Test 5: GPG Encryption/Decryption Test
test_gpg_encryption() {
    start_test "GPG Encryption/Decryption"

    local test_start=$(date +%s)

    if ! command -v gpg >/dev/null 2>&1; then
        log_test "GPG Encryption/Decryption" "SKIP" "GPG not installed"
        return 0
    fi

    # Create test file
    local test_file="${TEST_TEMP}/gpg-test.txt"
    local test_content="DR test content at $(date)"

    echo "${test_content}" > "${test_file}"

    # Encrypt
    local encrypted_file="${test_file}.gpg"

    if ! gpg --batch --yes --output "${encrypted_file}" \
        --symmetric --cipher-algo AES256 "${test_file}" >/dev/null 2>&1; then

        log_test "GPG Encryption/Decryption" "FAIL" "Failed to encrypt test file"
        return 1
    fi

    # Decrypt
    local decrypted_file="${test_file}.decrypted"

    if ! gpg --batch --yes --output "${decrypted_file}" \
        --decrypt "${encrypted_file}" >/dev/null 2>&1; then

        log_test "GPG Encryption/Decryption" "FAIL" "Failed to decrypt test file"
        return 1
    fi

    # Verify content
    if ! grep -q "${test_content}" "${decrypted_file}"; then
        log_test "GPG Encryption/Decryption" "FAIL" "Decrypted content mismatch"
        return 1
    fi

    local test_end=$(date +%s)
    local duration=$(measure_time ${test_start} ${test_end})

    log_test "GPG Encryption/Decryption" "PASS" \
        "GPG operations successful in $(format_seconds ${duration})"
    return 0
}

# Test 6: Disk Space Check
test_disk_space() {
    start_test "Disk Space Check"

    local test_start=$(date +%s)
    local warnings=0

    local mounts=("/spark" "/mnt/shares" "/var")

    for mount in "${mounts[@]}"; do
        if [[ ! -d "${mount}" ]]; then
            continue
        fi

        local available_gb
        available_gb=$(df -BG "${mount}" | awk 'NR==2 {print $4}' | sed 's/G//')

        if [[ ${available_gb} -lt 100 ]]; then
            log_test "Disk Space (${mount})" "WARN" "Only ${available_gb}GB available"
            ((warnings++))
        fi
    done

    local test_end=$(date +%s)
    local duration=$(measure_time ${test_start} ${test_end})

    if [[ ${warnings} -eq 0 ]]; then
        log_test "Disk Space Check" "PASS" \
            "All mounts have adequate space in $(format_seconds ${duration})"
        return 0
    else
        log_test "Disk Space Check" "WARN" \
            "${warnings} mount(s) with low space in $(format_seconds ${duration})"
        return 0
    fi
}

# Test 7: Replication Status Check
test_replication_status() {
    start_test "Replication Status"

    local test_start=$(date +%s)

    local log_dir="/var/log/backup-replication"
    if [[ ! -d "${log_dir}" ]]; then
        log_test "Replication Status" "SKIP" "Replication log directory not found"
        return 0
    fi

    # Find latest replication log
    local latest_log
    latest_log=$(find "${log_dir}" -name "replication-*.log" -type f -printf '%T@ %p\n' 2>/dev/null | sort -rn | head -1 | cut -d' ' -f2-)

    if [[ -z "${latest_log}" ]]; then
        log_test "Replication Status" "WARN" "No replication logs found"
        return 0
    fi

    # Check last replication status
    local last_status="unknown"
    if grep -q "SUCCESS" "${latest_log}" 2>/dev/null; then
        last_status="success"
    elif grep -q "FAILED" "${latest_log}" 2>/dev/null; then
        last_status="failed"
    fi

    local replication_age_seconds
    replication_age_seconds=$(($(date +%s) - $(stat -c %Y "${latest_log}")))
    local replication_age_hours=$((replication_age_seconds / 3600))

    local test_end=$(date +%s)
    local duration=$(measure_time ${test_start} ${test_end})

    if [[ "${last_status}" == "success" ]] && [[ ${replication_age_hours} -lt 26 ]]; then
        log_test "Replication Status" "PASS" \
            "Last replication: ${replication_age_hours}h ago (${last_status})"
        return 0
    elif [[ "${last_status}" == "failed" ]]; then
        log_test "Replication Status" "FAIL" \
            "Last replication failed (${replication_age_hours}h ago)"
        return 1
    else
        log_test "Replication Status" "WARN" \
            "Last replication: ${replication_age_hours}h ago (status: ${last_status})"
        return 0
    fi
}

# ============================================================================
# REPORT GENERATION
# ============================================================================

generate_report() {
    local report_file="${TEST_REPORT}"

    cat > "${report_file}" << EOF
# Disaster Recovery Test Report

**Test Date**: $(date '+%Y-%m-%d %H:%M:%S')
**Test Duration**: $(format_seconds $(($(date +%s) - TEST_START_TIME)))
**Test Environment**: $(hostname)
**Test Type**: ${TEST_TYPE:-Full}

## Executive Summary

| Metric | Value |
|--------|-------|
| Total Tests | ${#TEST_RESULTS[@]} |
| Passed | $(echo "${TEST_RESULTS[@]}" | grep -o "PASS" | wc -l) |
| Failed | $(echo "${TEST_RESULTS[@]}" | grep -o "FAIL" | wc -l) |
| Warnings | $(echo "${TEST_RESULTS[@]}" | grep -o "WARN" | wc -l) |
| Skipped | $(echo "${TEST_RESULTS[@]}" | grep -o "SKIP" | wc -l) |

## Test Results

### Detailed Results

| Test Name | Status | Details |
|-----------|--------|---------|
EOF

    for message in "${TEST_MESSAGES[@]}"; do
        local test_name=$(echo "${message}" | cut -d: -f1)
        local status=$(echo "${message}" | cut -d: -f2)
        local details=$(echo "${message}" | cut -d: -f3-)

        echo "| ${test_name} | ${status} | ${details} |" >> "${report_file}"
    done

    cat >> "${report_file}" << EOF

## Recommendations

EOF

    # Add recommendations based on test results
    local failed_tests=$(echo "${TEST_RESULTS[@]}" | grep -o "FAIL" | wc -l)
    if [[ ${failed_tests} -gt 0 ]]; then
        echo "- Address ${failed_tests} failed test(s) immediately" >> "${report_file}"
    fi

    local warn_tests=$(echo "${TEST_RESULTS[@]}" | grep -o "WARN" | wc -l)
    if [[ ${warn_tests} -gt 0 ]]; then
        echo "- Review ${warn_tests} warning(s) and address as needed" >> "${report_file}"
    fi

    if [[ ${failed_tests} -eq 0 ]] && [[ ${warn_tests} -eq 0 ]]; then
        echo "- All tests passed successfully. Continue quarterly testing schedule." >> "${report_file}"
    fi

    cat >> "${report_file}" << EOF

## Test Environment

- **Host**: $(hostname)
- **OS**: $(lsb_release -d | cut -f2)
- **Kernel**: $(uname -r)
- **Proxmox Version**: $(pveversion 2>/dev/null || echo "N/A")
- **Docker Version**: $(docker --version 2>/dev/null || echo "N/A")

## Next Steps

1. Review failed tests and implement fixes
2. Update runbook if procedures changed
3. Schedule next quarterly test
4. Archive this report for audit purposes

---

**Report Generated**: $(date '+%Y-%m-%d %H:%M:%S')
**Report Location**: ${report_file}
EOF

    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}  Test Report Generated${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo -e "Report saved to: ${report_file}"
    echo ""
    cat "${report_file}"
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

show_usage() {
    cat << EOF
Disaster Recovery Test Script

Usage: $0 [OPTIONS]

Options:
    --quick              Run quick smoke test only
    --database           Test database restoration only
    --offsite            Test offsite restore only
    --report             Generate report only (use with --quick)
    -h, --help           Show this help message

Examples:
    $0                              # Full test suite
    $0 --quick                      # Quick smoke test
    $0 --database                   # Test database restore only

Recommended Schedule:
    - Quarterly: Full test suite
    - Monthly: Quick smoke test
    - Weekly: Backup integrity check
EOF
}

main() {
    local test_mode="full"
    local generate_report_only=false
    TEST_START_TIME=$(date +%s)
    TEST_TYPE="Full"

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --quick)
                test_mode="quick"
                TEST_TYPE="Quick Smoke Test"
                shift
                ;;
            --database)
                test_mode="database"
                TEST_TYPE="Database Only"
                shift
                ;;
            --offsite)
                test_mode="offsite"
                TEST_TYPE="Offsite Only"
                shift
                ;;
            --report)
                generate_report_only=true
                shift
                ;;
            -h|--help)
                show_usage
                exit 0
                ;;
            *)
                echo "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done

    # Initialization
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}  Disaster Recovery Test${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
    echo "Test Type: ${TEST_TYPE}"
    echo "Test Start: $(date '+%Y-%m-%d %H:%M:%S')"
    echo ""

    create_test_environment

    # Run tests based on mode
    case "${test_mode}" in
        quick)
            test_backup_integrity
            test_replication_status
            test_disk_space
            ;;
        database)
            test_backup_integrity
            test_database_restoration
            test_gpg_encryption
            ;;
        offsite)
            test_offsite_connectivity
            test_offsite_download
            test_gpg_encryption
            ;;
        full)
            test_backup_integrity
            test_offsite_connectivity
            test_replication_status
            test_disk_space
            test_database_restoration
            test_offsite_download
            test_gpg_encryption
            ;;
    esac

    # Cleanup
    cleanup_test_environment

    # Generate report
    generate_report

    # Exit with appropriate code
    local failed_count
    failed_count=$(echo "${TEST_RESULTS[@]}" | grep -o "FAIL" | wc -l)

    if [[ ${failed_count} -gt 0 ]]; then
        echo ""
        echo -e "${RED}========================================${NC}"
        echo -e "${RED}  TESTS FAILED${NC}"
        echo -e "${RED}========================================${NC}"
        echo -e "Failed tests: ${failed_count}"
        exit 1
    else
        echo ""
        echo -e "${GREEN}========================================${NC}"
        echo -e "${GREEN}  ALL TESTS PASSED${NC}"
        echo -e "${GREEN}========================================${NC}"
        exit 0
    fi
}

main "$@"
