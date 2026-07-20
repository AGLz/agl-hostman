#!/usr/bin/env bash
# Smoke sem OAuth: falha em /health se down. Com OAuth: /v1/models + chat mínimo.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DIR="${AUTH2API_DIR:-$ROOT/docker/auth2api}"
HOST="${AUTH2API_HOST:-127.0.0.1}"
PORT="${AUTH2API_PORT:-8317}"
BASE="http://${HOST}:${PORT}"

KEY=""
if [[ -f "$DIR/.env" ]]; then
  # shellcheck disable=SC1091
  set -a
  source "$DIR/.env"
  set +a
  KEY="${AUTH2API_API_KEY:-}"
fi
if [[ -z "$KEY" && -f "$DIR/config.yaml" ]]; then
  KEY="$(awk '/^api-keys:/{getline; gsub(/[" ]/,""); gsub(/^-/,""); print; exit}' "$DIR/config.yaml" || true)"
fi

echo "== GET /health =="
curl -fsS "${BASE}/health" | head -c 400
echo

if [[ -z "$KEY" ]]; then
  echo "Sem API key — só health. Corre bootstrap + login." >&2
  exit 0
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "jq é obrigatório para o smoke chat" >&2
  exit 1
fi

echo "== GET /v1/models =="
MODELS="$(curl -fsS "${BASE}/v1/models" -H "Authorization: Bearer ${KEY}")"
echo "$MODELS" | jq -c '{object, count:(.data|length), sample:(.data[:3]|map(.id))}'
echo

echo "== GET /admin/accounts =="
curl -fsS "${BASE}/admin/accounts" -H "Authorization: Bearer ${KEY}" | jq -c .
echo

COUNT="$(echo "$MODELS" | jq '.data|length')"
if [[ "${COUNT:-0}" -eq 0 ]]; then
  echo "AVISO: 0 modelos — falta login OAuth (scripts/auth2api/login.sh)." >&2
  exit 2
fi

MODEL="$(echo "$MODELS" | jq -r '.data[0].id')"
echo "== POST /v1/chat/completions model=${MODEL} =="
PAYLOAD="$(jq -nc --arg m "$MODEL" \
  '{"model":$m,"messages":[{"role":"user","content":"ping"}],"max_tokens":16}')"
curl -fsS "${BASE}/v1/chat/completions" \
  -H "Authorization: Bearer ${KEY}" \
  -H "Content-Type: application/json" \
  --data-binary "$PAYLOAD" \
  | jq -c '{id, model, choices:(.choices|map({finish_reason, text:(.message.content // .text // "")[0:80]}))}'
echo
echo "OK smoke auth2api"
