#!/usr/bin/env bash
# Tailscale no CT318 aglsrv3-pbs (identidade própria; não reutilizar aglsrv6-pbs).
#
# Uso:
#   export TAILSCALE_AUTHKEY='tskey-auth-…'
#   bash scripts/proxmox/pct-tailscale-up-aglsrv3-pbs.sh
#
# Interactivo (URL ~10 min):
#   bash scripts/proxmox/pct-tailscale-up-aglsrv3-pbs.sh --url-only

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=aglsrv-vmid-map.env
source "${SCRIPT_DIR}/aglsrv-vmid-map.env"

VMID="${AGLSRV3_PBS_VMID:-318}"
HOSTNAME="${AGLSRV3_PBS_TS_HOSTNAME:-aglsrv3-pbs}"
AGLSRV3_SSH="${AGLSRV3_SSH:-root@100.123.5.81}"
AUTHKEY_FILE="${TAILSCALE_AUTHKEY_FILE:-/root/.tailscale-authkey-aglsrv3-pbs}"
URL_ONLY=false

log() { echo "[$(date +%H:%M:%S)] $*"; }
remote() { ssh -o BatchMode=yes -o ConnectTimeout=25 "${AGLSRV3_SSH}" "$@"; }

for arg in "$@"; do
  case "$arg" in
    --url-only) URL_ONLY=true ;;
  esac
done

if [[ -z "${TAILSCALE_AUTHKEY:-}" && -f "${AUTHKEY_FILE}" ]]; then
  TAILSCALE_AUTHKEY="$(tr -d '\r\n' < "${AUTHKEY_FILE}")"
  export TAILSCALE_AUTHKEY
fi

if ! remote "pct status ${VMID}" | grep -q running; then
  remote "pct start ${VMID} && sleep 8"
fi

remote "pct exec ${VMID} -- systemctl start tailscaled 2>/dev/null || true"

status_line="$(remote "pct exec ${VMID} -- tailscale status --self 2>&1 | head -1" || true)"
if echo "${status_line}" | grep -q "${HOSTNAME}"; then
  log "CT${VMID} já registado como ${HOSTNAME}:"
  remote "pct exec ${VMID} -- tailscale ip -4"
  exit 0
fi

reset_guest() {
  remote "pct exec ${VMID} -- bash -s" <<'GUEST'
set -euo pipefail
tailscale logout 2>/dev/null || true
systemctl stop tailscaled
rm -rf /var/lib/tailscale/*
systemctl start tailscaled
sleep 2
GUEST
}

_up_flags=(
  --accept-dns=false
  "--hostname=${HOSTNAME}"
  --ssh
  --accept-risk=lose-ssh
  --timeout=90s
)

if [[ -n "${TAILSCALE_AUTHKEY:-}" ]]; then
  log "tailscale up com authkey (${HOSTNAME})"
  reset_guest
  remote "pct exec ${VMID} -- tailscale up ${_up_flags[*]@Q} --auth-key=${TAILSCALE_AUTHKEY@Q}"
else
  log "Reset estado + tailscale up interactivo"
  reset_guest
  out="$(remote "pct exec ${VMID} -- tailscale up ${_up_flags[*]@Q} 2>&1" || true)"
  echo "${out}"
  if [[ "${URL_ONLY}" == true ]]; then
    echo "${out}" | grep -oE 'https://login\.tailscale\.com/a/[a-f0-9]+' | head -1
    exit 0
  fi
fi

remote "pct exec ${VMID} -- tailscale status --self 2>&1 | head -3"
log "IPv4: $(remote "pct exec ${VMID} -- tailscale ip -4 2>/dev/null" || echo NeedsLogin)"
