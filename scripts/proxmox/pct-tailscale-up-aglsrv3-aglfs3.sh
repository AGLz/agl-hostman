#!/usr/bin/env bash
# Tailscale no CT338 aglfs3 (pós-clone CT178).
#
# Uso:
#   export TAILSCALE_AUTHKEY='tskey-auth-…'
#   bash scripts/proxmox/pct-tailscale-up-aglsrv3-aglfs3.sh
#
# Ou: /root/.tailscale-authkey-aglfs3 (chmod 600) no AGLSRV3.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=aglsrv-vmid-map.env
source "${SCRIPT_DIR}/aglsrv-vmid-map.env"

VMID="${AGLSRV3_AGLFS3_VMID:-338}"
HOSTNAME="${AGLSRV3_AGLFS3_TS_HOSTNAME:-aglsrv3-aglfs3}"
AGLSRV3_SSH="${AGLSRV3_SSH:-root@100.123.5.81}"
AUTHKEY_FILE="${TAILSCALE_AUTHKEY_FILE:-/root/.tailscale-authkey-aglfs3}"

log() { echo "[$(date +%H:%M:%S)] $*"; }

remote() { ssh -o BatchMode=yes -o ConnectTimeout=20 "${AGLSRV3_SSH}" "$@"; }

if [[ -z "${TAILSCALE_AUTHKEY:-}" && -f "${AUTHKEY_FILE}" ]]; then
  TAILSCALE_AUTHKEY="$(tr -d '\r\n' < "${AUTHKEY_FILE}")"
  export TAILSCALE_AUTHKEY
fi

if ! remote "pct status ${VMID}" | grep -q running; then
  log "A arrancar CT${VMID}..."
  remote "pct start ${VMID} && sleep 8"
fi

status_line="$(remote "pct exec ${VMID} -- tailscale status --peers=false 2>&1 | head -1" || true)"
if echo "${status_line}" | grep -qE '^100\.'; then
  log "CT${VMID} (${HOSTNAME}) já na tailnet:"
  remote "pct exec ${VMID} -- tailscale ip -4"
  exit 0
fi

log "Reset Tailscale (clone CT178 → identidade nova)"
remote "pct exec ${VMID} -- bash -c '
  set -e
  systemctl stop tailscaled
  rm -rf /var/lib/tailscale/*
  systemctl start tailscaled
  sleep 2
'"

_up_flags=(
  --accept-dns=false
  "--hostname=${HOSTNAME}"
  --ssh
  --accept-risk=lose-ssh
)

if [[ -n "${TAILSCALE_AUTHKEY:-}" ]]; then
  log "tailscale up com authkey (${HOSTNAME})"
  remote "pct exec ${VMID} -- tailscale up ${_up_flags[*]@Q} --auth-key=${TAILSCALE_AUTHKEY@Q}"
else
  log "Sem auth key — tailscale up interactivo (visitar URL)"
  remote "pct exec ${VMID} -- tailscale up ${_up_flags[*]@Q} --timeout=60s" || true
fi

remote "pct exec ${VMID} -- tailscale status 2>&1 | head -8"
echo "IPv4: $(remote "pct exec ${VMID} -- tailscale ip -4 2>/dev/null" || echo NeedsLogin)"
log "OK — actualizar docs/INFRA.md com IP Tailscale aglsrv3-aglfs3"
