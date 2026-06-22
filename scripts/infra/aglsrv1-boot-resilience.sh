#!/usr/bin/env bash
# AGLSRV1 — resiliência de boot pós-corte de energia.
# Garante: rclone → mergerfs → pve-guests; delay startall; ordem CTs storage-dependent.
#
# Uso:
#   ./scripts/infra/aglsrv1-boot-resilience.sh              # aplicar no host (SSH)
#   ./scripts/infra/aglsrv1-boot-resilience.sh --verify-only
#   AGLSRV1_HOST=root@100.107.113.33 ./scripts/infra/aglsrv1-boot-resilience.sh
#
# Efeito no host: fstab, systemd drop-ins, node startall delay, pct startup order.
# Não remonta mergerfs em runtime (aplica-se no próximo reboot).
set -euo pipefail

AGLSRV1_HOST="${AGLSRV1_HOST:-root@100.107.113.33}"
STARTALL_DELAY="${STARTALL_DELAY:-180}"
VERIFY_ONLY="${VERIFY_ONLY:-0}"

if [[ "${1:-}" == "--verify-only" ]]; then
  VERIFY_ONLY=1
fi

remote() {
  ssh -o BatchMode=yes -o ConnectTimeout=25 -o StrictHostKeyChecking=accept-new "${AGLSRV1_HOST}" "$@"
}

apply_on_host() {
  remote "STARTALL_DELAY=${STARTALL_DELAY} VERIFY_ONLY=${VERIFY_ONLY} bash -s" <<'REMOTE'
set -euo pipefail
STARTALL_DELAY="${STARTALL_DELAY:-180}"
VERIFY_ONLY="${VERIFY_ONLY:-0}"
NODE="$(hostname -s)"
FSTAB="/etc/fstab"
BACKUP_TAG="$(date +%Y%m%d_%H%M%S)"

log() { echo "[aglsrv1-boot] $*"; }

if [[ "$VERIFY_ONLY" == "1" ]]; then
  log "=== verify startall delay ==="
  grep -E 'startall-onboot-delay' "/etc/pve/nodes/${NODE}/config" 2>/dev/null || echo "MISSING startall-onboot-delay"
  log "=== verify fstab mergerfs deps ==="
  grep mergerfs "$FSTAB" || true
  log "=== verify rclone Before=mnt-storage ==="
  grep -h Before= /etc/systemd/system/rclone-gc.service /etc/systemd/system/rclone-gd.service 2>/dev/null || true
  log "=== verify pve-guests drop-in ==="
  cat /etc/systemd/system/pve-guests.service.d/storage-after-mergerfs.conf 2>/dev/null || echo "MISSING drop-in"
  log "=== CT startup (storage-dependent) ==="
  for id in 113 121 123 124 178 179 182 185; do
    printf 'CT%s: ' "$id"
    pct config "$id" 2>/dev/null | grep '^startup:' || echo "n/a"
  done
  exit 0
fi

log "backup configs (${BACKUP_TAG})"
cp -a "$FSTAB" "${FSTAB}.bak.${BACKUP_TAG}"
mkdir -p /root/boot-resilience-backup/"${BACKUP_TAG}"
cp -a /etc/systemd/system/rclone-gc.service /etc/systemd/system/rclone-gd.service \
  /root/boot-resilience-backup/"${BACKUP_TAG}"/ 2>/dev/null || true

log "set startall-onboot-delay=${STARTALL_DELAY}"
mkdir -p "/etc/pve/nodes/${NODE}"
if grep -q '^startall-onboot-delay:' "/etc/pve/nodes/${NODE}/config" 2>/dev/null; then
  sed -i "s/^startall-onboot-delay:.*/startall-onboot-delay: ${STARTALL_DELAY}/" "/etc/pve/nodes/${NODE}/config"
else
  echo "startall-onboot-delay: ${STARTALL_DELAY}" >> "/etc/pve/nodes/${NODE}/config"
fi

log "patch fstab mergerfs → after rclone"
MERGER_LINE='/mnt/gcrypt:/mnt/gdrive /mnt/storage fuse.mergerfs allow_other,use_ino,cache.files=auto-full,dropcacheonclose=true,category.create=mfs,minfreespace=50G,fsname=mergerfs,x-systemd.requires=rclone-gc.service,x-systemd.requires=rclone-gd.service,x-systemd.after=rclone-gc.service,x-systemd.after=rclone-gd.service,x-systemd.after=network-online.target,x-systemd.before=pve-guests.service 0 0'
if grep -q 'x-systemd.requires=rclone-gc.service' "$FSTAB"; then
  log "fstab already patched"
else
  sed -i '\|/mnt/gcrypt:/mnt/gdrive /mnt/storage|d' "$FSTAB"
  echo "$MERGER_LINE" >> "$FSTAB"
fi

patch_rclone_unit() {
  local unit="$1"
  local path="/etc/systemd/system/${unit}"
  [[ -f "$path" ]] || return 0
  if grep -q 'Before=mnt-storage.mount' "$path"; then
    return 0
  fi
  if grep -q '^\[Unit\]' "$path"; then
    sed -i '/^\[Unit\]/a Before=mnt-storage.mount' "$path"
  fi
  if ! grep -q 'network-online.target' "$path"; then
    sed -i 's/After=network.target/After=network-online.target network.target/' "$path"
  fi
}

log "patch rclone systemd units"
patch_rclone_unit rclone-gc.service
patch_rclone_unit rclone-gd.service

log "pve-guests drop-in: after mnt-storage"
mkdir -p /etc/systemd/system/pve-guests.service.d
cat > /etc/systemd/system/pve-guests.service.d/storage-after-mergerfs.conf <<'DROPIN'
[Unit]
After=mnt-storage.mount network-online.target
Wants=mnt-storage.mount network-online.target
DROPIN

log "CT startup order (storage / NFS tier)"
pct set 178 -startup order=15,up=30
pct set 179 -startup order=25,up=120
pct set 185 -startup order=25,up=120
pct set 182 -startup order=26,up=60
pct set 113 -startup order=30,up=30
pct set 121 -startup order=31,up=15
pct set 123 -startup order=32,up=15
pct set 124 -startup order=33,up=15

log "systemd daemon-reload"
systemctl daemon-reload

log "done — mergerfs ordering applies on next reboot"
REMOTE
}

main() {
  echo "[aglsrv1-boot] host=${AGLSRV1_HOST} delay=${STARTALL_DELAY}s verify=${VERIFY_ONLY}"
  apply_on_host
  if [[ "$VERIFY_ONLY" == "1" ]]; then
    return 0
  fi
  VERIFY_ONLY=1 apply_on_host
}

main "$@"
