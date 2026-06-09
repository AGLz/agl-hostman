#!/usr/bin/env bash
# Repara venv Hermes no contentor agl-hermes-jarvis (CT188) quando dashboard/CLI falham.
#
# Sintomas:
#   - Web UI :9119 → connection reset / empty reply
#   - logs: hermes-shim: /opt/hermes/.venv/bin/hermes not found
#   - hermes dashboard: No module named 'fastapi'
#
# Causa típica: venv corrompido (binários/scripts removidos, deps web em falta).
#
# Uso (root no CT188):
#   bash repair-hermes-jarvis-venv-ct188.sh

set -euo pipefail

CONTAINER="${HERMES_JARVIS_CONTAINER:-agl-hermes-jarvis}"

if ! docker ps --format '{{.Names}}' | grep -qx "${CONTAINER}"; then
  echo "ERRO: contentor ${CONTAINER} não está a correr" >&2
  exit 1
fi

echo "=== Reparar venv Hermes em ${CONTAINER} ==="
docker exec -u root "${CONTAINER}" bash -lc '
set -euo pipefail
cd /opt/hermes
uv sync --frozen --no-install-project --extra all --extra messaging --extra voice --extra edge-tts
uv pip install -e .
# Plugin observability/langfuse (removido por conflito de lock em alguns uv sync)
uv pip install 'langfuse>=4.7,<5' 2>/dev/null || uv pip install langfuse

if [[ ! -x /opt/hermes/.venv/bin/dashboard ]]; then
  cat > /opt/hermes/.venv/bin/dashboard <<'"'"'EOF'"'"'
#!/bin/sh
exec /opt/hermes/.venv/bin/hermes dashboard "$@"
EOF
  chmod +x /opt/hermes/.venv/bin/dashboard
fi

chown -R hermes:hermes /opt/hermes/.venv
/opt/hermes/.venv/bin/python3 -c "import fastapi, uvicorn; import hermes_cli"
/opt/hermes/.venv/bin/hermes --version
echo "OK venv reparado"
'

echo "=== Reiniciar ${CONTAINER} ==="
docker restart "${CONTAINER}"

echo "A aguardar readiness..."
for _ in $(seq 1 60); do
  code="$(curl -sS -o /dev/null -w '%{http_code}' --max-time 3 http://127.0.0.1:9119/ 2>/dev/null || echo 000)"
  if [[ "${code}" == "200" ]]; then
    echo "OK Web UI http://127.0.0.1:9119 → HTTP ${code}"
    exit 0
  fi
  sleep 2
done

echo "AVISO: Web UI ainda não responde HTTP 200 — ver docker logs ${CONTAINER}" >&2
exit 1
