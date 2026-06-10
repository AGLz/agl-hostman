#!/usr/bin/env bash
# Actualiza ingress remoto do túnel aglsrv1b (archon) no Zero Trust.
# Requer CLOUDFLARE_API_TOKEN com Cloudflare Tunnel Edit + Account read.
set -euo pipefail

ACCOUNT_ID="${CLOUDFLARE_ACCOUNT_ID:-08e7b6e3a5084b4a3a2e0b3de153b02e}"
TUNNEL_ID="${ARCHON_TUNNEL_ID:-908b1097-e182-4725-9960-626ecc003375}"
TOKEN="${CLOUDFLARE_API_TOKEN:-${CF_API_TOKEN:-}}"

if [[ -z "${TOKEN}" ]]; then
    echo "Erro: defina CLOUDFLARE_API_TOKEN ou CF_API_TOKEN" >&2
    exit 1
fi

payload=$(cat <<'JSON'
{
  "config": {
    "warp-routing": { "enabled": true },
    "ingress": [
      { "hostname": "cbapp.aglz.io", "service": "http://100.94.221.87:8077" },
      { "hostname": "ald-dev.aglz.io", "service": "http://100.94.221.87:8089" },
      { "hostname": "archon.aglz.io", "service": "http://192.168.0.183:3000" },
      { "hostname": "mysql-master.aglz.io", "service": "tcp://192.168.0.131:3306" },
      {
        "hostname": "mesh.aglz.io",
        "service": "https://192.168.0.162",
        "originRequest": { "noTLSVerify": true, "disableChunkedEncoding": true }
      },
      {
        "hostname": "hw.aglz.io",
        "service": "http://100.81.225.22:9119",
        "originRequest": { "disableChunkedEncoding": true }
      },
      { "hostname": "dp.aglz.io", "service": "http://100.72.66.106:3000" },
      { "service": "http_status:404" }
    ]
  }
}
JSON
)

response=$(curl -sS -X PUT \
    "https://api.cloudflare.com/client/v4/accounts/${ACCOUNT_ID}/cfd_tunnel/${TUNNEL_ID}/configurations" \
    -H "Authorization: Bearer ${TOKEN}" \
    -H "Content-Type: application/json" \
    --data "${payload}")

if echo "${response}" | python3 -c "import sys,json; d=json.load(sys.stdin); sys.exit(0 if d.get('success') else 1)"; then
    echo "OK: ingress remoto actualizado (archon.aglz.io → :3000)"
else
    echo "Falha ao actualizar ingress remoto:" >&2
    echo "${response}" >&2
    exit 1
fi
