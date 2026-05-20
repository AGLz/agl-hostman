#!/usr/bin/env bash
# Prepara AGLSRV1 para passthrough exclusivo da GTX 1650 (05:00.0 + 05:00.1) → VM110.
# Executar como root no AGLSRV1. Pode exigir reboot se o driver nvidia não descarregar.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VFIO_IDS="10de:1f82,10de:10fa"

log() { echo "[enable-vfio] $*"; }

disable_vfio_pci_blacklist() {
  local bad=/etc/modprobe.d/blacklist-vfio-gpu.conf
  if [[ -f "$bad" ]] && grep -q '^blacklist vfio-pci' "$bad"; then
    mv "$bad" "${bad}.disabled-$(date +%Y%m%d%H%M%S)"
    log "Desactivado ${bad}"
  fi
}

write_vfio_modprobe() {
  install -d /etc/modprobe.d
  install -m 0644 "${SCRIPT_DIR}/vfio-gpu.conf" /etc/modprobe.d/vfio-gpu.conf
  log "Instalado /etc/modprobe.d/vfio-gpu.conf (disable_vga=1)"
}

disable_legacy_vfio_disabled() {
  if [[ -f /etc/modprobe.d/vfio.conf.disabled ]]; then
    mv /etc/modprobe.d/vfio.conf.disabled /etc/modprobe.d/vfio.conf.disabled.bak-"$(date +%Y%m%d)" 2>/dev/null || true
  fi
}

try_bind_vfio_now() {
  modprobe vfio-pci || true
  if lspci -k -s 05:00.0 2>/dev/null | grep -q vfio-pci; then
    log "GPU já em vfio-pci"
    return 0
  fi
  log "Tentar descarregar nvidia no host..."
  systemctl stop nvidia-persistenced 2>/dev/null || true
  modprobe -r nvidia_drm 2>/dev/null || true
  modprobe -r nvidia_modeset 2>/dev/null || true
  modprobe -r nvidia_uvm 2>/dev/null || true
  modprobe -r nvidia 2>/dev/null || true
  echo "$VFIO_IDS" | tr ',' '\n' | while read -r id; do
    echo "$id" | sed 's/:/ /' | xargs -r sh -c 'echo $1 $2 > /sys/bus/pci/drivers/vfio-pci/new_id' _ 2>/dev/null || true
  done
  if lspci -k -s 05:00.0 2>/dev/null | grep -q vfio-pci; then
    log "GPU ligada a vfio-pci (sem reboot)"
    return 0
  fi
  log "AVISO: reboot recomendado para libertar GPU ao vfio-pci"
  return 1
}

main() {
  if [[ "${EUID:-0}" -ne 0 ]]; then
    echo "ERRO: executar como root no AGLSRV1." >&2
    exit 1
  fi
  disable_vfio_pci_blacklist
  write_vfio_modprobe
  disable_legacy_vfio_disabled
  try_bind_vfio_now || {
    log "Após reboot, verificar: lspci -k -s 05:00.0 | grep vfio"
    exit 2
  }
}

main "$@"
