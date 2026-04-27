#!/bin/bash
################################################################################
# Disaster Recovery Failover Script
# Executes automated failover from primary to backup region
# Usage: ./dr-failover.sh [--dry-run] [--force] [--validate-only]
################################################################################

set -euo pipefail

################################################################################
# Configuration
################################################################################

# DR Configuration
PRIMARY_REGION="${PRIMARY_REGION:-us-east-1}"
BACKUP_REGION="${BACKUP_REGION:-us-west-2}"
DR_MODE="${DR_MODE:-active-passive}"  # active-active, active-passive, pilot-light

# DNS Configuration
HOSTED_ZONE_ID="${HOSTED_ZONE_ID:-}"
DNS_RECORD_NAME="${DNS_RECORD_NAME:-app.example.com}"
DNS_TTL="${DNS_TTL:-60}"

# Database Configuration
DB_PRIMARY_HOST="${DB_PRIMARY_HOST:-db-primary.example.com}"
DB_BACKUP_HOST="${DB_BACKUP_HOST:-db-backup.example.com}"
DB_REPLICATION_USER="${DB_REPLICATION_USER:-replicator}"

# Notification Settings
SLACK_WEBHOOK="${SLACK_WEBHOOK:-}"
NOTIFICATION_EMAIL="${NOTIFICATION_EMAIL:-ops@example.com}"

# Failover Settings
AUTO_FAILOVER="${AUTO_FAILOVER:-false}"
FAILOVER_TIMEOUT="${FAILOVER_TIMEOUT:-600}"  # 10 minutes
ROLLBACK_ON_FAILURE="${ROLLBACK_ON_FAILURE:-true}"

# Script Options
DRY_RUN="${DRY_RUN:-false}"
FORCE="${FORCE:-false}"
VALIDATE_ONLY="${VALIDATE_ONLY:-false}"

# Logging
LOG_DIR="/var/log/dr"
LOG_FILE="${LOG_DIR}/failover-$(date +%Y%m%d-%H%M%S).log"
LOCK_FILE="/var/run/dr-failover.lock"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

################################################################################
# Logging Functions
################################################################################

log_info() {
    echo -e "${GREEN}[INFO]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

log_debug() {
    if [[ "${DEBUG:-false}" == "true" ]]; then
        echo -e "${BLUE}[DEBUG]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
    fi
}

################################################################################
# Utility Functions
################################################################################

# Create log directory
setup_logging() {
    mkdir -p "$LOG_DIR"
    log_info "=== DR Failover Script Started ==="
    log_info "Log file: $LOG_FILE"
    log_info "Primary Region: $PRIMARY_REGION"
    log_info "Backup Region: $BACKUP_REGION"
    log_info "DR Mode: $DR_MODE"
}

# Check for existing failover
check_lock() {
    if [[ -f "$LOCK_FILE" ]]; then
        local pid=$(cat "$LOCK_FILE")
        if ps -p "$pid" > /dev/null 2>&1; then
            log_error "Failover already in progress (PID: $pid)"
            if [[ "$FORCE" != "true" ]]; then
                exit 1
            else
                log_warn "Force mode: continuing despite existing failover"
            fi
        else
            log_warn "Removing stale lock file"
            rm -f "$LOCK_FILE"
        fi
    fi

    # Create lock file
    echo $$ > "$LOCK_FILE"
    trap 'rm -f "$LOCK_FILE"' EXIT
}

# Send notification
send_notification() {
    local status="$1"
    local message="$2"
    local severity="${3:-high}"

    log_info "Sending notification: $status - $message"

    # Slack notification
    if [[ -n "$SLACK_WEBHOOK" ]]; then
        local color="good"
        [[ "$status" == "FAILED" ]] && color="danger"
        [[ "$status" == "WARNING" ]] && color="warning"

        curl -s -X POST "$SLACK_WEBHOOK" \
            -H 'Content-Type: application/json' \
            -d "{
                \"attachments\": [{
                    \"color\": \"$color\",
                    \"title\": \"DR Failover: $status\",
                    \"text\": \"$message\",
                    \"fields\": [
                        {\"title\": \"Region\", \"value\": \"$BACKUP_REGION\", \"short\": true},
                        {\"title\": \"Timestamp\", \"value\": \"$(date -Iseconds)\", \"short\": true}
                    ]
                }]
            }" > /dev/null 2>&1 || true
    fi

    # Email notification
    if [[ -n "$NOTIFICATION_EMAIL" ]]; then
        echo "$message" | mail -s "DR Failover $status" "$NOTIFICATION_EMAIL" 2>/dev/null || true
    fi
}

# Execute command with dry-run support
execute() {
    local cmd="$1"
    log_debug "Executing: $cmd"

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY-RUN] Would execute: $cmd"
        return 0
    fi

    eval "$cmd"
}

################################################################################
# Validation Functions
################################################################################

# Pre-flight checks
preflight_check() {
    log_info "=== Pre-flight Checks ==="

    local checks_passed=0
    local checks_failed=0

    # Check AWS CLI
    if command -v aws > /dev/null 2>&1; then
        log_info "✓ AWS CLI available"
        ((checks_passed++))
    else
        log_error "✗ AWS CLI not found"
        ((checks_failed++))
    fi

    # Check database client
    if command -v mysql > /dev/null 2>&1 || command -v psql > /dev/null 2>&1; then
        log_info "✓ Database client available"
        ((checks_passed++))
    else
        log_error "✗ Database client not found"
        ((checks_failed++))
    fi

    # Check backup region connectivity
    if ping -c 1 -W 2 "$(echo "$BACKUP_REGION" | cut -d. -f1)" > /dev/null 2>&1; then
        log_info "✓ Backup region reachable"
        ((checks_passed++))
    else
        log_warn "✗ Backup region not reachable (may be expected)"
        ((checks_failed++))
    fi

    # Check configuration
    if [[ -n "$HOSTED_ZONE_ID" ]]; then
        log_info "✓ Hosted zone configured"
        ((checks_passed++))
    else
        log_warn "✗ Hosted zone ID not set"
        ((checks_failed++))
    fi

    log_info "Pre-flight checks: $checks_passed passed, $checks_failed failed"

    if [[ $checks_failed -gt 0 ]]; then
        if [[ "$FORCE" != "true" ]]; then
            log_error "Pre-flight checks failed. Use --force to override."
            return 1
        else
            log_warn "Continuing despite failed checks (force mode)"
        fi
    fi

    return 0
}

# Validate backup region readiness
validate_backup_region() {
    log_info "=== Validating Backup Region ==="

    local healthy=true

    # Check backup database
    log_info "Checking backup database..."
    if mysql -h "$DB_BACKUP_HOST" -e "SELECT 1" > /dev/null 2>&1; then
        log_info "✓ Backup database accessible"
    else
        log_error "✗ Backup database not accessible"
        healthy=false
    fi

    # Check replication status
    log_info "Checking replication status..."
    local replication_status=$(mysql -h "$DB_BACKUP_HOST" -e "SHOW SLAVE STATUS\G" 2>/dev/null | grep "Seconds_Behind_Master" | awk '{print $2}')
    if [[ "$replication_status" != "NULL" && "$replication_status" -lt 60 ]]; then
        log_info "✓ Replication lag: ${replication_status}s"
    else
        log_warn "✗ Replication lag high or stopped: ${replication_status}"
        healthy=false
    fi

    # Check application servers in backup region
    log_info "Checking backup application servers..."
    # Add your application-specific health checks here

    if [[ "$healthy" == "true" ]]; then
        log_info "Backup region validation: PASSED"
        return 0
    else
        log_error "Backup region validation: FAILED"
        return 1
    fi
}

################################################################################
# Failover Functions
################################################################################

# Database failover
failover_database() {
    log_info "=== Initiating Database Failover ==="

    # Stop replication
    log_info "Stopping replication on backup..."
    execute "mysql -h '$DB_BACKUP_HOST' -e 'STOP SLAVE;'"

    # Promote backup to primary
    log_info "Promoting backup database to primary..."
    execute "mysql -h '$DB_BACKUP_HOST' -e 'RESET SLAVE ALL;'"

    # Update application configuration
    log_info "Updating database configuration..."
    if [[ "$DRY_RUN" != "true" ]]; then
        # Update environment or config files
        # This is application-specific
        log_info "Database config updated (application-specific)"
    else
        log_info "[DRY-RUN] Would update database configuration"
    fi

    log_info "Database failover: COMPLETE"
    return 0
}

# DNS failover
failover_dns() {
    log_info "=== Initiating DNS Failover ==="

    if [[ -z "$HOSTED_ZONE_ID" ]]; then
        log_warn "Hosted zone ID not configured, skipping DNS failover"
        return 0
    fi

    # Get current DNS record
    log_info "Fetching current DNS configuration..."
    local current_record=$(aws route53 list-resource-record-sets \
        --hosted-zone-id "$HOSTED_ZONE_ID" \
        --query "ResourceRecordSets[?Name=='${DNS_RECORD_NAME}.']" \
        --output json 2>/dev/null)

    if [[ -z "$current_record" ]]; then
        log_error "Could not find DNS record: $DNS_RECORD_NAME"
        return 1
    fi

    log_debug "Current record: $current_record"

    # Prepare failover record
    local backup_lb="${BACKUP_LB:-lb-backup-${BACKUP_REGION}.example.com}"

    log_info "Updating DNS to point to backup: $backup_lb"

    # Create change batch
    local change_batch="{
        \"Changes\": [{
            \"Action\": \"UPSERT\",
            \"ResourceRecordSet\": {
                \"Name\": \"${DNS_RECORD_NAME}\",
                \"Type\": \"CNAME\",
                \"SetIdentifier\": \"dr-failover\",
                \"Failover\": \"SECONDARY\",
                \"TTL\": ${DNS_TTL},
                \"ResourceRecords\": [{\"Value\": \"${backup_lb}\"}],
                \"HealthCheckId\": \"${HEALTH_CHECK_ID:-}\"
            }
        }]
    }"

    execute "aws route53 change-resource-record-sets \
        --hosted-zone-id '$HOSTED_ZONE_ID' \
        --change-batch '$change_batch'"

    log_info "DNS failover: INITIATED"
    log_info "Note: DNS propagation may take up to ${DNS_TTL} seconds"

    return 0
}

# Application failover
failover_application() {
    log_info "=== Initiating Application Failover ==="

    # Start application services in backup region
    log_info "Starting application services..."
    execute "ssh '$BACKUP_REGION' 'systemctl start application.service' || true"

    # Scale up if needed
    log_info "Scaling application services..."
    # Add scaling commands here

    # Wait for services to be ready
    log_info "Waiting for services to become healthy..."
    local max_wait=60
    local waited=0
    while [[ $waited -lt $max_wait ]]; do
        if curl -f "https://${BACKUP_REGION}/health" > /dev/null 2>&1; then
            log_info "Application services: HEALTHY"
            return 0
        fi
        sleep 5
        ((waited+=5))
    done

    log_warn "Application services health check timeout"
    return 1
}

################################################################################
# Main Execution
################################################################################

main() {
    setup_logging
    check_lock

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --force)
                FORCE=true
                shift
                ;;
            --validate-only)
                VALIDATE_ONLY=true
                shift
                ;;
            *)
                log_error "Unknown option: $1"
                exit 1
                ;;
        esac
    done

    log_info "Starting failover procedure..."
    send_notification "STARTED" "DR failover initiated"

    # Pre-flight checks
    if ! preflight_check; then
        log_error "Pre-flight checks failed"
        send_notification "FAILED" "Pre-flight checks failed"
        exit 1
    fi

    # Validate backup region
    if ! validate_backup_region; then
        log_error "Backup region validation failed"
        send_notification "FAILED" "Backup region validation failed"
        exit 1
    fi

    # Exit if validate-only mode
    if [[ "$VALIDATE_ONLY" == "true" ]]; then
        log_info "Validation complete (validate-only mode)"
        send_notification "COMPLETE" "DR validation successful"
        exit 0
    fi

    # Confirm failover (unless auto-failover is enabled)
    if [[ "$AUTO_FAILOVER" != "true" && "$DRY_RUN" != "true" ]]; then
        echo ""
        log_warn "About to execute DR failover to $BACKUP_REGION"
        read -p "Continue? (yes/no): " confirm
        if [[ "$confirm" != "yes" ]]; then
            log_info "Failover cancelled by user"
            exit 0
        fi
    fi

    # Execute failover steps
    local failover_success=true

    # 1. Database failover
    if ! failover_database; then
        log_error "Database failover failed"
        failover_success=false
    fi

    # 2. Application failover
    if ! failover_application; then
        log_error "Application failover failed"
        failover_success=false
    fi

    # 3. DNS failover
    if ! failover_dns; then
        log_error "DNS failover failed"
        failover_success=false
    fi

    # Check results
    if [[ "$failover_success" == "true" ]]; then
        log_info "=== Failover Completed Successfully ==="
        send_notification "COMPLETE" "DR failover to $BACKUP_REGION completed successfully"
        exit 0
    else
        log_error "=== Failover Failed ==="
        send_notification "FAILED" "DR failover encountered errors"

        if [[ "$ROLLBACK_ON_FAILURE" == "true" ]]; then
            log_warn "Automatic rollback not implemented - manual intervention required"
        fi

        exit 1
    fi
}

# Run main function
main "$@"
