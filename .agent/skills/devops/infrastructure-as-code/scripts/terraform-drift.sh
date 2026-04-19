#!/bin/bash
# Check infrastructure drift by comparing actual state with Terraform configuration
# Usage: ./scripts/terraform-drift.sh [environment] [create-issue]

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Default values
ENVIRONMENT="${1:-prod}"
CREATE_ISSUE="${2:-false}"
PLAN_FILE="drift-plan-${ENVIRONMENT}"
REPORT_FILE="drift-report-${ENVIRONMENT}.json"
SUMMARY_FILE="drift-summary-${ENVIRONMENT}.txt"
GITHUB_REPO="${GITHUB_REPO:-}"
GITHUB_TOKEN="${GITHUB_TOKEN:-}"

# Functions
log_info() {
  echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
  echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
  echo -e "${RED}[ERROR]${NC} $1"
}

log_drift() {
  echo -e "${BLUE}[DRIFT]${NC} $1"
}

check_terraform() {
  if ! command -v terraform &> /dev/null; then
    log_error "Terraform is not installed"
    exit 1
  fi
}

check_environment() {
  if [[ ! -d "environments/${ENVIRONMENT}" ]]; then
    log_error "Environment not found: $ENVIRONMENT"
    exit 1
  fi
}

initialize_terraform() {
  log_info "Initializing Terraform..."

  if [[ ! -d ".terraform" ]]; then
    ./scripts/tf-init.sh "$ENVIRONMENT"
  fi
}

refresh_state() {
  log_info "Refreshing Terraform state..."

  terraform refresh \
    -var-file="environments/${ENVIRONMENT}/terraform.tfvars" \
    -lock-timeout=5m

  log_info "State refreshed"
}

check_drift() {
  log_info "Checking for infrastructure drift..."

  terraform plan \
    -var-file="environments/${ENVIRONMENT}/terraform.tfvars" \
    -refresh-only \
    -out="$PLAN_FILE" \
    -detailed-exitcode

  local exit_code=$?

  case $exit_code in
    0)
      log_info "✅ No drift detected"
      return 0
      ;;
    1)
      log_error "Drift check failed"
      return 1
      ;;
    2)
      log_warn "⚠️  Drift detected!"
      return 2
      ;;
  esac
}

generate_report() {
  log_info "Generating drift report..."

  terraform show -json "$PLAN_FILE" > "$REPORT_FILE"

  # Extract drift details
  local drifted_resources=$(jq -r '
    .resource_changes[] |
    select(.change.actions != ["no-op"]) |
    "\(.address): \(.change.actions | join(", "))"
  ' "$REPORT_FILE")

  local drift_count=$(echo "$drifted_resources" | wc -l)

  cat > "$SUMMARY_FILE" <<EOF
# Infrastructure Drift Report

**Environment:** $ENVIRONMENT
**Timestamp:** $(date -u +"%Y-%m-%dT%H:%M:%SZ")
**Drifted Resources:** $drift_count

## Drifted Resources

$drifted_resources

## Details

Run \`terraform show $PLAN_FILE\` for full details.
EOF

  log_info "Report saved to: $SUMMARY_FILE"
  log_drift "$drifted_resources"

  return "$drift_count"
}

create_github_issue() {
  if [[ "$CREATE_ISSUE" != "true" ]]; then
    return 0
  fi

  if [[ -z "$GITHUB_REPO" ]] || [[ -z "$GITHUB_TOKEN" ]]; then
    log_warn "GitHub integration not configured"
    log_warn "Set GITHUB_REPO and GITHUB_TOKEN environment variables"
    return 0
  fi

  log_info "Creating GitHub issue..."

  local drift_count=$(wc -l < "$SUMMARY_FILE")
  local title="Infrastructure Drift Detected: ${ENVIRONMENT}"
  local body=$(cat "$SUMMARY_FILE")

  local response=$(curl -s -X POST \
    -H "Authorization: token $GITHUB_TOKEN" \
    -H "Accept: application/vnd.github.v3+json" \
    "https://api.github.com/repos/${GITHUB_REPO}/issues" \
    -d "{
      \"title\": \"${title}\",
      \"body\": $(echo "$body" | jq -Rs .),
      \"labels\": [\"drift\", \"infrastructure\", \"${ENVIRONMENT}\"]
    }")

  local issue_url=$(echo "$response" | jq -r '.html_url')

  if [[ "$issue_url" != "null" ]]; then
    log_info "✅ Issue created: $issue_url"
  else
    log_error "Failed to create issue"
    echo "$response" | jq -r '.message // "Unknown error"'
  fi
}

notify_slack() {
  if [[ -z "${SLACK_WEBHOOK_URL:-}" ]]; then
    return 0
  fi

  local drift_count=$(jq -r '[.resource_changes[] | select(.change.actions != ["no-op"])] | length' "$REPORT_FILE")

  log_info "Sending Slack notification..."

  curl -s -X POST "$SLACK_WEBHOOK_URL" \
    -H 'Content-Type: application/json' \
    -d "{
      \"text\": \"⚠️ Infrastructure Drift Detected\",
      \"blocks\": [
        {
          \"type\": \"section\",
          \"text\": {
            \"type\": \"mrkdwn\",
            \"text\": \":warning: *Infrastructure Drift Detected*\n\n*Environment:* ${ENVIRONMENT}\n*Drifted Resources:* ${drift_count}\n*Timestamp:* $(date -u +"%Y-%m-%dT%H:%M:%SZ")\"
          }
        },
        {
          \"type\": \"section\",
          \"text\": {
            \"type\": \"mrkdwn\",
            \"text\": \"Please review the drift report and remediate.\"
          }
        }
      ]
    }" &>/dev/null || log_warn "Failed to send Slack notification"
}

cleanup() {
  if [[ -f "$PLAN_FILE" ]]; then
    log_info "Cleaning up plan file..."
    rm -f "$PLAN_FILE"
  fi
}

# Main execution
main() {
  log_info "=== Infrastructure Drift Detection ==="
  log_info "Environment: $ENVIRONMENT"
  log_info "Create Issue: $CREATE_ISSUE"

  trap cleanup EXIT

  check_terraform
  check_environment
  initialize_terraform
  refresh_state

  check_drift
  local exit_code=$?

  if [[ $exit_code -eq 0 ]]; then
    log_info "✅ No drift detected - exiting"
    exit 0
  fi

  generate_report
  local drift_count=$?

  create_github_issue
  notify_slack

  echo ""
  log_warn "⚠️  Drift Summary: $drift_count resources have drifted"
  log_info "Review: $SUMMARY_FILE"
  log_info "Details: $REPORT_FILE"
  log_info "Plan: $PLAN_FILE"

  exit 2
}

main "$@"
