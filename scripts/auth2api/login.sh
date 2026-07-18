#!/usr/bin/env bash
# OAuth login (manual) — cola o redirect localhost de volta no terminal.
# Providers: anthropic (default) | codex | cursor
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DIR="${AUTH2API_DIR:-$ROOT/docker/auth2api}"
COMPOSE=(docker compose -f "$DIR/docker-compose.yml")

PROVIDER="anthropic"
MANUAL=1
EXTRA=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --provider=*) PROVIDER="${1#*=}" ;;
    --provider) PROVIDER="$2"; shift ;;
    --auto) MANUAL=0 ;;
    --manual) MANUAL=1 ;;
    *) EXTRA+=("$1") ;;
  esac
  shift
done

case "$PROVIDER" in
  anthropic|codex|cursor) ;;
  *)
    echo "Provider inválido: ${PROVIDER}. Aceites: anthropic|codex|cursor" >&2
    exit 1
    ;;
esac

if [[ ! -f "$DIR/config.yaml" ]]; then
  echo "Falta config.yaml — corre: bash scripts/auth2api/bootstrap.sh" >&2
  exit 1
fi

ARGS=(node dist/index.js --config=/config/config.yaml --login "--provider=${PROVIDER}")
# Cursor usa deep-link + poll (sem callback localhost) — --manual não aplica.
if [[ "$PROVIDER" == "cursor" ]]; then
  MANUAL=0
fi
if [[ "$MANUAL" -eq 1 ]]; then
  ARGS+=(--manual)
fi

echo "Provider: ${PROVIDER} (manual=${MANUAL})"
if [[ "$PROVIDER" == "cursor" ]]; then
  echo "Abre o URL loginDeepControl e clica Yes, Log In — o poll completa sozinho."
elif [[ "$MANUAL" -eq 1 ]]; then
  echo "Após autorizar no browser, cola aqui o URL completo do redirect (localhost que falha)."
fi
echo

# Portas de callback (anthropic/codex auto); Cursor não precisa.
RUN_OPTS=(run --rm -T)
if [[ -t 0 && -t 1 ]]; then
  RUN_OPTS=(run --rm -it)
fi
exec "${COMPOSE[@]}" "${RUN_OPTS[@]}" \
  -p "127.0.0.1:54545:54545" \
  -p "127.0.0.1:1455:1455" \
  auth2api \
  "${ARGS[@]}" \
  "${EXTRA[@]+"${EXTRA[@]}"}"
