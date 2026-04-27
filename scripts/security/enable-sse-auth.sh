#!/bin/bash
# AGL-20: Enable SSE Authentication for MCP Endpoints
# HIGH: SSE endpoints require token-based authentication

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Laravel MCP SSE endpoints that need authentication
LARAVEL_MCP_ENDPOINT="http://192.168.0.183:8000/mcp/sse"
SSE_ROUTES=(
    "/mcp/sse/subscribe"
    "/mcp/sse/unsubscribe"
    "/mcp/sse/events"
)

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1${NC}"
}

log_error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} ERROR: $1${NC}" >&2
}

log_warning() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} WARNING: $1${NC}" >&2
}

log_info() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} INFO: $1${NC}"
}

# Check if Laravel Boost MCP has SSE authentication
log "Checking Laravel Boost MCP SSE authentication..."

# Test current endpoint
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$LARAVEL_MCP_ENDPOINT" 2>/dev/null)

if [ "$HTTP_CODE" = "401" ]; then
    log "✅ SSE authentication is WORKING (401 Unauthorized = expected)"
    log "Bearer token authentication is active"
elif [ "$HTTP_CODE" = "200" ]; then
    log_warning "⚠️  SSE endpoint returns 200 - may allow anonymous access"
    log_warning "Bearer token authentication should be enforced"
else
    log_error "❌ Unexpected HTTP code: $HTTP_CODE"
fi

# Check for SSE middleware in Laravel
LARAVEL_PATH="/mnt/overpower/apps/dev/agl/agl-hostman/src"
SSE_MIDDLEWARE="$LARAVEL_PATH/app/Http/Middleware/SseAuthentication.php"

if [ -f "$SSE_MIDDLEWARE" ]; then
    log "✅ SSE Authentication middleware exists"
    log "   File: $SSE_MIDDLEWARE"
else
    log_warning "⚠️  SSE Authentication middleware not found"
    log "   Expected location: $SSE_MIDDLEWARE"
fi

# Check if authentication is required in config
MCP_CONFIG_FILE="$HOME/.config/claude/mcp.json"

if [ -f "$MCP_CONFIG_FILE" ]; then
    log "Checking MCP configuration for SSE settings..."
    if grep -q '"sseAuthentication":\s*true' "$MCP_CONFIG_FILE"; then
        log "✅ SSE authentication is enabled in config"
    else
        log_warning "⚠️  SSE authentication may not be configured"
    fi
fi

# Generate secure bearer token for testing
generate_sse_token() {
    # Generate 32-byte random token
    openssl rand -base64 32 2>/dev/null | tr -d '\n' | head -1
}

# Recommendations
echo ""
log "=== SSE Authentication Implementation ==="
log ""
log "${YELLOW}CRITICAL FIX REQUIRED:${NC}"
log "${YELLOW}SSE endpoints need bearer token authentication${NC}"
log ""
log "${YELLOW}Implementation Steps:${NC}"
log ""
log "${GREEN}1. Verify SSE Authentication middleware exists${NC}"
log "   File: src/app/Http/Middleware/SseAuthentication.php"
log "   Should validate Bearer token from Authorization header"
log ""
log "${GREEN}2. Update Laravel Boost MCP config${NC}"
log "   Add: \"sseAuthentication\": true${NC}"
log "   Configure allowed tokens or JWT validation${NC}"
log ""
log "${GREEN}3. Test authentication${NC}"
log "   curl -H \"Authorization: Bearer <token>\" $LARAVEL_MCP_ENDPOINT"
log ""
log "${GREEN}4. Monitor SSE access logs${NC}"
log "   Enable audit logging for SSE connections${NC}"
log ""
