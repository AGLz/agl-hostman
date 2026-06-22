#!/usr/bin/env bash
# Configura perfil Hermes curator no CT188 (config.yaml + .env) para cron curator-maintenance.
#
# Uso (root no CT188):
#   bash bootstrap-hermes-curator-profile-ct188.sh
#   bash bootstrap-hermes-curator-profile-ct188.sh /mnt/overpower/apps/dev/agl/agl-hostman

set -euo pipefail

AGL_HOSTMAN="${1:-/mnt/overpower/apps/dev/agl/agl-hostman}"
HERMES_ROOT="${HERMES_ROOT:-/opt/agl-hermes}"
HERMES_UID="${HERMES_UID:-10000}"
HERMES_GID="${HERMES_GID:-10000}"
JARVIS_CFG="${HERMES_ROOT}/data/config.yaml"
CURATOR_DIR="${HERMES_ROOT}/profiles/curator"
CURATOR_CFG="${CURATOR_DIR}/config.yaml"
CURATOR_ENV="${CURATOR_DIR}/.env"
LITELLM_LAN="${LITELLM_LAN:-http://100.125.249.8:4000}"
PRIMARY_MODEL="${CURATOR_MODEL:-groq-llama-31-8b}"
FALLBACK_MODEL="${CURATOR_FALLBACK:-or-nemotron-super-free}"

migrate_curator_legacy() {
  local legacy="${HERMES_ROOT}/data/profiles/curator"
  if [[ -d "${legacy}" ]] && [[ ! -f "${CURATOR_DIR}/config.yaml" ]]; then
    echo "=== Migrar curator legado data/profiles → profiles/curator ==="
    install -d -m 700 -o "${HERMES_UID}" -g "${HERMES_GID}" "${CURATOR_DIR}"
    cp -a "${legacy}/." "${CURATOR_DIR}/"
  fi
}
migrate_curator_legacy

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

install -d -m 700 -o "${HERMES_UID}" -g "${HERMES_GID}" "${CURATOR_DIR}"

if [[ -f "${AGL_HOSTMAN}/docker/hermes/profiles/curator/SOUL.md" ]]; then
  install -m 0600 -o "${HERMES_UID}" -g "${HERMES_GID}" \
    "${AGL_HOSTMAN}/docker/hermes/profiles/curator/SOUL.md" "${CURATOR_DIR}/SOUL.md"
fi

python3 - "${CURATOR_CFG}" "${API_KEY}" "${LITELLM_LAN}" "${PRIMARY_MODEL}" "${FALLBACK_MODEL}" <<'PY'
import sys
from pathlib import Path
import yaml

path, api_key, base_url, primary, fallback = sys.argv[1:6]
cfg = {
    "model": {
        "provider": "custom",
        "base_url": base_url.rstrip("/"),
        "default": primary,
        "fallback": fallback,
        "api_key": api_key,
    },
    "providers": {"custom": {"base_url": base_url.rstrip("/")}},
    "fallback_providers": [],
    "fallback_model": {
        "provider": "custom",
        "base_url": base_url.rstrip("/"),
        "model": fallback,
        "api_key": api_key,
    },
    "memory": {
        "memory_enabled": True,
        "user_profile_enabled": True,
        "memory_char_limit": 2750,
        "user_char_limit": 2750,
    },
    "skills": {"default": ["llm-wiki"]},
    "curator": {
        "enabled": True,
        "interval_hours": 168,
        "min_idle_hours": 2,
        "stale_after_days": 30,
        "archive_after_days": 90,
        "backup": {"enabled": True, "keep": 5},
    },
    "terminal": {"env_passthrough": ["WIKI_PATH"]},
    "approvals": {"mode": "off", "cron_mode": "approve"},
    "cron": {"wrap_response": True},
    "_config_version": 24,
}
Path(path).write_text(yaml.safe_dump(cfg, sort_keys=False, allow_unicode=True), encoding="utf-8")
print(f"OK wrote {path}")
PY

cat > "${CURATOR_ENV}" <<EOF
WIKI_PATH=/opt/llm-wiki/wiki
EOF
chown "${HERMES_UID}:${HERMES_GID}" "${CURATOR_CFG}" "${CURATOR_ENV}"
chmod 600 "${CURATOR_CFG}" "${CURATOR_ENV}"

install -d -m 700 -o "${HERMES_UID}" -g "${HERMES_GID}" "${CURATOR_DIR}/.hermes"
cp "${CURATOR_CFG}" "${CURATOR_DIR}/.hermes/config.yaml"
chown "${HERMES_UID}:${HERMES_GID}" "${CURATOR_DIR}/.hermes/config.yaml"
chmod 600 "${CURATOR_DIR}/.hermes/config.yaml"

SKILL_SRC="${HERMES_ROOT}/data/skills/research/llm-wiki"
CURATOR_SKILLS="${CURATOR_DIR}/skills/research"
if [[ -f "${SKILL_SRC}/SKILL.md" ]]; then
  install -d -m 700 -o "${HERMES_UID}" -g "${HERMES_GID}" "${CURATOR_SKILLS}"
  ln -sfn "${SKILL_SRC}" "${CURATOR_SKILLS}/llm-wiki"
  chown -h "${HERMES_UID}:${HERMES_GID}" "${CURATOR_SKILLS}/llm-wiki" 2>/dev/null || true
  echo "OK curator skill: llm-wiki"
else
  echo "AVISO: ${SKILL_SRC}/SKILL.md em falta — correr fix-curator-llm-wiki-skill-ct188.sh após instalar skill no jarvis" >&2
fi

FIX_SCRIPT="${AGL_HOSTMAN}/scripts/proxmox/fix-curator-llm-wiki-skill-ct188.sh"
if [[ -x "${FIX_SCRIPT}" ]]; then
  bash "${FIX_SCRIPT}" "${AGL_HOSTMAN}" || true
fi

echo "=== curator doctor (profile) ==="
docker exec -e HERMES_HOME=/opt/data agl-hermes-jarvis \
  /opt/hermes/.venv/bin/hermes doctor 2>&1 | grep -i curator || true

echo "Curator profile: ${CURATOR_DIR}"
echo "Integrar contentor: bash configure-hermes-curator-orion-ct188.sh"
echo "Reiniciar: docker restart agl-hermes-curator 2>/dev/null || docker restart agl-hermes-jarvis"
