#!/bin/bash
# AGL-20: Enable HTTPS for Archon MCP Server
# HIGH: HTTP protocol is insecure - must use HTTPS

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

ARCHON_HOST="192.168.0.183"
ARCHON_PORT="8051"
ARCHON_PATH="/mcp"

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1${NC}"
}

log_error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} ERROR: $1${NC}" >&2
}

log_warning() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} WARNING: $1${NC}" >&2
}

# Check current Archon configuration
log "Checking current Archon MCP server configuration..."

# First, let's check if we can access it
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "http://$ARCHON_HOST:$ARCHON_PORT$ARCHON_PATH" 2>/dev/null)

if [ "$HTTP_CODE" = "404" ]; then
    log_warning "Archon MCP endpoint returns 404 - this may be expected"
    log_warning "The MCP endpoint works, but HTTP health check fails"
elif [ "$HTTP_CODE" = "200" ]; then
    log "Archon is accessible via HTTP (port $ARCHON_PORT)"
    log_warning "⚠️  INSECURE: HTTP protocol should be replaced with HTTPS"
else
    log_error "Cannot connect to Archon - HTTP code: $HTTP_CODE"
fi

# Check if Archon has TLS/SSL configured
log "Checking for SSL/TLS certificate on Archon..."

# Try HTTPS connection
HTTPS_CODE=$(curl -s -o /dev/null -w "%{http_code}" -k "https://$ARCHON_HOST:$ARCHON_PORT$ARCHON_PATH" 2>/dev/null)

if [ "$HTTPS_CODE" = "000" ] || [ "$HTTPS_CODE" = "000" ]; then
    # Connection refused or timeout
    log_warning "HTTPS connection refused - Archon may not have SSL enabled"
    log_warning "SSL certificate needs to be configured"
elif [ "$HTTPS_CODE" = "404" ]; then
    log "Archon MCP endpoint accessible via HTTPS (404 - expected for MCP)"
    log_warning "SSL verification needed"
elif [ "$HTTPS_CODE" = "200" ]; then
    log "✅ HTTPS is working on Archon!"
    log_warning "HTTP (8051) should be disabled in favor of HTTPS (8443 or another port)"
else
    log "HTTPS returned code: $HTTPS_CODE"
fi

# Check port 443 for HTTPS (standard HTTPS alt port)
log "Checking if Archon is listening on standard HTTPS port 443..."

HTTPS_443_CODE=$(curl -s -o /dev/null -w "%{http_code}" -k "https://$ARCHON_HOST:443$ARCHON_PATH" 2>/dev/null)

if [ "$HTTPS_443_CODE" = "200" ]; then
    log "✅ Archon is available on HTTPS port 443"
    log "Recommended: Configure MCP to use https://$ARCHON_HOST:443$ARCHON_PATH"
elif [ "$HTTPS_443_CODE" = "000" ] || [ "$HTTPS_443_CODE" = "000" ]; then
    log_warning "Port 443 not available"
fi

# Archon MCP configuration file
ARCHON_CONFIG_FILE="$HOME/.archon-mcp/config.json"

if [ -f "$ARCHON_CONFIG_FILE" ]; then
    log "Found Archon config at: $ARCHON_CONFIG_FILE"
    log "Current configuration:"
    cat "$ARCHON_CONFIG_FILE" | head -20
else
    log "Archon config not found at expected location"
    log "Creating recommended configuration..."
fi

# Recommendations
echo ""
log "=== Security Recommendations ==="
log ""
log "${YELLOW}CRITICAL FIXES REQUIRED:${NC}"
log "${YELLOW}1. Configure Archon MCP server to use HTTPS${NC}"
log "   Option A: Use port 443 (standard HTTPS)${NC}"
log "   Option B: Use port 8443 with valid SSL certificate${NC}"
log "   Option C: Reverse proxy with SSL termination (nginx/traefik)${NC}"
log ""
log "${YELLOW}2. Update MCP configuration to use HTTPS endpoint${NC}"
log "   File: $MCP_CONFIG_FILE${NC}"
log "   Change 'http://192.168.0.183:8051/mcp'${NC}"
log "   To: 'https://192.168.0.183:443/mcp' or 'https://archon.agl.local/mcp'${NC}"
log ""
log "${YELLOW}3. Implement Authentication for SSE endpoints${NC}"
log "   SSE MCP endpoints require token-based authentication${NC}"
log "   Add middleware to validate bearer tokens${NC}"
log ""

# Implementation guide
echo ""
log "=== Implementation Steps ==="
log ""
log "1. Generate SSL certificate for Archon (if using port 8443):"
log "   openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout /etc/ssl/archon.key -out /etc/ssl/archon.crt"
log ""
log "2. Update Archon MCP server configuration:"
log "   server {"
log "     listen {"
log "       addr = ':443 ssl';"
log "       cert file = '/etc/ssl/archon.crt';"
log "       key file = '/etc/ssl/archon.key';"
log "   }"
log ""
log "3. Update MCP configuration in Claude:"
log "   mcp set archon https://archon.agl.local:443/mcp"
log ""
log "4. Restart Archon MCP server with new configuration"
log ""
