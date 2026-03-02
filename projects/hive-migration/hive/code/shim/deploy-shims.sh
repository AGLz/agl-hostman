#!/bin/bash
#
# PHP 8.1 Compatibility Shims Deployment Script
# ==============================================
#
# This script deploys all compatibility shims to the Laravel project
# Target: FGSRV05 (100.71.107.26) /var/www/fg_OLD2_NEW
#
# Usage:
#   1. Copy this directory to the server
#   2. Run: ./deploy-shims.sh
#

set -e

echo "========================================"
echo "PHP 8.1 Compatibility Shims Deployment"
echo "========================================"

# Configuration
LARAVEL_ROOT="${LARAVEL_ROOT:-/var/www/fg_OLD2_NEW}"
HELPERS_DIR="$LARAVEL_ROOT/app/Helpers"
TESTS_DIR="$LARAVEL_ROOT/tests/Unit/Helpers"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Function to print status
print_status() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

# Check if Laravel root exists
if [ ! -d "$LARAVEL_ROOT" ]; then
    print_error "Laravel root not found: $LARAVEL_ROOT"
    echo "Set LARAVEL_ROOT environment variable to the correct path"
    exit 1
fi

print_status "Laravel root found: $LARAVEL_ROOT"

# Step 1: Create directories
echo ""
echo "Step 1: Creating directories..."
mkdir -p "$HELPERS_DIR"
mkdir -p "$TESTS_DIR"
print_status "Directories created"

# Step 2: Deploy shim files
echo ""
echo "Step 2: Deploying shim files..."

SHIM_FILES=(
    "MysqlCompatibility.php"
    "MoneyFormatShim.php"
    "InputFacade.php"
    "StringFunctions.php"
)

for file in "${SHIM_FILES[@]}"; do
    if [ -f "$file" ]; then
        cp "$file" "$HELPERS_DIR/"
        print_status "Deployed: $file"
    else
        print_error "Missing: $file"
        exit 1
    fi
done

# Step 3: Deploy unit tests
echo ""
echo "Step 3: Deploying unit tests..."

TEST_FILES=(
    "MysqlCompatibilityTest.php"
    "MoneyFormatShimTest.php"
    "StringFunctionsTest.php"
)

for file in "${TEST_FILES[@]}"; do
    if [ -f "$file" ]; then
        cp "$file" "$TESTS_DIR/"
        print_status "Deployed: $file"
    else
        print_warning "Missing test: $file (optional)"
    fi
done

# Step 4: Update composer.json
echo ""
echo "Step 4: Updating composer.json..."
echo ""
print_warning "MANUAL STEP REQUIRED:"
echo "Add the following to your composer.json 'autoload.files' section:"
echo ""
cat composer-autoload-snippet.json
echo ""
read -p "Press Enter when you've updated composer.json..."

# Step 5: Update config/app.php
echo ""
echo "Step 5: Updating config/app.php..."
echo ""
print_warning "MANUAL STEP REQUIRED:"
echo "Add the following to your config/app.php 'aliases' section:"
echo ""
cat app-php-aliases-snippet.php
echo ""
read -p "Press Enter when you've updated config/app.php..."

# Step 6: Regenerate autoload
echo ""
echo "Step 6: Regenerating autoload..."
cd "$LARAVEL_ROOT"
composer dump-autoload
print_status "Autoload regenerated"

# Step 7: Clear caches
echo ""
echo "Step 7: Clearing Laravel caches..."
php artisan cache:clear
php artisan config:clear
php artisan route:clear
print_status "Caches cleared"

# Step 8: Run unit tests (optional)
echo ""
read -p "Run unit tests now? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "Running unit tests..."
    cd "$LARAVEL_ROOT"
    php artisan test --filter=Helpers
    print_status "Unit tests completed"
fi

# Summary
echo ""
echo "========================================"
echo "           DEPLOYMENT SUMMARY"
echo "========================================"
echo ""
echo "Shims deployed to: $HELPERS_DIR"
echo "Tests deployed to: $TESTS_DIR"
echo ""
echo "Next steps:"
echo "1. Test critical endpoints:"
echo "   curl -H \"Authorization: Bearer TOKEN\" https://api.falg.com.br/api/recibo/1"
echo ""
echo "2. Monitor logs for errors:"
echo "   tail -f $LARAVEL_ROOT/storage/logs/laravel.log"
echo ""
echo "3. Run full test suite:"
echo "   php artisan test"
echo ""
print_status "Deployment complete!"
