#!/bin/bash
###############################################################################
# CT183 Remote Diagnostics Script
# Purpose: Diagnose Archon and Supabase containers WITHOUT SSH access
# Usage: ./ct183-diagnose.sh [--fix]
#
# This script uses network probes to determine container status
###############################################################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
CT183_IP="192.168.0.183"
CT183_TAILSCALE_IP="100.80.30.59"

# Critical ports
ARCHON_PORTS=(
    "3737:archon-ui:Web UI"
    "8051:archon-mcp:MCP Server"
    "8181:archon-server:API Backend"
)

SUPABASE_PORTS=(
    "8000:supabase-kong:API Gateway"
    "3000:supabase-studio:Studio UI"
    "5432:supabase-db:PostgreSQL"
)

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

test_port() {
    local port=$1
    local name=$2
    local description=$3

    if timeout 2 bash -c "echo >/dev/tcp/$CT183_IP/$port" 2>/dev/null; then
        log_success "$name ($port) - $description"
        return 0
    else
        log_error "$name ($port) - $description - CONNECTION REFUSED"
        return 1
    fi
}

test_http() {
    local port=$1
    local name=$2
    local path=${3:-/}

    local response=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 2 "http://$CT183_IP:$port$path" 2>/dev/null || echo "000")

    if [[ "$response" =~ ^[23] ]]; then
        log_success "$name (port $port) - HTTP $response"
        return 0
    elif [[ "$response" == "000" ]]; then
        log_error "$name (port $port) - NO RESPONSE"
        return 1
    else
        log_warning "$name (port $port) - HTTP $response (unexpected)"
        return 2
    fi
}

check_connectivity() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🌐 NETWORK CONNECTIVITY"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    # Test basic connectivity
    log_info "Testing ICMP ping to CT183..."
    if ping -c 2 -W 2 $CT183_IP &>/dev/null; then
        local rtt=$(ping -c 1 $CT183_IP 2>/dev/null | grep "time=" | awk -F'time=' '{print $2}' | awk '{print $1}')
        log_success "CT183 is reachable (${rtt}ms latency)"
    else
        log_error "CT183 is NOT reachable"
        return 1
    fi
    echo ""

    # Test Tailscale
    log_info "Testing Tailscale connectivity..."
    if ping -c 1 -W 2 $CT183_TAILSCALE_IP &>/dev/null; then
        log_success "Tailscale IP is reachable"
    else
        log_warning "Tailscale IP is NOT reachable (non-critical)"
    fi
    echo ""
}

check_archon() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🤖 ARCHON CONTAINER STATUS"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    local archon_up=0
    local archon_down=0

    log_info "Testing Archon ports..."
    echo ""

    for port_info in "${ARCHON_PORTS[@]}"; do
        IFS=':' read -r port container description <<< "$port_info"

        if test_port "$port" "$container" "$description"; then
            archon_up=$((archon_up + 1))
        else
            archon_down=$((archon_down + 1))
        fi
    done

    echo ""
    log_info "Testing HTTP endpoints..."
    echo ""

    # Test Web UI
    if test_http "3737" "archon-ui" "/"; then
        log_info "  → Web interface is accessible"
    fi
    echo ""

    # Summary
    echo "Archon Status: $archon_up UP, $archon_down DOWN"
    echo ""

    if [[ $archon_down -gt 0 ]]; then
        log_error "Some Archon containers are NOT running!"
        echo ""
        echo "Recommended actions:"
        if [[ $archon_down -ge 2 ]]; then
            echo "  1. SSH into CT183 and run: /root/ct183-startup.sh --force-restart"
        else
            echo "  1. Check specific container logs on CT183"
            echo "  2. Restart failed container: docker restart <container-name>"
        fi
        return 1
    else
        log_success "All Archon containers are running"
        return 0
    fi
}

check_supabase() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📦 SUPABASE CONTAINER STATUS"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    local supabase_up=0
    local supabase_down=0

    log_info "Testing Supabase ports..."
    echo ""

    for port_info in "${SUPABASE_PORTS[@]}"; do
        IFS=':' read -r port container description <<< "$port_info"

        if test_port "$port" "$container" "$description"; then
            supabase_up=$((supabase_up + 1))
        else
            supabase_down=$((supabase_down + 1))
        fi
    done

    echo ""
    log_info "Testing HTTP endpoints..."
    echo ""

    # Test Kong API Gateway
    if test_http "8000" "supabase-kong" "/rest/v1/"; then
        log_info "  → API Gateway is accessible"
    fi
    echo ""

    # Summary
    echo "Supabase Status: $supabase_up UP, $supabase_down DOWN"
    echo ""

    if [[ $supabase_down -gt 0 ]]; then
        log_error "Some Supabase containers are NOT running!"
        echo ""
        echo "Recommended action:"
        echo "  1. SSH into CT183 and run: /root/ct183-startup.sh --force-restart"
        return 1
    else
        log_success "All Supabase containers are running"
        return 0
    fi
}

check_mcp() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🔌 MCP CONNECTIVITY"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    log_info "Testing MCP endpoint (port 8051)..."
    echo ""

    local response=$(curl -s -m 2 "http://$CT183_IP:8051/mcp" 2>&1)

    if [[ "$response" =~ "jsonrpc" ]]; then
        log_success "MCP server is responding"
        echo ""
        echo "Response preview:"
        echo "  $response" | head -3
        return 0
    else
        log_error "MCP server is NOT responding properly"
        echo ""
        echo "Response:"
        echo "  $response"
        return 1
    fi
}

generate_report() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📋 DIAGNOSTIC REPORT"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    echo "Host: CT183 ($CT183_IP)"
    echo "Date: $(date '+%Y-%m-%d %H:%M:%S')"
    echo ""

    # Archon summary
    echo "Archon Containers:"
    for port_info in "${ARCHON_PORTS[@]}"; do
        IFS=':' read -r port container description <<< "$port_info"
        if timeout 1 bash -c "echo >/dev/tcp/$CT183_IP/$port" 2>/dev/null; then
            echo "  ✓ $container (port $port)"
        else
            echo "  ✗ $container (port $port) - DOWN"
        fi
    done
    echo ""

    # Supabase summary
    echo "Supabase Containers:"
    for port_info in "${SUPABASE_PORTS[@]}"; do
        IFS=':' read -r port container description <<< "$port_info"
        if timeout 1 bash -c "echo >/dev/tcp/$CT183_IP/$port" 2>/dev/null; then
            echo "  ✓ $container (port $port)"
        else
            echo "  ✗ $container (port $port) - DOWN"
        fi
    done
    echo ""

    echo "Service URLs:"
    echo "  - Archon Web UI:   http://$CT183_IP:3737"
    echo "  - Archon MCP:      http://$CT183_IP:8051/mcp"
    echo "  - Supabase API:    http://$CT183_IP:8000"
    echo ""
}

suggest_fixes() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🔧 RECOMMENDED ACTIONS"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    # Count issues
    local issues=0

    # Check archon-server specifically
    if ! timeout 1 bash -c "echo >/dev/tcp/$CT183_IP/8181" 2>/dev/null; then
        log_error "archon-server (port 8181) is DOWN"
        echo "  → This is critical: API backend is not accessible"
        echo "  → Fix: SSH into CT183 and restart Archon"
        issues=$((issues + 1))
    fi

    # Check Supabase
    if ! timeout 1 bash -c "echo >/dev/tcp/$CT183_IP/8000" 2>/dev/null; then
        log_error "Supabase API Gateway (port 8000) is DOWN"
        echo "  → This is critical: Archon cannot work without Supabase"
        echo "  → Fix: Start Supabase first, then Archon"
        issues=$((issues + 1))
    fi

    if [[ $issues -eq 0 ]]; then
        log_success "No critical issues detected!"
        echo ""
        echo "Optional optimizations:"
        echo "  1. Run health check: /root/ct183-health.sh --detailed"
        echo "  2. Check logs: docker logs archon-server --tail 50"
        echo "  3. Monitor resources: docker stats"
    else
        echo ""
        echo "Quick fix commands (run on CT183):"
        echo ""
        echo "  # If you have SSH access:"
        echo "  ssh root@$CT183_IP"
        echo "  /root/ct183-startup.sh --force-restart"
        echo ""
        echo "  # If scripts are not installed:"
        echo "  scp ./scripts/ct183-*.sh root@$CT183_IP:/root/"
        echo "  ssh root@$CT183_IP '/root/ct183-startup.sh'"
    fi
    echo ""
}

# Main execution
main() {
    echo ""
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║  CT183 Remote Diagnostics                                 ║"
    echo "║  Host: $CT183_IP"
    echo "╚════════════════════════════════════════════════════════════╝"

    # Run checks
    check_connectivity
    local conn_status=$?

    if [[ $conn_status -ne 0 ]]; then
        echo ""
        log_error "CT183 is not reachable - cannot continue diagnostics"
        exit 1
    fi

    check_supabase
    local supabase_status=$?

    check_archon
    local archon_status=$?

    check_mcp
    local mcp_status=$?

    generate_report
    suggest_fixes

    # Exit with appropriate code
    if [[ $supabase_status -ne 0 ]] || [[ $archon_status -ne 0 ]] || [[ $mcp_status -ne 0 ]]; then
        exit 1
    else
        exit 0
    fi
}

main "$@"
