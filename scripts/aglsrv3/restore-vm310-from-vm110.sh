#!/usr/bin/env bash
# Restaura VM310 (agl-ollama) no AGLSRV3 a partir de backup da VM110 (AGLSRV1).
# Executar APÓS: PVE 9 + pool aglsrv3-tb recriado (ou usar local-lvm).
#
# Uso (no AGLSRV3, root):
#   bash restore-vm310-from-vm110.sh --dump-only    # só gera backup no AGLSRV1
#   bash restore-vm310-from-vm110.sh --restore      # transfer + qmrestore + ajustes
#   bash restore-vm310-from-vm110.sh --full         # dump + restore
#
# Pós-restore (manual):
#   - Tailscale na guest: tailscale up
#   - Modelos: ollama pull qwen3:8b (etc.)
#   - NAT/host: scripts/aglsrv3/ollama-tailscale-nat.sh (se necessário)
set -euo pipefail

SRC_VMID=110
DST_VMID=310
SRC_HOST="${SRC_HOST:-root@100.107.113.33}"
STORAGE="${STORAGE:-local-lvm}"
DUMP_DIR="${DUMP_DIR:-/var/lib/vz/dump}"
DUMP_GLOB="vzdump-qemu-${SRC_VMID}-*.vma.zst"

# Rede AGLSRV3 (AGLFG)
IP="${IP:-192.168.15.210/24}"
GW="${GW:-192.168.15.1}"
DNS="${DNS:-192.168.15.102}"
MAC="${MAC:-BC:24:11:BA:73:10}"
GPU_MAP="${GPU_MAP:-RX580}"
GPU_MAP2="${GPU_MAP2:-RX580_2}"

log() { echo "[restore-vm310] $*" >&2; }

dump_on_aglsrv1() {
  log "vzdump VM${SRC_VMID} no AGLSRV1 (${SRC_HOST})..."
  # Reason: vzdump com GPU passthrough falha ao arrancar KVM se o PCI não está presente no host.
  ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new "${SRC_HOST}" \
    "qm set ${SRC_VMID} --delete hostpci0 2>/dev/null || true; \
     vzdump ${SRC_VMID} --mode stop --compress zstd --storage local --notes-template 'template-vm310-aglsrv3'"
  local remote_dump
  remote_dump="$(ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new "${SRC_HOST}" \
    "ls -t ${DUMP_DIR}/${DUMP_GLOB} 2>/dev/null | head -1")"
  [[ -n "${remote_dump}" ]] || { log "ERRO: backup não encontrado no AGLSRV1"; exit 1; }
  echo "${remote_dump}"
}

transfer_dump() {
  local remote_path="$1"
  local base
  base="$(basename "${remote_path}")"
  log "Transferir ${base} → AGLSRV3 ${DUMP_DIR}/"
  mkdir -p "${DUMP_DIR}"
  scp -o BatchMode=yes -o StrictHostKeyChecking=accept-new "${SRC_HOST}:${remote_path}" "${DUMP_DIR}/${base}"
  echo "${DUMP_DIR}/${base}"
}

purge_dst_if_needed() {
  if qm status "${DST_VMID}" &>/dev/null; then
    log "Remover VM${DST_VMID} órfã (config sem disco válido)..."
    qm stop "${DST_VMID}" 2>/dev/null || true
    qm destroy "${DST_VMID}" --purge 1
  fi
}

restore_and_tune() {
  local dump_file="$1"
  purge_dst_if_needed

  log "qmrestore ${dump_file} → VM${DST_VMID} storage=${STORAGE}"
  qmrestore "${dump_file}" "${DST_VMID}" --storage "${STORAGE}" --force

  log "Ajustes AGLSRV3 (2× GPU RX580, rede AGLFG, sem hook VM110)..."
  qm set "${DST_VMID}" \
    --name agl-ollama \
    --delete hookscript \
    --delete numa0 \
    --delete affinity \
    --delete unused0 \
    --delete unused1 \
    --hostpci0 "mapping=${GPU_MAP},pcie=1,rombar=0" \
    --hostpci1 "mapping=${GPU_MAP2},pcie=1,rombar=0" \
    --net0 "virtio,bridge=vmbr0,macaddr=${MAC}" \
    --ipconfig0 "ip=${IP},gw=${GW}" \
    --nameserver "${DNS}" \
    --searchdomain aglz.io \
    --onboot 1 \
    --startup order=2 \
    --description "Ollama GPU RX580 — restaurado de VM110 AGLSRV1 $(date +%F)"

  # Guest AMD: override Ollama (HSA Polaris)
  log "Config VM${DST_VMID}:"
  qm config "${DST_VMID}"

  cat <<EOF

=== VM${DST_VMID} restaurada ===
Próximos passos na guest (${IP%/*}):
  1. tailscale up   # novo nó (hostname aglsrv3-ollama)
  2. ollama pull qwen3:8b   # e demais modelos
  3. ollama ps      # confirmar 100% GPU (RX580)

Opcional no host:
  bash scripts/aglsrv3/install-vm310-ollama-guest.sh   # se ROCm/firmware em falta
  bash scripts/aglsrv3/ollama-tailscale-nat.sh         # só se API via host TS

EOF
}

cmd_dump_only() {
  dump_on_aglsrv1 >/dev/null
  log "Backup criado no AGLSRV1 em ${DUMP_DIR}/"
}

cmd_restore() {
  local remote dump local_dump
  remote="$(ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new "${SRC_HOST}" \
    "ls -t ${DUMP_DIR}/${DUMP_GLOB} 2>/dev/null | head -1")"
  if [[ -z "${remote}" ]]; then
    log "Sem backup local; a criar vzdump no AGLSRV1..."
    remote="$(dump_on_aglsrv1)"
  fi
  local_dump="$(transfer_dump "${remote}")"
  restore_and_tune "${local_dump}"
}

main() {
  [[ "${EUID:-0}" -eq 0 ]] || { echo "Executar como root no AGLSRV3." >&2; exit 1; }

  case "${1:-}" in
    --dump-only) cmd_dump_only ;;
    --restore)   cmd_restore ;;
    --full)
      remote="$(dump_on_aglsrv1)"
      local_dump="$(transfer_dump "${remote}")"
      restore_and_tune "${local_dump}"
      ;;
    *)
      echo "Uso: $0 --dump-only | --restore | --full" >&2
      exit 1
      ;;
  esac
}

main "$@"
