#!/usr/bin/env bash
# Satya (COO) — pipeline makemoney01: instala scripts, env, smoke e limpa erros de cron.
#
# Pré-requisitos: migração Manager (crons no perfil Satya), mount makemoney01, LiteLLM key em config.yaml.
#
# Uso (root no CT188):
#   bash setup-hermes-satya-makemoney-crons-ct188.sh
#   bash setup-hermes-satya-makemoney-crons-ct188.sh /mnt/overpower/apps/dev/agl/agl-hostman

set -euo pipefail

AGL_HOSTMAN="${1:-/mnt/overpower/apps/dev/agl/agl-hostman}"
HERMES_ROOT="${HERMES_ROOT:-/opt/agl-hermes}"
SATYA_DIR="${HERMES_ROOT}/profiles/satya"
SCRIPTS_DIR="${SATYA_DIR}/scripts"
JOBS="${SATYA_DIR}/cron/jobs.json"
SATYA_ENV="${SATYA_DIR}/.env"
JARVIS_CFG="${HERMES_ROOT}/data/config.yaml"
MON="${AGL_HOSTMAN}/scripts/monitoring"
MAKEMONEY_DIR="${MAKEMONEY_DIR:-/mnt/overpower/apps/dev/agl/makemoney01}"
HERMES_UID="${HERMES_UID:-10000}"
CONTAINER="${SATYA_CONTAINER:-agl-hermes-satya}"

test -d "${MON}" || { echo "ERRO: falta ${MON}" >&2; exit 1; }
test -f "${JARVIS_CFG}" || { echo "ERRO: falta ${JARVIS_CFG}" >&2; exit 1; }

install -d -m 755 -o "${HERMES_UID}" -g "${HERMES_UID}" "${SCRIPTS_DIR}"

install_script() {
  local src="${MON}/${1}"
  local dst="${SCRIPTS_DIR}/${1}"
  test -f "${src}" || { echo "ERRO: falta ${src}" >&2; exit 1; }
  sed 's/\r$//' "${src}" > "${dst}.tmp" && mv "${dst}.tmp" "${dst}"
  chmod 0755 "${dst}"
  chown "${HERMES_UID}:${HERMES_UID}" "${dst}"
  echo "OK script ${1}"
}

for s in \
  hermes-makemoney-sync-crons.sh \
  hermes-makemoney-deep-dive.sh \
  hermes-makemoney-wiki-feed.sh \
  hermes-makemoney-pipeline-report.sh \
  hermes-makemoney-git-sync.sh; do
  install_script "${s}"
done

GEN_SRC="${MAKEMONEY_DIR}/scripts/cron/generate-dossiers.sh"
GEN_DST="${SCRIPTS_DIR}/makemoney-generate-dossiers.sh"
if [[ -f "${GEN_SRC}" ]]; then
  sed 's/\r$//' "${GEN_SRC}" > "${GEN_DST}.tmp" && mv "${GEN_DST}.tmp" "${GEN_DST}"
  chmod 0755 "${GEN_DST}"
  chown "${HERMES_UID}:${HERMES_UID}" "${GEN_DST}"
  echo "OK script makemoney-generate-dossiers.sh (makemoney01)"
else
  echo "AVISO: falta ${GEN_SRC}" >&2
fi

# .env Satya: MAKEMONEY_DIR + ELON_CRON_OUTPUT (sync research do Elon)
touch "${SATYA_ENV}"
grep -q '^MAKEMONEY_DIR=' "${SATYA_ENV}" 2>/dev/null && \
  sed -i "s|^MAKEMONEY_DIR=.*|MAKEMONEY_DIR=${MAKEMONEY_DIR}|" "${SATYA_ENV}" || \
  echo "MAKEMONEY_DIR=${MAKEMONEY_DIR}" >> "${SATYA_ENV}"
grep -q '^ELON_CRON_OUTPUT=' "${SATYA_ENV}" 2>/dev/null || \
  echo "ELON_CRON_OUTPUT=/opt/elon-cron-output" >> "${SATYA_ENV}"
if grep -q '^MAKEMONEY_LLM_MODEL=' "${SATYA_ENV}" 2>/dev/null; then
  sed -i 's|^MAKEMONEY_LLM_MODEL=.*|MAKEMONEY_LLM_MODEL=agl-primary-zai-glm-flash|' "${SATYA_ENV}"
else
  echo "MAKEMONEY_LLM_MODEL=agl-primary-zai-glm-flash" >> "${SATYA_ENV}"
fi
chown "${HERMES_UID}:${HERMES_UID}" "${SATYA_ENV}"
chmod 600 "${SATYA_ENV}"
echo "OK ${SATYA_ENV}"

# Compose: mount Elon cron output no Satya (idempotente no deploy)
COMPOSE="${HERMES_ROOT}/docker-compose.aglz-quartet.yml"
if [[ -f "${COMPOSE}" ]] && ! grep -q 'elon-cron-output' "${COMPOSE}"; then
  echo "AVISO: adicionar mount elon-cron-output ao hermes-satya no compose e recriar contentor" >&2
fi

if docker ps --format '{{.Names}}' | grep -qx "${CONTAINER}"; then
  echo "=== Smoke (contentor ${CONTAINER}) ==="
  for s in hermes-makemoney-sync-crons.sh hermes-makemoney-wiki-feed.sh \
    hermes-makemoney-pipeline-report.sh hermes-makemoney-git-sync.sh; do
    if docker exec "${CONTAINER}" bash -lc "cd /opt/data && bash scripts/${s}" >/tmp/satya-smoke-$$.txt 2>&1; then
      echo "  OK ${s}"
    else
      echo "  FAIL ${s}: $(tail -1 /tmp/satya-smoke-$$.txt)"
    fi
  done
  rm -f /tmp/satya-smoke-$$.txt

  # generate-dossiers: 1 oportunidade (--id) para não bloquear smoke
  if docker exec "${CONTAINER}" bash -lc "cd /opt/data && timeout 120 bash scripts/makemoney-generate-dossiers.sh --id=2026-06-27-1" 2>&1 | tail -3; then
    echo "  OK makemoney-generate-dossiers.sh (amostra)"
  else
    echo "  AVISO: generate-dossiers amostra falhou ou timeout (verificar agl-primary-zai-glm-flash no LiteLLM)"
  fi

  echo "=== Recriar Satya com mount Elon (se compose actualizado) ==="
  if grep -q 'elon-cron-output' "${COMPOSE}" 2>/dev/null; then
    (cd "${HERMES_ROOT}" && docker compose -f docker-compose.aglz-quartet.yml up -d hermes-satya) || true
  fi
fi

# Limpar last_error stale nos jobs makemoney (scheduler mostra estado antigo pré-migração)
if [[ -f "${JOBS}" ]]; then
  python3 - "${JOBS}" <<'PY'
import json, sys
from pathlib import Path
p = Path(sys.argv[1])
data = json.loads(p.read_text())
for j in data.get("jobs", []):
    if "makemoney" in (j.get("name") or ""):
        j["last_error"] = None
        j["last_delivery_error"] = None
        # last_status mantém-se até próxima execução agendada
p.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
print(f"OK limpeza last_error em {p}")
PY
  chown "${HERMES_UID}:${HERMES_UID}" "${JOBS}"
fi

echo ""
echo "Satya makemoney pipeline: scripts em ${SCRIPTS_DIR}"
echo "Próximo: docker compose up -d hermes-satya (mount /opt/elon-cron-output)"
