#!/usr/bin/env bash
# Deploy LiteLLM em host específico (config + DB locais)
# Uso: ./scripts/litellm/deploy-litellm-host.sh <host>
# Hosts: agldv03, agldv04, agldv12, fgsrv06
# Ref: docs/LITELLM-MULTI-HOST-DEPLOYMENT.md

set -e

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CONFIG_DIR="$REPO_ROOT/config/litellm"

# Mapeamento host -> IP (Tailscale) e tipo de config
declare -A HOST_IPS
HOST_IPS[agldv03]="100.94.221.87"
HOST_IPS[agldv04]="100.113.9.98"
HOST_IPS[agldv12]="100.71.217.115"
HOST_IPS[fgsrv06]="100.83.51.9"

# fgsrv06 usa config remota (Ollama via Tailscale)
REMOTE_HOSTS="fgsrv06"

usage() {
  echo "Uso: $0 <host> [-y|--yes]"
  echo "  Hosts: agldv03, agldv04, agldv12, fgsrv06"
  echo "  -y, --yes: iniciar LiteLLM automaticamente (sem prompt)"
  echo ""
  echo "Deploy LiteLLM com config e DB locais. OpenClaw/Claude-flow usam localhost:4000."
  exit 1
}

[[ $# -lt 1 ]] && usage
HOST="$1"
AUTO_START=false
[[ "${2:-}" == "-y" || "${2:-}" == "--yes" ]] && AUTO_START=true
IP="${HOST_IPS[$HOST]:-}"

if [[ -z "$IP" ]]; then
  echo "Erro: host '$HOST' desconhecido"
  usage
fi

# Base: agldv03 (100.94.221.87)
AGLDV03_IP="100.94.221.87"
AGLDV03_CONFIG="/opt/litellm/config.yaml"

# Para agldv03: usar config do repo (bootstrap). Demais: puxar de agldv03
if [[ "$HOST" == "agldv03" ]]; then
  CONFIG_SOURCE="$CONFIG_DIR/config.yaml"
  if [[ ! -f "$CONFIG_SOURCE" ]]; then
    echo "Erro: $CONFIG_SOURCE não encontrado (bootstrap agldv03)"
    exit 1
  fi
  CONFIG_DESC="repo (bootstrap)"
else
  if ! ssh "root@${AGLDV03_IP}" "test -f ${AGLDV03_CONFIG}" 2>/dev/null; then
    echo "Erro: ${AGLDV03_CONFIG} não encontrado em agldv03 (base)"
    echo "  Deploy agldv03 primeiro ou garanta config em /opt/litellm/"
    exit 1
  fi
  CONFIG_DESC="agldv03 (base)"
fi

ENV_EXAMPLE="$CONFIG_DIR/.env.example"
if [[ ! -f "$ENV_EXAMPLE" ]]; then
  echo "Erro: $ENV_EXAMPLE não encontrado"
  exit 1
fi

echo "=== Deploy LiteLLM → $HOST ($IP) ==="
echo "  Config: $CONFIG_DESC"
echo "  Destino: /opt/litellm"
echo ""

# Criar diretório primeiro
ssh "root@${IP}" "mkdir -p /opt/litellm"

# Docker compose para deploy standalone (sem paths do repo)
# fgsrv06 usa compose com Redis
if [[ "$HOST" == "fgsrv06" ]]; then
  COMPOSE_FILE="$REPO_ROOT/docker/litellm/docker-compose-fgsrv06.yml"
  if [[ -f "$COMPOSE_FILE" ]]; then
    scp "$COMPOSE_FILE" "root@${IP}:/opt/litellm/docker-compose.yml"
  fi
else
COMPOSE_CONTENT='services:
  litellm-db:
    image: postgres:16-alpine
    container_name: litellm-db
    restart: unless-stopped
    environment:
      POSTGRES_USER: litellm
      POSTGRES_PASSWORD: litellm_db_pass
      POSTGRES_DB: litellm
    volumes:
      - litellm-db-data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U litellm -d litellm"]
      interval: 10s
      timeout: 5s
      retries: 5
    networks:
      - litellm-net

  litellm-proxy:
    image: ghcr.io/berriai/litellm:main-latest
    container_name: litellm-proxy
    restart: unless-stopped
    depends_on:
      litellm-db:
        condition: service_healthy
    ports:
      - "4000:4000"
    env_file:
      - .env
    environment:
      - CONFIG_FILE_PATH=/app/config.yaml
      - DATABASE_URL=postgresql://litellm:litellm_db_pass@litellm-db:5432/litellm
    volumes:
      - ./config.yaml:/app/config.yaml:ro
    healthcheck:
      test: ["CMD", "python", "-c", "import urllib.request; urllib.request.urlopen('\''http://localhost:4000/health/readiness'\'', timeout=5)"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 15s
    networks:
      - litellm-net

volumes:
  litellm-db-data:

networks:
  litellm-net:
    driver: bridge
'
  ssh "root@${IP}" "cat > /opt/litellm/docker-compose.yml" <<< "$COMPOSE_CONTENT"
fi

# Copiar config
if [[ "$HOST" == "agldv03" ]]; then
  scp "$CONFIG_SOURCE" "root@${IP}:/opt/litellm/config.yaml"
elif [[ "$HOST" == "fgsrv06" ]]; then
  # fgsrv06: variante remota (Ollama via Tailscale, Redis local)
  ssh "root@${AGLDV03_IP}" "cat ${AGLDV03_CONFIG}" | \
    sed -e 's|http://192.168.0.200:11434|http://100.116.57.111:11434|g' \
        -e 's|host: "192.168.0.137"|host: "litellm-redis"|' \
        -e 's|# Redis Cache Configuration (CT137 - aglsrv1)|# Redis Cache Configuration (local - litellm-redis)|' \
        -e '/password: "os.environ\/REDIS_PASSWORD"/d' | \
    ssh "root@${IP}" "cat > /opt/litellm/config.yaml"
else
  scp "root@${AGLDV03_IP}:${AGLDV03_CONFIG}" "root@${IP}:/opt/litellm/config.yaml"
fi

# Copiar .env.example; criar .env se não existir
scp "$ENV_EXAMPLE" "root@${IP}:/opt/litellm/.env.example"
ssh "root@${IP}" "test -f /opt/litellm/.env || cp /opt/litellm/.env.example /opt/litellm/.env"

# Escrever docker-compose (fgsrv06 já recebeu via scp acima)
if [[ "$HOST" != "fgsrv06" ]]; then
  ssh "root@${IP}" "cat > /opt/litellm/docker-compose.yml" <<< "$COMPOSE_CONTENT"
fi

echo ""
echo "  Arquivos criados em root@${IP}:/opt/litellm/"
echo "  - config.yaml"
echo "  - .env (ou .env.example → editar e renomear)"
echo "  - docker-compose.yml"
echo ""
echo "  IMPORTANTE: Edite /opt/litellm/.env com LITELLM_MASTER_KEY e API keys"
echo ""
if [[ "$AUTO_START" == "true" ]]; then
  DO_START=1
else
  read -p "Iniciar LiteLLM agora? [y/N] " -n 1 -r
  echo
  [[ $REPLY =~ ^[Yy]$ ]] && DO_START=1
fi
if [[ -n "${DO_START:-}" ]]; then
  ssh "root@${IP}" "cd /opt/litellm && docker compose up -d"
  echo ""
  echo "  Verificar: ssh root@${IP} 'curl -s http://localhost:4000/health/readiness'"
  echo "  Configurar OpenClaw local: node scripts/openclaw/use-litellm-local.mjs"
fi
echo ""
echo "=== Concluído ==="
