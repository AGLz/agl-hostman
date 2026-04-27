#!/bin/bash
# Dokploy Health Check Script
# Usage: ./health-check.sh [url] [max_attempts] [interval]
# Defaults: url=http://localhost/api/health, max_attempts=30, interval=2

# Configuration
HEALTH_URL="${1:-http://localhost/api/health}"
MAX_ATTEMPTS="${2:-30}"
ATTEMPT_INTERVAL="${3:-2}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}=== Health Check ===${NC}"
echo "URL: $HEALTH_URL"
echo "Max Attempts: $MAX_ATTEMPTS"
echo "Interval: ${ATTEMPT_INTERVAL}s"
echo ""

attempt=0
while [ $attempt -lt $MAX_ATTEMPTS ]; do
    attempt=$((attempt+1))

    # Make request and capture response
    response=$(curl -s -w "\n%{http_code}" "$HEALTH_URL" 2>&1)
    http_code=$(echo "$response" | tail -n1)
    body=$(echo "$response" | head -n-1)

    # Check if request was successful
    if [ "$http_code" = "200" ]; then
        echo -e "${GREEN}✓ Health check passed (attempt $attempt/$MAX_ATTEMPTS)${NC}"

        # Parse JSON response if jq is available
        if command -v jq &> /dev/null; then
            echo "$body" | jq -r '
                "Status: " + .status,
                "Timestamp: " + .timestamp,
                "Checks:",
                "  Database: " + .checks.database,
                "  Redis: " + .checks.redis,
                "  Storage: " + .checks.storage
            ' 2>/dev/null || echo "$body"
        else
            echo "Response: $body"
        fi

        exit 0
    fi

    echo -e "${YELLOW}Attempt $attempt/$MAX_ATTEMPTS failed (HTTP $http_code)${NC}"

    if [ $attempt -lt $MAX_ATTEMPTS ]; then
        sleep "$ATTEMPT_INTERVAL"
    fi
done

# All attempts failed
echo -e "${RED}✗ Health check failed after $MAX_ATTEMPTS attempts${NC}"
echo -e "${RED}Final response: HTTP $http_code${NC}"
echo "$body"

exit 1
