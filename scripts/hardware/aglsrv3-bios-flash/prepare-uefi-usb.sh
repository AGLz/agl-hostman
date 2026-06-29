#!/usr/bin/env bash
# Prepara pen USB FAT32 para flash BIOS HUANANZHI X99-F8 via UEFI Shell.
#
# NÃO inclui ROM proprietário — colocar manualmente após download oficial/iEngineer.
#
# Uso:
#   sudo ./prepare-uefi-usb.sh --usb /dev/sdX --bios-zip ~/Downloads/HUANANZHI-X99-F8-BIOS.zip
#   sudo ./prepare-uefi-usb.sh --usb /dev/sdX --bios-dir ./CX99DE77-NEWBIOS/
#   ./prepare-uefi-usb.sh --dry-run --bios-dir ./NEWBIOS/
#
# Requisitos: parted, mkfs.vfat, curl, unzip (opcional)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UEFI_SHELL_URL="${UEFI_SHELL_URL:-https://github.com/tianocore/edk2/releases/download/edk2-stable202402/Shell.efi}"
DRY_RUN=false
USB_DEV=""
BIOS_ZIP=""
BIOS_DIR=""
MOUNT_POINT="/mnt/aglsrv3-bios-usb"

log() { echo "[prepare-usb] $*"; }
die() { log "ERRO: $*"; exit 1; }

usage() {
  sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --usb) USB_DEV="$2"; shift 2 ;;
    --bios-zip) BIOS_ZIP="$2"; shift 2 ;;
    --bios-dir) BIOS_DIR="$2"; shift 2 ;;
    --mount) MOUNT_POINT="$2"; shift 2 ;;
    --dry-run) DRY_RUN=true; shift ;;
    -h|--help) usage; exit 0 ;;
    *) die "Opção desconhecida: $1" ;;
  esac
done

[[ -n "$BIOS_ZIP" || -n "$BIOS_DIR" ]] || die "Indique --bios-zip ou --bios-dir com ficheiros do fabricante/iEngineer"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

stage_bios() {
  local dest="$WORK/NEWBIOS"
  mkdir -p "$dest"

  if [[ -n "$BIOS_ZIP" ]]; then
    [[ -f "$BIOS_ZIP" ]] || die "ZIP não encontrado: $BIOS_ZIP"
    unzip -q -o "$BIOS_ZIP" -d "$WORK/extract"
    if [[ -f "$WORK/extract/flash.nsh" ]]; then
      cp -a "$WORK/extract/"* "$dest/"
    else
      find "$WORK/extract" -name 'flash.nsh' -exec dirname {} \; | head -1 | xargs -I{} cp -a {}/* "$dest/" 2>/dev/null \
        || cp -a "$WORK/extract/"* "$dest/"
    fi
  else
    [[ -d "$BIOS_DIR" ]] || die "Pasta não encontrada: $BIOS_DIR"
    cp -a "$BIOS_DIR/"* "$dest/"
  fi

  [[ -f "$dest/flash.nsh" ]] || log "AVISO: flash.nsh não encontrado — pacote iEngineer inclui; oficial pode usar AfuEfix64.efi"
  ls -la "$dest"
  echo "$dest"
}

fetch_shell() {
  local shell="$WORK/Shell.efi"
  if [[ -f "$SCRIPT_DIR/Shell.efi" ]]; then
    cp "$SCRIPT_DIR/Shell.efi" "$shell"
    return
  fi
  log "A descarregar UEFI Shell (Tianocore)..."
  if [[ "$DRY_RUN" == true ]]; then
    log "[dry-run] curl -L -o Shell.efi $UEFI_SHELL_URL"
    return
  fi
  curl -fsSL -o "$shell" "$UEFI_SHELL_URL" || die "Falha download Shell.efi — copiar manualmente para $SCRIPT_DIR/Shell.efi"
}

write_readme() {
  local root="$1"
  cat >"$root/LEIA-ME.txt" <<'TXT'
AGLSRV3 — Flash BIOS X99-F8 (UEFI Shell)
=========================================
1. Boot USB → F11/F12 → UEFI: Built-in EFI Shell (ou Boot from File → Shell.efi)
2. No shell: fs0: ou fs1: (testar com "map" e "ls")
3. cd NEWBIOS
4. flash.nsh
5. Aguardar 100% — NÃO desligar
6. Clear CMOS: retirar bateria CR2032 + PSU desligada 15 min
7. BIOS Del → Load Optimized Defaults → Boot #1 Samsung SSD 850 EVO → F10

Tutorial completo: docs/AGLSRV3-BIOS-UEFI-FLASH.md (repo agl-hostman)
TXT
}

if [[ "$DRY_RUN" == true && -z "$USB_DEV" ]]; then
  log "Dry-run: staging BIOS..."
  stage_bios >/dev/null
  fetch_shell
  log "OK — estrutura pronta em temp. Use --usb /dev/sdX para gravar."
  exit 0
fi

[[ -n "$USB_DEV" ]] || die "Indique --usb /dev/sdX (ex.: /dev/sdb — NÃO partição)"

if [[ "$DRY_RUN" == false ]]; then
  if [[ ! -b "$USB_DEV" ]]; then
    die "$USB_DEV não é block device"
  fi
  log "ATENÇÃO: vai apagar $USB_DEV — 5 s para cancelar (Ctrl+C)"
  sleep 5
fi

bios_staged="$(stage_bios)"
fetch_shell

if [[ "$DRY_RUN" == true ]]; then
  log "[dry-run] parted/mkfs/copy para $USB_DEV"
  exit 0
fi

parted -s "$USB_DEV" mklabel gpt
parted -s "$USB_DEV" mkpart EFI fat32 1MiB 100%
parted -s "$USB_DEV" set 1 esp on
sleep 2
PART="${USB_DEV}1"
[[ -b "$PART" ]] || PART="${USB_DEV}p1"
mkfs.vfat -F 32 -n AGLSRV3BIOS "$PART"

mkdir -p "$MOUNT_POINT"
mount "$PART" "$MOUNT_POINT"

mkdir -p "$MOUNT_POINT/EFI/BOOT" "$MOUNT_POINT/NEWBIOS"
cp "$WORK/Shell.efi" "$MOUNT_POINT/EFI/BOOT/BOOTX64.EFI"
cp -a "$bios_staged/"* "$MOUNT_POINT/NEWBIOS/"
write_readme "$MOUNT_POINT"

if [[ -f "$SCRIPT_DIR/flash.nsh.example" ]]; then
  cp "$SCRIPT_DIR/flash.nsh.example" "$MOUNT_POINT/NEWBIOS/flash.nsh.example"
fi

sync
umount "$MOUNT_POINT"
log "USB pronta. Ejectar com segurança e flash no AGLSRV3 via UEFI Shell."
