"""Testes patch prune DeepSeek/Gemini aliases."""
from __future__ import annotations

import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO / "scripts" / "litellm"))

from litellm_config_models import parse_model_list  # noqa: E402
from patch_config_prune_providers import patch_config  # noqa: E402


def test_removes_deepseek_and_gemini_models() -> None:
    src_path = REPO / "config" / "litellm" / "config.yaml.bak.prune-providers"
    if not src_path.is_file():
        src_path = REPO / "config" / "litellm" / "config.yaml"
    src = src_path.read_text(encoding="utf-8")
    out, removed = patch_config(src)
    names = {m.model_name for m in parse_model_list(out)}
    for gone in (
        "deepseek",
        "cursor-deepseek",
        "gemini",
        "gemini-lite",
        "gpt-4.4-mini",
        "qwen-coder",
    ):
        assert gone not in names, gone
    assert "deepseek" in removed
    assert "gemini" in removed


def test_ollama_qwen3_4b_repoints_to_gemma4_qat() -> None:
    src_path = REPO / "config" / "litellm" / "config.yaml.bak.prune-providers"
    if not src_path.is_file():
        src_path = REPO / "config" / "litellm" / "config.yaml"
    src = src_path.read_text(encoding="utf-8")
    out, _ = patch_config(src)
    assert out.count("model: ollama/qwen3:4b") == 0
    assert "model_name: ollama-qwen3-4b" in out
    idx = out.index("model_name: ollama-qwen3-4b")
    block = out[max(0, idx - 400): idx + 20]
    assert "model: ollama/gemma4-qat" in block


def test_keeps_openrouter_gemini_free_alias() -> None:
    src_path = REPO / "config" / "litellm" / "config.yaml.bak.prune-providers"
    if not src_path.is_file():
        src_path = REPO / "config" / "litellm" / "config.yaml"
    src = src_path.read_text(encoding="utf-8")
    out, _ = patch_config(src)
    assert "model_name: openrouter/google/gemini-2.5-flash-lite:free" in out


def test_removes_orphan_fallback_keys() -> None:
    src_path = REPO / "config" / "litellm" / "config.yaml.bak.prune-providers"
    if not src_path.is_file():
        src_path = REPO / "config" / "litellm" / "config.yaml"
    src = src_path.read_text(encoding="utf-8")
    out, _ = patch_config(src)
    for orphan in ("- deepseek:", "- deepseek-4:", "- gemini-lite:", "- r1:", "- gemini:"):
        assert orphan not in out, orphan
    assert "deepseek" not in out or "model_name: deepseek" not in out
