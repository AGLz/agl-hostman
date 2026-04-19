#!/usr/bin/env bash
# =============================================================================
# Valida LiteLLM em todos os hosts (agldv03, agldv04, agldv12, fgsrv06)
# Uso: ./scripts/litellm/validate-all-hosts.sh
# Ref: docs/LITELLM-MULTI-HOST-DEPLOYMENT.md
# =============================================================================
set -euo pipefail

declare -A HOSTS
HOSTS[agldv03]="100.94.221.87"
HOSTS[agldv04]="100.113.9.98"
HOSTS[agldv12]="100.71.217.115"
HOSTS[fgsrv06]="100.83.51.9"

PASS=0
FAIL=0

echo "=== Validação LiteLLM em todos os hosts ==="
echo ""

for host in agldv03 agldv04 agldv12 fgsrv06; do
  ip="${HOSTS[$host]}"
  echo "--- $host ($ip) ---"

  # Health readiness (sem auth)
  if code=$(ssh -o ConnectTimeout=5 -o BatchMode=yes "root@${ip}" \
    "curl -s -o /dev/null -w '%{http_code}' http://localhost:4000/health/readiness" 2>/dev/null); then
    if [[ "$code" == "200" ]]; then
      echo "  /health/readiness: HTTP 200 ✅"
      ((PASS++)) || true
    else
      echo "  /health/readiness: HTTP $code ❌"
      ((FAIL++)) || true
    fi
  else
    echo "  /health/readiness: SSH/curl falhou ❌"
    ((FAIL++)) || true
  fi

  # Docker status
  dc=$(ssh -o ConnectTimeout=5 -o BatchMode=yes "root@${ip}" \
    "cd /opt/litellm 2>/dev/null && docker compose ps --format '{{.Status}}' 2>/dev/null | head -1" 2>/dev/null || echo "-")
  echo "  Docker: ${dc:-n/a}"
  echo ""
done

echo "=== Resumo: $PASS passaram, $FAIL falharam ==="
[[ $FAIL -eq 0 ]] && exit 0 || exit 1
