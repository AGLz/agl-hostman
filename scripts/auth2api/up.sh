#!/usr/bin/env bash
# Sobe o proxy só se já existir token OAuth em data/.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DIR="${AUTH2API_DIR:-$ROOT/docker/auth2api}"
COMPOSE=(docker compose -f "$DIR/docker-compose.yml")

shopt -s nullglob
TOKENS=("$DIR"/data/claude-*.json "$DIR"/data/codex-*.json "$DIR"/data/cursor-*.json)
if [[ ${#TOKENS[@]} -eq 0 ]]; then
  echo "Sem tokens em $DIR/data — corre antes:" >&2
  echo "  bash scripts/auth2api/login.sh --provider=anthropic" >&2
  echo "  bash scripts/auth2api/login.sh --provider=codex" >&2
  exit 1
fi

"${COMPOSE[@]}" up -d
echo "auth2api em http://127.0.0.1:${AUTH2API_PORT:-8317}"
