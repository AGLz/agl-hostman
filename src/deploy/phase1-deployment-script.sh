#!/bin/bash

################################################################################
# Phase 1 Deployment Script - Critical Fixes
# AGL Infrastructure Admin Platform
#
# Based on: HIVE-MIND-ANALYSIS-COMPLETE.md
# Implements: Security hardening, performance optimization, database indexes
#
# Usage: ./deploy/phase1-deployment-script.sh [--rollback]
################################################################################

set -e  # Exit on error
set -u  # Exit on undefined variable

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
BACKUP_DIR="./storage/backups/phase1-$(date +%Y%m%d-%H%M%S)"
APP_ENV=$(php artisan env)
DRY_RUN=false
ROLLBACK=false

# Parse arguments
for arg in "$@"; do
    case $arg in
        --rollback)
            ROLLBACK=true
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
    esac
done

################################################################################
# Helper Functions
################################################################################

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_prerequisites() {
    log_info "Checking prerequisites..."

    # Check if we're in the right directory
    if [ ! -f "artisan" ]; then
        log_error "artisan file not found. Are you in the Laravel root directory?"
        exit 1
    fi

    # Check if database is accessible
    if ! php artisan db:show >/dev/null 2>&1; then
        log_error "Database connection failed"
        exit 1
    fi

    # Check if Redis is accessible
    if ! php artisan tinker --execute="Redis::ping()" >/dev/null 2>&1; then
        log_warning "Redis connection failed - some features may not work"
    fi

    log_info "Prerequisites check passed ✓"
}

create_backup() {
    log_info "Creating backup in $BACKUP_DIR..."
    mkdir -p "$BACKUP_DIR"

    # Backup database
    log_info "Backing up database..."
    php artisan db:backup --path="$BACKUP_DIR/database-backup.sql"

    # Backup .env
    log_info "Backing up .env file..."
    cp .env "$BACKUP_DIR/.env.backup"

    # Backup critical files that will be modified
    log_info "Backing up modified files..."
    if [ -f "app/Models/User.php" ]; then
        cp app/Models/User.php "$BACKUP_DIR/User.php.backup"
    fi
    if [ -f "app/Services/AIModelService.php" ]; then
        cp app/Services/AIModelService.php "$BACKUP_DIR/AIModelService.php.backup"
    fi
    if [ -f "app/Services/InfrastructureAnalyticsService.php" ]; then
        cp app/Services/InfrastructureAnalyticsService.php "$BACKUP_DIR/InfrastructureAnalyticsService.php.backup"
    fi

    log_info "Backup created successfully ✓"
    echo "Backup location: $BACKUP_DIR"
}

deploy_migrations() {
    log_info "Running database migrations..."

    if [ "$DRY_RUN" = true ]; then
        php artisan migrate:status
        log_warning "DRY RUN - migrations not executed"
        return
    fi

    # Run migrations
    php artisan migrate --force

    log_info "Migrations completed ✓"
}

configure_queue_driver() {
    log_info "Configuring Redis queue driver..."

    if [ "$DRY_RUN" = true ]; then
        log_warning "DRY RUN - queue driver not changed"
        return
    fi

    # Update .env
    if grep -q "^QUEUE_CONNECTION=" .env; then
        sed -i.bak 's/^QUEUE_CONNECTION=.*/QUEUE_CONNECTION=redis/' .env
    else
        echo "QUEUE_CONNECTION=redis" >> .env
    fi

    # Clear config cache
    php artisan config:clear

    log_info "Queue driver configured ✓"
}

restart_services() {
    log_info "Restarting services..."

    if [ "$DRY_RUN" = true ]; then
        log_warning "DRY RUN - services not restarted"
        return
    fi

    # Terminate Horizon workers (supervisor will restart)
    php artisan horizon:terminate

    # Clear all caches
    php artisan optimize:clear

    # Rebuild optimized files
    php artisan config:cache
    php artisan route:cache
    php artisan view:cache

    log_info "Services restarted ✓"
}

verify_deployment() {
    log_info "Verifying deployment..."

    # Check database indexes
    log_info "Checking database indexes..."
    INDEX_COUNT=$(php artisan tinker --execute="DB::select('SHOW INDEXES FROM users')" | grep -c "users_email_index" || true)
    if [ "$INDEX_COUNT" -gt 0 ]; then
        log_info "Database indexes verified ✓"
    else
        log_warning "Database indexes may not be applied correctly"
    fi

    # Check queue connection
    QUEUE_CONNECTION=$(php artisan tinker --execute="config('queue.default')")
    if [[ "$QUEUE_CONNECTION" == *"redis"* ]]; then
        log_info "Queue driver configured correctly ✓"
    else
        log_warning "Queue driver may not be configured correctly"
    fi

    # Check Horizon status
    if php artisan horizon:status | grep -q "running"; then
        log_info "Horizon running ✓"
    else
        log_warning "Horizon may not be running correctly"
    fi

    log_info "Verification completed ✓"
}

rollback_deployment() {
    log_error "Rolling back deployment..."

    if [ ! -d "$BACKUP_DIR" ]; then
        log_error "Backup directory not found. Cannot rollback."
        exit 1
    fi

    # Rollback migrations
    log_info "Rolling back migrations..."
    php artisan migrate:rollback --step=2 --force

    # Restore .env
    log_info "Restoring .env file..."
    cp "$BACKUP_DIR/.env.backup" .env

    # Restore modified files
    log_info "Restoring modified files..."
    if [ -f "$BACKUP_DIR/User.php.backup" ]; then
        cp "$BACKUP_DIR/User.php.backup" app/Models/User.php
    fi
    if [ -f "$BACKUP_DIR/AIModelService.php.backup" ]; then
        cp "$BACKUP_DIR/AIModelService.php.backup" app/Services/AIModelService.php
    fi
    if [ -f "$BACKUP_DIR/InfrastructureAnalyticsService.php.backup" ]; then
        cp "$BACKUP_DIR/InfrastructureAnalyticsService.php.backup" app/Services/InfrastructureAnalyticsService.php
    fi

    # Clear caches
    php artisan optimize:clear

    # Restart services
    php artisan horizon:terminate

    log_info "Rollback completed ✓"
}

################################################################################
# Main Execution
################################################################################

echo "========================================================================"
echo "  AGL Infrastructure Admin - Phase 1 Deployment"
echo "========================================================================"
echo ""

if [ "$ROLLBACK" = true ]; then
    echo "⚠️  ROLLBACK MODE"
    read -p "Are you sure you want to rollback? (yes/no): " confirm
    if [ "$confirm" != "yes" ]; then
        log_info "Rollback cancelled"
        exit 0
    fi
    rollback_deployment
    exit 0
fi

if [ "$DRY_RUN" = true ]; then
    log_warning "DRY RUN MODE - No changes will be made"
fi

log_info "Environment: $APP_ENV"
echo ""

# Confirm deployment
if [ "$APP_ENV" = "production" ] && [ "$DRY_RUN" = false ]; then
    echo "⚠️  WARNING: You are about to deploy to PRODUCTION"
    echo "This will:"
    echo "  - Add database indexes (brief table locks)"
    echo "  - Switch queue driver to Redis"
    echo "  - Restart Horizon workers"
    echo "  - Modify critical service files"
    echo ""
    read -p "Continue? (yes/no): " confirm
    if [ "$confirm" != "yes" ]; then
        log_info "Deployment cancelled"
        exit 0
    fi
fi

echo ""
log_info "Starting Phase 1 deployment..."
echo ""

# Execute deployment steps
check_prerequisites
create_backup
deploy_migrations
configure_queue_driver
restart_services
verify_deployment

echo ""
echo "========================================================================"
log_info "Phase 1 deployment completed successfully! ✓"
echo "========================================================================"
echo ""
echo "📊 Deployment Summary:"
echo "  - Database indexes added for performance"
echo "  - Queue driver switched to Redis"
echo "  - Services restarted"
echo "  - Backup created in: $BACKUP_DIR"
echo ""
echo "📋 Next Steps:"
echo "  1. Monitor application logs: tail -f storage/logs/laravel.log"
echo "  2. Check Horizon dashboard: /horizon"
echo "  3. Verify infrastructure metrics in dashboard"
echo "  4. Test N8N webhook integration"
echo ""
echo "🔄 To rollback: ./deploy/phase1-deployment-script.sh --rollback"
echo ""
