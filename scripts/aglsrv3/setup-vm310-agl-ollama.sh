#!/usr/bin/env bash
# Cria VM310 agl-ollama no AGLSRV3: Ubuntu 24.04, GPU RX580 passthrough, Ollama.
# Pré-requisito: VM301 parada e hostpci1 (RX580) removida.
set -euo pipefail

VMID="${VMID:-310}"
NAME="${NAME:-agl-ollama}"
MEMORY="${MEMORY:-16384}"
BALLOON="${BALLOON:-24576}"
CORES="${CORES:-8}"
DISK_GB="${DISK_GB:-120}"
STORAGE="${STORAGE:-aglsrv3-tb}"
BRIDGE="${BRIDGE:-vmbr0}"
IP="${IP:-192.168.15.210/24}"
GW="${GW:-192.168.15.1}"
DNS="${DNS:-192.168.15.117}"
MAC="${MAC:-BC:24:11:BA:73:10}"
CI_USER="${CI_USER:-agladmin}"
GPU_MAP="${GPU_MAP:-RX580}"
GPU_MAP2="${GPU_MAP2:-RX580_2}"
CLOUD_IMG="${CLOUD_IMG:-/var/lib/vz/template/cache/noble-server-cloudimg-amd64.img}"
CLOUD_IMG_URL="${CLOUD_IMG_URL:-https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img}"
SSH_KEY_FILE="${SSH_KEY_FILE:-/root/.ssh/authorized_keys}"

log() { echo "[setup-vm310] $*"; }

ensure_cloud_image() {
  if [[ -f "$CLOUD_IMG" ]]; then
    log "Cloud image: $CLOUD_IMG"
    return 0
  fi
  log "Download Ubuntu 24.04 cloud image..."
  wget -q --show-progress -O "$CLOUD_IMG" "$CLOUD_IMG_URL"
}

ensure_ssh_key() {
  if [[ ! -s "$SSH_KEY_FILE" ]]; then
    log "Gerar chave SSH para cloud-init..."
    ssh-keygen -t ed25519 -N "" -f /root/.ssh/id_ed25519_vm310 -q
    SSH_KEY_FILE="/root/.ssh/id_ed25519_vm310.pub"
  fi
  if [[ "$SSH_KEY_FILE" != *.pub ]] && [[ -f "${SSH_KEY_FILE}.pub" ]]; then
    SSH_KEY_FILE="${SSH_KEY_FILE}.pub"
  fi
  log "SSH key: $SSH_KEY_FILE"
}

gpu_free() {
  if qm list | awk '$1 == "301" && $3 == "running" { exit 1 }'; then
    :
  else
    if qm list | awk '$1 == "301" && $3 == "running" { found=1 } END { exit !found }'; then
      log "ERRO: VM301 ainda running — parar antes de criar VM310."
      exit 2
    fi
  fi
  if grep -q 'mapping=RX580' /etc/pve/qemu-server/*.conf 2>/dev/null; then
    log "ERRO: RX580 ainda mapeada noutra VM:"
    grep -l 'mapping=RX580' /etc/pve/qemu-server/*.conf || true
    exit 3
  fi
  lspci -k -s 02:00.0 2>/dev/null | grep -q vfio-pci || {
    log "AVISO: 02:00.0 não está em vfio-pci"
    lspci -k -s 02:00.0 || true
  }
}

create_vm() {
  if qm status "$VMID" &>/dev/null; then
    log "VM$VMID já existe"
    qm config "$VMID"
    exit 1
  fi

  gpu_free
  ensure_cloud_image
  ensure_ssh_key

  log "Criar VM$VMID $NAME..."
  qm create "$VMID" \
    --name "$NAME" \
    --memory "$MEMORY" \
    --balloon "$BALLOON" \
    --cores "$CORES" \
    --cpu host,hidden=1,flags=+pcid \
    --machine q35 \
    --bios ovmf \
    --ostype l26 \
    --agent enabled=1 \
    --scsihw virtio-scsi-single \
    --net0 "virtio,bridge=${BRIDGE},macaddr=${MAC}" \
    --serial0 socket \
    --vga none \
    --onboot 1 \
    --startup order=2

  qm set "$VMID" --efidisk0 "${STORAGE}:1,efitype=4m,pre-enrolled-keys=0"
  qm importdisk "$VMID" "$CLOUD_IMG" "$STORAGE"
  qm set "$VMID" --scsi0 "${STORAGE}:vm-${VMID}-disk-1,discard=on,ssd=1"
  qm set "$VMID" --boot order=scsi0
  qm resize "$VMID" scsi0 "${DISK_GB}G"
  qm set "$VMID" --ide2 "${STORAGE}:cloudinit"
  qm set "$VMID" --ciuser "$CI_USER"
  qm set "$VMID" --sshkeys "$SSH_KEY_FILE"
  qm set "$VMID" --ipconfig0 "ip=${IP},gw=${GW}"
  qm set "$VMID" --nameserver "$DNS"
  qm set "$VMID" --searchdomain aglz.io
  qm set "$VMID" --hostpci0 "mapping=${GPU_MAP},pcie=1,rombar=0"
  qm set "$VMID" --hostpci1 "mapping=${GPU_MAP2},pcie=1,rombar=0"
  qm set "$VMID" --description "Ollama GPU RX580 8GB — AGLSRV3 (substitui teste VM301)"

  log "Config VM$VMID:"
  qm config "$VMID"
}

start_vm() {
  log "Arrancar VM$VMID..."
  qm start "$VMID"
  for i in $(seq 1 36); do
    if qm agent "$VMID" ping &>/dev/null; then
      log "QEMU guest agent OK (${i}0s)"
      return 0
    fi
    sleep 10
  done
  log "AVISO: guest agent ainda não responde"
}

main() {
  if [[ "${EUID:-0}" -ne 0 ]]; then
    echo "ERRO: executar como root no AGLSRV3." >&2
    exit 1
  fi
  create_vm
  if [[ "${START_VM:-1}" == "1" ]]; then
    start_vm
  fi
  cat <<EOF

Próximo passo:
  scp scripts/aglsrv3/install-vm310-ollama-guest.sh ${CI_USER}@192.168.15.210:/tmp/
  ssh ${CI_USER}@192.168.15.210 'sudo bash /tmp/install-vm310-ollama-guest.sh'

EOF
}

main "$@"
