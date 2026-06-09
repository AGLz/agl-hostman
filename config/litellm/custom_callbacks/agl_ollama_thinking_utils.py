"""Helpers Ollama thinking — sem dependência LiteLLM (testável offline)."""
from __future__ import annotations

import re
from typing import Any, Optional

_OLLAMA_ALIAS_PATTERN = re.compile(
    r"(^|/)(agl-primary|ollama-qwen|ollama-llama|ollama-mistral|ollama-gemma|ollama-deepseek|openai/ollama-)",
    re.I,
)

_OLLAMA_THINKING_ALIAS_PATTERN = re.compile(
    r"(^|/)(agl-primary|ollama-qwen|ollama-deepseek|openai/ollama-qwen|openai/ollama-deepseek)",
    re.I,
)


def is_ollama_route(model: Optional[str], data: dict) -> bool:
    slug = str(model or "").strip()
    if slug.startswith("ollama/") or slug.startswith("ollama_chat/"):
        return True
    if _OLLAMA_ALIAS_PATTERN.search(slug):
        return True
    api_base = str(data.get("api_base") or "")
    if ":11434" in api_base:
        return True
    deployment = str(data.get("litellm_metadata", {}).get("deployment", ""))
    if "ollama" in deployment.lower():
        return True
    return False


def ollama_backend_slug(model: Optional[str], data: dict) -> str:
    slug = str(model or "")
    deployment = str(data.get("litellm_metadata", {}).get("deployment", ""))
    for candidate in (slug, deployment):
        if "ollama/" in candidate:
            return candidate.split("ollama/", 1)[-1]
        if "ollama_chat/" in candidate:
            return candidate.split("ollama_chat/", 1)[-1]
    return slug


def ollama_uses_thinking(model: Optional[str], data: dict) -> bool:
    slug = str(model or "")
    if _OLLAMA_THINKING_ALIAS_PATTERN.search(slug):
        return True
    backend = ollama_backend_slug(model, data)
    return bool(re.search(r"(qwen3|deepseek-r1)", backend, re.I))


def normalize_ollama_message_content(message: Any) -> None:
    if message is None:
        return
    content = getattr(message, "content", None)
    reasoning = getattr(message, "reasoning_content", None)
    if content and str(content).strip():
        return
    if reasoning and str(reasoning).strip():
        message.content = str(reasoning).strip()
