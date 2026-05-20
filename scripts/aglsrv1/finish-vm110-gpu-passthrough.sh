#!/usr/bin/env bash
# Reanexa GPU à VM110 após reboot do AGLSRV1 (vfio-pci activo em 05:00.0 + 05:00.1).
# Alinhado tutorial Proxmox 2025: q35, OVMF, host CPU, hostpci pcie+x-vga.
# Executar como root no AGLSRV1.
set -euo pipefail

VMID="${VMID:-110}"

log() { echo "[finish-gpu] $*"; }

gpu_ready() {
  lspci -k -s 05:00.0 2>/dev/null | grep -q vfio-pci && \
    lspci -k -s 05:00.1 2>/dev/null | grep -q vfio-pci
}

main() {
  if [[ "${EUID:-0}" -ne 0 ]]; then
    echo "ERRO: root no AGLSRV1." >&2
    exit 1
  fi

  if ! lspci -nn -s 05:00.0 2>/dev/null | grep -qi nvidia; then
    log "ERRO: 05:00.0 (VGA) não visível. Reboot do host ou verificar hardware/BIOS VT-d."
    lspci -nn | grep -i nvidia || true
    exit 2
  fi

  if ! gpu_ready; then
    log "GPU não está em vfio-pci em ambas as funções."
    lspci -k -s 05:00.0
    lspci -k -s 05:00.1
    log "Correr: bash prepare-gpu-passthrough-host.sh && reboot"
    exit 3
  fi

  log "Parar VM$VMID..."
  qm shutdown "$VMID" --timeout 120 2>/dev/null || qm stop "$VMID" 2>/dev/null || true
  sleep 3

  log "VM$VMID — passthrough (slot 05:00, VGA+áudio)..."
  qm set "$VMID" --machine q35
  qm set "$VMID" --bios ovmf
  qm set "$VMID" --cpu host,hidden=1,flags=+pcid
  # Passthrough do slot completo (VGA + HDMI audio) — tutorial: hostpci0: 01:00,x-vga=on,pcie=1
  qm set "$VMID" --hostpci0 "05:00,pcie=1,x-vga=1,rombar=0"
  qm set "$VMID" --vga none
  # Mantém ballooning (ex. memory 16384, balloon 32768) — não alterar; evita oversubscription no host.

  log "Arrancar VM$VMID..."
  if ! qm start "$VMID"; then
    log "ERRO no arranque — ver journalctl e /var/log/pve/qemu-server/${VMID}.log"
    exit 4
  fi

  log "Aguardar SSH..."
  for _ in $(seq 1 36); do
    if ssh -o StrictHostKeyChecking=no -o ConnectTimeout=3 agladmin@192.168.0.200 "true" 2>/dev/null; then
      log "VM online. Instalar driver na guest (Secure Boot desactivado na VM):"
      echo "  ssh agladmin@192.168.0.200"
      echo "  sudo ubuntu-drivers install --gpgpu   # ou: sudo apt install nvidia-driver-570-open"
      echo "  sudo reboot"
      echo "  nvidia-smi && ollama ps"
      exit 0
    fi
    sleep 10
  done
  log "AVISO: SSH indisponível — consola Proxmox ou aguardar cloud-init."
}

main "$@"
