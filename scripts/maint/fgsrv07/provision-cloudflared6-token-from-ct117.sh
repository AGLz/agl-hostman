#!/usr/bin/env bash
# Gera token aglsrv5e via CT117 (AGLSRV1) e instala no CT575 cloudflared6.
# Token nunca passa na linha de comando remota — só via ficheiro temp + pct push.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib-cloudflared-envfile-install.sh
source "${SCRIPT_DIR}/lib-cloudflared-envfile-install.sh"

AGLSRV1="${AGLSRV1:-root@100.107.113.33}"
FGSRV7="${FGSRV7:-root@100.109.181.93}"
CT117=117
TUNNEL_ID="${AGLSRV5E_TUNNEL_ID:-863fd93d-73c5-4c3e-90b5-7cbd37643f70}"
VMID=575

LOCAL_ENV="$(mktemp)"
REMOTE_ENV="/root/cloudflared575-token.$$.env"
REMOTE_LIB="/root/lib-cloudflared-envfile-install.$$.sh"

cleanup() {
    rm -f "$LOCAL_ENV"
    ssh -o BatchMode=yes "${FGSRV7}" "rm -f '${REMOTE_ENV}' '${REMOTE_LIB}'" 2>/dev/null || true
}
trap cleanup EXIT

log() { printf '[%s] %s\n' "$(date +%H:%M:%S)" "$*"; }

log "Gerar token aglsrv5e no CT117"
TOKEN=$(ssh -o BatchMode=yes "${AGLSRV1}" "pct exec ${CT117} -- cloudflared tunnel token ${TUNNEL_ID}" | tr -d '\r\n')
if [[ ${#TOKEN} -lt 100 ]]; then
    echo "Erro: token inválido (len=${#TOKEN})" >&2
    exit 1
fi

printf 'TUNNEL_TOKEN=%s\n' "$TOKEN" >"$LOCAL_ENV"
chmod 600 "$LOCAL_ENV"
unset TOKEN

log "Copiar env + helper para FGSRV7 e instalar via pct push"
scp -o BatchMode=yes "$LOCAL_ENV" "${FGSRV7}:${REMOTE_ENV}"
scp -o BatchMode=yes "${SCRIPT_DIR}/lib-cloudflared-envfile-install.sh" "${FGSRV7}:${REMOTE_LIB}"

ssh -o BatchMode=yes "${FGSRV7}" bash -s -- "$VMID" "$REMOTE_ENV" "$REMOTE_LIB" <<'REMOTE'
set -euo pipefail
VMID="$1"
REMOTE_ENV="$2"
REMOTE_LIB="$3"
# shellcheck source=/dev/null
source "$REMOTE_LIB"
cloudflared_install_from_envfile "$VMID" "$REMOTE_ENV" "cloudflared tunnel aglsrv5e (FGSRV7)"
rm -f "$REMOTE_ENV" "$REMOTE_LIB"
cloudflared_verify_active "$VMID"
REMOTE

log "Concluído — validar: ssh ${FGSRV7} pct exec ${VMID} -- journalctl -u cloudflared -n 5"
