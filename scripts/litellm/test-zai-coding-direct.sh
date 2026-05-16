#!/usr/bin/env bash
# Teste direto ao endpoint GLM Coding Plan (sem LiteLLM). Requer ZAI_API_KEY no ambiente.
# Documentação: https://docs.z.ai/api-reference/introduction
set -euo pipefail
KEY="${ZAI_API_KEY:-}"
if [ -z "$KEY" ]; then
  echo "Defina ZAI_API_KEY (chave da conta Z.AI / GLM Coding Plan)." >&2
  exit 2
fi
BASE="${ZAI_CODING_API_BASE:-https://api.z.ai/api/coding/paas/v4}"
curl -sS -X POST "${BASE%/}/chat/completions" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${KEY}" \
  -d '{"model":"glm-4.7","messages":[{"role":"user","content":"Reply exactly: ZAI_CODING_OK"}],"max_tokens":32}' \
  | head -c 2000
echo
