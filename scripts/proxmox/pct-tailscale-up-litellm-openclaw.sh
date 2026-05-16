#!/usr/bin/env bash
# Junta CT186 (LiteLLM) e CT187 (OpenClaw) à tailnet com chave reutilizável.
# Executar no nó AGLSRV1 (ou SSH para ele) com a chave só no ambiente — nunca no Git.
#
# Uso:
#   export TAILSCALE_AUTHKEY='tskey-auth-xxxxx'
#   bash scripts/proxmox/pct-tailscale-up-litellm-openclaw.sh
#
# Chave: https://login.tailscale.com/admin/settings/keys (reusable, tags ACL conforme política AGL)

set -euo pipefail

: "${TAILSCALE_AUTHKEY:?Defina TAILSCALE_AUTHKEY (chave auth reutilizável Tailscale).}"

command -v pct >/dev/null || {
  echo "ERRO: pct não encontrado — executar no Proxmox AGLSRV1." >&2
  exit 1
}

for entry in "186:agl-litellm-ct186" "187:agl-openclaw-ct187"; do
  vmid="${entry%%:*}"
  host="${entry##*:}"
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

echo "OK. Verificar nomes e tags no admin Tailscale; ajustar ACLs se necessário."
