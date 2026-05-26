#!/usr/bin/env bash
# Sincroniza compose + Dockerfile OpenClaw (CT187) do agl-hostman para /opt/agl-openclaw.
# Garante tag agl-openclaw:ops e .env sem override para imagem upstream sem ssh.
#
# Uso (AGLSRV1 ou máquina com pct + repo):
#   bash scripts/proxmox/pct187-sync-openclaw-stack-from-repo.sh [/caminho/agl-hostman]
#
set -euo pipefail

AGL_HOSTMAN="${1:-}"
if [[ -z "${AGL_HOSTMAN}" ]]; then
  for candidate in \
    "/mnt/overpower/apps/dev/agl/agl-hostman" \
    "${HOME}/agl-hostman" \
    "/opt/agl-hostman"; do
    if [[ -f "${candidate}/docker/openclaw/docker-compose.ct187.yml" ]]; then
      AGL_HOSTMAN="${candidate}"
      break
    fi
  done
fi

test -n "${AGL_HOSTMAN}" && test -d "${AGL_HOSTMAN}" || {
  echo "ERRO: agl-hostman não encontrado. Passe o caminho como 1.º argumento." >&2
  exit 1
}

CT="${CT:-187}"
COMPOSE_SRC="${AGL_HOSTMAN}/docker/openclaw/docker-compose.ct187.yml"
DOCKERFILE_SRC="${AGL_HOSTMAN}/docker/openclaw/Dockerfile.ct187"
ENV_EXAMPLE="${AGL_HOSTMAN}/docker/openclaw/.env.ct187.example"

command -v pct >/dev/null || {
  echo "ERRO: pct não encontrado — executar no AGLSRV1." >&2
  exit 1
}

for f in "${COMPOSE_SRC}" "${DOCKERFILE_SRC}"; do
  test -f "${f}" || { echo "ERRO: falta ${f}" >&2; exit 1; }
done

echo "=== pct push → CT${CT} /opt/agl-openclaw ==="
pct push "${CT}" "${COMPOSE_SRC}" /opt/agl-openclaw/docker-compose.yml
pct push "${CT}" "${DOCKERFILE_SRC}" /opt/agl-openclaw/Dockerfile.ct187
pct push "${CT}" "${DOCKERFILE_SRC}" /opt/agl-openclaw/Dockerfile.ops

pct exec "${CT}" -- bash <<'REMOTE'
set -euo pipefail
cd /opt/agl-openclaw
test -d docker-ssh-node || mkdir -p docker-ssh-node

if [[ -f .env ]]; then
  if grep -q '^OPENCLAW_IMAGE=ghcr.io/openclaw/openclaw:latest' .env; then
    sed -i 's|^OPENCLAW_IMAGE=ghcr.io/openclaw/openclaw:latest|OPENCLAW_IMAGE=agl-openclaw:ops|' .env
    echo "Corrigido .env: OPENCLAW_IMAGE=agl-openclaw:ops"
  fi
  grep -q '^OPENCLAW_SSH_DIR=' .env || echo 'OPENCLAW_SSH_DIR=./docker-ssh-node' >> .env
else
  echo "AVISO: falta /opt/agl-openclaw/.env — copiar de .env.ct187.example" >&2
fi

echo "=== docker compose build + up ==="
docker compose -f docker-compose.yml build --build-arg BUILDKIT_INLINE_CACHE=1 openclaw-gateway \
  || docker build --network=host -f Dockerfile.ct187 -t agl-openclaw:ops .
docker compose -f docker-compose.yml up -d

sleep 6
curl -sf http://127.0.0.1:28789/healthz | head -c 120 || true
echo ""
GW=$(docker ps --format '{{.Names}}' | grep -i gateway | head -1)
if [[ -n "${GW}" ]] && docker exec "${GW}" test -x /usr/bin/ssh 2>/dev/null; then
  docker exec "${GW}" /home/node/.openclaw/workspace/scripts/critical-services-monitor.sh || true
fi
REMOTE

echo "OK: CT${CT} sincronizado. Logs: pct exec ${CT} -- docker logs agl-openclaw-openclaw-gateway-1 --tail 30"
