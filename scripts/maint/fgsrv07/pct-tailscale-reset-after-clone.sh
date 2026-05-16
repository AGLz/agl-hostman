#!/usr/bin/env bash
# Apaga o estado local do Tailscale num CT (ex.: clone do CT170) e volta a fazer join
# com hostname novo, evitando duplicar o mesmo nó (mesmo IP / machine key).
#
# No host Proxmox FGSRV7 (root), exemplos:
#   CT_VMID=171 TS_HOSTNAME=fgsrv07-cloudflared7b bash /root/pct-tailscale-reset-after-clone.sh
#   CT_VMID=171 TS_HOSTNAME=fgsrv07-cloudflared7b TAILSCALE_AUTHKEY='tskey-auth-…' bash …
#
# Sem TAILSCALE_AUTHKEY: o comando imprime URL de login no browser (fluxo interactivo).

set -euo pipefail

CT_VMID="${CT_VMID:?Definir CT_VMID (ex.: 171)}"
TS_HOSTNAME="${TS_HOSTNAME:?Definir TS_HOSTNAME (ex.: fgsrv07-cloudflared7b)}"

if ! command -v pct >/dev/null 2>&1; then
    echo 'Erro: pct não encontrado — correr no nó Proxmox.' >&2
    exit 1
fi

echo "==> CT ${CT_VMID}: parar tailscaled e remover estado em /var/lib/tailscale"
pct exec "${CT_VMID}" -- systemctl stop tailscaled
pct exec "${CT_VMID}" -- bash -c 'rm -rf /var/lib/tailscale/*'
pct exec "${CT_VMID}" -- systemctl start tailscaled
sleep 2

_up_flags=(--accept-dns=false "--hostname=${TS_HOSTNAME}" --ssh)
if [[ -n "${TAILSCALE_AUTHKEY:-}" ]]; then
    echo "==> tailscale up com authkey (hostname ${TS_HOSTNAME})"
    pct exec "${CT_VMID}" -- tailscale up "${_up_flags[@]}" --authkey="${TAILSCALE_AUTHKEY}"
else
    echo "==> tailscale up (abrir URL no browser se pedido; hostname ${TS_HOSTNAME})"
    pct exec "${CT_VMID}" -- tailscale up "${_up_flags[@]}"
fi

echo "==> Estado:"
pct exec "${CT_VMID}" -- tailscale status 2>&1 | head -6
echo "IPv4 Tailscale: $(pct exec "${CT_VMID}" -- tailscale ip -4 2>/dev/null || echo '?')"
