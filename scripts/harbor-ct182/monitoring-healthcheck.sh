#!/bin/bash
#
# Harbor CT182 Monitoring and Health Check Script
# Comprehensive health monitoring and alerting
#
# Author: Hive Mind Coder Agent
# Session: swarm-1761131660305-65la2tiid
# Date: 2025-10-22
# Version: 1.0.0
#

set -euo pipefail

# Configuration
CT_ID="${CT_ID:-182}"
HARBOR_URL="${HARBOR_URL:-https://localhost}"
ALERT_EMAIL="${ALERT_EMAIL:-admin@example.com}"
ALERT_THRESHOLD_CPU=80
ALERT_THRESHOLD_MEM=85
ALERT_THRESHOLD_DISK=85
PROMETHEUS_PORT=9090

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Health Check Results
HEALTH_STATUS="HEALTHY"
HEALTH_ISSUES=()

info() { echo -e "${BLUE}[INFO]${NC} $*"; }
success() { echo -e "${GREEN}[✓]${NC} $*"; }
warn() { echo -e "${YELLOW}[!]${NC} $*"; HEALTH_STATUS="WARNING"; HEALTH_ISSUES+=("$*"); }
error() { echo -e "${RED}[✗]${NC} $*"; HEALTH_STATUS="CRITICAL"; HEALTH_ISSUES+=("$*"); }

# Check Harbor Container Health
check_container_health() {
    echo -e "\n${BLUE}═══ Checking Harbor Container Status ═══${NC}\n"

    local containers=(
        "harbor-core"
        "harbor-portal"
        "harbor-db"
        "harbor-redis"
        "harbor-jobservice"
        "registry"
        "nginx"
        "harbor-trivy"
    )

    for container in "${containers[@]}"; do
        if docker ps --filter "name=$container" --filter "status=running" | grep -q "$container"; then
            success "$container is running"
        else
            error "$container is NOT running or exited"
        fi
    done
}

# Check System Resources
check_system_resources() {
    echo -e "\n${BLUE}═══ Checking System Resources ═══${NC}\n"

    # CPU Usage
    local cpu_usage=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1}')
    cpu_usage=${cpu_usage%.*}

    if [[ $cpu_usage -lt $ALERT_THRESHOLD_CPU ]]; then
        success "CPU usage: ${cpu_usage}% (OK)"
    else
        warn "CPU usage: ${cpu_usage}% (HIGH - threshold: ${ALERT_THRESHOLD_CPU}%)"
    fi

    # Memory Usage
    local mem_usage=$(free | grep Mem | awk '{print int($3/$2 * 100)}')

    if [[ $mem_usage -lt $ALERT_THRESHOLD_MEM ]]; then
        success "Memory usage: ${mem_usage}% (OK)"
    else
        warn "Memory usage: ${mem_usage}% (HIGH - threshold: ${ALERT_THRESHOLD_MEM}%)"
    fi

    # Disk Usage
    local disk_usage=$(df -h / | tail -1 | awk '{print $5}' | sed 's/%//')

    if [[ $disk_usage -lt $ALERT_THRESHOLD_DISK ]]; then
        success "Disk usage: ${disk_usage}% (OK)"
    else
        warn "Disk usage: ${disk_usage}% (HIGH - threshold: ${ALERT_THRESHOLD_DISK}%)"
    fi
}

# Check Harbor API Health
check_harbor_api() {
    echo -e "\n${BLUE}═══ Checking Harbor API Health ═══${NC}\n"

    # Check API endpoint
    if curl -k -s -o /dev/null -w "%{http_code}" "${HARBOR_URL}/api/v2.0/health" | grep -q "200"; then
        success "Harbor API is responding (HTTP 200)"
    else
        error "Harbor API is NOT responding correctly"
    fi

    # Check web portal
    if curl -k -s "${HARBOR_URL}" | grep -q "Harbor"; then
        success "Harbor web portal is accessible"
    else
        error "Harbor web portal is NOT accessible"
    fi
}

# Check Database Connectivity
check_database() {
    echo -e "\n${BLUE}═══ Checking Database Connectivity ═══${NC}\n"

    if docker exec harbor-db pg_isready -U postgres &>/dev/null; then
        success "PostgreSQL database is ready"

        # Check connection count
        local conn_count=$(docker exec harbor-db psql -U postgres -t -c "SELECT count(*) FROM pg_stat_activity;" | xargs)
        info "Active database connections: $conn_count"

        # Check database size
        local db_size=$(docker exec harbor-db psql -U postgres -t -c "SELECT pg_size_pretty(pg_database_size('registry'));" | xargs)
        info "Registry database size: $db_size"
    else
        error "PostgreSQL database is NOT ready"
    fi
}

# Check Redis Cache
check_redis() {
    echo -e "\n${BLUE}═══ Checking Redis Cache ═══${NC}\n"

    if docker exec harbor-redis redis-cli ping | grep -q "PONG"; then
        success "Redis cache is responding"

        # Get Redis info
        local mem_used=$(docker exec harbor-redis redis-cli INFO memory | grep "used_memory_human" | cut -d: -f2 | tr -d '\r')
        info "Redis memory usage: $mem_used"
    else
        error "Redis cache is NOT responding"
    fi
}

# Check Storage
check_storage() {
    echo -e "\n${BLUE}═══ Checking Storage Health ═══${NC}\n"

    local data_volume="/data/registry"

    # Check if mounted
    if mountpoint -q "$data_volume" 2>/dev/null || [[ -d "$data_volume" ]]; then
        success "Data volume is accessible: $data_volume"

        # Check storage usage
        local storage_size=$(du -sh "$data_volume" 2>/dev/null | cut -f1)
        info "Registry storage usage: $storage_size"

        # Count images
        local image_count=$(find "$data_volume/registry/docker/registry/v2/repositories" -type d -name "_manifests" 2>/dev/null | wc -l)
        info "Total images stored: $image_count"
    else
        error "Data volume is NOT accessible: $data_volume"
    fi
}

# Check Network Connectivity
check_network() {
    echo -e "\n${BLUE}═══ Checking Network Connectivity ═══${NC}\n"

    # Check internet connectivity
    if ping -c 1 -W 2 8.8.8.8 &>/dev/null; then
        success "Internet connectivity: OK"
    else
        warn "Internet connectivity: FAILED (may affect Trivy updates)"
    fi

    # Check DNS resolution
    if nslookup google.com &>/dev/null; then
        success "DNS resolution: OK"
    else
        warn "DNS resolution: FAILED"
    fi

    # Check listening ports
    local ports=(80 443)
    for port in "${ports[@]}"; do
        if netstat -tuln | grep -q ":${port} "; then
            success "Port $port is listening"
        else
            error "Port $port is NOT listening"
        fi
    done
}

# Check Trivy Scanner
check_trivy() {
    echo -e "\n${BLUE}═══ Checking Trivy Vulnerability Scanner ═══${NC}\n"

    if docker ps --filter "name=harbor-trivy" --filter "status=running" | grep -q "harbor-trivy"; then
        success "Trivy scanner is running"

        # Check database version
        local trivy_version=$(docker exec harbor-trivy /home/scanner/bin/trivy --version 2>/dev/null | head -1 || echo "Unknown")
        info "Trivy version: $trivy_version"
    else
        error "Trivy scanner is NOT running"
    fi
}

# Check Backup Status
check_backup_status() {
    echo -e "\n${BLUE}═══ Checking Backup Status ═══${NC}\n"

    local backup_dir="/data/registry/backups"

    if [[ -d "$backup_dir" ]]; then
        # Find most recent backup
        local latest_backup=$(ls -t "$backup_dir"/harbor-backup-*.tar.gz 2>/dev/null | head -1)

        if [[ -n "$latest_backup" ]]; then
            local backup_age=$(($(date +%s) - $(stat -c %Y "$latest_backup")))
            local backup_age_days=$((backup_age / 86400))

            if [[ $backup_age_days -lt 2 ]]; then
                success "Latest backup: $(basename "$latest_backup") (${backup_age_days} days old)"
            else
                warn "Latest backup is ${backup_age_days} days old - backups may not be running"
            fi
        else
            warn "No backups found in $backup_dir"
        fi
    else
        warn "Backup directory does not exist: $backup_dir"
    fi
}

# Check Certificate Expiration
check_certificate_expiration() {
    echo -e "\n${BLUE}═══ Checking SSL Certificate Expiration ═══${NC}\n"

    local cert_file="/data/registry/secrets/cert/server.crt"

    if [[ -f "$cert_file" ]]; then
        local expiry_date=$(openssl x509 -enddate -noout -in "$cert_file" | cut -d= -f2)
        local expiry_epoch=$(date -d "$expiry_date" +%s)
        local current_epoch=$(date +%s)
        local days_until_expiry=$(( (expiry_epoch - current_epoch) / 86400 ))

        if [[ $days_until_expiry -gt 30 ]]; then
            success "SSL certificate expires in $days_until_expiry days"
        elif [[ $days_until_expiry -gt 0 ]]; then
            warn "SSL certificate expires in $days_until_expiry days - renewal needed"
        else
            error "SSL certificate has EXPIRED"
        fi
    else
        warn "SSL certificate file not found: $cert_file"
    fi
}

# Check Docker Daemon
check_docker_daemon() {
    echo -e "\n${BLUE}═══ Checking Docker Daemon ═══${NC}\n"

    if systemctl is-active --quiet docker; then
        success "Docker daemon is active"

        # Check Docker disk usage
        local docker_disk=$(docker system df --format "{{.Size}}" | head -1)
        info "Docker storage usage: $docker_disk"
    else
        error "Docker daemon is NOT active"
    fi
}

# Generate Prometheus Metrics
generate_prometheus_metrics() {
    echo -e "\n${BLUE}═══ Generating Prometheus Metrics ═══${NC}\n"

    local metrics_file="/var/lib/harbor/prometheus/harbor_metrics.prom"
    mkdir -p "$(dirname "$metrics_file")"

    cat > "$metrics_file" << EOF
# HELP harbor_health_status Harbor overall health status (1=healthy, 0=unhealthy)
# TYPE harbor_health_status gauge
harbor_health_status{instance="ct182"} $(if [[ "$HEALTH_STATUS" == "HEALTHY" ]]; then echo 1; else echo 0; fi)

# HELP harbor_containers_running Number of running Harbor containers
# TYPE harbor_containers_running gauge
harbor_containers_running{instance="ct182"} $(docker ps --filter "name=harbor" | grep -c harbor)

# HELP harbor_cpu_usage_percent CPU usage percentage
# TYPE harbor_cpu_usage_percent gauge
harbor_cpu_usage_percent{instance="ct182"} $(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1}')

# HELP harbor_memory_usage_percent Memory usage percentage
# TYPE harbor_memory_usage_percent gauge
harbor_memory_usage_percent{instance="ct182"} $(free | grep Mem | awk '{print int($3/$2 * 100)}')

# HELP harbor_disk_usage_percent Disk usage percentage
# TYPE harbor_disk_usage_percent gauge
harbor_disk_usage_percent{instance="ct182"} $(df -h / | tail -1 | awk '{print $5}' | sed 's/%//')
EOF

    success "Prometheus metrics generated: $metrics_file"
}

# Generate Health Report
generate_health_report() {
    local report_file="/var/log/harbor/health-report-$(date +%Y%m%d-%H%M%S).txt"

    {
        echo "═══════════════════════════════════════════════════════════"
        echo "Harbor CT182 Health Check Report"
        echo "═══════════════════════════════════════════════════════════"
        echo "Timestamp: $(date)"
        echo "Overall Status: $HEALTH_STATUS"
        echo ""

        if [[ ${#HEALTH_ISSUES[@]} -gt 0 ]]; then
            echo "Issues Detected:"
            for issue in "${HEALTH_ISSUES[@]}"; do
                echo "  - $issue"
            done
            echo ""
        fi

        echo "System Information:"
        echo "  Uptime: $(uptime -p)"
        echo "  Load Average: $(uptime | awk -F'load average:' '{print $2}')"
        echo ""

        echo "Container Status:"
        docker ps --filter "name=harbor" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
        echo ""

        echo "Resource Usage:"
        echo "  CPU: $(top -bn1 | grep "Cpu(s)")"
        echo "  Memory: $(free -h | grep Mem)"
        echo "  Disk: $(df -h / | tail -1)"
        echo ""

    } > "$report_file"

    info "Health report saved: $report_file"
}

# Send Alert
send_alert() {
    if [[ "$HEALTH_STATUS" != "HEALTHY" ]]; then
        warn "Health check detected issues - status: $HEALTH_STATUS"

        # Email alert (requires mailx or sendmail configured)
        if command -v mail &>/dev/null; then
            {
                echo "Harbor CT182 Health Alert"
                echo ""
                echo "Status: $HEALTH_STATUS"
                echo "Issues:"
                for issue in "${HEALTH_ISSUES[@]}"; do
                    echo "  - $issue"
                done
            } | mail -s "Harbor CT182 Health Alert - $HEALTH_STATUS" "$ALERT_EMAIL" || true
        fi
    fi
}

# Main Health Check
main() {
    echo -e "\n${BLUE}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║     Harbor CT182 Health Check - $(date +%Y-%m-%d\ %H:%M:%S)    ║${NC}"
    echo -e "${BLUE}╚═══════════════════════════════════════════════════════════╝${NC}\n"

    check_docker_daemon
    check_container_health
    check_system_resources
    check_harbor_api
    check_database
    check_redis
    check_storage
    check_network
    check_trivy
    check_backup_status
    check_certificate_expiration
    generate_prometheus_metrics
    generate_health_report
    send_alert

    echo -e "\n${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}Overall Health Status: ${HEALTH_STATUS}${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}\n"

    if [[ "$HEALTH_STATUS" == "HEALTHY" ]]; then
        success "All health checks passed"
        exit 0
    elif [[ "$HEALTH_STATUS" == "WARNING" ]]; then
        warn "Health checks completed with warnings"
        exit 1
    else
        error "Health checks failed - critical issues detected"
        exit 2
    fi
}

# Run health check
main "$@"
