#!/usr/bin/env bash
# Testa conectividade mínima a cada API (direct), uma chamada curta por provider.
# SKIP se a chave estiver vazia. Exit 0 se todos os testes executados passarem;
# exit 1 se algum teste falhar (4xx/5xx).
#
# Quota / rate limit: OPENCLAW_SMOKE_TREAT_RATE_LIMIT=1 trata HTTP 402 e 429 como
# WARN (não falha o script). Útil em CI ou quando a chave é válida mas o plano está esgotado.

set -uo pipefail

_FAILED=0
pass() { echo "  OK $*"; }
skip() { echo "  SKIP $*"; }
warn() { echo "  WARN $*"; }
fail() { echo "  FAIL $*" >&2; _FAILED=1; }

# Uso: check_http <rótulo> <corpo_http>
check_http() {
  local _label="$1"
  local _code="$2"
  local _file="$3"
  if [[ "$_code" == "200" ]]; then
    pass "$_label"
    return 0
  fi
  if [[ -n "${OPENCLAW_SMOKE_TREAT_RATE_LIMIT:-}" ]]; then
    if [[ "$_code" == "429" || "$_code" == "402" ]]; then
      warn "${_label} HTTP ${_code} (quota/rate-limit; OPENCLAW_SMOKE_TREAT_RATE_LIMIT=1)"
      return 0
    fi
  fi
  fail "${_label} HTTP ${_code} $(head -c 220 "${_file}" 2>/dev/null)"
}

echo "=== OpenClaw direct providers — smoke HTTP ==="
if [[ -n "${OPENCLAW_SMOKE_TREAT_RATE_LIMIT:-}" ]]; then
  echo "(rate limit / 402 → WARN)"
fi

# Anthropic
if [[ -z "${ANTHROPIC_API_KEY:-}${ANTHROPIC_AUTH_TOKEN:-}" ]]; then
  skip "anthropic (sem ANTHROPIC_API_KEY)"
else
  _k="${ANTHROPIC_API_KEY:-${ANTHROPIC_AUTH_TOKEN:-}}"
  _m="${TEST_ANTHROPIC_MODEL:-claude-sonnet-4-20250514}"
  _b="$(curl -sS -o /tmp/oc-test-anthropic.json -w '%{http_code}' \
    -H "content-type: application/json" \
    -H "anthropic-version: 2023-06-01" \
    -H "x-api-key: ${_k}" \
    -d "{\"model\":\"${_m}\",\"max_tokens\":8,\"messages\":[{\"role\":\"user\",\"content\":\"ping\"}]}" \
    "https://api.anthropic.com/v1/messages")" || true
  check_http "anthropic (${_m})" "${_b}" /tmp/oc-test-anthropic.json
fi

# OpenAI
if [[ -z "${OPENAI_API_KEY:-}" ]]; then
  skip "openai (sem OPENAI_API_KEY)"
else
  _m="${TEST_OPENAI_MODEL:-gpt-4o-mini}"
  _b="$(curl -sS -o /tmp/oc-test-openai.json -w '%{http_code}' \
    -H "Authorization: Bearer ${OPENAI_API_KEY}" \
    -H "content-type: application/json" \
    -d "{\"model\":\"${_m}\",\"max_tokens\":5,\"messages\":[{\"role\":\"user\",\"content\":\"ping\"}]}" \
    "https://api.openai.com/v1/chat/completions")" || true
  check_http "openai (${_m})" "${_b}" /tmp/oc-test-openai.json
fi

# Google Gemini (API key query)
if [[ -z "${GEMINI_API_KEY:-${GOOGLE_API_KEY:-}}" ]]; then
  skip "google (sem GEMINI_API_KEY / GOOGLE_API_KEY)"
else
  _gk="${GEMINI_API_KEY:-${GOOGLE_API_KEY:-}}"
  _m="${TEST_GEMINI_MODEL:-gemini-2.0-flash}"
  _u="https://generativelanguage.googleapis.com/v1beta/models/${_m}:generateContent?key=${_gk}"
  _b="$(curl -sS -o /tmp/oc-test-gemini.json -w '%{http_code}' \
    -H "content-type: application/json" \
    -d '{"contents":[{"parts":[{"text":"ping"}]}]}' "$_u")" || true
  check_http "google (${_m})" "${_b}" /tmp/oc-test-gemini.json
fi

# Z.AI (Anthropic-compatible)
if [[ -z "${ZAI_API_KEY:-${GLM_AUTH:-}}" ]]; then
  skip "z.ai (sem ZAI_API_KEY)"
else
  _zk="${ZAI_API_KEY:-${GLM_AUTH:-}}"
  _m="${TEST_ZAI_MODEL:-glm-4.7-flash}"
  _b="$(curl -sS -o /tmp/oc-test-zai.json -w '%{http_code}' \
    -H "content-type: application/json" \
    -H "anthropic-version: 2023-06-01" \
    -H "x-api-key: ${_zk}" \
    -d "{\"model\":\"${_m}\",\"max_tokens\":8,\"messages\":[{\"role\":\"user\",\"content\":\"ping\"}]}" \
    "https://api.z.ai/api/anthropic/v1/messages")" || true
  check_http "z.ai (${_m})" "${_b}" /tmp/oc-test-zai.json
fi

# DeepSeek via OpenRouter (API direta deepseek.com desativada no catálogo OpenClaw)
if [[ -z "${OPENROUTER_API_KEY:-}" ]]; then
  skip "openrouter deepseek (sem OPENROUTER_API_KEY)"
else
  _m="${TEST_OPENROUTER_DEEPSEEK_MODEL:-deepseek/deepseek-chat}"
  _b="$(curl -sS -o /tmp/oc-test-deepseek-or.json -w '%{http_code}' \
    -H "Authorization: Bearer ${OPENROUTER_API_KEY}" \
    -H "HTTP-Referer: https://github.com/agl-hostman/openclaw" \
    -H "X-Title: agl-hostman direct-providers test" \
    -H "content-type: application/json" \
    -d "{\"model\":\"${_m}\",\"max_tokens\":8,\"messages\":[{\"role\":\"user\",\"content\":\"ping\"}]}" \
    "https://openrouter.ai/api/v1/chat/completions")" || true
  check_http "openrouter/deepseek (${_m})" "${_b}" /tmp/oc-test-deepseek-or.json
fi

# Moonshot
if [[ -z "${MOONSHOT_API_KEY:-${KIMI_API_KEY:-}}" ]]; then
  skip "moonshot (sem MOONSHOT_API_KEY)"
else
  _mk="${MOONSHOT_API_KEY:-${KIMI_API_KEY:-}}"
  _m="${TEST_MOONSHOT_MODEL:-kimi-k2.5}"
  _b="$(curl -sS -o /tmp/oc-test-moonshot.json -w '%{http_code}' \
    -H "Authorization: Bearer ${_mk}" \
    -H "content-type: application/json" \
    -d "{\"model\":\"${_m}\",\"max_tokens\":8,\"messages\":[{\"role\":\"user\",\"content\":\"ping\"}]}" \
    "https://api.moonshot.ai/v1/chat/completions")" || true
  check_http "moonshot (${_m})" "${_b}" /tmp/oc-test-moonshot.json
fi

# DashScope (OpenAI-compatible)
if [[ -z "${DASHSCOPE_API_KEY:-}" ]]; then
  skip "dashscope (sem DASHSCOPE_API_KEY)"
else
  _m="${TEST_DASHSCOPE_MODEL:-qwen-plus}"
  _b="$(curl -sS -o /tmp/oc-test-dashscope.json -w '%{http_code}' \
    -H "Authorization: Bearer ${DASHSCOPE_API_KEY}" \
    -H "content-type: application/json" \
    -d "{\"model\":\"${_m}\",\"max_tokens\":8,\"messages\":[{\"role\":\"user\",\"content\":\"ping\"}]}" \
    "https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions")" || true
  check_http "dashscope (${_m})" "${_b}" /tmp/oc-test-dashscope.json
fi

# OpenRouter
if [[ -z "${OPENROUTER_API_KEY:-}" ]]; then
  skip "openrouter (sem OPENROUTER_API_KEY)"
else
  _m="${TEST_OPENROUTER_MODEL:-openai/gpt-4o-mini}"
  _b="$(curl -sS -o /tmp/oc-test-or.json -w '%{http_code}' \
    -H "Authorization: Bearer ${OPENROUTER_API_KEY}" \
    -H "HTTP-Referer: https://github.com/openclaw/openclaw" \
    -H "X-Title: agl-hostman-smoke" \
    -H "content-type: application/json" \
    -d "{\"model\":\"${_m}\",\"max_tokens\":5,\"messages\":[{\"role\":\"user\",\"content\":\"ping\"}]}" \
    "https://openrouter.ai/api/v1/chat/completions")" || true
  check_http "openrouter (${_m})" "${_b}" /tmp/oc-test-or.json
fi

echo "=== fim ==="
exit "${_FAILED:-0}"
