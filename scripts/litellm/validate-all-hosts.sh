#!/usr/bin/env bash
# =============================================================================
# Valida LiteLLM em CT186 (canónico) + agldv04, agldv12, fgsrv06
# Uso: ./scripts/litellm/validate-all-hosts.sh
# Ref: docs/LITELLM-MULTI-HOST-DEPLOYMENT.md
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_litellm-sync-common.sh
source "${SCRIPT_DIR}/_litellm-sync-common.sh"

PASS=0
FAIL=0

echo "=== Validação LiteLLM em todos os hosts ==="
echo ""

for host in ct186 agldv04 agldv12 fgsrv06; do
  ip="${LITELLM_HOST_IPS[$host]}"
  remote_dir="$(litellm_remote_dir "$host")"
  echo "--- $host ($ip) — ${remote_dir} ---"

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

  dc=$(ssh -o ConnectTimeout=5 -o BatchMode=yes "root@${ip}" \
    "cd ${remote_dir} 2>/dev/null && docker compose ps --format '{{.Status}}' 2>/dev/null | head -1" 2>/dev/null || echo "-")
  echo "  Docker: ${dc:-n/a}"
  echo ""
done

echo "=== Resumo: $PASS passaram, $FAIL falharam ==="
[[ $FAIL -eq 0 ]]
