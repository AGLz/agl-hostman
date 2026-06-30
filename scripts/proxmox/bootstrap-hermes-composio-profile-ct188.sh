#!/usr/bin/env bash
# Bootstrap perfil Hermes Composio (Integrations Operator — SaaS Actions) no CT188.
#
# Cria perfil + config (modelo no-logging + Composio MCP), .env e .hermes.
# OAuth Composio é concluído à parte: scripts/proxmox/composio-oauth-hermes-ct188.sh
#
# Uso (root no CT188):
#   bash bootstrap-hermes-composio-profile-ct188.sh
#   bash bootstrap-hermes-composio-profile-ct188.sh /mnt/overpower/apps/dev/agl/agl-hostman

set -euo pipefail

AGL_HOSTMAN="${1:-/mnt/overpower/apps/dev/agl/agl-hostman}"
HERMES_ROOT="${HERMES_ROOT:-/opt/agl-hermes}"
HERMES_UID="${HERMES_UID:-10000}"
HERMES_GID="${HERMES_GID:-10000}"
JARVIS_CFG="${HERMES_ROOT}/data/config.yaml"
COMPOSIO_DIR="${HERMES_ROOT}/profiles/composio"
COMPOSIO_CFG="${COMPOSIO_DIR}/config.yaml"
COMPOSIO_ENV="${COMPOSIO_DIR}/.env"
LITELLM_TS="${LITELLM_TS:-http://100.125.249.8:4000}"
PRIMARY_MODEL="${COMPOSIO_MODEL:-or-qwen3-next-free}"
FALLBACK_MODEL="${COMPOSIO_FALLBACK:-agl-sensitive}"
AUX_MODEL="${COMPOSIO_AUX:-groq-llama-31-8b}"
COMPOSIO_OAUTH_PORT="${COMPOSIO_OAUTH_PORT:-18432}"
# API key opcional aqui; o script de OAuth grava-a depois. Passar via env COMPOSIO_API_KEY.
COMPOSIO_API_KEY="${COMPOSIO_API_KEY:-}"

test -f "${JARVIS_CFG}" || { echo "ERRO: falta ${JARVIS_CFG}" >&2; exit 1; }

API_KEY="$(python3 - "${JARVIS_CFG}" <<'PY'
import sys, yaml
from pathlib import Path
cfg = yaml.safe_load(Path(sys.argv[1]).read_text()) or {}
key = (cfg.get("model") or {}).get("api_key") or ""
if not key:
    raise SystemExit("api_key ausente em jarvis config.yaml")
print(key)
PY
)"

install -d -m 700 -o "${HERMES_UID}" -g "${HERMES_GID}" "${COMPOSIO_DIR}"

if [[ -f "${AGL_HOSTMAN}/docker/hermes/profiles/composio/SOUL.md" ]]; then
  install -m 0600 -o "${HERMES_UID}" -g "${HERMES_GID}" \
    "${AGL_HOSTMAN}/docker/hermes/profiles/composio/SOUL.md" "${COMPOSIO_DIR}/SOUL.md"
fi

python3 - "${COMPOSIO_CFG}" "${API_KEY}" "${LITELLM_TS}" "${PRIMARY_MODEL}" "${FALLBACK_MODEL}" "${AUX_MODEL}" "${COMPOSIO_OAUTH_PORT}" <<'PY'
import sys
from pathlib import Path
import yaml

path, api_key, base_url, primary, fallback, aux, oauth_port = sys.argv[1:8]
base = base_url.rstrip("/")
cfg = {
    "model": {
        "provider": "custom",
        "base_url": base,
        "default": primary,
        "fallback": fallback,
        "max_tokens": 8192,
        "api_key": api_key,
    },
    "providers": {"custom": {"base_url": base}},
    "fallback_model": {
        "provider": "custom",
        "base_url": base,
        "model": fallback,
        "api_key": api_key,
    },
    "delegation": {
        "provider": "custom",
        "base_url": base,
        "model": aux,
        "api_key": api_key,
    },
    "memory": {
        "memory_enabled": True,
        "user_profile_enabled": True,
        "memory_char_limit": 2750,
        "user_char_limit": 2750,
    },
    "skills": {"default": ["llm-wiki"]},
    "mcp_servers": {
        "composio": {
            "url": "https://connect.composio.dev/mcp",
            "auth": "oauth",
            "enabled": False,  # ativar após OAuth (composio-oauth-hermes-ct188.sh enable)
            "connect_timeout": 600,
            "timeout": 600,
            "headers": {"x-api-key": "${COMPOSIO_API_KEY}"},
            "oauth": {
                "redirect_port": int(oauth_port),
                "client_name": "Hermes Agent AGLz CT188 (composio)",
                "timeout": 600,
            },
        }
    },
    "terminal": {"env_passthrough": ["WIKI_PATH", "COMPOSIO_API_KEY"]},
    "approvals": {"mode": "off", "cron_mode": "approve", "timeout": 300},
    "cron": {"wrap_response": True},
    "_config_version": 24,
}
Path(path).write_text(yaml.safe_dump(cfg, sort_keys=False, allow_unicode=True), encoding="utf-8")
print(f"OK wrote {path}")
PY

# .env: WIKI_PATH + (opcional) COMPOSIO_API_KEY
touch "${COMPOSIO_ENV}"
grep -q '^WIKI_PATH=' "${COMPOSIO_ENV}" 2>/dev/null || echo "WIKI_PATH=/opt/llm-wiki/wiki" >> "${COMPOSIO_ENV}"
if [[ -n "${COMPOSIO_API_KEY}" ]]; then
  if grep -q '^COMPOSIO_API_KEY=' "${COMPOSIO_ENV}" 2>/dev/null; then
    sed -i "s|^COMPOSIO_API_KEY=.*|COMPOSIO_API_KEY=${COMPOSIO_API_KEY}|" "${COMPOSIO_ENV}"
  else
    echo "COMPOSIO_API_KEY=${COMPOSIO_API_KEY}" >> "${COMPOSIO_ENV}"
  fi
fi

chown "${HERMES_UID}:${HERMES_GID}" "${COMPOSIO_CFG}" "${COMPOSIO_ENV}"
chmod 600 "${COMPOSIO_CFG}" "${COMPOSIO_ENV}"

install -d -m 700 -o "${HERMES_UID}" -g "${HERMES_GID}" "${COMPOSIO_DIR}/.hermes"
cp "${COMPOSIO_CFG}" "${COMPOSIO_DIR}/.hermes/config.yaml"
chown "${HERMES_UID}:${HERMES_GID}" "${COMPOSIO_DIR}/.hermes/config.yaml"

echo "Composio profile: ${COMPOSIO_CFG}"
echo "Subir contentor: docker compose -f docker-compose.aglz-quartet.yml up -d hermes-composio"
echo "OAuth Composio:   bash scripts/proxmox/composio-oauth-hermes-ct188.sh configure  (HERMES_CONTAINER=agl-hermes-composio)"
