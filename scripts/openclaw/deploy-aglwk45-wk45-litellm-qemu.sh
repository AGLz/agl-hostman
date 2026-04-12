#!/usr/bin/env bash
# Aplica sincronização LiteLLM (apiKey + baseUrl) na VM104 (aglwk45) via AGLSRV1 + qm guest exec.
# Requer: Python 3 no Proxmox, guest agent na VM104, Node.js instalado na VM104, SSH do AGLSRV1 ao agldv03 (ou LITELLM_MASTER_KEY no ambiente).
#
# Uso (a partir da raiz do repo):
#   bash scripts/openclaw/deploy-aglwk45-wk45-litellm-qemu.sh
#   AGLSRV1_HOST=root@192.168.0.245 LITELLM_MASTER_KEY='sk-...' bash scripts/openclaw/deploy-aglwk45-wk45-litellm-qemu.sh
set -euo pipefail

# Reason: a partir de agldv03 ou outro nó Tailscale, SSH direto a 100.x pode falhar no banner.
OPENCLAW_SSH=(ssh -o ProxyCommand="tailscale nc %h %p" -o BatchMode=yes -o ConnectTimeout=25 -o StrictHostKeyChecking=accept-new)
OPENCLAW_SCP=(scp -o ProxyCommand="tailscale nc %h %p" -o BatchMode=yes -o ConnectTimeout=25 -o StrictHostKeyChecking=accept-new)

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CJS="$REPO_ROOT/scripts/openclaw/wk45-sync-openclaw-litellm.cjs"
PY="$REPO_ROOT/scripts/openclaw/vm104_guest_wk45_litellm_sync.py"
AGLSRV="${AGLSRV1_HOST:-root@100.107.113.33}"
VMID="${AGLWK45_VMID:-104}"

[[ ! -f "$CJS" ]] && { echo "Erro: $CJS não encontrado"; exit 1; }
[[ ! -f "$PY" ]] && { echo "Erro: $PY não encontrado"; exit 1; }

# Obter chave na máquina que corre este script (não depender de SSH agldv03 a partir do Proxmox)
LITELLM_GATEWAY_SSH="${LITELLM_GATEWAY_SSH:-root@100.94.221.87}"
if [[ -z "${LITELLM_MASTER_KEY:-}" ]]; then
  echo "=== A obter LITELLM_MASTER_KEY de $LITELLM_GATEWAY_SSH ==="
  LITELLM_MASTER_KEY="$("${OPENCLAW_SSH[@]}" "$LITELLM_GATEWAY_SSH" \
    "grep ^LITELLM_MASTER_KEY= /opt/litellm/.env 2>/dev/null | cut -d= -f2-" || true)"
  export LITELLM_MASTER_KEY
  if [[ -z "$LITELLM_MASTER_KEY" ]]; then
    echo "Erro: defina LITELLM_MASTER_KEY ou configure SSH ao host LiteLLM ($LITELLM_GATEWAY_SSH)."
    exit 1
  fi
  echo "OK (${#LITELLM_MASTER_KEY} chars)"
fi

echo "=== Copiar scripts para $AGLSRV ==="
"${OPENCLAW_SCP[@]}" -q "$CJS" "$PY" "$AGLSRV:/tmp/"

echo "=== vm104_guest_wk45_litellm_sync (VMID=$VMID) ==="
REMOTE=""
if [[ -n "${LITELLM_MASTER_KEY:-}" ]]; then
  REMOTE+="export LITELLM_MASTER_KEY=$(printf '%q' "$LITELLM_MASTER_KEY"); "
fi
if [[ -n "${LITELLM_PROXY_BASE_URL:-}" ]]; then
  REMOTE+="export LITELLM_PROXY_BASE_URL=$(printf '%q' "$LITELLM_PROXY_BASE_URL"); "
fi
if [[ -n "${LITELLM_SSH_HOST:-}" ]]; then
  REMOTE+="export LITELLM_SSH_HOST=$(printf '%q' "$LITELLM_SSH_HOST"); "
fi
"${OPENCLAW_SSH[@]}" "$AGLSRV" "${REMOTE}chmod +x /tmp/vm104_guest_wk45_litellm_sync.py && python3 /tmp/vm104_guest_wk45_litellm_sync.py $VMID /tmp/wk45-sync-openclaw-litellm.cjs"

echo "=== Concluído (aglwk45 VM$VMID) ==="
echo "Na VM (sessão do utilizador que corre o gateway): openclaw gateway restart — o guest exec costuma não ter PATH para npm global."
