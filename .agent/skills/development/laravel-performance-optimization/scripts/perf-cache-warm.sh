#!/bin/bash

###############################################################################
# Laravel Cache Warming Script
#
# Warms up the cache with frequently accessed data to improve
# initial response times and reduce database load.
#
# Usage:
#   ./perf-cache-warm.sh [full|quick|custom]
#
# Examples:
#   ./perf-cache-warm.sh full     # Cache everything
#   ./perf-cache-warm.sh quick    # Cache only hot data
#   ./perf-cache-warm.sh custom   # Interactive selection
###############################################################################

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
WARM_TYPE="${1:-quick}"
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

echo -e "${BLUE}=== Laravel Cache Warming ===${NC}"
echo "Type: ${WARM_TYPE}"
echo "Project: ${PROJECT_ROOT}"
echo ""

###############################################################################
# Check if application is ready
###############################################################################

check_application() {
    echo -e "${BLUE}Checking application status...${NC}"

    cd "${PROJECT_ROOT}"

    # Check if .env exists
    if [ ! -f "${PROJECT_ROOT}/.env" ]; then
        echo -e "${RED}✗ .env file not found${NC}"
        exit 1
    fi

    # Check database connection
    echo -n "Testing database connection... "
    if php artisan db:show &> /dev/null; then
        echo -e "${GREEN}OK${NC}"
    else
        echo -e "${YELLOW}WARNING${NC}"
    fi

    # Check Redis connection
    echo -n "Testing Redis connection... "
    if php artisan tinker --execute="Cache::put('test', 'value', 60); echo Cache::get('test');" &> /dev/null; then
        echo -e "${GREEN}OK${NC}"
    else
        echo -e "${YELLOW}WARNING${NC}"
        echo "  Cache warming will continue but may not be effective"
    fi

    echo ""
}

###############################################################################
# Warm configuration cache
###############################################################################

warm_config() {
    echo -e "${BLUE}Warming configuration cache...${NC}"

    cd "${PROJECT_ROOT}"

    echo -n "Caching configuration... "
    if php artisan config:cache &> /dev/null; then
        echo -e "${GREEN}DONE${NC}"
    else
        echo -e "${YELLOW}FAILED${NC}"
    fi

    echo -n "Caching routes... "
    if php artisan route:cache &> /dev/null; then
        echo -e "${GREEN}DONE${NC}"
    else
        echo -e "${YELLOW}FAILED${NC}"
    fi

    echo -n "Caching views... "
    if php artisan view:cache &> /dev/null; then
        echo -e "${GREEN}DONE${NC}"
    else
        echo -e "${YELLOW}FAILED${NC}"
    fi

    echo ""
}

###############################################################################
# Warm user permissions cache
###############################################################################

warm_user_permissions() {
    echo -e "${BLUE}Warming user permissions cache...${NC}"

    cd "${PROJECT_ROOT}"

    USER_COUNT=$(php artisan tinker --execute="
        \$count = App\Models\User::count();
        echo \$count;
    " 2> /dev/null | tail -n 1)

    echo "Found ${USER_COUNT} users"

    if [ "${USER_COUNT}" -gt 0 ]; then
        # Cache permissions for all users
        php artisan tinker --execute="
            \$users = App\Models\User::with(['roles', 'permissions'])->get();
            \$cache = app(App\Services\RedisCacheStrategy::class);

            foreach (\$users as \$user) {
                \$cache->cacheUserData(
                    \$user->id,
                    'permissions',
                    fn() => \$user->load('roles', 'permissions'),
                    'long'
                );
            }

            echo 'Cached permissions for ' . count(\$users) . ' users\n';
        " 2> /dev/null | grep "Cached permissions" || true

        echo -e "${GREEN}✓ User permissions cached${NC}"
    else
        echo -e "${YELLOW}⚠ No users found${NC}"
    fi

    echo ""
}

###############################################################################
# Warm container cache
###############################################################################

warm_containers() {
    echo -e "${BLUE}Warming container cache...${NC}"

    cd "${PROJECT_ROOT}"

    CONTAINER_COUNT=$(php artisan tinker --execute="
        \$count = App\Models\LxcContainer::count();
        echo \$count;
    " 2> /dev/null | tail -n 1)

    echo "Found ${CONTAINER_COUNT} containers"

    if [ "${CONTAINER_COUNT}" -gt 0 ]; then
        # Cache active containers
        php artisan tinker --execute="
            \$optimizer = app(App\Services\DatabaseQueryOptimizer::class);
            \$containers = \$optimizer->getContainersOptimized(['status' => 'running']);

            \$cache = app(App\Services\RedisCacheStrategy::class);
            \$cache->warmCache([
                'containers_running' => \$containers,
            ], 'containers');

            echo 'Cached ' . count(\$containers) . ' running containers\n';
        " 2> /dev/null | grep "Cached" || true

        # Cache container status counts
        php artisan tinker --execute="
            \$optimizer = app(App\Services\DatabaseQueryOptimizer::class);
            \$counts = \$optimizer->getContainerStatusCounts();

            Cache::put('container_status_counts', \$counts, 3600);
            echo 'Cached container status counts\n';
        " 2> /dev/null | grep "Cached" || true

        echo -e "${GREEN}✓ Container data cached${NC}"
    else
        echo -e "${YELLOW}⚠ No containers found${NC}"
    fi

    echo ""
}

###############################################################################
# Warm deployment cache
###############################################################################

warm_deployments() {
    echo -e "${BLUE}Warming deployment cache...${NC}"

    cd "${PROJECT_ROOT}"

    DEPLOYMENT_COUNT=$(php artisan tinker --execute="
        \$count = App\Models\DokployDeployment::count();
        echo \$count;
    " 2> /dev/null | tail -n 1)

    echo "Found ${DEPLOYMENT_COUNT} deployments"

    if [ "${DEPLOYMENT_COUNT}" -gt 0 ]; then
        # Cache recent deployments
        php artisan tinker --execute="
            \$optimizer = app(App\Services\DatabaseQueryOptimizer::class);
            \$deployments = \$optimizer->getDeploymentsOptimized([], 50);

            \$cache = app(App\Services\RedisCacheStrategy::class);
            \$cache->warmCache([
                'deployments_recent' => \$deployments,
            ], 'deployments');

            echo 'Cached recent deployments\n';
        " 2> /dev/null | grep "Cached" || true

        # Cache deployment statistics
        php artisan tinker --execute="
            \$optimizer = app(App\Services\DatabaseQueryOptimizer::class);
            \$stats = \$optimizer->getDeploymentStatistics(30);

            Cache::put('deployment_statistics', \$stats, 3600);
            echo 'Cached deployment statistics\n';
        " 2> /dev/null | grep "Cached" || true

        echo -e "${GREEN}✓ Deployment data cached${NC}"
    else
        echo -e "${YELLOW}⚠ No deployments found${NC}"
    fi

    echo ""
}

###############################################################################
# Warm application list cache
###############################################################################

warm_applications() {
    echo -e "${BLUE}Warming application cache...${NC}"

    cd "${PROJECT_ROOT}"

    APP_COUNT=$(php artisan tinker --execute="
        \$count = App\Models\DokployApplication::count();
        echo \$count;
    " 2> /dev/null | tail -n 1)

    echo "Found ${APP_COUNT} applications"

    if [ "${APP_COUNT}" -gt 0 ]; then
        # Cache applications list
        php artisan tinker --execute="
            \$apps = App\Models\DokployApplication::with(['user:id,name'])
                ->select(['id', 'name', 'type', 'user_id', 'project_id'])
                ->get();

            \$cache = app(App\Services\RedisCacheStrategy::class);
            \$cache->warmCache([
                'applications_list' => \$apps,
            ], 'deployments');

            echo 'Cached ' . count(\$apps) . ' applications\n';
        " 2> /dev/null | grep "Cached" || true

        echo -e "${GREEN}✓ Application data cached${NC}"
    else
        echo -e "${YELLOW}⚠ No applications found${NC}"
    fi

    echo ""
}

###############################################################################
# Warm metrics cache
###############################################################################

warm_metrics() {
    echo -e "${BLUE}Warming metrics cache...${NC}"

    cd "${PROJECT_ROOT}"

    # Cache recent activity
    php artisan tinker --execute="
        \$optimizer = app(App\Services\DatabaseQueryOptimizer::class);
        \$activity = \$optimizer->getRecentActivity(50);

        Cache::put('recent_activity', \$activity, 300);
        echo 'Cached recent activity\n';
    " 2> /dev/null | grep "Cached" || true

    # Cache active alerts
    php artisan tinker --execute="
        \$optimizer = app(App\Services\DatabaseQueryOptimizer::class);
        \$alerts = \$optimizer->getAlertsOptimized(['is_resolved' => false]);

        Cache::put('active_alerts', \$alerts, 300);
        echo 'Cached active alerts\n';
    " 2> /dev/null | grep "Cached" || true

    echo -e "${GREEN}✓ Metrics cached${NC}"
    echo ""
}

###############################################################################
# Warm external API cache
###############################################################################

warm_external_apis() {
    echo -e "${BLUE}Warming external API cache...${NC}"

    cd "${PROJECT_ROOT}"

    # Check if Proxmox integration is enabled
    PROXMOX_ENABLED=$(grep "PROXMOX_ENABLED=true" .env 2>/dev/null || echo "")
    if [ -n "${PROXMOX_ENABLED}" ]; then
        echo "Caching Proxmox data..."

        php artisan tinker --execute="
            try {
                \$client = app(App\Services\ProxmoxService::class);
                \$nodes = \$client->getNodes();

                \$cache = app(App\Services\RedisCacheStrategy::class);
                \$cache->cacheProxmoxResponse(
                    'nodes',
                    null,
                    fn() => \$nodes,
                    'short'
                );

                echo 'Cached Proxmox nodes\n';
            } catch (\Exception \$e) {
                echo 'Could not cache Proxmox data: ' . \$e->getMessage() . '\n';
            }
        " 2> /dev/null | grep "Cached" || true
    fi

    # Check if Dokploy integration is enabled
    DOKPLOY_ENABLED=$(grep "DOKPLOY_ENABLED=true" .env 2>/dev/null || echo "")
    if [ -n "${DOKPLOY_ENABLED}" ]; then
        echo "Caching Dokploy data..."

        php artisan tinker --execute="
            try {
                \$client = app(App\Services\DokployService::class);
                \$apps = \$client->getApplications();

                \$cache = app(App\Services\RedisCacheStrategy::class);
                \$cache->cacheDokployResponse(
                    'applications',
                    null,
                    fn() => \$apps,
                    'medium'
                );

                echo 'Cached Dokploy applications\n';
            } catch (\Exception \$e) {
                echo 'Could not cache Dokploy data: ' . \$e->getMessage() . '\n';
            }
        " 2> /dev/null | grep "Cached" || true
    fi

    # Check if Harbor integration is enabled
    HARBOR_ENABLED=$(grep "HARBOR_ENABLED=true" .env 2>/dev/null || echo "")
    if [ -n "${HARBOR_ENABLED}" ]; then
        echo "Caching Harbor data..."

        php artisan tinker --execute="
            try {
                \$client = app(App\Services\HarborService::class);
                \$projects = \$client->getProjects();

                \$cache = app(App\Services\RedisCacheStrategy::class);
                \$cache->cacheHarborResponse(
                    'projects',
                    null,
                    fn() => \$projects,
                    'long'
                );

                echo 'Cached Harbor projects\n';
            } catch (\Exception \$e) {
                echo 'Could not cache Harbor data: ' . \$e->getMessage() . '\n';
            }
        " 2> /dev/null | grep "Cached" || true
    fi

    echo ""
}

###############################################################################
# Generate cache report
###############################################################################

generate_report() {
    echo -e "${BLUE}Generating cache report...${NC}"

    REPORT_FILE="${PROJECT_ROOT}/storage/app/cache-warm-${TIMESTAMP}.txt"

    cd "${PROJECT_ROOT}"

    {
        echo "Cache Warming Report"
        echo "===================="
        echo ""
        echo "Type: ${WARM_TYPE}"
        echo "Timestamp: ${TIMESTAMP}"
        echo ""

        echo "Cache Statistics"
        echo "----------------"
        php artisan tinker --execute="
            \$metrics = app(App\Services\RedisCacheStrategy::class)
                ->getPerformanceMetrics();

            echo 'Hit Rate: ' . (\$metrics['hit_rate'] ?? 'N/A') . \"%\n\";
            echo 'Total Keys: ' . (\$metrics['key_count'] ?? 'N/A') . \"\n\";
            echo 'Memory Usage: ' . (\$metrics['redis_info']['used_memory'] ?? 'N/A') . \"\n\";
        " 2> /dev/null || true

        echo ""
        echo "Cache Keys"
        echo "----------"

        # List cache keys (if Redis is available)
        if command -v redis-cli &> /dev/null; then
            REDIS_HOST=$(grep "REDIS_HOST" .env | cut -d '=' -f2)
            REDIS_PORT=$(grep "REDIS_PORT" .env | cut -d '=' -f2)
            REDIS_DB=$(grep "REDIS_DB" .env | cut -d '=' -f2)

            redis-cli -h "${REDIS_HOST:-127.0.0.1}" -p "${REDIS_PORT:-6379}" -n "${REDIS_DB:-0}" \
                KEYS "laravel_*" | head -20 || true
        fi

    } | tee "${REPORT_FILE}"

    echo -e "${GREEN}Report saved to: ${REPORT_FILE}${NC}"
    echo ""
}

###############################################################################
# Main execution
###############################################################################

main() {
    check_application
    warm_config

    case "${WARM_TYPE}" in
        full)
            echo -e "${BLUE}Running full cache warming...${NC}"
            echo ""
            warm_user_permissions
            warm_containers
            warm_deployments
            warm_applications
            warm_metrics
            warm_external_apis
            ;;
        quick)
            echo -e "${BLUE}Running quick cache warming...${NC}"
            echo ""
            warm_containers
            warm_deployments
            warm_metrics
            ;;
        custom)
            echo -e "${BLUE}Custom cache warming${NC}"
            echo "Select what to warm:"
            echo "  1) Configuration only"
            echo "  2) Containers"
            echo "  3) Deployments"
            echo "  4) Applications"
            echo "  5) Metrics"
            echo "  6) All"
            echo ""
            read -p "Enter choice (1-6): " choice

            case "${choice}" in
                1) warm_config ;;
                2) warm_containers ;;
                3) warm_deployments ;;
                4) warm_applications ;;
                5) warm_metrics ;;
                6)
                    warm_user_permissions
                    warm_containers
                    warm_deployments
                    warm_applications
                    warm_metrics
                    warm_external_apis
                    ;;
                *) echo "Invalid choice" ;;
            esac
            ;;
        *)
            echo -e "${RED}Unknown type: ${WARM_TYPE}${NC}"
            echo "Usage: $0 [full|quick|custom]"
            exit 1
            ;;
    esac

    generate_report

    echo -e "${GREEN}=== Cache Warming Complete ===${NC}"
    echo ""
    echo "Benefits:"
    echo "  - Faster initial page loads"
    echo "  - Reduced database load"
    echo "  - Improved response times"
    echo "  - Better user experience"
    echo ""
    echo "Next steps:"
    echo "  1. Test application performance"
    echo "  2. Monitor cache hit rates"
    echo "  3. Schedule regular cache warming (cron)"
    echo ""
    echo "To schedule cache warming, add to crontab:"
    echo "  */15 * * * * ${PROJECT_ROOT}/agent/skills/development/laravel-performance-optimization/scripts/perf-cache-warm.sh quick"
}

main "$@"
