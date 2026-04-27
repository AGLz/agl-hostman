#!/usr/bin/env bash
# Sincroniza config/litellm/config.yaml do repositório → /opt/litellm e reinicia o proxy.
# Correr no host onde o LiteLLM corre (ex.: agldv03) com o repo montado (ex.: NFS).
# Uso: sudo bash scripts/litellm/sync-litellm-repo-to-opt.sh [--no-restart]
# Opções:
#   --no-restart  só copia + backup + diff; não reinicia o contentor nem espera readiness
#   -h, --help    esta ajuda
# npm: npm run sync:litellm:opt  (requer permissão em /opt/litellm e docker, p.ex. root)
# Ref: scripts/litellm/deploy-litellm-host.sh, docs/LITELLM-MULTI-HOST-DEPLOYMENT.md

set -euo pipefail

NO_RESTART=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --no-restart)
      NO_RESTART=true
      shift
      ;;
    -h|--help)
      cat <<'USAGE'
Uso: sync-litellm-repo-to-opt.sh [--no-restart]

  Copia config/litellm/config.yaml do repo para /opt/litellm/config.yaml,
  com backup, e por omissão reinicia litellm-proxy e espera readiness.

  --no-restart   só cópia + validação diff; não reinicia Docker.

Ex.: sudo bash scripts/litellm/sync-litellm-repo-to-opt.sh
    npm run sync:litellm:opt
USAGE
      exit 0
      ;;
    *)
      echo "Erro: opção desconhecida: $1 (usa --help)"
      exit 1
      ;;
  esac
done

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SRC="$REPO_ROOT/config/litellm/config.yaml"
DEST_DIR="/opt/litellm"
DEST="$DEST_DIR/config.yaml"

if [[ ! -f "$SRC" ]]; then
  echo "Erro: $SRC não encontrado"
  exit 1
fi

if [[ ! -d "$DEST_DIR" ]]; then
  echo "Erro: $DEST_DIR não existe (deploy LiteLLM primeiro)"
  exit 1
fi

if [[ ! -w "$DEST_DIR" ]]; then
  echo "Erro: sem permissão de escrita em $DEST_DIR (usa root ou sudo)"
  exit 1
fi

echo "=== LiteLLM: repo → /opt/litellm ==="
echo "  Origem: $SRC"

if [[ -f "$DEST" ]]; then
  bak="$DEST_DIR/config.yaml.bak.$(date +%Y%m%d%H%M%S)"
  /bin/cp -a "$DEST" "$bak"
  echo "  Backup: $bak"
fi

/bin/cp -f "$SRC" "$DEST"
if ! diff -q "$SRC" "$DEST" >/dev/null; then
  echo "Erro: cópia não coincide com o repo"
  exit 1
fi

echo "  OK: $DEST actualizado"

if [[ "$NO_RESTART" == true ]]; then
  echo "  --no-restart: cópia concluída; reinicia quando quiseres: cd $DEST_DIR && docker compose restart litellm-proxy"
  exit 0
fi

if docker compose version >/dev/null 2>&1; then
  (cd "$DEST_DIR" && docker compose restart litellm-proxy)
else
  echo "Aviso: docker compose indisponível — reinicia manualmente: cd $DEST_DIR && docker compose restart litellm-proxy"
  exit 0
fi

echo "  A aguardar readiness (até ~90s; Prisma/migrate no arranque)..."
for _ in $(seq 1 90); do
  code="$(curl -sS -o /dev/null -w '%{http_code}' --max-time 3 "http://127.0.0.1:4000/health/readiness" 2>/dev/null || echo "000")"
  if [[ "$code" == "200" ]]; then
    echo "  OK: /health/readiness (HTTP $code)"
    exit 0
  fi
  sleep 1
done

echo "Aviso: readiness não respondeu a tempo — ver: docker logs litellm-proxy --tail 50"
exit 1
