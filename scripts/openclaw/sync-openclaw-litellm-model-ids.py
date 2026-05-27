#!/usr/bin/env python3
"""
Alinha referências a modelos no openclaw.json aos model_name expostos pelo LiteLLM (/v1/models).

Reason: LiteLLM deste deploy expõe p.ex. `deepseek`, `kimi-k2.5`, `claude-sonnet-4-6`, não
`deepseek/deepseek-chat` nem `moonshot/kimi-k2.5` nem `anthropic/claude-*` como ID de pedido.
"""
from __future__ import annotations

import json
import os
import sys
from copy import deepcopy
from pathlib import Path

# Ordem: strings mais longas primeiro (evitar substituições parciais).
LITELLM_MODEL_ID_REPLACEMENTS: tuple[tuple[str, str], ...] = (
    ("openrouter/deepseek/deepseek-v3.2", "deepseek-v3.2"),
    ("openrouter/z-ai/glm-4.5-air:free", "glm-air"),
    ("anthropic/claude-haiku-4-5-20251001", "claude-haiku-4-5-20251001"),
    ("anthropic/claude-sonnet-4-6", "claude-sonnet-4-6"),
    ("anthropic/claude-opus-4-6", "claude-opus-4-6"),
    ("moonshot/kimi-k2-thinking-turbo", "kimi-turbo"),
    ("moonshot/kimi-k2-thinking", "kimi-thinking"),
    ("moonshot/kimi-k2.5", "kimi-k2.5"),
    ("deepseek/deepseek-reasoner", "r1"),
    ("deepseek/deepseek-chat", "deepseek"),
    ("qwen/qwen3-coder-next", "qwen-coder"),
)


def remap_model_string(s: str) -> str:
    out = s
    for old, new in LITELLM_MODEL_ID_REPLACEMENTS:
        out = out.replace(old, new)
    return out


def replace_model_refs(value: object) -> object:
    if isinstance(value, str):
        return remap_model_string(value)
    if isinstance(value, list):
        return [replace_model_refs(x) for x in value]
    if isinstance(value, dict):
        out: dict[str, object] = {}
        for k, v in value.items():
            nk = remap_model_string(k) if isinstance(k, str) else k
            out[str(nk)] = replace_model_refs(v)
        return out
    return value


def qualify_zai_catalog_ids(providers: dict) -> None:
    zai = providers.get("zai")
    if not isinstance(zai, dict):
        return
    models = zai.get("models")
    if not isinstance(models, list):
        return
    for m in models:
        if not isinstance(m, dict):
            continue
        mid = m.get("id")
        if isinstance(mid, str) and mid and "/" not in mid and mid.startswith("glm"):
            m["id"] = f"zai/{mid}"


def set_deepseek_openai_completions(providers: dict) -> None:
    ds = providers.get("deepseek")
    if isinstance(ds, dict):
        ds["api"] = "openai-completions"


def fix_anthropic_catalog_ids(providers: dict) -> None:
    a = providers.get("anthropic")
    if not isinstance(a, dict):
        return
    models = a.get("models")
    if not isinstance(models, list):
        return
    for m in models:
        if not isinstance(m, dict):
            continue
        mid = m.get("id")
        if isinstance(mid, str) and mid.startswith("anthropic/"):
            m["id"] = mid.split("/", 1)[1]


def fix_openai_catalog_ids(providers: dict) -> None:
    o = providers.get("openai")
    if not isinstance(o, dict):
        return
    models = o.get("models")
    if not isinstance(models, list):
        return
    for m in models:
        if not isinstance(m, dict):
            continue
        mid = m.get("id")
        if mid == "gpt-5.3-instant":
            m["id"] = "openai/gpt-5.3-instant"


def fix_openrouter_catalog_ids(providers: dict) -> None:
    r = providers.get("openrouter")
    if not isinstance(r, dict):
        return
    models = r.get("models")
    if not isinstance(models, list):
        return
    for m in models:
        if not isinstance(m, dict):
            continue
        mid = m.get("id")
        if mid == "deepseek/deepseek-v3.2":
            m["id"] = "deepseek-v3.2"


def fix_deepseek_catalog_ids(providers: dict) -> None:
    ds = providers.get("deepseek")
    if not isinstance(ds, dict):
        return
    models = ds.get("models")
    if not isinstance(models, list):
        return
    for m in models:
        if not isinstance(m, dict):
            continue
        mid = m.get("id")
        if mid == "deepseek-chat":
            m["id"] = "deepseek"
        elif mid == "deepseek-reasoner":
            m["id"] = "r1"


def qualify_google_flash_ids(providers: dict) -> None:
    g = providers.get("google")
    if not isinstance(g, dict):
        return
    models = g.get("models")
    if not isinstance(models, list):
        return
    for m in models:
        if not isinstance(m, dict):
            continue
        mid = m.get("id")
        if mid == "gemini-3.1-pro-preview":
            m["id"] = "google/gemini-3.1-pro-preview"
        elif mid in ("gemini-2.5-flash", "gemini-2.5-flash-lite"):
            m["id"] = f"google/{mid}"


QWEN_CATALOG_ID_MAP: dict[str, str] = {
    "qwen3.5-plus-02-15": "qwen3.5-plus",
    "qwen3-max-2026-01-23": "qwen3-max",
    "qwen3-coder-next": "qwen-coder",
}


def fix_moonshot_kimi_catalog_ids(providers: dict) -> None:
    """LiteLLM model_name: kimi-thinking, kimi-turbo (não kimi-k2-thinking)."""
    for key in ("moonshot", "kimi"):
        block = providers.get(key)
        if not isinstance(block, dict):
            continue
        models = block.get("models")
        if not isinstance(models, list):
            continue
        for m in models:
            if not isinstance(m, dict):
                continue
            mid = m.get("id")
            if mid == "kimi-k2-thinking":
                m["id"] = "kimi-thinking"
            elif mid == "kimi-k2-thinking-turbo":
                m["id"] = "kimi-turbo"
            elif key == "kimi" and mid == "moonshot-v1-128k":
                m["id"] = "kimi/moonshot-v1-128k"


def map_qwen_catalog_ids(providers: dict) -> None:
    q = providers.get("qwen")
    if not isinstance(q, dict):
        return
    models = q.get("models")
    if not isinstance(models, list):
        return
    for m in models:
        if not isinstance(m, dict):
            continue
        mid = m.get("id")
        if isinstance(mid, str) and mid in QWEN_CATALOG_ID_MAP:
            m["id"] = QWEN_CATALOG_ID_MAP[mid]


def main() -> int:
    path = Path(os.environ.get("OPENCLAW_JSON", "/root/.openclaw/openclaw.json"))
    if not path.is_file():
        print("ERRO: openclaw.json inexistente", file=sys.stderr)
        return 1
    raw = path.read_text(encoding="utf-8")
    data = json.loads(raw)
    new_data = replace_model_refs(deepcopy(data))
    provs = new_data.get("models", {}).get("providers")
    if isinstance(provs, dict):
        qualify_zai_catalog_ids(provs)
        set_deepseek_openai_completions(provs)
        fix_anthropic_catalog_ids(provs)
        fix_openai_catalog_ids(provs)
        fix_openrouter_catalog_ids(provs)
        fix_deepseek_catalog_ids(provs)
        qualify_google_flash_ids(provs)
        map_qwen_catalog_ids(provs)
        fix_moonshot_kimi_catalog_ids(provs)
    new_raw = json.dumps(new_data, indent=2, ensure_ascii=False) + "\n"
    if new_raw == raw:
        print("Nada a alterar.")
        return 0
    bak = path.with_suffix(".json.bak.litellm-ids")
    bak.write_text(raw, encoding="utf-8")
    path.write_text(new_raw, encoding="utf-8")
    print(f"OK: backup {bak}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
