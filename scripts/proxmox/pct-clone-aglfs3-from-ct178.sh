#!/usr/bin/env bash
# Clona AGLSRV1 CT178 (aglfs1) → AGLSRV3 CT338 (aglfs3) via vzdump + restore.
#
# Uso:
#   bash scripts/proxmox/pct-clone-aglfs3-from-ct178.sh --dry-run
#   bash scripts/proxmox/pct-clone-aglfs3-from-ct178.sh --apply
#   bash scripts/proxmox/pct-clone-aglfs3-from-ct178.sh --apply --replace   # destrói CT338 actual
#
# Pós-clone: Tailscale logout, rede AGLFG, mp ZFS locais (sem overpower/spark do SRV1).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=aglsrv-vmid-map.env
source "${SCRIPT_DIR}/aglsrv-vmid-map.env"

SOURCE_VMID="${AGLFS1_SOURCE_VMID:-178}"
TARGET_VMID="${AGLSRV3_AGLFS3_VMID:-338}"
TARGET_HN="${AGLSRV3_AGLFS3_HOSTNAME:-aglfs3}"
TARGET_IP="${AGLSRV3_AGLFS3_IP}"
TARGET_IP_30="${AGLSRV3_AGLFS3_IP_30}"
TARGET_GW="${AGLSRV3_PBS_GW}"
TARGET_DNS="${AGLSRV3_DNS:-192.168.15.117}"
STORAGE="${AGLSRV3_RESTORE_CT_STORAGE:-aglsrv3-tb}"
ROOTFS_SIZE="${AGLSRV3_AGLFS3_ROOTFS_GB:-64}"

AGLSRV1_SSH="${AGLSRV1_SSH:-root@100.107.113.33}"
AGLSRV3_SSH="${AGLSRV3_SSH:-root@100.123.5.81}"

DUMP_NAME="vzdump-lxc-${SOURCE_VMID}-aglfs3-clone.tar.zst"
DUMP_SRV1="/var/lib/vz/dump/${DUMP_NAME}"
DUMP_SRV3="/var/lib/vz/dump/${DUMP_NAME}"

DRY_RUN=true
REPLACE=false

for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=true ;;
    --apply) DRY_RUN=false ;;
    --replace) REPLACE=true ;;
    -h | --help)
      sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
  esac
done

log() { echo "[$(date +%H:%M:%S)] $*"; }

remote() {
  ssh -o BatchMode=yes -o ConnectTimeout=25 "$1" "${@:2}"
}

ensure_dump() {
  log "=== vzdump CT${SOURCE_VMID} @ AGLSRV1 ==="
  if remote "${AGLSRV1_SSH}" "test -s ${DUMP_SRV1}"; then
    log "Reutilizar dump: ${DUMP_SRV1}"
    remote "${AGLSRV1_SSH}" "ls -lh ${DUMP_SRV1}"
    return 0
  fi
  if [[ "${DRY_RUN}" == true ]]; then
    log "DRY-RUN: vzdump ${SOURCE_VMID} --mode snapshot"
    return 0
  fi
  remote "${AGLSRV1_SSH}" "set -e
    pct status ${SOURCE_VMID} | grep -q running || pct start ${SOURCE_VMID}
    vzdump ${SOURCE_VMID} --dumpdir /var/lib/vz/dump --mode snapshot --compress zstd
    f=\$(ls -t /var/lib/vz/dump/vzdump-lxc-${SOURCE_VMID}-*.tar.zst 2>/dev/null | head -1)
    cp \"\${f}\" ${DUMP_SRV1}
    ls -lh ${DUMP_SRV1}"
}

copy_dump() {
  log "=== Transferência AGLSRV1 → AGLSRV3 ==="
  if [[ "${DRY_RUN}" == true ]]; then
    log "DRY-RUN: scp ${DUMP_SRV1} → ${AGLSRV3_SSH}:${DUMP_SRV3}"
    return 0
  fi
  remote "${AGLSRV3_SSH}" "mkdir -p /var/lib/vz/dump"
  remote "${AGLSRV3_SSH}" "scp -o StrictHostKeyChecking=no ${AGLSRV1_SSH}:${DUMP_SRV1} ${DUMP_SRV3} && ls -lh ${DUMP_SRV3}"
}

prepare_zfs_mounts() {
  log "=== Datasets ZFS (aglfs3) ==="
  if [[ "${DRY_RUN}" == true ]]; then
    log "DRY-RUN: zfs create aglsrv3-tb/{shares,data,overpower,power,storage}"
    return 0
  fi
  remote "${AGLSRV3_SSH}" "set -e
    for ds in shares data overpower power storage; do
      zfs list aglsrv3-tb/\${ds} >/dev/null 2>&1 || zfs create aglsrv3-tb/\${ds}
      mkdir -p /aglsrv3-tb/\${ds}
    done
    zfs list aglsrv3-tb/shares aglsrv3-tb/data"
}

destroy_target_if_replace() {
  if [[ "${REPLACE}" != true ]]; then
    return 0
  fi
  log "=== Remover CT${TARGET_VMID} existente (--replace) ==="
  if [[ "${DRY_RUN}" == true ]]; then
    log "DRY-RUN: pct stop/destroy ${TARGET_VMID}"
    return 0
  fi
  remote "${AGLSRV3_SSH}" "set -e
    pct status ${TARGET_VMID} 2>/dev/null | grep -q running && pct stop ${TARGET_VMID} || true
    pct destroy ${TARGET_VMID} 2>/dev/null || true"
}

restore_target() {
  log "=== Restore CT${TARGET_VMID} (${TARGET_HN}) ==="
  if remote "${AGLSRV3_SSH}" "pct config ${TARGET_VMID}" &>/dev/null; then
    if [[ "${REPLACE}" != true ]]; then
      log "CT${TARGET_VMID} já existe — usar --replace ou apagar manualmente"
      exit 1
    fi
  fi
  if [[ "${DRY_RUN}" == true ]]; then
    log "DRY-RUN: pct restore ${TARGET_VMID} storage=${STORAGE} ip=${TARGET_IP}"
    return 0
  fi
  remote "${AGLSRV3_SSH}" "set -e
    pct restore ${TARGET_VMID} ${DUMP_SRV3} \
      --storage ${STORAGE} \
      --rootfs ${STORAGE}:${ROOTFS_SIZE} \
      --hostname ${TARGET_HN} \
      --unique 1 \
      --ignore-unpack-errors 1"
}

configure_proxmox() {
  log "=== Config Proxmox CT${TARGET_VMID} ==="
  if [[ "${DRY_RUN}" == true ]]; then
    log "DRY-RUN: rede + mp ZFS + features"
    return 0
  fi
  remote "${AGLSRV3_SSH}" "set -e
    pct set ${TARGET_VMID} -hostname ${TARGET_HN}
    pct set ${TARGET_VMID} -nameserver ${TARGET_DNS}
    pct set ${TARGET_VMID} -searchdomain aglz.io
    pct set ${TARGET_VMID} -net0 name=eth0,bridge=vmbr0,gw=${TARGET_GW},ip=${TARGET_IP},type=veth
    pct set ${TARGET_VMID} -net1 name=eth1,bridge=vmbr1,ip=${TARGET_IP_30},type=veth
    for i in 0 1 2 5 6 7 8 9; do pct set ${TARGET_VMID} -delete mp\${i} 2>/dev/null || true; done
    pct set ${TARGET_VMID} -mp0 /aglsrv3-tb/shares,mp=/mnt/shares
    pct set ${TARGET_VMID} -mp1 /aglsrv3-tb/overpower,mp=/mnt/overpower
    pct set ${TARGET_VMID} -mp2 /aglsrv3-tb/power,mp=/mnt/power
    pct set ${TARGET_VMID} -mp5 /aglsrv3-tb/storage,mp=/mnt/storage
    pct set ${TARGET_VMID} -features nesting=1,fuse=1,mknod=1,keyctl=1
    pct set ${TARGET_VMID} -onboot 1
    pct set ${TARGET_VMID} -tags 'agl;fileserver;aglsrv3'
    pct set ${TARGET_VMID} -description 'Fileserver AGLSRV3 — clone CT178 aglfs1; storage ZFS local'
    grep -q 'dev/net/tun' /etc/pve/lxc/${TARGET_VMID}.conf || \
      echo 'lxc.mount.entry: /dev/net/tun dev/net/tun none bind,create=file' >> /etc/pve/lxc/${TARGET_VMID}.conf
    pct start ${TARGET_VMID}
    sleep 10"
}

post_clone_guest() {
  log "=== Pós-clone no guest ==="
  if [[ "${DRY_RUN}" == true ]]; then
    log "DRY-RUN: hostname, tailscale logout, wg off, nfs/smb restart"
    return 0
  fi
  remote "${AGLSRV3_SSH}" "pct exec ${TARGET_VMID} -- bash -s" <<'GUEST'
set -euo pipefail
hostnamectl set-hostname aglfs3 || true
sed -i 's/aglfs1/aglfs3/g' /etc/hosts 2>/dev/null || true

systemctl disable --now wg-quick@wg0 2>/dev/null || true
if command -v tailscale >/dev/null; then
  tailscale logout 2>/dev/null || true
fi

mkdir -p /mnt/shares /mnt/overpower /mnt/power /mnt/storage /srv /srv/storage /srv/homes
for d in shares overpower power storage; do
  touch "/mnt/${d}/.aglfs3-ready" 2>/dev/null || true
done

systemctl enable smbd nmbd nfs-server 2>/dev/null || true
systemctl restart smbd nmbd nfs-server 2>/dev/null || true
systemctl restart tailscaled 2>/dev/null || true

echo "OK guest post-clone: $(hostname) $(ip -4 -br addr show eth0 2>/dev/null || true)"
GUEST
}

verify() {
  log "=== Verificação ==="
  if [[ "${DRY_RUN}" == true ]]; then
    return 0
  fi
  remote "${AGLSRV3_SSH}" "pct list | grep ${TARGET_VMID}
    pct exec ${TARGET_VMID} -- systemctl is-active smbd nfs-server 2>/dev/null || true
    pct exec ${TARGET_VMID} -- ls -la /mnt/shares/.aglfs3-ready 2>/dev/null || true"
}

main() {
  log "Clone CT${SOURCE_VMID} → CT${TARGET_VMID} (${TARGET_HN} @ ${TARGET_IP}) replace=${REPLACE} dry=${DRY_RUN}"
  ensure_dump
  copy_dump
  prepare_zfs_mounts
  destroy_target_if_replace
  restore_target
  configure_proxmox
  post_clone_guest
  verify
  log "=== Concluído ==="
  log "Próximo: bash scripts/proxmox/pct-tailscale-up-aglsrv3-aglfs3.sh (Tailscale aglsrv3-aglfs3)"
  log "Doc: docs/AGLSRV3-AGLFS3-CLONE.md"
}

main
