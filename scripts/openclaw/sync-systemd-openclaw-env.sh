#!/usr/bin/env bash
# Gera ~/.config/environment.d/openclaw.conf para o systemd --user do gateway OpenClaw.
#
# Reason: systemd EnvironmentFile NÃO expande ${VAR:-x}; valores literais como
# "${OPENAI_API_KEY:-$OPENAI_AUTH}" quebram LiteLLM (401 Virtual Key / auth).
#
# Fluxo: (se OPENCLAW_ENV_MODE=litellm) source litellm-gateway.env → zshrc-openclaw.env
# → exports "seguros" do ~/.zshrc (só linhas export KEY= sem "${" no valor).
# Depois escrever KEY="valor" literal para cada chave relevante.
set -euo pipefail

mkdir -p ~/.config/environment.d
CONF=~/.config/environment.d/openclaw.conf

write_kv() {
  local k="$1"
  local v="${2:-}"
  if [[ -z "$v" ]]; then
    return 0
  fi
  if [[ "$v" == *\$\{* ]]; then
    echo "AVISO: $k ainda contém \${ — não escrito." >&2
    return 0
  fi
  local v_escaped="${v//\\/\\\\}"
  v_escaped="${v_escaped//\"/\\\"}"
  printf '%s="%s"\n' "$k" "$v_escaped" >> "$CONF"
}

: > "$CONF"

set -a
# Reason: litellm-gateway.env polui ANTHROPIC_BASE_URL / LITELLM_* — só em modo LiteLLM.
if [[ "${OPENCLAW_ENV_MODE:-}" == "litellm" ]]; then
  # shellcheck source=/dev/null
  source ~/.openclaw/litellm-gateway.env 2>/dev/null || true
fi
# shellcheck source=/dev/null
source ~/.openclaw/zshrc-openclaw.env 2>/dev/null || true

# Reason: chaves reais costumam estar no .zshrc; não fazer source completo (exit/return).
if [[ -f ~/.zshrc ]]; then
  _zex="$(mktemp)"
  grep -E '^export (LITELLM_MASTER_KEY|LITELLM_API_KEY|LITELLM_GATEWAY_URL|OPENAI_AUTH|OPENAI_URL|OPENAI_API_KEY|OPENROUTER_AUTH|OPENROUTER_URL|OPENROUTER_API_KEY|GEMINI_AUTH|GEMINI_URL|GEMINI_API_KEY|GOOGLE_API_KEY|KIMI_AUTH|KIMI_URL|MOONSHOT_API_KEY|DEEPSEEK_AUTH|DEEPSEEK_URL|DEEPSEEK_API_KEY|ZAI_API_KEY|GLM_AUTH|GLM_URL|DASHSCOPE_API_KEY|DASHSCOPE_URL|ANTHROPIC_BASE_URL|ANTHROPIC_API_KEY|ANTHROPIC_AUTH_TOKEN)=' \
    ~/.zshrc 2>/dev/null | grep -vF '${' > "$_zex" || true
  if [[ -s "$_zex" ]]; then
    # shellcheck source=/dev/null
    source "$_zex" || true
  fi
  rm -f "$_zex"
fi
set +a

# Modo direct (OpenClaw → providers): não injectar proxy Anthropic nem URL DeepSeek errada.
if [[ "${ANTHROPIC_BASE_URL:-}" == *":4000"* || "${ANTHROPIC_BASE_URL:-}" == *"litellm"* ]]; then
  echo "AVISO: ANTHROPIC_BASE_URL aponta para LiteLLM — omitindo no gateway (usa api.anthropic.com com ANTHROPIC_API_KEY)." >&2
  ANTHROPIC_BASE_URL=""
fi
if [[ "${DEEPSEEK_URL:-}" == *"/anthropic"* ]]; then
  echo "AVISO: DEEPSEEK_URL com /anthropic quebra o provider OpenAI-compat — usar https://api.deepseek.com/v1" >&2
  DEEPSEEK_URL="https://api.deepseek.com/v1"
fi
if [[ "${ANTHROPIC_API_KEY:-}" == "sk-optional" ]]; then
  ANTHROPIC_API_KEY=""
fi
if [[ "${ANTHROPIC_AUTH_TOKEN:-}" == "sk-litellm-default" ]]; then
  ANTHROPIC_AUTH_TOKEN=""
fi
if [[ "${OPENROUTER_URL:-}" == "https://openrouter.ai/api" || "${OPENROUTER_URL:-}" == "https://openrouter.ai/api/" ]]; then
  OPENROUTER_URL="https://openrouter.ai/api/v1"
fi

if [[ "${OPENCLAW_ENV_MODE:-}" == "litellm" ]]; then
  write_kv LITELLM_MASTER_KEY "${LITELLM_MASTER_KEY:-}"
  write_kv LITELLM_API_KEY "${LITELLM_API_KEY:-${LITELLM_MASTER_KEY:-}}"
  write_kv LITELLM_GATEWAY_URL "${LITELLM_GATEWAY_URL:-}"
  if [[ -n "${ANTHROPIC_BASE_URL:-}" ]]; then
    write_kv ANTHROPIC_BASE_URL "${ANTHROPIC_BASE_URL}"
  fi
fi

write_kv GLM_AUTH "${GLM_AUTH:-}"
write_kv ZAI_API_KEY "${ZAI_API_KEY:-${GLM_AUTH:-}}"
write_kv GLM_URL "${GLM_URL:-}"

write_kv KIMI_AUTH "${KIMI_AUTH:-}"
write_kv MOONSHOT_API_KEY "${MOONSHOT_API_KEY:-${KIMI_AUTH:-}}"
write_kv KIMI_URL "${KIMI_URL:-}"

write_kv DEEPSEEK_AUTH "${DEEPSEEK_AUTH:-}"
write_kv DEEPSEEK_API_KEY "${DEEPSEEK_API_KEY:-${DEEPSEEK_AUTH:-}}"
write_kv DEEPSEEK_URL "${DEEPSEEK_URL:-}"

write_kv OPENAI_AUTH "${OPENAI_AUTH:-}"
write_kv OPENAI_API_KEY "${OPENAI_API_KEY:-${OPENAI_AUTH:-}}"
write_kv OPENAI_URL "${OPENAI_URL:-}"

write_kv GEMINI_AUTH "${GEMINI_AUTH:-}"
write_kv GEMINI_API_KEY "${GEMINI_API_KEY:-${GEMINI_AUTH:-}}"
write_kv GEMINI_URL "${GEMINI_URL:-}"

write_kv OPENROUTER_AUTH "${OPENROUTER_AUTH:-}"
write_kv OPENROUTER_API_KEY "${OPENROUTER_API_KEY:-${OPENROUTER_AUTH:-}}"
write_kv OPENROUTER_URL "${OPENROUTER_URL:-}"

write_kv DASHSCOPE_API_KEY "${DASHSCOPE_API_KEY:-}"
write_kv DASHSCOPE_URL "${DASHSCOPE_URL:-}"

if [[ -n "${ANTHROPIC_API_KEY:-}" ]]; then
  write_kv ANTHROPIC_API_KEY "${ANTHROPIC_API_KEY}"
fi
if [[ -n "${ANTHROPIC_AUTH_TOKEN:-}" ]]; then
  write_kv ANTHROPIC_AUTH_TOKEN "${ANTHROPIC_AUTH_TOKEN}"
fi
if [[ -n "${GOOGLE_API_KEY:-}" ]]; then
  write_kv GOOGLE_API_KEY "${GOOGLE_API_KEY}"
fi

# Token WS do gateway (CLI: openclaw agent / gateway call).
OC_JSON="${OPENCLAW_JSON:-$HOME/.openclaw/openclaw.json}"
if [[ -f "$OC_JSON" ]] && command -v jq >/dev/null 2>&1; then
  _gw_tok="$(jq -r '.gateway.auth.token // empty' "$OC_JSON" 2>/dev/null || true)"
  if [[ -n "${_gw_tok:-}" && "$_gw_tok" != "null" ]]; then
    write_kv OPENCLAW_GATEWAY_TOKEN "$_gw_tok"
  fi
fi

echo "env OK -> $CONF"
