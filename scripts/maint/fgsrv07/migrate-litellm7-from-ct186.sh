#!/usr/bin/env bash
# Clone CT186 (AGLSRV1) → CT574 litellm7 (FGSRV7) via vzdump + restore. Deixa CT574 stopped.
#
# Executar em duas fases:
#   1) No AGLSRV1: DUMP_ONLY=1 bash migrate-litellm7-from-ct186.sh
#   2) No FGSRV7:  RESTORE_ONLY=1 DUMP_PATH=/path/186-*.vma.zst bash migrate-litellm7-from-ct186.sh
#
# Ou pipeline (se SSH entre nós OK):
#   bash migrate-litellm7-from-ct186.sh

set -euo pipefail

AGLSRV1="${AGLSRV1:-root@100.107.113.33}"
FGSRV7="${FGSRV7:-root@100.109.181.93}"
SOURCE_VMID="${SOURCE_VMID:-186}"
TARGET_VMID="${TARGET_VMID:-574}"
TARGET_HOSTNAME="${TARGET_HOSTNAME:-litellm7}"
TARGET_IP="${TARGET_IP:-192.168.70.248/24}"
TARGET_GW="${TARGET_GW:-192.168.70.1}"
TARGET_BRIDGE="${TARGET_BRIDGE:-vmbr70}"
STORAGE_FGSRV7="${STORAGE_FGSRV7:-bkp}"
DUMP_DIR="${DUMP_DIR:-/var/lib/vz/dump}"
DUMP_ONLY="${DUMP_ONLY:-0}"
RESTORE_ONLY="${RESTORE_ONLY:-0}"

log() { printf '[%s] %s\n' "$(date +%H:%M:%S)" "$*"; }

_dump() {
    log "vzdump CT${SOURCE_VMID} no AGLSRV1"
    ssh -o BatchMode=yes "${AGLSRV1}" bash -s <<REMOTE
set -euo pipefail
vzdump ${SOURCE_VMID} --mode snapshot --compress zstd --storage local --notes-template "litellm7-migrate"
ls -lt ${DUMP_DIR}/vzdump-lxc-${SOURCE_VMID}-*.tar.zst 2>/dev/null | head -1 || ls -lt ${DUMP_DIR}/vzdump-lxc-${SOURCE_VMID}-*.vma.zst 2>/dev/null | head -1
REMOTE
}

_restore() {
    local dump_path="$1"
    log "Restore CT${TARGET_VMID} no FGSRV7 a partir de ${dump_path}"
    ssh -o BatchMode=yes "${FGSRV7}" bash -s <<REMOTE
set -euo pipefail
if pct status ${TARGET_VMID} &>/dev/null; then
  echo "VMID ${TARGET_VMID} já existe"
  exit 1
fi
pct restore ${TARGET_VMID} "${dump_path}" --storage ${STORAGE_FGSRV7} --ignore-unpack-errors 1
pct set ${TARGET_VMID} -hostname ${TARGET_HOSTNAME}
pct set ${TARGET_VMID} -net0 name=eth0,bridge=${TARGET_BRIDGE},ip=${TARGET_IP},gw=${TARGET_GW},type=veth
pct set ${TARGET_VMID} -onboot 0
pct stop ${TARGET_VMID} 2>/dev/null || true
echo "CT${TARGET_VMID} restored, stopped, onboot=0"
REMOTE
}

if [[ "${DUMP_ONLY}" == "1" ]]; then
    _dump
    exit 0
fi

if [[ "${RESTORE_ONLY}" == "1" ]]; then
    [[ -n "${DUMP_PATH:-}" ]] || { echo "Definir DUMP_PATH"; exit 1; }
    _restore "${DUMP_PATH}"
    exit 0
fi

log "Pipeline: dump AGLSRV1 → scp → restore FGSRV7"
LATEST=$(ssh -o BatchMode=yes "${AGLSRV1}" "ls -t ${DUMP_DIR}/vzdump-lxc-${SOURCE_VMID}-*.tar.zst 2>/dev/null | head -1; ls -t ${DUMP_DIR}/vzdump-lxc-${SOURCE_VMID}-*.vma.zst 2>/dev/null | head -1" | head -1)
if [[ -z "${LATEST}" ]]; then
    _dump
    LATEST=$(ssh -o BatchMode=yes "${AGLSRV1}" "ls -t ${DUMP_DIR}/vzdump-lxc-${SOURCE_VMID}-*.tar.zst 2>/dev/null | head -1; ls -t ${DUMP_DIR}/vzdump-lxc-${SOURCE_VMID}-*.vma.zst 2>/dev/null | head -1" | head -1)
fi
REMOTE_NAME="litellm7-$(basename "${LATEST}")"
log "Transfer ${LATEST} → FGSRV7:${DUMP_DIR}/"
ssh -o BatchMode=yes "${FGSRV7}" "mkdir -p ${DUMP_DIR}"
ssh -o BatchMode=yes "${AGLSRV1}" "cat '${LATEST}'" | ssh -o BatchMode=yes "${FGSRV7}" "cat > ${DUMP_DIR}/${REMOTE_NAME}"
_restore "${DUMP_DIR}/${REMOTE_NAME}"
