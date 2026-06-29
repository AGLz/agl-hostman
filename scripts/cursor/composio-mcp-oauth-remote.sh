#!/usr/bin/env bash
# OAuth Composio MCP via mcp-remote — workaround Remote SSH (Cursor).
#
# IMPORTANTE: desactivar "composio" em Cursor → Tools & MCP antes de oauth-begin,
# senão várias instâncias mcp-remote sobrescrevem code_verifier e o callback falha.
#
# Fluxo:
#   1) PC local: ssh -N -L 8787:127.0.0.1:8787 root@<agldv04>
#   2) Remoto:   bash scripts/cursor/composio-mcp-oauth-remote.sh reset
#   3) Remoto:   bash scripts/cursor/composio-mcp-oauth-remote.sh begin
#   4) Browser:  abrir URL impressa (≤2 min)
#   5) Se browser mostrar callback URL em vez de sucesso, colar:
#              bash scripts/cursor/composio-mcp-oauth-remote.sh finish '<url_callback>'
#   6) Cursor:  reactivar composio MCP

set -euo pipefail

CALLBACK_PORT="${COMPOSIO_MCP_CALLBACK_PORT:-8787}"
ENV_FILE="${COMPOSIO_ENV_FILE:-/root/.config/agl/secrets.env}"
MCP_URL="https://connect.composio.dev/mcp"
AUTH_DIR="${MCP_REMOTE_CONFIG_DIR:-/root/.mcp-auth}"
PID_FILE="/tmp/composio-mcp-oauth.pid"
URL_FILE="/tmp/composio-mcp-oauth.url"
LOG_FILE="/tmp/composio-mcp-oauth.log"

load_key() {
  if [[ -f "${ENV_FILE}" ]]; then
    # shellcheck disable=SC1090
    set -a
    source "${ENV_FILE}"
    set +a
  fi
  if [[ -z "${COMPOSIO_API_KEY:-}" && -f /opt/agl-hermes/data/.env ]]; then
    COMPOSIO_API_KEY="$(grep -E '^COMPOSIO_API_KEY=' /opt/agl-hermes/data/.env | tail -1 | cut -d= -f2- || true)"
  fi
  if [[ -z "${COMPOSIO_API_KEY:-}" ]]; then
    echo "ERRO: definir COMPOSIO_API_KEY em ${ENV_FILE}" >&2
    exit 1
  fi
  export COMPOSIO_API_KEY
  # ak_ = project API key → x-api-key; ck_ = consumer key → x-consumer-api-key
  if [[ "${COMPOSIO_API_KEY}" == ck_* ]]; then
    COMPOSIO_MCP_HEADER="x-consumer-api-key:${COMPOSIO_API_KEY}"
  else
    COMPOSIO_MCP_HEADER="x-api-key:${COMPOSIO_API_KEY}"
  fi
  export COMPOSIO_MCP_HEADER
}

cmd_reset() {
  echo "=== reset: parar mcp-remote Composio + limpar ~/.mcp-auth ==="
  pkill -f 'mcp-remote.*connect.composio.dev' 2>/dev/null || true
  sleep 1
  rm -rf "${AUTH_DIR}"/* 2>/dev/null || true
  rm -f "${PID_FILE}" "${URL_FILE}" "${LOG_FILE}"
  echo "OK reset concluído. Desactiva composio no Cursor antes de 'begin'."
}

cmd_begin() {
  load_key
  if pgrep -f 'mcp-remote.*connect.composio.dev' >/dev/null 2>&1; then
    echo "ERRO: mcp-remote já a correr. Correr: $0 reset" >&2
    exit 1
  fi

  echo "=== begin: OAuth Composio (porta ${CALLBACK_PORT}) ==="
  echo "Túnel SSH no PC local:"
  echo "  ssh -N -L ${CALLBACK_PORT}:127.0.0.1:${CALLBACK_PORT} root@<agldv04>"
  echo ""
  echo "A iniciar UMA instância mcp-remote (log: ${LOG_FILE})..."

  : > "${LOG_FILE}"
  npx -y mcp-remote@latest "${MCP_URL}" "${CALLBACK_PORT}" \
    --header "${COMPOSIO_MCP_HEADER}" \
    --debug >> "${LOG_FILE}" 2>&1 &
  echo $! > "${PID_FILE}"

  echo "PID: $(cat "${PID_FILE}")"
  echo "À espera da URL de autorização (max 30s)..."

  local url=""
  for _ in $(seq 1 30); do
    url="$(grep -oE 'https://login\.composio\.dev/oauth2/authorize[^[:space:]]+' "${LOG_FILE}" | tail -1 || true)"
    if [[ -n "${url}" ]]; then
      echo "${url}" > "${URL_FILE}"
      break
    fi
    sleep 1
  done

  if [[ -z "${url}" ]]; then
    echo "ERRO: URL não apareceu. Ver ${LOG_FILE}" >&2
    tail -20 "${LOG_FILE}" >&2 || true
    exit 1
  fi

  echo ""
  echo "Abrir NO BROWSER (PC local, com túnel activo):"
  echo "${url}"
  echo ""
  echo "Se aparecer erro no browser, colar callback:"
  echo "  $0 finish 'http://127.0.0.1:${CALLBACK_PORT}/oauth/callback?code=...&state=...'"
  echo ""
  echo "A aguardar conclusão (max 10 min)..."
  if timeout 600 tail -f "${LOG_FILE}" 2>/dev/null | grep -qm1 -E 'Authentication completed|Connected to remote|tools/list'; then
    echo "OK OAuth concluído — reactivar composio no Cursor."
    exit 0
  fi
  echo "Timeout ou erro — ver ${LOG_FILE} e usar 'finish' se tiveres URL de callback."
  tail -15 "${LOG_FILE}" || true
  exit 1
}

cmd_finish() {
  local callback_url="${1:-}"
  if [[ -z "${callback_url}" ]]; then
    echo "Uso: $0 finish 'http://127.0.0.1:${CALLBACK_PORT}/oauth/callback?code=...&state=...'" >&2
    exit 1
  fi

  if [[ ! -f "${PID_FILE}" ]] || ! kill -0 "$(cat "${PID_FILE}")" 2>/dev/null; then
    echo "AVISO: begin não activo — a tentar callback directo na porta ${CALLBACK_PORT}..."
  fi

  echo "=== finish: enviar callback ==="
  curl -sS -m 15 -v "${callback_url}" 2>&1 | tail -20
  echo ""
  sleep 2
  if [[ -f "${LOG_FILE}" ]]; then
    tail -10 "${LOG_FILE}" || true
  fi
  ls -la "${AUTH_DIR}"/mcp-remote-*/*tokens* 2>/dev/null || ls -la "${AUTH_DIR}"/mcp-remote-*/*.json 2>/dev/null || true
}

cmd_status() {
  echo "=== status ==="
  pgrep -af 'mcp-remote.*connect.composio' || echo "(sem mcp-remote)"
  [[ -f "${PID_FILE}" ]] && echo "pid_file: $(cat "${PID_FILE}")"
  [[ -f "${URL_FILE}" ]] && echo "url_file: $(cat "${URL_FILE}")"
  find "${AUTH_DIR}" -name '*tokens*' -o -name '*_tokens.json' 2>/dev/null | head -5 || echo "(sem tokens guardados)"
}

case "${1:-begin}" in
  reset) cmd_reset ;;
  begin) cmd_begin ;;
  finish) cmd_finish "${2:-}" ;;
  status) cmd_status ;;
  *)
    echo "Uso: $0 {reset|begin|finish|status}" >&2
    exit 1
    ;;
esac
