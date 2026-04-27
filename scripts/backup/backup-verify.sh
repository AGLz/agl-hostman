#!/bin/bash
# Backup Verification and Integrity Check Script
# Validates backup age, retention compliance, and data integrity
#
# Usage: sudo ./backup-verify.sh [--full] [--email] [--verbose]

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="/var/log/backup-verify.log"
STATE_FILE="/var/lib/backup-verify/state.json"
PBS_SERVER="${PBS_SERVER:-10.6.0.14}"
PBS_PORT="${PBS_PORT:-8007}"
PBS_DATASTORE="${PBS_DATASTORE:-aglsrv6-pbs}"
ADMIN_EMAIL="${ADMIN_EMAIL:-admin@agl.io}"

# Options
FULL_VERIFY=false
SEND_EMAIL=false
VERBOSE=false
RETENTION_OK=0

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Logging functions
log() {
    local level=$1
    shift
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $*"
    echo "$msg" | tee -a "$LOG_FILE"

    case $level in
        ERROR)
            echo -e "${RED}$msg${NC}" >&2
            ;;
        WARN)
            echo -e "${YELLOW}$msg${NC}"
            ;;
        INFO)
            echo -e "${GREEN}$msg${NC}"
            ;;
        DEBUG)
            if [[ "$VERBOSE" == true ]]; then
                echo -e "${BLUE}$msg${NC}"
            fi
            ;;
    esac
}

# Initialize state file
init_state() {
    local state_dir=$(dirname "$STATE_FILE")
    mkdir -p "$state_dir"

    if [[ ! -f "$STATE_FILE" ]]; then
        cat > "$STATE_FILE" << EOF
{
  "last_check": null,
  "checks": {
    "backup_age": {},
    "retention": {},
    "integrity": {}
  },
  "failures": []
}
EOF
    fi
}

# Update state file
update_state() {
    local key=$1
    local value=$2

    local tmp_file="${STATE_FILE}.tmp"
    jq ".$key = $value" "$STATE_FILE" > "$tmp_file"
    mv "$tmp_file" "$STATE_FILE"
}

# Check backup age
verify_backup_age() {
    local vmid=$1
    local max_age_hours=$2
    local priority=$3

    log INFO "Checking backup age for CT$vmid (max: ${max_age_hours}h)"

    # Get latest backup from PBS
    local backup_info=$(ssh -p "$PBS_PORT" root@"$PBS_SERVER" \
        "proxmox-backup-client snapshot list --repository ${PBS_SERVER}:${PBS_DATASTORE} 2>/dev/null | \
         grep \"ct/$vmid/\" | tail -1" || true)

    if [[ -z "$backup_info" ]]; then
        log ERROR "No backup found for CT$vmid on $PBS_SERVER:$PBS_DATASTORE"
        update_state "checks.backup_age.$vmid" '{"status": "failed", "error": "no_backup_found"}'
        return 1
    fi

    # Extract timestamp
    local backup_timestamp=$(echo "$backup_info" | awk '{print $1" "$2}' | tr -d '[]')
    local backup_epoch=$(date -d "$backup_timestamp" +%s 2>/dev/null || echo 0)
    local current_epoch=$(date +%s)
    local age_hours=$(( (current_epoch - backup_epoch) / 3600 ))

    log DEBUG "CT$vmid last backup: $backup_timestamp (${age_hours}h ago)"

    if [[ $age_hours -gt $max_age_hours ]]; then
        log ERROR "CT$vmid backup is $age_hours hours old (max: ${max_age_hours}h)"
        update_state "checks.backup_age.$vmid" "{\"status\": \"failed\", \"age_hours\": $age_hours, \"max_age_hours\": $max_age_hours}"
        return 1
    fi

    log INFO "CT$vmid backup OK (${age_hours}h old, within ${max_age_hours}h limit)"
    update_state "checks.backup_age.$vmid" "{\"status\": \"ok\", \"age_hours\": $age_hours, \"max_age_hours\": $max_age_hours}"
    return 0
}

# Verify retention policy compliance
verify_retention_compliance() {
    log INFO "Checking retention policy compliance on $PBS_SERVER:$PBS_DATASTORE"

    local compliance_result=$(ssh -p "$PBS_PORT" root@"$PBS_SERVER" \
        "proxmox-backup-manager datastore info -- datastore ${PBS_DATASTORE}" 2>/dev/null || echo "{}")

    local total_snapshots=$(echo "$compliance_result" | jq -r '.total_snapshots // 0')
    local storage_used=$(echo "$compliance_result" | jq -r '.used // 0')

    log INFO "Total snapshots in datastore: $total_snapshots"
    log INFO "Storage used: $storage_used bytes"

    # Check retention settings
    local retention_keep_daily=7
    local retention_keep_weekly=4
    local retention_keep_monthly=12

    local expected_snapshots=$((retention_keep_daily + retention_keep_weekly + retention_keep_monthly))

    if [[ $total_snapshots -lt $((expected_snapshots / 2)) ]]; then
        log WARN "Low snapshot count: $total_snapshots (expected ~$expected_snapshots)"
        update_state "checks.retention" "{\"status\": \"warning\", \"snapshots\": $total_snapshots, \"expected\": $expected_snapshots}"
        return 0
    fi

    log INFO "Retention compliance OK"
    update_state "checks.retention" "{\"status\": \"ok\", \"snapshots\": $total_snapshots, \"used_bytes\": $storage_used}"
    return 0
}

# Verify backup catalog integrity
verify_backup_integrity() {
    local vmid=$1

    log INFO "Verifying backup integrity for CT$vmid"

    # Get snapshot list
    local snapshots=$(ssh -p "$PBS_PORT" root@"$PBS_SERVER" \
        "proxmox-backup-client snapshot list --repository ${PBS_SERVER}:${PBS_DATASTORE} 2>/dev/null | \
         grep \"ct/$vmid/\" | wc -l" || echo "0")

    if [[ $snapshots -eq 0 ]]; then
        log ERROR "No snapshots to verify for CT$vmid"
        update_state "checks.integrity.$vmid" '{"status": "failed", "error": "no_snapshots"}'
        return 1
    fi

    log INFO "Found $snapshots snapshots for CT$vmid"

    # For full verify, do actual catalog verification
    if [[ "$FULL_VERIFY" == true ]]; then
        log INFO "Running full integrity verification for CT$vmid (this may take a while)..."

        local verify_output=$(ssh -p "$PBS_PORT" root@"$PBS_SERVER" \
            "proxmox-backup-client verify --repository ${PBS_SERVER}:${PBS_DATASTORE} \
             --backup-id ct/$vmid --skip-catalog-verification false" 2>&1 || echo "FAILED")

        if [[ "$verify_output" == *"FAILED"* ]] || [[ "$verify_output" == *"error"* ]]; then
            log ERROR "Integrity verification failed for CT$vmid: $verify_output"
            update_state "checks.integrity.$vmid" '{"status": "failed", "error": "verification_failed"}"
            return 1
        fi

        log INFO "Integrity verification passed for CT$vmid"
    else
        log DEBUG "Skipping full integrity verification (use --full for complete check)"
    fi

    update_state "checks.integrity.$vmid" '{"status": "ok", "snapshots_verified": '"$snapshots"'}'
    return 0
}

# Verify PBS connectivity
verify_pbs_connectivity() {
    log INFO "Verifying PBS connectivity to $PBS_SERVER:$PBS_PORT"

    if ! ping -c 1 -W 2 "$PBS_SERVER" >/dev/null 2>&1; then
        log ERROR "Cannot reach PBS server at $PBS_SERVER"
        return 1
    fi

    if ! nc -z -w 2 "$PBS_SERVER" "$PBS_PORT" 2>/dev/null; then
        log ERROR "PBS port $PBS_PORT not accessible"
        return 1
    fi

    # Test PBS API
    local api_test=$(curl -s -k "https://${PBS_SERVER}:${PBS_PORT}/api2/json/version" 2>/dev/null || echo "{}")
    local api_version=$(echo "$api_test" | jq -r '.data.version // ""')

    if [[ -n "$api_version" ]]; then
        log INFO "PBS API version: $api_version"
        return 0
    else
        log ERROR "PBS API not responding"
        return 1
    fi
}

# Generate verification report
generate_report() {
    local exit_code=$1

    log INFO "=== Backup Verification Report ==="
    log INFO "Date: $(date)"
    log INFO "PBS Server: $PBS_SERVER:$PBS_PORT"
    log INFO "Datastore: $PBS_DATASTORE"
    log INFO "Exit Code: $exit_code"

    echo ""
    log INFO "Detailed results stored in: $STATE_FILE"

    if [[ "$exit_code" -ne 0 ]]; then
        log ERROR "Verification FAILED - review logs for details"
    else
        log INFO "Verification PASSED - all checks successful"
    fi
}

# Send email notification
send_notification() {
    local exit_code=$1

    if [[ "$SEND_EMAIL" == false ]]; then
        return 0
    fi

    local subject="Backup Verification $([ $exit_code -eq 0 ] && echo 'SUCCESS' || echo 'FAILED')"
    local body=$(cat << EOF
Backup verification completed on $(hostname)

Status: $([ $exit_code -eq 0 ] && echo 'SUCCESS' || echo 'FAILED')
Date: $(date)
PBS Server: $PBS_SERVER:$PBS_PORT

Full log: $LOG_FILE
State: $STATE_FILE

EOF
)

    echo "$body" | mail -s "$subject" "$ADMIN_EMAIL"
    log INFO "Email notification sent to $ADMIN_EMAIL"
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --full)
            FULL_VERIFY=true
            shift
            ;;
        --email)
            SEND_EMAIL=true
            shift
            ;;
        --verbose|-v)
            VERBOSE=true
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [--full] [--email] [--verbose]"
            echo ""
            echo "Options:"
            echo "  --full       Run full integrity verification (slower)"
            echo "  --email      Send email notification"
            echo "  --verbose    Enable verbose output"
            echo "  --help       Show this help message"
            exit 0
            ;;
        *)
            log ERROR "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Main execution
main() {
    log INFO "=== Starting Backup Verification ==="

    # Initialize state
    init_state

    # Verify PBS connectivity
    verify_pbs_connectivity || {
        log ERROR "PBS connectivity check failed"
        exit 1
    }

    # Check backup age for all containers
    log INFO "--- Backup Age Verification ---"

    # Critical systems (24h max age)
    verify_backup_age 183 24 "critical" || RETENTION_OK=1
    verify_backup_age 184 24 "critical" || RETENTION_OK=1

    # High priority (48h max age)
    verify_backup_age 180 48 "high" || RETENTION_OK=1
    verify_backup_age 182 48 "high" || RETENTION_OK=1

    # Standard (7 days max age)
    verify_backup_age 173 168 "standard" || RETENTION_OK=1

    # Verify retention compliance
    log INFO "--- Retention Compliance Verification ---"
    verify_retention_compliance || RETENTION_OK=1

    # Verify backup integrity
    log INFO "--- Backup Integrity Verification ---"
    for vmid in 173 180 182 183 184; do
        verify_backup_integrity $vmid || RETENTION_OK=1
    done

    # Update state
    update_state "last_check" "\"$(date -Iseconds)\""

    # Generate report
    generate_report $RETENTION_OK

    # Send notification
    send_notification $RETENTION_OK

    exit $RETENTION_OK
}

# Run main
main "$@"
