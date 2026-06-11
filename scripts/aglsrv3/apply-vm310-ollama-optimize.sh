#!/usr/bin/env bash
# Aplica override Ollama optimizado na VM310 (AGLSRV3) e reinicia o serviço.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OVERRIDE_SRC="${OVERRIDE_SRC:-${SCRIPT_DIR}/vm310-ollama-override.conf}"
VMID="${VMID:-310}"
AGLSRV3="${AGLSRV3:-root@100.123.5.81}"

log() { echo "[apply-vm310-ollama] $*"; }

if [[ ! -f "$OVERRIDE_SRC" ]]; then
  echo "ERRO: override não encontrado: $OVERRIDE_SRC" >&2
  exit 1
fi

B64=$(base64 -w0 "$OVERRIDE_SRC")

ssh -o BatchMode=yes "$AGLSRV3" bash -s -- "$VMID" "$B64" <<'REMOTE'
set -euo pipefail
VMID="$1"
B64="$2"
qm guest exec "$VMID" -- bash -lc "
set -e
install -d /etc/systemd/system/ollama.service.d
echo '$B64' | base64 -d > /etc/systemd/system/ollama.service.d/override.conf
usermod -aG render,video ollama 2>/dev/null || true
systemctl daemon-reload
systemctl restart ollama
sleep 5
systemctl is-active ollama
curl -sf http://127.0.0.1:11434/api/tags >/dev/null && echo API_OK
journalctl -u ollama -n 30 --no-pager | grep -iE 'inference compute|vulkan|total_vram|library=' || true
"
REMOTE

log "Concluído. Testar: curl http://100.67.253.52:11434/api/tags"
