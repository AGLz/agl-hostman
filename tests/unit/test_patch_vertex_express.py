"""Testes patch_config_vertex_express."""
from __future__ import annotations

import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO / "scripts" / "litellm"))

from patch_config_vertex_express import patch_config  # noqa: E402


def test_migrates_gemini_to_vertex_express() -> None:
    sample = """
model_list:
  - litellm_params:
      api_key: os.environ/GEMINI_API_KEY
      model: gemini/gemini-2.5-flash-lite
    model_name: gemini-lite
"""
    out, names = patch_config(sample)
    assert names == ["gemini-lite"]
    assert "gemini/gemini-2.5-flash-lite" in out
    assert "api_base: https://aiplatform.googleapis.com/v1/publishers/google" in out
    assert "vertex_project:" not in out
    assert "model: vertex_ai/" not in out


def test_migrates_vertex_ai_prefix_back_to_gemini() -> None:
    sample = """
model_list:
  - litellm_params:
      api_key: os.environ/GEMINI_API_KEY
      api_base: https://aiplatform.googleapis.com
      vertex_location: os.environ/VERTEXAI_LOCATION
      vertex_project: os.environ/VERTEXAI_PROJECT
      model: vertex_ai/gemini-2.5-flash-lite
    model_name: gemini-lite
"""
    out, names = patch_config(sample)
    assert names == ["gemini-lite"]
    assert "gemini/gemini-2.5-flash-lite" in out
    assert "model: vertex_ai/" not in out
    assert "vertex_project:" not in out


def test_config_yaml_has_vertex_express_gemini() -> None:
    text = (REPO / "config" / "litellm" / "config.yaml").read_text(encoding="utf-8")
    assert "gemini/gemini-2.5-flash-lite" in text
    assert "api_base: https://aiplatform.googleapis.com/v1/publishers/google" in text
    assert "vertex_ai/gemini-" not in text
