#!/usr/bin/env bash
# Instala limpeza de temp_backup_* órfãos no CT134 (cron diário).
#
# ponytail: BackupService remove temp após sucesso; falhas/interrupções deixam dirs gigantes.
#
# Uso:
#   bash scripts/proxmox/setup-ct134-backup-retention.sh
set -euo pipefail

AGLSRV1_SSH="${AGLSRV1_SSH:-root@100.107.113.33}"
CT134_VMID="${CT134_VMID:-134}"
BACKUP_DIR="${BACKUP_DIR:-/var/www/html/storage/backups}"
RETENTION_HOURS="${RETENTION_HOURS:-24}"
CRON_SCHEDULE="${CRON_SCHEDULE:-15 3 * * *}"
MARKER="# agl-ct134-backup-temp-cleanup"

log() { printf '[setup-ct134-backup-retention] %s\n' "$*"; }

CLEANUP_SCRIPT="/usr/local/bin/agl-cleanup-backup-temps.sh"

ssh -o BatchMode=yes "${AGLSRV1_SSH}" "pct exec ${CT134_VMID} -- bash -s" <<REMOTE
set -euo pipefail
cat > ${CLEANUP_SCRIPT} <<'SCRIPT'
#!/usr/bin/env bash
set -euo pipefail
BACKUP_DIR="${BACKUP_DIR}"
RETENTION_HOURS="${RETENTION_HOURS}"
find "\${BACKUP_DIR}" -maxdepth 1 -type d -name 'temp_backup_*' -mmin +\$((RETENTION_HOURS * 60)) -print0 2>/dev/null \
  | xargs -0r rm -rf
SCRIPT
chmod +x ${CLEANUP_SCRIPT}
(crontab -l 2>/dev/null | grep -v "${MARKER}" | grep -v agl-cleanup-backup-temps || true
 echo "# ${MARKER}"
 echo "${CRON_SCHEDULE} ${CLEANUP_SCRIPT} >> /var/log/hostman/backup-cleanup.log 2>&1") | crontab -
mkdir -p /var/log/hostman
REMOTE

log "Smoke run cleanup..."
ssh -o BatchMode=yes "${AGLSRV1_SSH}" "pct exec ${CT134_VMID} -- ${CLEANUP_SCRIPT}" || true
log "OK: cron ${CRON_SCHEDULE} no CT${CT134_VMID}"
