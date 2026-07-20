#!/usr/bin/env bash
# Activa agl-cursor-worker-pool após configurar User API Key.
# Uso: CURSOR_API_KEY='key_...' sudo bash scripts/cursor/enable-cursor-worker.sh
set -euo pipefail

REPO="${AGL_HOSTMAN_DIR:-$(cd "$(dirname "$0")/../.." && pwd)}"
[[ "$(id -u)" -eq 0 ]] || { echo "[FAIL] correr com sudo" >&2; exit 1; }

[[ -n "${CURSOR_API_KEY:-}" ]] && bash "$REPO/scripts/cursor/sync-cursor-worker-pool-env.sh"
bash "$REPO/scripts/cursor/ensure-cursor-worker-pool-ready.sh"
systemctl enable agl-cursor-worker-pool.service
systemctl restart agl-cursor-worker-pool.service
systemctl status agl-cursor-worker-pool.service --no-pager
curl -sf http://127.0.0.1:18080/healthz && echo " OK healthz" || echo "[WARN] healthz ainda não responde"
