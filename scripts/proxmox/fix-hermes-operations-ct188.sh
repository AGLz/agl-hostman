#!/usr/bin/env bash
# Remediação completa Hermes CT188: disco, rate limits, crons, Langfuse, perms.
#
# Uso (root no CT188):
#   bash fix-hermes-operations-ct188.sh
#   bash fix-hermes-operations-ct188.sh /mnt/overpower/apps/dev/agl/agl-hostman

set -euo pipefail

AGL_HOSTMAN="${1:-/mnt/overpower/apps/dev/agl/agl-hostman}"
SCRIPTS="${AGL_HOSTMAN}/scripts/proxmox"

test -d "${SCRIPTS}" || { echo "ERRO: ${SCRIPTS} inexistente" >&2; exit 1; }

echo "========== HERMES CT188 — remediação completa =========="
echo "Antes:" && df -h / | tail -1

bash "${SCRIPTS}/cleanup-hermes-disk-ct188.sh"
bash "${SCRIPTS}/fix-hermes-cron-perms-ct188.sh" --install-cron
bash "${SCRIPTS}/fix-hermes-rate-limits-ct188.sh" "${AGL_HOSTMAN}"
bash "${SCRIPTS}/fix-hermes-langfuse-ct188.sh"
bash "${SCRIPTS}/deploy-hermes-health-cron-ct188.sh" "${AGL_HOSTMAN}" --test-run

echo ""
echo "=== Smoke ==="
if [[ -x "${SCRIPTS}/smoke-hermes-aglz-quartet.sh" ]]; then
  bash "${SCRIPTS}/smoke-hermes-aglz-quartet.sh" || echo "WARN: smoke parcial" >&2
fi

echo ""
echo "Depois:" && df -h / | tail -1
docker ps --format 'table {{.Names}}\t{{.Status}}' | grep -E 'hermes|NAMES'
echo ""
echo "Concluído. Enviar NOVA mensagem Telegram ao Jarvis (/new se thread antiga)."
