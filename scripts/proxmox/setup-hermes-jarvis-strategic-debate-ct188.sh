#!/usr/bin/env bash
# Jarvis — instala skill strategic-debate + scripts no perfil data/ (CT188).
#
# Uso (root no CT188):
#   bash setup-hermes-jarvis-strategic-debate-ct188.sh
#   bash setup-hermes-jarvis-strategic-debate-ct188.sh /mnt/overpower/apps/dev/agl/agl-hostman

set -euo pipefail

AGL_HOSTMAN="${1:-/mnt/overpower/apps/dev/agl/agl-hostman}"
HERMES_ROOT="${HERMES_ROOT:-/opt/agl-hermes}"
JARVIS_DATA="${HERMES_ROOT}/data"
SCRIPTS_DIR="${JARVIS_DATA}/scripts"
SKILL_DST="${JARVIS_DATA}/skills/strategic-debate"
HERMES_UID="${HERMES_UID:-10000}"
SRC_PY="${AGL_HOSTMAN}/scripts/hermes/strategic_debate.py"
SRC_SH="${AGL_HOSTMAN}/scripts/hermes/strategic-debate.sh"
SKILL_SRC="${AGL_HOSTMAN}/docker/hermes/profiles/jarvis/skills/strategic-debate/SKILL.md"
DEBATE_RAW="${LLM_WIKI_DIR:-/opt/agl-llm-wiki}/raw/hermes/jarvis"

test -f "${SRC_PY}" || { echo "ERRO: falta ${SRC_PY}" >&2; exit 1; }
test -f "${SKILL_SRC}" || { echo "ERRO: falta ${SKILL_SRC}" >&2; exit 1; }

install -d -m 755 -o "${HERMES_UID}" -g "${HERMES_UID}" "${SCRIPTS_DIR}"
install -d -m 755 -o "${HERMES_UID}" -g "${HERMES_UID}" "${SKILL_DST}"
install -d -m 775 -o "${HERMES_UID}" -g "${HERMES_UID}" "${DEBATE_RAW}"

install_script() {
  local src="$1" dst="$2"
  sed 's/\r$//' "${src}" > "${dst}.tmp" && mv "${dst}.tmp" "${dst}"
  chmod 0755 "${dst}"
  chown "${HERMES_UID}:${HERMES_UID}" "${dst}"
}

install_script "${SRC_PY}" "${SCRIPTS_DIR}/strategic_debate.py"
install_script "${SRC_SH}" "${SCRIPTS_DIR}/strategic-debate.sh"
install -m 0644 -o "${HERMES_UID}" -g "${HERMES_UID}" "${SKILL_SRC}" "${SKILL_DST}/SKILL.md"

# SOUL Jarvis (repo canónico)
SOUL_SRC="${AGL_HOSTMAN}/docker/hermes/profiles/jarvis/SOUL.md"
if [[ -f "${SOUL_SRC}" ]]; then
  install -m 0600 -o "${HERMES_UID}" -g "${HERMES_UID}" "${SOUL_SRC}" "${JARVIS_DATA}/SOUL.md"
fi

echo "OK scripts → ${SCRIPTS_DIR}/strategic-debate.sh"
echo "OK skill → ${SKILL_DST}/SKILL.md"
echo "OK debate output dir → ${DEBATE_RAW}"

if docker ps --format '{{.Names}}' | grep -qx agl-hermes-jarvis; then
  echo "=== Smoke dry-run (contentor Jarvis) ==="
  if docker exec agl-hermes-jarvis bash -lc \
    "bash /opt/data/scripts/strategic-debate.sh --dry-run -q 'Smoke debate' -c 'teste'" \
    | grep -q 'DRY-RUN'; then
    echo "  OK strategic-debate --dry-run"
  else
    echo "  AVISO: dry-run sem output esperado" >&2
  fi
fi

echo ""
echo "Jarvis: usar skill strategic-debate na fase Plan antes de delegar decisões estratégicas."
