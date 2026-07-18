#!/usr/bin/env python3
"""Remapeia aliases OpenAI no LiteLLM — ChatGPT Plus ≠ créditos API.

Política AGL (2026-07-18): subscription é ChatGPT Plus (produto). Sem billing
em platform.openai.com → todos os chat devolvem insufficient_quota.
Aliases gpt-* e misrouted glm-4.7-flash → Z.AI glm-4.5-flash (como claude-*).

Uso:
  python3 scripts/litellm/remap-openai-no-api-chatgpt-plus.py config/litellm/config.yaml
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

import yaml

ZAI_BLOCK = """- litellm_params:
    api_base: https://api.z.ai/api/anthropic
    api_key: os.environ/ZAI_API_KEY
    model: anthropic/glm-4.5-flash
    max_tokens: 8192
    timeout: 90
  model_info:
    access: direct
    context_window: 131072
    free_tier: true
    input_cost_per_token: 0
    max_tokens: 8192
    note: 'ChatGPT Plus ≠ API OpenAI (2026-07). Sem créditos platform.openai.com;
      alias → Z.AI glm-4.5-flash. Reverter para openai/* quando billing API activo.'
    output_cost_per_token: 0
    data_policy: zero-openai-api-chatgpt-plus-only
"""

# Aliases que usam OPENAI_API_KEY / openai/gpt-* e devem ir para Z.AI
REMAP_NAMES = {
    "gpt",
    "gpt-4o",
    "gpt-4o-mini",
    "gpt-5-mini",
    "gpt-5-nano",
    "gpt-5.4",
    "gpt-5.4-mini",
    "gpt-5.4-nano",
    "gpt-5.5",
    "gpt-5.6",
    "gpt-5.6-sol",
    "gpt-5.6-terra",
    "gpt-5.6-luna",
    # miswired: estavam openai/gpt-5-nano
    "glm-4.7-flash",
    "zai/glm-4.7-flash",
}


def _replace_model_blocks(text: str, names: set[str], block: str) -> str:
    lines = text.splitlines(keepends=True)
    out: list[str] = []
    i = 0
    block_re = re.compile(r"^- litellm_params:")
    name_re = re.compile(r"^\s+model_name:\s+(\S+)")
    while i < len(lines):
        line = lines[i]
        if not block_re.match(line):
            out.append(line)
            i += 1
            continue
        start = i
        i += 1
        model_name: str | None = None
        while i < len(lines) and not block_re.match(lines[i]):
            m = name_re.match(lines[i])
            if m:
                model_name = m.group(1)
            i += 1
        if model_name and model_name in names:
            out.append(block)
            out.append(f"  model_name: {model_name}\n")
        else:
            out.extend(lines[start:i])
    return "".join(out)


def main() -> None:
    if len(sys.argv) != 2:
        print(f"Uso: {sys.argv[0]} <config.yaml>", file=sys.stderr)
        raise SystemExit(2)
    path = Path(sys.argv[1])
    text = path.read_text(encoding="utf-8")
    out = _replace_model_blocks(text, REMAP_NAMES, ZAI_BLOCK)
    yaml.safe_load(out)
    path.write_text(out, encoding="utf-8")
    print(f"OK: remapeados {len(REMAP_NAMES)} aliases → Z.AI glm-4.5-flash ({path})")


if __name__ == "__main__":
    main()
