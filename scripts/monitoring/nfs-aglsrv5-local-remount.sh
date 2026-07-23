#!/bin/bash
# Remount leve de NFS no CT538 — executar no host Proxmox AGLSRV5 (tem pct).
# Objetivo: quando FGSRV4 volta após queda, remontar sem depender do monitor remoto.
#
# Uso: ./nfs-aglsrv5-local-remount.sh [--force-umount]
# Systemd: ver config/systemd/agl-nfs-aglsrv5-local.*

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="${NFS_MONITOR_LOG_DIR:-${SCRIPT_DIR}/../../logs/nfs-monitor}"
LOG_FILE="${LOG_DIR}/aglsrv5-local-$(date +%Y%m%d).log"
CT_ID="${NFS_CT_ID:-138}"
FGSRV4_TS_IP="${FGSRV4_TS_IP:-100.111.79.2}"
FORCE_UMOUNT=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --force-umount)
      FORCE_UMOUNT=true
      shift
      ;;
    *)
      echo "Opção desconhecida: $1"
      exit 1
      ;;
  esac
done

log() {
  local ts
  ts=$(date '+%Y-%m-%d %H:%M:%S')
  mkdir -p "${LOG_DIR}"
  echo "[${ts}] [aglsrv5-local] $*" | tee -a "${LOG_FILE}"
}

run_ct() {
  pct exec "${CT_ID}" -- bash -c "$*" 2>&1
}

if ! command -v pct &>/dev/null; then
  log "ERRO: pct não encontrado — este script deve correr no Proxmox (AGLSRV5)."
  exit 1
fi

status=$(pct status "${CT_ID}" 2>/dev/null | awk '{print $2}' || echo "missing")
if [[ "${status}" != "running" ]]; then
  log "CT${CT_ID} não está running (status=${status}); sair."
  exit 0
fi

if ! run_ct "ping -c 1 -W 3 ${FGSRV4_TS_IP}" &>/dev/null; then
  log "FGSRV4 (${FGSRV4_TS_IP}) inalcançável a partir do CT${CT_ID}; aguardar próximo ciclo."
  exit 0
fi

MOUNT_POINTS=(
  "/mnt/fgsrv4-fg_antigo-wg"
  "/mnt/fgsrv4-fg_antigo-ts"
  "/mnt/fgsrv4-nfs-ts"
)

needs_work=false
for mp in "${MOUNT_POINTS[@]}"; do
  if ! run_ct "mountpoint -q ${mp}" &>/dev/null; then
    needs_work=true
    log "Mount em falta ou inválido: ${mp}"
  fi
done

if [[ "${needs_work}" != "true" ]]; then
  log "Todos os mounts OK."
  exit 0
fi

if [[ "${FORCE_UMOUNT}" == "true" ]]; then
  for mp in "${MOUNT_POINTS[@]}"; do
    if run_ct "mountpoint -q ${mp}" &>/dev/null; then
      log "umount forçado: ${mp}"
      run_ct "umount -f ${mp} 2>/dev/null || umount -l ${mp} 2>/dev/null || true" || true
    fi
  done
  sleep 2
fi

log "A executar mount -a no CT${CT_ID}..."
if run_ct "mount -a"; then
  log "mount -a concluído."
else
  log "AVISO: mount -a falhou (fstab ou rede); pode ser necessário nfs-tailscale-recovery.sh"
  exit 1
fi

ok=0
for mp in "${MOUNT_POINTS[@]}"; do
  if run_ct "mountpoint -q ${mp}" &>/dev/null; then
    ((ok++)) || true
    log "OK: ${mp}"
  else
    log "AINDA FALHA: ${mp}"
  fi
done

if [[ "${ok}" -eq "${#MOUNT_POINTS[@]}" ]]; then
  log "Remount completo (${ok} mounts)."
  exit 0
fi

exit 1
