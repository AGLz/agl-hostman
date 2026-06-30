#!/usr/bin/env bash
# Deploy módulo PC Gamer no CT134 produção — migrate pcg_* + smoke scheduler/Horizon.
#
# Pré-requisitos: imagem agl-hostman já no CT134 (deploy-llm-monitor ou pipeline main).
#
# Uso:
#   bash scripts/proxmox/deploy-pcgamer-ct134.sh
#   bash scripts/proxmox/deploy-pcgamer-ct134.sh --skip-build
#   bash scripts/proxmox/deploy-pcgamer-ct134.sh --migrate-only
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
HARBOR_REGISTRY="${HARBOR_REGISTRY:-harbor.aglz.io}"
HARBOR_PROJECT="${HARBOR_PROJECT:-agl-hostman-prod}"
IMAGE_NAME="${IMAGE_NAME:-hostman}"
IMAGE_TAG="${IMAGE_TAG:-prod-pcgamer-$(date +%Y%m%d)}"
FULL_IMAGE="${HARBOR_REGISTRY}/${HARBOR_PROJECT}/${IMAGE_NAME}:${IMAGE_TAG}"
LATEST_IMAGE="${HARBOR_REGISTRY}/${HARBOR_PROJECT}/${IMAGE_NAME}:prod-latest"
AGLSRV1_SSH="${AGLSRV1_SSH:-root@100.107.113.33}"
CT134_VMID="${CT134_VMID:-134}"
DEPLOY_DIR="/opt/agl-hostman-prod"
SKIP_BUILD=0
MIGRATE_ONLY=0
IMAGE_LOADED_LOCALLY=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-build) SKIP_BUILD=1; shift ;;
    --migrate-only) MIGRATE_ONLY=1; shift ;;
    -h|--help)
      sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *) echo "Opção desconhecida: $1" >&2; exit 2 ;;
  esac
done

log() { echo "[deploy-pcgamer-ct134] $*" >&2; }

pct_exec() {
  ssh -o BatchMode=yes -o ConnectTimeout=15 "$AGLSRV1_SSH" "pct exec ${CT134_VMID} -- $*"
}

docker_exec_app() {
  pct_exec "docker exec agl-hostman-prod-app $*"
}

transfer_image_to_ct134() {
  local tar="/tmp/agl-hostman-${IMAGE_TAG}.tar"
  log "Transferir imagem via docker save/load..."
  docker save "${LATEST_IMAGE}" -o "${tar}"
  scp -o BatchMode=yes "${tar}" "${AGLSRV1_SSH}:/tmp/agl-hostman-image.tar"
  ssh -o BatchMode=yes "$AGLSRV1_SSH" "pct push ${CT134_VMID} /tmp/agl-hostman-image.tar /tmp/agl-hostman-image.tar"
  pct_exec "docker load -i /tmp/agl-hostman-image.tar"
  pct_exec "rm -f /tmp/agl-hostman-image.tar"
  rm -f "${tar}"
  ssh -o BatchMode=yes "$AGLSRV1_SSH" "rm -f /tmp/agl-hostman-image.tar"
  IMAGE_LOADED_LOCALLY=1
}

if [[ "$MIGRATE_ONLY" -eq 0 ]]; then
  if [[ "$SKIP_BUILD" -eq 0 ]]; then
    log "Build imagem ${FULL_IMAGE}..."
    docker build --target production -t "${FULL_IMAGE}" -t "${LATEST_IMAGE}" -f "${REPO_ROOT}/src/Dockerfile" "${REPO_ROOT}/src"
    log "Push Harbor..."
    if docker push "${FULL_IMAGE}" && docker push "${LATEST_IMAGE}"; then
      log "Push Harbor OK"
    else
      transfer_image_to_ct134
    fi
  else
    log "Skip build — transferir imagem local ${LATEST_IMAGE}"
    if ! docker image inspect "${LATEST_IMAGE}" >/dev/null 2>&1; then
      log "ERRO: imagem local ${LATEST_IMAGE} não encontrada" >&2
      exit 1
    fi
    transfer_image_to_ct134
  fi

  log "Actualizar .env PC Gamer no CT134..."
  ssh -o BatchMode=yes "$AGLSRV1_SSH" "pct exec ${CT134_VMID} -- bash -s" <<'REMOTE'
set -euo pipefail
ENV_FILE="/opt/agl-hostman-prod/.env"
touch "$ENV_FILE"
chmod 600 "$ENV_FILE"

upsert_env() {
  local key="$1" val="$2"
  if grep -q "^${key}=" "$ENV_FILE" 2>/dev/null; then
    sed -i "s|^${key}=.*|${key}=${val}|" "$ENV_FILE"
  else
    echo "${key}=${val}" >> "$ENV_FILE"
  fi
}

upsert_env TELEGRAM_MONITOR_CHATS "@mmpromo,@pcdofafapromo,@tecnoarthardware,@opczaopromocoes,@amandapromos"
upsert_env TME_SYNC_LIMIT "20"
upsert_env OFFER_VALIDATION_MAX_AGE_HOURS "72"
upsert_env OFFER_REVALIDATE_MINUTES "30"
upsert_env OFFER_VALIDATION_BATCH "20"
upsert_env OFFER_PRICE_TOLERANCE_PERCENT "5"
upsert_env PCG_MARKET_FETCH_PROVIDERS "mercadolivre,pichau,aliexpress,4gamers"
REMOTE

  log "Restart stack CT134..."
  if [[ "${IMAGE_LOADED_LOCALLY}" -eq 1 ]]; then
    pct_exec "bash -lc 'cd ${DEPLOY_DIR} && docker compose up -d'"
  else
    pct_exec "bash -lc 'cd ${DEPLOY_DIR} && docker compose pull && docker compose up -d'" || \
      pct_exec "bash -lc 'cd ${DEPLOY_DIR} && docker compose up -d'"
  fi

  log "Aguardar app healthy..."
  for _ in $(seq 1 36); do
    if pct_exec "docker inspect agl-hostman-prod-app --format '{{.State.Health.Status}}' 2>/dev/null" | grep -q healthy; then
      break
    fi
    sleep 5
  done
fi

log "Migrate tabelas pcg_*..."
docker_exec_app php artisan migrate --path=database/migrations/2026_06_30_000001_create_pcgamer_tables.php --force --no-interaction

log "Seed catálogo PC Gamer (se vazio)..."
docker_exec_app php artisan db:seed --class=Database\\Seeders\\PcgCatalogSeeder --force --no-interaction || true

log "Smoke: rotas web pc-gamer..."
docker_exec_app php artisan route:list --path=pc-gamer

log "Smoke: comandos artisan pcg:*..."
docker_exec_app php artisan list pcg

log "Smoke: sync t.me (1 canal, dry)..."
docker_exec_app php artisan pcg:sync-tme --chat=@mmpromo --limit=3 --sync || log "AVISO: sync-tme falhou (rede/WAF?)"

log "Smoke: schedule pcg..."
docker_exec_app php artisan schedule:list | grep pcg || true

log "Restart Horizon + scheduler (fila pc-gamer)..."
pct_exec "docker restart agl-hostman-prod-horizon agl-hostman-prod-scheduler"

log "=== Deploy PC Gamer concluído ==="
log "UI: https://ah.aglz.io/pc-gamer/builds (auth required)"
log "Sync manual: docker exec agl-hostman-prod-app php artisan pcg:sync-tme --sync"
log "Desligar cron Python sidecar em agldv04 quando scheduler Laravel confirmado"
