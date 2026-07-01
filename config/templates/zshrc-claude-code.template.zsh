# =============================================================================
# Claude Code — bloco zsh AGL (template sem secrets)
# Copiar para ~/.zshrc ou fazer source a partir do agl-hostman.
# Wiki: [[agl-hostman — Claude Code Shell zsh]] (llm-wiki)
# =============================================================================

export IS_SANDBOX="${IS_SANDBOX:-1}"

# --- URLs e chaves (substituir placeholders; NÃO commitar valores reais) ---
export LITELLM_GATEWAY_URL="${LITELLM_GATEWAY_URL:-http://TAILSCALE_CT186_IP:4000}"
export LITELLM_MASTER_KEY="${LITELLM_MASTER_KEY:-}"   # sk-litellm-… em ~/.openclaw/litellm-master.secret.env

export GLM_URL="${GLM_URL:-https://api.z.ai/api/anthropic}"
export ZAI_API_KEY="${ZAI_API_KEY:-your-zai-api-key}"

export KIMI_URL="${KIMI_URL:-https://api.moonshot.ai/anthropic}"
export MOONSHOT_API_KEY="${MOONSHOT_API_KEY:-your-moonshot-key}"

export DEEPSEEK_URL="${DEEPSEEK_URL:-https://api.deepseek.com/anthropic}"
export DEEPSEEK_API_KEY="${DEEPSEEK_API_KEY:-your-deepseek-key}"

export OPENROUTER_URL="${OPENROUTER_URL:-https://openrouter.ai/api}"
export OPENROUTER_API_KEY="${OPENROUTER_API_KEY:-your-openrouter-key}"

# Repo agl-hostman (ajustar path)
_AGL_HOSTMAN="${AGL_HOSTMAN_ROOT:-/path/to/agl-hostman}"

# --- helpers internos ---
_claude_use_dsp() {
    [[ $EUID -eq 0 ]] && return 1
    [[ -n "$IS_SANDBOX" && "$IS_SANDBOX" != "0" ]]
}

cc_envs_all() {
    export API_TIMEOUT_MS="${API_TIMEOUT_MS:-3000000}"
    export CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC="${CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC:-0}"
    unset CLAUDE_CODE_USE_BEDROCK
}

cc_envs() {
    export CC_PROVIDER=direct
    export ANTHROPIC_API_KEY=""
    export ANTHROPIC_AUTH_TOKEN="$MODEL_AUTH_TOKEN"
    export ANTHROPIC_BASE_URL="$MODEL_BASE_URL"
    export ANTHROPIC_MODEL="$MODEL_ROBUST"
    export ANTHROPIC_SMALL_FAST_MODEL="$MODEL_FAST"
    cc_envs_all
}

cc_envs3() {
    export CC_PROVIDER=anthropic
    unset MODEL_ROBUST MODEL_FAST MODEL_BASE_URL MODEL_AUTH_TOKEN
    unset ANTHROPIC_API_KEY ANTHROPIC_AUTH_TOKEN ANTHROPIC_BASE_URL
    unset ANTHROPIC_MODEL ANTHROPIC_DEFAULT_SONNET_MODEL ANTHROPIC_DEFAULT_OPUS_MODEL
    unset ANTHROPIC_DEFAULT_HAIKU_MODEL ANTHROPIC_SMALL_FAST_MODEL
    cc_envs_all
}

_cc_provider_settings_args() {
  case "${CC_PROVIDER:-litellm}" in
    litellm)
      local settings="${HOME}/.claude/settings-litellm.json"
      if [[ -f ".claude/settings.litellm.json" ]]; then
        settings="$(pwd)/.claude/settings.litellm.json"
      fi
      [[ -f "$settings" ]] || return 1
      export ANTHROPIC_BASE_URL="${ANTHROPIC_BASE_URL:-${LITELLM_GATEWAY_URL}}"
      export ANTHROPIC_MODEL="${ANTHROPIC_MODEL:-${AGL_CC_MODEL_DEFAULT:-agl-primary}}"
      export ANTHROPIC_DEFAULT_SONNET_MODEL="${ANTHROPIC_DEFAULT_SONNET_MODEL:-${AGL_CC_MODEL_SONNET:-agl-primary}}"
      export ANTHROPIC_DEFAULT_OPUS_MODEL="${ANTHROPIC_DEFAULT_OPUS_MODEL:-${AGL_CC_MODEL_OPUS:-agl-primary-strong}}"
      export ANTHROPIC_DEFAULT_HAIKU_MODEL="${ANTHROPIC_DEFAULT_HAIKU_MODEL:-${AGL_CC_MODEL_HAIKU:-agl-primary-zai-glm-flash}}"
      export ANTHROPIC_SMALL_FAST_MODEL="${ANTHROPIC_SMALL_FAST_MODEL:-${AGL_CC_MODEL_HAIKU:-agl-primary-zai-glm-flash}}"
      unset ANTHROPIC_API_KEY ANTHROPIC_AUTH_TOKEN
      REPLY=(--bare --settings "$settings")
      return 0
      ;;
    direct)
      local base="${ANTHROPIC_BASE_URL:-${MODEL_BASE_URL:-}}"
      [[ -n "$base" ]] || return 1
      REPLY=(--bare --settings "{\"env\":{\"ANTHROPIC_BASE_URL\":\"${base}\",\"ANTHROPIC_API_KEY\":\"${ANTHROPIC_AUTH_TOKEN:-${MODEL_AUTH_TOKEN:-}}\",\"ANTHROPIC_AUTH_TOKEN\":\"\"}}")
      return 0
      ;;
    anthropic|*)
      local settings="${HOME}/.claude/settings-anthropic.json"
      [[ -f "$settings" ]] || return 1
      unset ANTHROPIC_API_KEY ANTHROPIC_AUTH_TOKEN ANTHROPIC_BASE_URL
      unset ANTHROPIC_MODEL ANTHROPIC_DEFAULT_SONNET_MODEL ANTHROPIC_DEFAULT_OPUS_MODEL
      unset ANTHROPIC_DEFAULT_HAIKU_MODEL ANTHROPIC_SMALL_FAST_MODEL
      REPLY=(--settings "$settings")
      return 0
      ;;
  esac
}

# cc  — sessão interactiva (TUI)
cc() {
    local -a cmd=()
    if _cc_provider_settings_args; then cmd=("${REPLY[@]}"); fi
    if _claude_use_dsp; then
        claude "${cmd[@]}" --dangerously-skip-permissions "$@"
    else
        claude "${cmd[@]}" "$@"
    fi
}

# ccs — one-shot (claude -p), imprime e sai
ccs() {
    local -a cmd=(claude)
    if _cc_provider_settings_args; then cmd+=("${REPLY[@]}"); fi
    cmd+=(-p --output-format text)
    if _claude_use_dsp; then
        cmd+=(--dangerously-skip-permissions)
    elif [[ $EUID -eq 0 && -n "${IS_SANDBOX:-}" && "${IS_SANDBOX}" != "0" ]]; then
        cmd+=(--dangerously-skip-permissions)
    fi
    [[ $# -gt 0 ]] || { echo "Uso: ccs 'prompt'" >&2; return 1; }
    "${cmd[@]}" "$@" < /dev/null
}

# cccl — Anthropic Cloud (OAuth / Pro)
cccl() {
    cc_envs3
    echo "✅ Anthropic Cloud (CC_PROVIDER=anthropic, OAuth)"
}

# ccll — LiteLLM gateway CT186
ccll() {
    export CC_PROVIDER=litellm
    export LITELLM_GATEWAY_URL="${LITELLM_GATEWAY_URL:-http://TAILSCALE_CT186_IP:4000}"
    export ANTHROPIC_BASE_URL="${LITELLM_GATEWAY_URL}"
    export ANTHROPIC_MODEL="${AGL_CC_MODEL_DEFAULT:-agl-primary-zai-glm-flash}"
    export ANTHROPIC_DEFAULT_SONNET_MODEL="${AGL_CC_MODEL_SONNET:-agl-primary-zai-glm-flash}"
    export ANTHROPIC_DEFAULT_OPUS_MODEL="${AGL_CC_MODEL_OPUS:-agl-primary-strong}"
    export ANTHROPIC_DEFAULT_HAIKU_MODEL="${AGL_CC_MODEL_HAIKU:-agl-primary-zai-glm-flash}"
    export ANTHROPIC_SMALL_FAST_MODEL="${AGL_CC_MODEL_HAIKU:-agl-primary-zai-glm-flash}"
    if [[ -z "${LITELLM_MASTER_KEY:-}" && -r "${HOME}/.openclaw/litellm-master.secret.env" ]]; then
        source "${HOME}/.openclaw/litellm-master.secret.env"
    fi
    unset ANTHROPIC_API_KEY ANTHROPIC_AUTH_TOKEN
    echo "✓ LiteLLM: $ANTHROPIC_BASE_URL [${AGL_CC_MODEL_DEFAULT:-agl-primary-zai-glm-flash}]"
}

# ccz — Z.AI directo (GLM-5)
ccz() {
    export MODEL_ROBUST="glm-5"
    export MODEL_FAST="glm-5-air"
    export MODEL_BASE_URL="$GLM_URL"
    export MODEL_AUTH_TOKEN="$ZAI_API_KEY"
    cc_envs
    echo "✓ Z.AI directo ($MODEL_BASE_URL)"
}

# --- arranque: LiteLLM por defeito (comentar se preferires Anthropic) ---
export OPENCLAW_ENV_MODE=litellm
[[ -f "${_AGL_HOSTMAN}/config/openclaw/zshrc-openclaw.env" ]] && source "${_AGL_HOSTMAN}/config/openclaw/zshrc-openclaw.env"
ccll
