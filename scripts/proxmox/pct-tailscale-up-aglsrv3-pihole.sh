#!/usr/bin/env bash
# Tailscale join do CT117 (pihole3) no AGLSRV3 após clone do Pi-hole AGLSRV1 CT102.
#
# Executar no host Proxmox AGLSRV3 (root):
#   export TAILSCALE_AUTHKEY='tskey-auth-…'
#   bash scripts/proxmox/pct-tailscale-up-aglsrv3-pihole.sh
#
# Ou criar /root/.tailscale-authkey (uma linha, chmod 600) no AGLSRV3.
#
# Sem auth key: imprime URL de login (fluxo interactivo).

set -euo pipefail

CT_VMID="${CT_VMID:-117}"
TS_HOSTNAME="${TS_HOSTNAME:-aglsrv3-pihole}"
AUTHKEY_FILE="${TAILSCALE_AUTHKEY_FILE:-/root/.tailscale-authkey}"

if [[ -z "${TAILSCALE_AUTHKEY:-}" && -f "${AUTHKEY_FILE}" ]]; then
  TAILSCALE_AUTHKEY="$(tr -d '\r\n' < "${AUTHKEY_FILE}")"
  export TAILSCALE_AUTHKEY
fi

command -v pct >/dev/null || {
  echo 'Erro: pct não encontrado — executar no nó Proxmox AGLSRV3.' >&2
  exit 1
}

if ! pct status "${CT_VMID}" &>/dev/null; then
  echo "Erro: CT${CT_VMID} não existe." >&2
  exit 1
fi

if ! pct status "${CT_VMID}" | grep -q running; then
  pct start "${CT_VMID}"
  sleep 5
fi

status_line="$(pct exec "${CT_VMID}" -- tailscale status --peers=false 2>&1 | head -1 || true)"
if echo "${status_line}" | grep -qE '^100\.'; then
  echo "CT${CT_VMID} (${TS_HOSTNAME}) já na tailnet:"
  pct exec "${CT_VMID}" -- tailscale ip -4
  exit 0
fi

echo "==> CT ${CT_VMID}: reset estado Tailscale (clone CT102)"
pct exec "${CT_VMID}" -- systemctl stop tailscaled
pct exec "${CT_VMID}" -- bash -c 'rm -rf /var/lib/tailscale/*'
pct exec "${CT_VMID}" -- systemctl start tailscaled
sleep 2

_up_flags=(
  --accept-dns=false
  "--hostname=${TS_HOSTNAME}"
  --ssh
  --accept-risk=lose-ssh
)

if [[ -n "${TAILSCALE_AUTHKEY:-}" ]]; then
  echo "==> tailscale up com authkey (${TS_HOSTNAME})"
  pct exec "${CT_VMID}" -- tailscale up "${_up_flags[@]}" --auth-key="${TAILSCALE_AUTHKEY}"
else
  echo "==> tailscale up (visitar URL se aparecer; hostname ${TS_HOSTNAME})"
  pct exec "${CT_VMID}" -- tailscale up "${_up_flags[@]}" --timeout=60s || true
fi

echo "==> Estado:"
pct exec "${CT_VMID}" -- tailscale status 2>&1 | head -8
echo "IPv4 Tailscale: $(pct exec "${CT_VMID}" -- tailscale ip -4 2>/dev/null || echo 'NeedsLogin')"
