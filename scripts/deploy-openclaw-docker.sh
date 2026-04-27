#!/usr/bin/env bash
# Build and Deploy OpenClaw with Docker
# Last Updated: 2026-04-13 (Docker migration)
# Usage: ./scripts/deploy-openclaw-docker.sh [build|deploy|start|stop|logs|validate]

set -e
REPO_ROOT="/mnt/overpower/apps/dev/agl/openclaw-repo"
HOSTMAN_ROOT="/mnt/overpower/apps/dev/agl/agl-hostman"

COMMAND="${1:-help}"

# --- BUILD ---
build_image() {
  echo "=== Building OpenClaw Docker Image ==="
  cd "$REPO_ROOT"

  # Build with Docker
  docker build -t openclaw:local .

  echo ""
  echo "✅ Image built: openclaw:local"
  docker images openclaw:local
}

# --- DEPLOY ---
deploy_config() {
  echo "=== Deploying OpenClaw Configuration ==="

  # Verificar variáveis de ambiente
  if [[ -z "$OPENROUTER_API_KEY" ]]; then
    echo "⚠️  OPENROUTER_API_KEY não definida"
    echo "   export OPENROUTER_API_KEY='sk-or-v1-...'"
    exit 1
  fi

  # Criar diretórios locais
  mkdir -p "$REPO_ROOT/config"
  mkdir -p "$REPO_ROOT/workspace"

  # Copiar configuração FREE-only
  cp "$HOSTMAN_ROOT/config/openclaw/openclaw-free-only.json" "$REPO_ROOT/config/openclaw.json"

  # Criar .env para Docker Compose
  cat > "$REPO_ROOT/.env" <<EOF
OPENCLAW_IMAGE=openclaw:local
OPENROUTER_API_KEY=${OPENROUTER_API_KEY}
DASHSCOPE_API_KEY=${DASHSCOPE_API_KEY:-}
ZAI_API_KEY=${ZAI_API_KEY:-}
OPENCLAW_GATEWAY_BIND=lan
OPENCLAW_GATEWAY_PORT=18789
OPENCLAW_BRIDGE_PORT=18790
OPENCLAW_TZ=UTC
OPENCLAW_CONFIG_DIR=./config
OPENCLAW_WORKSPACE_DIR=./workspace
EOF

  echo "✅ Configuration deployed"
}

# --- START ---
start_local() {
  echo "=== Starting OpenClaw Locally (Docker) ==="
  cd "$REPO_ROOT"

  # Parar containers existentes
  docker compose down 2>/dev/null || true

  # Iniciar containers
  docker compose up -d

  echo ""
  echo "⏳ Aguardando gateway iniciar..."
  sleep 10

  # Verificar saúde
  if curl -s http://localhost:18789/healthz > /dev/null; then
    echo "✅ Gateway healthy!"
  else
    echo "⚠️  Gateway não respondeu. Verifique logs:"
    echo "   docker compose logs -f"
  fi

  echo ""
  echo "📋 Endpoints:"
  echo "   Gateway: http://localhost:18789"
  echo "   Health:  http://localhost:18789/healthz"
  echo ""
  echo "📋 Teste:"
  echo "   docker compose exec openclaw-cli openclaw agent -m 'Hello' --to +15550000000"
}

# --- STOP ---
stop_local() {
  echo "=== Stopping OpenClaw (Docker) ==="
  cd "$REPO_ROOT"
  docker compose down
  echo "✅ Stopped"
}

# --- LOGS ---
logs_local() {
  cd "$REPO_ROOT"
  docker compose logs -f
}

# --- DEPLOY REMOTO ---
deploy_remote() {
  echo "=== Deploying OpenClaw to Remote Hosts ==="

  if [[ -z "$OPENROUTER_API_KEY" ]]; then
    echo "⚠️  OPENROUTER_API_KEY não definida"
    exit 1
  fi

  for host in "${HOSTS[@]}"; do
    echo ""
    echo "=== Deploying to $host ==="

    # Testar conectividade
    if ! timeout 5 ssh -o ConnectTimeout=3 -o BatchMode=yes "$host" "echo 'OK'" 2>/dev/null; then
      echo "  ⚠️  Host inacessível (pulando)"
      continue
    fi

    # Criar diretórios
    ssh "$host" "mkdir -p ~/openclaw-docker/config ~/openclaw-docker/workspace"

    # Copiar arquivos
    scp "$REPO_ROOT/docker-compose.yml" "$host:~/openclaw-docker/"
    scp "$HOSTMAN_ROOT/config/openclaw/openclaw-free-only.json" "$host:~/openclaw-docker/config/openclaw.json"

    # Criar .env remoto
    ssh "$host" "cat > ~/openclaw-docker/.env" <<EOF
OPENCLAW_IMAGE=openclaw:local
OPENROUTER_API_KEY=${OPENROUTER_API_KEY}
DASHSCOPE_API_KEY=${DASHSCOPE_API_KEY:-}
ZAI_API_KEY=${ZAI_API_KEY:-}
OPENCLAW_GATEWAY_BIND=lan
OPENCLAW_GATEWAY_PORT=18789
OPENCLAW_BRIDGE_PORT=18790
OPENCLAW_TZ=UTC
OPENCLAW_CONFIG_DIR=./config
OPENCLAW_WORKSPACE_DIR=./workspace
EOF

    # Copiar imagem Docker (se existir localmente)
    if docker images openclaw:local --format "{{.ID}}" | grep -q .; then
      echo "  Salvando imagem Docker..."
      docker save openclaw:local | ssh "$host" "docker load"
    fi

    # Iniciar containers
    ssh "$host" "cd ~/openclaw-docker && docker compose down && docker compose up -d"

    echo "  ✅ $host deployado"
  done

  echo ""
  echo "=== Deploy Remoto Concluído ==="
}

# --- TEST ---
test_local() {
  echo "=== Testing OpenClaw (Docker) ==="
  cd "$REPO_ROOT"

  echo "Testando health endpoint..."
  curl -s http://localhost:18789/healthz | jq . || echo "Health check failed"

  echo ""
  echo "Testando agente..."
  docker compose exec -T openclaw-cli openclaw agent -m "Hello, respond with just 'OK'" --to +15550000000
}

# --- MAIN ---
case "$COMMAND" in
  build)
    build_image
    ;;
  deploy)
    deploy_config
    ;;
  start)
    start_local
    ;;
  stop)
    stop_local
    ;;
  logs)
    logs_local
    ;;
  remote)
    deploy_remote
    ;;
  test)
    test_local
    ;;
  all)
    build_image
    deploy_config
    start_local
    test_local
    ;;
  validate)
    echo "=== Running OpenClaw Validation ==="
    bash "$HOSTMAN_ROOT/scripts/openclaw/validate-openclaw-docker.sh" --verbose
    echo ""
    echo "=== Running Health vs Schedules ==="
    bash "$HOSTMAN_ROOT/scripts/openclaw/health-vs-schedules.sh" --verbose
    ;;
  *)
    echo "Uso: $0 {build|deploy|start|stop|logs|remote|test|validate|all}"
    echo ""
    echo "Comandos:"
    echo "  build     - Build Docker image"
    echo "  deploy    - Deploy configuration files"
    echo "  start     - Start containers locally"
    echo "  stop      - Stop containers"
    echo "  logs      - Show container logs"
    echo "  remote    - Deploy to remote hosts"
    echo "  test      - Test OpenClaw"
    echo "  validate  - Run full validation suite"
    echo "  all       - Build, deploy, start, and test"
    exit 1
    ;;
esac
