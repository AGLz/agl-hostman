#!/usr/bin/env python3
"""
Comprehensive LiteLLM model test - tests ALL models for response, latency, errors.
Groups by provider and reports detailed results.
"""
import urllib.request
import json
import time
import sys

LITELLM_URL = "http://localhost:4000"
LITELLM_KEY = "sk-litellm-8fd0003fd1a3883e7d6308c60cb5eed3ac4680832e801ded90e1873ce4dfe1a0"

# All models from the LiteLLM config, grouped by provider
MODELS = {
    "Ollama (local)": [
        "agl-primary",
        "ollama-nemotron-3-nano-4b",
        "openai/ollama-nemotron-3-nano-4b",
        "ollama-qwen3-0.6b",
        "ollama-qwen3-1.7b",
        "ollama-deepseek-r1-1.5b",
    ],
    "ZAI (free)": [
        "glm-4.7-flash",
        "glm-flash",
        "glm-5",
        "glm-4.7",
        "glm",
        "glm-air",
        "glm-4.5-flash",
    ],
    "Anthropic (paid)": [
        "claude-sonnet-4-6",
        "claude-haiku",
    ],
    "DashScope/Qwen": [
        "qwen3.5-flash",
        "qwen-plus",
        "qwen-coder",
        "qwen-turbo",
        "qwen3.5-plus",
        "qwen-max",
    ],
    "DeepSeek": [
        "deepseek",
        "r1",
    ],
    "Google Gemini": [
        "gemini-lite",
        "google/gemini-2.5-flash",
        "gemini-2.5-pro",
    ],
    "Moonshot/Kimi": [
        "kimi",
        "kimi-128k",
    ],
    "OpenAI": [
        "gpt",
        "gpt-4o",
    ],
    "Groq": [
        "groq-llama-33",
        "groq-llama-31-8b",
    ],
    "Cerebras": [
        "cerebras-llama-33",
    ],
    "OpenRouter (free)": [
        "or-glm-air-free",
        "or-llama-3.3-70b-free",
        "or-gemma-3-4b-free",
        "or-qwen3-coder-free",
        "or-mistral-small-free",
        "or-step-3.5-free",
        "openrouter/openrouter/free",
    ],
}

def test_model(model, timeout=30):
    """Test a single model. Returns (success, latency_ms, error_msg, response_preview)."""
    payload = json.dumps({
        "model": model,
        "messages": [{"role": "user", "content": "Say OK"}],
        "max_tokens": 10
    }).encode()
    
    start = time.time()
    try:
        req = urllib.request.Request(f"{LITELLM_URL}/v1/chat/completions", data=payload)
        req.add_header("Content-Type", "application/json")
        req.add_header("Authorization", f"Bearer {LITELLM_KEY}")
        resp = urllib.request.urlopen(req, timeout=timeout)
        latency = int((time.time() - start) * 1000)
        data = json.loads(resp.read())
        content = data["choices"][0]["message"]["content"] if data.get("choices") else ""
        usage = data.get("usage", {})
        tokens = usage.get("total_tokens", 0)
        return True, latency, None, content[:30], tokens
    except urllib.error.HTTPError as e:
        latency = int((time.time() - start) * 1000)
        body = e.read().decode()[:200]
        # Extract short error
        try:
            err_data = json.loads(body)
            msg = err_data.get("error", {}).get("message", body)[:100]
        except:
            msg = body[:100]
        return False, latency, f"HTTP {e.code}: {msg}", None, 0
    except Exception as e:
        latency = int((time.time() - start) * 1000)
        return False, latency, f"{type(e).__name__}: {str(e)[:80]}", None, 0

# Run tests
print("=" * 80)
print("  LiteLLM Comprehensive Model Test")
print("=" * 80)

total_pass = 0
total_fail = 0
results_by_group = {}

for group, models in MODELS.items():
    print(f"\n--- {group} ---")
    group_results = []
    for model in models:
        ok, lat, err, preview, tokens = test_model(model)
        if ok:
            total_pass += 1
            print(f"  PASS  {model:45s} {lat:5d}ms  {tokens:3d}tok  {preview}")
        else:
            total_fail += 1
            print(f"  FAIL  {model:45s} {lat:5d}ms  {err}")
        group_results.append({
            "model": model, "ok": ok, "latency_ms": lat,
            "error": err, "preview": preview, "tokens": tokens
        })
    results_by_group[group] = group_results

# Summary
print("\n" + "=" * 80)
print("  SUMMARY")
print("=" * 80)
print(f"\n  Total: {total_pass + total_fail} models tested")
print(f"  PASS:  {total_pass}")
print(f"  FAIL:  {total_fail}")

print("\n  By provider:")
for group, results in results_by_group.items():
    passed = sum(1 for r in results if r["ok"])
    failed = sum(1 for r in results if not r["ok"])
    avg_lat = 0
    working = [r for r in results if r["ok"]]
    if working:
        avg_lat = sum(r["latency_ms"] for r in working) // len(working)
    status = "OK" if failed == 0 else f"{passed}/{len(results)}"
    print(f"    {group:25s}  {status:8s}  avg {avg_lat:5d}ms")

# Failed models detail
failed_models = [(g, r) for g, results in results_by_group.items() for r in results if not r["ok"]]
if failed_models:
    print("\n  Failed models:")
    for group, r in failed_models:
        print(f"    [{group}] {r['model']}: {r['error']}")

# Performance ranking (top 10 fastest)
all_ok = [(g, r) for g, results in results_by_group.items() for r in results if r["ok"]]
all_ok.sort(key=lambda x: x[1]["latency_ms"])
print("\n  Fastest models (top 10):")
for g, r in all_ok[:10]:
    print(f"    {r['latency_ms']:5d}ms  {r['model']} [{g}]")
