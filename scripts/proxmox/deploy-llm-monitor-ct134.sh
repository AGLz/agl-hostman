#!/usr/bin/env bash
# Deploy LLM Monitor (Fase 2) no CT134 produção — build + migrate + smoke.
#
# Uso:
#   bash scripts/proxmox/deploy-llm-monitor-ct134.sh
#   bash scripts/proxmox/deploy-llm-monitor-ct134.sh --skip-build
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
HARBOR_REGISTRY="${HARBOR_REGISTRY:-harbor.aglz.io}"
HARBOR_PROJECT="${HARBOR_PROJECT:-agl-hostman-prod}"
IMAGE_NAME="${IMAGE_NAME:-hostman}"
IMAGE_TAG="${IMAGE_TAG:-prod-llm-monitor-$(date +%Y%m%d)}"
FULL_IMAGE="${HARBOR_REGISTRY}/${HARBOR_PROJECT}/${IMAGE_NAME}:${IMAGE_TAG}"
LATEST_IMAGE="${HARBOR_REGISTRY}/${HARBOR_PROJECT}/${IMAGE_NAME}:prod-latest"
AGLSRV1_SSH="${AGLSRV1_SSH:-root@100.107.113.33}"
CT134_VMID="${CT134_VMID:-134}"
DEPLOY_DIR="/opt/agl-hostman-prod"
SKIP_BUILD=0
IMAGE_LOADED_LOCALLY=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-build) SKIP_BUILD=1; shift ;;
    -h|--help)
      sed -n '2,8p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *) echo "Opção desconhecida: $1" >&2; exit 2 ;;
  esac
done

log() { echo "[deploy-llm-monitor-ct134] $*" >&2; }

pct_exec() {
  ssh -o BatchMode=yes "$AGLSRV1_SSH" "pct exec ${CT134_VMID} -- $*"
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
    log "ERRO: imagem local ${LATEST_IMAGE} não encontrada — correr sem --skip-build" >&2
    exit 1
  fi
  transfer_image_to_ct134
fi

log "Sync docker-compose CT134..."
scp -o BatchMode=yes "${REPO_ROOT}/docker/dokploy/docker-compose.ct134.production.yml" "${AGLSRV1_SSH}:/tmp/docker-compose.ct134.yml"
ssh -o BatchMode=yes "$AGLSRV1_SSH" "pct push ${CT134_VMID} /tmp/docker-compose.ct134.yml ${DEPLOY_DIR}/docker-compose.yml"

log "Obter LITELLM_MASTER_KEY do CT186 (AGLSRV1)..."
LITELLM_KEY="$(ssh -o BatchMode=yes "$AGLSRV1_SSH" "pct exec 186 -- grep '^LITELLM_MASTER_KEY=' /opt/agl-litellm/.env 2>/dev/null | cut -d= -f2- | tr -d '\"'" || true)"

log "Actualizar .env CT134..."
ssh -o BatchMode=yes "$AGLSRV1_SSH" "pct exec ${CT134_VMID} -- bash -s" <<REMOTE
set -euo pipefail
ENV_FILE="${DEPLOY_DIR}/.env"
mkdir -p "\$(dirname "\$ENV_FILE")" /var/log/hostman
touch "\$ENV_FILE"
chmod 600 "\$ENV_FILE"

upsert_env() {
  local key="\$1" val="\$2"
  [[ -n "\$val" ]] || return 0
  if grep -q "^\${key}=" "\$ENV_FILE" 2>/dev/null; then
    sed -i "s|^\${key}=.*|\${key}=\${val}|" "\$ENV_FILE"
  else
    echo "\${key}=\${val}" >> "\$ENV_FILE"
  fi
}

upsert_env IMAGE "${LATEST_IMAGE}"
upsert_env LITELLM_GATEWAY_URL "http://192.168.0.186:4000"
upsert_env LLM_MONITOR_PROBE_MODEL "glm-4.7-flash"
upsert_env LLM_MONITOR_SPEND_WARN_USD "80"
upsert_env HARNESS_GOVERNOR_STATE_PATH "/var/log/hostman/quota-governor-state.json"
upsert_env LLM_MONITOR_GOVERNOR_STATE_PATH "/var/log/hostman/quota-governor-state.json"
REMOTE

if [[ -n "${LITELLM_KEY}" ]]; then
  ssh -o BatchMode=yes "$AGLSRV1_SSH" "pct exec ${CT134_VMID} -- bash -lc 'grep -q ^LITELLM_MASTER_KEY= ${DEPLOY_DIR}/.env 2>/dev/null && sed -i \"s|^LITELLM_MASTER_KEY=.*|LITELLM_MASTER_KEY=${LITELLM_KEY}|\" ${DEPLOY_DIR}/.env || echo LITELLM_MASTER_KEY=${LITELLM_KEY} >> ${DEPLOY_DIR}/.env'"
fi

ssh -o BatchMode=yes "$AGLSRV1_SSH" "pct exec ${CT134_VMID} -- bash -lc 'if ! grep -q ^API_KEY= ${DEPLOY_DIR}/.env 2>/dev/null; then k=\$(openssl rand -hex 24); echo API_KEY=\$k >> ${DEPLOY_DIR}/.env; echo GERADO_API_KEY=\$k > /root/.agl-hostman-api-key.generated; chmod 600 /root/.agl-hostman-api-key.generated; fi'"

log "Copiar governor state exemplo para CT134..."
if [[ -f "${REPO_ROOT}/config/monitoring/quota-governor-state.example.json" ]]; then
  scp -o BatchMode=yes "${REPO_ROOT}/config/monitoring/quota-governor-state.example.json" "${AGLSRV1_SSH}:/tmp/quota-governor-state.json"
  ssh -o BatchMode=yes "$AGLSRV1_SSH" "pct push ${CT134_VMID} /tmp/quota-governor-state.json /var/log/hostman/quota-governor-state.json"
  pct_exec "chmod 644 /var/log/hostman/quota-governor-state.json"
fi

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

log "Migrate LLM monitor tables..."
docker_exec_app php artisan migrate --path=database/migrations/2026_06_27_000001_create_llm_monitor_tables.php --force --no-interaction

log "Smoke: rotas llm-monitor..."
docker_exec_app php artisan route:list --path=llm-monitor

log "Smoke: ingest governor..."
docker_exec_app php artisan tinker --execute="\$n=app(\\App\\Services\\LlmMonitor\\LlmMonitorService::class)->ingestGovernorState(); echo 'ingested='.\$n.' snapshots='.\\App\\Models\\LlmProviderSnapshot::count().PHP_EOL;" || true

log "Restart Horizon + scheduler..."
pct_exec "docker restart agl-hostman-prod-horizon agl-hostman-prod-scheduler"

log "=== Deploy concluído ==="
log "Imagem: ${LATEST_IMAGE}"
log "API_KEY: ssh ${AGLSRV1_SSH} pct exec ${CT134_VMID} -- cat /root/.agl-hostman-api-key.generated 2>/dev/null || echo '(já existia em .env)'"
log "Health: curl -fsS https://ah.aglz.io/health/"
