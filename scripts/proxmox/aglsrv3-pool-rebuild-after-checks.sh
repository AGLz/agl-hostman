#!/usr/bin/env bash
# AGLSRV3: aguarda badblocks/wipes, destrói pool, upgrade PVE 8→9, recria raidz1 5×1TB.
# Executar NO host (root). Log: /var/log/aglsrv3-pool-rebuild.log
#
# Uso:
#   aglsrv3-pool-rebuild-after-checks.sh              # daemon (espera pré-requisitos)
#   aglsrv3-pool-rebuild-after-checks.sh --status     # estado actual
#   aglsrv3-pool-rebuild-after-checks.sh --phase post-reboot  # após reboot (systemd)

set -euo pipefail

STATE_DIR="/var/lib/aglsrv3-pool-rebuild"
STATE_FILE="${STATE_DIR}/state"
LOG="/var/log/aglsrv3-pool-rebuild.log"
POOL_NAME="aglsrv3-tb"
CT_VMIDS=(304 306 317 318 338)
# VM agl-ollama — único guest no pool além dos CTs; migrar para local-lvm antes do destroy
VM310_VMID=310
VM310_TARGET_STORAGE="local-lvm"

# 5×1TB — by-id (ordem estável)
POOL_DISKS=(
  /dev/disk/by-id/ata-WDC_WD10SPZX-75Z10T1_WX91A48LL4CN
  /dev/disk/by-id/ata-ST1000LM024_HN-M101MBB_S33JJ5CG901030
  /dev/disk/by-id/ata-TOSHIBA_MQ01ABD100_X6KLT31BT
  /dev/disk/by-id/ata-TOSHIBA_MQ01ABD100_X6KLT319T
  /dev/disk/by-id/ata-TOSHIBA_MQ01ABD100_X6KLT31FT
)

log() {
  echo "[$(date -Iseconds)] $*" | tee -a "${LOG}"
}

set_state() {
  mkdir -p "${STATE_DIR}"
  echo "$1" > "${STATE_FILE}"
  log "STATE -> $1"
}

current_state() {
  [[ -f "${STATE_FILE}" ]] && cat "${STATE_FILE}" || echo "idle"
}

badblocks_done() {
  local dev="$1"
  local logfile="/tmp/badblocks-${dev}.log"
  if pgrep -f "badblocks -sv /dev/${dev}" >/dev/null 2>&1; then
    return 1
  fi
  [[ -f "${logfile}" ]] || return 1
  if grep -qE '[1-9][0-9]*/[1-9][0-9]*/[1-9][0-9]* errors' "${logfile}"; then
    log "ERRO: badblocks ${dev} reportou blocos danificados"
    return 2
  fi
  return 0
}

disk_wiped() {
  local byid="$1"
  wipefs --all --noheadings "${byid}" 2>/dev/null | grep -q . && return 1
  return 0
}

wait_prerequisites() {
  log "A aguardar badblocks sdj (6WS2Q6QR) e sdh (W8E0CAKW)..."
  while true; do
    local sdj_ok=0 sdh_ok=0
    badblocks_done sdj && sdj_ok=1 || true
    badblocks_done sdh && sdh_ok=1 || true
    if [[ ${sdj_ok} -eq 1 && ${sdh_ok} -eq 1 ]]; then
      log "badblocks sdj+sdh concluídos sem erros"
      break
    fi
    sleep 120
  done

  log "A aguardar wipe automático de sdh..."
  while pgrep -f "badblocks -sv /dev/sdh" >/dev/null 2>&1; do
    sleep 60
  done
  # watcher wipe-sdh corre em paralelo; esperar até sdh limpo ou timeout generoso
  local tries=0
  while ! disk_wiped /dev/disk/by-id/ata-APPLE_HDD_ST2000DM001_W8E0CAKW; do
    tries=$((tries + 1))
    if [[ ${tries} -gt 180 ]]; then
      log "AVISO: sdh ainda não limpo após 3h; continuar na mesma"
      break
    fi
    sleep 60
  done
  log "sdh (2TB) pronto — fora do pool aglsrv3-tb"

  if ! disk_wiped /dev/disk/by-id/ata-WDC_WD20SPZX-75UA7T0_WXB1E39AE1J3; then
    log "AVISO: sdk (2TB) não parece wiped; ignorar para pool 1TB"
  else
    log "sdk (2TB) confirmado limpo"
  fi
}

migrate_vm310_to_local_lvm() {
  local vmid="${VM310_VMID}"
  local target="${VM310_TARGET_STORAGE}"
  local pool="${POOL_NAME}"

  if ! qm config "${vmid}" &>/dev/null; then
    log "VM${vmid} não existe — saltar migração de storage"
    return 0
  fi

  if ! qm config "${vmid}" | grep -q "${pool}:"; then
    log "VM${vmid} já sem discos em ${pool} — saltar migração"
    return 0
  fi

  if ! zpool list -H -o name 2>/dev/null | grep -qx "${pool}"; then
    log "Pool ${pool} inexistente — saltar migração VM${vmid} (recriar guest depois)"
    return 0
  fi

  local avail_kb
  avail_kb="$(pvesm status 2>/dev/null | awk -v s="${target}" '$1 == s {print $5}')"
  if [[ -n "${avail_kb}" && "${avail_kb}" -lt 125000000 ]]; then
    log "ERRO: ${target} com pouco espaço (~$(( avail_kb / 1024 / 1024 ))G livre); VM310 precisa ~120G"
    exit 1
  fi

  local was_running=0
  if qm status "${vmid}" 2>/dev/null | grep -q running; then
    was_running=1
    log "Parar VM${vmid} (agl-ollama) para mover discos ${pool} → ${target}"
    qm shutdown "${vmid}" --timeout 180 2>&1 | tee -a "${LOG}" || qm stop "${vmid}" 2>&1 | tee -a "${LOG}"
    sleep 5
  fi

  local disk
  for disk in scsi0 efidisk0 ide2; do
    if qm config "${vmid}" | grep -qE "^${disk}:.*${pool}:"; then
      log "qm move-disk ${vmid} ${disk} ${target} --delete 1"
      qm move-disk "${vmid}" "${disk}" "${target}" --delete 1 2>&1 | tee -a "${LOG}"
    fi
  done

  if qm config "${vmid}" | grep -q "${pool}:"; then
    log "ERRO: VM${vmid} ainda tem discos em ${pool} após move-disk"
    qm config "${vmid}" | grep -E '^(scsi0|efidisk0|ide2):' | tee -a "${LOG}"
    exit 1
  fi

  log "VM${vmid} em ${target}:"
  qm config "${vmid}" | grep -E '^(scsi0|efidisk0|ide2):' | tee -a "${LOG}"

  if [[ ${was_running} -eq 1 ]]; then
    log "Religar VM${vmid}"
    qm start "${vmid}" 2>&1 | tee -a "${LOG}" || log "AVISO: falha ao religar VM${vmid}"
  fi
}

stop_cts_and_remove_storages() {
  log "Parar CTs no pool ${POOL_NAME}: ${CT_VMIDS[*]}"
  for vmid in "${CT_VMIDS[@]}"; do
    if pct status "${vmid}" 2>/dev/null | grep -q running; then
      pct stop "${vmid}" || true
    fi
  done
  sleep 5

  log "Remover storages pvesm (pbs-* e ${POOL_NAME})"
  while read -r sid; do
    [[ -n "${sid}" ]] || continue
    pvesm remove "${sid}" 2>/dev/null || true
  done < <(pvesm status 2>/dev/null | awk '$1 ~ /^pbs-/ {print $1}')

  if pvesm status 2>/dev/null | awk 'NR>1 {print $1}' | grep -qx "${POOL_NAME}"; then
    pvesm remove "${POOL_NAME}" || true
  fi
}

destroy_pool() {
  if zpool list -H -o name 2>/dev/null | grep -qx "${POOL_NAME}"; then
    log "zpool destroy -f ${POOL_NAME}"
    zpool destroy -f "${POOL_NAME}"
  else
    log "Pool ${POOL_NAME} já inexistente"
  fi
}

upgrade_pve9() {
  if pveversion | grep -q 'pve-manager/9\.'; then
    log "Já em PVE 9 — saltar upgrade"
    return 0
  fi

  if [[ -x /usr/local/sbin/aglsrv3-pve9-preupgrade.sh ]]; then
    log "Correcções pré-upgrade PVE 9 (microcode, GRUB, repos, pve8to9)"
    /usr/local/sbin/aglsrv3-pve9-preupgrade.sh apply 2>&1 | tee -a "${LOG}" || {
      log "ERRO: preupgrade falhou — abortar upgrade"
      exit 1
    }
  fi

  log "pve8to9 --full (validação final)"
  if ! pve8to9 --full 2>&1 | tee -a "${LOG}" | grep -qE 'FAILURES: +0'; then
    log "ERRO: pve8to9 ainda reporta FAILURES — abortar upgrade"
    exit 1
  fi

  log "Actualizar repositórios Bookworm → Trixie"
  sed -i 's/bookworm/trixie/g' /etc/apt/sources.list /etc/apt/sources.list.d/*.list 2>/dev/null || true
  sed -i 's/bookworm/trixie/g' /etc/apt/sources.list.d/pve-enterprise.list 2>/dev/null || true
  sed -i 's/bookworm/trixie/g' /etc/apt/sources.list.d/ceph.list 2>/dev/null || true
  # Tailscale: actualizar suite após Trixie estável (ver docs/AGLSRV3-DISKS.md)
  if [[ -f /etc/apt/sources.list.d/tailscale.list ]]; then
    sed -i 's/bookworm/trixie/g' /etc/apt/sources.list.d/tailscale.list 2>/dev/null || true
  fi

  log "apt update && dist-upgrade (usar tmux se sessão SSH)"
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -y 2>&1 | tee -a "${LOG}"
  apt-get dist-upgrade -y -o Dpkg::Options::="--force-confold" 2>&1 | tee -a "${LOG}"

  set_state "rebooting-for-pve9"
  log "Reboot para concluir upgrade PVE 9..."
  sync
  sleep 3
  reboot
}

create_pool() {
  for d in "${POOL_DISKS[@]}"; do
    [[ -b "${d}" ]] || { log "ERRO: disco em falta ${d}"; exit 1; }
  done

  if zpool list -H -o name 2>/dev/null | grep -qx "${POOL_NAME}"; then
    log "Pool ${POOL_NAME} já existe — saltar create"
    return 0
  fi

  log "Criar ${POOL_NAME} raidz1 (5 discos) — PVE 9 / OpenZFS 2.3+"
  # Pool: raidz_expansion (6.º disco futuro), props Proxmox (lz4, xattr=sa, acltype)
  local -a zpool_create_opts=(
    -f
    -o ashift=12
    -o autotrim=off
    -o feature@raidz_expansion=enabled
    -O compression=lz4
    -O atime=off
    -O xattr=sa
    -O acltype=posixacl
    -O redundant_metadata=all
  )
  if zpool create "${zpool_create_opts[@]}" \
    "${POOL_NAME}" raidz1 "${POOL_DISKS[@]}" 2>&1 | tee -a "${LOG}"; then
    :
  else
    log "Fallback: create mínimo + upgrade feature raidz_expansion"
    zpool create -f -o ashift=12 -O compression=lz4 -O atime=off -O xattr=sa -O acltype=posixacl \
      "${POOL_NAME}" raidz1 "${POOL_DISKS[@]}"
    zpool upgrade -o feature@raidz_expansion=enabled "${POOL_NAME}" 2>/dev/null || true
  fi

  # Dataset para vzdump / ficheiros grandes (melhor ratio que lz4)
  zfs create -o compression=zstd-3 -o recordsize=1M -o atime=off \
    "${POOL_NAME}/backups" 2>/dev/null || true
  mkdir -p "/${POOL_NAME}/backups"

  if ! pvesm status 2>/dev/null | awk 'NR>1 {print $1}' | grep -qx "${POOL_NAME}"; then
    pvesm add zfspool "${POOL_NAME}" -pool "${POOL_NAME}" -content images,rootdir
  fi

  log "Pool criado:"
  zpool status "${POOL_NAME}" | tee -a "${LOG}"
  zpool get feature@raidz_expansion,feature@block_cloning,feature@longname,feature@fast_dedup \
    "${POOL_NAME}" 2>/dev/null | tee -a "${LOG}" || true
  zfs get compression,recordsize,xattr,acltype,redundant_metadata "${POOL_NAME}" "${POOL_NAME}/backups" 2>/dev/null \
    | tee -a "${LOG}" || true
}

phase_pre_reboot() {
  local st
  st="$(current_state)"
  case "${st}" in
    idle|waiting)
      set_state "waiting"
      wait_prerequisites
      set_state "migrating-vm310"
      migrate_vm310_to_local_lvm
      set_state "destroying"
      stop_cts_and_remove_storages
      destroy_pool
      set_state "upgrading"
      upgrade_pve9
      ;;
    migrating-vm310)
      log "Retomar migração VM310 (após badblocks)"
      migrate_vm310_to_local_lvm
      set_state "destroying"
      stop_cts_and_remove_storages
      destroy_pool
      set_state "upgrading"
      upgrade_pve9
      ;;
    destroying|upgrading)
      log "Retomar fase destroy/upgrade (estado=${st})"
      stop_cts_and_remove_storages
      destroy_pool
      set_state "upgrading"
      upgrade_pve9
      ;;
    rebooting-for-pve9)
      log "Ainda a aguardar reboot..."
      ;;
    *)
      log "Estado ${st}: nada a fazer em pre-reboot"
      ;;
  esac
}

phase_post_reboot() {
  local st
  st="$(current_state)"
  if [[ "${st}" != "rebooting-for-pve9" && "${st}" != "creating-pool" ]]; then
    if zpool list -H -o name 2>/dev/null | grep -qx "${POOL_NAME}"; then
      log "Pool já online — estado ${st}"
      set_state "complete"
      return 0
    fi
    if [[ "${st}" == "complete" ]]; then
      return 0
    fi
    log "post-reboot ignorado (estado=${st})"
    return 0
  fi

  set_state "creating-pool"
  log "PVE: $(pveversion | head -1)"
  log "ZFS: $(zfs --version | head -1)"

  if ! pveversion | grep -q 'pve-manager/9\.'; then
    log "AVISO: ainda não em PVE 9 após reboot"
  fi

  create_pool
  if [[ -x /usr/local/sbin/aglsrv3-pve9-preupgrade.sh ]]; then
    /usr/local/sbin/aglsrv3-pve9-preupgrade.sh --grub-fix 2>&1 | tee -a "${LOG}" || true
  fi
  set_state "complete"
  log "=== CONCLUÍDO: pool ${POOL_NAME} raidz1 5×1TB ==="
  log "Próximo: reprovisionar CTs (304,306,317,318,338) e pbs-link-host-storages.sh"
}

show_status() {
  echo "Estado: $(current_state)"
  echo "PVE: $(pveversion 2>/dev/null | head -1 || echo n/a)"
  echo "ZFS: $(zfs --version 2>/dev/null | head -1 || echo n/a)"
  for d in sdj sdh; do
    echo -n "badblocks ${d}: "
    tail -1 "/tmp/badblocks-${d}.log" 2>/dev/null | tr -d '\r' | grep -oE '[0-9.]+% done[^$]*errors' | tail -1 || echo "sem log"
  done
  zpool status "${POOL_NAME}" 2>/dev/null | head -15 || echo "pool ${POOL_NAME}: ausente"
  if qm config "${VM310_VMID}" &>/dev/null; then
    echo "VM${VM310_VMID} discos:"
    qm config "${VM310_VMID}" | grep -E '^(scsi0|efidisk0|ide2):' || true
  fi
}

main() {
  mkdir -p "${STATE_DIR}"
  touch "${LOG}"

  case "${1:-run}" in
    --status)
      show_status
      ;;
    --phase)
      case "${2:-}" in
        pre-reboot) phase_pre_reboot ;;
        post-reboot) phase_post_reboot ;;
        *) echo "Uso: --phase pre-reboot|post-reboot" >&2; exit 1 ;;
      esac
      ;;
    run|"")
      phase_pre_reboot
      ;;
    *)
      echo "Uso: $0 [--status|--phase pre-reboot|post-reboot|run]" >&2
      exit 1
      ;;
  esac
}

main "$@"
