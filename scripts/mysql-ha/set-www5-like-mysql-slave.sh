#!/bin/bash
#
# Configura www5.falg.com.br para apontar para o MESMO tunnel do mysql-slave.falg.com.br
# usando a Cloudflare API v4 (DNS Records).
#
# Requisitos:
# - curl
# - jq
#
# Autenticação (recomendado): API Token (Bearer) com permissão Zone > DNS > Edit.
#
# Exemplo:
#   export CF_API_TOKEN="..."
#   export CF_ZONE_ID="01ce76a70c797ca510bb56bf61f3a75e"
#   ./scripts/mysql-ha/set-www5-like-mysql-slave.sh
#
# Nota:
# - Este script NÃO hardcodeia o target do tunnel. Ele lê o CNAME de mysql-slave
#   e faz upsert do CNAME de www5 com o mesmo content.

set -euo pipefail

CF_API_TOKEN="${CF_API_TOKEN:-}"
CF_ZONE_ID="${CF_ZONE_ID:-}"

SOURCE_FQDN="${SOURCE_FQDN:-mysql-slave.falg.com.br}"
TARGET_FQDN="${TARGET_FQDN:-www5.falg.com.br}"

CF_TTL="${CF_TTL:-60}"
CF_PROXIED="${CF_PROXIED:-false}"

require_env() {
  local name="$1"
  if [[ -z "${!name:-}" ]]; then
    echo "ERRO: variável obrigatória não definida: ${name}" >&2
    exit 2
  fi
}

require_env CF_API_TOKEN
require_env CF_ZONE_ID

api_get() {
  local url="$1"
  curl -sS -X GET "$url" \
    -H "Authorization: Bearer ${CF_API_TOKEN}" \
    -H "Content-Type: application/json"
}

api_post() {
  local url="$1"
  local data="$2"
  curl -sS -X POST "$url" \
    -H "Authorization: Bearer ${CF_API_TOKEN}" \
    -H "Content-Type: application/json" \
    --data "$data"
}

api_put() {
  local url="$1"
  local data="$2"
  curl -sS -X PUT "$url" \
    -H "Authorization: Bearer ${CF_API_TOKEN}" \
    -H "Content-Type: application/json" \
    --data "$data"
}

zone_base="https://api.cloudflare.com/client/v4/zones/${CF_ZONE_ID}"

echo "A ler DNS source: ${SOURCE_FQDN}"
source_resp="$(api_get "${zone_base}/dns_records?type=CNAME&name=${SOURCE_FQDN}")"

if ! echo "$source_resp" | jq -e '.success == true' >/dev/null; then
  echo "ERRO: falha a consultar ${SOURCE_FQDN}" >&2
  echo "$source_resp" | jq -r '.errors[]?.message' >&2 || true
  exit 1
fi

source_content="$(echo "$source_resp" | jq -r '.result[0].content // empty')"
if [[ -z "$source_content" ]]; then
  echo "ERRO: não encontrei um CNAME para ${SOURCE_FQDN} (sem content)" >&2
  exit 1
fi

echo "Target do tunnel (CNAME content): ${source_content}"

echo "A verificar se já existe DNS target: ${TARGET_FQDN}"
target_resp="$(api_get "${zone_base}/dns_records?type=CNAME&name=${TARGET_FQDN}")"

if ! echo "$target_resp" | jq -e '.success == true' >/dev/null; then
  echo "ERRO: falha a consultar ${TARGET_FQDN}" >&2
  echo "$target_resp" | jq -r '.errors[]?.message' >&2 || true
  exit 1
fi

target_id="$(echo "$target_resp" | jq -r '.result[0].id // empty')"

payload="$(jq -nc \
  --arg type "CNAME" \
  --arg name "$TARGET_FQDN" \
  --arg content "$source_content" \
  --argjson ttl "${CF_TTL}" \
  --argjson proxied "${CF_PROXIED}" \
  '{type: $type, name: $name, content: $content, ttl: $ttl, proxied: $proxied}')"

if [[ -n "$target_id" ]]; then
  echo "A atualizar ${TARGET_FQDN} (id=${target_id})..."
  update_resp="$(api_put "${zone_base}/dns_records/${target_id}" "$payload")"
  echo "$update_resp" | jq -e '.success == true' >/dev/null || {
    echo "ERRO: falha ao atualizar ${TARGET_FQDN}" >&2
    echo "$update_resp" | jq -r '.errors[]?.message' >&2 || true
    exit 1
  }
else
  echo "A criar ${TARGET_FQDN}..."
  create_resp="$(api_post "${zone_base}/dns_records" "$payload")"
  echo "$create_resp" | jq -e '.success == true' >/dev/null || {
    echo "ERRO: falha ao criar ${TARGET_FQDN}" >&2
    echo "$create_resp" | jq -r '.errors[]?.message' >&2 || true
    exit 1
  }
fi

echo "OK: ${TARGET_FQDN} agora aponta para ${source_content}"

