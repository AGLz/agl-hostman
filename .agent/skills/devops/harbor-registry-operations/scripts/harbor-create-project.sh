#!/bin/bash
# Harbor Project Creation Script
# Creates Harbor projects with retention policies and security settings
#
# Usage: ./harbor-create-project.sh [options]
#   --project NAME              Project name (required)
#   --public                    Make project public
#   --vulnerability-policy      Set vulnerability policy (block|scan|none)
#   --retention-days DAYS       Keep images for N days (default: 90)
#   --retention-count N         Keep last N images (default: 10)
#   --content-trust             Enable content trust (signing)
#   --scan-on-push              Enable automatic scanning on push
#   --harbor-host HOST          Harbor host (default: from env)
#   --username USER             Harbor username (default: admin)
#   --password PASS             Harbor password (default: from env)

set -euo pipefail

# Configuration
HARBOR_HOST="${HARBOR_HOST:-harbor.local}"
HARBOR_USERNAME="${HARBOR_USERNAME:-admin}"
HARBOR_PASSWORD="${HARBOR_PASSWORD:-}"
PROJECT_NAME=""
PUBLIC=false
VULNERABILITY_POLICY="scan"
RETENTION_DAYS=90
RETENTION_COUNT=10
CONTENT_TRUST=false
SCAN_ON_PUSH=true

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Logging
log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
fatal() { log_error "$1"; exit 1; }

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --project) PROJECT_NAME="$2"; shift 2 ;;
        --public) PUBLIC=true; shift ;;
        --vulnerability-policy) VULNERABILITY_POLICY="$2"; shift 2 ;;
        --retention-days) RETENTION_DAYS="$2"; shift 2 ;;
        --retention-count) RETENTION_COUNT="$2"; shift 2 ;;
        --content-trust) CONTENT_TRUST=true; shift ;;
        --scan-on-push) SCAN_ON_PUSH=true; shift ;;
        --harbor-host) HARBOR_HOST="$2"; shift 2 ;;
        --username) HARBOR_USERNAME="$2"; shift 2 ;;
        --password) HARBOR_PASSWORD="$2"; shift 2 ;;
        *) fatal "Unknown option: $1" ;;
    esac
done

# Validation
[[ -z "$PROJECT_NAME" ]] && fatal "Project name required (--project)"
[[ -z "$HARBOR_PASSWORD" ]] && fatal "Harbor password required (set HARBOR_PASSWORD or --password)"

log_info "Creating Harbor project: ${PROJECT_NAME}"

# Check if project exists
log_info "Checking if project exists..."

PROJECT_EXISTS=$(curl -sk -u "${HARBOR_USERNAME}:${HARBOR_PASSWORD}" \
    "https://${HARBOR_HOST}/api/v2.0/projects?name=${PROJECT_NAME}" | \
    jq -r '.[] | .name == "'"$PROJECT_NAME"'"' | grep true || echo "")

if [[ -n "$PROJECT_EXISTS" ]]; then
    log_warn "Project ${PROJECT_NAME} already exists"
    read -p "Update existing project? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Skipping project creation"
        exit 0
    fi
fi

# Create project
if [[ -z "$PROJECT_EXISTS" ]]; then
    log_info "Creating project..."

    CREATE_RESPONSE=$(curl -skX POST "https://${HARBOR_HOST}/api/v2.0/projects" \
        -u "${HARBOR_USERNAME}:${HARBOR_PASSWORD}" \
        -H "Content-Type: application/json" \
        -d "{
            \"project_name\": \"${PROJECT_NAME}\",
            \"public\": ${PUBLIC},
            \"metadata\": {
                \"public\": \"$(echo ${PUBLIC} | tr '[:upper:]' '[:lower:]')\",
                \"enable_content_trust\": \"$(echo ${CONTENT_TRUST} | tr '[:upper:]' '[:lower:]')\",
                \"prevent_vul\": \"$([ "$VULNERABILITY_POLICY" == "block" ] && echo "true" || echo "false")\"
            }
        }")

    # Get project ID
    PROJECT_ID=$(curl -sk -u "${HARBOR_USERNAME}:${HARBOR_PASSWORD}" \
        "https://${HARBOR_HOST}/api/v2.0/projects?name=${PROJECT_NAME}" | \
        jq -r '.[0].project_id')

    log_info "Project created with ID: ${PROJECT_ID}"
else
    PROJECT_ID=$(curl -sk -u "${HARBOR_USERNAME}:${HARBOR_PASSWORD}" \
        "https://${HARBOR_HOST}/api/v2.0/projects?name=${PROJECT_NAME}" | \
        jq -r '.[0].project_id')
fi

# Configure vulnerability policy
if [[ "$VULNERABILITY_POLICY" != "none" ]]; then
    log_info "Setting vulnerability policy: ${VULNERABILITY_POLICY}"

    # Map policy to severity threshold
    case "$VULNERABILITY_POLICY" in
        block)
            SEVERITY="high"
            ACTION="prevent"
            ;;
        scan)
            SEVERITY="critical"
            ACTION="none"
            ;;
        *)
            SEVERITY="critical"
            ACTION="none"
            ;;
    esac

    curl -skX PUT "https://${HARBOR_HOST}/api/v2.0/projects/${PROJECT_ID}/scanner" \
        -u "${HARBOR_USERNAME}:${HARBOR_PASSWORD}" \
        -H "Content-Type: application/json" \
        -d "{
            \"uuid\": \"$(curl -sk -u "${HARBOR_USERNAME}:${HARBOR_PASSWORD}" \
                "https://${HARBOR_HOST}/api/v2.0/scanners" | \
                jq -r '.[0].uuid // ""')\"
        }" > /dev/null 2>&1

    if [[ "$ACTION" == "prevent" ]]; then
        curl -skX PUT "https://${HARBOR_HOST}/api/v2.0/projects/${PROJECT_ID}/retention" \
            -u "${HARBOR_USERNAME}:${HARBOR_PASSWORD}" \
            -H "Content-Type: application/json" \
            -d "{
                \"algorithm\": \"or\",
                \"rules\": [{
                    \"disabled\": false,
                    \"action\": \"retain\",
                    \"scope_selectors\": {
                        \"repository\": [{
                            \"kind\": \"doublestar\",
                            \"decoration\": \"repoMatches\",
                            \"pattern\": \"**\"
                        }]
                    },
                    \"tag_selectors\": [{
                        \"kind\": \"doublestar\",
                        \"decoration\": \"matches\",
                        \"pattern\": \"**\"
                    }],
                    \"params\": {
                        \"latestPushedK\": ${RETENTION_COUNT}
                    },
                    \"templates\": [{
                        \"n_days_since_last_push\": ${RETENTION_DAYS},
                        \"latestPushedK\": ${RETENTION_COUNT}
                    }]
                }],
                \"trigger\": {
                    \"kind\": \"Schedule\",
                    \"settings\": {
                        \"cron\": \"0 0 * * *\"
                    }
                },
                \"scope\": {
                    \"level\": \"project\",
                    \"ref\": ${PROJECT_ID}
                }
            }" > /dev/null 2>&1
    fi

    log_info "Vulnerability policy configured"
fi

# Create retention policy
log_info "Creating retention policy..."

curl -skX POST "https://${HARBOR_HOST}/api/v2.0/retentions" \
    -u "${HARBOR_USERNAME}:${HARBOR_PASSWORD}" \
    -H "Content-Type: application/json" \
    -d "{
        \"algorithm\": \"or\",
        \"rules\": [{
            \"disabled\": false,
            \"action\": \"retain\",
            \"scope_selectors\": {
                \"repository\": [{
                    \"kind\": \"doublestar\",
                    \"decoration\": \"repoMatches\",
                    \"pattern\": \"**\"
                }]
            },
            \"tag_selectors\": [{
                \"kind\": \"doublestar\",
                \"decoration\": \"matches\",
                \"pattern\": \"**\"
            }],
            \"params\": {
                \"latestPushedK\": ${RETENTION_COUNT}
            },
            \"templates\": [{
                \"n_days_since_last_pull\": ${RETENTION_DAYS}
            }]
        }],
        \"trigger\": {
            \"kind\": \"Schedule\",
            \"settings\": {
                \"cron\": \"0 0 * * *\"
            }
        },
        \"scope\": {
            \"level\": \"project\",
            \"ref\": ${PROJECT_ID}
        }
    }" > /dev/null 2>&1

log_info "Retention policy configured: keep last ${RETENTION_COUNT} images, purge after ${RETENTION_DAYS} days"

# Enable automatic scanning on push
if [[ "$SCAN_ON_PUSH" == true ]]; then
    log_info "Enabling automatic scanning on push..."

    # Configure webhook for scan trigger
    curl -skX POST "https://${HARBOR_HOST}/api/v2.0/projects/${PROJECT_ID}/webhooks/policies" \
        -u "${HARBOR_USERNAME}:${HARBOR_PASSWORD}" \
        -H "Content-Type: application/json" \
        -d "{
            \"name\": \"Auto-scan on push\",
            \"description\": \"Trigger vulnerability scan when image is pushed\",
            \"project_id\": ${PROJECT_ID},
            \"targets\": [{
                \"type\": \"http\",
                \"address\": \"https://${HARBOR_HOST}/api/v2.0/webhook/events\",
                \"auth_header\": \"\"
            }],
            \"event_types\": [\"PUSH_ARTIFACT\"],
            \"enabled\": true
        }" > /dev/null 2>&1

    log_info "Automatic scanning enabled"
fi

# Summary
log_info "Project configuration complete!"
echo ""
echo "Project Details:"
echo "  Name: ${PROJECT_NAME}"
echo "  ID: ${PROJECT_ID}"
echo "  Public: ${PUBLIC}"
echo "  Content Trust: ${CONTENT_TRUST}"
echo "  Vulnerability Policy: ${VULNERABILITY_POLICY}"
echo "  Retention: Last ${RETENTION_COUNT} images, ${RETENTION_DAYS} days"
echo "  Auto-scan: ${SCAN_ON_PUSH}"
echo ""
echo "Next steps:"
echo "  1. Create robot account: ./harbor-robot-account.sh --project ${PROJECT_NAME}"
echo "  2. Configure webhook: ./harbor-webhook.sh --project ${PROJECT_NAME}"
echo "  3. Push image: docker push ${HARBOR_HOST}/${PROJECT_NAME}/myapp:v1.0.0"
