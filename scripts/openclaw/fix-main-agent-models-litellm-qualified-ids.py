#!/usr/bin/env python3
"""
Normaliza `id` em agents/main/agent/models.json para coincidir com model_name do LiteLLM (/v1/models).

Reason: O OpenClaw envia o `id` do catálogo no body model=.... Este deploy expõe p.ex. zai/glm-5,
claude-sonnet-4-6, deepseek, kimi-k2.5 — não glm-5, anthropic/claude-..., deepseek/deepseek-chat.
"""
from __future__ import annotations

import json
import os
import sys
from pathlib import Path

QWEN_ID_MAP = {
    "qwen3.5-plus-02-15": "qwen3.5-plus",
    "qwen3-max-2026-01-23": "qwen3-max",
    "qwen3-coder-next": "qwen-coder",
}


def normalize_id(provider: str, mid: str) -> str:
    if not mid or not isinstance(mid, str):
        return mid
    if provider == "kimi" and mid == "moonshot-v1-128k":
        return "kimi/moonshot-v1-128k"
    if provider == "zai" and "/" not in mid and mid.startswith("glm"):
        return f"zai/{mid}"
    if provider == "anthropic":
        if mid.startswith("anthropic/"):
            return mid.split("/", 1)[1]
        return mid
    if provider == "deepseek":
        if mid == "deepseek-chat":
            return "deepseek"
        if mid == "deepseek-reasoner":
            return "r1"
        if mid.startswith("deepseek/"):
            return mid.split("/", 1)[1]
        return mid
    if provider == "google":
        if mid == "gemini-3.1-pro-preview":
            return "google/gemini-3.1-pro-preview"
        if mid in ("gemini-2.5-flash", "gemini-2.5-flash-lite"):
            return f"google/{mid}"
        if mid.startswith("google/"):
            return mid
        return mid
    if provider == "openai":
        if mid == "gpt-5.3-instant":
            return "openai/gpt-5.3-instant"
        if mid.startswith("openai/"):
            return mid
        return mid
    if provider == "openrouter":
        if mid == "deepseek/deepseek-v3.2":
            return "deepseek-v3.2"
        return mid
    if provider == "qwen":
        return QWEN_ID_MAP.get(mid, mid)
    if provider in ("moonshot", "kimi"):
        if mid == "kimi-k2-thinking":
            return "kimi-thinking"
        if mid == "kimi-k2-thinking-turbo":
            return "kimi-turbo"
        return mid
    return mid


def main() -> int:
    p = Path(
        os.environ.get(
            "OPENCLAW_AGENT_MODELS_JSON",
            "/root/.openclaw/agents/main/agent/models.json",
        ),
    )
    if not p.is_file():
        print("ERRO: models.json inexistente", file=sys.stderr)
        return 1
    raw = p.read_text(encoding="utf-8")
    data = json.loads(raw)
    provs = data.get("providers")
    if not isinstance(provs, dict):
        print("ERRO: providers inválido", file=sys.stderr)
        return 1

    if isinstance(provs.get("deepseek"), dict):
        provs["deepseek"]["api"] = "openai-completions"

    changed = []
    for pname, prov in provs.items():
        if not isinstance(prov, dict):
            continue
        models = prov.get("models")
        if not isinstance(models, list):
            continue
        for m in models:
            if not isinstance(m, dict):
                continue
            old = m.get("id")
            if not isinstance(old, str) or not old:
                continue
            new = normalize_id(str(pname), old)
            if new != old:
                m["id"] = new
                changed.append((pname, old, new))

    if not changed:
        print("Nada a alterar.")
        return 0
    bak = p.with_suffix(".json.bak.litellm-normalize")
    bak.write_text(raw, encoding="utf-8")
    p.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    try:
        p.chmod(0o600)
    except OSError:
        pass
    print(f"OK: backup {bak}")
    for row in changed:
        print(f"  {row[0]}: {row[1]} → {row[2]}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
