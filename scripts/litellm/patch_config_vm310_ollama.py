#!/usr/bin/env python3
"""Patch LiteLLM config.yaml — Ollama dual: VM310 (ctx longo) + VM110 (failover AGLSRV1)."""
from __future__ import annotations

import os
import re
import sys
from pathlib import Path

VM310_GPU0 = os.environ.get("VM310_OLLAMA_GPU0", "http://100.67.253.52:11434")
VM310_GPU1 = os.environ.get("VM310_OLLAMA_GPU1", "http://100.67.253.52:11435")
VM110_BASE = os.environ.get("VM110_OLLAMA_BASE", "http://100.74.118.51:11434")

# Contexto alvo (tunable via env antes de deploy; validar com tune-vm310-ollama-context.sh)
CTX_PRIMARY = int(os.environ.get("VM310_AGL_PRIMARY_CTX", "32768"))
CTX_STRONG = int(os.environ.get("VM310_AGL_PRIMARY_STRONG_CTX", "16384"))
CTX_FAST = int(os.environ.get("VM310_AGL_PRIMARY_FAST_CTX", "8192"))
CTX_VM110 = int(os.environ.get("VM110_AGL_PRIMARY_CTX", "8192"))
OUT_PRIMARY = int(os.environ.get("VM310_AGL_PRIMARY_MAX_OUT", "8192"))
TIMEOUT_LONG = int(os.environ.get("VM310_OLLAMA_TIMEOUT", "240"))
TIMEOUT_PRIMARY = int(os.environ.get("VM310_AGL_PRIMARY_TIMEOUT", "12"))
TIMEOUT_VM110 = int(os.environ.get("VM110_OLLAMA_TIMEOUT", "90"))

AGL_PRIMARY_FALLBACKS = [
    "agl-primary-vm110",
    "agl-primary-strong",
    "glm-4.7-flash",
    "groq-llama-31-8b",
    "zai-glm-flash",
    "or-nemotron-super-free",
]


def _block(
    model: str,
    api_base: str,
    note: str,
    *,
    ctx: int = 8192,
    timeout: int = 120,
    max_out: int = 8192,
    think: bool | None = None,
    num_ctx: int | None = None,
) -> str:
    think_line = f"\n      think: {'true' if think else 'false'}" if think is not None else ""
    nctx = num_ctx if num_ctx is not None else ctx
    extra = ""
    if nctx != ctx or nctx > 8192:
        extra = f"""
      extra_body:
        options:
          num_ctx: {nctx}"""
    return f"""  - litellm_params:
      api_base: {api_base}
      api_key: ollama
      model: {model}
      timeout: {timeout}
      stream: true
      max_tokens: {max_out}{think_line}{extra}
    model_info:
      access: direct
      context_window: {ctx}
      free_tier: true
      input_cost_per_token: 0
      max_tokens: {max_out}
      note: "{note}"
      output_cost_per_token: 0
"""


PATCHES: dict[str, str] = {
    # Primário local: modelo menor + contexto longo (qwen3:4b ~5GB VRAM → margem para KV 32k)
    "agl-primary": _block(
        "ollama/qwen3:4b",
        VM310_GPU0,
        "VM310 GPU0 — qwen3:4b ctx-long (primário local AGL)",
        ctx=CTX_PRIMARY,
        timeout=TIMEOUT_PRIMARY,
        max_out=OUT_PRIMARY,
        think=False,
        num_ctx=CTX_PRIMARY,
    ),
    "agl-primary-fast": _block(
        "ollama/gemma4-qat",
        VM310_GPU0,
        "VM310 GPU0 — gemma4-qat rápido (ctx curto)",
        ctx=CTX_FAST,
        timeout=120,
        max_out=4096,
    ),
    "agl-primary-strong": _block(
        "ollama/qwen3:8b",
        VM310_GPU1,
        "VM310 GPU1 — qwen3:8b ctx médio",
        ctx=CTX_STRONG,
        timeout=TIMEOUT_LONG,
        max_out=8192,
        think=False,
        num_ctx=CTX_STRONG,
    ),
    "agl-primary-vm110": _block(
        "ollama/qwen3:4b",
        VM110_BASE,
        "VM110 GTX 1650 — qwen3:4b (failover quando VM310 offline)",
        ctx=CTX_VM110,
        timeout=TIMEOUT_VM110,
        max_out=4096,
        think=False,
        num_ctx=CTX_VM110,
    ),
    "ollama-gemma4-qat": _block(
        "ollama/gemma4-qat",
        VM310_GPU0,
        "Alias → VM310 gemma4-qat :11434",
        ctx=CTX_FAST,
    ),
    "ollama-qwen3-8b": _block(
        "ollama/qwen3:8b",
        VM310_GPU1,
        "Alias → VM310 qwen3:8b :11435",
        ctx=CTX_STRONG,
        timeout=TIMEOUT_LONG,
        think=False,
        num_ctx=CTX_STRONG,
    ),
    "ollama-qwen3-4b-fast": _block(
        "ollama/qwen3:4b",
        VM310_GPU0,
        "Alias → VM310 qwen3:4b :11434",
        ctx=CTX_PRIMARY,
        timeout=TIMEOUT_LONG,
        think=False,
        num_ctx=CTX_PRIMARY,
    ),
    "ollama-qwen3-4b": _block(
        "ollama/qwen3:4b",
        VM310_GPU0,
        "Alias legado → VM310 qwen3:4b :11434",
        ctx=CTX_PRIMARY,
        timeout=TIMEOUT_LONG,
        think=False,
        num_ctx=CTX_PRIMARY,
    ),
    "openai/ollama-qwen3-4b": _block(
        "ollama/qwen3:4b",
        VM310_GPU0,
        "Alias OpenAI-compat → VM310 qwen3:4b",
        ctx=CTX_PRIMARY,
        timeout=TIMEOUT_LONG,
        think=False,
        num_ctx=CTX_PRIMARY,
    ),
    "ollama-llama31-8b": _block(
        "ollama/llama3.1:8b",
        VM310_GPU0,
        "Alias → VM310 llama3.1:8b :11434",
        ctx=CTX_FAST,
    ),
    "ollama-gemma3-4b": _block(
        "ollama/gemma4-qat",
        VM310_GPU0,
        "Alias legado gemma3 → VM310 gemma4-qat :11434",
        ctx=CTX_FAST,
    ),
}


def _insert_after_model(text: str, after: str, name: str, block: str) -> str:
    if re.search(rf"^\s+model_name:\s+{re.escape(name)}\s*$", text, re.MULTILINE):
        return text
    anchor = re.search(
        rf"^\s+model_name:\s+{re.escape(after)}\s*$", text, re.MULTILINE
    )
    if not anchor:
        raise SystemExit(f"anchor {after} não encontrado para inserir {name}")
    pos = text.find("\n", anchor.end()) + 1
    insert = block + f"    model_name: {name}\n"
    return text[:pos] + insert + text[pos:]


def _patch_agl_primary_fallbacks(text: str) -> str:
    chain_lines = "\n".join(f"        - {m}" for m in AGL_PRIMARY_FALLBACKS)
    replacement = f"    - agl-primary:\n{chain_lines}\n"
    pattern = re.compile(
        r"    - agl-primary:\n(?:        - .+\n)+",
        re.MULTILINE,
    )
    if not pattern.search(text):
        raise SystemExit("fallback agl-primary não encontrado")
    return pattern.sub(replacement, text, count=1)


def _insert_missing_model(text: str, name: str, block: str) -> str:
    if re.search(rf"^\s+model_name:\s+{re.escape(name)}\s*$", text, re.MULTILINE):
        return text
    # Inserir antes do primeiro openrouter / groq após blocos ollama
    anchor = re.search(
        r"^\s+model_name:\s+ollama-gemma4-qat\s*$", text, re.MULTILINE)
    if not anchor:
        raise SystemExit(
            f"anchor ollama-gemma4-qat não encontrado para inserir {name}")
    pos = text.find("\n", anchor.end()) + 1
    insert = block + f"    model_name: {name}\n"
    return text[:pos] + insert + text[pos:]


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


def patch_config(text: str) -> str:
    for optional in ("agl-primary-fast", "agl-primary-vm110"):
        if optional in PATCHES and not re.search(
            rf"^\s+model_name:\s+{re.escape(optional)}\s*$", text, re.MULTILINE
        ):
            anchor = "agl-primary-strong" if optional == "agl-primary-vm110" else "agl-primary"
            text = _insert_after_model(
                text, anchor, optional, PATCHES[optional])
    for name in PATCHES:
        if name in ("agl-primary-fast", "agl-primary-vm110"):
            continue
        if not re.search(rf"^\s+model_name:\s+{re.escape(name)}\s*$", text, re.MULTILINE):
            raise SystemExit(f"model_name não encontrado: {name}")
    text = _replace_model_blocks(text, PATCHES)
    text = _patch_agl_primary_fallbacks(text)
    header = (
        f"# Ollama dual: VM310 agl-primary qwen3:4b ctx={CTX_PRIMARY} @ {VM310_GPU0}; "
        f"VM110 agl-primary-vm110 ctx={CTX_VM110} @ {VM110_BASE}\n"
        "# Tune VM310: scripts/aglsrv3/tune-vm310-ollama-context.sh\n"
    )
    if text.startswith("#"):
        text = re.sub(r"^(?:#.*\n)+", header, text, count=1)
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
    print(
        f"OK: {dst} ({len(PATCHES)} modelos; VM310 ctx={CTX_PRIMARY}, VM110 ctx={CTX_VM110})"
    )


if __name__ == "__main__":
    main()
