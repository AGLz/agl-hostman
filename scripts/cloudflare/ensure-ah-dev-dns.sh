#!/usr/bin/env bash
# Cria/atualiza CNAME ah-dev.aglz.io → túnel aglsrv1 (mesmo que ah.aglz.io).
set -euo pipefail

ZONE_NAME="${ZONE_NAME:-aglz.io}"
TUNNEL_ID="${AGLSRV1_TUNNEL_ID:-f7ab6239-5cbd-44ef-83b9-ee8bfb4965ce}"
RECORD_NAME="${RECORD_NAME:-ah-dev.aglz.io}"
TOKEN="${CLOUDFLARE_API_TOKEN:-${CF_API_TOKEN:-}}"

if [[ -z "${TOKEN}" ]]; then
  echo "Erro: defina CLOUDFLARE_API_TOKEN ou CF_API_TOKEN" >&2
  exit 1
fi

CONTENT="${TUNNEL_ID}.cfargotunnel.com"

zone_id="$(curl -sS "https://api.cloudflare.com/client/v4/zones?name=${ZONE_NAME}" \
  -H "Authorization: Bearer ${TOKEN}" | python3 -c "import json,sys; print(json.load(sys.stdin)['result'][0]['id'])")"

existing="$(curl -sS "https://api.cloudflare.com/client/v4/zones/${zone_id}/dns_records?name=${RECORD_NAME}" \
  -H "Authorization: Bearer ${TOKEN}")"

record_id="$(echo "${existing}" | python3 -c "import json,sys; r=json.load(sys.stdin).get('result',[]); print(r[0]['id'] if r else '')")"

payload="$(python3 -c "import json; print(json.dumps({'type':'CNAME','name':'${RECORD_NAME}','content':'${CONTENT}','proxied':True,'ttl':1}))")"

if [[ -n "${record_id}" ]]; then
  response="$(curl -sS -X PUT \
    "https://api.cloudflare.com/client/v4/zones/${zone_id}/dns_records/${record_id}" \
    -H "Authorization: Bearer ${TOKEN}" \
    -H "Content-Type: application/json" \
    --data "${payload}")"
  action="actualizado"
else
  response="$(curl -sS -X POST \
    "https://api.cloudflare.com/client/v4/zones/${zone_id}/dns_records" \
    -H "Authorization: Bearer ${TOKEN}" \
    -H "Content-Type: application/json" \
    --data "${payload}")"
  action="criado"
fi

if echo "${response}" | python3 -c "import sys,json; d=json.load(sys.stdin); sys.exit(0 if d.get('success') else 1)"; then
  echo "OK: ${RECORD_NAME} ${action} → ${CONTENT}"
else
  echo "Falha DNS:" >&2
  echo "${response}" >&2
  exit 1
fi
