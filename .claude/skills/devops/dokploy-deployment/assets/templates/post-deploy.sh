#!/bin/bash
# Dokploy Post-Deploy Hook
# This script runs after deployment completes

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
APP_NAME="${APP_NAME:-laravel-app}"
MAX_RETRIES=5
RETRY_DELAY=5

echo -e "${GREEN}=== Dokploy Post-Deploy Hook ===${NC}"
echo "Application: $APP_NAME"
echo "Timestamp: $(date)"

# 1. Run migrations
echo -e "\n${YELLOW}[1/6] Running database migrations...${NC}"
RETRY_COUNT=0
while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    if php artisan migrate --force; then
        echo -e "${GREEN}Migrations completed successfully${NC}"
        break
    else
        RETRY_COUNT=$((RETRY_COUNT+1))
        if [ $RETRY_COUNT -lt $MAX_RETRIES ]; then
            echo -e "${YELLOW}Migration failed, retrying in ${RETRY_DELAY}s... ($RETRY_COUNT/$MAX_RETRIES)${NC}"
            sleep $RETRY_DELAY
        else
            echo -e "${RED}Migration failed after $MAX_RETRIES attempts${NC}"
            exit 1
        fi
    fi
done

# 2. Seed database (optional)
if [ "${RUN_SEEDERS:-false}" = "true" ]; then
    echo -e "\n${YELLOW}[2/6] Running database seeders...${NC}"
    php artisan db:seed --force
    echo -e "${GREEN}Seeders completed${NC}"
else
    echo -e "\n${YELLOW}[2/6] Skipping seeders (set RUN_SEEDERS=true to enable)${NC}"
fi

# 3. Optimize application
echo -e "\n${YELLOW}[3/6] Optimizing application...${NC}"
php artisan config:cache
php artisan route:cache
php artisan view:cache
php artisan event:cache
echo -e "${GREEN}Application optimized${NC}"

# 4. Restart queue workers
echo -e "\n${YELLOW}[4/6] Restarting queue workers...${NC}"
php artisan queue:restart
echo -e "${GREEN}Queue workers restarted${NC}"

# 5. Clear OPcache
echo -e "\n${YELLOW}[5/6] Clearing OPcache...${NC}"
if php -r "exit(function_exists('opcache_reset') ? 0 : 1);"; then
    php artisan opcache:clear
    echo -e "${GREEN}OPcache cleared${NC}"
else
    echo -e "${YELLOW}OPcache not available${NC}"
fi

# 6. Health check
echo -e "\n${YELLOW}[6/6] Performing health check...${NC}"
HEALTH_CHECK_ATTEMPTS=0
HEALTH_CHECK_MAX=30

while [ $HEALTH_CHECK_ATTEMPTS -lt $HEALTH_CHECK_MAX ]; do
    if curl -f -s http://localhost/api/health > /dev/null; then
        echo -e "${GREEN}Health check passed${NC}"

        # Disable maintenance mode
        echo -e "\n${GREEN}Disabling maintenance mode...${NC}"
        php artisan up

        echo -e "\n${GREEN}=== Post-Deploy Hook Completed ===${NC}"
        echo "Deployment successful!"

        exit 0
    fi

    HEALTH_CHECK_ATTEMPTS=$((HEALTH_CHECK_ATTEMPTS+1))
    echo -e "${YELLOW}Health check failed, retrying in 2s... ($HEALTH_CHECK_ATTEMPTS/$HEALTH_CHECK_MAX)${NC}"
    sleep 2
done

# Health check failed
echo -e "${RED}Health check failed after $HEALTH_CHECK_MAX attempts${NC}"
echo -e "${RED}Keeping maintenance mode enabled${NC}"

exit 1
