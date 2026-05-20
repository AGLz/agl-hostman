#!/usr/bin/env bash
# Remove acesso à GPU GTX 1650 (05:00.x) de todos os CTs/VMs no AGLSRV1.
# Apenas VM110 (agl-ollama) deve manter hostpci0 após setup-vm110-agl-ollama.sh.
# Executar como root no AGLSRV1.
set -euo pipefail

BACKUP_DIR="${BACKUP_DIR:-/root/gpu-migration-backup-$(date +%Y%m%d-%H%M%S)}"
DRY_RUN="${DRY_RUN:-0}"
EXCLUSIVE_VMID="${EXCLUSIVE_VMID:-110}"

log() { echo "[strip-gpu] $*"; }

backup_file() {
  local f="$1"
  install -d "$BACKUP_DIR"
  cp -a "$f" "$BACKUP_DIR/"
  log "backup: $f -> $BACKUP_DIR/"
}

strip_lxc() {
  local conf="$1"
  local id
  id="$(basename "$conf" .conf)"
  if [[ "$id" == "200" ]]; then
    log "CT200: parar e desactivar onboot (descontinuado após VM110)"
    if [[ "$DRY_RUN" == "1" ]]; then
      log "[dry-run] pct stop 200; pct set 200 -onboot 0"
    else
      pct stop 200 2>/dev/null || true
      pct set 200 -onboot 0 2>/dev/null || true
    fi
  fi
  if ! grep -qE 'nvidia|195:|509:|234:|236:' "$conf" 2>/dev/null; then
    return 0
  fi
  backup_file "$conf"
  log "CT$id: remover linhas GPU"
  if [[ "$DRY_RUN" == "1" ]]; then
    grep -E 'nvidia|195:|509:|234:|236:' "$conf" || true
    return 0
  fi
  sed -i \
    -e '/lxc\.cgroup2\.devices\.allow: c 195:\*/d' \
    -e '/lxc\.cgroup2\.devices\.allow: c 234:\*/d' \
    -e '/lxc\.cgroup2\.devices\.allow: c 236:\*/d' \
    -e '/lxc\.cgroup2\.devices\.allow: c 509:\*/d' \
    -e '/lxc\.mount\.entry:.*nvidia/d' \
    -e '/lxc\.mount\.entry:.*\/dev\/dri/d' \
    -e '/^dev[0-9]*:.*nvidia/d' \
    "$conf"
}

strip_qemu() {
  local conf="$1"
  local id
  id="$(basename "$conf" .conf)"
  if [[ "$id" == "$EXCLUSIVE_VMID" ]]; then
    return 0
  fi
  if ! grep -qE 'hostpci.*05:00|hostpci0: 05:00' "$conf" 2>/dev/null; then
    return 0
  fi
  backup_file "$conf"
  log "VM$id: remover hostpci GTX 1650"
  if [[ "$DRY_RUN" == "1" ]]; then
    grep hostpci "$conf" || true
    return 0
  fi
  sed -i \
    -e '/^hostpci[0-9]*: 05:00/d' \
    "$conf"
}

main() {
  if [[ "${EUID:-0}" -ne 0 ]]; then
    echo "ERRO: executar como root no AGLSRV1." >&2
    exit 1
  fi
  install -d "$BACKUP_DIR"
  log "Backup em $BACKUP_DIR (DRY_RUN=$DRY_RUN)"

  for conf in /etc/pve/lxc/*.conf; do
    [[ -f "$conf" ]] || continue
    strip_lxc "$conf"
  done

  for conf in /etc/pve/qemu-server/*.conf; do
    [[ -f "$conf" ]] || continue
    strip_qemu "$conf"
  done

  log "Concluído. Validar: grep -r '05:00\\|nvidia' /etc/pve/lxc /etc/pve/qemu-server | grep -v ${EXCLUSIVE_VMID}.conf || true"
}

main "$@"
