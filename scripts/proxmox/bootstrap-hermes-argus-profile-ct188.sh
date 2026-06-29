#!/usr/bin/env bash
# Bootstrap perfil Hermes Argus (Quota Steward / LLM FinOps) no CT188.
#
# Uso (root no CT188):
#   bash bootstrap-hermes-argus-profile-ct188.sh
#   bash bootstrap-hermes-argus-profile-ct188.sh /mnt/overpower/apps/dev/agl/agl-hostman

set -euo pipefail

AGL_HOSTMAN="${1:-/mnt/overpower/apps/dev/agl/agl-hostman}"
HERMES_ROOT="${HERMES_ROOT:-/opt/agl-hermes}"
HERMES_UID="${HERMES_UID:-10000}"
HERMES_GID="${HERMES_GID:-10000}"
JARVIS_CFG="${HERMES_ROOT}/data/config.yaml"
ARGUS_DIR="${HERMES_ROOT}/profiles/argus"
ARGUS_CFG="${ARGUS_DIR}/config.yaml"
ARGUS_ENV="${ARGUS_DIR}/.env"
LITELLM_TS="${LITELLM_TS:-http://100.125.249.8:4000}"
MONITOR_API_URL="${MONITOR_API_URL:-}"
PRIMARY_MODEL="${ARGUS_MODEL:-glm-4.7-flash}"
FALLBACK_MODEL="${ARGUS_FALLBACK:-agl-primary-vm110}"
AUX_MODEL="${ARGUS_AUX:-groq-llama-31-8b}"

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

install -d -m 700 -o "${HERMES_UID}" -g "${HERMES_GID}" "${ARGUS_DIR}"

if [[ -f "${AGL_HOSTMAN}/docker/hermes/profiles/argus/SOUL.md" ]]; then
  install -m 0600 -o "${HERMES_UID}" -g "${HERMES_GID}" \
    "${AGL_HOSTMAN}/docker/hermes/profiles/argus/SOUL.md" "${ARGUS_DIR}/SOUL.md"
fi

# Skill cross-harness canónica (.claude/skills) → perfil Argus.
SKILL_SRC="${AGL_HOSTMAN}/.claude/skills/agl-llm-monitor"
ARGUS_SKILLS="${ARGUS_DIR}/skills/agl-llm-monitor"
if [[ -f "${SKILL_SRC}/SKILL.md" ]]; then
  install -d -m 700 -o "${HERMES_UID}" -g "${HERMES_GID}" "${ARGUS_DIR}/skills"
  rm -rf "${ARGUS_SKILLS}"
  cp -a "${SKILL_SRC}" "${ARGUS_SKILLS}"
  chown -R "${HERMES_UID}:${HERMES_GID}" "${ARGUS_SKILLS}"
  echo "OK argus skill: agl-llm-monitor"
fi

python3 - "${ARGUS_CFG}" "${API_KEY}" "${LITELLM_TS}" "${PRIMARY_MODEL}" "${FALLBACK_MODEL}" "${AUX_MODEL}" "${MONITOR_API_URL}" <<'PY'
import sys
from pathlib import Path
import yaml

path, api_key, base_url, primary, fallback, aux, monitor_api = sys.argv[1:8]
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
    "skills": {"default": ["agl-llm-monitor"]},
    "argus": {
        "enabled": True,
        "litellm_ts": base_url.rstrip("/"),
        "monitor_api_url": monitor_api,
        "reports_to": "jarvis",
        "delegate_litellm_apply_to": "werner",
        "approval_required_for_litellm_changes": True,
        "auto_failover_free_tier": True,
        "free_tier_limited": True,
        "watch_free_tier": True,
        "min_context_guard": True,
        "watch_windows": ["5h", "weekly", "monthly", "rate_limit", "context_window"],
    },
    "terminal": {"env_passthrough": ["AGL_HOSTMAN", "LITELLM_TS", "MONITOR_API_URL"]},
    "approvals": {"mode": "off", "cron_mode": "approve", "timeout": 300},
    "cron": {"wrap_response": True},
    "_config_version": 24,
}
Path(path).write_text(yaml.safe_dump(cfg, sort_keys=False, allow_unicode=True), encoding="utf-8")
print(f"OK wrote {path}")
PY

cat > "${ARGUS_ENV}" <<EOF
AGL_HOSTMAN=${AGL_HOSTMAN}
LITELLM_TS=${LITELLM_TS}
MONITOR_API_URL=${MONITOR_API_URL}
EOF
chown "${HERMES_UID}:${HERMES_GID}" "${ARGUS_CFG}" "${ARGUS_ENV}"
chmod 600 "${ARGUS_CFG}" "${ARGUS_ENV}"

install -d -m 700 -o "${HERMES_UID}" -g "${HERMES_GID}" "${ARGUS_DIR}/.hermes"
cp "${ARGUS_CFG}" "${ARGUS_DIR}/.hermes/config.yaml"
chown "${HERMES_UID}:${HERMES_GID}" "${ARGUS_DIR}/.hermes/config.yaml"

SETUP_CRONS="${AGL_HOSTMAN}/scripts/proxmox/setup-hermes-argus-monitor-crons-ct188.sh"
[[ -x "${SETUP_CRONS}" ]] && bash "${SETUP_CRONS}" || true

echo "Argus profile: ${ARGUS_CFG}"
echo "Subir contentor: docker compose -f docker-compose.aglz-quartet.yml up -d hermes-argus"
