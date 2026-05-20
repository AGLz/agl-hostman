#!/usr/bin/env bash
# Tailscale up apenas nos CT188–191 (Hermes, EvoNexus, OpenHuman, GStack).
# CT186/187 já estão na tailnet — usar pct-tailscale-up-litellm-openclaw.sh só se precisar rejoin.
#
# Uso:
#   export TAILSCALE_AUTHKEY='tskey-auth-xxxxx'
#   bash scripts/proxmox/pct-tailscale-up-agency-cts.sh

set -euo pipefail

# Chave: env TAILSCALE_AUTHKEY ou ficheiro no Proxmox (uma linha, chmod 600).
AUTHKEY_FILE="${TAILSCALE_AUTHKEY_FILE:-/root/.tailscale-authkey}"
if [[ -z "${TAILSCALE_AUTHKEY:-}" && -f "${AUTHKEY_FILE}" ]]; then
  TAILSCALE_AUTHKEY="$(tr -d '\r\n' < "${AUTHKEY_FILE}")"
  export TAILSCALE_AUTHKEY
fi

: "${TAILSCALE_AUTHKEY:?Defina TAILSCALE_AUTHKEY ou crie ${AUTHKEY_FILE} no AGLSRV1 (tskey-auth-… reutilizável).}"

command -v pct >/dev/null || {
  echo "ERRO: pct não encontrado — executar no Proxmox AGLSRV1." >&2
  exit 1
}

for entry in \
  "188:agl-hermes-ct188" \
  "189:agl-evonexus-ct189" \
  "190:agl-openhuman-ct190" \
  "191:agl-gstack-ct191"; do
  vmid="${entry%%:*}"
  host="${entry##*:}"
  status="$(pct exec "${vmid}" -- tailscale status --peers=false 2>&1 | head -1 || true)"
  if echo "${status}" | grep -qE '^100\.'; then
    echo "=== CT${vmid} (${host}) — já na tailnet, skip ==="
    pct exec "${vmid}" -- tailscale ip -4 || true
    echo ""
    continue
  fi
  echo "=== tailscale up CT${vmid} (${host}) ==="
  pct exec "${vmid}" -- tailscale up \
    --auth-key="${TAILSCALE_AUTHKEY}" \
    --hostname="${host}" \
    --accept-dns=false \
    --ssh \
    --accept-routes \
    --accept-risk=lose-ssh
  pct exec "${vmid}" -- tailscale status --peers=false
  pct exec "${vmid}" -- tailscale ip -4 || true
  echo ""
done

echo "OK. Verificar ACLs/tags no admin Tailscale."
