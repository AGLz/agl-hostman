#!/bin/bash
# Pre-Implementation Validation Check
# Verifies environment readiness before starting implementation

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPORT_DIR="${SCRIPT_DIR}/../reports"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
REPORT_FILE="${REPORT_DIR}/01-pre-implementation-${TIMESTAMP}.log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Counters
TOTAL_CHECKS=0
PASSED_CHECKS=0
FAILED_CHECKS=0

# Create report directory if it doesn't exist
mkdir -p "$REPORT_DIR"

# Logging function
log() {
    echo -e "$1" | tee -a "$REPORT_FILE"
}

# Check function
check() {
    local description=$1
    local command=$2

    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))

    log "\n[CHECK $TOTAL_CHECKS] $description"

    if eval "$command" &>/dev/null; then
        log "${GREEN}✓ PASS${NC}"
        PASSED_CHECKS=$((PASSED_CHECKS + 1))
        return 0
    else
        log "${RED}✗ FAIL${NC}"
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
        return 1
    fi
}

# Check with output
check_with_output() {
    local description=$1
    local command=$2

    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))

    log "\n[CHECK $TOTAL_CHECKS] $description"

    output=$(eval "$command" 2>&1)
    if [ $? -eq 0 ]; then
        log "${GREEN}✓ PASS${NC}"
        log "Output: $output"
        PASSED_CHECKS=$((PASSED_CHECKS + 1))
        return 0
    else
        log "${RED}✗ FAIL${NC}"
        log "Error: $output"
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
        return 1
    fi
}

# Start validation
log "=========================================="
log "Pre-Implementation Validation Check"
log "=========================================="
log "Started: $(date)"
log "Report: $REPORT_FILE"
log "=========================================="

# Section 1: Source Project Audit
log "\n=== SECTION 1: Source Project Audit (agl-hostman) ==="

check "Source project directory exists" \
    "[ -d /mnt/overpower/apps/dev/agl/agl-hostman ]"

check "Source project is git repository" \
    "git -C /mnt/overpower/apps/dev/agl/agl-hostman rev-parse --git-dir"

check_with_output "Source project git status" \
    "git -C /mnt/overpower/apps/dev/agl/agl-hostman status --short"

check "CLAUDE.md exists" \
    "[ -f /mnt/overpower/apps/dev/agl/agl-hostman/CLAUDE.md ]"

check "docs/INFRA.md exists" \
    "[ -f /mnt/overpower/apps/dev/agl/agl-hostman/docs/INFRA.md ]"

check "docs/ARCHON.md exists" \
    "[ -f /mnt/overpower/apps/dev/agl/agl-hostman/docs/ARCHON.md ]"

check "docs/WORKFLOWS.md exists" \
    "[ -f /mnt/overpower/apps/dev/agl/agl-hostman/docs/WORKFLOWS.md ]"

check "docs/RULES.md exists" \
    "[ -f /mnt/overpower/apps/dev/agl/agl-hostman/docs/RULES.md ]"

check "docs/QUICK-START.md exists" \
    "[ -f /mnt/overpower/apps/dev/agl/agl-hostman/docs/QUICK-START.md ]"

check "docs/DOKPLOY.md exists" \
    "[ -f /mnt/overpower/apps/dev/agl/agl-hostman/docs/DOKPLOY.md ]"

# Section 2: Target Project Audit
log "\n=== SECTION 2: Target Project Audit (crowbar) ==="

check "Target project directory exists" \
    "[ -d /mnt/overpower/apps/dev/agl/crowbar ]"

check "Target project is git repository" \
    "git -C /mnt/overpower/apps/dev/agl/crowbar rev-parse --git-dir"

check_with_output "Target project git status" \
    "git -C /mnt/overpower/apps/dev/agl/crowbar status --short"

check_with_output "Target project branches" \
    "git -C /mnt/overpower/apps/dev/agl/crowbar branch -a | head -10"

check_with_output "Target project disk space" \
    "df -h /mnt/overpower/apps/dev/agl/crowbar | tail -1 | awk '{print \$4}'"

# Section 3: Network Connectivity
log "\n=== SECTION 3: Network Connectivity ==="

check "WireGuard interface exists" \
    "ip link show wg0"

check "Archon WireGuard IP reachable (10.6.0.21)" \
    "ping -c 3 -W 2 10.6.0.21"

check "AGLSRV6 WireGuard IP reachable (10.6.0.12)" \
    "ping -c 3 -W 2 10.6.0.12"

check "AGLSRV1 LAN IP reachable (192.168.0.245)" \
    "ping -c 3 -W 2 192.168.0.245"

# Check if Tailscale is available
if command -v tailscale &>/dev/null; then
    check "Tailscale running" \
        "tailscale status"

    check "Archon Tailscale IP reachable (100.80.30.59)" \
        "ping -c 3 -W 2 100.80.30.59"
else
    log "${YELLOW}⚠ Tailscale not available (optional)${NC}"
fi

# Section 4: Archon MCP Endpoints
log "\n=== SECTION 4: Archon MCP Endpoints ==="

check "Archon MCP WireGuard endpoint accessible" \
    "curl -sf http://10.6.0.21:8051/mcp"

check "Archon MCP Tailscale endpoint accessible" \
    "curl -sf http://100.80.30.59:8051/mcp"

check "Archon MCP LAN endpoint accessible" \
    "curl -sf http://192.168.0.183:8052/mcp"

check_with_output "Claude MCP configuration" \
    "claude mcp list 2>/dev/null || echo 'Claude CLI not available'"

# Section 5: Harbor Registry
log "\n=== SECTION 5: Harbor Registry ==="

check "Harbor registry HTTPS accessible" \
    "curl -k -sf https://harbor.aglz.io:5000/v2/_catalog"

check "Docker daemon running" \
    "docker info"

# Section 6: Dokploy Platform
log "\n=== SECTION 6: Dokploy Platform ==="

check "Dokploy HTTPS accessible" \
    "curl -sf https://dok.aglz.io"

check "CT180 container exists" \
    "ssh -o ConnectTimeout=5 root@192.168.0.245 'pct status 180'"

# Section 7: Storage Mounts
log "\n=== SECTION 7: Storage Mounts ==="

check "NFS mount /mnt/pve/fgsrv6-wg exists" \
    "[ -d /mnt/pve/fgsrv6-wg ]"

check_with_output "NFS mounts status" \
    "df -h | grep -E '(fgsrv6|aglfs1)' || echo 'No NFS mounts found'"

check_with_output "Mount points" \
    "mount | grep nfs || echo 'No NFS mounts active'"

# Test write access if mount exists
if [ -d /mnt/pve/fgsrv6-wg ]; then
    check "Write access to NFS mount" \
        "touch /mnt/pve/fgsrv6-wg/test-$TIMESTAMP.tmp && rm /mnt/pve/fgsrv6-wg/test-$TIMESTAMP.tmp"
fi

# Section 8: Development Tools
log "\n=== SECTION 8: Development Tools ==="

check "Git installed" \
    "command -v git"

check "Docker installed" \
    "command -v docker"

check "curl installed" \
    "command -v curl"

check "jq installed" \
    "command -v jq"

check "Node.js installed" \
    "command -v node"

check "npm installed" \
    "command -v npm"

# Optional tools
if command -v markdownlint &>/dev/null; then
    check "markdownlint installed" \
        "command -v markdownlint"
else
    log "${YELLOW}⚠ markdownlint not installed (optional)${NC}"
fi

if command -v markdown-link-check &>/dev/null; then
    check "markdown-link-check installed" \
        "command -v markdown-link-check"
else
    log "${YELLOW}⚠ markdown-link-check not installed (optional)${NC}"
fi

# Summary
log "\n=========================================="
log "Validation Summary"
log "=========================================="
log "Total Checks: $TOTAL_CHECKS"
log "${GREEN}Passed: $PASSED_CHECKS${NC}"
log "${RED}Failed: $FAILED_CHECKS${NC}"

# Calculate pass rate
if [ $TOTAL_CHECKS -gt 0 ]; then
    PASS_RATE=$((PASSED_CHECKS * 100 / TOTAL_CHECKS))
    log "Pass Rate: ${PASS_RATE}%"
fi

log "=========================================="
log "Report saved to: $REPORT_FILE"
log "Completed: $(date)"
log "=========================================="

# Exit with failure if any critical checks failed
CRITICAL_FAILURES=$FAILED_CHECKS

if [ $CRITICAL_FAILURES -gt 0 ]; then
    log "\n${RED}⚠ VALIDATION FAILED${NC}"
    log "Critical failures detected: $CRITICAL_FAILURES"
    log "Please resolve issues before proceeding with implementation."
    exit 1
else
    log "\n${GREEN}✓ VALIDATION PASSED${NC}"
    log "Environment is ready for implementation."
    exit 0
fi
