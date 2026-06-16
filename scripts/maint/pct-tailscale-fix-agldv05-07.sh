#!/usr/bin/env bash
# Corrige identidade Tailscale duplicada agldv05 (CT536 AGLSRV5) / agldv07 (CT547 FGSRV7).
#
# Sintoma: ambos com a mesma machine key / IP (ex. 100.119.41.63), hostname TS errado,
# ou agldv07 offline em 100.64.139.79 após restore de disco.
#
# Uso (com auth key reutilizável — ver docs/INFRA.md):
#   export TAILSCALE_AUTHKEY='tskey-auth-…'
#   bash scripts/maint/pct-tailscale-fix-agldv05-07.sh
#
# Sem auth key: imprime URLs login.tailscale.com (aprovar no browser).
#
# Hosts Proxmox (Tailscale):
#   AGLSRV5  root@100.119.223.113  CT536 agldv05  → aglsrv5-agldv05
#   FGSRV7   root@100.109.181.93  CT547 agldv07  → fgsrv07-agldv07

set -euo pipefail

AGLSRV5="${AGLSRV5:-root@100.119.223.113}"
FGSRV7="${FGSRV7:-root@100.109.181.93}"
CT_AGLDV05=536
CT_AGLDV07=547
AUTHKEY_FILE="${TAILSCALE_AUTHKEY_FILE:-/root/.tailscale-authkey}"

if [[ -z "${TAILSCALE_AUTHKEY:-}" && -f "${AUTHKEY_FILE}" ]]; then
  TAILSCALE_AUTHKEY="$(tr -d '\r\n' < "${AUTHKEY_FILE}")"
  export TAILSCALE_AUTHKEY
fi

log() { echo "[INFO] $*"; }
ok() { echo "[OK] $*"; }

reset_ct() {
  local host="$1"
  local vmid="$2"
  local ts_hostname="$3"

  log "CT${vmid} (${ts_hostname}) em ${host}"
  ssh -o BatchMode=yes -o ConnectTimeout=25 "$host" "pct exec ${vmid} -- bash -s" <<REMOTE
set -euo pipefail
systemctl stop tailscaled
rm -rf /var/lib/tailscale/*
systemctl start tailscaled
sleep 2
_up=(--accept-dns=false --accept-routes=false "--hostname=${ts_hostname}" --ssh --accept-risk=lose-ssh)
if [[ -n "\${TAILSCALE_AUTHKEY:-}" ]]; then
  tailscale up "\${_up[@]}" --authkey="\${TAILSCALE_AUTHKEY}"
else
  tailscale up "\${_up[@]}"
fi
echo "IPv4: \$(tailscale ip -4)"
tailscale status 2>&1 | head -3
REMOTE
}

log "=== 1/2 agldv05 CT${CT_AGLDV05} ==="
reset_ct "$AGLSRV5" "$CT_AGLDV05" "aglsrv5-agldv05"

log "=== 2/2 agldv07 CT${CT_AGLDV07} ==="
reset_ct "$FGSRV7" "$CT_AGLDV07" "fgsrv07-agldv07"

ok "Concluído — remover nós fantasma na consola Tailscale (ex. aglsrv5-agldv05-old, fgsrv07-agldv07 offline antigo)"
log "IPs esperados após fix (podem mudar): agldv05 ~100.82.x, agldv07 ~100.64.x — confirmar com: tailscale status | grep agldv"
