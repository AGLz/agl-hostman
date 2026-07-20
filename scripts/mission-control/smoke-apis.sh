#!/usr/bin/env bash
# Reason: smoke Fase 0/1 Mission Control — endpoints auth + snapshot AGLSRV1
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BASE_URL="${MISSION_CONTROL_SMOKE_URL:-http://127.0.0.1:8000}"
TOKEN="${MISSION_CONTROL_SMOKE_TOKEN:-}"

echo "== Mission Control smoke =="
echo "base: $BASE_URL"

unauth_code="$(curl -s -o /dev/null -w '%{http_code}' "$BASE_URL/api/mission-control/hosts/aglsrv1/snapshot" || true)"
if [[ "$unauth_code" != "401" && "$unauth_code" != "302" ]]; then
  echo "WARN: esperado 401/302 sem auth, got $unauth_code"
else
  echo "OK: unauth snapshot → $unauth_code"
fi

if [[ -z "$TOKEN" ]]; then
  echo "SKIP: defina MISSION_CONTROL_SMOKE_TOKEN para testar snapshot autenticado"
  echo "Pest: cd src && php artisan test --filter=MissionControlApiTest"
  exit 0
fi

tmp="$(mktemp)"
code="$(curl -sS -o "$tmp" -w '%{http_code}' \
  -H "Authorization: Bearer $TOKEN" \
  -H "Accept: application/json" \
  "$BASE_URL/api/mission-control/hosts/aglsrv1/snapshot")"

if [[ "$code" != "200" ]]; then
  echo "FAIL: snapshot HTTP $code"
  cat "$tmp"
  rm -f "$tmp"
  exit 1
fi

python3 - "$tmp" <<'PY'
import json, sys
path = sys.argv[1]
data = json.load(open(path))
guests = data.get("summary", {}).get("guests_total", 0)
services = data.get("summary", {}).get("services_total", 0)
alerts = data.get("summary", {}).get("alerts_total", 0)
print(f"OK: guests={guests} services={services} alerts={alerts} semaphore={data.get('summary', {}).get('semaphore')}")
if guests < 20:
    raise SystemExit(f"FAIL: guests_total {guests} < 20")
if services < 10:
    raise SystemExit(f"FAIL: services_total {services} < 10")
PY

rm -f "$tmp"
echo "DONE"
