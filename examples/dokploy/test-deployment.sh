#!/bin/bash
# Test Dokploy deployment with simple nginx container
# This script verifies Dokploy is working correctly before deploying agl-hostman

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== Dokploy Test Deployment ===${NC}"
echo "This script will deploy a test nginx container to verify Dokploy is working"
echo ""

# Configuration
DOKPLOY_HOST="${DOKPLOY_HOST:-192.168.0.180}"
DOKPLOY_PORT="${DOKPLOY_PORT:-3000}"
TEST_CONTAINER_NAME="dokploy-test-nginx"
TEST_PORT="8080"

# Function to print status
print_status() {
    echo -e "${YELLOW}➜${NC} $1"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

# Check if Dokploy is accessible
print_status "Checking Dokploy accessibility..."
if curl -s -o /dev/null -w "%{http_code}" "http://${DOKPLOY_HOST}:${DOKPLOY_PORT}" | grep -q "200\|302"; then
    print_success "Dokploy is accessible at http://${DOKPLOY_HOST}:${DOKPLOY_PORT}"
else
    print_error "Cannot access Dokploy at http://${DOKPLOY_HOST}:${DOKPLOY_PORT}"
    echo "Please verify:"
    echo "  1. CT180 is running: ssh root@192.168.0.245 'pct status 180'"
    echo "  2. Dokploy is running: ssh root@192.168.0.180 'docker ps | grep dokploy'"
    exit 1
fi

# Check if Docker is available
print_status "Checking Docker availability..."
if ! command -v docker &> /dev/null; then
    print_error "Docker is not installed or not in PATH"
    exit 1
fi
print_success "Docker is available"

# Check if test container already exists
print_status "Checking for existing test container..."
if docker ps -a --filter name=${TEST_CONTAINER_NAME} --format '{{.Names}}' | grep -q ${TEST_CONTAINER_NAME}; then
    print_status "Removing existing test container..."
    docker stop ${TEST_CONTAINER_NAME} 2>/dev/null || true
    docker rm ${TEST_CONTAINER_NAME} 2>/dev/null || true
    print_success "Removed existing test container"
fi

# Deploy test nginx container
print_status "Deploying test nginx container..."
docker run -d \
    --name ${TEST_CONTAINER_NAME} \
    --restart always \
    -p ${TEST_PORT}:80 \
    --label "com.dokploy.managed=true" \
    --label "com.dokploy.app=test-nginx" \
    --label "com.dokploy.env=test" \
    nginx:alpine

if [ $? -eq 0 ]; then
    print_success "Test container deployed successfully"
else
    print_error "Failed to deploy test container"
    exit 1
fi

# Wait for container to be ready
print_status "Waiting for container to be ready..."
sleep 3

# Check if container is running
if docker ps --filter name=${TEST_CONTAINER_NAME} --format '{{.Names}}' | grep -q ${TEST_CONTAINER_NAME}; then
    print_success "Container is running"
else
    print_error "Container failed to start"
    docker logs ${TEST_CONTAINER_NAME}
    exit 1
fi

# Test HTTP endpoint
print_status "Testing HTTP endpoint..."
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:${TEST_PORT}")
if [ "$HTTP_CODE" = "200" ]; then
    print_success "HTTP endpoint responding (HTTP $HTTP_CODE)"
else
    print_error "HTTP endpoint not responding (HTTP $HTTP_CODE)"
    docker logs ${TEST_CONTAINER_NAME}
    exit 1
fi

# Test with curl
print_status "Fetching welcome page..."
RESPONSE=$(curl -s "http://localhost:${TEST_PORT}" | grep -o "Welcome to nginx" || true)
if [ -n "$RESPONSE" ]; then
    print_success "Successfully fetched nginx welcome page"
else
    print_error "Could not fetch nginx welcome page"
fi

# Show container info
echo ""
echo -e "${GREEN}=== Test Container Information ===${NC}"
docker ps --filter name=${TEST_CONTAINER_NAME} --format "table {{.ID}}\t{{.Names}}\t{{.Status}}\t{{.Ports}}"
echo ""

# Show logs
echo -e "${GREEN}=== Container Logs ===${NC}"
docker logs ${TEST_CONTAINER_NAME} 2>&1 | tail -10
echo ""

# Summary
echo -e "${GREEN}=== Test Summary ===${NC}"
echo "Container Name: ${TEST_CONTAINER_NAME}"
echo "Port: ${TEST_PORT}"
echo "URL: http://localhost:${TEST_PORT}"
echo "Dokploy URL: http://${DOKPLOY_HOST}:${DOKPLOY_PORT}"
echo ""
echo -e "${GREEN}✓ Test deployment successful!${NC}"
echo ""
echo "Next steps:"
echo "  1. Verify in Dokploy UI: http://${DOKPLOY_HOST}:${DOKPLOY_PORT}"
echo "  2. Access test nginx: http://localhost:${TEST_PORT}"
echo "  3. To cleanup: docker stop ${TEST_CONTAINER_NAME} && docker rm ${TEST_CONTAINER_NAME}"
echo ""
echo "You can now proceed with deploying agl-hostman using the docker-compose.yml file."
