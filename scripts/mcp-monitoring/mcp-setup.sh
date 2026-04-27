#!/bin/bash
##############################################################################
# MCP Server One-Time Setup Script
# Part of AGL-25: MCP Server Optimization
##############################################################################

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

# Main setup
main() {
    log_info "MCP Server One-Time Setup"
    echo ""

    # 1. Install all required packages globally
    log_info "Step 1: Installing MCP packages globally..."
    npm install -g claude-flow@alpha
    npm install -g ruv-swarm@latest
    npm install -g flow-nexus@latest
    npm install -g exa-mcp-server@latest
    npm install -g agentic-payments@latest
    log_success "All packages installed"
    echo ""

    # 2. Create log directory
    log_info "Step 2: Creating log directories..."
    mkdir -p "${PROJECT_ROOT}/logs/mcp-monitoring"
    log_success "Log directories created"
    echo ""

    # 3. Setup cron job
    log_info "Step 3: Setting up automated monitoring..."
    "${SCRIPT_DIR}/mcp-health-check.sh" setup-cron
    echo ""

    # 4. Run initial health check
    log_info "Step 4: Running initial health check..."
    "${SCRIPT_DIR}/mcp-health-check.sh" check
    echo ""

    # 5. Store status in Archon (if available)
    log_info "Step 5: Storing status in Archon memory..."
    if command -v claude &> /dev/null; then
        claude mcp list > "${PROJECT_ROOT}/logs/mcp-monitoring/mcp-list-initial.txt" 2>&1 || true
        log_success "MCP list saved to logs"
    fi
    echo ""

    # 6. Print summary
    log_success "Setup complete!"
    echo ""
    echo "Next steps:"
    echo "  1. Review health report: ${SCRIPT_DIR}/mcp-health-check.sh report"
    echo "  2. Start auto-restart: ${SCRIPT_DIR}/mcp-auto-restart.sh start"
    echo "  3. Or install as service: ${SCRIPT_DIR}/mcp-auto-restart.sh systemd"
    echo ""
    echo "Monitoring:"
    echo "  - Logs: ${PROJECT_ROOT}/logs/mcp-monitoring/"
    echo "  - Health: ${PROJECT_ROOT}/logs/mcp-monitoring/mcp-health-status.json"
    echo ""
}

main "$@"
