#!/usr/bin/env bash
# Monitoriza pool aglsrv3-tb e tenta online do disco removido (X6KLT31FT).
# Cron sugerido (aglsrv3): */15 * * * * root /path/aglsrv3-zfs-disk-watch.sh
#
# Uso:
#   bash scripts/proxmox/aglsrv3-zfs-disk-watch.sh
#   bash scripts/proxmox/aglsrv3-zfs-disk-watch.sh --alert
set -euo pipefail

POOL="${AGLSRV3_ZFS_POOL:-aglsrv3-tb}"
MISSING_ID="${AGLSRV3_ZFS_MISSING_DISK:-ata-TOSHIBA_MQ01ABD100_X6KLT31FT}"
LOG="${AGLSRV3_ZFS_WATCH_LOG:-/var/log/hostman/aglsrv3-zfs-watch.log}"
ALERT=false

[[ "${1:-}" == "--alert" ]] && ALERT=true

mkdir -p "$(dirname "$LOG")"
ts="$(date '+%Y-%m-%d %H:%M:%S')"

state="$(zpool list -H -o health "$POOL" 2>/dev/null || echo UNKNOWN)"

if [[ "$state" == "ONLINE" ]]; then
  echo "[$ts] OK pool $POOL ONLINE" >>"$LOG"
  exit 0
fi

dev="/dev/disk/by-id/${MISSING_ID}"
if [[ -e "$dev" ]]; then
  echo "[$ts] Disco ${MISSING_ID} detectado — zpool online" | tee -a "$LOG"
  zpool online "$POOL" "$dev" 2>&1 | tee -a "$LOG"
  zpool status "$POOL" | tee -a "$LOG"
  if [[ "$ALERT" == true ]] && command -v agl-alert-notify.sh >/dev/null 2>&1; then
    AGL_MONITOR_ENV=/etc/agl-hostman/monitor.env agl-alert-notify.sh \
      --severity warn --title "ZFS $POOL disco online" --body "${MISSING_ID} reposto; verificar zpool status"
  fi
  exit 0
fi

# Rescan SCSI (barato)
for h in /sys/class/scsi_host/host*/scan; do
  echo "- - -" >"$h" 2>/dev/null || true
done

msg="[$ts] WARN pool $POOL state=$state — disco ${MISSING_ID} ausente (intervenção física ou zpool replace)"
echo "$msg" >>"$LOG"

if [[ "$ALERT" == true ]]; then
  REPO="${REPO_ROOT:-/mnt/overpower/apps/dev/agl/agl-hostman}"
  NOTIFY="${REPO}/scripts/monitoring/agl-alert-notify.sh"
  if [[ -x "$NOTIFY" ]]; then
    AGL_MONITOR_ENV=/etc/agl-hostman/monitor.env bash "$NOTIFY" \
      --severity critical --title "ZFS $POOL DEGRADED" \
      --body "Disco ${MISSING_ID} REMOVED. Pool funcional com 4/5 discos. Ver docs/AGLSRV3-DISKS.md"
  fi
fi

exit 1
