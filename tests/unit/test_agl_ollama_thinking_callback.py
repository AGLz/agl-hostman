"""Testes unitários — helpers Ollama thinking (offline)."""
from __future__ import annotations

import importlib.util
from pathlib import Path

import pytest

_MODULE = Path(__file__).resolve(
).parents[2] / "config/litellm/custom_callbacks/agl_ollama_thinking_utils.py"
_spec = importlib.util.spec_from_file_location(
    "agl_ollama_thinking_utils", _MODULE)
_mod = importlib.util.module_from_spec(_spec)
assert _spec.loader is not None
_spec.loader.exec_module(_mod)


@pytest.mark.parametrize(
    ("model", "data", "expected"),
    [
        ("agl-primary", {"api_base": "http://100.67.253.52:11434"}, True),
        ("ollama-qwen3-8b", {}, True),
        ("ollama/llama3.1:8b", {}, True),
        ("gpt-5.4-mini", {}, False),
    ],
)
def test_is_ollama_route(model: str, data: dict, expected: bool) -> None:
    assert _mod.is_ollama_route(model, data) is expected


@pytest.mark.parametrize(
    ("model", "data", "expected"),
    [
        ("agl-primary", {}, True),
        ("ollama-qwen3-4b-fast", {}, True),
        ("ollama-llama31-8b",
         {"litellm_metadata": {"deployment": "ollama/llama3.1:8b"}}, False),
        ("ollama-gemma3-4b",
         {"litellm_metadata": {"deployment": "ollama/gemma3:4b"}}, False),
    ],
)
def test_ollama_uses_thinking(model: str, data: dict, expected: bool) -> None:
    assert _mod.ollama_uses_thinking(model, data) is expected


def test_normalize_empty_content_from_reasoning() -> None:
    class Msg:
        content = ""
        reasoning_content = "Resposta final aqui."

    msg = Msg()
    _mod.normalize_ollama_message_content(msg)
    assert msg.content == "Resposta final aqui."
