#!/usr/bin/env python3
"""Quick model tier test from HOST (not container)."""
import urllib.request, json, time

URL = "http://localhost:4000/v1/chat/completions"
KEY = "sk-litellm-8fd0003fd1a3883e7d6308c60cb5eed3ac4680832e801ded90e1873ce4dfe1a0"

TESTS = [
    ("STRONG", "agl-primary", 60),
    ("CREATIVE", "claude-sonnet-4-6", 30),
    ("MEDIUM", "qwen-plus", 30),
    ("FAST-qwen", "qwen3.5-flash", 30),
    ("FAST-groq", "groq-llama-33", 30),
    ("ZAI", "glm-5", 30),
    ("ZAI-flash", "glm-4.7-flash", 30),
]

for label, model, timeout in TESTS:
    payload = json.dumps({"model": model, "messages": [{"role": "user", "content": "OK"}], "max_tokens": 5}).encode()
    req = urllib.request.Request(URL, data=payload)
    req.add_header("Content-Type", "application/json")
    req.add_header("Authorization", f"Bearer {KEY}")
    t = time.time()
    try:
        resp = urllib.request.urlopen(req, timeout=timeout)
        data = json.loads(resp.read())
        c = data["choices"][0]["message"]["content"] if data.get("choices") else "empty"
        lat = int((time.time() - t) * 1000)
        print(f"  PASS  {label:<15} {model:<25} {lat:5d}ms  {c[:15]}")
    except Exception as e:
        lat = int((time.time() - t) * 1000)
        print(f"  FAIL  {label:<15} {model:<25} {lat:5d}ms  {str(e)[:40]}")
