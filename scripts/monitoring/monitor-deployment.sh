#!/bin/bash
#
# YouTube Analysis System - Deployment Monitor
# Run this script on Proxmox host 100.107.113.33 to monitor deployment progress
#

CONTAINER_ID="200"
CONTAINER_IP="192.168.1.200"

echo "========================================="
echo "YouTube Analysis System - Deployment Monitor"
echo "========================================="
echo ""

# Function to check deployment script status
check_deployment_script() {
    echo "1. Checking deployment script status..."
    if ps aux | grep -q "[d]eploy.sh"; then
        echo "   ✓ Deployment script is still running"
        echo "   ⏳ Please wait for completion (this may take 20-30 minutes total)"
        return 1
    else
        echo "   ✓ Deployment script has completed"
        return 0
    fi
}

# Function to check container status
check_container() {
    echo ""
    echo "2. Checking container status..."
    if pct status ${CONTAINER_ID} 2>/dev/null | grep -q "running"; then
        echo "   ✓ Container ${CONTAINER_ID} is running"
        return 0
    else
        echo "   ✗ Container ${CONTAINER_ID} is not running"
        return 1
    fi
}

# Function to check services
check_services() {
    echo ""
    echo "3. Checking services inside container..."

    local output=$(pct exec ${CONTAINER_ID} -- supervisorctl status 2>/dev/null)

    if [ -z "$output" ]; then
        echo "   ⏳ Supervisor not configured yet"
        return 1
    fi

    echo "$output" | while read line; do
        if echo "$line" | grep -q "RUNNING"; then
            echo "   ✓ $line"
        else
            echo "   ⏳ $line"
        fi
    done
}

# Function to test API
test_api() {
    echo ""
    echo "4. Testing API endpoint..."

    local response=$(curl -s --connect-timeout 5 http://${CONTAINER_IP}:8000/api/v1/health 2>&1)

    if echo "$response" | grep -q "healthy"; then
        echo "   ✓ API is healthy and responding"
        echo "   Response: $response"
        return 0
    else
        echo "   ⏳ API not responding yet"
        echo "   Response: $response"
        return 1
    fi
}

# Function to get API documentation URL
show_next_steps() {
    echo ""
    echo "========================================="
    echo "✓ DEPLOYMENT SUCCESSFUL!"
    echo "========================================="
    echo ""
    echo "API URLs:"
    echo "  - Health Check:  http://${CONTAINER_IP}:8000/api/v1/health"
    echo "  - API Docs:      http://${CONTAINER_IP}:8000/docs"
    echo "  - ReDoc:         http://${CONTAINER_IP}:8000/redoc"
    echo ""
    echo "Next Steps:"
    echo "1. Generate API key:"
    echo "   pct exec ${CONTAINER_ID} -- su - youtube -c 'cd /opt/youtube-analysis/app && source ../venv/bin/activate && python3 -c \"import secrets; print(\\\"API Key:\\\", secrets.token_urlsafe(32))\"'"
    echo ""
    echo "2. Update .env with API key hash:"
    echo "   pct exec ${CONTAINER_ID} -- nano /opt/youtube-analysis/.env"
    echo ""
    echo "3. Restart services:"
    echo "   pct exec ${CONTAINER_ID} -- supervisorctl restart all"
    echo ""
    echo "4. Test download:"
    echo "   curl -X POST http://${CONTAINER_IP}:8000/api/v1/download \\"
    echo "     -H \"Content-Type: application/json\" \\"
    echo "     -H \"X-API-Key: YOUR_API_KEY\" \\"
    echo "     -d '{\"url\": \"https://www.youtube.com/watch?v=dQw4w9WgXcQ\", \"quality\": \"medium\"}'"
    echo ""
    echo "For full documentation, see:"
    echo "  /root/youtube-analysis-system/README.md"
    echo ""
}

# Function to show deployment progress
show_deployment_progress() {
    echo ""
    echo "========================================="
    echo "⏳ DEPLOYMENT IN PROGRESS"
    echo "========================================="
    echo ""
    echo "The deployment script is still running. Progress:"
    echo ""

    # Check which stage we're at
    if pct status ${CONTAINER_ID} 2>/dev/null | grep -q "running"; then
        echo "✓ Container created and started"

        if pct exec ${CONTAINER_ID} -- test -f /opt/youtube-analysis/.env 2>/dev/null; then
            echo "✓ Configuration generated"
        else
            echo "⏳ Installing dependencies and configuring..."
        fi

        if pct exec ${CONTAINER_ID} -- systemctl is-active redis-server 2>/dev/null | grep -q "active"; then
            echo "✓ Redis service running"
        else
            echo "⏳ Setting up services..."
        fi

        if pct exec ${CONTAINER_ID} -- test -d /opt/youtube-analysis/venv 2>/dev/null; then
            echo "✓ Python virtual environment created"
        else
            echo "⏳ Creating Python environment..."
        fi
    else
        echo "⏳ Creating container..."
    fi

    echo ""
    echo "Estimated time remaining: 10-20 minutes"
    echo "Run this script again in a few minutes to check progress."
    echo ""
}

# Main execution
main() {
    if check_deployment_script; then
        if check_container; then
            check_services
            if test_api; then
                show_next_steps
                exit 0
            else
                echo ""
                echo "⏳ Services are starting up. Please wait 1-2 minutes and try again."
                echo ""
                exit 1
            fi
        else
            echo ""
            echo "✗ Container not running. Check deployment logs:"
            echo "   cat /root/youtube-analysis-system/deploy.log"
            echo ""
            exit 1
        fi
    else
        show_deployment_progress
        exit 2
    fi
}

# Run monitoring
main
