#!/usr/bin/env bash
# Deploy local agl-hostman a partir do mount NFS (não usar //AGLFS1/...).
# Uso: bash scripts/deployment/deploy-mount-path.sh [--skip-docker] [--skip-tests]

set -euo pipefail

REPO_ROOT="/mnt/overpower/apps/dev/agl/agl-hostman"
SRC="${REPO_ROOT}/src"
DB_SQLITE="${SRC}/database/database.sqlite"
SKIP_DOCKER=false
SKIP_TESTS=false

for arg in "$@"; do
    case "$arg" in
        --skip-docker) SKIP_DOCKER=true ;;
        --skip-tests) SKIP_TESTS=true ;;
        -h|--help)
            echo "Usage: $0 [--skip-docker] [--skip-tests]"
            exit 0
            ;;
    esac
done

log() { printf '[deploy-mount] %s\n' "$*"; }

if [[ ! -d "$REPO_ROOT" ]]; then
    echo "Repo não encontrado: $REPO_ROOT" >&2
    exit 1
fi

cd "$SRC"

# Garantir path SQLite no .env (evita //AGLFS1/... no Linux)
if [[ -f .env ]] && grep -q 'AGLFS1' .env 2>/dev/null; then
    sed -i 's|DB_DATABASE=//AGLFS1/overpower/apps/dev/agl/agl-hostman/src/database/database.sqlite|DB_DATABASE=/mnt/overpower/apps/dev/agl/agl-hostman/src/database/database.sqlite|g' .env
    log "DB_DATABASE corrigido para path do mount"
fi

mkdir -p "$(dirname "$DB_SQLITE")"
touch "$DB_SQLITE"

log "composer install"
composer install --no-interaction --prefer-dist

if [[ -f package.json ]]; then
    log "npm ci && npm run build"
    npm ci
    npm run build
fi

log "migrate (SQLite no mount)"
php artisan migrate --force

if [[ "$SKIP_TESTS" != true ]]; then
    log "testes auth.md"
    php artisan test tests/Feature/AuthMd/AuthMdProtocolTest.php
fi

php artisan route:clear
php artisan config:clear
php artisan view:clear

if [[ "$SKIP_DOCKER" != true ]]; then
    cd "$REPO_ROOT"
    log "docker compose up (cwd=${REPO_ROOT})"
    if docker compose build app nginx && docker compose up -d app nginx db redis; then
        sleep 5
        docker compose exec -T app php artisan migrate --force
        docker compose exec -T app php artisan route:clear
        docker compose exec -T app php artisan config:clear
        log "Docker OK — túnel: http://127.0.0.1:${NGINX_TUNNEL_PORT:-8055}"
    else
        log "AVISO: Docker falhou (cgroup/systemd em LXC é comum). App actualizada no mount; usar nginx host em /etc/nginx/sites-available/ah.aglz.io.conf ou corrigir permissões NFS para www-data em ${SRC}/public"
    fi
fi

log "concluído — repo: ${REPO_ROOT}"
log "smoke local: cd ${SRC} && php artisan serve --host=127.0.0.1 --port=18055 && curl http://127.0.0.1:18055/auth.md"
