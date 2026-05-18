#!/bin/bash
# AGL-20: Rotate MCP API Keys - Security Fix
# CRITICAL: Hardcoded LINEAR_API_TOKEN must be rotated

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
MCP_CONFIG_DIR="$HOME/.config/claude"
MCP_CONFIG_FILE="$MCP_CONFIG_DIR/mcp.json"
BACKUP_DIR="$MCP_CONFIG_DIR/backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Create backup directory
mkdir -p "$BACKUP_DIR"

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1${NC}"
}

log_error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} ERROR: $1${NC}" >&2
}

log_warning() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} WARNING: $1${NC}" >&2
}

# Function to generate secure random API key
generate_secure_key() {
    local length=${1:-64}
    # Generate base64-encoded random key with proper length
    openssl rand -base64 "$length" 2>/dev/null | tr -d '\n' | head -1
}

# Function to validate key strength
validate_key() {
    local key="$1"
    local min_length=64

    # Check length
    if [ ${#key} -lt $min_length ]; then
        log_error "Key too short (minimum $min_length characters)"
        return 1
    fi

    # Check for base64 valid characters
    if ! echo "$key" | base64 -d &>/dev/null; then
        log_error "Key contains invalid base64 characters"
        return 1
    fi

    return 0
}

# Backup current config
log "Creating backup of current MCP configuration..."
cp "$MCP_CONFIG_FILE" "$BACKUP_DIR/mcp.json.backup_$TIMESTAMP"

if [ $? -ne 0 ]; then
    log_error "Failed to create backup"
    exit 1
fi

# Check for existing LINEAR_API_TOKEN
if grep -q '"LINEAR_API_TOKEN"' "$MCP_CONFIG_FILE"; then
    log_warning "CRITICAL: LINEAR_API_TOKEN is hardcoded in config"
    log_warning "This is a security vulnerability - token should be rotated"
fi

# Generate new secure keys
log "Generating new secure API keys..."

NEW_LARAVEL_BOOST_KEY=$(generate_secure_key 64)
NEW_SHADCN_KEY=$(generate_secure_key 64)
NEW_RUV_SWARM_KEY=$(generate_secure_key 64)

# Validate new keys
validate_key "$NEW_LARAVEL_BOOST_KEY" || exit 1
validate_key "$NEW_SHADCN_KEY" || exit 1
validate_key "$NEW_RUV_SWARM_KEY" || exit 1

# Create new config with rotated keys
log "Creating new MCP configuration with rotated keys..."

cat > "$MCP_CONFIG_FILE.tmp" << EOF
{
  "apiKeys": {
    "linear": "$NEW_LARAVEL_BOOST_KEY",
    "shadcn": "$NEW_SHADCN_KEY",
    "ruv-swarm": "$NEW_RUV_SWARM_KEY"
  },
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "lastRotated": "$TIMESTAMP",
  "version": "2.0"
}
EOF

# Validate new config
if ! jq empty "$MCP_CONFIG_FILE.tmp" >/dev/null 2>&1; then
    log_error "Generated invalid JSON config"
    rm -f "$MCP_CONFIG_FILE.tmp"
    exit 1
fi

# Replace old config
log "Applying new MCP configuration..."
mv "$MCP_CONFIG_FILE.tmp" "$MCP_CONFIG_FILE"

if [ $? -ne 0 ]; then
    log_error "Failed to apply new configuration"
    exit 1
fi

# Update .env.security with new keys
log "Updating .env.security with new API keys..."

cat > /mnt/overpower/apps/dev/agl/agl-hostman/.env.security.tmp << EOF
# AGL-20: MCP Security Configuration
# Generated: $(date +'%Y-%m-%d %H:%M:%S')
# DO NOT commit these values to git!

# Laravel Boost MCP
MCP_LARAVEL_BOOST_KEY=$NEW_LARAVEL_BOOST_KEY

# Shadcn MCP
MCP_SHADCN_KEY=$NEW_SHADCN_KEY

# Ruv Swarm MCP
MCP_RUV_SWARM_KEY=$NEW_RUV_SWARM_KEY

# Security Settings
MCP_RATE_LIMITING_ENABLED=true
MCP_RATE_LIMIT_MAX_ATTEMPTS=60
MCP_IP_WHITELIST_ENABLED=false
MCP_AUDIT_LOGGING_ENABLED=true

# Secrets Management
VAULT_ADDR=https://vault.aglz.io:8200
VAULT_TOKEN=your_vault_token_here
BACKUP_GPG_RECIPIENT=admin@aglz.io
EOF

mv /mnt/overpower/apps/dev/agl/agl-hostman/.env.security.tmp /mnt/overpower/apps/dev/agl/agl-hostman/.env.security

if [ $? -ne 0 ]; then
    log_error "Failed to update .env.security"
    exit 1
fi

# Set secure permissions
chmod 600 "$MCP_CONFIG_FILE"
chmod 600 /mnt/overpower/apps/dev/agl/agl-hostman/.env.security

# Summary
echo ""
log "=== MCP Key Rotation Complete ==="
log ""
log "✅ New keys generated and applied"
log "✅ Configuration backup created: $BACKUP_DIR/mcp.json.backup_$TIMESTAMP"
log "✅ .env.security updated with new keys"
log "✅ File permissions set to 600"
log ""
log "${YELLOW}IMPORTANT ACTIONS REQUIRED:${NC}"
log "${YELLOW}1. Restart all MCP servers to use new keys${NC}"
log "${YELLOW}2. Test Linear integration to verify connectivity${NC}"
log "${YELLOW}3. Update any automation that references old keys${NC}"
log ""
log "${GREEN}Next rotation recommended: 30 days${NC}"
log ""
