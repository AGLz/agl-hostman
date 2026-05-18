#!/bin/bash
# AGL Infrastructure - Credential Rotation Script
# Version: 1.0.0
# Description: Rotates all exposed credentials from documentation
# Author: Security Agent V3
# Date: 2026-02-08

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
CREDENTIALS_FILE="/tmp/agl-credentials-$(date +%Y%m%d).txt"
LOG_FILE="/var/log/agl/credential-rotation-$(date +%Y%m%d).log"
PROJECT_ROOT="/mnt/overpower/apps/dev/agl/agl-hostman"

# Create log directory
mkdir -p "$(dirname "$LOG_FILE")"

# Logging function
log() {
    local level=$1
    shift
    local message="$@"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${timestamp} [${level}] ${message}" | tee -a "$LOG_FILE"
}

log_info() {
    log "INFO" "${GREEN}$@${NC}"
}

log_warn() {
    log "WARN" "${YELLOW}$@${NC}"
}

log_error() {
    log "ERROR" "${RED}$@${NC}"
}

# Generate secure random password
generate_password() {
    local length=${1:-32}
    openssl rand -base64 "$length" | tr -d '=+/' | cut -c1-"$length"
}

# Store credential for reference
store_credential() {
    local service=$1
    local username=$2
    local password=$3
    echo "${service}|${username}|${password}" >> "$CREDENTIALS_FILE"
    chmod 600 "$CREDENTIALS_FILE"
}

# Rotate Archon credentials
rotate_archon() {
    log_info "Rotating Archon credentials..."

    local new_password=$(generate_password 32)
    local archon_host="192.168.0.183"

    # Store credential
    store_credential "Archon" "admin" "$new_password"

    # Update htpasswd file
    ssh root@"${archon_host}" "cd /root/archon && htpasswd -bc nginx/.htpasswd admin ${new_password}"

    # Restart nginx container
    ssh root@"${archon_host}" "docker restart archon-nginx-proxy"

    log_info "Archon credentials rotated successfully"
    log_warn "Update .env with: ARCHON_PASSWORD=${new_password}"
}

# Rotate Harbor credentials
rotate_harbor() {
    log_info "Rotating Harbor credentials..."

    local new_password=$(generate_password 32)
    local harbor_url="https://harbor.aglz.io"

    # Store credential
    store_credential "Harbor" "admin" "$new_password"

    # Change Harbor admin password via API
    # Note: You'll need to provide current admin password
    log_warn "Manually update Harbor admin password at: ${harbor_url}"
    log_warn "New password: ${new_password}"
}

# Rotate Grafana credentials
rotate_grafana() {
    log_info "Rotating Grafana credentials..."

    local new_password=$(generate_password 32)
    local grafana_host="192.168.0.183"

    # Store credential
    store_credential "Grafana" "admin" "$new_password"

    # Update via Grafana API
    curl -X PUT "http://${grafana_host}:3000/api/admin/users/1/password" \
        -H "Content-Type: application/json" \
        -d "{\"password\":\"${new_password}\"}" \
        --user admin:$(grep GRAFANA_ADMIN_PASSWORD "${PROJECT_ROOT}/.env" | cut -d= -f2)

    log_info "Grafana credentials rotated successfully"
    log_warn "Update .env with: GRAFANA_ADMIN_PASSWORD=${new_password}"
}

# Generate new APP_KEY
rotate_app_key() {
    log_info "Generating new APP_KEY..."

    cd "$PROJECT_ROOT/src"
    local new_key=$(php artisan key:generate --show)

    echo "APP_KEY=${new_key}" >> "${PROJECT_ROOT}/.env"

    log_info "New APP_KEY generated: ${new_key}"
    log_warn "Update all .env files with new APP_KEY"
}

# Update MCP API keys
rotate_mcp_keys() {
    log_info "Rotating MCP API keys..."

    local mcp_keys=(
        "MCP_LARAVEL_BOOST_KEY"
        "MCP_SHADCN_KEY"
        "MCP_RUV_SWARM_KEY"
    )

    for key in "${mcp_keys[@]}"; do
        local new_key=$(generate_password 64)
        store_credential "MCP" "${key}" "${new_key}"

        # Append to .env if not exists
        if ! grep -q "^${key}=" "${PROJECT_ROOT}/.env"; then
            echo "${key}=${new_key}" >> "${PROJECT_ROOT}/.env"
        fi

        log_info "Generated new ${key}"
    done
}

# Generate database password
rotate_db_password() {
    log_info "Rotating database passwords..."

    local new_password=$(generate_password 32)
    store_credential "Database" "agl_hostman" "${new_password}"

    log_warn "Manually update database password in MySQL/MariaDB"
    log_warn "New password: ${new_password}"
    log_warn "Update .env with: DB_PASSWORD=${new_password}"
}

# Remove credentials from documentation
clean_documentation() {
    log_info "Removing credentials from documentation..."

    local patterns=(
        "admin/ArchonPass2025"
        "password.*=.*['\"].*['\"]"
        "api_key.*=.*['\"].*['\"]"
        "sk-[a-zA-Z0-9]{48}"
        "AKIA[0-9A-Z]{16}"
    )

    # Find all .md files
    find "$PROJECT_ROOT" -name "*.md" -type f | while read -r file; do
        # Check if file contains credentials
        for pattern in "${patterns[@]}"; do
            if grep -qE "$pattern" "$file"; then
                log_warn "Found potential credentials in: $file"
                # Create backup
                cp "$file" "${file}.backup.$(date +%Y%m%d%H%M%S)"
                log_info "Backup created: ${file}.backup.$(date +%Y%m%d%H%M%S)"
            fi
        done
    done

    log_warn "Please manually review and clean credential references in documentation"
}

# Pre-commit hook to prevent credential commits
install_git_hooks() {
    log_info "Installing pre-commit hook to prevent credential commits..."

    local hook_file="${PROJECT_ROOT}/.git/hooks/pre-commit"

    cat > "$hook_file" << 'EOF'
#!/bin/bash
# Prevent committing credentials

# Patterns to check
patterns=(
    "password\s*[:=]\s*['\"][^'\"]{8,}['\"]"
    "api_key\s*[:=]\s*['\"][^'\"]{20,}['\"]"
    "secret\s*[:=]\s*['\"][^'\"]{20,}['\"]"
    "AKIA[0-9A-Z]{16}"
    "sk-[a-zA-Z0-9]{48}"
    "ghp_[a-zA-Z0-9]{36}"
)

# Check staged files
files=$(git diff --cached --name-only --diff-filter=ACM)
for file in $files; do
    for pattern in "${patterns[@]}"; do
        if grep -qE "$pattern" "$file" 2>/dev/null; then
            echo "ERROR: Potential credential found in $file"
            echo "Pattern: $pattern"
            echo "Commit aborted. Please remove credentials before committing."
            exit 1
        fi
    done
done
EOF

    chmod +x "$hook_file"
    log_info "Pre-commit hook installed successfully"
}

# Main execution
main() {
    log_info "Starting credential rotation for AGL Infrastructure..."
    log_info "=============================================="

    # Check if running as root
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root"
        exit 1
    fi

    # Ask for confirmation
    log_warn "This will rotate all credentials in the system"
    read -p "Are you sure you want to continue? (yes/no): " confirm

    if [[ "$confirm" != "yes" ]]; then
        log_info "Credential rotation cancelled"
        exit 0
    fi

    # Execute rotation
    rotate_archon
    rotate_harbor
    rotate_grafana
    rotate_app_key
    rotate_mcp_keys
    rotate_db_password
    clean_documentation
    install_git_hooks

    log_info "=============================================="
    log_info "Credential rotation completed!"
    log_info "Credentials stored in: ${CREDENTIALS_FILE}"
    log_info "Log file: ${LOG_FILE}"
    log_warn "IMPORTANT: Store ${CREDENTIALS_FILE} in secure location"
    log_warn "Update all .env files with new credentials"
    log_warn "Restart all services after updating credentials"

    # Display summary
    echo ""
    echo "Credential Summary:"
    echo "==================="
    cat "$CREDENTIALS_FILE" | column -t -s '|'
}

# Run main function
main "$@"
