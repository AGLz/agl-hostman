#!/bin/bash
# Hook Proxmox VM110 — prepara GTX 1650 (05:00) antes do passthrough.
# Instalar: /var/lib/vz/snippets/vm110-gpu-hook.sh
# qm set 110 --hookscript local:snippets/vm110-gpu-hook.sh
set -euo pipefail

GPU_VGA="0000:05:00.0"
GPU_AUD="0000:05:00.1"
PCIE_SLOT="05:00"

log() {
  logger -t vm110-gpu-hook "$*"
  echo "[vm110-gpu-hook] $*"
}

unbind_dev() {
  local d="$1"
  [[ -e "/sys/bus/pci/devices/$d/driver/unbind" ]] || return 0
  echo "$d" > "/sys/bus/pci/devices/$d/driver/unbind" 2>/dev/null || true
}

bind_vfio() {
  modprobe vfio-pci disable_vga=1 2>/dev/null || modprobe vfio-pci
  for d in "$GPU_VGA" "$GPU_AUD"; do
    [[ -e "/sys/bus/pci/devices/$d" ]] || continue
    echo on > "/sys/bus/pci/devices/$d/power/control" 2>/dev/null || true
    unbind_dev "$d"
  done
  sleep 1
  for d in "$GPU_VGA" "$GPU_AUD"; do
    [[ -e "/sys/bus/pci/devices/$d" ]] || continue
    echo "$d" > /sys/bus/pci/drivers/vfio-pci/bind 2>/dev/null || true
  done
}

reenumerate_gpu() {
  # Reason: após qm stop a GTX 1650 fica em estado inválido (pci_irq_handler no 2.º start).
  for d in "$GPU_AUD" "$GPU_VGA"; do
    [[ -e "/sys/bus/pci/devices/$d/remove" ]] && echo 1 > "/sys/bus/pci/devices/$d/remove" 2>/dev/null || true
  done
  sleep 2
  [[ -e /sys/bus/pci/rescan ]] && echo 1 > /sys/bus/pci/rescan
  sleep 4
  for _ in $(seq 1 20); do
    lspci -s "${PCIE_SLOT}.0" >/dev/null 2>&1 && return 0
    sleep 1
  done
  log "AVISO: GPU não reenumerou — pode ser necessário reboot do host"
  return 1
}

case "${1:-}" in
  pre-start)
    if [[ -w "/sys/bus/pci/devices/$GPU_VGA/reset_method" ]]; then
      echo device_specific > "/sys/bus/pci/devices/$GPU_VGA/reset_method" 2>/dev/null || true
    fi
    if ! lspci -k -s 05:00.0 2>/dev/null | grep -q vfio-pci; then
      bind_vfio
    fi
    ;;
  post-stop)
    log "post-stop: libertar GPU"
    unbind_dev "$GPU_VGA"
    unbind_dev "$GPU_AUD"
    sleep 2
    reenumerate_gpu || true
    bind_vfio
    ;;
esac

exit 0
