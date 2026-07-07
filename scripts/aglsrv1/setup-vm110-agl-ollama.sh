#!/usr/bin/env bash
# Cria VM110 agl-ollama no AGLSRV1: Ubuntu 24.04, 16GB RAM (balloon 32GB), 240GB, GPU passthrough.
# Mantém IP/MAC do CT200 (192.168.0.200 / BC:24:11:BA:72:22) para LiteLLM sem alterações.
# Executar como root no AGLSRV1 após strip-gpu-from-aglsrv1.sh e enable-vfio-gpu-host.sh.
set -euo pipefail

VMID="${VMID:-110}"
NAME="${NAME:-agl-ollama}"
MEMORY="${MEMORY:-16384}"
BALLOON="${BALLOON:-32768}"
CORES="${CORES:-48}"
DISK_GB="${DISK_GB:-240}"
STORAGE="${STORAGE:-local-zfs}"
BRIDGE="${BRIDGE:-vmbr0}"
IP="${IP:-192.168.0.200/24}"
GW="${GW:-192.168.0.1}"
DNS="${DNS:-192.168.0.102}"
MAC="${MAC:-BC:24:11:BA:72:22}"
CI_USER="${CI_USER:-agladmin}"
GPU_PCI="${GPU_PCI:-05:00}"
CLOUD_IMG="${CLOUD_IMG:-/var/lib/vz/template/cache/noble-server-cloudimg-amd64.img}"
CLOUD_IMG_URL="${CLOUD_IMG_URL:-https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img}"
SSH_KEY_FILE="${SSH_KEY_FILE:-/root/.ssh/authorized_keys}"

log() { echo "[setup-vm110] $*"; }

ensure_cloud_image() {
  if [[ -f "$CLOUD_IMG" ]]; then
    log "Cloud image: $CLOUD_IMG"
    return 0
  fi
  log "Download Ubuntu 24.04 cloud image..."
  wget -q --show-progress -O "$CLOUD_IMG" "$CLOUD_IMG_URL"
}

ensure_ssh_key() {
  if [[ ! -f "$SSH_KEY_FILE" ]]; then
    log "Gerar chave SSH para cloud-init..."
    ssh-keygen -t ed25519 -N "" -f /root/.ssh/id_ed25519_vm110 -q
    SSH_KEY_FILE="/root/.ssh/id_ed25519_vm110.pub"
  fi
  if [[ "$SSH_KEY_FILE" == *.pub ]]; then
    :
  elif [[ -f "${SSH_KEY_FILE}.pub" ]]; then
    SSH_KEY_FILE="${SSH_KEY_FILE}.pub"
  fi
  log "SSH key: $SSH_KEY_FILE"
}

create_vm() {
  if qm status "$VMID" &>/dev/null; then
    log "VM$VMID já existe — abortar ou definir VMID diferente"
    qm config "$VMID"
    exit 1
  fi

  ensure_cloud_image
  ensure_ssh_key

  log "Criar VM$VMID $NAME..."
  qm create "$VMID" \
    --name "$NAME" \
    --memory "$MEMORY" \
    --balloon "$BALLOON" \
    --cores "$CORES" \
    --cpu host \
    --machine q35 \
    --bios ovmf \
    --ostype l26 \
    --agent enabled=1 \
    --scsihw virtio-scsi-single \
    --net0 "virtio,bridge=${BRIDGE},macaddr=${MAC}" \
    --serial0 socket \
    --vga serial0 \
    --onboot 1 \
    --startup order=3

  qm set "$VMID" --efidisk0 "${STORAGE}:1,efitype=4m,pre-enrolled-keys=1"
  qm importdisk "$VMID" "$CLOUD_IMG" "$STORAGE"
  qm set "$VMID" --scsi0 "${STORAGE}:vm-${VMID}-disk-1,discard=on,ssd=1"
  qm set "$VMID" --boot order=scsi0
  qm resize "$VMID" scsi0 "${DISK_GB}G"
  qm set "$VMID" --ide2 "${STORAGE}:cloudinit"
  qm set "$VMID" --ciuser "$CI_USER"
  qm set "$VMID" --sshkeys "$SSH_KEY_FILE"
  qm set "$VMID" --ipconfig0 "ip=${IP},gw=${GW}"
  qm set "$VMID" --nameserver "$DNS"
  qm set "$VMID" --searchdomain localdomain
  qm set "$VMID" --hostpci0 "${GPU_PCI},pcie=1"
  qm set "$VMID" --description "Ollama qwen3:4b — GPU exclusiva (substitui CT200)"

  log "Config VM$VMID:"
  qm config "$VMID"
}

start_vm() {
  log "Arrancar VM$VMID..."
  qm start "$VMID"
  log "Aguardar cloud-init / agent (até 120s)..."
  for i in $(seq 1 24); do
    if qm agent "$VMID" ping &>/dev/null; then
      log "QEMU guest agent OK"
      return 0
    fi
    sleep 5
  done
  log "AVISO: guest agent ainda não responde — continuar manualmente"
}

main() {
  if [[ "${EUID:-0}" -ne 0 ]]; then
    echo "ERRO: executar como root no AGLSRV1." >&2
    exit 1
  fi
  create_vm
  if [[ "${START_VM:-1}" == "1" ]]; then
    start_vm
  fi
  cat <<EOF

Próximo passo (na VM ou via qm guest exec após SSH):
  ssh ${CI_USER}@192.168.0.200
  # copiar scripts/aglsrv1 e correr:
  sudo bash install-vm110-ollama-guest.sh

EOF
}

main "$@"
