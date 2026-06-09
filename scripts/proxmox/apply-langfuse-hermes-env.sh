#!/usr/bin/env bash
# Propaga HERMES_LANGFUSE_* de /root/.aglz-langfuse.env para os 4 profiles + activa plugin.
#
# Uso (root no CT188):
#   bash apply-langfuse-hermes-env.sh

set -euo pipefail

AGL_HOSTMAN="${AGL_HOSTMAN:-/mnt/overpower/apps/dev/agl/agl-hostman}"
HERMES_ROOT="${HERMES_ROOT:-/opt/agl-hermes}"
KEYS_FILE="/root/.aglz-langfuse.env"

test -f "${KEYS_FILE}" || {
  echo "ERRO: ${KEYS_FILE} inexistente — criar keys na UI Langfuse primeiro" >&2
  exit 1
}
chmod 600 "${KEYS_FILE}"

# shellcheck disable=SC1090
source "${KEYS_FILE}"

for var in HERMES_LANGFUSE_PUBLIC_KEY HERMES_LANGFUSE_SECRET_KEY; do
  if [[ -z "${!var:-}" ]] || [[ "${!var}" == *CHANGE_ME* ]] || [[ "${!var}" == *...* ]]; then
    echo "ERRO: ${var} inválido em ${KEYS_FILE}" >&2
    exit 1
  fi
done

HERMES_LANGFUSE_BASE_URL="${HERMES_LANGFUSE_BASE_URL:-http://langfuse-web:3000}"
HERMES_LANGFUSE_ENV="${HERMES_LANGFUSE_ENV:-production}"

profile_dir() {
  local agent="$1"
  if [[ "${agent}" == "jarvis" ]]; then
    echo "${HERMES_ROOT}/data"
  else
    echo "${HERMES_ROOT}/profiles/${agent}"
  fi
}

upsert_env() {
  local file="$1"
  local key="$2"
  local val="$3"
  touch "${file}"
  if grep -q "^${key}=" "${file}"; then
    sed -i "s|^${key}=.*|${key}=${val}|" "${file}"
  else
    echo "${key}=${val}" >>"${file}"
  fi
}

enable_langfuse_plugin() {
  local cfg="$1"
  python3 - "${cfg}" <<'PY'
import sys
from pathlib import Path
import yaml

path = sys.argv[1]
cfg = yaml.safe_load(Path(path).read_text()) or {}
plugins = cfg.setdefault("plugins", {})
enabled = plugins.setdefault("enabled", [])
if not isinstance(enabled, list):
    enabled = []
    plugins["enabled"] = enabled
needle = "observability/langfuse"
if needle not in enabled:
    enabled.append(needle)
Path(path).write_text(yaml.dump(cfg, default_flow_style=False, allow_unicode=True))
print("OK plugin", path)
PY
}

for agent in jarvis elon satya werner; do
  pdir="$(profile_dir "${agent}")"
  envf="${pdir}/.env"
  test -d "${pdir}" || { echo "WARN: ${pdir} inexistente, saltar" >&2; continue; }
  upsert_env "${envf}" "HERMES_LANGFUSE_PUBLIC_KEY" "${HERMES_LANGFUSE_PUBLIC_KEY}"
  upsert_env "${envf}" "HERMES_LANGFUSE_SECRET_KEY" "${HERMES_LANGFUSE_SECRET_KEY}"
  upsert_env "${envf}" "HERMES_LANGFUSE_BASE_URL" "${HERMES_LANGFUSE_BASE_URL}"
  upsert_env "${envf}" "HERMES_LANGFUSE_ENV" "${HERMES_LANGFUSE_ENV}"
  chmod 600 "${envf}"
  if [[ -f "${pdir}/config.yaml" ]]; then
    enable_langfuse_plugin "${pdir}/config.yaml"
  fi
  chown -R 10000:10000 "${pdir}" 2>/dev/null || true
  echo "OK langfuse env ${agent}"
done

COMPOSE_SRC="${AGL_HOSTMAN}/docker/hermes/docker-compose.aglz-quartet.ct188.yml"
if [[ -f "${COMPOSE_SRC}" ]]; then
  install -m 0644 "${COMPOSE_SRC}" "${HERMES_ROOT}/docker-compose.aglz-quartet.yml"
fi

cd "${HERMES_ROOT}"
docker compose -f docker-compose.aglz-quartet.yml up -d --force-recreate

echo ""
echo "Langfuse activo nos 4 gateways. UI: http://127.0.0.1:3000"
