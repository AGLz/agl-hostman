#!/usr/bin/env python3
"""Restaura aliases Gemini (Google API) no config.yaml a partir do backup prune."""
from __future__ import annotations

import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
DEFAULT_CONFIG = REPO / "config" / "litellm" / "config.yaml"
DEFAULT_BACKUP = REPO / "config" / "litellm" / "config.yaml.bak.prune-providers"

GEMINI_MODEL_NAMES = frozenset({
    "gemini",
    "gemini-3.1-pro",
    "gemini-2.5-pro",
    "gemini-lite",
    "gemini-2.0",
    "google/gemini-2.5-flash-lite",
    "google/gemini-2.5-flash-lite:free",
    "google/gemini-2.5-flash",
})

INSERT_MARKER = "    model_name: openrouter/google/gemini-2.5-flash-lite:free"


def _extract_model_name(block: str) -> str | None:
    match = re.search(r"^\s+model_name:\s*(.+)$", block, re.MULTILINE)
    if not match:
        return None
    raw = match.group(1).strip()
    if raw.startswith('"') and raw.endswith('"'):
        return raw[1:-1]
    return raw


def extract_gemini_blocks(backup_text: str) -> list[str]:
    start = backup_text.find("model_list:")
    if start < 0:
        return []
    section = backup_text[start:]
    chunks = re.split(r"\n(?=\s+- litellm_params:)", section)
    blocks: list[str] = []
    for block in chunks[1:]:
        name = _extract_model_name(block)
        if name and name in GEMINI_MODEL_NAMES:
            if not block.startswith("\n"):
                block = "\n" + block
            blocks.append(block)
    return blocks


def restore_gemini(config_text: str, backup_text: str) -> tuple[str, list[str]]:
    blocks = extract_gemini_blocks(backup_text)
    if not blocks:
        return config_text, []
    names = [_extract_model_name(b) or "?" for b in blocks]
    marker_idx = config_text.find(INSERT_MARKER)
    if marker_idx < 0:
        raise SystemExit(f"Marcador não encontrado: {INSERT_MARKER}")
    insert_at = config_text.rfind("\n  - litellm_params:", 0, marker_idx)
    if insert_at < 0:
        raise SystemExit(
            "Não foi possível localizar ponto de inserção antes do OpenRouter Gemini")
    payload = "".join(blocks)
    if not payload.endswith("\n"):
        payload += "\n"
    out = config_text[:insert_at] + payload + config_text[insert_at:]
    out = out.replace(
        "# DeepSeek + Gemini (Google API): aliases REMOVIDOS 2026-06-15 (402 sem saldo / 401 key inválida).\n",
        "# Gemini (Google API): restaurado após nova GEMINI_API_KEY em config/litellm/.env.\n",
    )
    return out, names


def main() -> int:
    config_path = Path(sys.argv[1]) if len(sys.argv) > 1 else DEFAULT_CONFIG
    backup_path = Path(sys.argv[2]) if len(sys.argv) > 2 else DEFAULT_BACKUP
    if not backup_path.is_file():
        raise SystemExit(f"Backup inexistente: {backup_path}")
    src = config_path.read_text(encoding="utf-8")
    backup = backup_path.read_text(encoding="utf-8")
    out, names = restore_gemini(src, backup)
    if out == src:
        print("Nenhuma alteração (Gemini já presente?)")
        return 0
    backup_out = config_path.with_suffix(
        config_path.suffix + ".bak.pre-gemini-restore")
    if not backup_out.is_file():
        backup_out.write_text(src, encoding="utf-8")
    config_path.write_text(out, encoding="utf-8")
    print(f"Restaurados ({len(names)}): {', '.join(names)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
