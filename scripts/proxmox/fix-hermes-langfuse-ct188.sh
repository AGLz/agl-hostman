#!/usr/bin/env bash
# Corrige spam OTLP 401: desactiva plugin Langfuse se keys inválidas.
# Para reactivar com keys válidas: bash apply-langfuse-hermes-env.sh
#
# Uso (root no CT188):
#   bash fix-hermes-langfuse-ct188.sh
#   bash fix-hermes-langfuse-ct188.sh --enable   # só se /root/.aglz-langfuse.env estiver OK

set -euo pipefail

MODE="${1:-disable}"
HERMES_ROOT="${HERMES_ROOT:-/opt/agl-hermes}"
KEYS_FILE="/root/.aglz-langfuse.env"

profile_cfg() {
  local agent="$1"
  if [[ "${agent}" == "jarvis" ]]; then
    echo "${HERMES_ROOT}/data/config.yaml"
  else
    echo "${HERMES_ROOT}/profiles/${agent}/config.yaml"
  fi
}

profile_dir() {
  local agent="$1"
  if [[ "${agent}" == "jarvis" ]]; then
    echo "${HERMES_ROOT}/data"
  else
    echo "${HERMES_ROOT}/profiles/${agent}"
  fi
}

if [[ "${MODE}" == "--enable" ]]; then
  test -f "${KEYS_FILE}" || { echo "ERRO: ${KEYS_FILE} inexistente" >&2; exit 1; }
  AGL_HOSTMAN="${AGL_HOSTMAN:-/mnt/overpower/apps/dev/agl/agl-hostman}"
  bash "${AGL_HOSTMAN}/scripts/proxmox/apply-langfuse-hermes-env.sh"
  exit 0
fi

echo "=== Desactivar plugin observability/langfuse (OTLP 401) ==="
for agent in jarvis elon satya werner; do
  pdir="$(profile_dir "${agent}")"
  envf="${pdir}/.env"
  cfg="$(profile_cfg "${agent}")"
  [[ -d "${pdir}" ]] || continue

  for var in OTEL_SDK_DISABLED OTEL_TRACES_EXPORTER OTEL_METRICS_EXPORTER OTEL_LOGS_EXPORTER; do
    if [[ -f "${envf}" ]]; then
      grep -q "^${var}=" "${envf}" 2>/dev/null && sed -i "s|^${var}=.*|${var}=none|" "${envf}" || true
    fi
  done
  if [[ -f "${envf}" ]] && ! grep -q '^OTEL_SDK_DISABLED=' "${envf}"; then
    echo 'OTEL_SDK_DISABLED=true' >>"${envf}"
  fi

  [[ -f "${cfg}" ]] || continue
  python3 - "${cfg}" <<'PY'
import sys
from pathlib import Path
import yaml

path = Path(sys.argv[1])
cfg = yaml.safe_load(path.read_text()) or {}
plugins = cfg.setdefault("plugins", {})
enabled = plugins.setdefault("enabled", [])
if isinstance(enabled, list):
    needle = "observability/langfuse"
    if needle in enabled:
        enabled.remove(needle)
        Path(path).write_text(yaml.dump(cfg, default_flow_style=False, allow_unicode=True))
        print("OK disabled", path)
    else:
        print("OK já disabled", path)
PY
  chown 10000:10000 "${cfg}" 2>/dev/null || true
done

cd "${HERMES_ROOT}"
docker compose -f docker-compose.aglz-quartet.yml restart jarvis elon satya werner 2>/dev/null \
  || docker compose -f docker-compose.aglz-quartet.yml restart

echo "Langfuse desactivado nos gateways. UI Langfuse continua no host se necessário."
