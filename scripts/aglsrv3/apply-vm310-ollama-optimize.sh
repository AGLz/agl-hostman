#!/usr/bin/env bash
# Aplica override Ollama na VM310: GPU0 (:11434) sempre; GPU1 (:11435) se 2.ª RX580 tiver driver.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GPU0_OVERRIDE="${GPU0_OVERRIDE:-${SCRIPT_DIR}/vm310-ollama-override.conf}"
GPU1_OVERRIDE="${GPU1_OVERRIDE:-${SCRIPT_DIR}/vm310-ollama-gpu1-override.conf}"
GPU1_UNIT="${GPU1_UNIT:-${SCRIPT_DIR}/vm310-ollama-gpu1.service}"
VMID="${VMID:-310}"
AGLSRV3="${AGLSRV3:-root@100.123.5.81}"

log() { echo "[apply-vm310-ollama] $*"; }

for f in "$GPU0_OVERRIDE" "$GPU1_OVERRIDE" "$GPU1_UNIT"; do
  if [[ ! -f "$f" ]]; then
    echo "ERRO: ficheiro em falta: $f" >&2
    exit 1
  fi
done

B64_GPU0=$(base64 -w0 "$GPU0_OVERRIDE")
B64_GPU1=$(base64 -w0 "$GPU1_OVERRIDE")
B64_UNIT=$(base64 -w0 "$GPU1_UNIT")

ssh -o BatchMode=yes "$AGLSRV3" bash -s -- "$VMID" "$B64_GPU0" "$B64_GPU1" "$B64_UNIT" <<'REMOTE'
set -euo pipefail
VMID="$1"
B64_GPU0="$2"
B64_GPU1="$3"
B64_UNIT="$4"
qm guest exec "$VMID" -- bash -lc "
set -e
install -d /etc/systemd/system/ollama.service.d
install -d /etc/systemd/system/ollama-gpu1.service.d
echo '$B64_GPU0' | base64 -d > /etc/systemd/system/ollama.service.d/override.conf
echo '$B64_GPU1' | base64 -d > /etc/systemd/system/ollama-gpu1.service.d/override.conf
echo '$B64_UNIT' | base64 -d > /etc/systemd/system/ollama-gpu1.service
usermod -aG render,video ollama 2>/dev/null || true
systemctl daemon-reload
systemctl enable ollama
systemctl restart ollama
sleep 4
systemctl is-active ollama
curl -sf http://127.0.0.1:11434/api/tags >/dev/null && echo GPU0_API_OK
if dmesg | grep -q 'Initialized amdgpu.*0000:02:00.0'; then
  systemctl enable ollama-gpu1
  systemctl restart ollama-gpu1
  sleep 4
  systemctl is-active ollama-gpu1
  curl -sf http://127.0.0.1:11435/api/tags >/dev/null && echo GPU1_API_OK
else
  systemctl disable --now ollama-gpu1 2>/dev/null || true
  echo GPU1_SKIPPED_NO_DRIVER
fi
journalctl -u ollama -n 5 --no-pager | grep inference || true
"
REMOTE

log "Concluído. Pre-warm: bash scripts/aglsrv3/prewarm-vm310-dual-ollama.sh --remote"
