#!/usr/bin/env bash
# Deploy LiteLLM em host específico (config + DB locais)
# Uso: ./scripts/litellm/deploy-litellm-host.sh <host> [-y|--yes]
# Hosts: ct186, agldv04, agldv12, fgsrv06  (agldv03 descontinuado)
# Ref: docs/LITELLM-MULTI-HOST-DEPLOYMENT.md

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_litellm-sync-common.sh
source "${SCRIPT_DIR}/_litellm-sync-common.sh"

ENV_EXAMPLE="${LITELLM_REPO_ROOT}/config/litellm/.env.example"

usage() {
  echo "Uso: $0 <host> [-y|--yes]"
  echo "  Hosts: ct186, agldv04, agldv12, fgsrv06"
  echo "  -y, --yes: iniciar LiteLLM automaticamente (sem prompt)"
  echo ""
  echo "  ct186: canónico (/opt/agl-litellm) — preferir bootstrap-ct186-litellm.sh na 1.ª vez"
  echo "  agldv03: descontinuado — use CT186"
  exit 1
}

[[ $# -lt 1 ]] && usage
HOST="$1"
AUTO_START=false
[[ "${2:-}" == "-y" || "${2:-}" == "--yes" ]] && AUTO_START=true

litellm_reject_deprecated_host "$HOST"

IP="${LITELLM_HOST_IPS[$HOST]:-}"
if [[ -z "$IP" ]]; then
  echo "Erro: host '$HOST' desconhecido"
  usage
fi

litellm_require_repo_config

if [[ ! -f "$ENV_EXAMPLE" ]]; then
  echo "Erro: $ENV_EXAMPLE não encontrado"
  exit 1
fi

remote_dir="$(litellm_remote_dir "$HOST")"

echo "=== Deploy LiteLLM → $HOST ($IP) ==="
echo "  Config: repo (${LITELLM_CONFIG_SRC})"
echo "  Destino: ${remote_dir}"
echo ""

if [[ "$HOST" == "ct186" ]]; then
  echo "  CT186: a usar deploy-litellm-callbacks-ct186.sh + .env local"
  bash "${SCRIPT_DIR}/deploy-litellm-callbacks-ct186.sh"
  if [[ -f "${LITELLM_REPO_ROOT}/config/litellm/.env" ]]; then
    scp -q "$LITELLM_ENV_SRC" "root@${IP}:/tmp/litellm-env-bootstrap"
    ssh "root@${IP}" "test -f ${remote_dir}/.env || cp /tmp/litellm-env-bootstrap ${remote_dir}/.env"
    rm -f /tmp/litellm-env-bootstrap 2>/dev/null || true
  fi
  echo ""
  echo "=== Concluído (CT186) ==="
  exit 0
fi

ssh "root@${IP}" "mkdir -p ${remote_dir}"
litellm_push_compose_to_host "$HOST" "$IP"
litellm_push_config_to_host "$HOST" "$IP"
litellm_push_callbacks_to_host "$IP" "$HOST"

scp "$ENV_EXAMPLE" "root@${IP}:${remote_dir}/.env.example"
ssh "root@${IP}" "test -f ${remote_dir}/.env || cp ${remote_dir}/.env.example ${remote_dir}/.env"

echo ""
echo "  Arquivos criados em root@${IP}:${remote_dir}/"
echo "  - config.yaml"
echo "  - .env (ou .env.example → editar)"
echo "  - docker-compose.yml"
echo ""
echo "  IMPORTANTE: Edite ${remote_dir}/.env com LITELLM_MASTER_KEY e API keys"
echo ""

if [[ "$AUTO_START" == "true" ]]; then
  DO_START=1
else
  read -r -p "Iniciar LiteLLM agora? [y/N] " -n 1 -r
  echo
  [[ $REPLY =~ ^[Yy]$ ]] && DO_START=1
fi

if [[ -n "${DO_START:-}" ]]; then
  ssh "root@${IP}" "cd ${remote_dir} && docker compose up -d"
  echo ""
  echo "  Verificar: ssh root@${IP} 'curl -s http://localhost:4000/health/readiness'"
  echo "  Configurar OpenClaw local: node scripts/openclaw/use-litellm-local.mjs"
fi

echo ""
echo "=== Concluído ==="
