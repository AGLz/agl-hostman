#!/usr/bin/env bash
# Pré-check antes de arrancar agl-cursor-worker-pool (My Machines, Pro+).
set -euo pipefail

ENV_FILE="/etc/cursor/worker-pool.env"
LABELS_FILE="/etc/cursor/worker-labels.json"
AGENT_BIN="/root/.local/bin/agent"
WORKER_DIR="${AGL_HOSTMAN_DIR:-/mnt/overpower/apps/dev/agl/agl-hostman}"

if [[ ! -x "$AGENT_BIN" ]]; then
  echo "[FAIL] $AGENT_BIN em falta — correr install-cursor-agent-cli.sh" >&2
  exit 1
fi

if [[ ! -f "$LABELS_FILE" ]]; then
  echo "[FAIL] $LABELS_FILE em falta — correr install-cursor-worker-pool.sh" >&2
  exit 1
fi

if [[ ! -d "$WORKER_DIR/.git" ]]; then
  echo "[FAIL] $WORKER_DIR não é um repositório git" >&2
  exit 1
fi

CURSOR_API_KEY=""
if [[ -f "$ENV_FILE" ]]; then
  CURSOR_API_KEY="$(grep -m1 '^CURSOR_API_KEY=' "$ENV_FILE" | cut -d= -f2- | tr -d '\r' || true)"
fi

if [[ -n "$CURSOR_API_KEY" ]] && [[ ${#CURSOR_API_KEY} -ge 20 ]]; then
  exit 0
fi

if [[ -f /root/.config/cursor/auth.json ]] && "$AGENT_BIN" status >/dev/null 2>&1; then
  exit 0
fi

echo "[FAIL] auth em falta — User API Key em $ENV_FILE ou 'agent login' como root" >&2
exit 1
