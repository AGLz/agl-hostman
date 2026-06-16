#!/usr/bin/env python3
"""Patch LiteLLM config.yaml — VM110 Ollama (qwen3:4b único até Plan C / VM310)."""
from __future__ import annotations

import os
import re
import sys
from pathlib import Path

VM110_BASE = os.environ.get("VM110_OLLAMA_BASE", "http://100.74.118.51:11434")
QWEN = "ollama/qwen3:4b"


def _block(
    model: str,
    note: str,
    *,
    think: bool | None = None,
) -> str:
    think_line = f"\n      think: {'true' if think else 'false'}" if think is not None else ""
    return f"""  - litellm_params:
      api_base: {VM110_BASE}
      api_key: ollama
      model: {model}
      timeout: 120
      stream: true
      max_tokens: 8192{think_line}
    model_info:
      access: direct
      context_window: 8192
      free_tier: true
      input_cost_per_token: 0
      max_tokens: 8192
      note: "{note}"
      output_cost_per_token: 0
"""


PATCHES: dict[str, str] = {
    "agl-primary": _block(
        QWEN,
        "VM110 GTX 1650 — qwen3:4b (failover VM310 offline)",
        think=False,
    ),
    "agl-primary-strong": _block(
        QWEN,
        "VM110 — qwen3:4b (mesmo endpoint até VM310 GPU1)",
        think=False,
    ),
    "ollama-gemma4-qat": _block(
        QWEN,
        "Alias legado → VM110 qwen3:4b (gemma4-qat indisponível)",
        think=False,
    ),
    "ollama-qwen3-8b": _block(
        QWEN,
        "Alias → VM110 qwen3:4b",
        think=False,
    ),
    "ollama-qwen3-4b-fast": _block(
        QWEN,
        "Alias → VM110 qwen3:4b",
        think=False,
    ),
    "ollama-qwen3-4b": _block(
        QWEN,
        "Alias → VM110 qwen3:4b",
        think=False,
    ),
    "openai/ollama-qwen3-4b": _block(
        QWEN,
        "Alias OpenAI-compat → VM110 qwen3:4b",
        think=False,
    ),
    "ollama-llama31-8b": _block(
        QWEN,
        "Alias legado → VM110 qwen3:4b",
        think=False,
    ),
    "ollama-gemma3-4b": _block(
        QWEN,
        "Alias legado gemma3 → VM110 qwen3:4b",
        think=False,
    ),
}


def _replace_model_blocks(text: str, patches: dict[str, str]) -> str:
    lines = text.splitlines(keepends=True)
    out: list[str] = []
    i = 0
    block_re = re.compile(r"^\s+- litellm_params:")
    name_re = re.compile(r"^\s+model_name:\s+(\S+)")
    while i < len(lines):
        line = lines[i]
        if not block_re.match(line):
            out.append(line)
            i += 1
            continue
        block_start = i
        i += 1
        model_name: str | None = None
        name_indent = "    "
        while i < len(lines) and not block_re.match(lines[i]):
            m = name_re.match(lines[i])
            if m:
                model_name = m.group(1)
                name_indent = re.match(r"^(\s+)", lines[i]).group(1)
            i += 1
        if model_name and model_name in patches:
            out.append(patches[model_name])
            out.append(f"{name_indent}model_name: {model_name}\n")
        else:
            out.extend(lines[block_start:i])
    return "".join(out)


def _strip_routing_headers(text: str) -> str:
    skip_fragments = (
        "# VM310 Ollama",
        "# VM110 Ollama",
        "# VM110 Plan C",
        "# Aliases agl-primary",
        "# Restaurar:",
        "# Restaurar VM310",
        "# Fallbacks: Groq",
    )
    kept: list[str] = []
    for line in text.splitlines(keepends=True):
        if line.startswith("#") and any(frag in line for frag in skip_fragments):
            continue
        kept.append(line)
    return "".join(kept)


def patch_config(text: str) -> str:
    for name in PATCHES:
        if not re.search(rf"^\s+model_name:\s+{re.escape(name)}\s*$", text, re.MULTILINE):
            raise SystemExit(f"model_name não encontrado: {name}")
    text = _strip_routing_headers(text)
    text = _replace_model_blocks(text, PATCHES)
    header = (
        f"# VM110 Ollama — agl-primary / ollama-* @ {VM110_BASE} (qwen3:4b; VM310 offline)\n"
        "# Restaurar VM310: scripts/litellm/apply-litellm-vm310-ollama.sh\n"
    )
    if text.startswith("#"):
        text = re.sub(r"^#.*\n", header, text, count=1)
    else:
        text = header + text
    return text


def main() -> None:
    if len(sys.argv) != 3:
        print(f"Uso: {sys.argv[0]} <config.in> <config.out>", file=sys.stderr)
        raise SystemExit(2)
    src, dst = Path(sys.argv[1]), Path(sys.argv[2])
    out = patch_config(src.read_text(encoding="utf-8"))
    dst.write_text(out, encoding="utf-8")
    print(f"OK: {dst} ({len(PATCHES)} modelos → {VM110_BASE})")


if __name__ == "__main__":
    main()
