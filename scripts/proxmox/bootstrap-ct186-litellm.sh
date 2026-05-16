#!/usr/bin/env bash
# Bootstrap LiteLLM no CT186 (Debian + Docker + stack em /opt/agl-litellm).
# Executar dentro do CT186 como root, com clone/cópia do agl-hostman disponível.
#
# Uso:
#   bash bootstrap-ct186-litellm.sh /caminho/para/agl-hostman
#
# Antes: copiar config/litellm/.env para /opt/agl-litellm/.env (segredos; não vem do git).

set -euo pipefail

AGL_HOSTMAN="${1:?Uso: $0 /caminho/para/agl-hostman}"

test -d "${AGL_HOSTMAN}" || { echo "ERRO: diretório inexistente: ${AGL_HOSTMAN}" >&2; exit 1; }
test -f "${AGL_HOSTMAN}/config/litellm/config.yaml" || { echo "ERRO: falta config/litellm/config.yaml" >&2; exit 1; }

export DEBIAN_FRONTEND=noninteractive

if ! command -v docker >/dev/null 2>&1; then
  echo "=== Instalar Docker (get.docker.com) ==="
  apt-get update -qq
  apt-get install -y -qq ca-certificates curl
  curl -fsSL https://get.docker.com | sh
fi

install -d -m 0755 /opt/agl-litellm
cd /opt/agl-litellm

echo "=== Copiar compose e config ==="
install -m 0644 "${AGL_HOSTMAN}/docker/litellm/docker-compose.ct186.yml" /opt/agl-litellm/docker-compose.yml
install -m 0644 "${AGL_HOSTMAN}/config/litellm/config.yaml" /opt/agl-litellm/config.yaml

if [[ ! -f /opt/agl-litellm/.env ]]; then
  echo "ERRO: crie /opt/agl-litellm/.env (ex.: copie de config/litellm/.env no repo ou do agldv03)." >&2
  echo "       Campos típicos: OPENAI_API_KEY, LITELLM_MASTER_KEY, outras chaves referenciadas no config.yaml." >&2
  exit 1
fi

echo "=== Subir LiteLLM ==="
docker compose -f /opt/agl-litellm/docker-compose.yml pull
docker compose -f /opt/agl-litellm/docker-compose.yml up -d

echo "=== Aguardar readiness ==="
for _ in $(seq 1 30); do
  if curl -sf "http://127.0.0.1:4000/health/readiness" >/dev/null; then
    echo "OK: LiteLLM em http://127.0.0.1:4000"
    exit 0
  fi
  sleep 2
done

echo "AVISO: readiness não respondeu a tempo. Ver: docker compose -f /opt/agl-litellm/docker-compose.yml logs --tail=80" >&2
exit 1
