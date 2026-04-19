#!/usr/bin/env bash
# Reason: LITELLM_MASTER_KEY pode estar só em env, em .env ou ausente (proxy sem auth).
# Escreve apenas a chave em stdout; sem saída se não existir (exit 0).

ENV_FILE="${LITELLM_ENV_FILE:-/opt/litellm/.env}"

_emit() {
  printf '%s' "$1"
  exit 0
}

if [[ -n "${LITELLM_MASTER_KEY:-}" ]]; then
  _emit "${LITELLM_MASTER_KEY}"
fi

k=""
if [[ -r "$ENV_FILE" ]]; then
  k=$(grep -m1 '^LITELLM_MASTER_KEY=' "$ENV_FILE" 2>/dev/null | cut -d= -f2- || true)
fi
k="${k//$'\r'/}"
k="${k//\"/}"

if [[ -n "$k" ]]; then
  _emit "$k"
fi

if command -v docker >/dev/null 2>&1; then
  if docker ps --format '{{.Names}}' 2>/dev/null | grep -qx 'litellm-proxy'; then
    dk=$(docker exec litellm-proxy printenv LITELLM_MASTER_KEY 2>/dev/null | tr -d '\r' || true)
    if [[ -n "${dk:-}" ]]; then
      _emit "$dk"
    fi
  fi
fi

exit 0
