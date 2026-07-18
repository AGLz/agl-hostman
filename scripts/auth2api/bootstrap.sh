#!/usr/bin/env bash
# Bootstrap spike auth2api: gera config + build. NÃO sobe sem OAuth (upstream sai).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DIR="${AUTH2API_DIR:-$ROOT/docker/auth2api}"
COMPOSE=(docker compose -f "$DIR/docker-compose.yml")

mkdir -p "$DIR/data"
chmod 700 "$DIR/data"

if [[ ! -f "$DIR/config.yaml" ]]; then
  KEY="$(openssl rand -hex 32)"
  sed "s/CHANGE_ME_RUN_BOOTSTRAP/${KEY}/" "$DIR/config.example.yaml" >"$DIR/config.yaml"
  chmod 600 "$DIR/config.yaml"
  echo "Criado config.yaml com API key (guardar): ${KEY}"
  echo "AUTH2API_API_KEY=${KEY}" >"$DIR/.env"
  chmod 600 "$DIR/.env"
else
  echo "config.yaml já existe — a manter."
fi

# Parar restart loop se alguém fez up sem tokens
"${COMPOSE[@]}" down 2>/dev/null || true

"${COMPOSE[@]}" build

echo
echo "=== auth2api spike (build OK) ==="
echo "1) Login OAuth (obrigatório — o processo não arranca sem contas):"
echo "     bash $ROOT/scripts/auth2api/login.sh --provider=anthropic"
echo "     bash $ROOT/scripts/auth2api/login.sh --provider=codex"
echo "2) Subir proxy:"
echo "     bash $ROOT/scripts/auth2api/up.sh"
echo "3) Smoke:"
echo "     bash $ROOT/scripts/auth2api/smoke-test.sh"
echo "Docs: docs/AUTH2API-SPIKE.md"
echo "AVISO: ToS Anthropic/OpenAI — lab / 1 operador; não Agency multi-tenant."
