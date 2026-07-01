"""Testes patch-litellm-zero-openrouter.py"""
from __future__ import annotations

import importlib.util
from pathlib import Path

import yaml

REPO = Path(__file__).resolve().parents[2]
PATCH = REPO / "scripts" / "litellm" / "patch-litellm-zero-openrouter.py"


def _load():
    spec = importlib.util.spec_from_file_location("patch_zor", PATCH)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def test_remaps_or_and_strips_paid() -> None:
    mod = _load()
    chain = mod._clean_chain(
        ["or-owl-alpha", "or-nemotron-super", "groq-llama-31-8b"]
    )
    assert "or-owl-alpha" not in chain
    assert "or-nemotron-super" not in chain
    assert "groq-llama-31-8b" in chain
    assert "agl-primary" in chain


def test_agl_sensitive_no_openrouter(tmp_path) -> None:
    mod = _load()
    cfg = yaml.safe_load(
        (REPO / "config" / "litellm" / "config.yaml").read_text())
    mod._patch_agl_sensitive(cfg)
    sens = next(m for m in cfg["model_list"] if m.get(
        "model_name") == "agl-sensitive")
    assert "openrouter" not in str(sens["litellm_params"].get("model", ""))
    assert "ZAI_API_KEY" in sens["litellm_params"]["api_key"]


def test_model_list_or_redirected() -> None:
    mod = _load()
    cfg = yaml.safe_load(
        (REPO / "config" / "litellm" / "config.yaml").read_text())
    mod.patch(cfg)
    for block in cfg.get("model_list") or []:
        name = str(block.get("model_name") or "")
        if not name.startswith("or-"):
            continue
        lp = block.get("litellm_params") or {}
        assert "openrouter" not in str(lp.get("model", "")), name


def test_drop_params_global() -> None:
    mod = _load()
    cfg = yaml.safe_load(
        (REPO / "config" / "litellm" / "config.yaml").read_text())
    out = mod.patch(cfg)
    assert out["litellm_settings"].get("drop_params") is True
