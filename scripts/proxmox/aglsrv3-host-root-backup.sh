#!/usr/bin/env bash
# Backup do disco principal Proxmox (pve-root / Samsung SSD) no AGLSRV3.
# Tier 1 (daily): config crítica + manifest → aglsrv3-tb/backups/host-root
# Tier 2 (weekly): snapshot LVM + dump comprimido do volume root (opcional)
# Tier 3 (daily, se PBS activo): pxar das mesmas paths → datastore aglsrv3-tb
#
# Uso (no host aglsrv3 como root):
#   aglsrv3-host-root-backup.sh daily          # config + manifest + PBS pxar
#   aglsrv3-host-root-backup.sh weekly         # dump LVM pve/root
#   aglsrv3-host-root-backup.sh all             # daily + weekly
#   aglsrv3-host-root-backup.sh daily --dry-run
#
# Instalação cron (via deploy ou manual):
#   30 3 * * * root /usr/local/sbin/aglsrv3-host-root-backup.sh daily
#   0  3 * * 0 root /usr/local/sbin/aglsrv3-host-root-backup.sh weekly

set -euo pipefail

SCRIPT_NAME="$(basename "$0")"
MODE="${1:-daily}"
DRY_RUN=false
PREPARE_LV=false

for arg in "$@"; do
  case "${arg}" in
    --dry-run) DRY_RUN=true ;;
    --prepare-lv) PREPARE_LV=true ;;
  esac
done

# shellcheck disable=SC1091
[[ -f /etc/aglsrv3/host-backup.env ]] && source /etc/aglsrv3/host-backup.env

BACKUP_ROOT="${AGLSRV3_HOST_BACKUP_ROOT:-/aglsrv3-tb/backups/host-root}"
CONFIG_DIR="${BACKUP_ROOT}/config"
EFI_DIR="${BACKUP_ROOT}/efi"
LV_DIR="${BACKUP_ROOT}/lv"
MANIFEST_DIR="${BACKUP_ROOT}/manifests"
LOG="${AGLSRV3_HOST_BACKUP_LOG:-/var/log/aglsrv3-host-root-backup.log}"
HOST="$(hostname -s)"
TS="$(date +%Y%m%d-%H%M%S)"
PBS_VMID="${AGLSRV3_PBS_VMID:-318}"
PBS_IP="${AGLSRV3_PBS_IP:-192.168.15.118}"
PBS_IP="${PBS_IP%%/*}"
PBS_DATASTORE="${AGLSRV3_PBS_HOST_DATASTORE:-aglsrv3-tb}"
PBS_USER="${PBS_USER:-root@pam}"
STALE_SNAP="${AGLSRV3_STALE_ROOT_SNAP:-root-snap-pre-pve9}"
LV_SNAP="${AGLSRV3_LV_BACKUP_SNAP:-root-backup-snap}"
LV_COW_SIZE="${AGLSRV3_LV_COW_SIZE:-10G}"
RETAIN_CONFIG_DAYS="${AGLSRV3_HOST_CONFIG_RETAIN_DAYS:-14}"
RETAIN_LV_WEEKS="${AGLSRV3_HOST_LV_RETAIN_WEEKS:-8}"

log() {
  echo "[$(date -Iseconds)] $*" | tee -a "${LOG}"
}

die() {
  log "ERRO: $*"
  exit 1
}

require_root() {
  [[ "${EUID}" -eq 0 ]] || die "Executar como root no host Proxmox"
}

ensure_dirs() {
  mkdir -p "${CONFIG_DIR}" "${EFI_DIR}" "${LV_DIR}" "${MANIFEST_DIR}"
  zfs list "${BACKUP_ROOT#/}" >/dev/null 2>&1 || mkdir -p "${BACKUP_ROOT}"
}

write_manifest() {
  local out="${MANIFEST_DIR}/${HOST}-manifest-${TS}.txt"
  if [[ "${DRY_RUN}" == true ]]; then
    log "DRY-RUN: manifest → ${out}"
    return 0
  fi
  {
    echo "=== ${HOST} manifest ${TS} ==="
    date -Is
    echo "--- pveversion ---"
    pveversion -v 2>/dev/null || true
    echo "--- uname ---"
    uname -a
    echo "--- qm list ---"
    qm list 2>/dev/null || true
    echo "--- pct list ---"
    pct list 2>/dev/null || true
    echo "--- pvesm status ---"
    pvesm status 2>/dev/null || true
    echo "--- lvs ---"
    lvs -o lv_name,vg_name,lv_size,data_percent 2>/dev/null || true
    echo "--- vgs ---"
    vgs 2>/dev/null || true
    echo "--- df ---"
    df -hT 2>/dev/null || true
    echo "--- zpool ---"
    zpool status aglsrv3-tb 2>/dev/null || true
    echo "--- efibootmgr ---"
    efibootmgr 2>/dev/null || true
  } > "${out}"
  log "Manifest: ${out}"
}

backup_config() {
  local archive="${CONFIG_DIR}/${HOST}-config-${TS}.tar.zst"
  local paths=(
    /etc/pve
    /etc/network
    /etc/fstab
    /etc/crypttab
    /etc/default/grub
    /etc/hostname
    /etc/hosts
    /etc/modprobe.d
    /etc/sysctl.d
    /etc/modules-load.d
    /etc/pve-backup
    /etc/vzdump.conf
    /etc/cron.d
  )

  if [[ "${DRY_RUN}" == true ]]; then
    log "DRY-RUN: config tar → ${archive} (${#paths[@]} paths)"
    return 0
  fi

  local existing=()
  local p
  for p in "${paths[@]}"; do
    [[ -e "${p}" ]] && existing+=("${p}")
  done

  tar --xattrs --acls --one-file-system -cpf - "${existing[@]}" 2>/dev/null \
    | zstd -T0 -7 -o "${archive}"
  log "Config backup: ${archive} ($(du -h "${archive}" | awk '{print $1}'))"
}

backup_efi() {
  [[ -d /boot/efi ]] || return 0
  local archive="${EFI_DIR}/${HOST}-efi-${TS}.tar.zst"
  if [[ "${DRY_RUN}" == true ]]; then
    log "DRY-RUN: EFI tar → ${archive}"
    return 0
  fi
  tar --xattrs --acls -cpf - /boot/efi 2>/dev/null | zstd -T0 -7 -o "${archive}"
  log "EFI backup: ${archive} ($(du -h "${archive}" | awk '{print $1}'))"
}

ensure_pbs_running() {
  if ! pct status "${PBS_VMID}" 2>/dev/null | grep -q running; then
    log "A arrancar CT${PBS_VMID} (PBS) para sync pxar..."
    pct unlock "${PBS_VMID}" 2>/dev/null || true
    pct start "${PBS_VMID}"
    sleep 8
  fi
}

sync_to_pbs() {
  if [[ ! -x /usr/bin/proxmox-backup-client ]]; then
    log "AVISO: proxmox-backup-client ausente — saltar PBS pxar"
    return 0
  fi
  if [[ ! -f /root/.pbs-link-password ]]; then
    log "AVISO: /root/.pbs-link-password ausente — saltar PBS pxar"
    return 0
  fi

  if [[ "${DRY_RUN}" == true ]]; then
    log "DRY-RUN: proxmox-backup-client pxar → ${PBS_USER}@${PBS_IP}:${PBS_DATASTORE}"
    return 0
  fi

  ensure_pbs_running

  # shellcheck disable=SC2155
  export PBS_PASSWORD="$(cat /root/.pbs-link-password)"
  local fp
  fp="$(awk -v ds="${PBS_DATASTORE}" '
    /^pbs:/ { in_block=0 }
    /^[[:space:]]+datastore / && $2 == ds { in_block=1 }
    in_block && /^[[:space:]]+fingerprint / {
      gsub(/^[[:space:]]+fingerprint /, "")
      print
      exit
    }
  ' /etc/pve/storage.cfg 2>/dev/null || true)"
  if [[ -n "${fp}" ]]; then
    export PBS_FINGERPRINT="${fp}"
  fi

  local repo="${PBS_USER}@${PBS_IP}:${PBS_DATASTORE}"
  local backup_id="${HOST}-host"

  proxmox-backup-client backup \
    pve.pxar:/etc/pve \
    network.pxar:/etc/network \
    modprobe.pxar:/etc/modprobe.d \
    sysctl.pxar:/etc/sysctl.d \
    fstab.conf:/etc/fstab \
    grub.conf:/etc/default/grub \
    hostname.conf:/etc/hostname \
    hosts.conf:/etc/hosts \
    --repository "${repo}" \
    --backup-id "${backup_id}" \
    --backup-type host \
    >> "${LOG}" 2>&1 && log "PBS pxar OK: ${repo} backup-id=${backup_id}" \
    || log "AVISO: PBS pxar falhou (ver ${LOG})"
}

prepare_lv_snapshot_space() {
  if lvs "pve/${STALE_SNAP}" &>/dev/null; then
    if [[ "${PREPARE_LV}" != true ]]; then
      log "AVISO: snapshot obsoleto pve/${STALE_SNAP} ocupa COW — usar --prepare-lv para remover antes do dump semanal"
      return 1
    fi
    log "Remover snapshot obsoleto pve/${STALE_SNAP} (--prepare-lv)"
    lvremove -f "pve/${STALE_SNAP}"
  fi
  return 0
}

backup_root_lv() {
  local archive="${LV_DIR}/${HOST}-pve-root-${TS}.img.zst"
  local snap="/dev/pve/${LV_SNAP}"

  if [[ "${DRY_RUN}" == true ]]; then
    log "DRY-RUN: LVM snapshot dump → ${archive}"
    return 0
  fi

  if ! prepare_lv_snapshot_space; then
    log "Saltar dump LVM (espaço/snapshot obsoleto)"
    return 0
  fi

  local vfree
  vfree="$(vgs --noheadings -o vg_free --units g --nosuffix pve 2>/dev/null | tr -d ' ' | cut -d. -f1)"
  if [[ -z "${vfree}" || "${vfree}" -lt 10 ]]; then
    log "AVISO: VFree pve < 10G (${vfree:-?}G) — saltar dump LVM"
    return 0
  fi

  if lvs "pve/${LV_SNAP}" &>/dev/null; then
    lvremove -f "pve/${LV_SNAP}"
  fi

  log "Criar snapshot pve/${LV_SNAP} (COW ${LV_COW_SIZE})..."
  lvcreate -s -L "${LV_COW_SIZE}" -n "${LV_SNAP}" pve/root

  log "Dump LVM → ${archive} (pode demorar vários minutos)..."
  dd if="${snap}" bs=4M status=progress iflag=fullblock 2>>"${LOG}" \
    | zstd -T0 -3 -o "${archive}"
  lvremove -f "pve/${LV_SNAP}"

  log "LV backup: ${archive} ($(du -h "${archive}" | awk '{print $1}'))"
}

prune_local() {
  if [[ "${DRY_RUN}" == true ]]; then
    log "DRY-RUN: prune config>${RETAIN_CONFIG_DAYS}d lv>${RETAIN_LV_WEEKS} semanas"
    return 0
  fi
  find "${CONFIG_DIR}" -name "${HOST}-config-*.tar.zst" -mtime +"${RETAIN_CONFIG_DAYS}" -delete 2>/dev/null || true
  find "${EFI_DIR}" -name "${HOST}-efi-*.tar.zst" -mtime +"${RETAIN_CONFIG_DAYS}" -delete 2>/dev/null || true
  find "${MANIFEST_DIR}" -name "${HOST}-manifest-*.txt" -mtime +"${RETAIN_CONFIG_DAYS}" -delete 2>/dev/null || true
  find "${LV_DIR}" -name "${HOST}-pve-root-*.img.zst" -mtime +$((RETAIN_LV_WEEKS * 7)) -delete 2>/dev/null || true
  log "Prune local concluído (config ${RETAIN_CONFIG_DAYS}d, lv ${RETAIN_LV_WEEKS}w)"
}

run_daily() {
  write_manifest
  backup_config
  backup_efi
  sync_to_pbs
  prune_local
}

run_weekly() {
  backup_root_lv
  prune_local
}

main() {
  require_root
  ensure_dirs
  log "=== ${SCRIPT_NAME} mode=${MODE} dry_run=${DRY_RUN} ==="

  case "${MODE}" in
    daily) run_daily ;;
    weekly) run_weekly ;;
    all)
      run_daily
      run_weekly
      ;;
    *)
      die "Modo inválido: ${MODE} (daily|weekly|all)"
      ;;
  esac

  log "=== Concluído ==="
}

main "$@"
