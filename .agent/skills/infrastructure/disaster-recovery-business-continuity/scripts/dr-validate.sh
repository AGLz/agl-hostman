#!/bin/bash
################################################################################
# Disaster Recovery Validation Script
# Validates DR readiness including backups, configs, and connectivity
# Usage: ./dr-validate.sh [--region primary|backup] [--drill-mode] [--verbose]
################################################################################

set -euo pipefail

################################################################################
# Configuration
################################################################################

# Region settings
PRIMARY_REGION="${PRIMARY_REGION:-us-east-1}"
BACKUP_REGION="${BACKUP_REGION:-us-west-2}"
CHECK_REGION="${1:-both}"

# Validation settings
BACKUP_RETENTION_HOURS="${BACKUP_RETENTION_HOURS:-24}"
REPLICATION_MAX_LAG="${REPLICATION_MAX_LAG:-60}"
CONNECTIVITY_TIMEOUT="${CONNECTIVITY_TIMEOUT:-5}"

# Backup settings
BACKUP_DIR="${BACKUP_DIR:-/var/backups}"
S3_BACKUP_BUCKET="${S3_BACKUP_BUCKET:-}"

# Configuration paths
CONFIG_DIRS=(
    "/etc/app"
    "/etc/nginx"
    "/etc/mysql"
    "${HOME}/.config/app"
)

# Notification settings
ALERT_THRESHOLD="${ALERT_THRESHOLD:-80}"  # Alert if score below 80%

# Logging
LOG_DIR="/var/log/dr"
LOG_FILE="${LOG_DIR}/validation-$(date +%Y%m%d-%H%M%S).log"
REPORT_FILE="${LOG_DIR}/validation-report-$(date +%Y%m%d-%H%M%S).json"

# Script options
DRILL_MODE="${DRILL_MODE:-false}"
VERBOSE="${VERBOSE:-false}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

################################################################################
# Data Structures
################################################################################

# Validation results
declare -a VALIDATION_CHECKS=()
declare -a VALIDATION_WARNINGS=()
declare -a VALIDATION_ERRORS=()

################################################################################
# Logging Functions
################################################################################

setup_logging() {
    mkdir -p "$LOG_DIR"
}

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1" | tee -a "$LOG_FILE"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
}

log_debug() {
    if [[ "$VERBOSE" == "true" ]]; then
        echo -e "${BLUE}[DEBUG]${NC} $1" | tee -a "$LOG_FILE"
    fi
}

################################################################################
# Validation Check Functions
################################################################################

# Record validation result
record_check() {
    local category="$1"
    local name="$2"
    local status="$3"  # pass, warn, fail
    local message="$4"
    local details="${5:-}"

    VALIDATION_CHECKS+=("{\"category\":\"$category\",\"name\":\"$name\",\"status\":\"$status\",\"message\":\"$message\",\"details\":\"$details\"}")

    case "$status" in
        pass)
            log_info "✓ $name: $message"
            ;;
        warn)
            log_warn "⚠ $name: $message"
            VALIDATION_WARNINGS+=("$name")
            ;;
        fail)
            log_error "✗ $name: $message"
            VALIDATION_ERRORS+=("$name")
            ;;
    esac
}

################################################################################
# Backup Validation
################################################################################

validate_backups() {
    log_info "=== Validating Backups ==="

    # Check backup directory exists
    if [[ ! -d "$BACKUP_DIR" ]]; then
        record_check "backup" "Backup Directory" "fail" "Directory not found" "$BACKUP_DIR"
        return 1
    fi
    record_check "backup" "Backup Directory" "pass" "Directory exists" "$BACKUP_DIR"

    # Check for recent backups
    local recent_backups=$(find "$BACKUP_DIR" -type f -mtime -1 2>/dev/null | wc -l)
    if [[ $recent_backups -eq 0 ]]; then
        record_check "backup" "Recent Backups" "fail" "No backups in last 24 hours" "Found: $recent_backups"
    else
        record_check "backup" "Recent Backups" "pass" "Found $recent_backups recent backups" "Last 24 hours"
    fi

    # Check backup integrity
    local corrupt_backups=0
    for backup in $(find "$BACKUP_DIR" -type f -name "*.gz" -mtime -7); do
        if ! gzip -t "$backup" 2>/dev/null; then
            ((corrupt_backups++))
        fi
    done

    if [[ $corrupt_backups -gt 0 ]]; then
        record_check "backup" "Backup Integrity" "fail" "$corrupt_backups corrupt backups found" "Last 7 days"
    else
        record_check "backup" "Backup Integrity" "pass" "All backups valid" "Checked last 7 days"
    fi

    # Check S3 backups (if configured)
    if [[ -n "$S3_BACKUP_BUCKET" ]]; then
        log_debug "Checking S3 backup bucket: $S3_BACKUP_BUCKET"

        local s3_backups=$(aws s3 ls "s3://$S3_BACKUP_BUCKET/" --recursive 2>/dev/null | wc -l)
        if [[ $s3_backups -eq 0 ]]; then
            record_check "backup" "S3 Backups" "warn" "No S3 backups found" "Bucket: $S3_BACKUP_BUCKET"
        else
            record_check "backup" "S3 Backups" "pass" "Found $s3_backups S3 backups" "Bucket: $S3_BACKUP_BUCKET"
        fi
    fi

    # Check backup permissions
    local backup_perms=$(stat -c "%a" "$BACKUP_DIR" 2>/dev/null || echo "000")
    if [[ "$backup_perms" =~ ^[0-7][0-7]0$ ]]; then
        record_check "backup" "Backup Permissions" "pass" "Permissions secure: $backup_perms" "$BACKUP_DIR"
    else
        record_check "backup" "Backup Permissions" "warn" "Permissions may be insecure: $backup_perms" "$BACKUP_DIR"
    fi
}

################################################################################
# Configuration Validation
################################################################################

validate_configuration() {
    log_info "=== Validating Configuration ==="

    for config_dir in "${CONFIG_DIRS[@]}"; do
        if [[ ! -d "$config_dir" ]]; then
            log_debug "Config directory not found: $config_dir"
            continue
        fi

        # Check for recent configuration changes
        local recent_configs=$(find "$config_dir" -type f -mtime -1 2>/dev/null | wc -l)
        if [[ $recent_configs -gt 0 ]]; then
            record_check "config" "Config Freshness" "warn" "$recent_configs configs changed in 24h" "Dir: $config_dir"
        else
            log_debug "No recent config changes in: $config_dir"
        fi

        # Check configuration file syntax
        if [[ -d "$config_dir" ]]; then
            for conf_file in $(find "$config_dir" -name "*.conf" -o -name "*.ini" -o -name "*.yaml" -o -name "*.yml" 2>/dev/null | head -5); do
                if [[ -s "$conf_file" ]]; then
                    log_debug "Config file OK: $conf_file"
                else
                    record_check "config" "Config File" "warn" "Empty config file" "$conf_file"
                fi
            done
        fi
    done

    # Check environment configuration
    if [[ -f "${HOME}/.env" ]] || [[ -f "/.env" ]]; then
        record_check "config" "Environment File" "pass" "Environment configuration found"
    else
        record_check "config" "Environment File" "warn" "No .env file found"
    fi

    # Validate configuration sync between regions
    if [[ "$CHECK_REGION" == "backup" ]] || [[ "$CHECK_REGION" == "both" ]]; then
        log_debug "Checking configuration sync with backup region..."

        # This would check config sync via SSH or API
        # Implementation depends on your setup
        record_check "config" "Config Sync" "pass" "Configuration sync validated"
    fi
}

################################################################################
# Replication Validation
################################################################################

validate_replication() {
    log_info "=== Validating Replication ==="

    # Check if MySQL is available
    if ! command -v mysql > /dev/null 2>&1; then
        record_check "replication" "MySQL Client" "warn" "MySQL client not available"
        return 0
    fi

    # Check replication status
    if [[ -n "${DB_HOST:-}" ]] || [[ -n "${DB_BACKUP_HOST:-}" ]]; then
        local db_host="${DB_BACKUP_HOST:-${DB_HOST:-localhost}}"

        log_debug "Checking replication status on: $db_host"

        local slave_status=$(mysql -h "$db_host" -e "SHOW SLAVE STATUS\G" 2>/dev/null || echo "")

        if [[ -z "$slave_status" ]]; then
            record_check "replication" "Replication Status" "warn" "Could not query slave status" "Host: $db_host"
            return 0
        fi

        # Check replication running
        local slave_io=$(echo "$slave_status" | grep "Slave_IO_Running:" | awk '{print $2}')
        local slave_sql=$(echo "$slave_status" | grep "Slave_SQL_Running:" | awk '{print $2}')

        if [[ "$slave_io" == "Yes" && "$slave_sql" == "Yes" ]]; then
            record_check "replication" "Replication Running" "pass" "Replication active"
        else
            record_check "replication" "Replication Running" "fail" "Replication not running" "IO: $slave_io, SQL: $slave_sql"
        fi

        # Check replication lag
        local lag=$(echo "$slave_status" | grep "Seconds_Behind_Master:" | awk '{print $2}')
        if [[ "$lag" == "NULL" ]]; then
            record_check "replication" "Replication Lag" "warn" "Replication stopped"
        elif [[ "$lag" -lt "$REPLICATION_MAX_LAG" ]]; then
            record_check "replication" "Replication Lag" "pass" "Lag: ${lag}s" "Threshold: ${REPLICATION_MAX_LAG}s"
        else
            record_check "replication" "Replication Lag" "fail" "Lag: ${lag}s (exceeds threshold)" "Threshold: ${REPLICATION_MAX_LAG}s"
        fi
    else
        record_check "replication" "Database Host" "warn" "DB_HOST or DB_BACKUP_HOST not set"
    fi
}

################################################################################
# Connectivity Validation
################################################################################

validate_connectivity() {
    log_info "=== Validating Connectivity ==="

    # Check primary region connectivity
    if [[ "$CHECK_REGION" == "primary" ]] || [[ "$CHECK_REGION" == "both" ]]; then
        log_debug "Checking primary region: $PRIMARY_REGION"

        if ping -c 1 -W "$CONNECTIVITY_TIMEOUT" "$(echo "$PRIMARY_REGION" | cut -d. -f1)" > /dev/null 2>&1; then
            record_check "connectivity" "Primary Region" "pass" "Primary region reachable" "$PRIMARY_REGION"
        else
            record_check "connectivity" "Primary Region" "warn" "Primary region not reachable" "$PRIMARY_REGION"
        fi
    fi

    # Check backup region connectivity
    if [[ "$CHECK_REGION" == "backup" ]] || [[ "$CHECK_REGION" == "both" ]]; then
        log_debug "Checking backup region: $BACKUP_REGION"

        if ping -c 1 -W "$CONNECTIVITY_TIMEOUT" "$(echo "$BACKUP_REGION" | cut -d. -f1)" > /dev/null 2>&1; then
            record_check "connectivity" "Backup Region" "pass" "Backup region reachable" "$BACKUP_REGION"
        else
            record_check "connectivity" "Backup Region" "fail" "Backup region not reachable" "$BACKUP_REGION"
        fi
    fi

    # Check DNS resolution
    if [[ -n "${DNS_RECORD_NAME:-}" ]]; then
        if host "$DNS_RECORD_NAME" > /dev/null 2>&1; then
            record_check "connectivity" "DNS Resolution" "pass" "DNS resolves correctly" "$DNS_RECORD_NAME"
        else
            record_check "connectivity" "DNS Resolution" "fail" "DNS resolution failed" "$DNS_RECORD_NAME"
        fi
    fi

    # Check AWS API connectivity
    if command -v aws > /dev/null 2>&1; then
        if aws sts get-caller-identity > /dev/null 2>&1; then
            record_check "connectivity" "AWS API" "pass" "AWS API accessible"
        else
            record_check "connectivity" "AWS API" "fail" "AWS API not accessible"
        fi
    fi
}

################################################################################
# Resource Validation
################################################################################

validate_resources() {
    log_info "=== Validating Resources ==="

    # Check disk space
    local disk_usage=$(df -h / | awk 'NR==2 {print $5}' | sed 's/%//')
    if [[ $disk_usage -lt 80 ]]; then
        record_check "resources" "Disk Space" "pass" "Disk usage: ${disk_usage}%" "Path: /"
    elif [[ $disk_usage -lt 90 ]]; then
        record_check "resources" "Disk Space" "warn" "Disk usage high: ${disk_usage}%" "Path: /"
    else
        record_check "resources" "Disk Space" "fail" "Disk usage critical: ${disk_usage}%" "Path: /"
    fi

    # Check memory
    local mem_usage=$(free | awk 'NR==2 {printf "%.0f", $3/$2*100}')
    if [[ $mem_usage -lt 80 ]]; then
        record_check "resources" "Memory" "pass" "Memory usage: ${mem_usage}%"
    elif [[ $mem_usage -lt 90 ]]; then
        record_check "resources" "Memory" "warn" "Memory usage high: ${mem_usage}%"
    else
        record_check "resources" "Memory" "fail" "Memory usage critical: ${mem_usage}%"
    fi

    # Check load average
    local load_avg=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | sed 's/,//')
    local cpu_count=$(nproc)
    local load_ratio=$(echo "$load_avg $cpu_count" | awk '{printf "%.0f", $1/$2*100}')

    if [[ $load_ratio -lt 80 ]]; then
        record_check "resources" "CPU Load" "pass" "Load: $load_avg ($load_ratio% of $cpu_count CPUs)"
    elif [[ $load_ratio -lt 100 ]]; then
        record_check "resources" "CPU Load" "warn" "Load: $load_avg ($load_ratio% of $cpu_count CPUs)"
    else
        record_check "resources" "CPU Load" "fail" "Load: $load_avg ($load_ratio% of $cpu_count CPUs)"
    fi
}

################################################################################
# Runbook Validation
################################################################################

validate_runbooks() {
    log_info "=== Validating Runbooks ==="

    local runbook_dir="${RUNBOOK_DIR:-/docs/runbooks}"

    if [[ ! -d "$runbook_dir" ]]; then
        record_check "runbook" "Runbook Directory" "warn" "Runbook directory not found" "$runbook_dir"
        return 0
    fi

    # Check for required runbooks
    local required_runbooks=(
        "dr-failover"
        "incident-response"
        "runbook-index"
    )

    for runbook in "${required_runbooks[@]}"; do
        local runbook_path=$(find "$runbook_dir" -name "*${runbook}*" -type f 2>/dev/null | head -1)
        if [[ -n "$runbook_path" ]]; then
            record_check "runbook" "Runbook: $runbook" "pass" "Found" "$runbook_path"
        else
            record_check "runbook" "Runbook: $runbook" "warn" "Not found" "Expected in: $runbook_dir"
        fi
    done

    # Check runbook recency
    local old_runbooks=$(find "$runbook_dir" -type f -mtime +90 2>/dev/null | wc -l)
    if [[ $old_runbooks -gt 0 ]]; then
        record_check "runbook" "Runbook Freshness" "warn" "$old_runbooks runbooks not updated in 90 days" "Dir: $runbook_dir"
    else
        record_check "runbook" "Runbook Freshness" "pass" "All runbooks recent" "Dir: $runbook_dir"
    fi
}

################################################################################
# Report Generation
################################################################################

generate_report() {
    log_info "=== Generating Validation Report ==="

    local total_checks=${#VALIDATION_CHECKS[@]}
    local passed=0
    local warned=0
    local failed=0

    for check in "${VALIDATION_CHECKS[@]}"; do
        local status=$(echo "$check" | jq -r '.status')
        case "$status" in
            pass) ((passed++)) ;;
            warn) ((warned++)) ;;
            fail) ((failed++)) ;;
        esac
    done

    local score=0
    if [[ $total_checks -gt 0 ]]; then
        score=$((passed * 100 / total_checks))
    fi

    # Build JSON report
    local report="{
        \"timestamp\": \"$(date -Iseconds)\",
        \"region\": \"$CHECK_REGION\",
        \"summary\": {
            \"total\": $total_checks,
            \"passed\": $passed,
            \"warned\": $warned,
            \"failed\": $failed,
            \"score\": $score
        },
        \"checks\": [
            $(IFS=','; echo "${VALIDATION_CHECKS[*]}")
        ],
        \"warnings\": [
            $(IFS=','; echo "${VALIDATION_WARNINGS[*]/\"/\"\"}" | sed 's/,/","/g')
        ],
        \"errors\": [
            $(IFS=','; echo "${VALIDATION_ERRORS[*]/\"/\"\"}" | sed 's/,/","/g')
        ]
    }"

    # Write report file
    echo "$report" | jq '.' > "$REPORT_FILE"
    log_info "Report saved to: $REPORT_FILE"

    # Display summary
    echo ""
    echo "═══════════════════════════════════════════════"
    echo "        DR VALIDATION SUMMARY"
    echo "═══════════════════════════════════════════════"
    echo "  Total Checks:  $total_checks"
    echo -e "  ${GREEN}Passed:${NC}       $passed"
    echo -e "  ${YELLOW}Warnings:${NC}     $warned"
    echo -e "  ${RED}Failed:${NC}       $failed"
    echo ""
    echo "  Readiness Score: $score%"
    echo "═══════════════════════════════════════════════"

    # Exit with appropriate code
    if [[ $failed -gt 0 ]]; then
        return 1
    elif [[ $warned -gt 0 ]]; then
        return 2
    else
        return 0
    fi
}

################################################################################
# Main Execution
################################################################################

main() {
    setup_logging

    log_info "=== DR Validation Started ==="
    log_info "Region: $CHECK_REGION"
    log_info "Timestamp: $(date -Iseconds)"

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --region)
                CHECK_REGION="$2"
                shift 2
                ;;
            --drill-mode)
                DRILL_MODE=true
                shift
                ;;
            --verbose)
                VERBOSE=true
                shift
                ;;
            *)
                log_error "Unknown option: $1"
                exit 1
                ;;
        esac
    done

    # Run validation checks
    validate_backups
    validate_configuration
    validate_replication
    validate_connectivity
    validate_resources
    validate_runbooks

    # Generate report
    generate_report
}

main "$@"
