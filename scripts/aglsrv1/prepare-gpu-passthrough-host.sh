#!/usr/bin/env bash
# Prepara o host AGLSRV1 para passthrough NVIDIA (tutorial Proxmox 2025 + AGL).
# Executar como root no AGLSRV1 ANTES do reboot. Não arranca a VM110 com GPU.
#
# Corrige:
#   - blacklist vfio-pci acidental (impede passthrough)
#   - vfio-gpu.conf com disable_vga=1 + softdep snd_hda_intel
#   - módulos vfio em /etc/modules
#   - initramfs
#
# Após reboot:
#   lspci -k -s 05:00.0  # vfio-pci em VGA e audio
#   bash finish-vm110-gpu-passthrough.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VFIO_IDS="10de:1f82,10de:10fa"

log() { echo "[prepare-gpu] $*"; }

require_root() {
  if [[ "${EUID:-0}" -ne 0 ]]; then
    echo "ERRO: executar como root no AGLSRV1." >&2
    exit 1
  fi
}

check_grub_iommu() {
  local grub=/etc/default/grub
  if grep -qE 'intel_iommu=on|amd_iommu=on' "$grub"; then
    log "GRUB: IOMMU já presente"
    return 0
  fi
  log "AVISO: adicionar intel_iommu=on a GRUB_CMDLINE_LINUX_DEFAULT e correr update-grub"
  return 1
}

fix_vfio_blacklist() {
  local bad=/etc/modprobe.d/blacklist-vfio-gpu.conf
  if [[ -f "$bad" ]] && grep -q '^blacklist vfio-pci' "$bad"; then
    mv "$bad" "${bad}.disabled-$(date +%Y%m%d%H%M%S)"
    log "Desactivado ${bad} (blacklist vfio-pci bloqueava passthrough)"
  fi
}

install_vfio_modprobe() {
  install -d /etc/modprobe.d
  install -m 0644 "${SCRIPT_DIR}/vfio-gpu.conf" /etc/modprobe.d/vfio-gpu.conf
  log "Instalado /etc/modprobe.d/vfio-gpu.conf"
}

ensure_vfio_modules() {
  local modules=/etc/modules
  local -a needed=(vfio vfio_iommu_type1 vfio_pci)
  for m in "${needed[@]}"; do
    if ! grep -qx "$m" "$modules" 2>/dev/null; then
      echo "$m" >>"$modules"
      log "Adicionado $m a $modules"
    fi
  done
  # vfio_virqfd removido em kernels recentes — não adicionar se ausente
}

ensure_nvidia_blacklist() {
  local f=/etc/modprobe.d/blacklist-nvidia-host.conf
  if [[ ! -f "$f" ]]; then
    cat >"$f" <<'EOF'
blacklist nouveau
blacklist nvidia
blacklist nvidia_drm
blacklist nvidia_modeset
blacklist nvidia_uvm
EOF
    log "Criado $f"
  fi
}

warn_pve_audio_blacklist() {
  if grep -q '^blacklist snd_hda_intel' /etc/modprobe.d/pve-blacklist.conf 2>/dev/null; then
    log "NOTA: pve-blacklist.conf bloqueia snd_hda_intel no host (OK se só VM usa áudio GPU)"
  fi
}

strip_other_gpu_assignments() {
  local found=0
  for conf in /etc/pve/qemu-server/*.conf /etc/pve/lxc/*.conf; do
    [[ -f "$conf" ]] || continue
    if grep -qE 'hostpci.*05:00|lxc\.mount.*nvidia|/dev/nvidia' "$conf" 2>/dev/null; then
      if [[ "$conf" != *"/110.conf" ]]; then
        log "AVISO: GPU referenciada em $conf"
        found=1
      fi
    fi
  done
  if [[ "$found" -eq 0 ]]; then
    log "Nenhum CT/VM (excepto 110) com GPU 05:00"
  fi
}

update_initramfs() {
  log "update-initramfs -u ..."
  update-initramfs -u -k all
}

print_status() {
  log "--- Estado actual (antes do reboot) ---"
  lspci -nn | grep -i nvidia || log "NVIDIA não visível no PCI — reboot necessário"
  lspci -k -s 05:00.0 2>/dev/null || true
  lspci -k -s 05:00.1 2>/dev/null || true
  dmesg | grep -e DMAR -e IOMMU 2>/dev/null | tail -3 || true
  echo ""
  log "Próximo passo: reboot do AGLSRV1, depois:"
  echo "  lspci -k -s 05:00.0 | grep vfio-pci"
  echo "  bash ${SCRIPT_DIR}/finish-vm110-gpu-passthrough.sh"
}

main() {
  require_root
  check_grub_iommu || true
  fix_vfio_blacklist
  install_vfio_modprobe
  ensure_vfio_modules
  ensure_nvidia_blacklist
  warn_pve_audio_blacklist
  strip_other_gpu_assignments
  update_initramfs
  print_status
  log "Concluído (sem reboot automático)."
}

main "$@"
