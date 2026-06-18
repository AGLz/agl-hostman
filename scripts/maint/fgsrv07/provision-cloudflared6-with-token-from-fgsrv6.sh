#!/usr/bin/env bash
# Obtém CLOUDFLARE_TUNNEL_TOKEN do FGSRV6 e configura CT575 (túnel aglsrv5e).
# Usa `cloudflared tunnel run` + EnvironmentFile + pct push (sem token em ps).
# Nota: se o token no FGSRV6 estiver revogado, regenerar em Zero Trust antes do cutover.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

FGSRV6="${FGSRV6:-root@100.83.51.9}"
FGSRV7="${FGSRV7:-root@100.109.181.93}"
ENV_TMP="/tmp/cf-tunnel-aglsrv5e.env"
REMOTE_LIB="/root/lib-cloudflared-envfile-install.$$.sh"

if ssh -o BatchMode=yes "${FGSRV7}" 'pct status 575 2>/dev/null | grep -qi running && [[ "$(pct exec 575 -- systemctl is-active cloudflared 2>/dev/null)" == "active" ]]'; then
    echo "CT575 cloudflared já activo — skip"
    exit 0
fi

ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new "${FGSRV6}" \
    'grep -E "^CLOUDFLARE_TUNNEL_TOKEN=" /opt/docker/cloudflared/.env' > "${ENV_TMP}"
if [[ ! -s "${ENV_TMP}" ]]; then
    echo "Erro: token não encontrado em ${FGSRV6}" >&2
    exit 1
fi

scp -o BatchMode=yes -o StrictHostKeyChecking=accept-new "${ENV_TMP}" "${FGSRV7}:/root/cf-tunnel-aglsrv5e.env"
scp -o BatchMode=yes -o StrictHostKeyChecking=accept-new \
    "${SCRIPT_DIR}/lib-cloudflared-envfile-install.sh" "${FGSRV7}:${REMOTE_LIB}"
rm -f "${ENV_TMP}"

ssh -o BatchMode=yes "${FGSRV7}" bash -s -- "$REMOTE_LIB" <<'REMOTE'
set -euo pipefail
REMOTE_LIB="$1"
# shellcheck source=/dev/null
source "$REMOTE_LIB"

python3 - <<'PY'
from pathlib import Path
src = Path("/root/cf-tunnel-aglsrv5e.env")
dst = Path("/tmp/cloudflared575.env")
for line in src.read_text().splitlines():
    if line.startswith("CLOUDFLARE_TUNNEL_TOKEN="):
        token = line.split("=", 1)[1].strip().strip('"').strip("'")
        dst.write_text(f"TUNNEL_TOKEN={token}\n")
        break
else:
    raise SystemExit("CLOUDFLARE_TUNNEL_TOKEN ausente")
PY
chmod 600 /tmp/cloudflared575.env
rm -f /root/cf-tunnel-aglsrv5e.env

cloudflared_install_from_envfile 575 /tmp/cloudflared575.env "cloudflared tunnel aglsrv5e (migrado FGSRV6)"
rm -f /tmp/cloudflared575.env "$REMOTE_LIB"

cloudflared_verify_active 575 || {
  pct exec 575 -- journalctl -u cloudflared -n 5 --no-pager
  exit 1
}
REMOTE
