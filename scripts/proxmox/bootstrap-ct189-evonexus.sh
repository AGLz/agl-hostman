#!/usr/bin/env bash
# Bootstrap EvoNexus no CT189 (Debian + Docker + /opt/evonexus).
# O upstream evo-nexus não está neste repo — clonar no CT ou copiar stack do CT242 (fgsrv7).
#
# Uso:
#   bash bootstrap-ct189-evonexus.sh /caminho/para/agl-hostman [http://IP_CT186:4000]
#
# Depois: overlays e rotinas AGLz — scripts/evonexus/* (ver README-evonexus-overlays.md)

set -euo pipefail

AGL_HOSTMAN="${1:?Uso: $0 /caminho/para/agl-hostman [LITELLM_BASE_URL]}"
LITELLM_TAILSCALE_OR_LAN="${2:-http://192.168.0.186:4000}"

export DEBIAN_FRONTEND=noninteractive

if ! command -v docker >/dev/null 2>&1; then
  echo "=== Instalar Docker ==="
  apt-get update -qq
  apt-get install -y -qq ca-certificates curl git
  curl -fsSL https://get.docker.com | sh
fi

apt-get install -y -qq git curl ca-certificates

install -d -m 0755 /opt/evonexus
cd /opt/evonexus

if [[ ! -f /opt/evonexus/docker-compose.hub.yml && ! -f /opt/evonexus/docker-compose.yml ]]; then
  echo "=== Clonar evo-nexus (ajuste EVONEXUS_REPO se necessário) ==="
  EVONEXUS_REPO="${EVONEXUS_REPO:-https://github.com/aglz-io/evo-nexus.git}"
  if [[ ! -d /opt/evonexus/.git ]]; then
    git clone --depth 1 "${EVONEXUS_REPO}" /opt/evonexus-src || true
    if [[ -d /opt/evonexus-src ]]; then
      cp -a /opt/evonexus-src/. /opt/evonexus/
    fi
  fi
fi

if [[ ! -f /opt/evonexus/docker-compose.hub.yml ]]; then
  echo "ERRO: falta docker-compose.hub.yml em /opt/evonexus." >&2
  echo "      Copie a stack do CT242: rsync root@fgsrv7:/opt/evonexus/ /opt/evonexus/" >&2
  echo "      ou defina EVONEXUS_REPO com o repositório correcto." >&2
  exit 1
fi

COMPOSE_FILE="/opt/evonexus/docker-compose.hub.yml"
if [[ ! -f /opt/evonexus/.env ]]; then
  echo "ERRO: crie /opt/evonexus/.env (ANTHROPIC_BASE_URL, ANTHROPIC_AUTH_TOKEN, LITELLM_GATEWAY_URL, etc.)." >&2
  echo "      Base URL sugerida: ${LITELLM_TAILSCALE_OR_LAN}" >&2
  exit 1
fi

echo "=== Stage overlays AGLz do agl-hostman ==="
mkdir -p /opt/evonexus/adw-routines
cp -a "${AGL_HOSTMAN}/scripts/evonexus/adw-routines/"* /opt/evonexus/adw-routines/ 2>/dev/null || true
cp -a "${AGL_HOSTMAN}/scripts/evonexus/adw-routines/custom/." /opt/evonexus/adw-routines/custom/ 2>/dev/null || true
cp "${AGL_HOSTMAN}/scripts/evonexus/sync-providers-anthropic-from-env.py" /opt/evonexus/ 2>/dev/null || true
cp "${AGL_HOSTMAN}/scripts/evonexus/overlays/terminal-server-server.js" /opt/evonexus/server.js.atlas-result-text 2>/dev/null || true

echo "=== Subir stack EvoNexus ==="
docker compose -f "${COMPOSE_FILE}" pull
docker compose -f "${COMPOSE_FILE}" up -d

echo "=== Smoke HTTP (Flask dashboard) ==="
for _ in $(seq 1 30); do
  if curl -sf -o /dev/null -w "%{http_code}" "http://127.0.0.1:8080/" | grep -qE '^[23]'; then
    echo "OK: EvoNexus dashboard responde em :8080"
    echo "     Aplicar deploy-adw-routines adaptado: CTID=189 HOST=local pct …"
    exit 0
  fi
  sleep 4
done

echo "AVISO: :8080 não respondeu. Ver logs: docker compose -f ${COMPOSE_FILE} logs --tail=80" >&2
exit 1
