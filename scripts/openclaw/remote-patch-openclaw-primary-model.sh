#!/usr/bin/env bash
# Primário AGL: Z.AI glm-4.7-flash; fallbacks GLM-5 / DeepSeek / cloud (sem Cerebras/Groq).
set -euo pipefail
OC=/root/.openclaw/openclaw.json
cp -a "$OC" "$OC.bak.primary.$(date +%Y%m%d%H%M%S)"
tmp="$(mktemp)"
jq '.agents.defaults.model.primary = "zai/glm-4.7-flash"
  | .agents.defaults.model.fallbacks = [
      "zai/glm-5",
      "openrouter/deepseek/deepseek-chat",
      "anthropic/claude-sonnet-4-6",
      "moonshot/kimi-k2.5",
      "openai/gpt-5.3-instant",
      "google/gemini-3.1-pro-preview",
      "openrouter/deepseek/deepseek-v3.2",
      "openrouter/z-ai/glm-4.5-air:free"
    ]
  | if (.agents.list | type) == "array" then
    .agents.list |= map(
      if .id == "infra" then
        .model.primary = "zai/glm-4.7-flash"
        | .model.fallbacks = [
            "zai/glm-5",
            "openrouter/deepseek/deepseek-chat",
            "anthropic/claude-sonnet-4-6",
            "moonshot/kimi-k2.5"
          ]
      else . end
    )
  else . end' "$OC" > "$tmp"
mv "$tmp" "$OC"
chmod 600 "$OC"
echo "OK: primary=zai/glm-4.7-flash; fallbacks zai/glm-5 -> openrouter/deepseek-chat -> cloud"
