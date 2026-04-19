#!/bin/bash
###############################################################################
# Fix All Portainer Agents Script
# Automatically fixes Portainer Agent crash loops across AGL infrastructure
#
# Issue: Docker Swarm DNS resolution failures causing agent restarts
# Solution: Set AGENT_CLUSTER_ADDR=127.0.0.1 environment variable
#
# Usage:
#   ./fix-all-portainer-agents.sh [--via-proxmox]
#
# Options:
#   --via-proxmox   Use Proxmox 'pct enter' instead of SSH (if running on host)
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

# Parse arguments
VIA_PROXMOX=false
if [[ "${1:-}" == "--via-proxmox" ]]; then
    VIA_PROXMOX=true
    log_info "Using Proxmox pct enter mode"
fi

# Hosts to fix (IP:Hostname:CT_ID)
HOSTS=(
    "192.168.0.180:dokploy:180"
    "192.168.0.183:archon:183"
    "192.168.0.202:n8n-docker:202"
)

# Agent installation/fix script (runs inside container)
read -r -d '' AGENT_FIX_SCRIPT << 'SCRIPT' || true
#!/bin/bash
set -e

echo "=== Portainer Agent Fix Script ==="
echo "Host: $(hostname)"
echo ""

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo "ERROR: Docker not found. Please install Docker first."
    exit 1
fi

echo "Docker version: $(docker --version)"
echo ""

# Check for existing Portainer agent
echo "Checking for existing Portainer agent..."
if docker ps -a | grep -q portainer_agent; then
    echo "Found existing Portainer agent"

    # Check if it's crashing
    STATUS=$(docker inspect portainer_agent --format='{{.State.Status}}' 2>/dev/null || echo "not found")
    echo "Current status: $STATUS"

    if [[ "$STATUS" == "restarting" ]] || [[ "$STATUS" == "exited" ]]; then
        echo "Agent is in crash loop. Fixing..."

        # Stop and remove
        echo "Stopping and removing old agent..."
        docker stop portainer_agent 2>/dev/null || true
        docker rm portainer_agent 2>/dev/null || true
        echo "Old agent removed"
    else
        echo "Agent appears to be running. Recreating with proper configuration..."
        docker stop portainer_agent 2>/dev/null || true
        docker rm portainer_agent 2>/dev/null || true
    fi
else
    echo "No existing agent found. Installing new one..."
fi

echo ""
echo "Creating Portainer agent with Swarm fix..."

# Create agent with proper configuration
docker run -d \
  --name=portainer_agent \
  --restart=always \
  -e AGENT_CLUSTER_ADDR=127.0.0.1 \
  -p 9001:9001 \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v /var/lib/docker/volumes:/var/lib/docker/volumes \
  portainer/agent:2.16.2

if [ $? -eq 0 ]; then
    echo "✓ Agent container created successfully"
else
    echo "✗ Failed to create agent container"
    exit 1
fi

# Wait for agent to start
echo ""
echo "Waiting for agent to start..."
sleep 5

# Verify agent is running
echo ""
echo "Verifying agent status..."
if docker ps | grep -q portainer_agent; then
    echo "✓ Agent is running"
    docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep portainer_agent
    echo ""

    # Check logs for errors
    echo "Checking agent logs (last 10 lines)..."
    docker logs portainer_agent --tail 10 2>&1 | grep -E "(starting|listening|INFO|ERROR|FTL)" || echo "No critical messages"

    # Check if agent API is responding
    echo ""
    echo "Testing agent API..."
    if curl -s http://localhost:9001 > /dev/null 2>&1; then
        echo "✓ Agent API is responding on port 9001"
    else
        echo "⚠ Agent API not responding yet (may need a few more seconds)"
    fi

    echo ""
    echo "=== Fix completed successfully ==="
    exit 0
else
    echo "✗ Agent not running after creation"
    echo "Logs:"
    docker logs portainer_agent --tail 20
    exit 1
fi
SCRIPT

# Function to fix via SSH
fix_via_ssh() {
    local ip=$1
    local hostname=$2

    log_info "Fixing Portainer Agent on $hostname ($ip) via SSH..."

    # Test connectivity
    if ! ping -c 1 -W 2 "$ip" &>/dev/null; then
        log_error "Host $hostname ($ip) not reachable"
        return 1
    fi

    # Execute fix script via SSH
    if ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no root@"$ip" bash << EOF
$AGENT_FIX_SCRIPT
EOF
    then
        log_success "Agent fixed on $hostname ($ip)"
        return 0
    else
        log_error "Failed to fix agent on $hostname ($ip)"
        log_warning "You may need to run this manually: ssh root@$ip"
        return 1
    fi
}

# Function to fix via Proxmox pct
fix_via_proxmox() {
    local ct_id=$1
    local hostname=$2

    log_info "Fixing Portainer Agent on $hostname (CT$ct_id) via Proxmox..."

    # Check if CT exists
    if ! pct status "$ct_id" &>/dev/null; then
        log_error "Container CT$ct_id not found"
        return 1
    fi

    # Check if CT is running
    if ! pct status "$ct_id" | grep -q "running"; then
        log_error "Container CT$ct_id is not running"
        return 1
    fi

    # Execute fix script via pct enter
    if echo "$AGENT_FIX_SCRIPT" | pct enter "$ct_id"; then
        log_success "Agent fixed on $hostname (CT$ct_id)"
        return 0
    else
        log_error "Failed to fix agent on $hostname (CT$ct_id)"
        return 1
    fi
}

# Main execution
echo ""
echo "========================================="
echo "  Portainer Agents Fix Script"
echo "========================================="
echo ""
echo "This script will fix Portainer Agent crash loops on:"
for entry in "${HOSTS[@]}"; do
    IFS=':' read -r ip hostname ct_id <<< "$entry"
    echo "  - $hostname ($ip / CT$ct_id)"
done
echo ""

# Track results
FIXED=0
FAILED=0
TOTAL=${#HOSTS[@]}

for entry in "${HOSTS[@]}"; do
    IFS=':' read -r ip hostname ct_id <<< "$entry"
    echo ""
    echo "--- Processing $hostname ---"

    if [ "$VIA_PROXMOX" = true ]; then
        if fix_via_proxmox "$ct_id" "$hostname"; then
            ((FIXED++))
        else
            ((FAILED++))
        fi
    else
        if fix_via_ssh "$ip" "$hostname"; then
            ((FIXED++))
        else
            ((FAILED++))
            log_info "You can try manually: ssh root@$ip"
            log_info "Or run this script with --via-proxmox from Proxmox host"
        fi
    fi
done

# Summary
echo ""
echo "========================================="
echo "  Summary"
echo "========================================="
echo "Total hosts: $TOTAL"
echo "Successfully fixed: $FIXED"
echo "Failed: $FAILED"
echo ""

if [ "$FAILED" -gt 0 ]; then
    log_warning "Some agents could not be fixed automatically"
    log_info "For manual fix, see: /mnt/overpower/apps/dev/agl/agl-hostman/docs/PORTAINER-AGENTS-FIX-GUIDE.md"
    exit 1
fi

log_success "All agents fixed successfully!"
echo ""
echo "Next steps:"
echo "1. Access Portainer Server: http://192.168.0.103:9000"
echo "2. Add environments for each agent:"
for entry in "${HOSTS[@]}"; do
    IFS=':' read -r ip hostname ct_id <<< "$entry"
    echo "   - $hostname: $ip:9001"
done
echo ""

exit 0
