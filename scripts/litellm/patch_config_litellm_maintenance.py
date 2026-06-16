#!/usr/bin/env python3
"""Manutenção LiteLLM: remove cursor*, corrige rotas Z.AI/Groq."""
from __future__ import annotations

import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
DEFAULT_CONFIG = REPO / "config" / "litellm" / "config.yaml"

from patch_config_prune_providers import (  # noqa: E402
    _clean_fallback_targets,
    _extract_model_name,
    clean_fallback_sections,
    remove_model_blocks,
)

CURSOR_PREFIX = "cursor-"

CURSOR_FALLBACK_TARGETS = frozenset({
    "cursor-composer",
    "cursor-composer-2-fast",
    "cursor-claude-sonnet",
    "cursor-claude-opus",
    "cursor-claude-opus-4-6",
    "cursor-glm-5",
    "cursor-deepseek",
})

ZAI_OPENAI_FLASH_ROUTE = """      api_base: https://api.z.ai/api/openai/v1
      api_key: os.environ/ZAI_API_KEY
      model: openai/glm-4.7-flash
      max_tokens: 1024
      timeout: 30"""

ZAI_ANTHROPIC_FLASH_ROUTE = """      api_base: https://api.z.ai/api/anthropic
      api_key: os.environ/ZAI_API_KEY
      model: anthropic/glm-4.5-flash
      max_tokens: 512
      timeout: 90"""

ZAI_OPENAI_GLM47_ROUTE = """      api_base: https://api.z.ai/api/openai/v1
      api_key: os.environ/ZAI_API_KEY
      model: openai/glm-4.7
      timeout: 90"""

ZAI_NATIVE_GLM47_ROUTE = """      api_key: os.environ/ZAI_API_KEY
      model: zai/glm-4.7
      max_tokens: 512
      timeout: 90"""

ZAI_CODING_OPENAI_GLM47 = """      api_base: https://api.z.ai/api/coding/paas/v4
      api_key: os.environ/ZAI_API_KEY
      model: openai/glm-4.7"""

ZAI_CODING_GLM47 = """      api_base: https://api.z.ai/api/coding/paas/v4
      api_key: os.environ/ZAI_API_KEY
      model: glm-4.7"""

GLM47_ANTHROPIC_BLOCK = """  - litellm_params:
      api_base: https://api.z.ai/api/anthropic
      api_key: os.environ/ZAI_API_KEY
      model: anthropic/glm-4.5-flash
      max_tokens: 512
      timeout: 90
    model_info:
      access: direct
      context_window: 203000
      input_cost_per_token: 6.0e-07
      max_tokens: 8192
      output_cost_per_token: 2.2e-06
    model_name: glm-4.7
"""

GLM47_NATIVE_BLOCK = """  - litellm_params:
      api_key: os.environ/ZAI_API_KEY
      model: zai/glm-4.7
      max_tokens: 512
      timeout: 90
    model_info:
      access: direct
      context_window: 203000
      input_cost_per_token: 6.0e-07
      max_tokens: 8192
      output_cost_per_token: 2.2e-06
    model_name: glm-4.7
"""


def _is_cursor_model(name: str | None) -> bool:
    return bool(name and name.startswith(CURSOR_PREFIX))


def remove_cursor_models(text: str) -> tuple[str, list[str]]:
    start = text.find("model_list:")
    if start < 0:
        return text, []
    prefix = text[:start]
    section = text[start:]
    split_pattern = (
        r"\n(?=\s+- model_name:)"
        if re.search(r"\n\s+- model_name:", section)
        else r"\n(?=\s+- litellm_params:)"
    )
    chunks = re.split(split_pattern, section)
    head, *blocks = chunks
    kept: list[str] = []
    removed: list[str] = []
    for block in blocks:
        name = _extract_model_name(block)
        if _is_cursor_model(name):
            removed.append(name or "?")
            continue
        kept.append(block)
    body = "\n".join(kept)
    if body and not body.startswith("\n"):
        body = "\n" + body
    return prefix + head + body, removed


def _clean_fallback_targets_with_cursor(lines: list[str]) -> list[str]:
    out: list[str] = []
    i = 0
    while i < len(lines):
        line = lines[i]
        key_match = re.match(r"^(\s+)- ([^:]+):\s*$", line)
        next_is_child = (
            i + 1 < len(lines)
            and len(lines[i + 1]) - len(lines[i + 1].lstrip(" ")) > len(line) - len(line.lstrip(" "))
            and re.match(r"^\s+- ", lines[i + 1])
        )
        if key_match and next_is_child:
            key = key_match.group(2).strip().strip('"')
            if key.startswith(CURSOR_PREFIX):
                key_indent = len(line) - len(line.lstrip(" "))
                i += 1
                while i < len(lines) and (len(lines[i]) - len(lines[i].lstrip(" "))) > key_indent:
                    i += 1
                continue
            out.append(line)
            key_indent = len(line) - len(line.lstrip(" "))
            i += 1
            while i < len(lines) and (len(lines[i]) - len(lines[i].lstrip(" "))) > key_indent:
                target = lines[i].split("-", 1)[1].strip()
                if target not in CURSOR_FALLBACK_TARGETS:
                    out.append(lines[i])
                i += 1
            continue
        if line.strip().startswith("- ") and not line.strip().startswith("- litellm"):
            target = line.split("-", 1)[1].strip()
            if target in CURSOR_FALLBACK_TARGETS:
                i += 1
                continue
        out.append(line)
        i += 1
    return out


def clean_cursor_fallbacks(text: str) -> str:
    markers = ["  context_window_fallbacks:", "  fallbacks:"]
    for section in markers:
        start = text.find(section)
        if start < 0:
            continue
        end = text.find("\nmodel_list:", start)
        if end < 0:
            end = len(text)
        before = text[:start]
        chunk = text[start:end]
        after = text[end:]
        lines = chunk.splitlines(keepends=True)
        if not lines:
            continue
        header = lines[0]
        body = _clean_fallback_targets_with_cursor(lines[1:])
        text = before + header + "".join(body) + after

    def strip_cursor_targets_from_line(line: str) -> str | None:
        match = re.match(r"^(\s+)- ([^:]+):\s*\[(.*)\]\s*$", line)
        if not match:
            return line
        key = match.group(2).strip().strip('"')
        if key.startswith(CURSOR_PREFIX):
            return None
        targets = [t.strip().strip('"') for t in match.group(3).split(",") if t.strip()]
        kept = [t for t in targets if t not in CURSOR_FALLBACK_TARGETS]
        if not kept:
            return None
        return f"{match.group(1)}- {match.group(2)}: [{', '.join(kept)}]"

    out_lines: list[str] = []
    for line in text.splitlines(keepends=True):
        cleaned = strip_cursor_targets_from_line(line.rstrip("\n"))
        if cleaned is not None:
            out_lines.append(cleaned + ("\n" if line.endswith("\n") else ""))
    return "".join(out_lines)


def fix_zai_and_groq_routes(text: str) -> str:
    text = text.replace(ZAI_OPENAI_FLASH_ROUTE, ZAI_ANTHROPIC_FLASH_ROUTE)
    text = text.replace(ZAI_OPENAI_GLM47_ROUTE, ZAI_NATIVE_GLM47_ROUTE)
    text = text.replace(ZAI_CODING_OPENAI_GLM47, ZAI_CODING_GLM47)
    text = text.replace(GLM47_ANTHROPIC_BLOCK, GLM47_NATIVE_BLOCK)
    text = text.replace(
        "      model: groq/openai/gpt-oss-120b\n      timeout: 120",
        "      model: groq/openai/gpt-oss-120b\n      reasoning_effort: low\n      timeout: 120",
    )
    return text


def patch_config(text: str) -> tuple[str, list[str]]:
    text = clean_cursor_fallbacks(text)
    text = fix_zai_and_groq_routes(text)
    text, cursor_removed = remove_cursor_models(text)
    return text, cursor_removed


def main() -> int:
    path = Path(sys.argv[1]) if len(sys.argv) > 1 else DEFAULT_CONFIG
    src = path.read_text(encoding="utf-8")
    out, removed = patch_config(src)
    if out == src:
        print(f"{path}: nenhuma alteração")
        return 0
    backup = path.with_suffix(path.suffix + ".bak.maintenance")
    if not backup.is_file():
        backup.write_text(src, encoding="utf-8")
    path.write_text(out, encoding="utf-8")
    print(f"{path}: backup {backup}")
    print(f"Removidos cursor ({len(removed)}): {', '.join(sorted(removed))}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
