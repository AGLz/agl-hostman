#!/usr/bin/env bash
# Propaga openclaw.json para aglwk45 (VM104): SSH ao AGLSRV1 + qm guest exec (QEMU guest agent).
#
# Fluxo:
#   1) Obtém ~/.openclaw/openclaw.json do agldv03 (ou usa OPENCLAW_WK45_JSON_PREPARED já com jq client).
#   2) Aplica openclaw-litellm-client.jq (LiteLLM em 100.94.221.87:4000).
#   3) scp do JSON + vm104_guest_push_openclaw_json.py para o Proxmox.
#   4) python3 no AGLSRV1 corre qm guest exec na VM104.
#
# Não copia nem altera ~/.openclaw/cron/ na VM Windows (schedulers locais).
#
# Uso:
#   bash scripts/openclaw/propagate-openclaw-to-aglwk45-qemu.sh
#   AGLSRV1_HOST=root@192.168.0.245 bash scripts/openclaw/propagate-openclaw-to-aglwk45-qemu.sh
#
# Chamado automaticamente por propagate-openclaw-from-agldv03.sh com AGLWK45_VIA_AGLSRV1=1
# (define OPENCLAW_WK45_JSON_PREPARED para evitar segundo download).

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SOURCE="${OPENCLAW_PROPAGATE_SOURCE:-root@100.94.221.87}"
REMOTE_JSON="${AGLSRV1_OPENCLAW_STAGING:-/tmp/openclaw-wk45-propagate.json}"
AGLSRV="${AGLSRV1_HOST:-root@100.107.113.33}"
VMID="${AGLWK45_VMID:-104}"
CLIENT_JQ="$REPO_ROOT/config/openclaw/openclaw-litellm-client.jq"
PY="$REPO_ROOT/scripts/openclaw/vm104_guest_push_openclaw_json.py"

OPENCLAW_SSH=(ssh -o ProxyCommand="tailscale nc %h %p" -o BatchMode=yes -o ConnectTimeout=25 -o StrictHostKeyChecking=accept-new)
OPENCLAW_SCP=(scp -o ProxyCommand="tailscale nc %h %p" -o BatchMode=yes -o ConnectTimeout=25 -o StrictHostKeyChecking=accept-new)

if [[ ! -f "$CLIENT_JQ" || ! -f "$PY" ]]; then
  echo "Erro: $CLIENT_JQ ou $PY em falta." >&2
  exit 1
fi

if [[ -n "${OPENCLAW_WK45_JSON_PREPARED:-}" ]]; then
  JSON_OUT="$OPENCLAW_WK45_JSON_PREPARED"
  if [[ ! -f "$JSON_OUT" ]]; then
    echo "Erro: OPENCLAW_WK45_JSON_PREPARED não existe: $JSON_OUT" >&2
    exit 1
  fi
else
  TMP_DIR="$(mktemp -d)"
  trap 'rm -rf "$TMP_DIR"' EXIT
  echo "=== Descarregar openclaw.json de $SOURCE ==="
  "${OPENCLAW_SCP[@]}" -q "$SOURCE:~/.openclaw/openclaw.json" "$TMP_DIR/openclaw-src.json"
  JSON_OUT="$TMP_DIR/openclaw-wk45.json"
  jq -f "$CLIENT_JQ" "$TMP_DIR/openclaw-src.json" > "$JSON_OUT"
fi

echo "=== AGLSRV1 $AGLSRV — guest agent VM $VMID ==="
scp -q "$JSON_OUT" "$AGLSRV:$REMOTE_JSON"
scp -q "$PY" "$AGLSRV:/tmp/vm104_guest_push_openclaw_json.py"
# shellcheck disable=SC2029
ssh "$AGLSRV" "python3 /tmp/vm104_guest_push_openclaw_json.py $VMID $REMOTE_JSON"

echo "=== Concluído: openclaw.json na aglwk45 (VM$VMID); cron/ local não foi tocado ==="
