#!/usr/bin/env bash
# Troca modelo primário: zai/glm-5 via LiteLLM usa quase só reasoning_tokens → OpenClaw fica com content [].
# Primário: glm-4.7-flash (texto visível, testado no proxy).
set -euo pipefail
OC=/root/.openclaw/openclaw.json
cp -a "$OC" "$OC.bak.primary.$(date +%Y%m%d%H%M%S)"
tmp="$(mktemp)"
jq '.agents.defaults.model.primary = "zai/glm-4.7-flash"
  | .agents.defaults.model.fallbacks = [
      "deepseek/deepseek-chat",
      "anthropic/claude-sonnet-4-6",
      "zai/glm-5",
      "moonshot/kimi-k2.5",
      "kimi/moonshot-v1-128k",
      "openai/gpt-5.3-instant",
      "google/gemini-3.1-pro-preview",
      "openrouter/deepseek/deepseek-v3.2",
      "openrouter/z-ai/glm-4.5-air:free",
      "google/gemini-2.5-flash-lite"
    ]
  | if (.agents.list | type) == "array" then
    .agents.list |= map(
      if .id == "infra" then
        .model.primary = "zai/glm-4.7-flash"
        | .model.fallbacks = [
            "deepseek/deepseek-chat",
            "openai/gpt-5.3-instant",
            "anthropic/claude-sonnet-4-6",
            "zai/glm-5"
          ]
      else . end
    )
  else . end' "$OC" > "$tmp"
mv "$tmp" "$OC"
chmod 600 "$OC"
echo "OK: primary=zai/glm-4.7-flash; glm-5 só após deepseek+claude"
