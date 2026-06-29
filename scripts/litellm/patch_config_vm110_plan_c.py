#!/usr/bin/env python3
"""Patch LiteLLM config.yaml — VM110 Plan C (Ollama local gemma4-qat).

Sem PyYAML: substitui blocos - litellm_params … model_name: <alias>.
"""
from __future__ import annotations

import os
import re
import sys
from pathlib import Path

VM110_BASE = os.environ.get("VM110_OLLAMA_BASE", "http://100.116.57.111:11434")


def _block(
    model: str,
    note: str,
    *,
    ctx: int = 8192,
) -> str:
    # Indentação alinhada ao model_list do config.yaml: "  - litellm_params:" (2 espaços),
    # chaves a 6 espaços, model_info a 4. model_name é acrescentado por _replace_model_blocks.
    return f"""  - litellm_params:
      api_base: {VM110_BASE}
      api_key: ollama
      model: {model}
      timeout: 120
      stream: true
      max_tokens: 8192
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
        "Plan C VM110 GTX 1650 — gemma4-qat QAT GGUF text-only (HF google/gemma-4-E2B-it-qat-q4_0-gguf)",
    ),
    "agl-primary-strong": _block(
        "ollama/qwen3:4b",
        "VM110 secundário — qwen3:4b (~3,2 GB VRAM); Groq 70B na cadeia de fallback",
    ),
    "ollama-gemma4-qat": _block(
        "ollama/gemma4-qat",
        "Alias → VM110 gemma4-qat Plan C",
    ),
    "ollama-qwen3-4b-fast": _block(
        "ollama/qwen3:4b",
        "Alias → VM110 qwen3:4b",
    ),
    "ollama-qwen3-4b": _block(
        "ollama/qwen3:4b",
        "Alias → VM110 qwen3:4b",
    ),
}


def _replace_model_blocks(text: str, patches: dict[str, str]) -> str:
    # Os itens do model_list usam indentação "  - litellm_params:" (2 espaços) e
    # "    model_name:" (4 espaços). O matcher tem de respeitar essa indentação.
    lines = text.splitlines(keepends=True)
    out: list[str] = []
    i = 0
    while i < len(lines):
        line = lines[i]
        if not line.startswith("  - litellm_params:"):
            out.append(line)
            i += 1
            continue

        block_start = i
        i += 1
        model_name: str | None = None
        while i < len(lines) and not lines[i].startswith("  - litellm_params:"):
            if lines[i].startswith("    model_name:"):
                model_name = lines[i].split(":", 1)[1].strip()
            i += 1

        if model_name and model_name in patches:
            out.append(patches[model_name])
            out.append(f"    model_name: {model_name}\n")
        else:
            out.extend(lines[block_start:i])
    return "".join(out)


def patch_config(text: str) -> str:
    for name in PATCHES:
        if f"  model_name: {name}\n" not in text and f"  model_name: {name}\r\n" not in text:
            raise SystemExit(f"model_name não encontrado: {name}")
    text = _replace_model_blocks(text, PATCHES)

    header = (
        "# VM110 Plan C — agl-primary / ollama-* → Ollama @ "
        f"{VM110_BASE} (Gemma4 QAT text-only). Reverter: scripts/litellm/restore-litellm-groq-failover.sh\n"
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
