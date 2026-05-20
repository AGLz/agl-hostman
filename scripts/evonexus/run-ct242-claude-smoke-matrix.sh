#!/usr/bin/env bash
# Orquestra smoke Claude no EvoNexus (CT242): copia script para o contentor e corre matriz modelo×agente.
# Executar num host com `pct` (ex.: fgsrv7) e com o CT242 a correr Docker EvoNexus.
#
# Uso (a partir da raiz do agl-hostman):
#   bash scripts/evonexus/run-ct242-claude-smoke-matrix.sh
#
# Variáveis opcionais (override):
#   CT_ID=242 DASHBOARD_CT=evonexus-dashboard
#   EVONEXUS_SMOKE_MODELS="glm-4.7-flash,gpt-5.5"   # omissão = glm-4.7-flash (default EvoNexus)
#   EVONEXUS_SMOKE_AGENTS="jarvis,atlas-project,hawk-debugger"
#   EVONEXUS_SMOKE_PROMPT="informe sobre o avanço dos projetos"

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
CT_ID="${CT_ID:-242}"
CONTAINER="${DASHBOARD_CT:-evonexus-dashboard}"
SCRIPT_SRC="${ROOT}/scripts/evonexus/claude-agents-smoke.py"
SCRIPT_CT="/root/claude-agents-smoke.py"
SCRIPT_DOCKER="/tmp/claude-agents-smoke.py"

: "${EVONEXUS_SMOKE_MODELS:=glm-4.7-flash}"
: "${EVONEXUS_SMOKE_AGENTS:=jarvis,atlas-project,hawk-debugger}"
: "${EVONEXUS_SMOKE_PROMPT:=informe sobre o avanço dos projetos}"

if ! command -v pct >/dev/null 2>&1; then
  echo "pct não encontrado — correr este script no Proxmox host (ex.: fgsrv7)." >&2
  exit 1
fi

if [[ ! -f "$SCRIPT_SRC" ]]; then
  echo "Falta $SCRIPT_SRC" >&2
  exit 1
fi

echo ">>> pct push $CT_ID claude-agents-smoke.py → $SCRIPT_CT"
pct push "$CT_ID" "$SCRIPT_SRC" "$SCRIPT_CT"

echo ">>> docker cp para $CONTAINER:$SCRIPT_DOCKER"
pct exec "$CT_ID" -- docker cp "$SCRIPT_CT" "${CONTAINER}:${SCRIPT_DOCKER}"

echo ">>> docker exec matriz (modelos: $EVONEXUS_SMOKE_MODELS)"
pct exec "$CT_ID" -- docker exec -w /workspace \
  -e EVONEXUS_SMOKE_MODELS="$EVONEXUS_SMOKE_MODELS" \
  -e EVONEXUS_SMOKE_AGENTS="$EVONEXUS_SMOKE_AGENTS" \
  -e EVONEXUS_SMOKE_PROMPT="$EVONEXUS_SMOKE_PROMPT" \
  "$CONTAINER" python3 "$SCRIPT_DOCKER"

echo ">>> feito."
