#!/usr/bin/env bash
# Restaura /opt/agl-openclaw/.env no CT187 a partir de um backup .env.bak.telegram.*
# criado por pct187-rotate-telegram-bot-token.sh (o backup mais recente = estado *antes*
# da última rotação de token, ou seja, o token “anterior”).
#
# No Proxmox AGLSRV1:
#   bash /caminho/agl-hostman/scripts/proxmox/pct187-restore-telegram-env-from-backup.sh
#   bash .../pct187-restore-telegram-env-from-backup.sh 1   # segundo backup mais recente
#
set -euo pipefail

CT="${CT:-187}"
IDX="${1:-0}"

command -v pct >/dev/null || {
  echo "ERRO: pct não encontrado — executar no AGLSRV1." >&2
  exit 1
}

pct exec "$CT" -- bash -s -- "$IDX" <<'REMOTE'
set -euo pipefail
IDX="${1:-0}"
cd /opt/agl-openclaw || exit 1
mapfile -t baks < <(ls -t .env.bak.telegram.* 2>/dev/null || true)
if [[ ${#baks[@]} -eq 0 ]]; then
  echo "ERRO: não há ficheiros .env.bak.telegram.* em /opt/agl-openclaw" >&2
  exit 1
fi
if ! [[ "$IDX" =~ ^[0-9]+$ ]] || [[ "$IDX" -ge "${#baks[@]}" ]]; then
  echo "ERRO: índice inválido ${IDX} (existem ${#baks[@]} backup(s), índices 0..$((${#baks[@]} - 1)))" >&2
  exit 1
fi
src="${baks[$IDX]}"
ts="$(date +%Y%m%d%H%M%S)"
cp -a .env ".env.bak.before-restore.${ts}"
cp -a "$src" .env
echo "OK: .env restaurado a partir de: $src"
docker compose -f docker-compose.yml restart
REMOTE

echo "Logs: pct exec ${CT} -- docker logs agl-openclaw-openclaw-gateway-1 --tail 40"
