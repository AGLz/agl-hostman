#!/usr/bin/env bash
# Descarrega o virtio-win ISO mais recente para overpower:iso e liga-o à VM104 (ide2).
# Instalação in-guest (guest tools + QEMU-GA) via qm guest exec se o agent responder.
#
# Uso no AGLSRV1 (root):
#   bash scripts/proxmox/vm104-apply-latest-virtio-iso.sh
#   bash scripts/proxmox/vm104-apply-latest-virtio-iso.sh --install

set -euo pipefail

print_manual_steps() {
  cat <<'EOF'

Instalação manual (RDP 192.168.0.33 ou Tailscale aglsrv1-aglwk45), sem reiniciar a VM se possível:
  1. Abrir o segundo CD-ROM (virtio-win-0.1.285) — letra típica E: ou F: (ide0 pode ser outro ISO).
  2. Executar como Administrador: virtio-win-gt-x64.msi  (ou virtio-win-guest-tools.exe).
  3. Ou só o agent: guest-agent\qemu-ga-x86_64.msi
  4. Serviços → QEMU Guest Agent → Iniciar; arranque Automático.
  5. No AGLSRV1: qm agent 104 ping

Repetir com --install quando o agent já responder.
EOF
}

VMID="${AGLWK45_VMID:-104}"
ISO_DIR="${VIRTIO_ISO_DIR:-/overpower/base/template/iso}"
ISO_NAME="virtio-win-0.1.285.iso"
ISO_PATH="${ISO_DIR}/${ISO_NAME}"
ISO_VOLID="overpower:iso/${ISO_NAME}"
DOWNLOAD_URL="https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/latest-virtio/virtio-win.iso"
DO_INSTALL=0

for arg in "$@"; do
  case "$arg" in
    --install) DO_INSTALL=1 ;;
    -h | --help)
      sed -n '2,10p' "$0"
      exit 0
      ;;
    *)
      echo "Argumento desconhecido: $arg" >&2
      exit 1
      ;;
  esac
done

command -v qm >/dev/null || {
  echo "ERRO: executar no Proxmox AGLSRV1." >&2
  exit 1
}

mkdir -p "${ISO_DIR}"

if [[ ! -f "${ISO_PATH}" ]] || [[ $(stat -c%s "${ISO_PATH}") -lt 500000000 ]]; then
  echo "=== Download ${DOWNLOAD_URL} → ${ISO_PATH} ==="
  wget -q --show-progress -O "${ISO_PATH}.tmp" "${DOWNLOAD_URL}"
  mv "${ISO_PATH}.tmp" "${ISO_PATH}"
fi
echo "ISO: $(ls -lh "${ISO_PATH}")"

echo "=== qm set ${VMID} ide2=${ISO_VOLID} ==="
qm set "${VMID}" --ide2 "${ISO_VOLID},media=cdrom"
qm config "${VMID}" | grep -E '^ide'

if [[ "${DO_INSTALL}" -eq 1 ]]; then
  echo "=== qm agent ping ==="
  if qm agent "${VMID}" ping >/dev/null 2>&1; then
    echo "=== Instalar guest tools + QEMU-GA (MSI silencioso) ==="
    qm guest exec "${VMID}" -- cmd /c "for %d in (D E F G H I J) do @if exist %d:\\virtio-win-gt-x64.msi (msiexec /i %d:\\virtio-win-gt-x64.msi /qn /norestart & goto ga) & if exist %d:\\guest-agent\\qemu-ga-x86_64.msi (msiexec /i %d:\\guest-agent\\qemu-ga-x86_64.msi /qn /norestart) & :ga"
    sleep 5
    if qm agent "${VMID}" ping >/dev/null 2>&1; then
      echo "OK: guest agent responde"
    else
      echo "AVISO: agent ainda sem ping — iniciar serviço QEMU-GA no Windows ou RDP"
      exit 2
    fi
  else
    echo "AVISO: guest agent não está a correr."
    print_manual_steps
    exit 2
  fi
else
  print_manual_steps
fi
