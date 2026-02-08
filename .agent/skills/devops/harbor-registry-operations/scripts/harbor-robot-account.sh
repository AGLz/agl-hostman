#!/bin/bash
# Harbor Robot Account Management Script
# Creates and manages Harbor robot accounts for CI/CD and automation
#
# Usage: ./harbor-robot-account.sh [options]
#   --create                    Create a new robot account (default)
#   --list                      List robot accounts
#   --delete ID                 Delete robot account by ID
#   --regenerate ID            Regenerate secret for robot account
#   --name NAME                 Robot account name (required for create)
#   --project NAME              Project name (required for create)
#   --permissions PERMS         Permissions: pull,push,all (default: pull,push)
#   --duration DAYS             Account validity in days (default: 90)
#   --description DESC          Account description
#   --harbor-host HOST          Harbor host (default: from env)
#   --username USER             Harbor username (default: admin)
#   --password PASS             Harbor password (default: from env)

set -euo pipefail

# Configuration
HARBOR_HOST="${HARBOR_HOST:-harbor.local}"
HARBOR_USERNAME="${HARBOR_USERNAME:-admin}"
HARBOR_PASSWORD="${HARBOR_PASSWORD:-}"
ACTION="create"
ROBOT_NAME=""
PROJECT_NAME=""
PERMISSIONS="pull,push"
DURATION=90
DESCRIPTION=""
ROBOT_ID=""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Logging
log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
fatal() { log_error "$1"; exit 1; }

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --create) ACTION="create"; shift ;;
        --list) ACTION="list"; shift ;;
        --delete) ACTION="delete"; ROBOT_ID="$2"; shift 2 ;;
        --regenerate) ACTION="regenerate"; ROBOT_ID="$2"; shift 2 ;;
        --name) ROBOT_NAME="$2"; shift 2 ;;
        --project) PROJECT_NAME="$2"; shift 2 ;;
        --permissions) PERMISSIONS="$2"; shift 2 ;;
        --duration) DURATION="$2"; shift 2 ;;
        --description) DESCRIPTION="$2"; shift 2 ;;
        --harbor-host) HARBOR_HOST="$2"; shift 2 ;;
        --username) HARBOR_USERNAME="$2"; shift 2 ;;
        --password) HARBOR_PASSWORD="$2"; shift 2 ;;
        *) fatal "Unknown option: $1" ;;
    esac
done

# Validation
[[ -z "$HARBOR_PASSWORD" ]] && fatal "Harbor password required (set HARBOR_PASSWORD or --password)"

# List robot accounts
if [[ "$ACTION" == "list" ]]; then
    log_info "Listing robot accounts..."

    ROBOTS=$(curl -sk -u "${HARBOR_USERNAME}:${HARBOR_PASSWORD}" \
        "https://${HARBOR_HOST}/api/v2.0/robots")

    echo ""
    echo "Harbor Robot Accounts:"
    echo "======================"

    echo "$ROBOTS" | jq -r '.[] |
        "\(.name | gsub("robot$"; "")) (\(.id))\n" +
        "  Description: \(.description // "N/A")\n" +
        "  Expires: \(.expires_at // "Never")\n" +
        "  Permissions: \(.permissions | length) project(s)\n" +
        "  Created: \(.creation_time)\n" +
        "  "'
    echo ""
    exit 0
fi

# Delete robot account
if [[ "$ACTION" == "delete" ]]; then
    [[ -z "$ROBOT_ID" ]] && fatal "Robot ID required for delete"

    log_info "Deleting robot account ID: ${ROBOT_ID}..."

    ROBOT_NAME=$(curl -sk -u "${HARBOR_USERNAME}:${HARBOR_PASSWORD}" \
        "https://${HARBOR_HOST}/api/v2.0/robots/${ROBOT_ID}" | \
        jq -r '.name // "unknown"')

    curl -skX DELETE "https://${HARBOR_HOST}/api/v2.0/robots/${ROBOT_ID}" \
        -u "${HARBOR_USERNAME}:${HARBOR_PASSWORD}" > /dev/null 2>&1

    log_info "Robot account '${ROBOT_NAME}' deleted"
    exit 0
fi

# Regenerate secret
if [[ "$ACTION" == "regenerate" ]]; then
    [[ -z "$ROBOT_ID" ]] && fatal "Robot ID required for regenerate"

    log_info "Regenerating secret for robot account ID: ${ROBOT_ID}..."

    RESPONSE=$(curl -skX PATCH "https://${HARBOR_HOST}/api/v2.0/robots/${ROBOT_ID}" \
        -u "${HARBOR_USERNAME}:${HARBOR_PASSWORD}" \
        -H "Content-Type: application/json" \
        -d '{"secret": null}')

    SECRET=$(echo "$RESPONSE" | jq -r '.secret // empty')

    if [[ -n "$SECRET" ]]; then
        log_info "New secret generated:"
        echo ""
        echo "Robot Account: $(echo "$RESPONSE" | jq -r '.name')"
        echo "Secret: ${SECRET}"
        echo ""
        echo "Docker login:"
        echo "docker login ${HARBOR_HOST} -u $(echo "$RESPONSE" | jq -r '.name') -p ${SECRET}"
        echo ""
    else
        log_error "Failed to regenerate secret"
        exit 1
    fi
    exit 0
fi

# Create robot account
if [[ "$ACTION" == "create" ]]; then
    [[ -z "$ROBOT_NAME" ]] && fatal "Robot name required (--name)"
    [[ -z "$PROJECT_NAME" ]] && fatal "Project name required (--project)"

    log_info "Creating robot account: ${ROBOT_NAME}"

    # Get project ID
    PROJECT_ID=$(curl -sk -u "${HARBOR_USERNAME}:${HARBOR_PASSWORD}" \
        "https://${HARBOR_HOST}/api/v2.0/projects?name=${PROJECT_NAME}" | \
        jq -r '.[0].project_id // empty')

    if [[ -z "$PROJECT_ID" ]]; then
        fatal "Project '${PROJECT_NAME}' not found"
    fi

    # Build permissions array
    PERMS_ARRAY="[]"

    if [[ "$PERMISSIONS" == "all" ]]; then
        PERMS_ARRAY='[
            {"resource": "repository", "action": "push"},
            {"resource": "repository", "action": "pull"},
            {"resource": "repository", "action": "delete"}
        ]'
    else
        IFS=',' read -ra PERMS <<< "$PERMISSIONS"
        PERMS_ARRAY="["
        FIRST=true
        for perm in "${PERMS[@]}"; do
            perm=$(echo "$perm" | xargs)
            if [[ "$FIRST" == true ]]; then
                FIRST=false
            else
                PERMS_ARRAY="${PERMS_ARRAY},"
            fi
            PERMS_ARRAY="${PERMS_ARRAY}{\"resource\": \"repository\", \"action\": \"${perm}\"}"
        done
        PERMS_ARRAY="${PERMS_ARRAY}]"
    fi

    # Create robot account
    RESPONSE=$(curl -skX POST "https://${HARBOR_HOST}/api/v2.0/robots" \
        -u "${HARBOR_USERNAME}:${HARBOR_PASSWORD}" \
        -H "Content-Type: application/json" \
        -d "{
            \"name\": \"${ROBOT_NAME}\",
            \"description\": \"${DESCRIPTION:-CI/CD robot account for ${PROJECT_NAME}}\",
            \"duration\": ${DURATION},
            \"level\": \"project\",
            \"disable\": false,
            \"permissions\": [{
                \"kind\": \"project\",
                \"namespace\": \"${PROJECT_NAME}\",
                \"access\": ${PERMS_ARRAY}
            }]
        }")

    ROBOT_ID=$(echo "$RESPONSE" | jq -r '.id // empty')
    SECRET=$(echo "$RESPONSE" | jq -r '.secret // empty')

    if [[ -z "$ROBOT_ID" || -z "$SECRET" ]]; then
        log_error "Failed to create robot account"
        echo "$RESPONSE" | jq '.'
        exit 1
    fi

    # Get robot details
    FULL_NAME="robot$${ROBOT_NAME}"

    log_info "Robot account created successfully!"
    echo ""
    echo "Robot Account Details:"
    echo "======================"
    echo "ID: ${ROBOT_ID}"
    echo "Name: ${FULL_NAME}"
    echo "Description: ${DESCRIPTION:-CI/CD robot account for ${PROJECT_NAME}}"
    echo "Project: ${PROJECT_NAME}"
    echo "Permissions: ${PERMISSIONS}"
    echo "Duration: ${DURATION} days"
    echo ""
    echo "Authentication:"
    echo "Username: ${FULL_NAME}"
    echo "Secret: ${SECRET}"
    echo ""
    echo "Docker Login:"
    echo "docker login ${HARBOR_HOST} -u ${FULL_NAME} -p ${SECRET}"
    echo ""
    echo "Environment Variables:"
    echo "export HARBOR_USERNAME=\"${FULL_NAME}\""
    echo "export HARBOR_PASSWORD=\"${SECRET}\""
    echo ""
    echo "Kubernetes Secret:"
    echo "kubectl create secret docker-registry harbor-registry \\"
    echo "  --docker-server=${HARBOR_HOST} \\"
    echo "  --docker-username=${FULL_NAME} \\"
    echo "  --docker-password=${SECRET}"
    echo ""

    # Save to file
    CREDENTIALS_FILE=".harbor-robot-${ROBOT_NAME}.env"
    cat > "$CREDENTIALS_FILE" <<EOF
# Harbor Robot Account Credentials
# Generated: $(date)
# WARNING: Keep this file secret and secure!

HARBOR_HOST=${HARBOR_HOST}
HARBOR_USERNAME=${FULL_NAME}
HARBOR_PASSWORD=${SECRET}
HARBOR_PROJECT=${PROJECT_NAME}
EOF

    chmod 600 "$CREDENTIALS_FILE"
    log_info "Credentials saved to: ${CREDENTIALS_FILE}"
    log_warn "IMPORTANT: Store the secret securely. It cannot be retrieved later!"
fi
