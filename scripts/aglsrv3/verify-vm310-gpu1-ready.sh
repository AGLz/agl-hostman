#!/usr/bin/env bash
# Verifica se a 2.ª RX580 (guest 02:00.0) inicializou amdgpu e se :11435 responde.
# Exit 0 = GPU1 pronta para ollama-gpu1; exit 1 = só GPU0 activa.
set -euo pipefail

VMID="${VMID:-310}"
AGLSRV3="${AGLSRV3:-root@100.123.5.81}"
VM310_TS="${VM310_TS:-100.67.253.52}"

ssh -o BatchMode=yes "$AGLSRV3" bash -s -- "$VMID" <<'REMOTE'
set -euo pipefail
VMID="$1"
json=$(qm guest exec "$VMID" -- bash -lc '
  count=$(dmesg | grep -c "Initialized amdgpu" || true)
  gpu1=$(dmesg | grep "0000:02:00.0" | grep -c "Initialized amdgpu" || true)
  echo "amdgpu_count=${count} gpu1=${gpu1}"
' 2>/dev/null || true)
if echo "$json" | grep -q 'gpu1=1\|gpu1=2'; then
  :
elif echo "$json" | grep -qE 'amdgpu_count=[2-9]'; then
  echo "OK: ≥2 dispositivos amdgpu (contagem dmesg)"
else
  echo "WARN: GPU1 sem driver amdgpu — usar só ollama :11434 (GPU0)" >&2
  exit 1
fi
REMOTE

if curl -sf --max-time 5 "http://${VM310_TS}:11435/api/tags" >/dev/null 2>&1; then
  echo "OK: GPU1 Ollama API :11435"
  exit 0
fi

echo "WARN: amdgpu OK mas ollama-gpu1 (:11435) inactivo — correr apply-vm310-ollama-optimize.sh" >&2
exit 1
