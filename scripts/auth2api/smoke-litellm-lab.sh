#!/usr/bin/env bash
# Smoke modelos auth2api-* via LiteLLM local (:4000).
set -euo pipefail

LITELLM_DIR="${LITELLM_OPT_DIR:-/opt/litellm}"
BASE="${LITELLM_URL:-http://127.0.0.1:4000}"
# shellcheck disable=SC1091
set -a
source "${LITELLM_DIR}/.env"
set +a
KEY="${LITELLM_MASTER_KEY:-}"

AUTH=(-H "Content-Type: application/json")
if [[ -n "$KEY" ]]; then
  AUTH+=(-H "Authorization: Bearer ${KEY}")
fi

echo "== LiteLLM /health/liveliness =="
curl -fsS "${BASE}/health/liveliness" | head -c 200
echo

for model in auth2api-claude-sonnet auth2api-gpt-codex; do
  echo "== chat $model =="
  PAYLOAD="$(jq -nc --arg m "$model" \
    '{"model":$m,"messages":[{"role":"user","content":"ping"}],"max_tokens":16}')"
  code="$(curl -sS -o /tmp/ll-lab.json -w "%{http_code}" \
    "${BASE}/v1/chat/completions" "${AUTH[@]}" --data-binary "$PAYLOAD")"
  echo "HTTP $code"
  jq -c '{model:.model, text:(.choices[0].message.content // .choices[0].text // .error.message // .error)[0:120]}' \
    /tmp/ll-lab.json 2>/dev/null || head -c 300 /tmp/ll-lab.json
  echo
  [[ "$code" == "200" ]] || exit 1
done

echo "OK smoke LiteLLM ← auth2api"
