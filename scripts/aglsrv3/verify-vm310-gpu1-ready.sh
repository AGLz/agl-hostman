#!/usr/bin/env bash
# Verifica se a 2.ª RX580 (02:00.0) inicializou amdgpu na VM310.
# Exit 0 = GPU1 pronta para ollama-gpu1 (:11435); exit 1 = só GPU0 activa.
set -euo pipefail

VMID="${VMID:-310}"
AGLSRV3="${AGLSRV3:-root@100.123.5.81}"

ssh -o BatchMode=yes "$AGLSRV3" bash -s -- "$VMID" <<'REMOTE'
set -euo pipefail
VMID="$1"
out=$(qm guest exec "$VMID" -- bash -lc 'dmesg | grep "0000:02:00.0" | grep "Initialized amdgpu" || true' 2>/dev/null | tr -d '\n')
if echo "$out" | grep -q "Initialized amdgpu"; then
  echo "OK: GPU1 amdgpu inicializada (02:00.0)"
  exit 0
fi
echo "WARN: GPU1 sem driver amdgpu — usar só ollama :11434 (GPU0)" >&2
exit 1
REMOTE
