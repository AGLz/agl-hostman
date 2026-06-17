#!/usr/bin/env python3
"""Patch LiteLLM config.yaml — VM310 dual-GPU Ollama (agl-primary + aliases)."""
from __future__ import annotations

import os
import re
import sys
from pathlib import Path

VM310_GPU0 = os.environ.get("VM310_OLLAMA_GPU0", "http://100.67.253.52:11434")
VM310_GPU1 = os.environ.get("VM310_OLLAMA_GPU1", "http://100.67.253.52:11435")


def _block(
    model: str,
    api_base: str,
    note: str,
    *,
    ctx: int = 8192,
    timeout: int = 120,
    think: bool | None = None,
) -> str:
    think_line = f"\n      think: {'true' if think else 'false'}" if think is not None else ""
    return f"""  - litellm_params:
      api_base: {api_base}
      api_key: ollama
      model: {model}
      timeout: {timeout}
      stream: true
      max_tokens: 8192{think_line}
    model_info:
      access: direct
      context_window: {ctx}
      free_tier: true
      input_cost_per_token: 0
      max_tokens: 8192
      note: "{note}"
      output_cost_per_token: 0
"""


PATCHES: dict[str, str] = {
    "agl-primary": _block(
        "ollama/gemma4-qat",
        VM310_GPU0,
        "VM310 GPU0 — gemma4-qat (primário local AGL)",
    ),
    "agl-primary-strong": _block(
        "ollama/qwen3:8b",
        VM310_GPU1,
        "VM310 GPU1 — qwen3:8b (secundário forte local)",
        think=False,
    ),
    "ollama-gemma4-qat": _block(
        "ollama/gemma4-qat",
        VM310_GPU0,
        "Alias → VM310 gemma4-qat :11434",
    ),
    "ollama-qwen3-8b": _block(
        "ollama/qwen3:8b",
        VM310_GPU1,
        "Alias → VM310 qwen3:8b :11435",
        think=False,
    ),
    "ollama-qwen3-4b-fast": _block(
        "ollama/qwen3:4b",
        VM310_GPU0,
        "Alias → VM310 qwen3:4b :11434",
        think=False,
    ),
    "ollama-qwen3-4b": _block(
        "ollama/qwen3:4b",
        VM310_GPU0,
        "Alias legado → VM310 qwen3:4b :11434",
        think=False,
    ),
    "openai/ollama-qwen3-4b": _block(
        "ollama/qwen3:4b",
        VM310_GPU0,
        "Alias OpenAI-compat → VM310 qwen3:4b",
        think=False,
    ),
    "ollama-llama31-8b": _block(
        "ollama/llama3.1:8b",
        VM310_GPU0,
        "Alias → VM310 llama3.1:8b :11434",
    ),
    "ollama-gemma3-4b": _block(
        "ollama/gemma4-qat",
        VM310_GPU0,
        "Alias legado gemma3 → VM310 gemma4-qat :11434",
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
                # type: ignore[union-attr]
                name_indent = re.match(r"^(\s+)", lines[i]).group(1)
            i += 1
        if model_name and model_name in patches:
            out.append(patches[model_name])
            out.append(f"{name_indent}model_name: {model_name}\n")
        else:
            out.extend(lines[block_start:i])
    return "".join(out)


def patch_config(text: str) -> str:
    for name in PATCHES:
        if not re.search(rf"^\s+model_name:\s+{re.escape(name)}\s*$", text, re.MULTILINE):
            raise SystemExit(f"model_name não encontrado: {name}")
    text = _replace_model_blocks(text, PATCHES)
    header = (
        f"# VM310 Ollama dual-GPU — agl-primary @ {VM310_GPU0}, agl-primary-strong @ {VM310_GPU1}\n"
        "# Fallbacks: Groq / Z.AI / OpenRouter após falha local. Ver docs/AGL-OLLAMA-VM310.md\n"
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
    print(f"OK: {dst} ({len(PATCHES)} modelos Ollama VM310)")


if __name__ == "__main__":
    main()
