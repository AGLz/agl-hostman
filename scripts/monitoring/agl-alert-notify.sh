#!/usr/bin/env bash
# Notificação genérica AGL (Telegram + log local).
#
# Uso:
#   agl-alert-notify.sh --severity critical --title "Host down" --body "detalhe"
#   AGL_MONITOR_ENV=/etc/agl-hostman/monitor.env agl-alert-notify.sh ...
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
LOG_DIR="${AGL_ALERT_LOG_DIR:-/var/log/hostman}"
LOG_FILE="${LOG_DIR}/aglsrv3-alerts.log"

SEVERITY="warn"
TITLE=""
BODY=""

usage() {
  sed -n '2,6p' "$0" | sed 's/^# \{0,1\}//'
  exit 2
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --severity) SEVERITY="${2:-}"; shift 2 ;;
    --title) TITLE="${2:-}"; shift 2 ;;
    --body) BODY="${2:-}"; shift 2 ;;
    -h|--help) usage ;;
    *) echo "Argumento desconhecido: $1" >&2; usage ;;
  esac
done

[[ -n "$TITLE" ]] || { echo "ERRO: --title obrigatório" >&2; exit 2; }

load_env() {
  local f
  for f in \
    "${AGL_MONITOR_ENV:-}" \
    "/etc/agl-hostman/monitor.env" \
    "$REPO_ROOT/config/monitoring/aglsrv3-monitor.env" \
    "$REPO_ROOT/config/monitoring/aglsrv3-monitor.env.local"; do
    [[ -n "$f" && -f "$f" ]] || continue
    set -a
    # shellcheck disable=SC1090
    source "$f"
    set +a
    return 0
  done
  return 0
}

load_env
mkdir -p "$LOG_DIR"

TIMESTAMP="$(date '+%Y-%m-%d %H:%M:%S')"
PREFIX="${AGL_ALERT_PREFIX:-[AGL]}"
FULL_MSG="${PREFIX} [${SEVERITY^^}] ${TITLE}"
[[ -n "$BODY" ]] && FULL_MSG="${FULL_MSG}"$'\n'"${BODY}"

echo "[${TIMESTAMP}] [${SEVERITY}] ${TITLE} | ${BODY}" >>"$LOG_FILE"

TOKEN="${AGL_ALERT_TELEGRAM_BOT_TOKEN:-}"
CHAT="${AGL_ALERT_TELEGRAM_CHAT_ID:-}"

if [[ -z "$TOKEN" || -z "$CHAT" ]]; then
  echo "[agl-alert] Telegram não configurado — só log em ${LOG_FILE}" >&2
  exit 0
fi

curl -sf --max-time 15 \
  "https://api.telegram.org/bot${TOKEN}/sendMessage" \
  --data-urlencode "chat_id=${CHAT}" \
  --data-urlencode "text=${FULL_MSG}" \
  >/dev/null \
  || {
    echo "[agl-alert] Falha ao enviar Telegram" >&2
    exit 1
  }

echo "[agl-alert] Telegram enviado (${SEVERITY})"
