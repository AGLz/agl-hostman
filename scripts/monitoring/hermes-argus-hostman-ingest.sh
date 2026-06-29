#!/usr/bin/env bash
# Argus — push quota-governor state para Laravel CT134 (LLM Monitor API).
#
# Uso:
#   HOSTMAN_API_KEY=... bash hermes-argus-hostman-ingest.sh
#
# Env:
#   HOSTMAN_API_URL     default http://192.168.0.134
#   HOSTMAN_API_KEY     obrigatório (services.hostman.api_key no CT134)
#   GOVERNOR_STATE_FILE default /var/log/hostman/quota-governor-state.json

set -euo pipefail

_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_ENV_HOSTMAN="${_SCRIPT_DIR}/../.env.hostman"
if [[ -f "${_ENV_HOSTMAN}" ]]; then
  set -a
  # shellcheck source=/dev/null
  source "${_ENV_HOSTMAN}"
  set +a
fi

HOSTMAN_API_URL="${HOSTMAN_API_URL:-http://192.168.0.134}"
HOSTMAN_API_KEY="${HOSTMAN_API_KEY:-${API_KEY:-}}"
GOVERNOR_STATE_FILE="${GOVERNOR_STATE_FILE:-/var/log/hostman/quota-governor-state.json}"

if [[ -z "${HOSTMAN_API_KEY}" ]]; then
  echo "[argus-ingest] ERRO: HOSTMAN_API_KEY em falta" >&2
  exit 1
fi

if [[ ! -f "${GOVERNOR_STATE_FILE}" ]]; then
  echo "[argus-ingest] AVISO: sem estado em ${GOVERNOR_STATE_FILE} — skip"
  exit 0
fi

url="${HOSTMAN_API_URL%/}/api/llm-monitor/ingest"
code="$(curl -sS -o /tmp/argus-ingest-$$.json -w '%{http_code}' --max-time 30 \
  -H "X-API-Key: ${HOSTMAN_API_KEY}" \
  -H "Content-Type: application/json" \
  -d @"${GOVERNOR_STATE_FILE}" \
  "${url}" 2>/dev/null || echo 000)"

if [[ "${code}" == "200" ]]; then
  written="$(jq -r '.records_written // 0' /tmp/argus-ingest-$$.json 2>/dev/null || echo '?')"
  echo "[argus-ingest] OK records_written=${written}"
  rm -f /tmp/argus-ingest-$$.json
  exit 0
fi

echo "[argus-ingest] FALHA http=${code}" >&2
head -c 500 /tmp/argus-ingest-$$.json 2>/dev/null >&2 || true
rm -f /tmp/argus-ingest-$$.json
exit 1
