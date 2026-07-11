#!/usr/bin/env bash
# Biblioteca partilhada — política de notificação Telegram nos crons Hermes (--no-agent).
# Convenção: stdout vazio ou linha exacta "[SILENT]" → Hermes não envia Telegram.
#
# Uso:
#   source "$(dirname "$0")/hermes-notify-lib.sh"
#   hermes_notify_silent
#   hermes_notify_emit "texto"   # só se não vazio

hermes_notify_silent() {
  echo "[SILENT]"
}

hermes_notify_emit() {
  local msg="${1:-}"
  [[ -n "${msg}" ]] || return 0
  echo "${msg}"
}

# Emite bloco só se há alertas; senão [SILENT].
# Uso: hermes_notify_if_alerts "título" "${ALERTS[@]}"
hermes_notify_if_alerts() {
  local title="${1:-Alerta}"
  shift || true
  local alerts=("$@")
  if [[ ${#alerts[@]} -eq 0 ]]; then
    hermes_notify_silent
    return 0
  fi
  echo "${title}"
  for a in "${alerts[@]}"; do
    echo "• ${a}"
  done
}
