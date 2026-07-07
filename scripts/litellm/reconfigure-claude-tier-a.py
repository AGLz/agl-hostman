#!/usr/bin/env python3
"""Reconfigura entradas claude-* no config.yaml: primário Z.AI Anthropic glm-4.5-flash."""
from __future__ import annotations

import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
CONFIG = REPO / "config" / "litellm" / "config.yaml"

ZAI_BLOCK = """    api_base: https://api.z.ai/api/anthropic
    api_key: os.environ/ZAI_API_KEY
    model: anthropic/glm-4.5-flash
    max_tokens: 8192
    timeout: 90"""

CLAUDE_FALLBACK_PREFIX = """    - zai-glm-flash
    - glm-flash
    - groq-llama-31-8b
    - agl-primary-zai-glm-flash
    - agl-primary"""


def patch_claude_model_entries(text: str) -> tuple[str, int]:
    """Substitui blocos litellm_params Anthropic direct por Z.AI para model_name claude-*."""
    count = 0
    pattern = re.compile(
        r"(- litellm_params:\n)"
        r"((?:    .+\n)*?)"
        r"(  model_info:\n(?:    .+\n)*?)"
        r"(  model_name: (claude[^\n]+)\n)",
        re.MULTILINE,
    )

    def repl(m: re.Match[str]) -> str:
        nonlocal count
        params = m.group(2)
        model_name = m.group(5).strip()
        if "ANTHROPIC_API_KEY" not in params or not model_name.startswith("claude"):
            return m.group(0)
        count += 1
        return (
            f"{m.group(1)}{ZAI_BLOCK}\n"
            f"  model_info:\n"
            f"    access: direct\n"
            f"    context_window: 131072\n"
            f"    max_tokens: 8192\n"
            f"    note: '{model_name} → Z.AI glm-4.5-flash (tier A)'\n"
            f"  model_name: {model_name}\n"
        )

    return pattern.sub(repl, text), count


def patch_claude_fallback_lists(text: str) -> tuple[str, int]:
    """Prioriza zai-glm-flash nos fallbacks de modelos claude-*."""
    count = 0
    lines = text.splitlines(keepends=True)
    out: list[str] = []
    i = 0
    while i < len(lines):
        line = lines[i]
        m = re.match(r"  - (claude[^\s:]+):\s*$", line)
        if m:
            out.append(line)
            i += 1
            # skip existing indented fallbacks
            while i < len(lines) and lines[i].startswith("    - "):
                i += 1
            out.append(CLAUDE_FALLBACK_PREFIX + "\n")
            count += 1
            continue
        out.append(line)
        i += 1
    return "".join(out), count


def main() -> int:
    if not CONFIG.is_file():
        print(f"ERRO: {CONFIG} não encontrado", file=sys.stderr)
        return 1

    original = CONFIG.read_text(encoding="utf-8")
    text, models = patch_claude_model_entries(original)
    text, fallbacks = patch_claude_fallback_lists(text)

    if models == 0 and fallbacks == 0:
        print("Nada a alterar (já em tier A?)")
        return 0

    CONFIG.write_text(text, encoding="utf-8")
    print(f"OK: {CONFIG}")
    print(f"  model_list claude-*: {models} entradas")
    print(f"  fallbacks claude-*: {fallbacks} listas")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
