#!/usr/bin/env bash
# Renumeração in-place AGLSRV6 (600–699) — sem vzdump/clone (rpool quase cheio).
# Executar no host: bash pct-renumber-inplace-aglsrv6.sh [--dry-run]
set -euo pipefail

DRY_RUN=false
[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=true

log() { echo "[$(date +%H:%M:%S)] $*"; }

rename_ct_subvol() {
  local old=$1 new=$2
  local vol="subvol-${old}-disk-0"
  if ! pct config "${old}" &>/dev/null; then
    log "SKIP CT${old}: não existe"
    return 0
  fi
  if pct config "${new}" &>/dev/null; then
    log "SKIP CT${old}: CT${new} já existe"
    return 0
  fi
  log "PLAN CT${old} → CT${new} (zfs ${vol})"
  $DRY_RUN && return 0
  local was_running=false
  pct status "${old}" 2>/dev/null | grep -q running && was_running=true
  pct stop "${old}" 2>/dev/null || true
  sleep 2
  if zfs list "rpool/${vol}" &>/dev/null; then
    zfs rename "rpool/${vol}" "rpool/subvol-${new}-disk-0"
  fi
  # CT110 usa subvol-110-disk-1
  if zfs list "rpool/subvol-${old}-disk-1" &>/dev/null; then
    zfs rename "rpool/subvol-${old}-disk-1" "rpool/subvol-${new}-disk-1"
  fi
  mv "/etc/pve/lxc/${old}.conf" "/etc/pve/lxc/${new}.conf"
  sed -i "s/subvol-${old}-/subvol-${new}-/g; s/:${old}\//:${new}\//g" "/etc/pve/lxc/${new}.conf"
  [[ -d /var/lib/lxc/${old} ]] && mv "/var/lib/lxc/${old}" "/var/lib/lxc/${new}" || true
  $was_running && pct start "${new}"
  log "OK CT${old} → CT${new}"
}

rename_ct_lvm() {
  local old=$1 new=$2
  if ! pct config "${old}" &>/dev/null; then
    log "SKIP CT${old}: não existe"
    return 0
  fi
  if pct config "${new}" &>/dev/null; then
    log "SKIP CT${old}: CT${new} já existe"
    return 0
  fi
  log "PLAN CT${old} → CT${new} (lvm)"
  $DRY_RUN && return 0
  local was_running=false
  pct status "${old}" 2>/dev/null | grep -q running && was_running=true
  pct stop "${old}" 2>/dev/null || true
  sleep 2
  lvrename pve "vm-${old}-disk-0" "vm-${new}-disk-0" 2>/dev/null || true
  mv "/etc/pve/lxc/${old}.conf" "/etc/pve/lxc/${new}.conf"
  sed -i "s/vm-${old}-disk-0/vm-${new}-disk-0/g" "/etc/pve/lxc/${new}.conf"
  [[ -d /var/lib/lxc/${old} ]] && mv "/var/lib/lxc/${old}" "/var/lib/lxc/${new}" || true
  $was_running && pct start "${new}"
  log "OK CT${old} → CT${new}"
}

rename_vm_rpool() {
  local old=$1 new=$2
  if ! qm config "${old}" &>/dev/null; then
    log "SKIP VM${old}: não existe"
    return 0
  fi
  if qm config "${new}" &>/dev/null; then
    log "SKIP VM${old}: VM${new} já existe"
    return 0
  fi
  log "PLAN VM${old} → VM${new} (rpool zvols)"
  $DRY_RUN && return 0
  local was_running=false
  qm status "${old}" 2>/dev/null | grep -q running && was_running=true
  qm stop "${old}" 2>/dev/null || true
  sleep 3
  while read -r zvol; do
    [[ -z "${zvol}" ]] && continue
    local base newname
    base="$(basename "${zvol}")"
    newname="${base/vm-${old}-/vm-${new}-}"
    zfs rename "rpool/${base}" "rpool/${newname}" 2>/dev/null || true
  done < <(zfs list -H -o name rpool | grep "vm-${old}-disk" || true)
  mv "/etc/pve/qemu-server/${old}.conf" "/etc/pve/qemu-server/${new}.conf"
  sed -i "s/vm-${old}-/vm-${new}-/g" "/etc/pve/qemu-server/${new}.conf"
  $was_running && qm start "${new}"
  log "OK VM${old} → VM${new}"
}

log "=== AGLSRV6 in-place renumber ($($DRY_RUN && echo DRY-RUN || echo APPLY)) ==="

# CT107 partilha subvol-113-disk-0 com PBS — corrigir manualmente; não migrar
log "SKIP CT107 (kuber601): rootfs=subvol-113-disk-0 conflita com PBS CT113"

# LXC local-lvm (pequenos)
rename_ct_lvm 116 616
rename_ct_lvm 117 617
rename_ct_lvm 201 622

# LXC rpool (sem bind mp — bind mp mantém paths)
rename_ct_subvol 101 601
rename_ct_subvol 102 602
rename_ct_subvol 108 608
rename_ct_subvol 109 609
rename_ct_subvol 110 610
rename_ct_subvol 114 614
rename_ct_subvol 121 621

# LXC com bind mounts (rename subvol only)
rename_ct_subvol 104 604
rename_ct_subvol 111 611

# PBS por último
rename_ct_subvol 113 613

# VMs (rpool / passthrough OK — só renomeia zvols+config)
rename_vm_rpool 103 603
rename_vm_rpool 106 606
rename_vm_rpool 112 612
rename_vm_rpool 200 620
rename_vm_rpool 100 600
rename_vm_rpool 105 605

log "=== Concluído ==="
pct list 2>/dev/null || true
qm list 2>/dev/null || true
