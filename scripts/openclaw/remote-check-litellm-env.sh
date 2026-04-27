#!/usr/bin/env bash
set -euo pipefail
for v in OPENAI_API_KEY ANTHROPIC_API_KEY GEMINI_API_KEY DEEPSEEK_API_KEY MOONSHOT_API_KEY ZAI_API_KEY; do
  n="$(docker exec litellm-proxy printenv "$v" 2>/dev/null | wc -c || true)"
  echo "$v bytes in container: $n"
done
