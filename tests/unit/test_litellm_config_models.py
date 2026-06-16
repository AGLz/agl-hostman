"""Testes litellm_config_models — descoberta de modelos para benchmarks."""
from __future__ import annotations

import os
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO / "scripts" / "litellm"))

from litellm_config_models import (  # noqa: E402
    build_battery_manifest,
    infer_provider,
    infer_tier,
    load_models,
    parse_model_list,
)


def test_parse_model_list_includes_core_providers() -> None:
    text = (REPO / "config" / "litellm" /
            "config.yaml").read_text(encoding="utf-8")
    models = parse_model_list(text)
    names = {m.model_name for m in models}
    assert "agl-primary" in names
    assert "groq-llama-31-8b" in names
    assert "claude-sonnet" in names
    assert "openrouter-free" in names
    assert len(models) >= 75


def test_infer_provider_openrouter_free_alias() -> None:
    assert (
        infer_provider(
            "openrouter/openrouter/free",
            "",
            "os.environ/OPENROUTER_API_KEY",
            "openrouter-free",
        )
        == "openrouter"
    )

    assert infer_provider(
        "gemini/gemini-2.5-flash-lite",
        "https://aiplatform.googleapis.com/v1/publishers/google",
        "os.environ/GEMINI_API_KEY",
        "gemini-lite",
    ) == "google"

    assert infer_provider(
        "ollama/gemma4-qat", "http://100.67.253.52:11434", "ollama", "agl-primary") == "ollama"
    assert infer_provider("groq/llama-3.1-8b-instant", "",
                          "os.environ/GROQ_API_KEY", "groq-llama-31-8b") == "groq"


def test_infer_tier_local_and_free() -> None:
    assert infer_tier("ollama", True, "agl-primary",
                      "ollama/gemma4-qat") == "local"
    assert infer_tier("groq", True, "groq-llama-31-8b", "groq/x") == "free"
    assert infer_tier("anthropic", False, "claude-sonnet",
                      "anthropic/x") == "paid"


def test_load_models_filters_by_provider() -> None:
    models = load_models(require_keys=False, providers={"groq"})
    assert models
    assert all(m.provider == "groq" for m in models)


def test_load_models_skips_infra_agent() -> None:
    models = load_models(require_keys=False)
    assert "infra-agent" not in {m.model_name for m in models}


def test_load_models_require_keys_respects_env(monkeypatch) -> None:
    monkeypatch.delenv("GROQ_API_KEY", raising=False)
    monkeypatch.delenv("GROQ_API_KEY2", raising=False)
    groq = load_models(require_keys=True, providers={"groq"})
    assert groq == []
    monkeypatch.setenv("GROQ_API_KEY", "gsk-test")
    groq = load_models(require_keys=True, providers={"groq"})
    assert len(groq) >= 2


def test_build_battery_manifest_has_unique_ids() -> None:
    manifest = build_battery_manifest(require_keys=False)
    ids = [row["id"] for row in manifest["models"]]
    assert len(ids) == len(set(ids))
    providers = set(manifest["providers"])
    assert "groq" in providers
    assert "openrouter" in providers
    assert "anthropic" in providers
    assert "openai" in providers
    assert "zai" in providers
    assert "ollama" in providers
