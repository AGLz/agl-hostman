#!/bin/bash
set -e

# Deploy the patch to CT 183
# Usage: ./deploy.sh [--restart]

RESTART="${1:-}"

echo "=== Archon Stack Deployment ==="
echo "Target: CT 183 (archon) - Tailscale: 100.80.30.59"
echo ""

# Copy docker-compose to CT 183 (via Proxmox host)
echo "Copying docker-compose-hostnet.yml to CT 183..."
ssh root@100.107.113.33 'mkdir -p /root/Archon'
ssh root@100.107.113.33 'pct exec 183 -- mkdir -p /root/Archon'
scp docker-compose-hostnet.yml root@100.107.113.33:/root/Archon/
ssh root@100.107.113.33 'cp /root/Archon/docker-compose-hostnet.yml /var/lib/lxc/183/root/Archon/'

if [ "$RESTART" == "--restart" ]; then
    echo "Recreating containers with new configuration..."
    ssh root@100.80.30.59 'cd /root/Archon && docker compose -f docker-compose-hostnet.yml up -d --force-recreate'

    echo ""
    echo "Waiting for services to start..."
    sleep 5

    # Check health
    echo "Checking health endpoint..."
    HEALTH=$(ssh root@100.80.30.59 'curl -s http://localhost:8181/health')
    echo "Health: $HEALTH"

    # Check container status
    echo ""
    echo "Container status:"
    ssh root@100.80.30.59 'docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"'
fi

echo ""
echo "=== Deployment Complete ==="
echo ""
echo "Endpoints:"
echo "  API:  http://100.80.30.59:8181"
echo "  MCP:  http://100.80.30.59:8051/mcp"
echo "  UI:   http://100.80.30.59:3737"
echo "  CF:   https://archon.aglz.io"
