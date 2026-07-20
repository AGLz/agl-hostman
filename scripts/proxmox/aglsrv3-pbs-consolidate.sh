#!/usr/bin/env bash
# Consolida PBS AGLSRV3 no storage ZFS aglsrv3-tb (datastore principal).
#
# - Garante pbs-aglsrv3-tb → datastore aglsrv3-tb
# - Desactiva pbs-local / pbs-local-lvm se vazios (opcional)
# - Actualiza job backup-aglsrv3-pbs-daily
#
# Uso:
#   bash scripts/proxmox/aglsrv3-pbs-consolidate.sh --dry-run
#   bash scripts/proxmox/aglsrv3-pbs-consolidate.sh --apply
#   bash scripts/proxmox/aglsrv3-pbs-consolidate.sh --apply --remote --prune-empty
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=aglsrv-vmid-map.env
source "${SCRIPT_DIR}/aglsrv-vmid-map.env"

AGLSRV3_SSH="${AGLSRV3_SSH:-root@100.123.5.81}"
PBS_VMID="${AGLSRV3_PBS_VMID:-318}"
PRIMARY_PVESM="pbs-aglsrv3-tb"
PRIMARY_DS="aglsrv3-tb"
APPLY=false
REMOTE=false
PRUNE_EMPTY=false

log() { echo "[$(date +%H:%M:%S)] $*"; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --apply) APPLY=true; shift ;;
    --dry-run) APPLY=false; shift ;;
    --remote) REMOTE=true; shift ;;
    --prune-empty) PRUNE_EMPTY=true; shift ;;
    -h|--help)
      sed -n '2,11p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *) echo "Opção desconhecida: $1" >&2; exit 2 ;;
  esac
done

run_host() {
  if [[ "$REMOTE" == true ]]; then
    ssh -o BatchMode=yes "$AGLSRV3_SSH" "$@"
  else
    "$@"
  fi
}

main() {
  log "PBS CT${PBS_VMID} — consolidar em ${PRIMARY_DS}"

  run_host bash -s <<EOF
set -euo pipefail
APPLY=${APPLY}
PRUNE=${PRUNE_EMPTY}

echo "=== Datastores PBS ==="
pct exec ${PBS_VMID} -- proxmox-backup-manager datastore list 2>/dev/null || true

echo "=== pvesm pbs ==="
pvesm status 2>/dev/null | grep '^pbs' || true

if [[ "\$APPLY" == true ]]; then
  if ! pvesm status 2>/dev/null | grep -q '${PRIMARY_PVESM}.*active'; then
    echo "AVISO: ${PRIMARY_PVESM} inactivo — correr pbs-setup-renumbered-hosts.sh --host aglsrv3 --apply"
  fi

  if pvesh get /cluster/backup/backup-aglsrv3-pbs-daily &>/dev/null; then
    pvesh set /cluster/backup/backup-aglsrv3-pbs-daily --storage '${PRIMARY_PVESM}' \
      --comment 'AGLSRV3 daily PBS -> aglsrv3-tb (ZFS pool)' 2>/dev/null || true
    echo "Job backup-aglsrv3-pbs-daily → ${PRIMARY_PVESM}"
  fi

  if [[ "\$PRUNE" == true ]]; then
    for sid in pbs-local pbs-local-lvm; do
      used=\$(pvesm status 2>/dev/null | awk -v s="\$sid" '\$1==s {print \$4}' || echo 0)
      if [[ "\${used:-0}" -le 1 ]]; then
        pvesm set "\$sid" --disable 1 2>/dev/null && echo "Desactivado \$sid (vazio)" || true
      else
        echo "Manter \$sid (used=\$used)"
      fi
    done
  fi
fi
EOF

  if [[ "$APPLY" == true ]]; then
    log "Tailscale PBS: ${AGLSRV3_PBS_TS_IP:-100.117.110.95} — actualizar AGLSRV1 com aglsrv3-remote-storage-link.sh"
  fi
}

if [[ "$REMOTE" == true ]]; then
  scp -q "${SCRIPT_DIR}/aglsrv3-pbs-consolidate.sh" "${SCRIPT_DIR}/aglsrv-vmid-map.env" "${AGLSRV3_SSH}:/root/"
  ssh -o BatchMode=yes "$AGLSRV3_SSH" "bash /root/aglsrv3-pbs-consolidate.sh $([[ $APPLY == true ]] && echo --apply) $([[ $PRUNE_EMPTY == true ]] && echo --prune-empty)"
else
  main
fi
