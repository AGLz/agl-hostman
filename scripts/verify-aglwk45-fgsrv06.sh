#!/bin/bash
# ========================================
# Verificação Completa: AGLWK45 + FGSRV06 + LiteLLM
# Usage: ./scripts/verify-aglwk45-fgsrv06.sh
# ========================================

echo "========================================"
echo "  AGL Infrastructure Verification"
echo "  $(date '+%Y-%m-%d %H:%M:%S')"
echo "========================================"
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

FAIL_COUNT=0

pass() { echo -e "${GREEN}[OK]${NC} $1"; }
fail() { echo -e "${RED}[FAIL]${NC} $1"; ((FAIL_COUNT++)); }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }

# ========================================
# 1. FGSRV06 (Locaweb VPS vps41772)
# ========================================
echo "=== FGSRV06 (WireGuard Hub) ==="
echo ""

# 1.1 Locaweb API Status
echo -n "API Status: "
LW_STATUS=$(./scripts/locaweb-api/lw-status vps41772 2>/dev/null | grep "Status:" | head -1 | awk '{print $2}')
if [ "$LW_STATUS" = "installed" ]; then
    echo -e "${GREEN}installed/active${NC}"
else
    echo -e "${RED}$LW_STATUS${NC}"
fi

# 1.2 Tailscale Ping
echo -n "Tailscale (100.83.51.9): "
if ping -c 1 -W 3 100.83.51.9 >/dev/null 2>&1; then
    pass ""
else
    fail "unreachable"
fi

# 1.3 Public IP Ping
echo -n "Public IP (186.202.57.120): "
if ping -c 1 -W 3 186.202.57.120 >/dev/null 2>&1; then
    pass ""
else
    fail "unreachable"
fi

# 1.4 SSH Test
echo -n "SSH: "
if timeout 10 ssh -i ~/.ssh/fg_srv.pem -o ConnectTimeout=8 -o StrictHostKeyChecking=no root@186.202.57.120 'echo ok' >/dev/null 2>&1; then
    pass ""
else
    fail "timeout/banner issue"
fi

echo ""

# ========================================
# 2. AGLWK45 (VM104 via QEMU on AGLSRV1)
# ========================================
echo "=== AGLWK45 (Windows VM104) ==="
echo ""

# 2.1 VM Status
echo -n "VM Status: "
VM_STATUS=$(ssh -o ConnectTimeout=5 root@100.107.113.33 'qm status 104' 2>/dev/null | awk '{print $2}')
if [ "$VM_STATUS" = "running" ]; then
    pass "running"
else
    fail "$VM_STATUS"
fi

# 2.2 QEMU Guest Agent
echo -n "QEMU Guest Agent: "
if ssh -o ConnectTimeout=5 root@100.107.113.33 'qm agent 104 ping' >/dev/null 2>&1; then
    pass ""
else
    warn "not responding"
fi

# 2.3 Network - Ping agldv03
echo -n "Network (to agldv03): "
PING_RESULT=$(ssh -o ConnectTimeout=5 root@100.107.113.33 'qm guest exec 104 -- cmd /c "ping -n 1 100.94.221.87"' 2>&1)
if echo "$PING_RESULT" | grep -q "Lost = 0"; then
    pass ""
else
    fail "packet loss"
fi

# 2.4 OpenClaw Config
echo -n "OpenClaw Config: "
OPENCLAW_CONFIG=$(ssh -o ConnectTimeout=5 root@100.107.113.33 'qm guest exec 104 -- cmd /c "type C:\\Users\\Administrator\\.openclaw\\openclaw.json"' 2>&1)
if echo "$OPENCLAW_CONFIG" | grep -q "100.94.221.87:4000"; then
    pass "baseUrl -> agldv03:4000"
else
    warn "config issue"
fi

# 2.5 Repo agl-hostman no guest (U: overpower — pode falhar sem sessão interativa)
echo -n "Repo patch script (guest U:\\\\apps\\\\... ou WK45_REPO_WIN): "
REPO_PS1=$(ssh -o ConnectTimeout=5 root@100.107.113.33 'qm guest exec 104 -- cmd /c "if exist U:\apps\dev\agl\agl-hostman\scripts\openclaw\wk45-patch-gateway-nodeopts.ps1 (echo OK) else (echo NO)"' 2>&1)
if echo "$REPO_PS1" | grep -qE 'out-data.*OK'; then
    pass "wk45-patch-gateway-nodeopts.ps1 visível no guest exec"
else
    warn "ausente no contexto guest (normal se U: só no login) — ver docs/AGLWK45-SETUP.md"
fi

echo ""

# ========================================
# 3. LiteLLM (agldv03)
# ========================================
echo "=== LiteLLM (agldv03:4000) ==="
echo ""

# 3.1 Health Check
echo -n "Health Endpoint: "
HEALTH=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:4000/health 2>/dev/null)
if [ "$HEALTH" = "401" ] || [ "$HEALTH" = "200" ]; then
    pass "HTTP $HEALTH"
else
    fail "HTTP $HEALTH"
fi

# 3.2 Models List
echo -n "Models Available: "
MODELS=$(curl -s http://localhost:4000/v1/models -H "Authorization: Bearer sk-litellm-default" 2>/dev/null | jq -r '.data[].id' 2>/dev/null | wc -l)
if [ "$MODELS" -gt 5 ]; then
    pass "$MODELS models"
else
    warn "only $MODELS models"
fi

echo ""

# ========================================
# 4. Summary
# ========================================
echo "========================================"
echo "  SUMMARY"
echo "========================================"

if [ $FAIL_COUNT -eq 0 ]; then
    echo -e "${GREEN}All checks passed!${NC}"
    exit 0
else
    echo -e "${RED}$FAIL_COUNT check(s) failed${NC}"
    echo ""
    echo "=== Recommended Actions ==="

    echo "1. FGSRV06 offline? Reboot via Locaweb API:"
    echo "   echo 'y' | ./scripts/locaweb-api/lw-reboot vps41772"

    echo ""
    echo "2. Check LiteLLM on agldv03:"
    echo "   systemctl status litellm"

    echo ""
    echo "3. Check AGLWK45 OpenClaw logs:"
    echo "   ssh root@100.107.113.33 'qm guest exec 104 -- cmd /c \"type C:\\Users\\Administrator\\.openclaw\\logs\\*.log\"'"

    exit 1
fi
