#!/bin/bash

# AGL Infrastructure Admin - Deployment Script
# Deploy to Dokploy via Harbor Registry

set -e

# Configuration
REGISTRY="harbor.aglz.io:5000"
PROJECT="agl-infrastructure"
IMAGE_NAME="agl-hostman-app"
TAG="${1:-latest}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== AGL Infrastructure Admin Deployment ===${NC}"

# Step 1: Build the Docker image
echo -e "${YELLOW}Building Docker image...${NC}"
docker build -t ${REGISTRY}/${PROJECT}/${IMAGE_NAME}:${TAG} .

# Step 2: Run tests
echo -e "${YELLOW}Running tests...${NC}"
docker run --rm ${REGISTRY}/${PROJECT}/${IMAGE_NAME}:${TAG} php artisan test || {
    echo -e "${RED}Tests failed! Aborting deployment.${NC}"
    exit 1
}

# Step 3: Login to Harbor
echo -e "${YELLOW}Logging in to Harbor...${NC}"
echo "Please enter Harbor credentials:"
read -p "Username: " HARBOR_USER
read -s -p "Password: " HARBOR_PASSWORD
echo
docker login -u ${HARBOR_USER} -p ${HARBOR_PASSWORD} ${REGISTRY}

# Step 4: Push to Harbor
echo -e "${YELLOW}Pushing image to Harbor...${NC}"
docker push ${REGISTRY}/${PROJECT}/${IMAGE_NAME}:${TAG}

# Step 5: Trigger Dokploy webhook
echo -e "${YELLOW}Triggering Dokploy deployment...${NC}"
DOKPLOY_WEBHOOK="https://dok.aglz.io/api/webhooks/deploy"
curl -X POST ${DOKPLOY_WEBHOOK} \
    -H "Content-Type: application/json" \
    -d "{
        \"image\": \"${REGISTRY}/${PROJECT}/${IMAGE_NAME}:${TAG}\",
        \"service\": \"agl-hostman\",
        \"environment\": \"production\"
    }"

echo -e "${GREEN}Deployment complete!${NC}"
echo -e "Image: ${REGISTRY}/${PROJECT}/${IMAGE_NAME}:${TAG}"
echo -e "Access the application at: https://admin.aglz.io"