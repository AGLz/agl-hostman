#!/usr/bin/env bash
# Argus — digest limites/quota LLM. Modos:
#   --daily   (default) resumo no briefing matinal (07:30) — compacto
#   --alert   só emite se houver acção/bloqueio ou LiteLLM down
#
set -euo pipefail

MODE="${1:---daily}"
GOVERNOR_STATE_FILE="${GOVERNOR_STATE_FILE:-/var/log/hostman/quota-governor-state.json}"
LITELLM_TS="${LITELLM_TS:-http://100.125.249.8:4000}"

ALERTS=()
litellm_ok=0
if command -v curl >/dev/null 2>&1 && curl -sf -m 8 "${LITELLM_TS}/health/readiness" >/dev/null 2>&1; then
  litellm_ok=1
else
  ALERTS+=("LiteLLM CT186 inacessível (${LITELLM_TS})")
fi

gov_action=""
if [[ -f "${GOVERNOR_STATE_FILE}" ]] && command -v jq >/dev/null 2>&1; then
  gov_action="$(jq -r '.action // .status // empty' "${GOVERNOR_STATE_FILE}" 2>/dev/null || true)"
  if [[ -n "${gov_action}" && "${gov_action}" != "ok" && "${gov_action}" != "normal" ]]; then
    ALERTS+=("quota-governor: ${gov_action}")
  fi
fi

if [[ "${MODE}" == "--alert" ]]; then
  if [[ ${#ALERTS[@]} -eq 0 ]]; then
    echo "[SILENT]"
    exit 0
  fi
  echo "👁️ Argus — alerta limites LLM ($(date '+%Y-%m-%d %H:%M %Z'))"
  for a in "${ALERTS[@]}"; do echo "• ${a}"; done
  exit 0
fi

# --daily: compacto (1 bloco curto)
echo "👁️ Argus — limites LLM ($(date '+%Y-%m-%d %H:%M %Z'))"
if [[ "${litellm_ok}" -eq 1 ]]; then
  echo "• LiteLLM: OK"
else
  echo "• LiteLLM: FALHA"
fi
if [[ -f "${GOVERNOR_STATE_FILE}" ]] && command -v jq >/dev/null 2>&1; then
  ts="$(jq -r '.updated_at // .timestamp // "?"' "${GOVERNOR_STATE_FILE}" 2>/dev/null || echo "?")"
  echo "• Governor: ${gov_action:-ok} (atualizado ${ts})"
else
  echo "• Governor: sem estado (${GOVERNOR_STATE_FILE})"
fi
echo "• Tier B (mudanças LiteLLM): OK humano via Telegram → Argus → Werner"
