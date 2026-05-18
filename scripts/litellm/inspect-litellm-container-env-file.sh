#!/usr/bin/env bash
# Mostra como o contentor litellm-proxy foi arrancado (env_file vs Env).
set -euo pipefail
echo "=== litellm-proxy: tamanho das chaves (sem valores) ==="
for v in OPENAI_API_KEY GEMINI_API_KEY; do
  n="$(docker exec litellm-proxy printenv "$v" 2>/dev/null | wc -c || echo 0)"
  echo "$v bytes: $n"
done
echo ""
echo "=== Labels / compose project ==="
docker inspect litellm-proxy --format 'WorkingDir={{.Config.WorkingDir}}' 2>/dev/null || true
