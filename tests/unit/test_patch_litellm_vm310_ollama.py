"""Testes patch LiteLLM VM310 Ollama."""
from __future__ import annotations

import os
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO / "scripts" / "litellm"))

from patch_config_vm310_ollama import patch_config  # noqa: E402


def test_patches_agl_primary_to_gemma4_qat() -> None:
    src = REPO / "config" / "litellm" / "config.yaml.bak.groq-failover"
    if not src.is_file():
        src = REPO / "config" / "litellm" / "config.yaml"
    os.environ["VM310_OLLAMA_GPU0"] = "http://100.67.253.52:11434"
    os.environ["VM310_OLLAMA_GPU1"] = "http://100.67.253.52:11435"
    out = patch_config(src.read_text(encoding="utf-8"))
    assert "http://100.67.253.52:11434" in out
    assert "http://100.67.253.52:11435" in out
    assert "model: ollama/gemma4-qat" in out
    assert "model: ollama/qwen3:8b" in out
    assert "model_name: agl-primary" in out
