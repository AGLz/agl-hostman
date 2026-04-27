#!/usr/bin/env bash
# Investigação OpenClaw agldv03: config, Telegram, sessão, LiteLLM.
set -euo pipefail
OC=/root/.openclaw/openclaw.json

echo "======== 1) Gateway =========="
systemctl --user is-active openclaw-gateway 2>/dev/null || true
ss -tlnp 2>/dev/null | grep 18789 || true

echo ""
echo "======== 2) openclaw.json agents.defaults.model =========="
jq '.agents.defaults.model' "$OC" 2>/dev/null || echo "(jq falhou)"

echo ""
echo "======== 3) canais Telegram (sem token) =========="
jq '.channels.telegram | del(.botToken)' "$OC" 2>/dev/null || true

echo ""
echo "======== 4) Telegram getWebhookInfo + getUpdates (limit 3) =========="
TOK=$(jq -r '.channels.telegram.botToken // empty' "$OC")
if [[ -n "$TOK" ]]; then
  curl -sS "https://api.telegram.org/bot${TOK}/getWebhookInfo" | jq '{url: .result.url, pending: .result.pending_update_count, err: .result.last_error_message}'
  curl -sS "https://api.telegram.org/bot${TOK}/getUpdates?limit=3&timeout=1" | jq '{ok, n: (.result|length), last: .result[-1].update_id}'
else
  echo "(sem botToken)"
fi

echo ""
echo "======== 5) LiteLLM smoke (glm-4.7-flash + deepseek) =========="
if [[ -r /opt/litellm/.env ]]; then
  K=$(grep -m1 '^LITELLM_MASTER_KEY=' /opt/litellm/.env | cut -d= -f2- | tr -d '\r')
  K=${K//\"/}
  for m in zai/glm-4.7-flash deepseek/deepseek-chat; do
    body=$(jq -nc --arg m "$m" '{model:$m,messages:[{role:"user",content:"Responda só: A"}],max_tokens:16}')
    out=$(curl -sS --max-time 35 -H "Authorization: Bearer $K" -H "Content-Type: application/json" \
      http://127.0.0.1:4000/v1/chat/completions -d "$body")
    echo -n "$m => "
    echo "$out" | jq -r 'if .error then ("ERR:" + (.error.message|tostring|.[:120])) else (.choices[0].message.content|tostring|.[:60]) end' 2>/dev/null || echo "parse fail"
  done
else
  echo "sem /opt/litellm/.env"
fi

echo ""
echo "======== 6) Última troca na sessão com Carlos (1272190248) =========="
SESS=$(grep -l '1272190248' /root/.openclaw/agents/main/sessions/*.jsonl 2>/dev/null | head -1 || true)
if [[ -n "${SESS:-}" ]]; then
  echo "ficheiro: $SESS"
  tail -12 "$SESS" | jq -c '{t:.type, role: .message.role, model: .message.model, contentLen: (.message.content|if type=="array" then map(.text//"")|add|length elif .message.content==null then 0 else (.message.content|tostring|length) end), stop: .message.stopReason}' 2>/dev/null || tail -8 "$SESS"
else
  echo "(nenhuma sessão com 1272190248 encontrada pelo grep)"
  ls -t /root/.openclaw/agents/main/sessions/*.jsonl 2>/dev/null | head -1 | while read -r f; do
    echo "fallback última: $f"; tail -6 "$f"
  done
fi

echo ""
echo "======== 7) litellm-gateway.env + models.json openai key prefix =========="
grep -E '^LITELLM_' /root/.openclaw/litellm-gateway.env 2>/dev/null | sed 's/=.*/=***/' || true
jq -r '.providers.openai.apiKey' /root/.openclaw/agents/main/agent/models.json 2>/dev/null | head -c 22; echo "..."

echo ""
echo "======== 8) Variáveis agent main (se existir agent.json) =========="
for f in /root/.openclaw/agents/main/agent/agent.json /root/.openclaw/agents/main/agent/config.json; do
  [[ -f "$f" ]] && echo "--- $f ---" && cat "$f" | head -40
done
true
