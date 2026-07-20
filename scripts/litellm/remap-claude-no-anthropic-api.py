#!/usr/bin/env python3
"""Surgical remap: Claude aliases off Anthropic API; add GPT-5.6; fix fallbacks. Preserves YAML layout."""
from __future__ import annotations

import re
import sys
from pathlib import Path

import yaml

CONFIG = Path(__file__).resolve().parents[2] / "config/litellm/config.yaml"
NOTE = "sem Anthropic API — Claude Code Pro só no IDE; alias → Z.AI/Groq"
QUOTA_NOTE = "OpenAI QUOTA esgotada (Jul 2026) — fallbacks Z.AI flash / Groq / agl-primary"

CLAUDE_NAMES = {
    "claude-opus", "claude-opus-4-7", "claude-opus-4-6",
    "claude-sonnet", "claude-sonnet-4-6", "claude-sonnet-4-5-20250929",
    "claude-haiku", "claude-haiku-4-5-20251001", "claude-sonnet-5",
    "claude-opus-4-8", "claude-opus-4-5-20251101", "claude-opus-4-6-20250514",
    "claude-3-5-haiku-20241022", "claude-haiku-3-5",
}

ZAI_BLOCK = """- litellm_params:
    api_base: https://api.z.ai/api/anthropic
    api_key: os.environ/ZAI_API_KEY
    model: anthropic/glm-4.5-flash
    max_tokens: 8192
    timeout: {timeout}
  model_info:
    access: direct
    context_window: 131072
    free_tier: true
    input_cost_per_token: 0
    max_tokens: 8192
    note: '{note}'
    output_cost_per_token: 0
  model_name: {name}"""

GPT56_BLOCK = """- litellm_params:
    api_key: os.environ/OPENAI_API_KEY
    model: {upstream}
    timeout: 120
  model_info:
    access: direct
    context_window: 1000000
    description: '{desc}; {quota}'
    max_tokens: 16384
    note: '{quota}'
  model_name: {alias}"""

GPT56 = [
    ("gpt-5.6", "openai/gpt-5.6-sol", "OpenAI GPT-5.6 (alias → Sol)"),
    ("gpt-5.6-sol", "openai/gpt-5.6-sol", "OpenAI GPT-5.6 Sol (frontier)"),
    ("gpt-5.6-terra", "openai/gpt-5.6-terra", "OpenAI GPT-5.6 Terra (balanced)"),
    ("gpt-5.6-luna", "openai/gpt-5.6-luna", "OpenAI GPT-5.6 Luna (fast/cheap)"),
]

CLAUDE_FB = """  - {name}:
    - zai-glm-flash
    - groq-llama-31-8b
    - agl-primary-zai-glm-flash
    - agl-primary"""


def remap_claude_blocks(text: str) -> tuple[str, list[str]]:
    remapped = []
    # Match model_list entries ending with model_name: claude-*
    pattern = re.compile(
        r"- litellm_params:\n"
        r"    api_key: os\.environ/ANTHROPIC_API_KEY\n"
        r"    model: anthropic/claude-[^\n]+\n"
        r"(?:    timeout: \d+\n)?"
        r"  model_info:\n"
        r"(?:    [^\n]+\n)*?"
        r"  model_name: (claude-[^\n]+)",
        re.MULTILINE,
    )

    def repl(m: re.Match) -> str:
        name = m.group(1).strip()
        if name not in CLAUDE_NAMES:
            return m.group(0)
        timeout = "60" if "haiku" in name else "90"
        note = f"{NOTE}; alias {name} → Z.AI glm-4.5-flash (+ fallbacks Groq/agl-*)"
        remapped.append(name)
        return ZAI_BLOCK.format(timeout=timeout, note=note, name=name)

    return pattern.sub(repl, text), remapped


def fix_claude_fallbacks(text: str) -> str:
    for name in CLAUDE_NAMES:
        # Replace entire fallback block for this claude alias in fallbacks section
        pat = re.compile(
            rf"  - {re.escape(name)}:\n(?:    - [^\n]+\n)+",
            re.MULTILINE,
        )
        text = pat.sub(CLAUDE_FB.format(name=name) + "\n", text)
    return text


def strip_claude_refs_in_fallbacks(text: str) -> str:
    """Remove claude-* from non-claude fallback chains (glm-5, gpt-5-mini, etc.)."""
    lines = text.splitlines(keepends=True)
    out = []
    i = 0
    in_fallbacks = False
    current_key = None
    while i < len(lines):
        line = lines[i]
        if line.strip() == "fallbacks:":
            in_fallbacks = True
            out.append(line)
            i += 1
            continue
        if in_fallbacks:
            m = re.match(r"  - ([^:]+):\s*$", line)
            if m:
                current_key = m.group(1).strip()
                out.append(line)
                i += 1
                continue
            if line.startswith("  - ") and not line.startswith("    "):
                in_fallbacks = False
                current_key = None
                out.append(line)
                i += 1
                continue
            if line.startswith("    - claude-") and current_key and not current_key.startswith("claude-"):
                i += 1
                continue
            if line.startswith("    - ") and current_key and not current_key.startswith("claude-"):
                # inject zai-glm-flash if chain starts with gpt/openai refs
                pass
        out.append(line)
        i += 1
    return "".join(out)


def add_gpt56_entries(text: str) -> tuple[str, list[str]]:
    added = []
    for alias, upstream, desc in GPT56:
        if f"model_name: {alias}\n" in text or f"model_name: {alias}\r\n" in text:
            continue
        block = GPT56_BLOCK.format(
            upstream=upstream, alias=alias, desc=desc, quota=QUOTA_NOTE
        )
        # Insert before gemini section
        marker = "- litellm_params:\n    api_key: os.environ/GEMINI_API_KEY"
        if marker in text:
            text = text.replace(marker, block + "\n" + marker, 1)
            added.append(alias)
    return text, added


def add_gpt56_fallbacks(text: str) -> str:
    fb_block = ""
    for alias, _, _ in GPT56:
        fb_block += f"""  - {alias}:
    - zai-glm-flash
    - groq-llama-31-8b
    - agl-primary-zai-glm-flash
    - agl-primary
"""
    if "gpt-5.6-sol:" in text and "  - gpt-5.6-sol:" not in text:
        marker = "  - gpt-5.5:"
        text = text.replace(marker, fb_block + marker, 1)
    return text


def annotate_gpt_primary(text: str) -> str:
    old = """  model_name: gpt
- litellm_params:
    api_key: os.environ/OPENAI_API_KEY
    model: openai/gpt-4o"""
    new = """    note: '""" + QUOTA_NOTE + """'
  model_name: gpt
- litellm_params:
    api_key: os.environ/OPENAI_API_KEY
    model: openai/gpt-4o"""
    # Only add note if not present
    if "model_name: gpt\n" in text and QUOTA_NOTE not in text.split("model_name: gpt")[0][-200:]:
        text = text.replace(
            "    output_cost_per_token: 1.5e-05\n  model_name: gpt\n",
            "    output_cost_per_token: 1.5e-05\n    note: '" + QUOTA_NOTE + "'\n  model_name: gpt\n",
            1,
        )
    return text


def main() -> int:
    text = CONFIG.read_text()
    text, remapped = remap_claude_blocks(text)
    text = fix_claude_fallbacks(text)
    text = strip_claude_refs_in_fallbacks(text)
    text, added = add_gpt56_entries(text)
    text = add_gpt56_fallbacks(text)
    text = annotate_gpt_primary(text)

    # Validate
    yaml.safe_load(text)

    CONFIG.write_text(text)
    print(f"Remapped Claude: {', '.join(remapped)}")
    print(f"Added GPT-5.6: {', '.join(added) or '(already present)'}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
