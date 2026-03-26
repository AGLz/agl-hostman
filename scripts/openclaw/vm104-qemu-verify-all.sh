#!/usr/bin/env bash
# Verificação aglwk45 (VM Windows) via SSH ao Proxmox AGLSRV1 e qm guest exec.
#
# Limitação: guest exec corre como SYSTEM — PATH sem npm global; U: pode não existir.
# Ver openclaw status / doctor em sessão RDP (Administrator).
#
# Uso (a partir da raiz do repo):
#   bash scripts/openclaw/vm104-qemu-verify-all.sh
#   AGLSRV1_HOST=root@192.168.0.245 VMID=104 LITELLM_HOST=100.94.221.87 bash ...
#
set -uo pipefail

AGLSRV="${AGLSRV1_HOST:-root@100.107.113.33}"
VMID="${VMID:-104}"
LITELLM_HOST="${LITELLM_HOST:-100.94.221.87}"
WK_USER="${WK45_WINDOWS_USER:-Administrator}"
# Caminhos Windows: preferir PowerShell com / (guest exec + ssh não preservam bem \ no findstr)
OC_JSON_PS="C:/Users/${WK_USER}/.openclaw/openclaw.json"
OC_LOG_DIR_WIN="C:/Users/${WK_USER}/.openclaw/logs"
OC_ENV_WIN="C:/Users/${WK_USER}/.openclaw/litellm-gateway.env"
OC_CLONE_PKG="C:/Users/${WK_USER}/src/openclaw/package.json"
OC_GATEWAY_CMD_WIN="C:/Users/${WK_USER}/.openclaw/gateway.cmd"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

FAILS=0
pass() { echo -e "${GREEN}[OK]${NC} $1"; }
fail() { echo -e "${RED}[FAIL]${NC} $1"; FAILS=$((FAILS + 1)); }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
info() { echo -e "${CYAN}---${NC} $1 ${CYAN}---${NC}"; }

ssh_pve() {
  # Reason: BatchMode evita prompt; timeout evita bloqueio
  ssh -o ConnectTimeout=25 -o BatchMode=yes "$AGLSRV" "$@"
}

guest_cmd() {
  local inner=$1
  ssh_pve "qm guest exec ${VMID} -- ${inner}"
}

echo ""
echo "=========================================="
echo "  vm104-qemu-verify-all (aglwk45)"
echo "  $(date '+%Y-%m-%d %H:%M:%S')"
echo "  AGLSRV=${AGLSRV} VMID=${VMID} LITELLM=${LITELLM_HOST}"
echo "=========================================="
echo ""

info "Proxmox: estado VM + QEMU agent"
if ! OUTVM=$(ssh_pve "qm status ${VMID}" 2>&1); then
  fail "SSH ao Proxmox falhou: $OUTVM"
  exit 1
fi
echo "$OUTVM"
if echo "$OUTVM" | grep -q 'status: running'; then
  pass "VM a correr"
else
  fail "VM não está running"
fi

if ssh_pve "qm agent ${VMID} ping" >/dev/null 2>&1; then
  pass "qm agent ping"
else
  fail "qm agent ping"
fi

info "Rede guest → LiteLLM (ping)"
PING_OUT=$(guest_cmd "cmd /c ping -n 2 ${LITELLM_HOST}" 2>&1 || true)
echo "$PING_OUT" | head -20
if echo "$PING_OUT" | grep -q 'Lost = 0'; then
  pass "Ping ${LITELLM_HOST}"
else
  fail "Ping ${LITELLM_HOST}"
fi

info "LiteLLM liveliness (HTTP guest)"
LIVE_OUT=$(guest_cmd "cmd /c curl -s --connect-timeout 10 http://${LITELLM_HOST}:4000/health/liveliness" 2>&1 || true)
echo "$LIVE_OUT" | head -15
if echo "$LIVE_OUT" | grep -qi "alive"; then
  pass "health/liveliness"
else
  fail "health/liveliness"
fi

info "Node + OpenClaw (clone)"
NODEV=$(guest_cmd "cmd /c node --version" 2>&1 || true)
echo "$NODEV" | head -8
if echo "$NODEV" | grep -qE 'v[0-9]+\.'; then
  pass "node --version"
else
  warn "node --version (guest SYSTEM pode não refletir sessão interativa)"
fi

OC_VER=$(ssh_pve "qm guest exec ${VMID} -- powershell -NoProfile -Command '(Get-Content ${OC_CLONE_PKG} -Raw | ConvertFrom-Json).version'" 2>&1 || true)
echo "$OC_VER" | head -10
if echo "$OC_VER" | grep -qE '20[0-9]{2}\.[0-9]'; then
  pass "openclaw package.json (clone)"
else
  warn "package.json do clone inacessível ou clone ausente"
fi

info "openclaw.json → baseUrl LiteLLM"
JSON_GREP=$(ssh_pve "qm guest exec ${VMID} -- powershell -NoProfile -Command 'Select-String -Path ${OC_JSON_PS} -Pattern ${LITELLM_HOST} -SimpleMatch'" 2>&1 || true)
echo "$JSON_GREP" | head -12
if echo "$JSON_GREP" | grep -q "${LITELLM_HOST}"; then
  pass "openclaw.json contém ${LITELLM_HOST}"
else
  fail "openclaw.json sem URL LiteLLM esperada"
fi

info "Placeholder sk-litellm-default (0 = bom)"
SK_DEF=$(ssh_pve "qm guest exec ${VMID} -- powershell -NoProfile -Command '(Select-String -Path ${OC_JSON_PS} -Pattern sk-litellm-default -SimpleMatch).Count'" 2>&1 || true)
echo "$SK_DEF" | head -8
if echo "$SK_DEF" | grep -qE 'out-data.*0\\r\\n|"out-data"[[:space:]]*:[[:space:]]*\"0\\r\\n'; then
  pass "sem sk-litellm-default literal no JSON"
elif echo "$SK_DEF" | grep -q '"out-data"[[:space:]]*:[[:space:]]*\"0'; then
  pass "sem sk-litellm-default literal no JSON"
else
  warn "não foi possível confirmar contagem (ver saída acima); pode haver placeholder"
fi

info "litellm-gateway.env"
ENV_OK=$(ssh_pve "qm guest exec ${VMID} -- powershell -NoProfile -Command 'Test-Path ${OC_ENV_WIN}'" 2>&1 || true)
echo "$ENV_OK" | head -6
if echo "$ENV_OK" | grep -qi true; then
  pass "litellm-gateway.env existe"
else
  warn "litellm-gateway.env ausente (opcional se keys só no JSON)"
fi

info "gateway.cmd (NODE_OPTIONS / heap)"
GW_HEAD=$(ssh_pve "qm guest exec ${VMID} -- powershell -NoProfile -Command 'Get-Content ${OC_GATEWAY_CMD_WIN} -Head 40'" 2>&1 || true)
echo "$GW_HEAD" | head -35
if echo "$GW_HEAD" | grep -qEi 'dist.*index\.js'; then
  pass "gateway.cmd aponta para dist/index.js"
else
  warn "gateway.cmd inesperado ou em falta"
fi
NOOPT=$(ssh_pve "qm guest exec ${VMID} -- powershell -NoProfile -Command 'Select-String -Path ${OC_GATEWAY_CMD_WIN} -Pattern NODE_OPTIONS'" 2>&1 || true)
if echo "$NOOPT" | grep -qi NODE_OPTIONS; then
  pass "NODE_OPTIONS presente em gateway.cmd"
else
  warn "NODE_OPTIONS ausente — considerar wk45-patch-gateway-nodeopts.ps1 / heap"
fi

info "Porta gateway 18789"
PORT=$(ssh_pve "qm guest exec ${VMID} -- powershell -NoProfile -Command '(Get-NetTCPConnection -LocalPort 18789 -ErrorAction SilentlyContinue).State'" 2>&1 || true)
echo "$PORT" | head -10
if echo "$PORT" | grep -qi Listen; then
  pass "porta 18789 em Listen"
else
  fail "porta 18789 (gateway pode estar parado)"
fi

info "Tarefa agendada OpenClaw Gateway"
TASK=$(ssh_pve "qm guest exec ${VMID} -- cmd /c schtasks /Query /TN \"OpenClaw Gateway\" /FO LIST" 2>&1 || true)
echo "$TASK" | head -15
if echo "$TASK" | grep -qi 'Running'; then
  pass "OpenClaw Gateway task running"
else
  warn "tarefa não em Running ou nome diferente"
fi

info "Log mais recente em .openclaw/logs"
LOGNEW=$(ssh_pve "qm guest exec ${VMID} -- powershell -NoProfile -Command 'if (Test-Path ${OC_LOG_DIR_WIN}) { Get-ChildItem ${OC_LOG_DIR_WIN} | Sort-Object LastWriteTime -Descending | Select-Object -First 1 Name,LastWriteTime,Length }'" 2>&1 || true)
echo "$LOGNEW" | head -15
if echo "$LOGNEW" | grep -qiE 'Name|LastWriteTime|config-health'; then
  pass "directório de logs acessível"
else
  warn "logs vazios ou path diferente"
fi

info "Clone agl-hostman em U: (esperado WARN em guest SYSTEM)"
U_REPO=$(ssh_pve "qm guest exec ${VMID} -- powershell -NoProfile -Command 'Test-Path U:/apps/dev/agl/agl-hostman'" 2>&1 || true)
echo "$U_REPO" | head -6
if echo "$U_REPO" | grep -qi true; then
  pass "U:\\apps\\dev\\agl\\agl-hostman visível no guest exec"
else
  warn "U: não visível no SYSTEM — normal; ver vm104-verify-overpower-repo.sh / WK45_REPO_WIN"
fi

echo ""
echo "=========================================="
if [[ "$FAILS" -eq 0 ]]; then
  echo -e "${GREEN}Resumo: sem falhas críticas detetadas.${NC}"
  exit 0
fi
echo -e "${RED}Resumo: ${FAILS} verificação(ões) falharam.${NC}"
echo "Sessão RDP: openclaw doctor / openclaw logs gateway"
exit 1
