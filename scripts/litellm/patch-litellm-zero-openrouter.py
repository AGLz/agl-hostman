#!/usr/bin/env python3
"""LiteLLM: zero OpenRouter — créditos esgotados (402 em free também).

- agl-sensitive deixa de usar OpenRouter → Z.AI glm-4.5-flash (alias estável)
- Fallbacks: remove aliases or-* / openrouter-* e paid or-* sem -free
- Substitui por groq-llama-31-8b, agl-primary-zai-glm-flash, agl-primary
- agl-primary-vm110 ganha fallback próprio (não terminal)
- drop_params: true (Ollama rejeita context_management)
"""
from __future__ import annotations

import sys
from pathlib import Path

import yaml

REPO = Path(__file__).resolve().parents[2]
DEFAULT = REPO / "config" / "litellm" / "config.yaml"

# ponytail: mapa estático; rever quando créditos OR repostos
OR_TO_LOCAL = {
    "or-nemotron-super-free": "groq-llama-31-8b",
    "or-nemotron-ultra-free": "zai-glm-flash",
    "or-owl-alpha": "zai-glm-flash",
    "or-qwen3-coder-free": "agl-primary-zai-glm-flash",
    "or-qwen3-next-free": "agl-primary-zai-glm-flash",
    "or-hermes-free": "groq-llama-31-8b",
    "or-llama-3.3-70b-free": "groq-llama-31-8b",
    "or-minimax-m2.5-free": "groq-llama-31-8b",
    "or-gemma-3-4b-free": "groq-llama-31-8b",
    "or-gemma-3-12b-free": "groq-llama-31-8b",
    "or-gemma-3-27b-free": "zai-glm-flash",
    "or-mistral-small-free": "groq-llama-31-8b",
    "openrouter-free": "zai-glm-flash",
    "openrouter/openrouter/free": "zai-glm-flash",
}

PAID_OR = frozenset(
    {
        "or-nemotron-super",
        "or-minimax-m2.5",
        "or-llama-3.3-70b",
        "or-gpt-4o-mini",
        "or-deepseek-v3",
        "or-gemma-3-27b",
    }
)


def _index_model_list(cfg: dict) -> dict[str, dict]:
    out: dict[str, dict] = {}
    for block in cfg.get("model_list") or []:
        if isinstance(block, dict) and block.get("model_name"):
            out[str(block["model_name"])] = block
    return out


def _patch_model_list_or_entries(cfg: dict) -> int:
    """Redirecciona aliases or-* / openrouter-* para backends locais (evita 402)."""
    import copy

    by_name = _index_model_list(cfg)
    patched = 0
    for block in cfg.get("model_list") or []:
        if not isinstance(block, dict):
            continue
        name = str(block.get("model_name") or "")
        if not _is_openrouter_alias(name) and not name.startswith("openrouter/"):
            lp = block.get("litellm_params") or {}
            if "openrouter" not in str(lp.get("model") or ""):
                continue
        target = _remap_target(name)
        if not target:
            target = "groq-llama-31-8b"
        ref = by_name.get(target)
        if not ref:
            continue
        block["litellm_params"] = copy.deepcopy(
            ref.get("litellm_params") or {})
        info = block.setdefault("model_info", {})
        info["access"] = "direct"
        info["note"] = (
            f"zero-openrouter: alias {name} → backend {target} "
            "(OR créditos esgotados; reverter quando repostos)"
        )
        patched += 1
    return patched


SAFE_TAIL = ("groq-llama-31-8b", "agl-primary-zai-glm-flash", "agl-primary")


def _is_openrouter_alias(name: str) -> bool:
    return name.startswith("or-") or name.startswith("openrouter")


def _remap_target(name: str) -> str | None:
    if name in PAID_OR:
        return None
    if name in OR_TO_LOCAL:
        return OR_TO_LOCAL[name]
    if _is_openrouter_alias(name):
        return "groq-llama-31-8b"
    return name


def _clean_chain(targets: list) -> list[str]:
    out: list[str] = []
    seen: set[str] = set()
    for raw in targets:
        mapped = _remap_target(str(raw))
        if not mapped or mapped in seen:
            continue
        seen.add(mapped)
        out.append(mapped)
    for tail in SAFE_TAIL:
        if tail not in seen:
            out.append(tail)
            seen.add(tail)
    return out


def _patch_fallback_sections(cfg: dict) -> None:
    ls = cfg.setdefault("litellm_settings", {})
    for key in ("fallbacks", "context_window_fallbacks"):
        sections = ls.get(key)
        if not isinstance(sections, list):
            continue
        for entry in sections:
            if not isinstance(entry, dict):
                continue
            for model, chain in list(entry.items()):
                if isinstance(chain, list):
                    entry[model] = _clean_chain(chain)


def _patch_agl_sensitive(cfg: dict) -> None:
    models = cfg.get("model_list") or []
    for block in models:
        if not isinstance(block, dict):
            continue
        if block.get("model_name") != "agl-sensitive":
            continue
        block["litellm_params"] = {
            "api_base": "https://api.z.ai/api/anthropic",
            "api_key": "os.environ/ZAI_API_KEY",
            "model": "anthropic/glm-4.5-flash",
            "max_tokens": 8192,
            "timeout": 90,
        }
        info = block.setdefault("model_info", {})
        info["access"] = "direct"
        info["free_tier"] = True
        info["data_policy"] = "zero-openrouter-zai-flash"
        info["note"] = (
            "OR créditos esgotados (2026-07): tier sensível via Z.AI flash, sem OpenRouter. "
            "Reverter para or-qwen3-coder:free ZDR quando créditos repostos."
        )
        return
    raise SystemExit("agl-sensitive não encontrado em model_list")


def _patch_ollama_drop_params(cfg: dict) -> None:
    for block in cfg.get("model_list") or []:
        if not isinstance(block, dict):
            continue
        lp = block.get("litellm_params") or {}
        model = str(lp.get("model") or "")
        if model.startswith("ollama/") or "11434" in str(lp.get("api_base") or ""):
            lp["drop_params"] = True
            block["litellm_params"] = lp


def patch(cfg: dict) -> dict:
    ls = cfg.setdefault("litellm_settings", {})
    ls["drop_params"] = True
    _patch_fallback_sections(cfg)
    _patch_agl_sensitive(cfg)
    _patch_ollama_drop_params(cfg)
    n = _patch_model_list_or_entries(cfg)
    if n:
        print(f"  model_list or-* redireccionados: {n}")

    fb = ls.setdefault("fallbacks", [])
    if isinstance(fb, list):
        vm110 = next((e for e in fb if isinstance(e, dict)
                     and "agl-primary-vm110" in e), None)
        if vm110 is None:
            fb.append({"agl-primary-vm110": list(SAFE_TAIL)})
        else:
            vm110["agl-primary-vm110"] = _clean_chain(
                vm110.get("agl-primary-vm110") or [])

    return cfg


def main() -> None:
    path = Path(sys.argv[1]) if len(sys.argv) > 1 else DEFAULT
    cfg = yaml.safe_load(path.read_text(encoding="utf-8")) or {}
    patch(cfg)
    path.write_text(yaml.dump(cfg, sort_keys=False,
                    allow_unicode=True), encoding="utf-8")
    print(f"OK patch zero-openrouter → {path}")


if __name__ == "__main__":
    main()
