#!/usr/bin/env bash
# Backup leve diário Hermes CT188 — tarball local, sem push Git (sem LLM).
set -euo pipefail

BACKUP_ROOT="${HERMES_BACKUP_DIR:-/opt/data/backups/daily}"
KEEP_DAYS="${HERMES_BACKUP_KEEP_DAYS:-7}"
STAMP="$(date '+%Y%m%d-%H%M%S')"
ARCHIVE="${BACKUP_ROOT}/hermes-ct188-${STAMP}.tar.gz"
DATE="$(date '+%Y-%m-%d %H:%M %Z')"

mkdir -p "${BACKUP_ROOT}"

INCLUDE=(
  /opt/data/config.yaml
  /opt/data/SOUL.md
  /opt/data/cron/jobs.json
)
[[ -d /opt/data/skills ]] && INCLUDE+=(/opt/data/skills)
[[ -d /opt/data/profiles ]] && INCLUDE+=(/opt/data/profiles)

# Não incluir .env, sessions completas nem state.db (PII/volume)
tar -czf "${ARCHIVE}" \
  --ignore-failed-read \
  "${INCLUDE[@]}" 2>/dev/null || {
  echo "🔴 Backup falhou ao criar ${ARCHIVE}"
  exit 1
}

size_mb="$(du -m "${ARCHIVE}" | awk '{print $1}')"
find "${BACKUP_ROOT}" -name 'hermes-ct188-*.tar.gz' -mtime +"${KEEP_DAYS}" -delete 2>/dev/null || true
count="$(find "${BACKUP_ROOT}" -name 'hermes-ct188-*.tar.gz' 2>/dev/null | wc -l | tr -d ' ')"

# Resumo incluído no briefing 07:00 — evita mensagem Telegram extra às 04:30
echo "[SILENT] backup ok ${size_mb}MB count=${count}"
