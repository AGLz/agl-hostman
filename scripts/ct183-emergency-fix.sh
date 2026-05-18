#!/bin/bash
###############################################################################
# CT183 Emergency Fix - All-in-One Script
# Purpose: Fix Archon and Supabase containers on CT183
# Usage: Execute this script directly on CT183 (via Proxmox console or SSH)
#
# This script is SELF-CONTAINED and doesn't require any external files
###############################################################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

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

# Header
echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║  CT183 Emergency Fix - Archon + Supabase                   ║"
echo "║  Self-Contained Recovery Script                            ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

log_info "Starting recovery process..."
echo ""

# Step 1: Check Docker
log_info "Step 1: Checking Docker installation..."
if ! command -v docker &> /dev/null; then
    log_error "Docker is not installed!"
    exit 1
fi

if ! docker info &> /dev/null; then
    log_error "Docker daemon is not running!"
    log_info "Starting Docker..."
    systemctl start docker || service docker start
    sleep 3
fi

log_success "Docker is ready"
echo ""

# Step 2: Check directories
log_info "Step 2: Checking required directories..."

SUPABASE_DIR="/root/supabase-self-hosted/supabase/docker"
ARCHON_DIR="/root/Archon"

if [[ ! -d "$SUPABASE_DIR" ]]; then
    log_error "Supabase directory not found: $SUPABASE_DIR"
    log_info "Searching for Supabase installation..."
    SUPABASE_DIR=$(find /root -name "docker-compose.yml" -path "*/supabase/*" 2>/dev/null | head -1 | xargs dirname)

    if [[ -z "$SUPABASE_DIR" ]]; then
        log_error "Cannot find Supabase installation!"
        exit 1
    fi

    log_warning "Found Supabase at: $SUPABASE_DIR"
fi

if [[ ! -d "$ARCHON_DIR" ]]; then
    log_error "Archon directory not found: $ARCHON_DIR"
    log_info "Searching for Archon installation..."
    ARCHON_DIR=$(find /root -name "docker-compose.yml" -path "*/Archon/*" 2>/dev/null | head -1 | xargs dirname)

    if [[ -z "$ARCHON_DIR" ]]; then
        log_error "Cannot find Archon installation!"
        exit 1
    fi

    log_warning "Found Archon at: $ARCHON_DIR"
fi

log_success "All directories found"
echo ""

# Step 3: Stop all containers
log_info "Step 3: Stopping existing containers..."

cd "$ARCHON_DIR"
if [[ -f "docker-compose.yml" ]]; then
    log_info "Stopping Archon..."
    docker compose down 2>/dev/null || docker-compose down 2>/dev/null || true
fi

cd "$SUPABASE_DIR"
if [[ -f "docker-compose.yml" ]]; then
    log_info "Stopping Supabase..."
    docker compose down 2>/dev/null || docker-compose down 2>/dev/null || true
fi

log_success "All containers stopped"
echo ""

# Step 4: Start Supabase
log_info "Step 4: Starting Supabase containers..."

cd "$SUPABASE_DIR"

log_info "Starting Supabase (this may take 2-3 minutes)..."
docker compose up -d 2>/dev/null || docker-compose up -d

log_info "Waiting for Supabase to be healthy..."
sleep 10

# Wait for critical containers
for i in {1..24}; do
    healthy=$(docker ps --filter "name=supabase" --filter "health=healthy" --format "{{.Names}}" | wc -l)

    if [[ $healthy -ge 8 ]]; then
        log_success "Supabase is healthy ($healthy containers)"
        break
    fi

    if [[ $i -eq 24 ]]; then
        log_warning "Supabase startup timeout, but continuing..."
        break
    fi

    echo -ne "\r  Waiting... ($healthy/8 healthy, ${i}s) "
    sleep 5
done

echo ""
log_success "Supabase started"
docker ps --filter "name=supabase" --format "table {{.Names}}\t{{.Status}}" | head -10
echo ""

# Step 5: Start Archon
log_info "Step 5: Starting Archon containers..."

cd "$ARCHON_DIR"

log_info "Starting Archon..."
docker compose up -d 2>/dev/null || docker-compose up -d

log_info "Waiting for Archon to be healthy..."
sleep 10

# Wait for Archon containers
for i in {1..12}; do
    healthy=$(docker ps --filter "name=archon" --filter "health=healthy" --format "{{.Names}}" | wc -l)

    if [[ $healthy -ge 2 ]]; then
        log_success "Archon is healthy ($healthy containers)"
        break
    fi

    if [[ $i -eq 12 ]]; then
        log_warning "Archon startup timeout, but continuing..."
        break
    fi

    echo -ne "\r  Waiting... ($healthy/2 healthy, ${i}s) "
    sleep 5
done

echo ""
log_success "Archon started"
docker ps --filter "name=archon" --format "table {{.Names}}\t{{.Status}}"
echo ""

# Step 6: Verification
log_info "Step 6: Verifying services..."

# Check ports
declare -A ports=(
    ["3737"]="Archon Web UI"
    ["8051"]="Archon MCP Server"
    ["8181"]="Archon API Backend"
    ["8000"]="Supabase API Gateway"
    ["5432"]="Supabase PostgreSQL"
)

echo ""
log_info "Checking service ports..."
all_ok=true

for port in "${!ports[@]}"; do
    service="${ports[$port]}"

    if timeout 2 bash -c "echo >/dev/tcp/127.0.0.1/$port" 2>/dev/null; then
        log_success "$service (port $port) - OK"
    else
        log_error "$service (port $port) - FAILED"
        all_ok=false
    fi
done

echo ""

# Step 7: Show status
log_info "Step 7: Final status..."
echo ""

echo "Supabase Containers:"
docker ps --filter "name=supabase" --format "table {{.Names}}\t{{.Status}}" | head -10
echo ""

echo "Archon Containers:"
docker ps --filter "name=archon" --format "table {{.Names}}\t{{.Status}}"
echo ""

# Step 8: Show endpoints
log_info "Service Endpoints:"
echo ""
echo "Supabase:"
echo "  - API Gateway:  http://192.168.0.183:8000"
echo "  - PostgreSQL:   postgres://postgres:***@192.168.0.183:5432/postgres"
echo ""
echo "Archon:"
echo "  - Web UI:       http://192.168.0.183:3737"
echo "  - MCP Server:   http://192.168.0.183:8051/mcp"
echo "  - API Backend:  http://192.168.0.183:8181"
echo ""

# Final message
if [[ "$all_ok" == "true" ]]; then
    log_success "✓ ALL SERVICES RESTORED SUCCESSFULLY!"
    echo ""
    log_info "You can now access:"
    echo "  - Archon Web UI:  http://192.168.0.183:3737"
    echo "  - Archon MCP:     http://192.168.0.183:8051/mcp"
    echo ""
    exit 0
else
    log_warning "Some services may not be fully operational"
    echo ""
    log_info "Check logs with:"
    echo "  docker logs archon-server --tail 50"
    echo "  docker logs supabase-kong --tail 50"
    echo ""
    exit 1
fi
