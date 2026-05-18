#!/bin/bash
################################################################################
# Disaster Recovery Notification Script
# Sends DR notifications to stakeholders via various channels
# Usage: ./dr-notify.sh --type <type> --severity <level> --message <text>
################################################################################

set -euo pipefail

################################################################################
# Configuration
################################################################################

# Notification channels
ENABLE_SLACK="${ENABLE_SLACK:-true}"
ENABLE_EMAIL="${ENABLE_EMAIL:-true}"
ENABLE_SMS="${ENABLE_SMS:-false}"
ENABLE_STATUS_PAGE="${ENABLE_STATUS_PAGE:-true}"

# Channel endpoints
SLACK_WEBHOOK="${SLACK_WEBHOOK:-}"
STATUS_PAGE_API="${STATUS_PAGE_API:-}"
STATUS_PAGE_ID="${STATUS_PAGE_ID:-}"

# Email settings
SMTP_SERVER="${SMTP_SERVER:-}"
SMTP_PORT="${SMTP_PORT:-587}"
SMTP_USER="${SMTP_USER:-}"
SMTP_PASS="${SMTP_PASS:-}"
NOTIFICATION_FROM="${NOTIFICATION_FROM:-noreply@example.com}"

# SMS settings (Twilio)
TWILIO_ACCOUNT_SID="${TWILIO_ACCOUNT_SID:-}"
TWILIO_AUTH_TOKEN="${TWILIO_AUTH_TOKEN:-}"
TWILIO_FROM_NUMBER="${TWILIO_FROM_NUMBER:-}"

# Stakeholder contacts (comma-separated)
EXECUTIVE_TEAM_EMAILS="${EXECUTIVE_TEAM_EMAILS:-}"
ENGINEERING_EMAILS="${ENGINEERING_EMAILS:-ops@example.com}"
SUPPORT_EMAILS="${SUPPORT_EMAILS:-support@example.com}"
CUSTOMER_EMAILS="${CUSTOMER_EMAILS:-}"

# Phone numbers for SMS
ON_CALL_PHONE="${ON_CALL_PHONE:-}"
EXECUTIVE_PHONES="${EXECUTIVE_PHONES:-}"

# Notification settings
NOTIFICATION_LOG="/var/log/dr/notifications.log"
RETENTION_DAYS="${RETENTION_DAYS:-90}"

# Script options
DRY_RUN="${DRY_RUN:-false}"
VERBOSE="${VERBOSE:-false}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

################################################################################
# Logging Functions
################################################################################

log_info() {
    echo -e "${GREEN}[INFO]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$NOTIFICATION_LOG"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$NOTIFICATION_LOG"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$NOTIFICATION_LOG"
}

log_debug() {
    if [[ "$VERBOSE" == "true" ]]; then
        echo -e "${BLUE}[DEBUG]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
    fi
}

################################################################################
# Notification Functions
################################################################################

# Send Slack notification
send_slack() {
    local status="$1"
    local message="$2"
    local severity="${3:-high}"

    if [[ "$ENABLE_SLACK" != "true" ]]; then
        return 0
    fi

    if [[ -z "$SLACK_WEBHOOK" ]]; then
        log_warn "Slack webhook not configured"
        return 1
    fi

    log_info "Sending Slack notification..."

    local color="good"
    local emoji=":white_check_mark:"

    case "$severity" in
        critical)
            color="danger"
            emoji=":rotating_light:"
            ;;
        high)
            color="danger"
            emoji=":warning:"
            ;;
        medium)
            color="warning"
            emoji=":warning:"
            ;;
        low)
            color="good"
            emoji=":information_source:"
            ;;
    esac

    local payload="{
        \"username\": \"DR Notifications\",
        \"icon_emoji\": \"$emoji\",
        \"attachments\": [{
            \"color\": \"$color\",
            \"title\": \"DR Event: $status\",
            \"text\": \"$message\",
            \"fields\": [
                {\"title\": \"Severity\", \"value\": \"$severity\", \"short\": true},
                {\"title\": \"Timestamp\", \"value\": \"$(date -Iseconds)\", \"short\": true}
            ],
            \"footer\": \"Disaster Recovery System\",
            \"ts\": $(date +%s)
        }]
    }"

    if [[ "$DRY_RUN" != "true" ]]; then
        if curl -s -X POST "$SLACK_WEBHOOK" \
            -H 'Content-Type: application/json' \
            -d "$payload" > /dev/null 2>&1; then
            log_info "Slack notification sent"
            return 0
        else
            log_error "Failed to send Slack notification"
            return 1
        fi
    else
        log_info "[DRY-RUN] Would send to Slack: $message"
        return 0
    fi
}

# Send email notification
send_email() {
    local to="$1"
    local subject="$2"
    local body="$3"

    if [[ "$ENABLE_EMAIL" != "true" ]]; then
        return 0
    fi

    if [[ -z "$to" ]]; then
        log_debug "No recipients for email"
        return 0
    fi

    log_info "Sending email to: $to"

    if [[ "$DRY_RUN" != "true" ]]; then
        if echo "$body" | mail -s "$subject" -a "From: $NOTIFICATION_FROM" "$to" 2>/dev/null; then
            log_info "Email sent successfully"
            return 0
        else
            log_warn "Failed to send email (mail command may not be configured)"
            return 1
        fi
    else
        log_info "[DRY-RUN] Would send email to: $to"
        log_debug "Subject: $subject"
        log_debug "Body: $body"
        return 0
    fi
}

# Send SMS notification
send_sms() {
    local to="$1"
    local message="$2"

    if [[ "$ENABLE_SMS" != "true" ]]; then
        return 0
    fi

    if [[ -z "$TWILIO_ACCOUNT_SID" ]] || [[ -z "$TWILIO_AUTH_TOKEN" ]]; then
        log_warn "Twilio not configured"
        return 1
    fi

    log_info "Sending SMS to: $to"

    if [[ "$DRY_RUN" != "true" ]]; then
        local url="https://api.twilio.com/2010-04-01/Accounts/${TWILIO_ACCOUNT_SID}/Messages.json"
        local response=$(curl -s -X POST "$url" \
            --data-urlencode "From=$TWILIO_FROM_NUMBER" \
            --data-urlencode "To=$to" \
            --data-urlencode "Body=$message" \
            -u "${TWILIO_ACCOUNT_SID}:${TWILIO_AUTH_TOKEN}")

        if echo "$response" | grep -q '"status": "queued"'; then
            log_info "SMS sent successfully"
            return 0
        else
            log_error "Failed to send SMS"
            return 1
        fi
    else
        log_info "[DRY-RUN] Would send SMS to: $to"
        return 0
    fi
}

# Update status page
update_status_page() {
    local incident_id="$1"
    local status="$2"
    local message="$3"

    if [[ "$ENABLE_STATUS_PAGE" != "true" ]]; then
        return 0
    fi

    if [[ -z "$STATUS_PAGE_API" ]] || [[ -z "$STATUS_PAGE_ID" ]]; then
        log_warn "Status page not configured"
        return 1
    fi

    log_info "Updating status page..."

    if [[ "$DRY_RUN" != "true" ]]; then
        local status_page_status="investigating"
        case "$status" in
            DETECTED|DECLARATION) status_page_status="investigating" ;;
            UPDATE) status_page_status="identified" ;;
            RESOLVED) status_page_status="resolved" ;;
            POSTMORTEM) status_page_status="completed" ;;
        esac

        curl -s -X PATCH "${STATUS_PAGE_API}/pages/${STATUS_PAGE_ID}/incidents/${incident_id}" \
            -H "Authorization: Bearer ${STATUS_PAGE_API}" \
            -H "Content-Type: application/json" \
            -d "{
                \"incident\": {
                    \"status\": \"$status_page_status\",
                    \"body\": \"$message\"
                }
            }" > /dev/null 2>&1 || true

        log_info "Status page updated"
    else
        log_info "[DRY-RUN] Would update status page"
    fi

    return 0
}

################################################################################
# Notification Routing
################################################################################

route_notification() {
    local type="$1"
    local severity="$2"
    local message="$3"

    log_info "Routing notification: type=$type, severity=$severity"

    case "$type" in
        detection|DECLARATION)
            # Critical notifications - all channels
            send_slack "DR INCIDENT DECLARED" "$message" "$severity"

            if [[ "$severity" == "critical" ]]; then
                send_sms "$ON_CALL_PHONE" "DR ALERT: $message" 2>/dev/null || true
                for phone in ${EXECUTIVE_PHONES//,/ }; do
                    send_sms "$phone" "DR ALERT: $message" 2>/dev/null || true
                done
            fi

            send_email "$ENGINEERING_EMAILS" "[DR ALERT] $type" "$message"
            send_email "$EXECUTIVE_TEAM_EMAILS" "[DR ALERT] $type" "$message" 2>/dev/null || true
            send_email "$SUPPORT_EMAILS" "[DR ALERT] Customer Impact - $type" "$message" 2>/dev/null || true
            ;;

        update|UPDATE)
            # Progress updates - Slack + email
            send_slack "DR STATUS UPDATE" "$message" "$severity"
            send_email "$ENGINEERING_EMAILS" "[DR UPDATE] $type" "$message"
            ;;

        resolved|RESOLVED)
            # Resolution - all channels
            send_slack "DR INCIDENT RESOLVED" "$message" "low"
            send_email "$ENGINEERING_EMAILS" "[DR RESOLVED] $type" "$message"
            send_email "$EXECUTIVE_TEAM_EMAILS" "[DR RESOLVED] $type" "$message" 2>/dev/null || true
            send_email "$SUPPORT_EMAILS" "[DR RESOLVED] Service Restored" "$message" 2>/dev/null || true
            send_email "$CUSTOMER_EMAILS" "Service Restored" "$message" 2>/dev/null || true
            ;;

        postmortem|POSTMORTEM)
            # Post-incident review - email only
            send_email "$ENGINEERING_EMAILS" "[DR POST-MORTEM] $type" "$message"
            send_email "$EXECUTIVE_TEAM_EMAILS" "[DR POST-MORTEM] $type" "$message" 2>/dev/null || true
            ;;

        pre-failover)
            # Pre-failover warning - internal only
            send_slack "DR FAILOVER WARNING" "$message" "medium"
            send_email "$ENGINEERING_EMAILS" "[DR WARNING] Failover Imminent" "$message"
            ;;

        drill-start)
            # Drill notification - internal
            send_slack "DR DRILL STARTED" "$message" "low"
            send_email "$ENGINEERING_EMAILS" "[DR DRILL] $type" "$message"
            ;;

        drill-complete)
            # Drill completion - internal
            send_slack "DR DRILL COMPLETED" "$message" "low"
            send_email "$ENGINEERING_EMAILS" "[DR DRILL] $type" "$message"
            ;;

        *)
            log_warn "Unknown notification type: $type"
            ;;
    esac
}

################################################################################
# Template Generation
################################################################################

# Generate customer notification template
generate_customer_template() {
    local incident_id="$1"
    local status="$2"
    local message="$3"
    local eta="${4:-Unknown}"

    cat <<EOF
Subject: Service Incident Update - $incident_id

Dear Customer,

We are currently experiencing a service interruption. This message is to inform you of the current status and our efforts to resolve the issue.

**Incident Status:** $status

**Impact:**
$message

**Current Actions:**
Our team is actively working to restore full service. We have initiated our disaster recovery procedures to minimize disruption.

**Estimated Resolution:**
$eta

**Next Update:**
We will provide the next update in 30 minutes or sooner if there are significant developments.

We apologize for any inconvenience this may cause and appreciate your patience.

Thank you,
The Operations Team
EOF
}

# Generate executive summary template
generate_executive_template() {
    local incident_id="$1"
    local severity="$2"
    local impact="$3"
    local actions="$4"
    local rto_target="${5:-Unknown}"

    cat <<EOF
Subject: EXECUTIVE BRIEFING - DR Incident $incident_id

SEVERITY: $severity

INCIDENT SUMMARY:
$impact

BUSINESS IMPACT:
- User Impact: [To be determined]
- Revenue Impact: [To be determined]
- SLA Impact: [To be determined]

CURRENT ACTIONS:
$actions

TIMELINE:
- Detected: [Timestamp]
- Declared: [Timestamp]
- Current Status: In Progress

RECOVERY TARGET:
RTO: $rto_target

NEXT UPDATE: 30 minutes
EOF
}

################################################################################
# Main Execution
################################################################################

main() {
    mkdir -p "$(dirname "$NOTIFICATION_LOG")"

    local type=""
    local severity="high"
    local message=""
    local incident_id=""

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --type)
                type="$2"
                shift 2
                ;;
            --severity)
                severity="$2"
                shift 2
                ;;
            --message)
                message="$2"
                shift 2
                ;;
            --incident-id)
                incident_id="$2"
                shift 2
                ;;
            --dry-run)
                DRY_RUN=true
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

    # Validate required parameters
    if [[ -z "$type" ]] || [[ -z "$message" ]]; then
        log_error "Missing required parameters: --type and --message are required"
        echo "Usage: $0 --type <type> --severity <level> --message <text> [--incident-id <id>]"
        exit 1
    fi

    log_info "=== DR Notification ==="
    log_info "Type: $type"
    log_info "Severity: $severity"
    log_info "Message: $message"

    # Route notification
    route_notification "$type" "$severity" "$message"

    # Update status page if incident ID provided
    if [[ -n "$incident_id" ]]; then
        update_status_page "$incident_id" "$type" "$message"
    fi

    log_info "=== Notification Complete ==="
}

main "$@"
