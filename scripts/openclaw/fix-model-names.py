#!/usr/bin/env python3
"""
Fix OpenClaw model names to match LiteLLM aliases.
Since all providers route through LiteLLM, model names must match LiteLLM's model list.
"""
import json

PATH = "/mnt/overpower/apps/dev/agl/openclaw-repo/config/openclaw.json"

with open(PATH) as f:
    cfg = json.load(f)

# =============================================
# 1. Consolidate to single provider pointing to LiteLLM
# =============================================
LITELLM_URL = "http://192.168.32.3:4000"
LITELLM_KEY = "sk-litellm-8fd0003fd1a3883e7d6308c60cb5eed3ac4680832e801ded90e1873ce4dfe1a0"

# Replace all providers with a single "openai" provider
# LiteLLM exposes an OpenAI-compatible API
cfg["models"]["providers"] = {
    "openai": {
        "baseUrl": LITELLM_URL,
        "apiKey": LITELLM_KEY,
        "api": "openai-completions",
        "models": []
    }
}

# =============================================
# 2. Fix agent model references to use LiteLLM names
# =============================================
# Model name mapping: OpenClaw name -> LiteLLM name
MODEL_MAP = {
    "zai/glm-5": "agl-primary",
    "zai/glm-4.7": "agl-primary",
    "zai/glm-4.7-flash": "qwen3.5-flash",
    "anthropic/claude-sonnet-4-6": "claude-sonnet-4-6",
    "anthropic/claude-opus-4-6": "claude-opus-4-6",
    "anthropic/claude-haiku-4-5-20251001": "claude-haiku-4-5-20251001",
    "moonshot/kimi-k2.5": "kimi",
    "kimi/moonshot-v1-128k": "kimi-128k",
    "deepseek/deepseek-chat": "deepseek",
    "deepseek/deepseek-reasoner": "r1",
    "openai/gpt-5.3-chat-latest": "gpt",
    "openai/gpt-5.3-instant": "gpt",
    "openai/gpt-5.4": "gpt",
    "openai/gpt-4o": "gpt-4o",
    "openai/gpt-4o-mini": "gpt-4o",
    "openai/gpt-4.1": "gpt-4o",
    "google/gemini-3.1-pro-preview": "gemini-3.1-pro",
    "google/gemini-3.1-pro": "gemini-3.1-pro",
    "google/gemini-2.5-pro": "gemini-2.5-pro",
    "google/gemini-2.5-flash": "google/gemini-2.5-flash",
    "google/gemini-2.5-flash-lite": "gemini-lite",
    "google/gemini-2.0-flash": "gemini-2.0",
    "openrouter/deepseek/deepseek-v3.2": "deepseek-v3.2",
    "openrouter/z-ai/glm-4.5-air:free": "or-glm-air-free",
    "openrouter/google/gemini-2.5-flash-lite:free": "openrouter/google/gemini-2.5-flash-lite:free",
    "openrouter/meta-llama/llama-3.3-70b-instruct:free": "openrouter/meta-llama/llama-3.3-70b-instruct:free",
    "openrouter/deepseek/deepseek-chat": "deepseek",
    "openrouter/deepseek/deepseek-r1": "r1",
    "openrouter/openrouter/free": "openrouter/openrouter/free",
    "openrouter/google/gemini-2.0-flash-exp:free": "gemini-2.0",
    "dashscope/qwen-plus": "qwen-plus",
    "dashscope/qwen-coder": "qwen-coder",
    "openai/ollama-nemotron-3-nano-4b": "ollama-nemotron-3-nano-4b",
    "moonshot/kimi-k2-thinking": "kimi",
    "moonshot/kimi-k2-thinking-turbo": "kimi",
}

def map_model(name):
    return MODEL_MAP.get(name, name)

# Fix defaults
defaults = cfg["agents"]["defaults"]
defaults["model"]["primary"] = map_model(defaults["model"]["primary"])
defaults["model"]["fallbacks"] = [map_model(f) for f in defaults["model"]["fallbacks"]]

# Fix imageModel
if isinstance(defaults.get("imageModel"), dict):
    defaults["imageModel"]["primary"] = map_model(defaults["imageModel"]["primary"])
    defaults["imageModel"]["fallbacks"] = [map_model(f) for f in defaults["imageModel"].get("fallbacks", [])]
elif isinstance(defaults.get("imageModel"), str):
    defaults["imageModel"] = map_model(defaults["imageModel"])

# Fix compaction model
if "compaction" in defaults and "model" in defaults["compaction"]:
    defaults["compaction"]["model"] = map_model(defaults["compaction"]["model"])

# Fix model aliases
new_models = {}
for old_key, val in defaults.get("models", {}).items():
    new_key = map_model(old_key)
    new_models[new_key] = val
defaults["models"] = new_models

# Fix per-agent models
for agent in cfg["agents"].get("list", []):
    if "model" in agent:
        if isinstance(agent["model"], dict):
            agent["model"]["primary"] = map_model(agent["model"]["primary"])
            if "fallbacks" in agent["model"]:
                agent["model"]["fallbacks"] = [map_model(f) for f in agent["model"]["fallbacks"]]
        elif isinstance(agent["model"], str):
            agent["model"] = map_model(agent["model"])

# =============================================
# 3. Write result
# =============================================
with open(PATH, "w") as f:
    json.dump(cfg, f, indent=2, ensure_ascii=False)

print("=== Model names fixed ===")
print(f"Primary: {defaults['model']['primary']}")
print(f"Fallbacks: {defaults['model']['fallbacks']}")
print(f"Providers: {list(cfg['models']['providers'].keys())}")
print(f"Aliases: {len(defaults.get('models', {}))}")

# Show agent models
for agent in cfg["agents"].get("list", []):
    if "model" in agent:
        m = agent["model"]
        if isinstance(m, dict):
            print(f"  Agent {agent['id']}: {m['primary']}")
        else:
            print(f"  Agent {agent['id']}: {m}")
