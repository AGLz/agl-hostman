#!/usr/bin/env bash
# Aplica correcções Verdent Manager (auditoria 2026-07-03) no CT188.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="${REPO_ROOT:-$(cd "${SCRIPT_DIR}/../.." && pwd)}"
HERMES_ROOT="${HERMES_ROOT:-/opt/agl-hermes}"

log() { printf '[verdent-fix] %s\n' "$*"; }

log "1/8 Minions worker"
bash "${SCRIPT_DIR}/fix-hermes-minions-worker-ct188.sh" "${REPO}"
bash "${SCRIPT_DIR}/seed-hermes-minions-kanban-ct188.sh"

log "2/8 Briefing Jarvis"
install -d -m 755 "${HERMES_ROOT}/data/scripts"
install -m 755 "${REPO}/scripts/monitoring/hermes-ct188-daily-briefing-humanized.sh" \
  "${HERMES_ROOT}/data/scripts/hermes-ct188-daily-briefing-humanized.sh"
install -m 755 "${REPO}/scripts/monitoring/hermes-ct188-daily-briefing.sh" \
  "${HERMES_ROOT}/data/scripts/hermes-ct188-daily-briefing.sh"
chown 10000:10000 "${HERMES_ROOT}/data/scripts/"*.sh 2>/dev/null || true

log "3/8 Stand-up Verdent (substitui agency-sync)"
bash "${SCRIPT_DIR}/setup-hermes-jarvis-standup-cron-ct188.sh"

log "4/8 Honcho merge"
bash "${SCRIPT_DIR}/fix-hermes-honcho-merge-ct188.sh"

log "5/8 Curator + profile cron models"
CRON_MODEL=agl-primary-zai-glm-flash bash "${SCRIPT_DIR}/fix-hermes-profile-cron-models-ct188.sh"
CRON_MODEL=agl-primary-zai-glm-flash CRON_FALLBACK=groq-llama-31-8b \
  bash "${SCRIPT_DIR}/fix-hermes-cron-models-ct188.sh"

log "6/8 Agency-sync removido (feito no standup script)"

log "7/8 Review-queue helper + skill"
mkdir -p "${HERMES_ROOT}/data/skills/review-queue"
install -m 644 "${REPO}/docker/hermes/profiles/jarvis/skills/review-queue/SKILL.md" \
  "${HERMES_ROOT}/data/skills/review-queue/SKILL.md"
mkdir -p /opt/llm-wiki/raw/hermes/review-queue
[[ -f /opt/llm-wiki/raw/hermes/review-queue/queue.json ]] || \
  echo '{"items":[]}' > /opt/llm-wiki/raw/hermes/review-queue/queue.json
chown -R 10000:10000 /opt/llm-wiki/raw/hermes/review-queue 2>/dev/null || true

log "8/8 SOUL zero-OR + restart agentes"
for agent in jarvis elon satya werner curator orion argus verifier composio; do
  src="${REPO}/docker/hermes/profiles/${agent}/SOUL.md"
  if [[ "${agent}" == "jarvis" ]]; then
    dst="${HERMES_ROOT}/data/SOUL.md"
  else
    dst="${HERMES_ROOT}/profiles/${agent}/SOUL.md"
  fi
  [[ -f "${src}" ]] && install -m 644 "${src}" "${dst}" && chown 10000:10000 "${dst}" 2>/dev/null || true
done

cd "${HERMES_ROOT}"
docker compose -f docker-compose.aglz-quartet.yml restart \
  agl-hermes-jarvis agl-hermes-elon agl-hermes-satya agl-hermes-werner \
  agl-hermes-curator agl-hermes-orion agl-hermes-argus agl-hermes-verifier \
  agl-hermes-composio 2>/dev/null || docker compose restart

log "Concluído. Smoke: hermes cron list (jarvis) + curl :6969/api/tasks"
