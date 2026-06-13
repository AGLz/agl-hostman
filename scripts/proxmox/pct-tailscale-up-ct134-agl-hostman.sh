#!/usr/bin/env bash
# Tailscale join CT134 agl-hostman prod (AGLSRV1, LAN 192.168.0.134).
#
# Parâmetros canónicos AGL: --accept-dns=false --accept-routes=false --ssh
#
# Uso no AGLSRV1:
#   bash scripts/proxmox/pct-tailscale-up-ct134-agl-hostman.sh
#
# Com auth key reutilizável:
#   export TAILSCALE_AUTHKEY='tskey-auth-…'
#   bash scripts/proxmox/pct-tailscale-up-ct134-agl-hostman.sh
#
# Pré-requisito LXC: /dev/net/tun (ver pct-create / 134.conf)

set -euo pipefail

CT_VMID="${CT_VMID:-134}"
TS_HOSTNAME="${TS_HOSTNAME:-agl-hostman}"
AUTHKEY_FILE="${TAILSCALE_AUTHKEY_FILE:-/root/.tailscale-authkey}"
REPO="${AGL_HOSTMAN_DIR:-/mnt/overpower/apps/dev/agl/agl-hostman}"

if [[ -z "${TAILSCALE_AUTHKEY:-}" && -f "${AUTHKEY_FILE}" ]]; then
  TAILSCALE_AUTHKEY="$(tr -d '\r\n' < "${AUTHKEY_FILE}")"
  export TAILSCALE_AUTHKEY
fi

command -v pct >/dev/null || {
  echo "ERRO: pct não encontrado — executar no Proxmox AGLSRV1." >&2
  exit 1
}

if ! pct status "${CT_VMID}" 2>/dev/null | grep -q running; then
  pct start "${CT_VMID}"
  sleep 5
fi

status_line="$(pct exec "${CT_VMID}" -- tailscale status --peers=false 2>&1 | head -1 || true)"
if echo "${status_line}" | grep -qE '^100\.'; then
  echo "CT${CT_VMID} (${TS_HOSTNAME}) já na tailnet:"
  pct exec "${CT_VMID}" -- tailscale ip -4
  pct exec "${CT_VMID}" -- tailscale status --peers=false
  exit 0
fi

if ! pct exec "${CT_VMID}" -- command -v tailscale >/dev/null 2>&1; then
  echo "==> CT${CT_VMID}: instalar Tailscale"
  pct exec "${CT_VMID}" -- bash -c 'curl -fsSL https://tailscale.com/install.sh | sh'
  pct exec "${CT_VMID}" -- systemctl enable --now tailscaled
  sleep 2
fi

_up_flags=(
  --accept-dns=false
  --accept-routes=false
  "--hostname=${TS_HOSTNAME}"
  --ssh
  --accept-risk=lose-ssh
)

if [[ -n "${TAILSCALE_AUTHKEY:-}" ]]; then
  echo "==> tailscale up com authkey (${TS_HOSTNAME})"
  pct exec "${CT_VMID}" -- tailscale up "${_up_flags[@]}" --auth-key="${TAILSCALE_AUTHKEY}"
else
  echo "==> tailscale up — autenticar na URL abaixo (hostname ${TS_HOSTNAME})"
  pct exec "${CT_VMID}" -- tailscale up "${_up_flags[@]}" --timeout=120s 2>&1 || true
fi

echo ""
echo "==> Estado:"
pct exec "${CT_VMID}" -- tailscale status --peers=false 2>&1 | head -10
echo "IPv4 Tailscale: $(pct exec "${CT_VMID}" -- tailscale ip -4 2>/dev/null || echo 'NeedsLogin')"
