#!/bin/sh
# apiKeyHelper para Claude Code + LiteLLM
# Ignora placeholders no ambiente (environment.d / templates) e lê a chave real dos ficheiros.
# Ref: config/openclaw/zshrc-openclaw-litellm.env, docs/LITELLM-TROUBLESHOOTING.md

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Valores que não existem na LiteLLM_VerificationTokenTable → 401
is_placeholder_key() {
  case "$1" in
    ''|sk-litellm-default|sk-your-secure-master-key) return 0 ;;
    *) return 1 ;;
  esac
}

if [ -n "${LITELLM_MASTER_KEY:-}" ] && ! is_placeholder_key "$LITELLM_MASTER_KEY"; then
  printf '%s' "$LITELLM_MASTER_KEY"
  exit 0
fi

# 2) Ficheiros (repo primeiro — mesmo em sandbox costuma estar no workspace)
strip_key_val() {
  _line="$1"
  _v="${_line#*=}"
  _v="${_v#\"}"
  _v="${_v%\"}"
  _v="${_v#\'}"
  _v="${_v%\'}"
  printf '%s' "$_v"
}

for ENV_FILE in "$REPO_ROOT/config/litellm/.env" "${HOME:-}/.openclaw/litellm-master.secret.env" /opt/litellm/.env; do
  if [ -f "$ENV_FILE" ]; then
    _line=$(grep -E '^(export )?LITELLM_MASTER_KEY=' "$ENV_FILE" 2>/dev/null | head -1)
    if [ -n "$_line" ]; then
      KEY=$(strip_key_val "$_line")
      if [ -n "$KEY" ] && ! is_placeholder_key "$KEY"; then
        printf '%s' "$KEY"
        exit 0
      fi
    fi
  fi
done

exit 1
