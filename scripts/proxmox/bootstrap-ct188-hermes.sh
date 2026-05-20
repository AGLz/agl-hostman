#!/usr/bin/env bash
# Bootstrap Hermes Agent no CT188 (Debian + Docker + stack em /opt/agl-hermes).
# Executar dentro do CT188 como root.
#
# Uso:
#   bash bootstrap-ct188-hermes.sh /caminho/para/agl-hostman [http://IP_CT186:4000]
#
# Antes: copiar agl-hermes-config (sem segredos) ou correr `docker compose run … setup`.

set -euo pipefail

AGL_HOSTMAN="${1:?Uso: $0 /caminho/para/agl-hostman [LITELLM_BASE_URL]}"
LITELLM_BASE_URL="${2:-http://192.168.0.186:4000}"

test -d "${AGL_HOSTMAN}" || { echo "ERRO: diretório inexistente: ${AGL_HOSTMAN}" >&2; exit 1; }
test -f "${AGL_HOSTMAN}/docker/hermes/docker-compose.ct188.yml" || {
  echo "ERRO: falta docker/hermes/docker-compose.ct188.yml" >&2
  exit 1
}

export DEBIAN_FRONTEND=noninteractive

if ! command -v docker >/dev/null 2>&1; then
  echo "=== Instalar Docker (get.docker.com) ==="
  apt-get update -qq
  apt-get install -y -qq ca-certificates curl python3-yaml
  curl -fsSL https://get.docker.com | sh
fi

install -d -m 0755 /opt/agl-hermes/data
cd /opt/agl-hermes

echo "=== Copiar compose e exemplo .env ==="
install -m 0644 "${AGL_HOSTMAN}/docker/hermes/docker-compose.ct188.yml" /opt/agl-hermes/docker-compose.yml
if [[ ! -f /opt/agl-hermes/.env ]]; then
  install -m 0600 "${AGL_HOSTMAN}/docker/hermes/.env.ct188.example" /opt/agl-hermes/.env
fi
# API na 8642 (/health) — necessário para healthcheck e integrações
grep -q '^API_SERVER_ENABLED=' /opt/agl-hermes/.env 2>/dev/null || echo 'API_SERVER_ENABLED=true' >>/opt/agl-hermes/.env
grep -q '^API_SERVER_HOST=' /opt/agl-hermes/.env 2>/dev/null || echo 'API_SERVER_HOST=0.0.0.0' >>/opt/agl-hermes/.env
if ! grep -q '^API_SERVER_KEY=.\{8,\}' /opt/agl-hermes/.env 2>/dev/null; then
  echo "API_SERVER_KEY=$(openssl rand -hex 16)" >>/opt/agl-hermes/.env
fi

HERMES_CONFIG_SRC="${AGL_HOSTMAN}/../agl-hermes-config/config.yaml"
if [[ -f "${HERMES_CONFIG_SRC}" ]]; then
  echo "=== Seed config.yaml (agl-hermes-config, sem .env) ==="
  install -d -m 0700 /opt/agl-hermes/data
  if [[ ! -f /opt/agl-hermes/data/config.yaml ]]; then
    install -m 0600 "${HERMES_CONFIG_SRC}" /opt/agl-hermes/data/config.yaml
    python3 - "${LITELLM_BASE_URL}" <<'PY'
import sys
from pathlib import Path
import yaml

base = sys.argv[1].rstrip("/")
path = Path("/opt/agl-hermes/data/config.yaml")
data = yaml.safe_load(path.read_text())
model = data.setdefault("model", {})
model["default"] = model.get("default") or "qwen-coder"
prov = data.setdefault("providers", {})
custom = prov.setdefault("custom", {})
custom["base_url"] = base
path.write_text(yaml.dump(data, default_flow_style=False, allow_unicode=True))
print(f"OK: providers.custom.base_url = {base}")
PY
  fi
fi

echo "=== Subir Hermes gateway ==="
docker compose -f /opt/agl-hermes/docker-compose.yml pull
docker compose -f /opt/agl-hermes/docker-compose.yml up -d hermes-gateway

echo "=== Aguardar health ==="
for _ in $(seq 1 40); do
  if curl -sf "http://127.0.0.1:8642/health" >/dev/null 2>&1; then
    echo "OK: Hermes em http://127.0.0.1:8642 (LiteLLM: ${LITELLM_BASE_URL})"
    exit 0
  fi
  sleep 3
done

echo "AVISO: /health não respondeu. Correr setup interactivo se for primeira vez:" >&2
echo "  cd /opt/agl-hermes && docker compose run --rm hermes-gateway setup" >&2
exit 1
