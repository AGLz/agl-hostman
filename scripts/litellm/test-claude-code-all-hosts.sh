#!/usr/bin/env bash
# =============================================================================
# Testa fluxo Claude Code em todos os hosts (chat completion via LiteLLM local)
# Simula: ANTHROPIC_BASE_URL=localhost:4000 + ANTHROPIC_AUTH_TOKEN
# Uso: ./scripts/litellm/test-claude-code-all-hosts.sh
#      ./scripts/litellm/test-claude-code-all-hosts.sh --benchmark  # multi-model + latência
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_litellm-sync-common.sh
source "${SCRIPT_DIR}/_litellm-sync-common.sh"

[[ "${1:-}" == "--benchmark" ]] && exec "${SCRIPT_DIR}/benchmark-models-all-hosts.sh"
[[ "${1:-}" == "--consolidate" ]] && exec "${SCRIPT_DIR}/benchmark-consolidate.sh" "${@:2}"

PASS=0
FAIL=0

echo "=== Teste Claude Code (chat completion) em todos os hosts ==="
echo ""

for host in ct186 agldv04 agldv12 fgsrv06; do
  ip="${LITELLM_HOST_IPS[$host]}"
  env_dir="$(litellm_remote_dir "$host")"
  echo "--- $host ($ip) ---"

  result=$(ssh -o ConnectTimeout=5 -o BatchMode=yes "root@${ip}" \
    "KEY=\$(grep '^LITELLM_MASTER_KEY=' ${env_dir}/.env 2>/dev/null | cut -d= -f2-); KEY=\"\${KEY:-sk-litellm-default}\"; curl -s --max-time 60 -w '\n%{http_code}' -X POST http://localhost:4000/chat/completions -H 'Content-Type: application/json' -H \"Authorization: Bearer \$KEY\" -d '{\"model\":\"glm\",\"messages\":[{\"role\":\"user\",\"content\":\"Responda apenas: OK\"}],\"max_tokens\":10}' 2>/dev/null" 2>/dev/null) || result="ERR"

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
