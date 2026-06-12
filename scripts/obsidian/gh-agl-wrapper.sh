#!/usr/bin/env bash
# gh com fallback SSH quando api.github.com está bloqueado na LAN AGL (CT181/AGLSRV1).
# Jump default: GCE free-tier (Tailscale 100.109.71.103) onde a API responde.
set -euo pipefail

GH_REAL="${GH_REAL:-/usr/bin/gh}"
GH_JUMP_HOST="${GH_JUMP_HOST:-root@100.109.71.103}"
GH_API_PROBE_URL="${GH_API_PROBE_URL:-https://api.github.com/zen}"
GH_API_PROBE_SECS="${GH_API_PROBE_SECS:-5}"

gh_api_reachable() {
  curl -fsSL --max-time "${GH_API_PROBE_SECS}" "${GH_API_PROBE_URL}" >/dev/null 2>&1
}

if gh_api_reachable; then
  exec "${GH_REAL}" "$@"
fi

exec ssh -o BatchMode=yes -o ConnectTimeout=25 "${GH_JUMP_HOST}" "${GH_REAL}" "$@"
