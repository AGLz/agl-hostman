#!/usr/bin/env bash
# CT243 (fg-legacy): join Tailscale com opções AGL.
# Correr DENTRO do CT243 como root (após /dev/net/tun no LXC — ver pct-configure-ct243-lxc-tailscale.sh).

set -euo pipefail

TS_HOSTNAME="${TS_HOSTNAME:-fg-legacy}"
TS_TAG="${TS_TAG:-tag:servers}"

_up=(--ssh --accept-dns=false "--hostname=${TS_HOSTNAME}")

if [[ -n "${TAILSCALE_AUTHKEY:-}" ]]; then
    tailscale up "${_up[@]}" --authkey="${TAILSCALE_AUTHKEY}"
else
    echo "Sem TAILSCALE_AUTHKEY — seguir URL no browser se aparecer."
    tailscale up "${_up[@]}" --advertise-tags="${TS_TAG}"
fi

tailscale status | head -8
echo "IPv4: $(tailscale ip -4 2>/dev/null || echo '?')"
