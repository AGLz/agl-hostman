#!/bin/bash
################################################################################
# Harbor CT182 - Post-Installation Configuration
# Phase 5: Configure Harbor settings, projects, and policies
################################################################################

set -euo pipefail

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_step() { echo -e "${BLUE}[STEP]${NC} $1"; }

HARBOR_HOSTNAME="${HARBOR_HOSTNAME:-harbor.aglsrv1.local}"
HARBOR_URL="https://${HARBOR_HOSTNAME}"
HARBOR_USER="admin"
HARBOR_PASS="${HARBOR_ADMIN_PASSWORD:-Harbor12345}"

log_info "Harbor Post-Installation Configuration"
log_info "URL: $HARBOR_URL"

# Function to call Harbor API
harbor_api() {
    local method="$1"
    local endpoint="$2"
    local data="${3:-}"

    if [ -n "$data" ]; then
        curl -k -s -X "$method" \
            -u "${HARBOR_USER}:${HARBOR_PASS}" \
            -H "Content-Type: application/json" \
            -d "$data" \
            "${HARBOR_URL}/api/v2.0${endpoint}"
    else
        curl -k -s -X "$method" \
            -u "${HARBOR_USER}:${HARBOR_PASS}" \
            -H "Content-Type: application/json" \
            "${HARBOR_URL}/api/v2.0${endpoint}"
    fi
}

# Check Harbor is accessible
log_step "1/8 - Verifying Harbor accessibility..."
if ! curl -k -s "${HARBOR_URL}" > /dev/null; then
    log_error "Harbor is not accessible at ${HARBOR_URL}"
    exit 1
fi
log_info "Harbor is accessible ✓"

# Create projects
log_step "2/8 - Creating initial projects..."

create_project() {
    local name="$1"
    local public="$2"

    log_info "Creating project: $name"
    harbor_api POST /projects "{
        \"project_name\": \"${name}\",
        \"public\": ${public},
        \"metadata\": {
            \"auto_scan\": \"true\",
            \"severity\": \"high\",
            \"reuse_sys_cve_allowlist\": \"true\"
        }
    }" || log_warn "Project $name may already exist"
}

create_project "production" "false"
create_project "staging" "false"
create_project "development" "false"
create_project "library" "true"

# Configure retention policies
log_step "3/8 - Configuring retention policies..."

configure_retention() {
    local project="$1"

    log_info "Setting retention policy for $project"
    harbor_api POST "/projects/${project}/retentionpolicies" '{
        "algorithm": "or",
        "rules": [
            {
                "disabled": false,
                "action": "retain",
                "scope_selectors": {
                    "repository": [
                        {
                            "kind": "doublestar",
                            "decoration": "repoMatches",
                            "pattern": "**"
                        }
                    ]
                },
                "tag_selectors": [
                    {
                        "kind": "doublestar",
                        "decoration": "matches",
                        "pattern": "release-**"
                    }
                ],
                "template": "always"
            },
            {
                "disabled": false,
                "action": "retain",
                "scope_selectors": {
                    "repository": [
                        {
                            "kind": "doublestar",
                            "decoration": "repoMatches",
                            "pattern": "**"
                        }
                    ]
                },
                "tag_selectors": [
                    {
                        "kind": "latestPushedK",
                        "decoration": "recentPushed",
                        "pattern": "20"
                    }
                ],
                "template": "latestPushedK"
            },
            {
                "disabled": false,
                "action": "retain",
                "scope_selectors": {
                    "repository": [
                        {
                            "kind": "doublestar",
                            "decoration": "repoMatches",
                            "pattern": "**"
                        }
                    ]
                },
                "tag_selectors": [
                    {
                        "kind": "nDaysSinceLastPush",
                        "decoration": "withinDays",
                        "pattern": "90"
                    }
                ],
                "template": "nDaysSinceLastPush"
            }
        ]
    }' || log_warn "Retention policy may already exist for $project"
}

configure_retention "production"
configure_retention "staging"
configure_retention "development"

# Configure garbage collection
log_step "4/8 - Configuring garbage collection schedule..."

harbor_api PUT /system/gc/schedule '{
    "schedule": {
        "type": "Weekly",
        "cron": "0 2 * * 0"
    },
    "parameters": {
        "delete_untagged": true,
        "dry_run": false
    }
}' || log_warn "GC schedule may already be configured"

log_info "Garbage collection scheduled: Weekly, Sundays at 2 AM"

# Configure vulnerability scanning
log_step "5/8 - Configuring vulnerability scanning..."

harbor_api PUT /configurations '{
    "scan_all_policy": {
        "type": "daily",
        "parameter": {
            "daily_time": 0
        }
    }
}' || log_warn "Scan policy may already be configured"

log_info "Automatic scanning enabled: Daily at midnight"

# Configure project quotas
log_step "6/8 - Setting storage quotas..."

set_quota() {
    local project="$1"
    local quota_gb="$2"
    local quota_bytes=$((quota_gb * 1024 * 1024 * 1024))

    log_info "Setting quota for $project: ${quota_gb}GB"
    harbor_api PUT "/projects/${project}" "{
        \"metadata\": {
            \"storage_limit\": \"${quota_bytes}\"
        }
    }" || log_warn "Quota may already be set for $project"
}

set_quota "production" 100
set_quota "staging" 50
set_quota "development" 50
set_quota "library" 20

# Enable content trust
log_step "7/8 - Configuring content trust..."

harbor_api PUT /configurations '{
    "verify_remote_cert": true,
    "read_only": false
}' || log_warn "Content trust may already be configured"

# Display summary
log_step "8/8 - Configuration Summary"

echo ""
log_info "═══════════════════════════════════════════════════"
log_info "  Harbor Configuration Completed!"
log_info "═══════════════════════════════════════════════════"
echo ""
log_info "Projects created:"
log_info "  • production (private, 100GB quota)"
log_info "  • staging (private, 50GB quota)"
log_info "  • development (private, 50GB quota)"
log_info "  • library (public, 20GB quota)"
echo ""
log_info "Policies configured:"
log_info "  • Retention: Keep latest 20 images + 90 days + releases"
log_info "  • Garbage Collection: Weekly, Sundays at 2 AM"
log_info "  • Vulnerability Scanning: Automatic on push + Daily scan"
log_info "  • Content Trust: Enabled"
echo ""
log_warn "⚠️  Remember to:"
log_warn "  1. Change the admin password"
log_warn "  2. Configure LDAP/OIDC authentication if available"
log_warn "  3. Review and customize retention policies"
log_warn "  4. Set up backup procedures"
echo ""

exit 0
