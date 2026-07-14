#!/usr/bin/env bash
# Smoke Harbor CT182 — falha se /v2/ inacessível.
# Uso: bash scripts/proxmox/harbor-health-ct182.sh
set -euo pipefail

URL="${HARBOR_URL:-https://harbor.aglz.io/v2/}"
code="$(curl -sk -o /dev/null -w '%{http_code}' --connect-timeout 5 --max-time 15 "${URL}" || true)"
# 401 = registry vivo sem auth; 200 também OK
if [[ "${code}" != "401" && "${code}" != "200" ]]; then
  echo "FAIL: Harbor ${URL} → HTTP ${code:-unreachable}" >&2
  exit 1
fi
echo "OK: Harbor ${URL} → HTTP ${code}"
