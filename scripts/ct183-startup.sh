#!/bin/bash
###############################################################################
# CT183 Startup Script - Supabase + Archon
# Host: CT183 (192.168.0.183)
# Purpose: Start containers in correct order with health checks
#
# CRITICAL: Supabase MUST start BEFORE Archon
# Archon depends on Supabase PostgreSQL + PostgREST API
#
# Usage: sudo ./ct183-startup.sh [--force-restart]
###############################################################################

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SUPABASE_DIR="/root/supabase-self-hosted/supabase/docker"
ARCHON_DIR="/root/Archon"
SUPABASE_STARTUP_TIMEOUT=120  # seconds
ARCHON_STARTUP_TIMEOUT=60     # seconds
HEALTH_CHECK_INTERVAL=5        # seconds

# Functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_docker() {
    log_info "Checking Docker installation..."
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed"
        exit 1
    fi

    if ! docker info &> /dev/null; then
        log_error "Docker daemon is not running"
        exit 1
    fi

    log_success "Docker is ready"
}

check_directories() {
    log_info "Checking required directories..."

    if [[ ! -d "$SUPABASE_DIR" ]]; then
        log_error "Supabase directory not found: $SUPABASE_DIR"
        exit 1
    fi

    if [[ ! -d "$ARCHON_DIR" ]]; then
        log_error "Archon directory not found: $ARCHON_DIR"
        exit 1
    fi

    if [[ ! -f "$SUPABASE_DIR/docker-compose.yml" ]]; then
        log_error "Supabase docker-compose.yml not found"
        exit 1
    fi

    if [[ ! -f "$ARCHON_DIR/docker-compose.yml" ]]; then
        log_error "Archon docker-compose.yml not found"
        exit 1
    fi

    log_success "All required directories and files found"
}

wait_for_supabase() {
    log_info "Waiting for Supabase to be healthy..."

    local elapsed=0
    while [[ $elapsed -lt $SUPABASE_STARTUP_TIMEOUT ]]; do
        # Check if critical containers are healthy
        local healthy_containers=$(docker ps --filter "name=supabase" --filter "health=healthy" --format "{{.Names}}" | wc -l)

        if [[ $healthy_containers -ge 8 ]]; then
            log_success "Supabase is healthy ($healthy_containers containers running)"
            return 0
        fi

        log_info "Supabase is starting... ($healthy_containers/8 healthy, ${elapsed}s elapsed)"
        sleep $HEALTH_CHECK_INTERVAL
        elapsed=$((elapsed + HEALTH_CHECK_INTERVAL))
    done

    log_warning "Supabase startup timeout, but continuing..."
    return 0
}

wait_for_archon() {
    log_info "Waiting for Archon to be healthy..."

    local elapsed=0
    while [[ $elapsed -lt $ARCHON_STARTUP_TIMEOUT ]]; do
        # Check if Archon containers are healthy
        local healthy_containers=$(docker ps --filter "name=archon" --filter "health=healthy" --format "{{.Names}}" | wc -l)

        if [[ $healthy_containers -ge 2 ]]; then
            log_success "Archon is healthy ($healthy_containers containers running)"
            return 0
        fi

        log_info "Archon is starting... ($healthy_containers/2 healthy, ${elapsed}s elapsed)"
        sleep $HEALTH_CHECK_INTERVAL
        elapsed=$((elapsed + HEALTH_CHECK_INTERVAL))
    done

    log_warning "Archon startup timeout"
    return 0
}

start_supabase() {
    log_info "Starting Supabase containers..."

    cd "$SUPABASE_DIR"

    if [[ "$FORCE_RESTART" == "true" ]]; then
        log_warning "Force restart enabled - stopping existing containers..."
        docker compose down
    fi

    # Start Supabase
    docker compose up -d

    log_success "Supabase containers started"
    docker ps --filter "name=supabase" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

    # Wait for health
    wait_for_supabase
}

start_archon() {
    log_info "Starting Archon containers..."

    cd "$ARCHON_DIR"

    if [[ "$FORCE_RESTART" == "true" ]]; then
        log_warning "Force restart enabled - stopping existing containers..."
        docker compose down
    fi

    # Start Archon
    docker compose up -d

    log_success "Archon containers started"
    docker ps --filter "name=archon" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

    # Wait for health
    wait_for_archon
}

verify_connectivity() {
    log_info "Verifying connectivity between services..."

    # Test Archon -> Supabase connectivity
    local archon_ip=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' archon-server 2>/dev/null || echo "")

    if [[ -n "$archon_ip" ]]; then
        log_info "Testing connectivity from Archon to Supabase..."

        # Test PostgREST API
        if docker exec archon-server curl -s -f http://host.docker.internal:8000/rest/v1/ > /dev/null 2>&1; then
            log_success "Archon can reach Supabase API"
        else
            log_warning "Archon cannot reach Supabase API (this may be okay during startup)"
        fi
    fi
}

show_status() {
    echo ""
    log_info "=== FINAL CONTAINER STATUS ==="
    echo ""
    echo "Supabase Containers:"
    docker ps --filter "name=supabase" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
    echo ""
    echo "Archon Containers:"
    docker ps --filter "name=archon" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
    echo ""

    # Show service endpoints
    log_info "=== SERVICE ENDPOINTS ==="
    echo ""
    echo "Supabase:"
    echo "  - API Gateway:  http://192.168.0.183:8000"
    echo "  - PostgreSQL:   postgres://postgres:[password]@192.168.0.183:5432/postgres"
    echo ""
    echo "Archon:"
    echo "  - Web UI:       http://192.168.0.183:3737"
    echo "  - MCP Server:   http://192.168.0.183:8051/mcp"
    echo "  - API Backend:  http://192.168.0.183:8181"
    echo ""
}

# Main execution
main() {
    echo ""
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║  CT183 Startup Script - Supabase + Archon                  ║"
    echo "║  Host: 192.168.0.183                                       ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo ""

    # Parse arguments
    FORCE_RESTART=false
    if [[ "$1" == "--force-restart" ]]; then
        FORCE_RESTART=true
        log_warning "Force restart mode enabled"
    fi

    # Execute startup sequence
    check_docker
    check_directories

    log_info "Starting services in dependency order..."
    echo ""

    # Step 1: Start Supabase (MUST BE FIRST)
    start_supabase
    echo ""

    # Step 2: Start Archon (depends on Supabase)
    start_archon
    echo ""

    # Step 3: Verify connectivity
    verify_connectivity
    echo ""

    # Step 4: Show final status
    show_status

    log_success "Startup sequence completed!"
}

# Run main function
main "$@"
