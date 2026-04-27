#!/usr/bin/env bash
# =============================================================================
# Aplica no agldv03–fgsrv06: LiteLLM (config+.env+restart), OpenClaw env no repo
# e em ~/.openclaw/, e opcionalmente ~/.zshrc a partir do host de origem.
#
# Uso (a partir da raiz do repo):
#   ./scripts/deploy/sync-litellm-openclaw-shell-all-hosts.sh
#   ZSHRC_SOURCE_HOST=100.94.221.87 ./scripts/deploy/sync-litellm-openclaw-shell-all-hosts.sh
#   SKIP_ZSHRC=1 ./scripts/deploy/sync-litellm-openclaw-shell-all-hosts.sh
#
# Requer SSH root por Tailscale/IPs abaixo.
# =============================================================================
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SKIP_ZSHRC="${SKIP_ZSHRC:-0}"
# Host de onde copiar ~/.zshrc (default: agldv03)
ZSHRC_SOURCE_HOST="${ZSHRC_SOURCE_HOST:-100.94.221.87}"

declare -A HOST_IPS
HOST_IPS[agldv03]="100.94.221.87"
HOST_IPS[agldv04]="100.113.9.98"
HOST_IPS[agldv12]="100.71.217.115"
HOST_IPS[fgsrv06]="100.83.51.9"

REPO_PATH_REMOTE="/mnt/overpower/apps/dev/agl/agl-hostman"

echo "=============================================="
echo "  AGL — LiteLLM + OpenClaw + shell (multi-host)"
echo "=============================================="
echo "  Repo: $REPO_ROOT"
echo ""

# --- 1) LiteLLM: replica config + merge .env em todos (script existente) ---
if [[ ! -f "$REPO_ROOT/scripts/litellm/replicate-all-hosts.sh" ]]; then
  echo "ERRO: replicate-all-hosts.sh não encontrado"
  exit 1
fi
bash "$REPO_ROOT/scripts/litellm/replicate-all-hosts.sh"

echo ""
echo "=== OpenClaw (zshrc-openclaw*.env) → ~/.openclaw + clone repo ==="

OC_FILES=(
  "zshrc-openclaw.env"
  "zshrc-openclaw-litellm.env"
  "zshrc-openclaw-direct.env"
)

for entry in "${!HOST_IPS[@]}"; do
  ip="${HOST_IPS[$entry]}"
  echo "--- $entry ($ip) OpenClaw ---"
  if ! ssh -o ConnectTimeout=12 -o BatchMode=yes "root@${ip}" "umask 077; mkdir -p /root/.openclaw"; then
    echo "  SKIP: SSH falhou"
    continue
  fi
  for f in "${OC_FILES[@]}"; do
    src="$REPO_ROOT/config/openclaw/$f"
    [[ -f "$src" ]] || continue
    scp -q "$src" "root@${ip}:/root/.openclaw/$f" && echo "  OK ~/.openclaw/$f"
  done
  if ssh -o ConnectTimeout=8 "root@${ip}" "test -d ${REPO_PATH_REMOTE}/config/openclaw" 2>/dev/null; then
    for f in "${OC_FILES[@]}"; do
      src="$REPO_ROOT/config/openclaw/$f"
      [[ -f "$src" ]] || continue
      scp -q "$src" "root@${ip}:${REPO_PATH_REMOTE}/config/openclaw/$f" && echo "  OK ${REPO_PATH_REMOTE}/config/openclaw/$f"
    done
  else
    echo "  (sem clone em ${REPO_PATH_REMOTE}; só ~/.openclaw)"
  fi
done

if [[ "$SKIP_ZSHRC" != "1" ]]; then
  echo ""
  echo "=== ~/.zshrc (origem root@${ZSHRC_SOURCE_HOST}) ==="
  tmp_zsh="$(mktemp)"
  if ! scp -q "root@${ZSHRC_SOURCE_HOST}:/root/.zshrc" "$tmp_zsh" 2>/dev/null; then
    echo "  ERRO: não ler ~/.zshrc de ${ZSHRC_SOURCE_HOST} — defina ZSHRC_SOURCE_HOST ou SKIP_ZSHRC=1"
    rm -f "$tmp_zsh"
    exit 1
  fi
  for entry in "${!HOST_IPS[@]}"; do
    ip="${HOST_IPS[$entry]}"
    [[ "$ip" == "$ZSHRC_SOURCE_HOST" ]] && { echo "  $entry: origem (não sobrescrever)"; continue; }
    echo "  $entry ($ip)..."
    if ! ssh -o ConnectTimeout=12 "root@${ip}" "true"; then
      echo "    SKIP SSH"
      continue
    fi
    ts="$(date +%Y%m%d%H%M)"
    ssh "root@${ip}" "cp -a /root/.zshrc /root/.zshrc.bak.${ts} 2>/dev/null || true"
    scp -q "$tmp_zsh" "root@${ip}:/root/.zshrc"
    echo "    OK ~/.zshrc (backup .bak.$ts)"
  done
  rm -f "$tmp_zsh"
fi

echo ""
echo "=============================================="
echo "  Concluído. Novas shells: source ~/.zshrc"
echo "  LiteLLM: curl http://<host>:4000/health/readiness"
echo "=============================================="
