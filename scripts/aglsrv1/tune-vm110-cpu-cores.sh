#!/usr/bin/env bash
# Ajusta vCPUs da VM110 agl-ollama no AGLSRV1 (Ollama failover / Plan C).
# Reason: 48 cores não melhorou inferência CPU; 16 vCPUs alinhados ao NUMA0 (GPU socket).
# GPU: GTX 1650 activa; RX580 8GB na janela de manutenção (ver docs/AGL-OLLAMA-VM110.md).
#
# Uso (root no AGLSRV1 ou remoto):
#   bash scripts/aglsrv1/tune-vm110-cpu-cores.sh
#   CORES=16 bash scripts/aglsrv1/tune-vm110-cpu-cores.sh
set -euo pipefail

VMID="${VMID:-110}"
CORES="${CORES:-16}"
AGLSRV1="${AGLSRV1:-root@100.107.113.33}"
MEMORY_MB="${MEMORY_MB:-16384}"

# ponytail: pin socket 0 — GTX 1650 em 05:00.0 (NUMA node 0)
AFFINITY="${AFFINITY:-0-15,28-43}"
NUMA0="${NUMA0:-cpus=0-15,hostnodes=0,memory=${MEMORY_MB},policy=bind}"

log() { echo "[tune-vm110] $*"; }

run_local() {
  qm set "$VMID" --cores "$CORES" --sockets 1 \
    --affinity "$AFFINITY" \
    --numa 0 \
    --numa0 "$NUMA0"
  qm config "$VMID" | grep -E '^(name|cores|sockets|affinity|numa|memory|balloon):'
}

if [[ "${EUID:-0}" -eq 0 ]] && command -v qm &>/dev/null; then
  log "Local AGLSRV1 — VM${VMID} → ${CORES} cores"
  run_local
else
  log "Remoto ${AGLSRV1} — VM${VMID} → ${CORES} cores"
  ssh -o BatchMode=yes "$AGLSRV1" \
    "VMID=${VMID} CORES=${CORES} MEMORY_MB=${MEMORY_MB} AFFINITY='${AFFINITY}' NUMA0='${NUMA0}' bash -s" <<'REMOTE'
set -euo pipefail
qm set "$VMID" --cores "$CORES" --sockets 1 \
  --affinity "$AFFINITY" \
  --numa 0 \
  --numa0 "$NUMA0"
qm config "$VMID" | grep -E '^(name|cores|sockets|affinity|numa|memory|balloon):'
REMOTE
fi

log "Nota: redução de vCPUs pode exigir reboot da VM para o guest ver nproc=${CORES}."
log "RX580 8GB: aguardar janela de manutenção (finish-vm110-gpu-passthrough.sh após troca)."
