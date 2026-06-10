#!/usr/bin/env bash
# AGLSRV3 — preparação e mitigações para upgrade Proxmox VE 8 → 9.
# Baseado em: https://pve.proxmox.com/wiki/Upgrade_from_8_to_9
# Executar NO host como root, ANTES de dist-upgrade para Trixie.
#
# Uso:
#   aglsrv3-pve9-preupgrade.sh              # aplicar correcções
#   aglsrv3-pve9-preupgrade.sh --check-only # só pve8to9 --full
#   aglsrv3-pve9-preupgrade.sh --grub-fix   # pós-reboot se GRUB falhar

set -euo pipefail

LOG="/var/log/aglsrv3-pve9-preupgrade.log"
HOST_IP_LAN="${AGLSRV3_HOST_IP:-192.168.30.247}"

log() {
  echo "[$(date -Iseconds)] $*" | tee -a "${LOG}"
}

require_root() {
  [[ "${EUID}" -eq 0 ]] || { echo "Executar como root" >&2; exit 1; }
}

fix_stale_repos() {
  log "Remover repositório obsoleto pxve-no-sub (bullseye)"
  if [[ -f /etc/apt/sources.list.d/pxve-no-sub.list ]]; then
    mv /etc/apt/sources.list.d/pxve-no-sub.list /etc/apt/sources.list.d/pxve-no-sub.list.disabled
  fi
}

enable_non_free_firmware() {
  log "Activar componente non-free-firmware nos repos Debian"
  if ! grep -q non-free-firmware /etc/apt/sources.list; then
    sed -i 's/ main contrib$/ main contrib non-free-firmware/' /etc/apt/sources.list
    sed -i 's/ main contrib non-free-firmware non-free-firmware/ main contrib non-free-firmware/' /etc/apt/sources.list
  fi
}

fix_hosts_resolution() {
  # pve8to9 FAIL: IP em /etc/hosts deve existir numa interface local
  log "Corrigir /etc/hosts: aglsrv3 → ${HOST_IP_LAN}"
  if grep -q '192.168.30.111' /etc/hosts; then
    sed -i "s/192.168.30.111/${HOST_IP_LAN}/" /etc/hosts
  elif ! grep -q "${HOST_IP_LAN}.*aglsrv3" /etc/hosts; then
    sed -i "/aglsrv3/s/^127.0.0.1/# disabled old\n# /" /etc/hosts 2>/dev/null || true
    sed -i "1a ${HOST_IP_LAN} aglsrv3.aglz.io aglsrv3" /etc/hosts
  fi
}

install_intel_microcode() {
  log "Instalar intel-microcode (Xeon E5-2690 v3 / Haswell-EP)"
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -y >> "${LOG}" 2>&1
  apt-get install -y intel-microcode >> "${LOG}" 2>&1
  if [[ -d /sys/firmware/efi ]]; then
    apt-get install -y initramfs-tools >> "${LOG}" 2>&1
    update-initramfs -u -k all >> "${LOG}" 2>&1
  fi
  log "Microcode actual (requer reboot para activar): $(dmesg 2>/dev/null | grep 'microcode: Current revision' | tail -1 || echo 'reboot pendente')"
}

remove_systemd_boot_metapackage() {
  log "Remover meta-pacote systemd-boot (GRUB + proxmox-boot-tool no host)"
  if dpkg -l systemd-boot 2>/dev/null | grep -q '^ii'; then
    export DEBIAN_FRONTEND=noninteractive
    apt-get purge -y systemd-boot >> "${LOG}" 2>&1 || true
  fi
}

upgrade_pve8_latest() {
  log "Actualizar PVE 8.x para último point release antes do salto 8→9"
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -y >> "${LOG}" 2>&1
  apt-get dist-upgrade -y -o Dpkg::Options::="--force-confold" >> "${LOG}" 2>&1
}

migrate_lvm_autoactivation() {
  if [[ -x /usr/share/pve-manager/migrations/pve-lvm-disable-autoactivation ]]; then
    log "Desactivar LVM autoactivation em volumes de guest (recomendado PVE 9)"
    /usr/share/pve-manager/migrations/pve-lvm-disable-autoactivation >> "${LOG}" 2>&1 || true
  fi
}

migrate_sysctl() {
  if [[ -f /etc/sysctl.conf ]] && grep -qvE '^\s*(#|$)' /etc/sysctl.conf; then
    log "Migrar /etc/sysctl.conf → /etc/sysctl.d/99-aglsrv3-legacy.conf"
    cp -a /etc/sysctl.conf /etc/sysctl.d/99-aglsrv3-legacy.conf
    echo "# Migrado para /etc/sysctl.d/ — ver PVE 9 upgrade wiki" > /etc/sysctl.conf
  fi
}

prepare_grub_uefi_lvm() {
  # Mitigação: GRUB+UEFI+LVM falha após upgrade (wiki + forum Proxmox)
  log "Preparar GRUB EFI (UEFI + root LVM)"
  if [[ ! -d /sys/firmware/efi ]]; then
    log "BIOS/Legacy — saltar grub-efi"
    return 0
  fi
  export DEBIAN_FRONTEND=noninteractive
  echo 'grub-efi-amd64 grub2/force_efi_extra_removable boolean true' | debconf-set-selections
  apt-get install -y --reinstall grub-efi-amd64 >> "${LOG}" 2>&1 || apt-get install -y grub-efi-amd64 >> "${LOG}" 2>&1
  grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=proxmox --recheck >> "${LOG}" 2>&1 || true
  update-grub >> "${LOG}" 2>&1
  log "grubx64.efi mtime: $(stat -c '%y' /boot/efi/EFI/proxmox/grubx64.efi 2>/dev/null || echo n/a)"
}

disable_journal_audit_socket() {
  log "Desactivar systemd-journald-audit.socket (evita flood de audit durante upgrade)"
  systemctl disable --now systemd-journald-audit.socket 2>/dev/null || true
}

install_tmux() {
  if ! command -v tmux >/dev/null; then
    apt-get install -y tmux >> "${LOG}" 2>&1
  fi
}

snapshot_root_hint() {
  log "Espaço livre em /: $(df -h / | awk 'NR==2 {print $4}')"
  if lvs pve/root &>/dev/null; then
    if ! lvs pve/root-snap-pre-pve9 &>/dev/null; then
      log "Criar snapshot LVM pve/root-snap-pre-pve9 (rollback manual se necessário)"
      lvcreate -s -L 8G -n root-snap-pre-pve9 pve/root >> "${LOG}" 2>&1 || \
        log "AVISO: snapshot root falhou (espaço VFree: $(vgs --noheadings -o vg_free pve))"
    fi
  fi
}

run_pve8to9() {
  log "=== pve8to9 --full ==="
  pve8to9 --full 2>&1 | tee -a "${LOG}"
}

grub_post_reboot_fix() {
  require_root
  log "Reparo GRUB pós-upgrade PVE 9"
  prepare_grub_uefi_lvm
  efibootmgr -v 2>/dev/null | tee -a "${LOG}" || true
  log "Verificar BootOrder inclui entrada proxmox ou UEFI OS → \\EFI\\proxmox\\grubx64.efi"
}

apply_all() {
  require_root
  touch "${LOG}"
  log "=== AGLSRV3 PVE9 pre-upgrade START ==="

  fix_stale_repos
  enable_non_free_firmware
  fix_hosts_resolution
  remove_systemd_boot_metapackage
  migrate_sysctl
  migrate_lvm_autoactivation
  install_tmux
  disable_journal_audit_socket
  upgrade_pve8_latest
  install_intel_microcode
  prepare_grub_uefi_lvm
  snapshot_root_hint

  log "=== pve8to9 após correcções ==="
  if pve8to9 --full 2>&1 | tee -a "${LOG}" | grep -q 'FAILURES: 0'; then
    log "pve8to9: 0 FAILURES — pronto para Trixie"
  else
    log "AVISO: ainda há FAIL/WARN — rever ${LOG}"
  fi
  log "=== DONE (reboot recomendado para activar microcode antes do upgrade 8→9) ==="
}

main() {
  case "${1:-apply}" in
    --check-only) require_root; run_pve8to9 ;;
    --grub-fix) grub_post_reboot_fix ;;
    apply|"") apply_all ;;
    *)
      echo "Uso: $0 [apply|--check-only|--grub-fix]" >&2
      exit 1
      ;;
  esac
}

main "$@"
