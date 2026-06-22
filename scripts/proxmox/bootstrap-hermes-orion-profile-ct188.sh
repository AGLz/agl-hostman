#!/usr/bin/env bash
# Bootstrap perfil Hermes Orion (media *arr) no CT188.
#
# Uso (root no CT188):
#   bash bootstrap-hermes-orion-profile-ct188.sh
#   bash bootstrap-hermes-orion-profile-ct188.sh /mnt/overpower/apps/dev/agl/agl-hostman

set -euo pipefail

AGL_HOSTMAN="${1:-/mnt/overpower/apps/dev/agl/agl-hostman}"
HERMES_ROOT="${HERMES_ROOT:-/opt/agl-hermes}"
HERMES_UID="${HERMES_UID:-10000}"
HERMES_GID="${HERMES_GID:-10000}"
JARVIS_CFG="${HERMES_ROOT}/data/config.yaml"
ORION_DIR="${HERMES_ROOT}/profiles/orion"
ORION_CFG="${ORION_DIR}/config.yaml"
ORION_ENV="${ORION_DIR}/.env"
LITELLM_TS="${LITELLM_TS:-http://100.125.249.8:4000}"
PRIMARY_MODEL="${ORION_MODEL:-glm-4.7-flash}"
FALLBACK_MODEL="${ORION_FALLBACK:-agl-primary-vm110}"
AUX_MODEL="${ORION_AUX:-groq-llama-31-8b}"

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

install -d -m 700 -o "${HERMES_UID}" -g "${HERMES_GID}" "${ORION_DIR}"

if [[ -f "${AGL_HOSTMAN}/docker/hermes/profiles/orion/SOUL.md" ]]; then
  install -m 0600 -o "${HERMES_UID}" -g "${HERMES_GID}" \
    "${AGL_HOSTMAN}/docker/hermes/profiles/orion/SOUL.md" "${ORION_DIR}/SOUL.md"
fi

SKILL_SRC="${AGL_HOSTMAN}/docker/hermes/profiles/orion/skills/agl-media"
ORION_SKILLS="${ORION_DIR}/skills/agl-media"
if [[ -f "${SKILL_SRC}/SKILL.md" ]]; then
  install -d -m 700 -o "${HERMES_UID}" -g "${HERMES_GID}" "${ORION_DIR}/skills"
  rm -rf "${ORION_SKILLS}"
  cp -a "${SKILL_SRC}" "${ORION_SKILLS}"
  chown -R "${HERMES_UID}:${HERMES_GID}" "${ORION_SKILLS}"
  echo "OK orion skill: agl-media"
fi

python3 - "${ORION_CFG}" "${API_KEY}" "${LITELLM_TS}" "${PRIMARY_MODEL}" "${FALLBACK_MODEL}" "${AUX_MODEL}" <<'PY'
import sys
from pathlib import Path
import yaml

path, api_key, base_url, primary, fallback, aux = sys.argv[1:7]
cfg = {
    "model": {
        "provider": "custom",
        "base_url": base_url.rstrip("/"),
        "default": primary,
        "fallback": fallback,
        "max_tokens": 8192,
        "api_key": api_key,
    },
    "providers": {"custom": {"base_url": base_url.rstrip("/")}},
    "fallback_model": {
        "provider": "custom",
        "base_url": base_url.rstrip("/"),
        "model": fallback,
        "api_key": api_key,
    },
    "delegation": {
        "provider": "custom",
        "base_url": base_url.rstrip("/"),
        "model": aux,
        "api_key": api_key,
    },
    "memory": {
        "memory_enabled": True,
        "user_profile_enabled": True,
        "memory_char_limit": 2750,
        "user_char_limit": 2750,
    },
    "skills": {"default": ["agl-media"]},
    "orion": {
        "enabled": True,
        "aglsrv1_ssh": "root@100.107.113.33",
        "media_mode": "grabs-only",
        "verify_cron_hours": 24,
    },
    "terminal": {"env_passthrough": ["AGL_HOSTMAN", "AGLSRV1"]},
    "approvals": {"mode": "off", "cron_mode": "approve", "timeout": 300},
    "cron": {"wrap_response": True},
    "_config_version": 24,
}
Path(path).write_text(yaml.safe_dump(cfg, sort_keys=False, allow_unicode=True), encoding="utf-8")
print(f"OK wrote {path}")
PY

cat > "${ORION_ENV}" <<EOF
AGL_HOSTMAN=${AGL_HOSTMAN}
AGLSRV1=root@100.107.113.33
EOF
chown "${HERMES_UID}:${HERMES_GID}" "${ORION_CFG}" "${ORION_ENV}"
chmod 600 "${ORION_CFG}" "${ORION_ENV}"

install -d -m 700 -o "${HERMES_UID}" -g "${HERMES_GID}" "${ORION_DIR}/.hermes"
cp "${ORION_CFG}" "${ORION_DIR}/.hermes/config.yaml"
chown "${HERMES_UID}:${HERMES_GID}" "${ORION_DIR}/.hermes/config.yaml"

SETUP_CRONS="${AGL_HOSTMAN}/scripts/proxmox/setup-hermes-orion-media-crons-ct188.sh"
[[ -x "${SETUP_CRONS}" ]] && bash "${SETUP_CRONS}" || true

echo "Orion profile: ${ORION_CFG}"
echo "Subir contentor: docker compose -f docker-compose.aglz-quartet.yml up -d hermes-orion"
