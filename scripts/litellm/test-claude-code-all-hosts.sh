#!/usr/bin/env bash
# =============================================================================
# Testa fluxo Claude Code em todos os hosts (chat completion via LiteLLM local)
# Simula: ANTHROPIC_BASE_URL=localhost:4000 + ANTHROPIC_AUTH_TOKEN
# Uso: ./scripts/litellm/test-claude-code-all-hosts.sh
#      ./scripts/litellm/test-claude-code-all-hosts.sh --benchmark  # multi-model + latência
# =============================================================================
set -euo pipefail

[[ "${1:-}" == "--benchmark" ]] && exec "$(dirname "$0")/benchmark-models-all-hosts.sh"
[[ "${1:-}" == "--consolidate" ]] && exec "$(dirname "$0")/benchmark-consolidate.sh" "${@:2}"

declare -A HOSTS
HOSTS[agldv03]="100.94.221.87"
HOSTS[agldv04]="100.113.9.98"
HOSTS[agldv12]="100.71.217.115"
HOSTS[fgsrv06]="100.83.51.9"

PASS=0
FAIL=0

echo "=== Teste Claude Code (chat completion) em todos os hosts ==="
echo ""

for host in agldv03 agldv04 agldv12 fgsrv06; do
  ip="${HOSTS[$host]}"
  echo "--- $host ($ip) ---"

  # Lê LITELLM_MASTER_KEY de /opt/litellm/.env no host e faz POST /chat/completions
  result=$(ssh -o ConnectTimeout=5 -o BatchMode=yes "root@${ip}" \
    'KEY=$(grep "^LITELLM_MASTER_KEY=" /opt/litellm/.env 2>/dev/null | cut -d= -f2-); KEY="${KEY:-sk-litellm-default}"; curl -s --max-time 60 -w "\n%{http_code}" -X POST http://localhost:4000/chat/completions -H "Content-Type: application/json" -H "Authorization: Bearer $KEY" -d "{\"model\":\"glm\",\"messages\":[{\"role\":\"user\",\"content\":\"Responda apenas: OK\"}],\"max_tokens\":10}" 2>/dev/null' 2>/dev/null) || result="ERR"

  if [[ "$result" == "ERR" ]]; then
    echo "  Claude Code test: SSH/curl falhou ❌"
    ((FAIL++)) || true
  else
    code=$(echo "$result" | tail -1)
    body=$(echo "$result" | sed '$d')
    if [[ "$code" == "200" ]]; then
      if echo "$body" | grep -q '"content"'; then
        echo "  Claude Code test: HTTP 200, resposta OK ✅"
        ((PASS++)) || true
      else
        echo "  Claude Code test: HTTP 200 mas sem content ❌"
        ((FAIL++)) || true
      fi
    elif [[ "$code" == "401" ]]; then
      echo "  Claude Code test: HTTP 401 (auth inválida) ❌"
      ((FAIL++)) || true
    else
      echo "  Claude Code test: HTTP $code ❌"
      ((FAIL++)) || true
    fi
  fi
  echo ""
done

echo "=== Resumo: $PASS passaram, $FAIL falharam ==="
[[ $FAIL -eq 0 ]] && exit 0 || exit 1
