#!/usr/bin/env bash
# Verifica preparação Tailscale nos CT188–191 (sem fazer login).
# Uso no AGLSRV1: bash scripts/proxmox/pct-tailscale-verify-agency-cts.sh

set -euo pipefail

command -v pct >/dev/null || {
  echo "ERRO: executar no Proxmox AGLSRV1." >&2
  exit 1
}

FAIL=0

for vmid in 188 189 190 191; do
  echo "=== CT${vmid} ==="
  if ! pct status "${vmid}" 2>/dev/null | grep -q running; then
    echo "  ERRO: CT não está running"
    FAIL=1
    continue
  fi
  if pct exec "${vmid}" -- sh -c 'command -v tailscale >/dev/null 2>&1'; then
    echo "  OK tailscale instalado"
  else
    echo "  ERRO: tailscale não instalado"
    FAIL=1
  fi
  if pct exec "${vmid}" -- systemctl is-active tailscaled >/dev/null 2>&1; then
    echo "  OK tailscaled active"
  else
    echo "  ERRO: tailscaled não active"
    FAIL=1
  fi
  if pct exec "${vmid}" -- test -c /dev/net/tun; then
    echo "  OK /dev/net/tun"
  else
    echo "  ERRO: /dev/net/tun em falta"
    FAIL=1
  fi
  echo -n "  Estado: "
  pct exec "${vmid}" -- tailscale status --peers=false 2>&1 | head -1 || echo "NeedsLogin"
  echo ""
done

if [[ "${FAIL}" -eq 0 ]]; then
  echo "Preparação OK. Próximo:"
  echo "  TAILSCALE_AUTHKEY ou /root/.tailscale-authkey → pct-tailscale-up-agency-cts.sh"
  echo "  bash scripts/proxmox/pct-install-agl-lan-routes.sh"
else
  echo "Corrigir erros antes de tailscale up (bootstrap-ct-lxc-base-docker.sh, pct-apply-agldv03-lxc-profile.sh)."
  exit 1
fi
