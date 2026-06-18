#!/usr/bin/env bash
# Actualiza ingress remoto do túnel aglsrv5e (FGSRV6 → FGSRV7 CT575/572/573).
# Auth: CLOUDFLARE_API_TOKEN (conta aglz.io) — gerar/validar via CT117 cert.pem ou agldv03.
#
# Uso:
#   export CLOUDFLARE_API_TOKEN='…'
#   bash scripts/cloudflare/update-aglsrv5e-tunnel-ingress.sh
#   bash scripts/cloudflare/update-aglsrv5e-tunnel-ingress.sh --dry-run
set -euo pipefail

ACCOUNT_ID="${CLOUDFLARE_ACCOUNT_ID:-08e7b6e3a5084b4a3a2e0b3de153b02e}"
TUNNEL_ID="${AGLSRV5E_TUNNEL_ID:-863fd93d-73c5-4c3e-90b5-7cbd37643f70}"
N8N_ORIGIN="${N8N_ORIGIN:-http://192.168.70.247:5678}"
APIS_ORIGIN="${APIS_ORIGIN:-http://192.168.70.246:80}"
APIS_TLS_ORIGIN="${APIS_TLS_ORIGIN:-https://192.168.70.246:443}"
TOKEN="${CLOUDFLARE_API_TOKEN:-${CF_API_TOKEN:-}}"
DRY_RUN=0

for arg in "$@"; do
    case "$arg" in
        --dry-run) DRY_RUN=1 ;;
        -h | --help)
            sed -n '1,20p' "$0"
            exit 0
            ;;
        *)
            echo "Opção desconhecida: $arg" >&2
            exit 1
            ;;
    esac
done

if [[ -z "${TOKEN}" ]]; then
    echo "Erro: defina CLOUDFLARE_API_TOKEN (conta aglz.io, Tunnel Edit)" >&2
    exit 1
fi

payload=$(python3 - <<PY
import json
ingress = [
    {
        "hostname": "n8n5e.aglz.io",
        "service": "${N8N_ORIGIN}",
        "originRequest": {"disableChunkedEncoding": True},
    },
    {
        "hostname": "api-v8-dev.falg.com.br",
        "service": "${APIS_TLS_ORIGIN}",
        "originRequest": {"noTLSVerify": True, "disableChunkedEncoding": True},
    },
    {
        "hostname": "api-v9-dev.falg.com.br",
        "service": "${APIS_TLS_ORIGIN}",
        "originRequest": {"noTLSVerify": True, "disableChunkedEncoding": True},
    },
    {
        "hostname": "api-v8-qa.falg.com.br",
        "service": "${APIS_ORIGIN}",
        "originRequest": {"disableChunkedEncoding": True},
    },
    {
        "hostname": "aglpy01.aguileraz.net",
        "service": "${APIS_ORIGIN}",
        "originRequest": {"disableChunkedEncoding": True},
    },
    {
        "hostname": "aglpy02.aguileraz.net",
        "service": "${APIS_ORIGIN}",
        "originRequest": {"disableChunkedEncoding": True},
    },
    {"service": "http_status:404"},
]
print(json.dumps({"config": {"ingress": ingress, "warp-routing": {"enabled": True}}}))
PY
)

echo "Túnel: aglsrv5e (${TUNNEL_ID})"
echo "n8n → ${N8N_ORIGIN}"
echo "APIs → ${APIS_ORIGIN} / ${APIS_TLS_ORIGIN}"

if [[ "${DRY_RUN}" -eq 1 ]]; then
    echo "${payload}" | python3 -m json.tool
    exit 0
fi

response=$(curl -sS -X PUT \
    "https://api.cloudflare.com/client/v4/accounts/${ACCOUNT_ID}/cfd_tunnel/${TUNNEL_ID}/configurations" \
    -H "Authorization: Bearer ${TOKEN}" \
    -H "Content-Type: application/json" \
    --data "${payload}")

if echo "${response}" | python3 -c "import sys,json; d=json.load(sys.stdin); sys.exit(0 if d.get('success') else 1)"; then
    echo "OK: ingress aglsrv5e actualizado para FGSRV7."
else
    echo "Falha:" >&2
    echo "${response}" >&2
    exit 1
fi
