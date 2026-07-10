#!/usr/bin/env bash
# Pré-check antes de arrancar agl-cursor-worker-pool (My Machines, Pro+).
# Worker mode exige CURSOR_API_KEY (User API Key); OAuth agent login não basta.
set -euo pipefail

ENV_FILE="/etc/cursor/worker-pool.env"
LABELS_FILE="/etc/cursor/worker-labels.json"
AGENT_BIN="/root/.local/bin/agent"
WORKER_DIR="${AGL_HOSTMAN_DIR:-/mnt/overpower/apps/dev/agl/agl-hostman}"

[[ -x "$AGENT_BIN" ]] || { echo "[FAIL] $AGENT_BIN em falta" >&2; exit 1; }
[[ -f "$LABELS_FILE" ]] || { echo "[FAIL] $LABELS_FILE em falta" >&2; exit 1; }
[[ -d "$WORKER_DIR/.git" ]] || { echo "[FAIL] $WORKER_DIR não é git repo" >&2; exit 1; }

CURSOR_API_KEY=""
[[ -f "$ENV_FILE" ]] && CURSOR_API_KEY="$(grep -m1 '^CURSOR_API_KEY=' "$ENV_FILE" | cut -d= -f2- | tr -d '\r' || true)"
if [[ -n "$CURSOR_API_KEY" ]] && [[ ${#CURSOR_API_KEY} -ge 20 ]]; then
  exit 0
fi

echo "[FAIL] User API Key em falta em $ENV_FILE (Dashboard → Cloud Agents → User API Keys)" >&2
exit 1
