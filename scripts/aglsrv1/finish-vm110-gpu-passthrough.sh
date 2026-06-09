#!/usr/bin/env bash
# Reanexa GPU à VM110 após reboot do AGLSRV1 (vfio-pci activo em 05:00.0 + 05:00.1).
# Alinhado tutorial Proxmox 2025: q35, OVMF, host CPU, hostpci pcie+x-vga.
# Executar como root no AGLSRV1.
set -euo pipefail

VMID="${VMID:-110}"

log() { echo "[finish-gpu] $*"; }

warn_no_kernel_downgrade() {
  log "AVISO: não fazer pin em kernel < 6.11 — rpool usa vdev_zaps_v2 (ver docs/proxmox-kernel-issue.md)"
}

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

  warn_no_kernel_downgrade

  log "Parar VM$VMID..."
  qm shutdown "$VMID" --timeout 120 2>/dev/null || qm stop "$VMID" 2>/dev/null || true
  sleep 3

  log "VM$VMID — passthrough headless (05:00.0 VGA, consola virtio)..."
  qm set "$VMID" --machine q35
  qm set "$VMID" --bios ovmf
  qm set "$VMID" --cpu host,hidden=1,flags=+pcid
  # Só VGA (05:00.0) — áudio HDMI opcional; evita conflitos IRQ em alguns hosts.
  qm set "$VMID" --hostpci0 "0000:05:00.0,pcie=1,rombar=0"
  qm set "$VMID" --vga virtio
  # Secure Boot OFF — módulo nvidia proprietário não assina para OVMF MS keys
  if qm config "$VMID" | grep -q 'pre-enrolled-keys=1'; then
    log "AVISO: recriar efidisk com pre-enrolled-keys=0 se modprobe nvidia falhar na guest"
  fi
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
