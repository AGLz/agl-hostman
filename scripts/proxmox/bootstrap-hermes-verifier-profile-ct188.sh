#!/usr/bin/env bash
# Bootstrap perfil Hermes Verifier (QA Gate, modelo Verdent @Verifier) no CT188.
#
# Uso (root no CT188):
#   bash bootstrap-hermes-verifier-profile-ct188.sh
#   bash bootstrap-hermes-verifier-profile-ct188.sh /mnt/overpower/apps/dev/agl/agl-hostman

set -euo pipefail

AGL_HOSTMAN="${1:-/mnt/overpower/apps/dev/agl/agl-hostman}"
HERMES_ROOT="${HERMES_ROOT:-/opt/agl-hermes}"
HERMES_UID="${HERMES_UID:-10000}"
HERMES_GID="${HERMES_GID:-10000}"
JARVIS_CFG="${HERMES_ROOT}/data/config.yaml"
V_DIR="${HERMES_ROOT}/profiles/verifier"
V_CFG="${V_DIR}/config.yaml"
V_ENV="${V_DIR}/.env"
LITELLM_TS="${LITELLM_TS:-http://100.125.249.8:4000}"
PRIMARY_MODEL="${VERIFIER_MODEL:-or-nemotron-ultra-free}"
FALLBACK_MODEL="${VERIFIER_FALLBACK:-or-owl-alpha}"
AUX_MODEL="${VERIFIER_AUX:-groq-llama-31-8b}"

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

install -d -m 700 -o "${HERMES_UID}" -g "${HERMES_GID}" "${V_DIR}"

if [[ -f "${AGL_HOSTMAN}/docker/hermes/profiles/verifier/SOUL.md" ]]; then
  install -m 0600 -o "${HERMES_UID}" -g "${HERMES_GID}" \
    "${AGL_HOSTMAN}/docker/hermes/profiles/verifier/SOUL.md" "${V_DIR}/SOUL.md"
fi
if [[ -f "${AGL_HOSTMAN}/docker/hermes/profiles/SECOND-BRAIN.md" ]]; then
  install -m 0600 -o "${HERMES_UID}" -g "${HERMES_GID}" \
    "${AGL_HOSTMAN}/docker/hermes/profiles/SECOND-BRAIN.md" "${V_DIR}/SECOND-BRAIN.md"
fi

python3 - "${V_CFG}" "${API_KEY}" "${LITELLM_TS}" "${PRIMARY_MODEL}" "${FALLBACK_MODEL}" "${AUX_MODEL}" <<'PY'
import sys
from pathlib import Path
import yaml

path, api_key, base_url, primary, fallback, aux = sys.argv[1:7]
base = base_url.rstrip("/")
cfg = {
    "model": {
        "provider": "custom", "base_url": base, "default": primary,
        "fallback": fallback, "max_tokens": 8192, "api_key": api_key,
    },
    "providers": {"custom": {"base_url": base}},
    "fallback_model": {"provider": "custom", "base_url": base, "model": fallback, "api_key": api_key},
    "delegation": {"provider": "custom", "base_url": base, "model": aux, "api_key": api_key},
    "auxiliary": {
        "compression": {"provider": "custom", "base_url": base, "model": aux, "api_key": api_key},
    },
    "memory": {
        "memory_enabled": True, "user_profile_enabled": True,
        "memory_char_limit": 2750, "user_char_limit": 2750,
    },
    "verifier": {
        "enabled": True, "reports_to": "jarvis", "role": "qa_gate",
        "review_queue": "/opt/llm-wiki/raw/hermes/review-queue/queue.json",
        "verdicts": ["PASS", "FAIL"],
    },
    "toolsets": ["hermes-cli", "terminal", "file", "skills"],
    "approvals": {"mode": "off", "cron_mode": "approve", "timeout": 300},
    "cron": {"wrap_response": True},
    "_config_version": 1,
}
Path(path).write_text(yaml.safe_dump(cfg, sort_keys=False, allow_unicode=True), encoding="utf-8")
print(f"OK wrote {path}")
PY

cat > "${V_ENV}" <<EOF
AGL_HOSTMAN=${AGL_HOSTMAN}
LITELLM_TS=${LITELLM_TS}
REVIEW_QUEUE=/opt/llm-wiki/raw/hermes/review-queue/queue.json
EOF
chown "${HERMES_UID}:${HERMES_GID}" "${V_CFG}" "${V_ENV}"
chmod 600 "${V_CFG}" "${V_ENV}"

install -d -m 700 -o "${HERMES_UID}" -g "${HERMES_GID}" "${V_DIR}/.hermes"
cp "${V_CFG}" "${V_DIR}/.hermes/config.yaml"
chown "${HERMES_UID}:${HERMES_GID}" "${V_DIR}/.hermes/config.yaml"

# Review-queue partilhada (rw para todos os perfis via mount LLM_WIKI_DIR).
LLM_WIKI_DIR="${LLM_WIKI_DIR:-/opt/agl-llm-wiki}"
install -d -m 777 "${LLM_WIKI_DIR}/raw/hermes/review-queue" 2>/dev/null || true

echo "Verifier profile: ${V_CFG}"
echo "Subir contentor: docker compose -f docker-compose.aglz-quartet.yml up -d hermes-verifier"
