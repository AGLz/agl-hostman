#!/bin/bash
###############################################################################
# CT183 Stop Script - Supabase + Archon
# Host: CT183 (192.168.0.183)
# Purpose: Stop containers in correct order
#
# Order: Archon FIRST, then Supabase (reverse of startup)
#
# Usage: sudo ./ct183-stop.sh [--verbose]
###############################################################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
SUPABASE_DIR="/root/supabase-self-hosted/supabase/docker"
ARCHON_DIR="/root/Archon"
VERBOSE=false

# Functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_verbose() {
    if [[ "$VERBOSE" == "true" ]]; then
        echo -e "${YELLOW}[VERBOSE]${NC} $1"
    fi
}

stop_archon() {
    log_info "Stopping Archon containers..."

    if [[ ! -d "$ARCHON_DIR" ]]; then
        log_info "Archon directory not found, skipping..."
        return 0
    fi

    cd "$ARCHON_DIR"

    if [[ "$VERBOSE" == "true" ]]; then
        docker compose down --verbose
    else
        docker compose down
    fi

    log_success "Archon containers stopped"
}

stop_supabase() {
    log_info "Stopping Supabase containers..."

    if [[ ! -d "$SUPABASE_DIR" ]]; then
        log_info "Supabase directory not found, skipping..."
        return 0
    fi

    cd "$SUPABASE_DIR"

    if [[ "$VERBOSE" == "true" ]]; then
        docker compose down --verbose
    else
        docker compose down
    fi

    log_success "Supabase containers stopped"
}

show_status() {
    echo ""
    log_info "Remaining containers:"
    docker ps --filter "name=supabase" --filter "name=archon" --format "table {{.Names}}\t{{.Status}}" 2>/dev/null || true
    echo ""
}

# Main execution
main() {
    echo ""
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║  CT183 Stop Script - Supabase + Archon                     ║"
    echo "║  Host: 192.168.0.183                                       ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo ""

    # Parse arguments
    if [[ "$1" == "--verbose" ]]; then
        VERBOSE=true
    fi

    # Stop in reverse order (Archon first, then Supabase)
    stop_archon
    stop_supabase

    show_status
    log_success "All containers stopped"
}

main "$@"
