#!/usr/bin/env python3
"""Detailed LiteLLM chat test with error reporting."""
import urllib.request
import json
import sys

LITELLM_URL = "http://localhost:4000"
LITELLM_KEY = "sk-litellm-8fd0003fd1a3883e7d6308c60cb5eed3ac4680832e801ded90e1873ce4dfe1a0"

MODELS = [
    "zai/glm-5",
    "zai/glm-4.7-flash", 
    "deepseek/deepseek-chat",
    "openrouter/z-ai/glm-4.5-air:free",
    "openrouter/deepseek/deepseek-chat",
    "dashscope/qwen-plus",
    "moonshot/kimi-k2.5",
    "agl-primary",
    "google/gemini-2.5-flash",
]

for model in MODELS:
    try:
        payload = json.dumps({
            "model": model,
            "messages": [{"role": "user", "content": "Say OK"}],
            "max_tokens": 10
        }).encode()
        req = urllib.request.Request(f"{LITELLM_URL}/v1/chat/completions", data=payload)
        req.add_header("Content-Type", "application/json")
        req.add_header("Authorization", f"Bearer {LITELLM_KEY}")
        resp = urllib.request.urlopen(req, timeout=30)
        data = json.loads(resp.read())
        content = data["choices"][0]["message"]["content"]
        print(f"  PASS {model}: {content[:30]}")
    except urllib.error.HTTPError as e:
        body = e.read().decode()[:200]
        print(f"  FAIL {model}: HTTP {e.code} - {body}")
    except Exception as e:
        print(f"  FAIL {model}: {type(e).__name__}: {e}")
