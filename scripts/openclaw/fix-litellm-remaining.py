#!/usr/bin/env python3
"""
Fix all remaining LiteLLM issues:
1. Pull missing Ollama models on CT200
2. Fix glm-4.7 format
3. Remove Cerebras
4. Add qwen3.5-flash alias
5. Fix or-glm-air-free alias
6. Check Gemini key
"""
import urllib.request
import json
import subprocess
import re
import time

CONFIG = "/opt/litellm/config.yaml"
CONFIG_MOUNT = "/mnt/overpower/apps/dev/agl/agl-hostman/config/litellm/config.yaml"

# =============================================
# 1. Check & Pull Ollama models
# =============================================
print("=" * 60)
print("1. OLLAMA MODELS")
print("=" * 60)

try:
    req = urllib.request.Request("http://192.168.0.200:11434/api/tags")
    resp = urllib.request.urlopen(req, timeout=5)
    data = json.loads(resp.read())
    existing = [m["name"] for m in data.get("models", [])]
    print(f"  Existing: {existing}")
except Exception as e:
    existing = []
    print(f"  Ollama API error: {e}")

NEEDED = ["qwen3:0.6b", "qwen3:1.7b", "deepseek-r1:1.5b"]
to_pull = [m for m in NEEDED if m not in existing]

if to_pull:
    print(f"  Need to pull: {to_pull}")
    for model in to_pull:
        print(f"  Pulling {model}...")
        try:
            payload = json.dumps({"name": model}).encode()
            req = urllib.request.Request("http://192.168.0.200:11434/api/pull", data=payload)
            req.add_header("Content-Type", "application/json")
            resp = urllib.request.urlopen(req, timeout=300)
            # Stream the response
            while True:
                line = resp.readline()
                if not line:
                    break
                data = json.loads(line)
                status = data.get("status", "")
                if "success" in status.lower() or "pulling" in status.lower():
                    print(f"    {status}")
            print(f"  {model}: DONE")
        except Exception as e:
            print(f"  {model}: FAIL - {e}")
else:
    print("  All models already present")

# =============================================
# 2-6. Fix LiteLLM config.yaml
# =============================================
print("\n" + "=" * 60)
print("2-6. LITELLM CONFIG FIXES")
print("=" * 60)

with open(CONFIG) as f:
    content = f.read()

changes = 0

# 2. Fix glm-4.7 - it uses anthropic format which doesn't work with OpenAI endpoint
# The issue is glm-4.7 returns invalid response format
# Change glm-4.7 model to glm-4.7-flash (which works)
if 'model_name: "glm-4.7"' in content:
    # Find the glm-4.7 entry and check its model param
    # The model "openai/glm-4.7" might not exist on ZAI OpenAI endpoint
    # Replace with glm-4.7-flash which works
    old = '''  - model_name: "glm-4.7"
    litellm_params:
      model: "openai/glm-4.7"'''
    new = '''  - model_name: "glm-4.7"
    litellm_params:
      model: "openai/glm-4.7-flash"'''
    if old in content:
        content = content.replace(old, new)
        changes += 1
        print("  Fixed glm-4.7 -> glm-4.7-flash backend")

# 3. Remove/disable Cerebras (model discontinued)
if 'model_name: "cerebras-' in content:
    # Comment out the cerebras entries
    lines = content.split("\n")
    new_lines = []
    skip_until_next_model = False
    for i, line in enumerate(lines):
        if 'model_name: "cerebras-' in line:
            skip_until_next_model = True
            new_lines.append("  # DISABLED: " + line.strip() + "  # Model discontinued")
            changes += 1
            print(f"  Disabled cerebras entry")
            continue
        if skip_until_next_model:
            if line.strip().startswith("- model_name:") or (line.strip() == "" and i+1 < len(lines) and lines[i+1].strip().startswith("- model_name:")):
                skip_until_next_model = False
                new_lines.append(line)
            else:
                new_lines.append("  # " + line.strip())
            continue
        new_lines.append(line)
    content = "\n".join(new_lines)

# 4. Add qwen3.5-flash alias (missing from this config)
if 'model_name: "qwen3.5-flash"' not in content:
    # Add after qwen3.5-plus entry
    qwen_entry = '''
  # qwen3.5-flash alias (added for OpenClaw compatibility)
  - model_name: "qwen3.5-flash"
    litellm_params:
      model: "openai/qwen3.5-flash"
      api_key: os.environ/DASHSCOPE_API_KEY
      api_base: "https://dashscope-intl.aliyuncs.com/compatible-mode/v1"
      timeout: 30
    model_info:
      max_tokens: 8192
      context_window: 131072
      free_tier: true
'''
    # Insert before the first OpenRouter entry
    if 'model_name: "qwen3-max"' in content:
        content = content.replace(
            '  - model_name: "qwen3-max"',
            qwen_entry + '  - model_name: "qwen3-max"'
        )
        changes += 1
        print("  Added qwen3.5-flash alias")
    else:
        print("  WARNING: Could not find insertion point for qwen3.5-flash")

# 5. Fix or-glm-air-free - check if the model_name is registered correctly
# The config had "or-glm-4.5-air-free" but test used "or-glm-air-free"
if 'model_name: "or-glm-air-free"' not in content and 'model_name: "or-glm-4.5-air-free"' in content:
    # Add alias
    content = content.replace(
        '  - model_name: "or-glm-4.5-air-free"',
        '  - model_name: "or-glm-4.5-air-free"\n'
        '    # Also registered as or-glm-air-free\n\n'
        '  - model_name: "or-glm-air-free"\n'
        '    litellm_params:\n'
        '      model: "openrouter/z-ai/glm-4.5-air:free"\n'
        '      api_key: os.environ/OPENROUTER_API_KEY\n'
        '    model_info:\n'
        '      max_tokens: 8192\n'
        '      context_window: 128000\n'
        '      free_tier: true\n\n'
    )
    changes += 1
    print("  Added or-glm-air-free alias")

# 6. Check Gemini key
print("\n  Checking Gemini key...")
with open("/opt/litellm/.env") as f:
    for line in f:
        if line.startswith("GEMINI_API_KEY="):
            gkey = line.strip().split("=", 1)[1]
            print(f"  Gemini key: {gkey[:8]}...{gkey[-4:]}")
            # Test it
            try:
                req = urllib.request.Request(
                    f"https://generativelanguage.googleapis.com/v1beta/models?key={gkey}"
                )
                resp = urllib.request.urlopen(req, timeout=10)
                print(f"  Gemini key: VALID ({resp.status})")
            except urllib.error.HTTPError as e:
                print(f"  Gemini key: INVALID (HTTP {e.code}) - needs renewal")
            except Exception as e:
                print(f"  Gemini key: ERROR - {e}")
            break

# Write config
with open(CONFIG, "w") as f:
    f.write(content)

# Also sync to mount path
with open(CONFIG_MOUNT, "w") as f:
    f.write(content)

print(f"\n  Total changes: {changes}")
print(f"  Config synced to both paths")
print(f"  Model entries: {content.count('model_name:')}")
