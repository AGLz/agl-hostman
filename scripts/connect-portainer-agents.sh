#!/bin/bash
###############################################################################
# Connect All Portainer Agents to Portainer Server
# Automatically adds all 7 agents as endpoints via Portainer API
###############################################################################

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Configuration
PORTAINER_URL="https://portainer.aglz.io"
PORTAINER_USER="admin"
PORTAINER_PASS="lx4936@klfap"

# Agents to add (Name:IP:Port)
AGENTS=(
    "agldv03:192.168.0.179:9001"
    "gameserver:192.168.0.161:9001"
    "agldv04:192.168.0.181:9001"
    "dokploy:192.168.0.180:9001"
    "archon:192.168.0.183:9001"
    "n8n-docker:192.168.0.202:9001"
    "ollama:192.168.0.200:9001"
)

echo ""
echo "========================================="
echo "  Portainer Agents Connection Script"
echo "========================================="
echo ""
echo "Server: $PORTAINER_URL"
echo "Total Agents: ${#AGENTS[@]}"
echo ""

# Step 1: Authenticate and get JWT token
log_info "Authenticating with Portainer..."
AUTH_RESPONSE=$(curl -s -X POST "${PORTAINER_URL}/api/auth" \
    -H "Content-Type: application/json" \
    -d "{\"Username\":\"${PORTAINER_USER}\",\"Password\":\"${PORTAINER_PASS}\"}")

JWT_TOKEN=$(echo "$AUTH_RESPONSE" | jq -r '.jwt // empty')

if [ -z "$JWT_TOKEN" ] || [ "$JWT_TOKEN" = "null" ]; then
    log_error "Authentication failed!"
    echo "Response: $AUTH_RESPONSE"
    exit 1
fi

log_success "Authenticated successfully!"
echo "Token: ${JWT_TOKEN:0:20}..."
echo ""

# Step 2: Add each agent as endpoint
ADDED=0
FAILED=0
SKIPPED=0

for agent in "${AGENTS[@]}"; do
    IFS=':' read -r name ip port <<< "$agent"

    echo "--- Processing $name ($ip:$port) ---"

    # Check if endpoint already exists
    EXISTING=$(curl -s -X GET "${PORTAINER_URL}/api/endpoints" \
        -H "Authorization: Bearer ${JWT_TOKEN}" | jq -r ".[] | select(.Name == \"${name}\") | .Id // empty")

    if [ ! -z "$EXISTING" ]; then
        log_warning "Endpoint '$name' already exists (ID: $EXISTING)"
        ((SKIPPED++))
        echo ""
        continue
    fi

    # Create endpoint
    log_info "Adding endpoint '$name'..."

    CREATE_RESPONSE=$(curl -s -X POST "${PORTAINER_URL}/api/endpoints" \
        -H "Authorization: Bearer ${JWT_TOKEN}" \
        -H "Content-Type: application/json" \
        -d "{
            \"Name\": \"${name}\",
            \"EndpointCreationType\": 1,
            \"EndpointType\": 2,
            \"URL\": \"tcp://${ip}:${port}\",
            \"PublicURL\": \"\",
            \"TLS\": false,
            \"TLSSkipVerify\": false,
            \"TLSSkipClientVerify\": false
        }")

    ENDPOINT_ID=$(echo "$CREATE_RESPONSE" | jq -r '.Id // empty')

    if [ ! -z "$ENDPOINT_ID" ] && [ "$ENDPOINT_ID" != "null" ]; then
        log_success "Endpoint '$name' added successfully (ID: $ENDPOINT_ID)"
        ((ADDED++))
    else
        log_error "Failed to add endpoint '$name'"
        echo "Response: $CREATE_RESPONSE"
        ((FAILED++))
    fi

    echo ""
done

# Summary
echo "========================================="
echo "  Summary"
echo "========================================="
echo "Total agents: ${#AGENTS[@]}"
echo "Successfully added: $ADDED"
echo "Already existed: $SKIPPED"
echo "Failed: $FAILED"
echo ""

if [ "$FAILED" -gt 0 ]; then
    log_warning "Some endpoints could not be added"
    exit 1
fi

if [ "$ADDED" -eq 0 ] && [ "$SKIPPED" -eq ${#AGENTS[@]} ]; then
    log_info "All agents were already connected"
else
    log_success "All agents connected successfully!"
fi

echo ""
echo "Access Portainer: $PORTAINER_URL"
echo "Go to: Environments → Check all endpoints are green"
echo ""

exit 0
