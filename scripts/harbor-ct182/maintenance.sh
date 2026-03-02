#!/bin/bash
#
# Harbor Maintenance Script
# Daily/weekly maintenance tasks for Harbor CT182
#

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
CTID=182
HARBOR_DIR="/opt/harbor"
DATA_DIR="/var/harbor"
LOG_DIR="/var/log/harbor"
HARBOR_URL="https://192.168.1.182"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Harbor Maintenance Script${NC}"
echo -e "${BLUE}========================================${NC}"

# Check if running on Proxmox host or container
if command -v pct &> /dev/null && pct status $CTID &> /dev/null; then
    RUN_PREFIX="pct exec $CTID --"
    echo -e "${GREEN}Running maintenance on CT$CTID${NC}"
else
    RUN_PREFIX=""
    echo -e "${GREEN}Running maintenance directly${NC}"
fi

# Function to execute commands
run_cmd() {
    if [ -n "$RUN_PREFIX" ]; then
        $RUN_PREFIX bash -c "$1"
    else
        bash -c "$1"
    fi
}

# Health check
health_check() {
    echo -e "${GREEN}Performing health check...${NC}"

    # Check Harbor services
    echo -e "${YELLOW}Checking Harbor services...${NC}"
    run_cmd "cd $HARBOR_DIR && docker-compose ps"

    # Check API health
    echo -e "${YELLOW}Checking API health...${NC}"
    if run_cmd "curl -k -s $HARBOR_URL/api/v2.0/health" | grep -q "healthy"; then
        echo -e "${GREEN}✓ Harbor API is healthy${NC}"
    else
        echo -e "${RED}✗ Harbor API is not responding${NC}"
    fi

    # Check disk space
    echo -e "${YELLOW}Checking disk space...${NC}"
    run_cmd "df -h $DATA_DIR"

    USAGE=$(run_cmd "df $DATA_DIR | tail -1 | awk '{print \$5}' | sed 's/%//'")
    if [ "$USAGE" -gt 80 ]; then
        echo -e "${RED}WARNING: Disk usage is at ${USAGE}%${NC}"
    else
        echo -e "${GREEN}✓ Disk usage is at ${USAGE}%${NC}"
    fi

    # Check memory usage
    echo -e "${YELLOW}Checking memory usage...${NC}"
    run_cmd "free -h"

    # Check Docker daemon
    echo -e "${YELLOW}Checking Docker daemon...${NC}"
    if run_cmd "docker info > /dev/null 2>&1"; then
        echo -e "${GREEN}✓ Docker daemon is running${NC}"
    else
        echo -e "${RED}✗ Docker daemon is not running${NC}"
    fi
}

# Log rotation
log_rotation() {
    echo -e "${GREEN}Performing log rotation...${NC}"

    run_cmd "mkdir -p $LOG_DIR"

    # Rotate Harbor logs
    echo -e "${YELLOW}Rotating Harbor container logs...${NC}"
    run_cmd "cd $HARBOR_DIR && docker-compose exec -T registry sh -c 'find /var/log/harbor -name \"*.log\" -mtime +7 -exec gzip {} \;'" || true

    # Clean old logs
    echo -e "${YELLOW}Removing logs older than 30 days...${NC}"
    run_cmd "find $LOG_DIR -name '*.gz' -mtime +30 -delete" || true

    # Rotate Docker logs
    echo -e "${YELLOW}Checking Docker log sizes...${NC}"
    run_cmd "du -sh /var/lib/docker/containers/*/‌*-json.log" || true
}

# Database maintenance
database_maintenance() {
    echo -e "${GREEN}Performing database maintenance...${NC}"

    # Vacuum database
    echo -e "${YELLOW}Vacuuming PostgreSQL database...${NC}"
    run_cmd "cd $HARBOR_DIR && docker-compose exec -T postgresql psql -U postgres -d registry -c 'VACUUM ANALYZE;'" || true

    # Check database size
    echo -e "${YELLOW}Checking database size...${NC}"
    run_cmd "cd $HARBOR_DIR && docker-compose exec -T postgresql psql -U postgres -c \"SELECT pg_size_pretty(pg_database_size('registry'));\"" || true

    # Reindex database (optional, run monthly)
    if [ "${1:-}" == "--full" ]; then
        echo -e "${YELLOW}Reindexing database (this may take a while)...${NC}"
        run_cmd "cd $HARBOR_DIR && docker-compose exec -T postgresql psql -U postgres -d registry -c 'REINDEX DATABASE registry;'" || true
    fi
}

# Docker cleanup
docker_cleanup() {
    echo -e "${GREEN}Performing Docker cleanup...${NC}"

    # Remove stopped containers
    echo -e "${YELLOW}Removing stopped containers...${NC}"
    run_cmd "docker container prune -f" || true

    # Remove unused images
    echo -e "${YELLOW}Removing unused images...${NC}"
    run_cmd "docker image prune -af --filter 'until=168h'" || true

    # Remove unused volumes (be careful!)
    if [ "${1:-}" == "--full" ]; then
        echo -e "${YELLOW}Removing unused volumes...${NC}"
        run_cmd "docker volume prune -f" || true
    fi

    # Remove unused networks
    echo -e "${YELLOW}Removing unused networks...${NC}"
    run_cmd "docker network prune -f" || true

    # Clean build cache
    echo -e "${YELLOW}Cleaning build cache...${NC}"
    run_cmd "docker builder prune -af --filter 'until=168h'" || true
}

# Security scan
security_scan() {
    echo -e "${GREEN}Performing security scan...${NC}"

    # Check for container vulnerabilities (if Trivy is available)
    echo -e "${YELLOW}Scanning Harbor images for vulnerabilities...${NC}"
    run_cmd "cd $HARBOR_DIR && docker-compose images -q | xargs -I {} docker run --rm -v /var/run/docker.sock:/var/run/docker.sock aquasec/trivy image --severity HIGH,CRITICAL {}" || echo -e "${YELLOW}Trivy not available, skipping...${NC}"

    # Check SSL certificate expiration
    echo -e "${YELLOW}Checking SSL certificate expiration...${NC}"
    run_cmd "openssl x509 -in $HARBOR_DIR/ssl/harbor.crt -noout -enddate" || true
}

# Performance metrics
performance_metrics() {
    echo -e "${GREEN}Collecting performance metrics...${NC}"

    # Container stats
    echo -e "${YELLOW}Container resource usage:${NC}"
    run_cmd "docker stats --no-stream --format 'table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}\t{{.BlockIO}}'"

    # Registry statistics
    echo -e "${YELLOW}Registry statistics:${NC}"
    run_cmd "cd $HARBOR_DIR && docker-compose exec -T registry du -sh /storage" || true

    # Database connections
    echo -e "${YELLOW}Database connections:${NC}"
    run_cmd "cd $HARBOR_DIR && docker-compose exec -T postgresql psql -U postgres -c 'SELECT count(*) FROM pg_stat_activity;'" || true
}

# Update check
update_check() {
    echo -e "${GREEN}Checking for Harbor updates...${NC}"

    CURRENT_VERSION=$(run_cmd "cd $HARBOR_DIR && grep '^version:' common/config/registry/config.yml | awk '{print \$2}'") || echo "unknown"
    echo -e "Current version: ${GREEN}$CURRENT_VERSION${NC}"

    echo -e "${YELLOW}Check for updates at: https://github.com/goharbor/harbor/releases${NC}"
}

# Generate report
generate_report() {
    echo -e "${GREEN}Generating maintenance report...${NC}"

    REPORT_FILE="/tmp/harbor-maintenance-report-$(date +%Y%m%d).txt"

    cat > $REPORT_FILE << EOF
Harbor Maintenance Report
========================
Date: $(date)
Server: CT$CTID (192.168.1.182)

HEALTH STATUS
-------------
$(run_cmd "curl -k -s $HARBOR_URL/api/v2.0/health" || echo "API not responding")

DISK USAGE
----------
$(run_cmd "df -h $DATA_DIR")

MEMORY USAGE
-----------
$(run_cmd "free -h")

DOCKER CONTAINERS
-----------------
$(run_cmd "cd $HARBOR_DIR && docker-compose ps")

DATABASE SIZE
-------------
$(run_cmd "cd $HARBOR_DIR && docker-compose exec -T postgresql psql -U postgres -c \"SELECT pg_size_pretty(pg_database_size('registry'));\"" || echo "Unable to get DB size")

RESOURCE USAGE
--------------
$(run_cmd "docker stats --no-stream --format 'table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}'")

RECOMMENDATIONS
---------------
- Run garbage collection weekly
- Monitor disk usage
- Keep Harbor updated
- Regular backups are essential
- Review vulnerability scan results

EOF

    echo -e "${GREEN}Report generated: $REPORT_FILE${NC}"
    run_cmd "cat $REPORT_FILE"
}

# Display usage
usage() {
    echo -e "${YELLOW}Usage:${NC}"
    echo -e "  $0 health         - Health check"
    echo -e "  $0 logs           - Log rotation"
    echo -e "  $0 database       - Database maintenance"
    echo -e "  $0 cleanup        - Docker cleanup"
    echo -e "  $0 security       - Security scan"
    echo -e "  $0 metrics        - Performance metrics"
    echo -e "  $0 update-check   - Check for updates"
    echo -e "  $0 report         - Generate report"
    echo -e "  $0 all            - Run all maintenance tasks"
    echo -e "  $0 full           - Run all tasks including deep cleaning"
    exit 1
}

# Main script logic
case "${1:-}" in
    health)
        health_check
        ;;
    logs)
        log_rotation
        ;;
    database)
        database_maintenance "$2"
        ;;
    cleanup)
        docker_cleanup "$2"
        ;;
    security)
        security_scan
        ;;
    metrics)
        performance_metrics
        ;;
    update-check)
        update_check
        ;;
    report)
        generate_report
        ;;
    all)
        health_check
        log_rotation
        database_maintenance
        docker_cleanup
        performance_metrics
        generate_report
        ;;
    full)
        health_check
        log_rotation
        database_maintenance --full
        docker_cleanup --full
        security_scan
        performance_metrics
        update_check
        generate_report
        ;;
    *)
        usage
        ;;
esac

echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}Maintenance tasks completed!${NC}"
echo -e "${BLUE}========================================${NC}"
