#!/usr/bin/env bash
# Bootstrap OpenClaw no CT187 (Debian + Docker + stack em /opt/agl-openclaw).
# Executar dentro do CT187 como root.
#
# Uso:
#   bash bootstrap-ct187-openclaw.sh /caminho/para/agl-hostman http://IP_DO_CT186:4000
#
# O segundo argumento é a baseUrl do LiteLLM para models.providers.openai no openclaw.json.
# Alternativa: editar openclaw.json manualmente antes de docker compose up.

set -euo pipefail

AGL_HOSTMAN="${1:?Uso: $0 /caminho/para/agl-hostman [http://IP_CT186:4000]}"
LITELLM_BASE_URL="${2:-}"

test -d "${AGL_HOSTMAN}" || { echo "ERRO: diretório inexistente: ${AGL_HOSTMAN}" >&2; exit 1; }

export DEBIAN_FRONTEND=noninteractive

if ! command -v docker >/dev/null 2>&1; then
  echo "=== Instalar Docker (get.docker.com) ==="
  apt-get update -qq
  apt-get install -y -qq ca-certificates curl
  curl -fsSL https://get.docker.com | sh
fi

install -d -m 0755 /opt/agl-openclaw/config /opt/agl-openclaw/workspace
cd /opt/agl-openclaw

echo "=== Copiar compose ==="
install -m 0644 "${AGL_HOSTMAN}/docker/openclaw/docker-compose.ct187.yml" /opt/agl-openclaw/docker-compose.yml

if [[ ! -f /opt/agl-openclaw/config/openclaw.json ]]; then
  if [[ -f "${AGL_HOSTMAN}/../openclaw-repo/config/openclaw.json" ]]; then
    install -m 0600 "${AGL_HOSTMAN}/../openclaw-repo/config/openclaw.json" /opt/agl-openclaw/config/openclaw.json
  elif [[ -f "${AGL_HOSTMAN}/config/openclaw/openclaw-patch.json" ]]; then
    echo "AVISO: usando apenas openclaw-patch.json não é suficiente — copie openclaw.json completo do openclaw-repo ou agldv03." >&2
    exit 1
  else
    echo "ERRO: coloque /opt/agl-openclaw/config/openclaw.json (ex.: rsync desde openclaw-repo ou CT179)." >&2
    exit 1
  fi
fi

if [[ -n "${LITELLM_BASE_URL}" ]]; then
  echo "=== Ajustar baseUrl LiteLLM em openclaw.json ==="
  python3 "${AGL_HOSTMAN}/scripts/proxmox/patch-openclaw-litellm-baseurl.py" \
    /opt/agl-openclaw/config/openclaw.json "${LITELLM_BASE_URL}"
fi

echo "=== Permissões para utilizador node (uid 1000) nos volumes montados ==="
chown -R 1000:1000 /opt/agl-openclaw/config /opt/agl-openclaw/workspace

if [[ ! -f /opt/agl-openclaw/.env ]]; then
  echo "ERRO: crie /opt/agl-openclaw/.env (OPENCLAW_IMAGE, TELEGRAM_BOT_TOKEN, OPENROUTER_API_KEY, OPENCLAW_GATEWAY_TOKEN, OPENCLAW_CONFIG_DIR=./config, OPENCLAW_WORKSPACE_DIR=./workspace, portas)." >&2
  echo "       Ver docs/LITELLM-OPENCLAW-DEDICATED-LXC.md e docker/openclaw/.env.ct187.example" >&2
  exit 1
fi

echo "=== Subir OpenClaw (só gateway; perfil cli opcional) ==="
if docker image inspect "${OPENCLAW_IMAGE:-agl-openclaw:ops}" >/dev/null 2>&1; then
  docker compose -f /opt/agl-openclaw/docker-compose.yml up -d
else
  docker compose -f /opt/agl-openclaw/docker-compose.yml pull
  docker compose -f /opt/agl-openclaw/docker-compose.yml up -d
fi

set -a
# shellcheck source=/dev/null
source /opt/agl-openclaw/.env
set +a
GW_PORT="${OPENCLAW_GATEWAY_PORT:-28789}"

echo "=== Aguardar healthz (porta host ${GW_PORT}) ==="
for _ in $(seq 1 40); do
  if curl -sf "http://127.0.0.1:${GW_PORT}/healthz" | grep -q '"ok":true'; then
    echo "OK: OpenClaw gateway em http://127.0.0.1:${GW_PORT}"
    exit 0
  fi
  sleep 3
done

echo "AVISO: healthz não respondeu. Ver: docker compose -f /opt/agl-openclaw/docker-compose.yml logs --tail=80" >&2
exit 1
