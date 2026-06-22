#!/usr/bin/env bash
# Corrige Telegram DM: agente main usa groq-llama-31-8b (streaming OK) em vez de gpt-5.4-nano.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
REMOTE_HOST="${AGLSRV1_HOST:-AGLSRV1}"
CTID="${OPENCLAW_CTID:-187}"
CONTAINER="${OPENCLAW_CONTAINER:-agl-openclaw-openclaw-gateway-1}"

scp -o BatchMode=yes \
  "${REPO_ROOT}/scripts/openclaw/patch-openclaw-main-model-telegram-ct187.py" \
  "${REMOTE_HOST}:/tmp/"

ssh -o BatchMode=yes "$REMOTE_HOST" bash -s -- "$CTID" "$CONTAINER" <<'REMOTE'
set -euo pipefail
CTID="$1"
CONTAINER="$2"

pct push "$CTID" /tmp/patch-openclaw-main-model-telegram-ct187.py /tmp/patch-openclaw-main-model-telegram-ct187.py
pct exec "$CTID" -- docker cp /tmp/patch-openclaw-main-model-telegram-ct187.py \
  "${CONTAINER}:/tmp/patch-openclaw-main-model-telegram-ct187.py"
pct exec "$CTID" -- docker exec "$CONTAINER" python3 /tmp/patch-openclaw-main-model-telegram-ct187.py

echo "--- verify ---"
pct exec "$CTID" -- docker exec "$CONTAINER" sh -c \
  'jq "{main: (.agents.list[]|select(.id==\"main\")|.model), thinking: .agents.defaults.thinkingDefault, tg_stream: .channels.telegram.streaming}" /home/node/.openclaw/openclaw.json'

echo "--- restart gateway ---"
pct exec "$CTID" -- docker restart "$CONTAINER" >/dev/null
sleep 8
pct exec "$CTID" -- docker exec "$CONTAINER" openclaw channels status 2>&1 | head -5

echo "--- stream smoke (groq via LiteLLM) ---"
pct exec "$CTID" -- docker exec "$CONTAINER" sh -c '
KEY=$(jq -r ".models.providers.openai.apiKey" /home/node/.openclaw/openclaw.json)
curl -sS -m 20 -N -H "Authorization: Bearer $KEY" -H "Content-Type: application/json" \
  -d "{\"model\":\"groq-llama-31-8b\",\"messages\":[{\"role\":\"user\",\"content\":\"ping\"}],\"max_tokens\":32,\"stream\":true}" \
  http://100.125.249.8:4000/v1/chat/completions | head -c 200
echo
'
REMOTE

echo "Fix Telegram DM LLM concluído — envia /new e depois olá no bot."
