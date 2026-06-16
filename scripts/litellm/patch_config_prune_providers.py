#!/usr/bin/env python3
"""Remove aliases DeepSeek/Gemini (sem saldo/key) e corrige Ollama qwen3:4b legado."""
from __future__ import annotations

import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
DEFAULT_CONFIG = REPO / "config" / "litellm" / "config.yaml"

REMOVE_MODEL_NAMES = frozenset({
    "deepseek",
    "r1",
    "deepseek-v3.2",
    "deepseek-v4-flash",
    "deepseek-v4-pro",
    "deepseek-4",
    "cursor-deepseek",
    "qwen-coder",
    "openai/qwen3-coder-plus",
    "qwen/qwen-coder",
    "gemini",
    "gemini-3.1-pro",
    "gemini-2.5-pro",
    "gemini-lite",
    "gemini-2.0",
    "google/gemini-2.5-flash-lite",
    "google/gemini-2.5-flash-lite:free",
    "google/gemini-2.5-flash",
    "gpt-4.4-mini",
})

REMOVE_FALLBACK_KEYS = REMOVE_MODEL_NAMES | frozenset({
    "openai/qwen3-coder-plus",
})

REMOVE_FALLBACK_TARGETS = frozenset({
    "deepseek",
    "cursor-deepseek",
    "gemini",
    "gemini-lite",
    "gemini-3.1-pro",
    "gemini-2.5-pro",
    "gemini-2.0",
    "google/gemini-2.5-flash-lite",
    "google/gemini-2.5-flash-lite:free",
    "google/gemini-2.5-flash",
    "openrouter/google/gemini-2.5-flash-lite:free",
})

OLLAMA_LEGACY_NOTE = "Alias legado → VM310 gemma4-qat :11434 (substitui qwen3:4b)"


def _extract_model_name(block: str) -> str | None:
    for pattern in (
        r"^\s+- model_name:\s*(.+)$",
        r"^\s+model_name:\s*(.+)$",
    ):
        match = re.search(pattern, block, re.MULTILINE)
        if match:
            raw = match.group(1).strip()
            if raw.startswith('"') and raw.endswith('"'):
                return raw[1:-1]
            return raw
    return None


def _line_indent(line: str) -> int:
    return len(line) - len(line.lstrip(" "))


def _is_nested_fallback_entry(line: str, parent_indent: int) -> bool:
    if not re.match(r"^\s+- ", line):
        return False
    return _line_indent(line) > parent_indent


def remove_model_blocks(text: str) -> tuple[str, list[str]]:
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
        if name and name in REMOVE_MODEL_NAMES:
            removed.append(name)
            continue
        if name and name in {
            "ollama-qwen3-4b",
            "openai/ollama-qwen3-4b",
            "ollama-qwen3-4b-fast",
        }:
            block = block.replace("model: ollama/qwen3:4b", "model: ollama/gemma4-qat")
            block = re.sub(
                r'note: "[^"]*qwen3:4b[^"]*"',
                f'note: "{OLLAMA_LEGACY_NOTE}"',
                block,
            )
        kept.append(block)
    body = "\n".join(kept)
    if body and not body.startswith("\n"):
        body = "\n" + body
    return prefix + head + body, removed


def _clean_fallback_targets(lines: list[str]) -> list[str]:
    out: list[str] = []
    i = 0
    while i < len(lines):
        line = lines[i]
        key_match = re.match(r"^(\s+)- ([^:]+):\s*$", line)
        next_is_child = (
            i + 1 < len(lines)
            and _is_nested_fallback_entry(lines[i + 1], _line_indent(line))
        )
        if key_match and next_is_child:
            key = key_match.group(2).strip().strip('"')
            if key in REMOVE_FALLBACK_KEYS:
                key_indent = _line_indent(line)
                i += 1
                while i < len(lines) and _is_nested_fallback_entry(lines[i], key_indent):
                    i += 1
                continue
            out.append(line)
            key_indent = _line_indent(line)
            i += 1
            while i < len(lines) and _is_nested_fallback_entry(lines[i], key_indent):
                target = lines[i].split("-", 1)[1].strip()
                if target not in REMOVE_FALLBACK_TARGETS:
                    out.append(lines[i])
                i += 1
            continue
        if line.strip().startswith("- ") and not line.strip().startswith("- litellm"):
            target = line.split("-", 1)[1].strip()
            if target in REMOVE_FALLBACK_TARGETS:
                i += 1
                continue
        out.append(line)
        i += 1
    return out


def _clean_inline_fallback_arrays(text: str) -> str:
    """config-remote.yaml: `- alias: [a, b, deepseek]` em uma linha."""

    def repl_line(line: str) -> str | None:
        match = re.match(r"^(\s+)- ([^:]+):\s*\[(.*)\]\s*$", line)
        if not match:
            return line
        key = match.group(2).strip().strip('"')
        if key in REMOVE_FALLBACK_KEYS:
            return None
        targets = [t.strip().strip('"') for t in match.group(3).split(",") if t.strip()]
        kept = [t for t in targets if t not in REMOVE_FALLBACK_TARGETS]
        if not kept:
            return None
        inner = ", ".join(kept)
        return f"{match.group(1)}- {match.group(2)}: [{inner}]"

    lines = text.splitlines(keepends=True)
    out: list[str] = []
    for line in lines:
        cleaned = repl_line(line.rstrip("\n"))
        if cleaned is not None:
            out.append(cleaned + ("\n" if line.endswith("\n") else ""))
    return "".join(out)


def clean_fallback_sections(text: str) -> str:
    markers = [
        "  context_window_fallbacks:",
        "  fallbacks:",
    ]
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
        body = _clean_fallback_targets(lines[1:])
        text = before + header + "".join(body) + after
    return text


def update_header_comments(text: str) -> str:
    insert = (
        "# DeepSeek + Gemini (Google API): aliases REMOVIDOS 2026-06-15 (402 sem saldo / 401 key inválida).\n"
        "# qwen-coder → removido (era DeepSeek). Ollama qwen3:4b* → gemma4-qat @ :11434.\n"
    )
    if "DeepSeek + Gemini (Google API): aliases REMOVIDOS" not in text:
        text = text.replace(
            "# VM310 Ollama dual-GPU",
            insert + "# VM310 Ollama dual-GPU",
            1,
        )
    text = re.sub(
        r"# Política de routing \(2026-06\): \*\*paid → local → free\*\*\. Subscrições/API: Anthropic, OpenAI, Z\.AI \(incl\. Coding Plan\), DeepSeek, Kimi, Gemini\.",
        "# Política de routing (2026-06): **paid → local → free**. Subscrições/API: Anthropic, OpenAI, Z.AI (incl. Coding Plan), Kimi.",
        text,
    )
    return text


def patch_config(text: str) -> tuple[str, list[str]]:
    text = update_header_comments(text)
    text = clean_fallback_sections(text)
    if re.search(r"^\s+- [^:]+:\s*\[", text, re.MULTILINE):
        text = _clean_inline_fallback_arrays(text)
    text, removed = remove_model_blocks(text)
    return text, removed


def main() -> int:
    paths = [Path(p) for p in sys.argv[1:]] if len(sys.argv) > 1 else [DEFAULT_CONFIG]
    exit_code = 0
    for path in paths:
        src = path.read_text(encoding="utf-8")
        out, removed = patch_config(src)
        if out == src:
            print(f"{path}: nenhuma alteração")
            continue
        backup = path.with_suffix(path.suffix + ".bak.prune-providers")
        if not backup.is_file():
            backup.write_text(src, encoding="utf-8")
        path.write_text(out, encoding="utf-8")
        print(f"{path}: backup {backup}")
        print(f"{path}: removidos ({len(removed)}): {', '.join(sorted(removed))}")
    return exit_code


if __name__ == "__main__":
    raise SystemExit(main())
