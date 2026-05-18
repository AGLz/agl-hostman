#!/bin/bash
###############################################################################
# CT183 Health Check Script
# Host: CT183 (192.168.0.183)
# Purpose: Check health status of Supabase and Archon services
#
# Usage: sudo ./ct183-health.sh [--detailed]
###############################################################################

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
DETAILED=false

# Functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

log_error() {
    echo -e "${RED}[✗]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

check_container_health() {
    local container_name=$1
    local health_status=$(docker inspect --format='{{.State.Health.Status}}' "$container_name" 2>/dev/null || echo "unknown")

    case $health_status in
        "healthy")
            log_success "$container_name is healthy"
            return 0
            ;;
        "unhealthy")
            log_error "$container_name is unhealthy"
            return 1
            ;;
        "starting")
            log_warning "$container_name is starting"
            return 2
            ;;
        *)
            log_warning "$container_name: no health check ($health_status)"
            return 3
            ;;
    esac
}

check_supabase() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📦 SUPABASE HEALTH CHECK"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    local containers=(
        "supabase-db"
        "supabase-auth"
        "supabase-rest"
        "supabase-kong"
        "supabase-storage"
        "supabase-realtime"
        "supabase-studio"
        "supabase-meta"
    )

    local healthy=0
    local total=0

    for container in "${containers[@]}"; do
        if docker ps --filter "name=$container" --format "{{.Names}}" | grep -q .; then
            total=$((total + 1))
            if check_container_health "$container"; then
                healthy=$((healthy + 1))
            fi
        else
            log_warning "$container is not running"
        fi
    done

    echo ""
    log_info "Supabase Health: $healthy/$total containers healthy"

    if [[ $healthy -eq $total ]]; then
        log_success "Supabase is fully operational"
        return 0
    elif [[ $healthy -gt 0 ]]; then
        log_warning "Supabase is partially operational"
        return 1
    else
        log_error "Supabase is not operational"
        return 2
    fi
}

check_archon() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🤖 ARCHON HEALTH CHECK"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    local containers=(
        "archon-server"
        "archon-mcp"
        "archon-ui"
    )

    local healthy=0
    local total=0

    for container in "${containers[@]}"; do
        if docker ps --filter "name=$container" --format "{{.Names}}" | grep -q .; then
            total=$((total + 1))
            if check_container_health "$container"; then
                healthy=$((healthy + 1))
            fi
        else
            log_warning "$container is not running"
        fi
    done

    echo ""
    log_info "Archon Health: $healthy/$total containers healthy"

    if [[ $healthy -eq $total ]]; then
        log_success "Archon is fully operational"
        return 0
    elif [[ $healthy -gt 0 ]]; then
        log_warning "Archon is partially operational"
        return 1
    else
        log_error "Archon is not operational"
        return 2
    fi
}

check_connectivity() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🔗 CONNECTIVITY CHECK"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    # Check if Archon can reach Supabase
    if docker ps --filter "name=archon-server" --format "{{.Names}}" | grep -q .; then
        log_info "Testing Archon → Supabase connectivity..."

        if docker exec archon-server curl -s -f http://host.docker.internal:8000/rest/v1/ > /dev/null 2>&1; then
            log_success "Archon can reach Supabase API Gateway"
        else
            log_error "Archon cannot reach Supabase API Gateway"
        fi

        if docker exec archon-server curl -s -f http://host.docker.internal:8000/rest/v1/archon_settings > /dev/null 2>&1; then
            log_success "Archon can query Supabase database (archon_settings table)"
        else
            log_error "Archon cannot query Supabase database"
        fi
    else
        log_warning "Archon server is not running - skipping connectivity check"
    fi
}

show_detailed_status() {
    if [[ "$DETAILED" == "true" ]]; then
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "📊 DETAILED CONTAINER STATUS"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""

        echo "Supabase Containers:"
        docker ps --filter "name=supabase" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
        echo ""

        echo "Archon Containers:"
        docker ps --filter "name=archon" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
        echo ""

        echo "Recent Logs (Archon MCP):"
        docker logs --tail 20 archon-mcp 2>&1 | grep -E "✓|✅|Error|Failed" || true
        echo ""

        echo "Recent Logs (Archon Server):"
        docker logs --tail 20 archon-server 2>&1 | grep -E "✓|✅|Error|Failed" || true
        echo ""
    fi
}

show_service_endpoints() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🌐 SERVICE ENDPOINTS"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    echo "Supabase:"
    echo "  - API Gateway:     http://192.168.0.183:8000"
    echo "  - PostgREST:       http://192.168.0.183:3000"
    echo "  - PostgreSQL:      postgres://postgres:[password]@192.168.0.183:5432/postgres"
    echo ""

    echo "Archon:"
    echo "  - Web UI:          http://192.168.0.183:3737"
    echo "  - MCP Server:      http://192.168.0.183:8051/mcp"
    echo "  - API Backend:     http://192.168.0.183:8181"
    echo ""
}

show_summary() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📋 HEALTH CHECK SUMMARY"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    local supabase_running=$(docker ps --filter "name=supabase" --format "{{.Names}}" | wc -l)
    local archon_running=$(docker ps --filter "name=archon" --format "{{.Names}}" | wc -l)

    echo "Supabase: $supabase_running containers running"
    echo "Archon:   $archon_running containers running"
    echo ""

    if [[ $supabase_running -ge 8 ]] && [[ $archon_running -ge 2 ]]; then
        log_success "All services are operational"
        return 0
    else
        log_error "Some services are not running properly"
        return 1
    fi
}

# Main execution
main() {
    echo ""
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║  CT183 Health Check                                        ║"
    echo "║  Host: 192.168.0.183                                       ║"
    echo "╚════════════════════════════════════════════════════════════╝"

    # Parse arguments
    if [[ "$1" == "--detailed" ]]; then
        DETAILED=true
    fi

    # Run health checks
    check_supabase
    local supabase_status=$?

    check_archon
    local archon_status=$?

    check_connectivity

    show_detailed_status
    show_service_endpoints
    show_summary

    # Exit with appropriate code
    if [[ $supabase_status -eq 0 ]] && [[ $archon_status -eq 0 ]]; then
        exit 0
    else
        exit 1
    fi
}

main "$@"
