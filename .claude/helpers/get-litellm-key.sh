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

# 2) Ficheiros — localhost: chave em /opt/litellm; remoto: repo ou ~/.openclaw
strip_key_val() {
  _line="$1"
  _v="${_line#*=}"
  _v="${_v#\"}"
  _v="${_v%\"}"
  _v="${_v#\'}"
  _v="${_v%\'}"
  printf '%s' "$_v"
}

read_key_from_file() {
  ENV_FILE="$1"
  [ -f "$ENV_FILE" ] || return 1
  _line=$(grep -E '^(export )?LITELLM_MASTER_KEY=' "$ENV_FILE" 2>/dev/null | head -1)
  [ -n "$_line" ] || return 1
  KEY=$(strip_key_val "$_line")
  [ -n "$KEY" ] && ! is_placeholder_key "$KEY"
}

_gateway="${LITELLM_GATEWAY_URL:-${ANTHROPIC_BASE_URL:-}}"
case "$_gateway" in
  *localhost*|*127.0.0.1*)
    for ENV_FILE in /opt/litellm/.env "${HOME:-}/.openclaw/litellm-master.secret.env" "$REPO_ROOT/config/litellm/.env"; do
      if read_key_from_file "$ENV_FILE"; then
        printf '%s' "$KEY"
        exit 0
      fi
    done
    ;;
  *)
    for ENV_FILE in "${HOME:-}/.openclaw/litellm-master.secret.env" "$REPO_ROOT/config/litellm/.env" /opt/litellm/.env; do
      if read_key_from_file "$ENV_FILE"; then
        printf '%s' "$KEY"
        exit 0
      fi
    done
    ;;
esac
unset _gateway KEY _line _v ENV_FILE

exit 1
