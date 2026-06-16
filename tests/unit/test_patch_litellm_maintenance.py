"""Testes patch manutenção LiteLLM (cursor, Z.AI, Groq)."""
from __future__ import annotations

import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO / "scripts" / "litellm"))

from litellm_config_models import parse_model_list  # noqa: E402
from patch_config_litellm_maintenance import patch_config  # noqa: E402


def test_removes_cursor_models_and_fallbacks() -> None:
    src_path = REPO / "config" / "litellm" / "config.yaml.bak.maintenance"
    if not src_path.is_file():
        src_path = REPO / "config" / "litellm" / "config.yaml"
    src = src_path.read_text(encoding="utf-8")
    out, removed = patch_config(src)
    names = {m.model_name for m in parse_model_list(out)}
    for gone in removed:
        assert gone not in names
    assert "cursor-composer" in removed
    assert "cursor-composer" not in out
    assert "- cursor-composer:" not in out


def test_zai_glm47_uses_native_provider() -> None:
    src_path = REPO / "config" / "litellm" / "config.yaml.bak.maintenance"
    if not src_path.is_file():
        src_path = REPO / "config" / "litellm" / "config.yaml"
    out, _ = patch_config(src_path.read_text(encoding="utf-8"))
    idx = out.index("model_name: glm-4.7")
    block = out[max(0, idx - 400): idx + 20]
    assert "model: zai/glm-4.7" in block


def test_groq_oss_has_low_reasoning_effort() -> None:
    src_path = REPO / "config" / "litellm" / "config.yaml.bak.maintenance"
    if not src_path.is_file():
        src_path = REPO / "config" / "litellm" / "config.yaml"
    out, _ = patch_config(src_path.read_text(encoding="utf-8"))
    assert "model: groq/openai/gpt-oss-120b\n      reasoning_effort: low" in out
