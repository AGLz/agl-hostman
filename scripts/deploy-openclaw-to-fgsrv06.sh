#!/usr/bin/env bash
# Deploy OpenClaw Docker to fgsrv06
# Uso: ./scripts/deploy-openclaw-to-fgsrv06.sh

set -e

REPO_ROOT="/mnt/overpower/apps/dev/agl/openclaw-repo"
HOSTMAN_ROOT="/mnt/overpower/apps/dev/agl/agl-hostman"
HOST="root@100.83.51.9"

echo "=== Deploying OpenClaw Docker to fgsrv06 ==="

# Verificar conectividade
echo "Verificando conectividade com $HOST..."
if ! timeout 5 ssh -o ConnectTimeout=3 -o BatchMode=yes "$HOST" "echo 'OK'" 2>/dev/null; then
    echo "❌ Host inacessível"
    exit 1
fi

echo "✅ Host acessível"

# Criar diretórios
echo "Criando diretórios..."
ssh "$HOST" "mkdir -p ~/openclaw-docker/config ~/openclaw-docker/workspace"

# Copiar docker-compose.yml
echo "Copiando docker-compose.yml..."
scp "$REPO_ROOT/docker-compose.yml" "$HOST:~/openclaw-docker/"

# Copiar configuração
echo "Copiando configuração..."
scp "$HOSTMAN_ROOT/config/openclaw/openclaw-free-only.json" "$HOST:~/openclaw-docker/config/openclaw.json"

# Copiar .env.docker
echo "Copiando .env..."
scp "$REPO_ROOT/.env.docker" "$HOST:~/openclaw-docker/.env"

# Verificar se imagem existe localmente
if docker images openclaw:local --format "{{.ID}}" 2>/dev/null | grep -q .; then
    echo "Transferindo imagem Docker..."
    docker save openclaw:local | ssh "$HOST" "docker load"
fi

# Parar containers existentes
echo "Parando containers existentes..."
ssh "$HOST" "cd ~/openclaw-docker && docker compose down 2>/dev/null || true"

# Iniciar containers
echo "Iniciando containers..."
ssh "$HOST" "cd ~/openclaw-docker && docker compose up -d"

# Aguardar inicialização
echo "Aguardando inicialização..."
sleep 10

# Verificar saúde
echo "Verificando saúde..."
if ssh "$HOST" "curl -s http://localhost:18789/healthz > /dev/null"; then
    echo "✅ OpenClaw gateway healthy!"
else
    echo "⚠️  Gateway não respondeu. Verifique logs:"
    echo "   ssh $HOST 'cd ~/openclaw-docker && docker compose logs -f'"
fi

echo ""
echo "=== Deploy Concluído ==="
echo "Endpoints:"
echo "  Gateway: http://$HOST:18789"
echo "  Health:  http://$HOST:18789/healthz"
