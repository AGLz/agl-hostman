#!/usr/bin/env bash
# Setup cross-site AGLSRV3: PBS aglsrv3-tb + aglfs3 exports + aglfs1 client + link AGLSRV1.
#
# Uso (agldv03):
#   bash scripts/proxmox/aglsrv3-cross-site-setup.sh --dry-run
#   bash scripts/proxmox/aglsrv3-cross-site-setup.sh --apply
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APPLY=false

log() { echo "[$(date +%H:%M:%S)] $*"; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --apply) APPLY=true; shift ;;
    --dry-run) APPLY=false; shift ;;
    -h|--help)
      sed -n '2,7p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *) echo "Opção desconhecida: $1" >&2; exit 2 ;;
  esac
done

flags=()
[[ "$APPLY" == true ]] && flags+=(--apply) || flags+=(--dry-run)

log "=== 1/5 PBS link + job vzdump (aglsrv3-tb) ==="
bash "${SCRIPT_DIR}/pbs-setup-renumbered-hosts.sh" --host aglsrv3 "${flags[@]}" --remote

log "=== 2/5 Consolidar PBS (primary pbs-aglsrv3-tb) ==="
bash "${SCRIPT_DIR}/aglsrv3-pbs-consolidate.sh" "${flags[@]}" --remote $([[ "$APPLY" == true ]] && echo --prune-empty)

log "=== 3/5 aglfs1 client + gateway CT338 ==="
bash "${SCRIPT_DIR}/aglsrv3-aglfs1-client-link.sh" "${flags[@]}" --remote --gateway-ct338

log "=== 4/5 aglfs3 NFS/Samba exports (Tailscale) ==="
bash "${SCRIPT_DIR}/pct-aglfs3-optimize-exports.sh" "${flags[@]}" --remote

log "=== 5/5 AGLSRV1 ← aglfs3 NFS + PBS remoto ==="
bash "${SCRIPT_DIR}/aglsrv3-remote-storage-link.sh" "${flags[@]}" --remote

log "=== Concluído (dry=${APPLY:-false}) ==="
log "Docs: docs/AGLSRV3-PBS-FILESHARE.md"
