#!/usr/bin/env bash
# Diagnóstico remoto agldv03: LiteLLM chat smoke + ficheiros agent main.
# Uso local: ssh root@100.94.221.87 'bash -s' < scripts/openclaw/remote-agldv03-diag-models.sh
set -euo pipefail

K="$(grep -m1 '^LITELLM_MASTER_KEY=' /opt/litellm/.env | cut -d= -f2-)"
if [[ -z "${K:-}" ]]; then
  echo "ERRO: LITELLM_MASTER_KEY vazia em /opt/litellm/.env"
  exit 1
fi

req() {
  local model="$1"
  local body
  body="$(jq -nc --arg m "$model" '{model:$m,messages:[{role:"user",content:"Responde só com um número: quanto é 3+5?"}],max_tokens:80}')"
  echo "=== POST /v1/chat/completions model=$model ==="
  curl -sS --max-time 90 -H "Authorization: Bearer $K" -H "Content-Type: application/json" \
    http://127.0.0.1:4000/v1/chat/completions -d "$body" \
    | jq '{finish: .choices[0].finish_reason, content: .choices[0].message.content, err: .error}' 2>/dev/null \
    || echo "(curl/jq falhou)"
  echo ""
}

echo "=== /v1/models HTTP ==="
code="$(curl -s -o /dev/null -w '%{http_code}' -H "Authorization: Bearer $K" http://127.0.0.1:4000/v1/models)"
echo "HTTP $code"
echo ""

for m in \
  "openai/gpt-5.3-chat-latest" \
  "openai/gpt-5.3-instant" \
  "gpt-5.3-instant" \
  "anthropic/claude-sonnet-4-6" \
  "google/gemini-3.1-pro-preview" \
  "kimi/moonshot-v1-128k" \
  "deepseek/deepseek-chat" \
  "zai/glm-4.7-flash"
do
  req "$m" || true
done

echo "=== agent main: openai apiKey prefix (12 chars) ==="
jq -r '.providers.openai.apiKey' /root/.openclaw/agents/main/agent/models.json 2>/dev/null | head -c 12
echo ""

echo "=== agent main: max_tokens / budget (models.json) ==="
jq '{defaults: .defaults, primary: .models.primary, fallbacks: .models.fallbacks}' \
  /root/.openclaw/agents/main/agent/models.json 2>/dev/null || echo "(sem models.json)"

echo ""
echo "=== agent main: snippet auth-profiles (só keys, redacted) ==="
jq 'to_entries[] | {profile: .key, hasKey: (.value.key != null and (.value.key|length)>0)}' \
  /root/.openclaw/agents/main/agent/auth-profiles.json 2>/dev/null || true

echo ""
echo "=== openclaw.conf tem LITELLM_MASTER_KEY? ==="
if grep -q '^LITELLM_MASTER_KEY=' /root/.config/environment.d/openclaw.conf 2>/dev/null; then
  echo "sim (valor não mostrado)"
else
  echo "NÃO — gateway pode falhar providers com \${LITELLM_MASTER_KEY} no openclaw.json"
fi
