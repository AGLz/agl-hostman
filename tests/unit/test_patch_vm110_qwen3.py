"""Testes patch_config_vm110_qwen3."""
from __future__ import annotations

import subprocess
import sys
from pathlib import Path

import pytest

REPO = Path(__file__).resolve().parents[2]
PATCH = REPO / "scripts/litellm/patch_config_vm110_qwen3.py"
CONFIG = REPO / "config/litellm/config.yaml"


def test_patch_vm110_qwen3_replaces_agl_primary(tmp_path: Path) -> None:
    src = CONFIG.read_text(encoding="utf-8")
    out = tmp_path / "out.yaml"
    env = {"VM110_OLLAMA_BASE": "http://100.74.118.51:11434"}
    subprocess.run(
        [sys.executable, str(PATCH), str(CONFIG), str(out)],
        check=True,
        env={**dict(__import__("os").environ), **env},
    )
    text = out.read_text(encoding="utf-8")
    assert "100.74.118.51:11434" in text
    assert "model: ollama/qwen3:4b" in text
    assert "model_name: agl-primary" in text
    assert "VM110 Ollama" in text
    assert "100.67.253.52" not in text
