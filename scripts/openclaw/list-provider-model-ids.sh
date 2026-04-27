#!/usr/bin/env bash
MP=/root/.openclaw/agents/main/agent/models.json
for p in zai anthropic deepseek openai google moonshot kimi openrouter qwen; do
  echo "== $p =="
  jq -r ".providers[\"$p\"].models[]?.id // empty" "$MP" 2>/dev/null || true
done
