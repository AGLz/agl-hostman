#!/usr/bin/env python3
"""Patch LiteLLM config (text-safe): output caps + fallback chains."""
from __future__ import annotations

import re
import sys
from pathlib import Path

CAP_512_ALIASES = frozenset(
    {
        "zai-glm-5",
        "zai-glm-flash",
        "glm-flash",
        "glm-4.7-flash",
        "agl-primary-zai-glm-flash",
        "qwen-turbo",
        "qwen-plus",
    }
)

NEW_OUTPUT_CAP = 8192

FALLBACK_CHAINS: dict[str, list[str]] = {
    "zai-glm-flash": [
        "glm-5",
        "gpt-5.4-mini",
        "agl-primary",
        "glm-4.7-flash",
        "or-nemotron-super-free",
    ],
    "zai-glm-5": [
        "glm-5",
        "gpt-5.4-mini",
        "zai-coding-glm-4.7",
        "agl-primary",
        "glm-4.7-flash",
        "or-nemotron-super-free",
    ],
}


def _patch_model_entries(text: str) -> tuple[str, int]:
    """Cada entrada: - litellm_params ... model_name: X"""
    entry_re = re.compile(
        r"(  - litellm_params:.*?^\s+model_name:\s+(\S+)\s*$)",
        re.MULTILINE | re.DOTALL,
    )
    changed = 0

    def repl(m: re.Match[str]) -> str:
        nonlocal changed
        block, model_name = m.group(1), m.group(2)
        if model_name not in CAP_512_ALIASES:
            return block
        new_block, n = re.subn(
            r"(?m)^(\s+max_tokens:\s+)512\s*$",
            rf"\g<1>{NEW_OUTPUT_CAP}",
            block,
            count=1,
        )
        if n:
            changed += n
            return new_block
        return block

    return entry_re.sub(repl, text), changed


def _format_chain(model: str, chain: list[str]) -> str:
    lines = [f"    - {model}:"]
    for item in chain:
        lines.append(f"        - {item}")
    return "\n".join(lines) + "\n"


def _patch_fallbacks_in_section(text: str, section_key: str) -> tuple[str, int]:
    m = re.search(rf"^  {section_key}:\s*$", text, re.MULTILINE)
    if not m:
        return text, 0
    rest = text[m.end():]
    next_key = re.search(r"^  [a-z_]+:\s*$", rest, re.MULTILINE)
    section_end = m.end() + (next_key.start() if next_key else len(rest))
    block = text[m.end(): section_end]
    changed = 0
    for model, chain in FALLBACK_CHAINS.items():
        pattern = re.compile(
            rf"^    - {re.escape(model)}:\s*\n(?:        - .+\n)+",
            re.MULTILINE,
        )
        replacement = _format_chain(model, chain)
        if pattern.search(block):
            new_block, n = pattern.subn(replacement, block, count=1)
            if n:
                block = new_block
                changed += 1
        else:
            block = block.rstrip() + "\n" + replacement
            changed += 1
    return text[: m.end()] + block + text[section_end:], changed


def patch_config(path: Path) -> None:
    raw = path.read_text(encoding="utf-8")
    text, cap_changes = _patch_model_entries(raw)
    text, fb1 = _patch_fallbacks_in_section(text, "fallbacks")
    text, fb2 = _patch_fallbacks_in_section(text, "context_window_fallbacks")
    path.write_text(text, encoding="utf-8")
    print(
        f"OK {path}: max_tokens bumps={cap_changes}, "
        f"fallback chains={fb1 + fb2} (fallbacks+ctx_window)"
    )


def main() -> None:
    target = Path(sys.argv[1] if len(sys.argv) >
                  1 else "config/litellm/config.yaml")
    patch_config(target)


if __name__ == "__main__":
    main()
