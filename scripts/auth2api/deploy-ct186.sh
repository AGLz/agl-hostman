#!/usr/bin/env bash
# Deploy canónico auth2api no CT186 (não usar agldv04 para Hermes).
# Copia build + tokens OAuth, sobe na rede LiteLLM, inject modelos, smoke.
#
# Pré-requisito: tokens já em docker/auth2api/data/ (login local ou rsync prévio).
# Uso:
#   bash scripts/auth2api/deploy-ct186.sh
#   bash scripts/auth2api/deploy-ct186.sh --skip-build
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
AUTH_DIR="${AUTH2API_DIR:-$ROOT/docker/auth2api}"
CT186_SSH="${LITELLM_SSH_HOST:-root@100.125.249.8}"
REMOTE_AUTH="${AUTH2API_REMOTE_DIR:-/opt/agl-auth2api}"
REMOTE_LITELLM="${LITELLM_REMOTE_DIR:-/opt/agl-litellm}"
SKIP_BUILD=0
BUILD_REMOTE=0

for a in "$@"; do
  case "$a" in
    --skip-build) SKIP_BUILD=1 ;;
    --build-remote) BUILD_REMOTE=1 ;;
    *) echo "Arg desconhecido: $a" >&2; exit 1 ;;
  esac
done

# shellcheck disable=SC1091
set -a
source "$AUTH_DIR/.env"
set +a
[[ -n "${AUTH2API_API_KEY:-}" ]] || { echo "AUTH2API_API_KEY em falta em $AUTH_DIR/.env" >&2; exit 1; }
[[ -f "$AUTH_DIR/config.yaml" ]] || { echo "falta $AUTH_DIR/config.yaml" >&2; exit 1; }

shopt -s nullglob
TOKENS=("$AUTH_DIR"/data/claude-*.json "$AUTH_DIR"/data/codex-*.json)
if [[ ${#TOKENS[@]} -eq 0 ]]; then
  echo "Sem tokens anthropic/codex em $AUTH_DIR/data — corre login.sh primeiro" >&2
  exit 1
fi

echo "=== Deploy auth2api → CT186 ($CT186_SSH) ==="
ssh -o StrictHostKeyChecking=accept-new "$CT186_SSH" "mkdir -p '$REMOTE_AUTH/data' && rm -rf '$REMOTE_AUTH/data'/*"

# Reason: CT186 LXC minimal sem rsync — tar|ssh.
tar -C "$AUTH_DIR" -czf - \
  Dockerfile docker-compose.ct186.yml config.yaml config.example.yaml .env \
  | ssh -o StrictHostKeyChecking=accept-new "$CT186_SSH" "tar -C '$REMOTE_AUTH' -xzf -"

tar -C "$AUTH_DIR/data" -czf - \
  --exclude='*.log' . \
  | ssh -o StrictHostKeyChecking=accept-new "$CT186_SSH" "tar -C '$REMOTE_AUTH/data' -xzf -"

IMAGE_TAG="${AUTH2API_IMAGE_TAG:-ct186}"
if [[ "$SKIP_BUILD" -eq 0 && "$BUILD_REMOTE" -eq 0 ]]; then
  # Reason: CT186 LXC tem DNS flaky no build apk; build no host lab e load remoto.
  echo "Build imagem no host local → agl-auth2api:${IMAGE_TAG}"
  # Reason: compose.ct186 exige rede CT186; build directo evita external network no lab.
  docker build \
    -t "agl-auth2api:${IMAGE_TAG}" \
    -f "$AUTH_DIR/Dockerfile" \
    --build-arg "AUTH2API_REF=${AUTH2API_REF:-a34c011f9fda1013ff3f9299160694c2ab62e4db}" \
    --build-arg "CODEX_CLIENT_VERSION=${CODEX_CLIENT_VERSION:-0.142.5}" \
    "$AUTH_DIR"
  docker save "agl-auth2api:${IMAGE_TAG}" \
    | ssh -o StrictHostKeyChecking=accept-new "$CT186_SSH" "docker load"
elif [[ "$SKIP_BUILD" -eq 0 && "$BUILD_REMOTE" -eq 1 ]]; then
  ssh -o StrictHostKeyChecking=accept-new "$CT186_SSH" \
    "cd '$REMOTE_AUTH' && docker compose -f docker-compose.ct186.yml build"
fi

ssh -o StrictHostKeyChecking=accept-new "$CT186_SSH" bash -s <<REMOTE
set -euo pipefail
cd '$REMOTE_AUTH'
ln -sfn docker-compose.ct186.yml docker-compose.yml
AUTH2API_IMAGE_TAG='${IMAGE_TAG}' docker compose -f docker-compose.ct186.yml up -d
sleep 5
curl -fsS -m 8 http://127.0.0.1:8317/health >/dev/null
echo "auth2api health OK em CT186"
ENVF='$REMOTE_LITELLM/.env'
grep -q '^AUTH2API_BASE_URL=' "\$ENVF" 2>/dev/null \
  && sed -i 's|^AUTH2API_BASE_URL=.*|AUTH2API_BASE_URL=http://agl-auth2api:8317/v1|' "\$ENVF" \
  || echo 'AUTH2API_BASE_URL=http://agl-auth2api:8317/v1' >>"\$ENVF"
grep -q '^AUTH2API_API_KEY=' "\$ENVF" 2>/dev/null \
  && sed -i "s|^AUTH2API_API_KEY=.*|AUTH2API_API_KEY=${AUTH2API_API_KEY}|" "\$ENVF" \
  || echo "AUTH2API_API_KEY=${AUTH2API_API_KEY}" >>"\$ENVF"
echo "LiteLLM .env AUTH2API_* OK"
REMOTE

# Inject model list expandido + recreate proxy
AUTH2API_BASE_URL='http://agl-auth2api:8317/v1' \
  bash "$ROOT/scripts/auth2api/enable-litellm-ct186.sh"

echo "=== Smoke CT186 (via LiteLLM) ==="
ssh -o StrictHostKeyChecking=accept-new "$CT186_SSH" bash -s <<'SMOKE'
set -euo pipefail
set -a; source /opt/agl-litellm/.env; set +a
for m in auth2api-claude-fable-5 auth2api-claude-sonnet auth2api-claude-opus auth2api-gpt-5.5; do
  out="$(curl -sS -m 90 http://127.0.0.1:4000/v1/chat/completions \
    -H "Authorization: Bearer $LITELLM_MASTER_KEY" -H "Content-Type: application/json" \
    -d "{\"model\":\"$m\",\"messages\":[{\"role\":\"user\",\"content\":\"Say OK\"}],\"max_tokens\":16}")"
  echo -n "$m: "
  python3 -c 'import sys,json;d=json.load(sys.stdin);c=d.get("choices",[{}])[0].get("message",{}).get("content");print(repr(c) if c else d.get("error",d))' <<<"$out"
done
SMOKE

echo "Done. Hermes usa só CT186 (100.125.249.8:4000). Lab agldv04 fica opcional."
