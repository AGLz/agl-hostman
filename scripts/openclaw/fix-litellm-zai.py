#!/usr/bin/env python3
"""
Fix ZAI model configuration in LiteLLM config.yaml.
Changes ZAI models from Anthropic format (slow, health check fails) to
OpenAI-compatible format (fast, health check works).

Before: api_base: https://api.z.ai/api/anthropic, model: anthropic/glm-X
After:  api_base: https://api.z.ai/api/openai/v1, model: openai/glm-X
"""
import re

CONFIG = "/opt/litellm/config.yaml"

with open(CONFIG) as f:
    content = f.read()

# Backup
with open(CONFIG + ".bak", "w") as f:
    f.write(content)
print("Backup created: config.yaml.bak")

# Replace all api.z.ai anthropic endpoints with openai endpoints
content = content.replace(
    'api_base: "https://api.z.ai/api/anthropic"',
    'api_base: "https://api.z.ai/api/openai/v1"'
)

# Replace anthropic/ model prefix with openai/ for ZAI models
# Only for lines that are under ZAI entries (model: "anthropic/glm-...")
content = re.sub(
    r'model: "anthropic/(glm-[^"]*)"',
    r'model: "openai/\1"',
    content
)

# Also fix api type from anthropic-messages to openai
# For ZAI entries that have api: "anthropic-messages" 
content = content.replace(
    'api: "anthropic-messages"',
    '# api: "anthropic-messages"  # removed - using openai format'
)

with open(CONFIG, "w") as f:
    f.write(content)

# Count changes
old_anthropic = content.count("api.z.ai/api/anthropic")
new_openai = content.count("api.z.ai/api/openai")
print(f"Remaining anthropic refs: {old_anthropic}")
print(f"New openai refs: {new_openai}")

# Verify
print("\nZAI model entries after fix:")
for line in content.split("\n"):
    if "api.z.ai" in line or ("model:" in line and "glm" in line.lower()):
        print(f"  {line.strip()}")
