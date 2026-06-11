#!/usr/bin/env bash
# Smoke LiteLLM nos LXC dedicados (CT186 LAN / Tailscale).
# Executar a partir de agldv03 ou host com rota para o gateway.
#
# Exemplos:
#   LITELLM_URL=http://192.168.0.186:4000 LITELLM_API_KEY=sk-… ./scripts/litellm/smoke-dedicated-lxc.sh
#   LITELLM_URL=http://100.x.x.x:4000 ./scripts/litellm/smoke-dedicated-lxc.sh   # Tailscale CT186
#
# Chave: LITELLM_API_KEY, ou master_key em config/litellm/.env (não imprimir).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LITELLM_URL="${LITELLM_URL:-http://192.168.0.186:4000}"
BASE="${LITELLM_URL%/}/v1/chat/completions"
HEALTH_URL="${LITELLM_URL%/}/health"

if [[ -z "${LITELLM_API_KEY:-}" ]]; then
  ENV_FILE="${LITELLM_ENV_FILE:-$ROOT/config/litellm/.env}"
  if [[ -f "$ENV_FILE" ]]; then
    # shellcheck disable=SC1090
    set -a && source "$ENV_FILE" && set +a
    LITELLM_API_KEY="${LITELLM_MASTER_KEY:-${LITELLM_API_KEY:-}}"
  fi
fi

if [[ -z "${LITELLM_API_KEY:-}" ]] && [[ -f "${HERMES_CONFIG:-/root/.hermes/config.yaml}" ]]; then
  LITELLM_API_KEY="$(awk '/^[[:space:]]*api_key:/{gsub(/"/,"",$2); print $2; exit}' "${HERMES_CONFIG}")"
fi

if [[ -z "${LITELLM_API_KEY:-}" ]]; then
  echo "ERRO: defina LITELLM_API_KEY ou configure config/litellm/.env" >&2
  exit 1
fi

echo "==> health $HEALTH_URL"
health_code="$(curl -sS -o /tmp/litellm-health.json -w '%{http_code}' "$HEALTH_URL" || echo 000)"
echo "    HTTP $health_code"

MODELS=(
  cursor-composer
  qwen-coder
  glm-flash
  zai/glm-4.7-flash
  ollama-qwen3-4b
  ollama-gemma3-4b
)

fail=0
for m in "${MODELS[@]}"; do
  code="$(curl -sS -o /tmp/litellm-smoke-lxc.json -w '%{http_code}' -X POST "$BASE" \
    -H "Authorization: Bearer $LITELLM_API_KEY" \
    -H "Content-Type: application/json" \
    -d "{\"model\":\"$m\",\"messages\":[{\"role\":\"user\",\"content\":\"Reply exactly: PONG\"}],\"max_tokens\":16}" || echo 000)"
  if command -v jq >/dev/null 2>&1; then
    err="$(jq -r '.error.message // empty' /tmp/litellm-smoke-lxc.json 2>/dev/null | head -c 160)"
    content="$(jq -r '.choices[0].message.content // empty' /tmp/litellm-smoke-lxc.json 2>/dev/null | head -c 80)"
  else
    err=""
    content=""
  fi
  if [[ "$code" == "200" && -z "$err" ]]; then
    echo "OK  $m  HTTP=$code  ${content//$'\n'/ }"
  else
    echo "BAD $m  HTTP=$code  err=${err//$'\n'/ }"
    fail=1
  fi
done

exit "$fail"
