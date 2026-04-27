#!/bin/bash
# Dokploy Pre-Deploy Hook
# This script runs before deployment starts

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
APP_NAME="${APP_NAME:-laravel-app}"
BACKUP_DIR="${BACKUP_DIR:-/tmp/backups}"

echo -e "${GREEN}=== Dokploy Pre-Deploy Hook ===${NC}"
echo "Application: $APP_NAME"
echo "Timestamp: $(date)"

# 1. Environment validation
echo -e "\n${YELLOW}[1/5] Validating environment...${NC}"
if [ ! -f .env ]; then
    echo -e "${RED}Error: .env file not found${NC}"
    exit 1
fi

# Check required environment variables
required_vars=("APP_KEY" "DB_HOST" "DB_DATABASE" "DB_USERNAME" "DB_PASSWORD")
for var in "${required_vars[@]}"; do
    if grep -q "^${var}=" .env; then
        echo "✓ $var is set"
    else
        echo -e "${RED}✗ $var is missing${NC}"
        exit 1
    fi
done

# 2. Create backup directory
echo -e "\n${YELLOW}[2/5] Creating backup directory...${NC}"
mkdir -p "$BACKUP_DIR"

# 3. Database backup
echo -e "\n${YELLOW}[3/5] Creating database backup...${NC}"
BACKUP_FILE="$BACKUP_DIR/db_backup_$(date +%Y%m%d_%H%M%S).sql"

if command -v php &> /dev/null; then
    php artisan db:backup --filename="$BACKUP_FILE"
    echo -e "${GREEN}Database backed up to: $BACKUP_FILE${NC}"
else
    echo -e "${YELLOW}PHP not available, skipping database backup${NC}"
fi

# 4. Clear all caches
echo -e "\n${YELLOW}[4/5] Clearing caches...${NC}"
if command -v php &> /dev/null; then
    php artisan cache:clear
    php artisan config:clear
    php artisan route:clear
    php artisan view:clear
    echo -e "${GREEN}Caches cleared${NC}"
fi

# 5. Maintenance mode
echo -e "\n${YELLOW}[5/5] Enabling maintenance mode...${NC}"
if command -v php &> /dev/null; then
    php artisan down --render="maintenance.html" --retry=60
    echo -e "${GREEN}Maintenance mode enabled${NC}"
fi

echo -e "\n${GREEN}=== Pre-Deploy Hook Completed ===${NC}"
echo "You can now proceed with deployment"

exit 0
