#!/usr/bin/env bash
# EvoNexus (compose Hub): uma única SQLite — /workspace/dashboard/data/evonexus.db
# Motivo: o app.py upstream usa dashboard.db na raiz do workspace (users vazios);
#   integrações e health usavam dashboard/data/dashboard.db; agentes em workspace/finance
#   apontavam para /workspace/dashboard.db. Tudo deve coincidir com evonexus.db.
#
# Onde correr: CT242 (evonexus) em /opt/evonexus, como root, com Docker acessível.
# Idempotente: reexecutar só recria mounts se ficheiros já existirem.

set -euo pipefail
COMPOSE_DIR="${EVONEXUS_COMPOSE_DIR:-/opt/evonexus}"
COMPOSE_FILE="${EVONEXUS_COMPOSE_FILE:-docker-compose.hub.yml}"
DASH="${EVONEXUS_DASHBOARD_CONTAINER:-evonexus-dashboard}"

cd "$COMPOSE_DIR"

need_copy_patch() {
  local src_in_container="$1"
  local host_file="$2"
  docker cp "${DASH}:${src_in_container}" "$host_file"
  # Unifica caminho data/dashboard.db → data/evonexus.db (string exact do upstream)
  sed -i 's|"dashboard" / "data" / "dashboard.db"|"dashboard" / "data" / "evonexus.db"|g' "$host_file"
}

if ! docker ps --format '{{.Names}}' | grep -qx "$DASH"; then
  echo "Container ${DASH} não está a correr; faça docker compose up -d primeiro." >&2
  exit 1
fi

# 1) app.py — SQLAlCHEMY na raiz dashboard.db → dashboard/data/evonexus.db
if [[ ! -f dashboard_backend_app.py ]]; then
  docker cp "${DASH}:/workspace/dashboard/backend/app.py" dashboard_backend_app.py
fi
sed -i "s|WORKSPACE / 'dashboard.db'|WORKSPACE / 'dashboard' / 'data' / 'evonexus.db'|g" dashboard_backend_app.py

# 2) plugin health + rotas integrações
need_copy_patch /workspace/dashboard/backend/plugin_integration_health.py dashboard_backend_plugin_integration_health.py
need_copy_patch /workspace/dashboard/backend/routes/integrations.py dashboard_backend_routes_integrations.py

# 3) Garantir mounts no compose (após services.routes.py; remove duplicados)
export COMPOSE_DIR COMPOSE_FILE
python3 <<'PY'
import os
from pathlib import Path

compose = Path(os.environ["COMPOSE_DIR"]) / os.environ.get("COMPOSE_FILE", "docker-compose.hub.yml")
text = compose.read_text()
need = [
    "      - ./dashboard_backend_app.py:/workspace/dashboard/backend/app.py:ro",
    "      - ./dashboard_backend_plugin_integration_health.py:/workspace/dashboard/backend/plugin_integration_health.py:ro",
    "      - ./dashboard_backend_routes_integrations.py:/workspace/dashboard/backend/routes/integrations.py:ro",
]
if all(n in text for n in need):
    raise SystemExit(0)
markers = (
    "./dashboard_backend_app.py:",
    "./dashboard_backend_plugin_integration_health.py:",
    "./dashboard_backend_routes_integrations.py:",
)
lines = [ln for ln in text.splitlines() if not any(m in ln for m in markers)]
out = []
inserted = False
for line in lines:
    out.append(line)
    if not inserted and "services.routes.py:/workspace/dashboard/backend/routes/services.py" in line:
        out.extend(need)
        inserted = True
if not inserted:
    raise SystemExit("services.routes.py mount não encontrado no compose")
compose.write_text("\n".join(out) + "\n")
PY

# 4) Workspace partilhado (agentes) — finance scripts
docker exec "$DASH" sh -c '
  for f in /workspace/workspace/finance/mrr_integration_collector.py /workspace/workspace/finance/validate_setup.py; do
    if [ -f "$f" ]; then
      sed -i "s|/workspace/dashboard.db|/workspace/dashboard/data/evonexus.db|g" "$f"
    fi
  done
'

docker compose -f "$COMPOSE_FILE" up -d --force-recreate

echo "OK. Verificação rápida (não deve haver dashboard.db em paths de dados):"
docker exec "$DASH" sh -c 'grep -rE "dashboard/data/dashboard\\.db|/workspace/dashboard\\.db" /workspace --include="*.py" 2>/dev/null | grep -v plugin_scan_runner || true'
