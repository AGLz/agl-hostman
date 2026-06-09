#!/usr/bin/env bash
# Fase 0 — backup read-only do FGSRV6 antes de reinstalação.
# Saída: .local/fgsrv6-backup-YYYYMMDD/ (não versionar — contém chaves WG)
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FGSRV6_HOST="${FGSRV6_HOST:-root@100.83.51.9}"
DATE_TAG="$(date +%Y%m%d)"
BACKUP_DIR="${BACKUP_DIR:-$REPO_ROOT/.local/fgsrv6-backup-$DATE_TAG}"
SSH_OPTS=(-o BatchMode=yes -o ConnectTimeout=15)

log() { printf '[%s] %s\n' "$(date +%H:%M:%S)" "$*"; }

mkdir -p "$BACKUP_DIR/docker-volumes"

log "Backup dir: $BACKUP_DIR"

log "WireGuard configs..."
rsync -az -e "ssh ${SSH_OPTS[*]}" "$FGSRV6_HOST:/etc/wireguard/" "$BACKUP_DIR/wireguard/"
rsync -az -e "ssh ${SSH_OPTS[*]}" "$FGSRV6_HOST:/root/wireguard-backup/" "$BACKUP_DIR/wireguard-backup/" 2>/dev/null || true

log "Compose stacks (sem /var/www)..."
rsync -az -e "ssh ${SSH_OPTS[*]}" \
  "$FGSRV6_HOST:/opt/litellm/docker-compose.yml" \
  "$FGSRV6_HOST:/opt/wg-easy/docker-compose.yml" \
  "$BACKUP_DIR/opt-litellm/" 2>/dev/null || true
rsync -az -e "ssh ${SSH_OPTS[*]}" "$FGSRV6_HOST:/opt/docker/cloudflared/" "$BACKUP_DIR/opt/cloudflared/" 2>/dev/null || true
rsync -az -e "ssh ${SSH_OPTS[*]}" "$FGSRV6_HOST:/opt/docker/n8n/" "$BACKUP_DIR/opt/n8n/" 2>/dev/null || true

log "Nginx sites..."
ssh "${SSH_OPTS[@]}" "$FGSRV6_HOST" 'cd /etc/nginx && tar czf - sites-enabled sites-available' \
  > "$BACKUP_DIR/nginx-sites.tar.gz"

log "Runtime snapshot..."
ssh "${SSH_OPTS[@]}" "$FGSRV6_HOST" \
  'wg show all; echo; docker ps -a; echo; docker volume ls; df -h /' \
  > "$BACKUP_DIR/runtime-snapshot.txt"

log "Docker volumes (litellm-db, n8n, portainer)..."
ssh "${SSH_OPTS[@]}" "$FGSRV6_HOST" bash -s <<'REMOTE'
set -euo pipefail
for v in litellm_litellm-db-data n8n_data portainer_data; do
  docker run --rm -v "${v}:/data:ro" -v /tmp:/backup alpine \
    tar czf "/backup/${v}.tar.gz" -C /data .
  ls -la "/tmp/${v}.tar.gz"
done
REMOTE

rsync -az -e "ssh ${SSH_OPTS[*]}" \
  "$FGSRV6_HOST:/tmp/litellm_litellm-db-data.tar.gz" \
  "$FGSRV6_HOST:/tmp/n8n_data.tar.gz" \
  "$FGSRV6_HOST:/tmp/portainer_data.tar.gz" \
  "$BACKUP_DIR/docker-volumes/"

log "Manifest..."
{
  echo "backup_date=$DATE_TAG"
  echo "source_host=$FGSRV6_HOST"
  du -sh "$BACKUP_DIR"/* 2>/dev/null || true
  sha256sum "$BACKUP_DIR"/wireguard/wg0.conf 2>/dev/null || true
} > "$BACKUP_DIR/MANIFEST.txt"

log "Done. Total:"
du -sh "$BACKUP_DIR"
log "AVISO: contém PrivateKey WireGuard — manter em .local/ apenas."
