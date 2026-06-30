#!/usr/bin/env bash
# Segundo cérebro bidireccional: skill llm-wiki + WIKI_PATH em todos os agentes Hermes CT188.
#
# Pré-requisito: skill global em data/skills/research/llm-wiki (bundled Hermes ou hermes skills install).
# Mount compose :rw em /opt/llm-wiki.
#
# Uso (root no CT188):
#   bash fix-hermes-llm-wiki-secondbrain-ct188.sh
#   bash fix-hermes-llm-wiki-secondbrain-ct188.sh /mnt/overpower/apps/dev/agl/agl-hostman

set -euo pipefail

AGL_HOSTMAN="${1:-/mnt/overpower/apps/dev/agl/agl-hostman}"
HERMES_ROOT="${HERMES_ROOT:-/opt/agl-hermes}"
HERMES_UID="${HERMES_UID:-10000}"
HERMES_GID="${HERMES_GID:-10000}"
WIKI_PATH="${WIKI_PATH:-/opt/llm-wiki/wiki}"
SECOND_BRAIN_SRC="${AGL_HOSTMAN}/docker/hermes/profiles/SECOND-BRAIN.md"

AGENTS=(jarvis elon satya werner curator orion argus verifier composio)
SKILL_SRC="${HERMES_ROOT}/data/skills/research/llm-wiki"
CURATOR_DATA="${CURATOR_DATA_DIR:-${HERMES_ROOT}/profiles/curator}"
LLM_WIKI_HOST="${LLM_WIKI_DIR:-/opt/agl-llm-wiki}"

profile_dir() {
  local agent="$1"
  if [[ "${agent}" == "jarvis" ]]; then
    echo "${HERMES_ROOT}/data"
    return
  fi
  local p="${HERMES_ROOT}/profiles/${agent}"
  if [[ ! -d "${p}" ]] && [[ -d "${HERMES_ROOT}/data/profiles/${agent}" ]]; then
    p="${HERMES_ROOT}/data/profiles/${agent}"
  fi
  echo "${p}"
}

if [[ ! -f "${SKILL_SRC}/SKILL.md" ]]; then
  echo "ERRO: falta ${SKILL_SRC}/SKILL.md — instalar skill llm-wiki no jarvis primeiro" >&2
  exit 1
fi

TOKENS_FILE="${TELEGRAM_TOKENS_FILE:-/root/.aglz-telegram-tokens.env}"
ALLOWED_USERS="${TELEGRAM_ALLOWED_USERS:-1272190248}"
if [[ -f "${TOKENS_FILE}" ]]; then
  # shellcheck disable=SC1090
  source "${TOKENS_FILE}"
fi

sync_telegram_env() {
  local agent="$1"
  local pdir
  pdir="$(profile_dir "${agent}")"
  local var="TELEGRAM_TOKEN_${agent^^}"
  local token="${!var:-}"
  local env_file="${pdir}/.env"
  [[ -d "${pdir}" ]] || return 0
  if [[ -z "${token}" ]]; then
    grep -q '^TELEGRAM_BOT_TOKEN=' "${env_file}" 2>/dev/null && return 0
    echo "AVISO: ${var} ausente — ${agent} sem Telegram" >&2
    return 0
  fi
  touch "${env_file}"
  chown "${HERMES_UID}:${HERMES_GID}" "${env_file}"
  chmod 600 "${env_file}"
  if grep -q '^TELEGRAM_BOT_TOKEN=' "${env_file}" 2>/dev/null; then
    sed -i "s|^TELEGRAM_BOT_TOKEN=.*|TELEGRAM_BOT_TOKEN=${token}|" "${env_file}"
  else
    echo "TELEGRAM_BOT_TOKEN=${token}" >>"${env_file}"
  fi
  grep -q '^TELEGRAM_ALLOWED_USERS=' "${env_file}" 2>/dev/null || \
    echo "TELEGRAM_ALLOWED_USERS=${ALLOWED_USERS}" >>"${env_file}"
  grep -q '^API_SERVER_ENABLED=' "${env_file}" 2>/dev/null || \
    echo "API_SERVER_ENABLED=false" >>"${env_file}"
  echo "OK ${agent} TELEGRAM_BOT_TOKEN"
}

echo "=== llm-wiki second brain — ${#AGENTS[@]} agentes ==="

for agent in "${AGENTS[@]}"; do
  pdir="$(profile_dir "${agent}")"
  if [[ ! -d "${pdir}" ]]; then
    echo "AVISO: perfil ${agent} ausente (${pdir}) — saltar" >&2
    continue
  fi

  install -d -m 700 -o "${HERMES_UID}" -g "${HERMES_GID}" "${pdir}/skills/research"
  if [[ "${agent}" != "jarvis" ]]; then
    ln -sfn "${SKILL_SRC}" "${pdir}/skills/research/llm-wiki"
    chown -h "${HERMES_UID}:${HERMES_GID}" "${pdir}/skills/research/llm-wiki" 2>/dev/null || true
    echo "OK ${agent} skill symlink → llm-wiki"
  elif [[ -f "${pdir}/skills/research/llm-wiki/SKILL.md" ]] || [[ -L "${pdir}/skills/research/llm-wiki" ]]; then
    echo "OK jarvis skill llm-wiki (global)"
  else
    ln -sfn "${SKILL_SRC}" "${pdir}/skills/research/llm-wiki"
    chown -h "${HERMES_UID}:${HERMES_GID}" "${pdir}/skills/research/llm-wiki" 2>/dev/null || true
    echo "OK jarvis skill symlink → llm-wiki"
  fi

  if [[ -f "${SECOND_BRAIN_SRC}" ]]; then
    install -m 0640 -o "${HERMES_UID}" -g "${HERMES_GID}" \
      "${SECOND_BRAIN_SRC}" "${pdir}/SECOND-BRAIN.md"
  fi

  soul_src="${AGL_HOSTMAN}/docker/hermes/profiles/${agent}/SOUL.md"
  if [[ -f "${soul_src}" ]]; then
    install -m 0600 -o "${HERMES_UID}" -g "${HERMES_GID}" "${soul_src}" "${pdir}/SOUL.md"
  fi

  env_file="${pdir}/.env"
  touch "${env_file}"
  chown "${HERMES_UID}:${HERMES_GID}" "${env_file}"
  chmod 600 "${env_file}"
  if grep -q '^WIKI_PATH=' "${env_file}" 2>/dev/null; then
    sed -i "s|^WIKI_PATH=.*|WIKI_PATH=${WIKI_PATH}|" "${env_file}"
  else
    echo "WIKI_PATH=${WIKI_PATH}" >>"${env_file}"
  fi

  cfg="${pdir}/config.yaml"
  if [[ -f "${cfg}" ]]; then
    python3 - "${cfg}" <<'PY'
import sys
from pathlib import Path
import yaml

path = Path(sys.argv[1])
cfg = yaml.safe_load(path.read_text()) or {}
skills = cfg.setdefault("skills", {})
defaults = skills.setdefault("default", [])
if not isinstance(defaults, list):
    defaults = list(defaults) if defaults else []
    skills["default"] = defaults
if "llm-wiki" not in defaults:
    defaults.insert(0, "llm-wiki")
term = cfg.setdefault("terminal", {})
passthrough = term.setdefault("env_passthrough", [])
if not isinstance(passthrough, list):
    passthrough = []
    term["env_passthrough"] = passthrough
if "WIKI_PATH" not in passthrough:
    passthrough.append("WIKI_PATH")
if cfg.get("telegram") is None:
    cfg["telegram"] = {"channel_prompts": {}}
path.write_text(yaml.safe_dump(cfg, sort_keys=False, allow_unicode=True), encoding="utf-8")
print(f"OK config skills+WIKI_PATH: {path}")
PY
    chown "${HERMES_UID}:${HERMES_GID}" "${cfg}"
    chmod 600 "${cfg}"
    hermes_dir="${pdir}/.hermes"
    if [[ -d "${hermes_dir}" ]] || [[ -f "${pdir}/.hermes/config.yaml" ]]; then
      install -d -m 700 -o "${HERMES_UID}" -g "${HERMES_GID}" "${hermes_dir}"
      cp "${cfg}" "${hermes_dir}/config.yaml"
      chown "${HERMES_UID}:${HERMES_GID}" "${hermes_dir}/config.yaml"
      chmod 600 "${hermes_dir}/config.yaml"
    fi
  fi

  install -d -m 775 -o "${HERMES_UID}" -g "${HERMES_GID}" "${CURATOR_DATA}/wiki-ingest/${agent}"
  if [[ -d "${LLM_WIKI_HOST}/raw" ]]; then
    install -d -m 775 -o "${HERMES_UID}" -g "${HERMES_GID}" "${LLM_WIKI_HOST}/raw/hermes/${agent}"
  fi
done

for agent in "${AGENTS[@]}"; do
  sync_telegram_env "${agent}"
done

chown -R "${HERMES_UID}:${HERMES_GID}" "${HERMES_ROOT}/data/skills" 2>/dev/null || true

FIX_CURATOR="${AGL_HOSTMAN}/scripts/proxmox/fix-curator-llm-wiki-skill-ct188.sh"
if [[ -f "${FIX_CURATOR}" ]]; then
  echo "=== Curator cron prompt (maintenance) ==="
  bash "${FIX_CURATOR}" "${AGL_HOSTMAN}" || true
fi

WIKI_GIT="${AGL_HOSTMAN}/scripts/proxmox/setup-hermes-wiki-git-ct188.sh"
if [[ -f "${WIKI_GIT}" ]]; then
  echo "=== llm-wiki git (perfis Hermes) ==="
  bash "${WIKI_GIT}" --test || echo "AVISO: wiki git — correr setup-hermes-wiki-git-ct188.sh no CT188" >&2
fi

echo "OK second brain bidireccional — skill llm-wiki + WIKI_PATH em todos os perfis"
