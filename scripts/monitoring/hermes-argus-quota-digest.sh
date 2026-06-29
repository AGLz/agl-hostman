#!/usr/bin/env bash
# Argus — digest leve dos limites/quota dos providers LLM (sem gastar LLM).
# Lê o estado do quota-governor e imprime um resumo legível para o Telegram (cron no_agent).
#
# Uso:
#   bash hermes-argus-quota-digest.sh
#
# Variáveis:
#   GOVERNOR_STATE_FILE  default /var/log/hostman/quota-governor-state.json
#   LITELLM_TS           default http://100.125.249.8:4000

set -euo pipefail

GOVERNOR_STATE_FILE="${GOVERNOR_STATE_FILE:-/var/log/hostman/quota-governor-state.json}"
LITELLM_TS="${LITELLM_TS:-http://100.125.249.8:4000}"

echo "👁️  Argus — estado dos limites LLM ($(date '+%Y-%m-%d %H:%M %Z'))"
echo ""

if [[ -f "${GOVERNOR_STATE_FILE}" ]] && command -v jq >/dev/null 2>&1; then
  echo "Fonte: quota-governor (${GOVERNOR_STATE_FILE})"
  jq -r '
    (.updated_at // .timestamp // "?") as $ts
    | "Atualizado: \($ts)",
      (if (.action // .status) then "Ação: \(.action // .status)" else empty end),
      (if .tiers then (.tiers | to_entries[] | "  • \(.key): \(.value.status // .value)") else empty end),
      (if .spend then "Spend global: \(.spend)" else empty end)
  ' "${GOVERNOR_STATE_FILE}" 2>/dev/null || {
    echo "(estado presente mas formato inesperado — dump bruto)"
    head -c 2000 "${GOVERNOR_STATE_FILE}"
  }
else
  echo "⚠️  Sem estado do quota-governor em ${GOVERNOR_STATE_FILE}."
  echo "    Correr: bash scripts/litellm/quota-governor.sh --notify"
fi

echo ""
echo "LiteLLM gateway: ${LITELLM_TS}"
if command -v curl >/dev/null 2>&1; then
  if curl -sf -m 8 "${LITELLM_TS}/health/readiness" >/dev/null 2>&1; then
    echo "  health/readiness: OK"
  else
    echo "  health/readiness: FALHA — verificar LiteLLM CT186"
  fi
fi

echo ""
echo "Tier B (mudanças estruturais no LiteLLM) requer o teu OK aqui no Telegram → Argus delega ao Werner."
