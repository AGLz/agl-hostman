#!/usr/bin/env bash
# Auditoria de providers para decisão de modelos (Hermes / LiteLLM CT186).
# Não imprime valores de API keys.
#
# Uso:
#   bash scripts/litellm/audit-providers-hermes.sh
#   LITELLM_ENV=/opt/agl-litellm/.env LITELLM_GATEWAY=http://127.0.0.1:4000 bash ...
#
set -euo pipefail

ENV_FILE="${LITELLM_ENV:-/opt/agl-litellm/.env}"
GATEWAY="${LITELLM_GATEWAY:-http://127.0.0.1:4000}"
TIMEOUT_DIRECT="${TIMEOUT_DIRECT:-30}"
TIMEOUT_PROXY="${TIMEOUT_PROXY:-75}"
TIMEOUT_OLLAMA="${TIMEOUT_OLLAMA:-25}"

if [[ -f "$ENV_FILE" ]]; then
  set -a
  # shellcheck source=/dev/null
  source "$ENV_FILE"
  set +a
else
  echo "AVISO: $ENV_FILE não encontrado" >&2
fi

KEY="${LITELLM_MASTER_KEY:-}"
CHAT_PROXY="${GATEWAY%/}/v1/chat/completions"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

now_ms() { date +%s%3N 2>/dev/null || python3 -c 'import time; print(int(time.time()*1000))'; }

classify() {
  local code="$1" snippet="$2"
  if [[ "$code" == "200" ]] && [[ "$snippet" == OK:* ]]; then
    echo "OK"
  elif [[ "$snippet" == *1310* ]] || [[ "$snippet" == *quota* ]] || [[ "$snippet" == *Quota* ]] || [[ "$snippet" == *rate_limit* ]] || [[ "$code" == "429" ]]; then
    echo "QUOTA"
  elif [[ "$code" == "401" ]] || [[ "$code" == "403" ]]; then
    echo "AUTH"
  elif [[ "$code" == "404" ]]; then
    echo "404"
  elif [[ "$code" == "000" ]]; then
    echo "TIMEOUT"
  else
    echo "FAIL($code)"
  fi
}

probe_post() {
  local id="$1" label="$2" url="$3" auth="$4" body="$5" timeout="$6"
  local out="$tmpdir/${id}.json" code t0 t1 dt snippet st detail
  t0="$(now_ms)"
  code="$(curl -sS -o "$out" -w "%{http_code}" --max-time "$timeout" \
    -H "Authorization: ${auth}" \
    -H "Content-Type: application/json" \
    -d "$body" "$url" 2>/dev/null || echo "000")"
  t1="$(now_ms)"
  dt=$((t1 - t0))
  snippet="$(python3 - "$out" <<'PY' 2>/dev/null || echo "ERR:parse"
import json, sys
p = sys.argv[1]
raw = open(p).read()
if not raw.strip():
    print("ERR:empty")
    raise SystemExit
try:
    d = json.loads(raw)
except Exception:
    print("ERR:" + raw[:90].replace("\n", " "))
    raise SystemExit
if "error" in d:
    e = d["error"]
    if isinstance(e, dict):
        print("ERR:" + str(e.get("code") or e.get("type") or "") + ":" + str(e.get("message") or e)[:90])
    else:
        print("ERR:" + str(e)[:90])
elif "choices" in d and d["choices"]:
    m = d["choices"][0].get("message") or {}
    c = (m.get("content") or m.get("reasoning_content") or "").strip()[:40]
    print("OK:" + repr(c) + " upstream=" + str(d.get("model", "")))
elif "content" in d:
    t = ""
    for part in d.get("content") or []:
        if isinstance(part, dict):
            t += part.get("text") or ""
    print("OK:" + repr(t[:40]) + " upstream=gemini")
elif "data" in d:
    print("OK:models=" + str(len(d.get("data") or [])))
else:
    print("ERR:" + str(d)[:90])
PY
)"
  st="$(classify "$code" "$snippet")"
  detail="${snippet#OK:}"
  [[ "$snippet" == ERR:* ]] && detail="${snippet#ERR:}"
  printf "| %s | %s | %s | %sms | %s |\n" "$id" "$label" "$st" "$dt" "$detail"
}

probe_get() {
  local id="$1" label="$2" url="$3" auth="$4" timeout="$5"
  probe_post "$id" "$label" "$url" "$auth" '{}' "$timeout"
}

echo "# Auditoria providers — $(date -Iseconds 2>/dev/null || date)"
echo ""
echo "Env: \`$ENV_FILE\` | Gateway: \`$GATEWAY\`"
echo ""
echo "## 1. APIs directas"
echo ""
echo "| ID | Teste | Estado | ms | Detalhe |"
echo "|----|-------|--------|-----|---------|"

if [[ -n "${OPENAI_API_KEY:-}" ]]; then
  for m in gpt-5-nano gpt-5-mini gpt-4o-mini; do
    probe_post "openai-$m" "OpenAI $m" "https://api.openai.com/v1/chat/completions" "Bearer $OPENAI_API_KEY" \
      "{\"model\":\"$m\",\"messages\":[{\"role\":\"user\",\"content\":\"OK\"}],\"max_tokens\":12}" "$TIMEOUT_DIRECT"
  done
else
  echo "| openai | OpenAI | SKIP | — | OPENAI_API_KEY ausente |"
fi

if [[ -n "${ANTHROPIC_API_KEY:-}" ]]; then
  probe_post "anthropic-haiku" "Anthropic claude-haiku-4-5" "https://api.anthropic.com/v1/messages" "Bearer $ANTHROPIC_API_KEY" \
    '{"model":"claude-haiku-4-5-20251001","max_tokens":12,"messages":[{"role":"user","content":"OK"}]}' "$TIMEOUT_DIRECT"
else
  echo "| anthropic | Anthropic | SKIP | — | ausente |"
fi

if [[ -n "${ZAI_API_KEY:-}" ]]; then
  probe_post "zai-ant-flash" "Z.AI Anthropic glm-4.5-flash" "https://api.z.ai/api/anthropic/v1/messages" "Bearer $ZAI_API_KEY" \
    '{"model":"glm-4.5-flash","max_tokens":12,"messages":[{"role":"user","content":"OK"}]}' "$TIMEOUT_DIRECT"
  probe_post "zai-ant-glm5" "Z.AI Anthropic glm-5" "https://api.z.ai/api/anthropic/v1/messages" "Bearer $ZAI_API_KEY" \
    '{"model":"glm-5","max_tokens":12,"messages":[{"role":"user","content":"OK"}]}' "$TIMEOUT_DIRECT"
  probe_post "zai-oai-flash" "Z.AI OpenAI-v1 glm-4.7-flash" "https://api.z.ai/api/openai/v1/chat/completions" "Bearer $ZAI_API_KEY" \
    '{"model":"glm-4.7-flash","messages":[{"role":"user","content":"OK"}],"max_tokens":12}' "$TIMEOUT_DIRECT"
else
  echo "| zai | Z.AI | SKIP | — | ausente |"
fi

if [[ -n "${DEEPSEEK_API_KEY:-}" ]]; then
  probe_post "deepseek" "DeepSeek deepseek-chat" "https://api.deepseek.com/chat/completions" "Bearer $DEEPSEEK_API_KEY" \
    '{"model":"deepseek-chat","messages":[{"role":"user","content":"OK"}],"max_tokens":12}' "$TIMEOUT_DIRECT"
else
  echo "| deepseek | DeepSeek | SKIP | — | ausente |"
fi

if [[ -n "${GEMINI_API_KEY:-}" ]]; then
  probe_post "gemini-lite" "Gemini 2.5-flash-lite" \
    "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-lite:generateContent?key=${GEMINI_API_KEY}" \
    "Bearer x" '{"contents":[{"parts":[{"text":"OK"}]}]}' "$TIMEOUT_DIRECT"
else
  echo "| gemini | Gemini | SKIP | — | ausente |"
fi

if [[ -n "${OPENROUTER_API_KEY:-}" ]]; then
  probe_post "or-minimax" "OR minimax-m2.5:free" "https://openrouter.ai/api/v1/chat/completions" "Bearer $OPENROUTER_API_KEY" \
    '{"model":"openrouter/minimax/minimax-m2.5:free","messages":[{"role":"user","content":"OK"}],"max_tokens":12}' 90
  probe_post "or-mistral" "OR mistral-small:free" "https://openrouter.ai/api/v1/chat/completions" "Bearer $OPENROUTER_API_KEY" \
    '{"model":"openrouter/mistralai/mistral-small-3.1-24b-instruct:free","messages":[{"role":"user","content":"OK"}],"max_tokens":12}' 90
  probe_post "or-nemotron" "OR nemotron-super:free" "https://openrouter.ai/api/v1/chat/completions" "Bearer $OPENROUTER_API_KEY" \
    '{"model":"openrouter/nvidia/nemotron-3-super-120b-a12b:free","messages":[{"role":"user","content":"OK"}],"max_tokens":12}' 90
  probe_post "or-gemma4b" "OR gemma-3-4b:free" "https://openrouter.ai/api/v1/chat/completions" "Bearer $OPENROUTER_API_KEY" \
    '{"model":"openrouter/google/gemma-3-4b-it:free","messages":[{"role":"user","content":"OK"}],"max_tokens":12}' 90
else
  echo "| openrouter | OpenRouter | SKIP | — | ausente |"
fi

if [[ -n "${MOONSHOT_API_KEY:-}" ]]; then
  probe_post "moonshot" "Moonshot moonshot-v1-8k" "https://api.moonshot.cn/v1/chat/completions" "Bearer $MOONSHOT_API_KEY" \
    '{"model":"moonshot-v1-8k","messages":[{"role":"user","content":"OK"}],"max_tokens":12}' "$TIMEOUT_DIRECT"
else
  echo "| moonshot | Moonshot | SKIP | — | ausente |"
fi

for g in GROQ_API_KEY GROQ_API_KEY2; do
  val="${!g:-}"
  if [[ -n "$val" ]]; then
    t0="$(now_ms)"
    code="$(curl -sS -o "$tmpdir/${g}.json" -w "%{http_code}" --max-time 15 \
      -H "Authorization: Bearer $val" "https://api.groq.com/openai/v1/models" 2>/dev/null || echo "000")"
    t1="$(now_ms)"
    st="$(classify "$code" "$( [[ "$code" == "200" ]] && echo OK:models || echo ERR:$code )")"
    printf "| %s | Groq %s /models | %s | %sms | HTTP %s |\n" "${g,,}" "$g" "$st" "$((t1-t0))" "$code"
  else
    echo "| ${g,,} | Groq $g | SKIP | — | não definida |"
  fi
done

probe_post "ollama" "Ollama qwen3:4b @100.74.118.51" "http://100.74.118.51:11434/api/chat" "Bearer ollama" \
  '{"model":"qwen3:4b","messages":[{"role":"user","content":"OK"}],"stream":false,"options":{"num_predict":8}}' "$TIMEOUT_OLLAMA"

echo ""
echo "## 2. LiteLLM proxy (aliases Hermes)"
echo ""
echo "| Alias | Estado | ms | Detalhe |"
echo "|-------|--------|-----|---------|"

if [[ -z "$KEY" ]]; then
  echo "| — | — | SKIP | — | LITELLM_MASTER_KEY ausente |"
else
  for alias in gpt-5-mini gpt-5-nano gpt-4o-mini gpt-5.5 glm-4.7-flash zai-glm-flash zai-glm-5 qwen-coder gemini-lite or-mistral-small-free or-minimax-m2.5-free or-nemotron-super-free ollama-qwen3-4b agl-primary; do
    out="$tmpdir/p-${alias}.json"
    t0="$(now_ms)"
    code="$(curl -sS -o "$out" -w "%{http_code}" --max-time "$TIMEOUT_PROXY" \
      -H "Authorization: Bearer $KEY" \
      -H "Content-Type: application/json" \
      -d "{\"model\":\"$alias\",\"messages\":[{\"role\":\"user\",\"content\":\"OK\"}],\"max_tokens\":12}" \
      "$CHAT_PROXY" 2>/dev/null || echo "000")"
    t1="$(now_ms)"
    snippet="$(python3 - "$out" <<'PY' 2>/dev/null || echo "ERR:parse"
import json, sys
raw = open(sys.argv[1]).read()
if not raw.strip():
    print("ERR:empty"); raise SystemExit
d = json.loads(raw)
if d.get("error"):
    e = d["error"]
    msg = (e.get("message") if isinstance(e, dict) else str(e))[:95]
    print("ERR:" + msg)
else:
    m = d["choices"][0]["message"]
    c = (m.get("content") or m.get("reasoning_content") or "").strip()[:40]
    print("OK:" + repr(c) + " upstream=" + str(d.get("model","")))
PY
)"
    st="$(classify "$code" "$snippet")"
    detail="${snippet#OK:}"
    [[ "$snippet" == ERR:* ]] && detail="${snippet#ERR:}"
    printf "| %s | %s | %sms | %s |\n" "$alias" "$st" "$((t1-t0))" "$detail"
  done
fi

echo ""
echo "## 3. Chaves no .env (tamanho, sem valor)"
echo ""
for v in OPENAI_API_KEY ANTHROPIC_API_KEY ZAI_API_KEY DEEPSEEK_API_KEY GEMINI_API_KEY \
  OPENROUTER_API_KEY MOONSHOT_API_KEY GROQ_API_KEY GROQ_API_KEY2 DASHSCOPE_API_KEY; do
  if [[ -n "${!v:-}" ]]; then
    eval "len=\${#${v}}"
    echo "- **$v**: definida (${len} caracteres)"
  else
    echo "- $v: ausente"
  fi
done
