#!/usr/bin/env python3
"""Substitui models.providers por catálogo direct-to-provider (sem LiteLLM/proxy).

Faz backup de ~/.openclaw/openclaw.json e, se existir, de agents/<id>/agent/models.json.
Remove entradas em models.providers cujo baseUrl aponta para LiteLLM ou :4000.
Preserva o bloco ollama se existir e não for proxy.
"""
from __future__ import annotations

import argparse
import json
import shutil
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


PROXY_MARKERS = ("litellm", ":4000", "127.0.0.1:4000", "localhost:4000")

AGL_PRIMARY_MODEL = "zai/glm-4.7-flash"
# Ordem: após falha Z.AI Flash — DeepSeek via OpenRouter, :free OpenRouter, GLM-5, DashScope.
AGL_DEFAULT_MODEL_FALLBACKS = [
    "openrouter/deepseek/deepseek-chat",
    "openrouter/meta-llama/llama-3.3-70b-instruct:free",
    "openrouter/z-ai/glm-4.5-air:free",
    "zai/glm-5",
    "dashscope/qwen-plus",
]
AGL_DEFAULT_IMAGE_FALLBACKS = [
    "openrouter/deepseek/deepseek-chat",
    "openrouter/meta-llama/llama-3.3-70b-instruct:free",
    "zai/glm-5",
]
# Alinhado com config/openclaw/openclaw-agents-list.fragment.json
AGL_SUBAGENT_MODELS: dict[str, dict[str, Any]] = {
    "infra": {
        "primary": AGL_PRIMARY_MODEL,
        "fallbacks": [
            "deepseek",
            "or-llama-free",
            "or-glm-air-free",
            "glm",
            "qwen-plus",
        ],
    },
    "storage": {
        "primary": AGL_PRIMARY_MODEL,
        "fallbacks": ["deepseek", "or-llama-free", "gemini-lite", "glm"],
    },
    "harbor": {
        "primary": AGL_PRIMARY_MODEL,
        "fallbacks": ["deepseek", "or-llama-free", "glm"],
    },
    "net": {
        "primary": AGL_PRIMARY_MODEL,
        "fallbacks": ["deepseek", "or-llama-free", "gemini-lite"],
    },
}


def _is_proxy_provider(cfg: dict[str, Any] | None) -> bool:
    if not cfg:
        return False
    base = str(cfg.get("baseUrl") or "").lower()
    return any(m in base for m in PROXY_MARKERS)


def _load(p: Path) -> dict[str, Any]:
    return json.loads(p.read_text(encoding="utf-8"))


def _save(p: Path, data: dict[str, Any]) -> None:
    p.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


def _backup(p: Path) -> Path:
    ts = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    bak = p.with_suffix(p.suffix + f".bak.direct-{ts}")
    shutil.copy2(p, bak)
    return bak


def _provider_maps_from_cfg(cfg: dict[str, Any]) -> list[dict[str, Any]]:
    """openclaw.json usa models.providers; agent models.json costuma usar providers na raiz."""
    maps: list[dict[str, Any]] = []
    mp = (cfg.get("models") or {}).get("providers")
    if isinstance(mp, dict):
        maps.append(mp)
    rp = cfg.get("providers")
    if isinstance(rp, dict):
        maps.append(rp)
    return maps


def _ollama_from_cfg(cfg: dict[str, Any]) -> dict[str, Any] | None:
    for prev in _provider_maps_from_cfg(cfg):
        oll = prev.get("ollama")
        if isinstance(oll, dict) and not _is_proxy_provider(oll):
            return oll
    return None


def _merge_providers(
    existing: dict[str, Any],
    template_providers: dict[str, Any],
) -> dict[str, Any]:
    out = dict(template_providers)
    oll = _ollama_from_cfg(existing)
    if oll is not None:
        out["ollama"] = oll
    return out


def _apply_agl_primary_flash(cfg: dict[str, Any]) -> None:
    """Primário e imageModel = zai/glm-4.7-flash; memorySearch sem LiteLLM (OpenAI embeddings)."""
    agents = cfg.setdefault("agents", {})
    defaults = agents.setdefault("defaults", {})
    dm = defaults.setdefault("model", {})
    dm["primary"] = AGL_PRIMARY_MODEL
    dm["fallbacks"] = list(AGL_DEFAULT_MODEL_FALLBACKS)
    im = defaults.setdefault("imageModel", {})
    im["primary"] = AGL_PRIMARY_MODEL
    im["fallbacks"] = list(AGL_DEFAULT_IMAGE_FALLBACKS)
    comp = defaults.setdefault("compaction", {})
    comp["mode"] = comp.get("mode") or "safeguard"
    comp["model"] = AGL_PRIMARY_MODEL
    defaults["memorySearch"] = {
        "provider": "openai",
        "model": "text-embedding-3-small",
        "remote": {
            "baseUrl": "https://api.openai.com/v1/",
            "apiKey": "${OPENAI_API_KEY}",
        },
        "fallback": "local",
    }
    alist = agents.get("list")
    if not isinstance(alist, list):
        return
    for agent in alist:
        if not isinstance(agent, dict):
            continue
        aid = agent.get("id")
        if aid == "main":
            continue
        spec = AGL_SUBAGENT_MODELS.get(str(aid))
        if spec is not None:
            agent["model"] = {
                "primary": spec["primary"],
                "fallbacks": list(spec["fallbacks"]),
            }
            continue
        m = agent.setdefault("model", {})
        m["primary"] = AGL_PRIMARY_MODEL
        m.setdefault(
            "fallbacks",
            ["zai/glm-5", "openrouter/deepseek/deepseek-chat"],
        )


def _strip_litellm_env(cfg: dict[str, Any]) -> None:
    env = cfg.get("env")
    if not isinstance(env, dict):
        return
    for k in list(env.keys()):
        if str(k).upper().startswith("LITELLM"):
            del env[k]


def patch_openclaw_json(path: Path, template: dict[str, Any], *, agl_primary_flash: bool) -> None:
    cfg = _load(path)
    _backup(path)
    tpl_models = template.get("models") or {}
    tpl_providers = tpl_models.get("providers")
    if not isinstance(tpl_providers, dict):
        raise SystemExit("Template sem models.providers (object).")
    cfg.setdefault("models", {})
    cfg["models"]["mode"] = tpl_models.get("mode") or "merge"
    cfg["models"]["providers"] = _merge_providers(cfg, tpl_providers)
    _strip_litellm_env(cfg)
    if agl_primary_flash:
        _apply_agl_primary_flash(cfg)
    _save(path, cfg)
    print(f"OK: {path}")


def patch_agent_models_json(path: Path, template: dict[str, Any]) -> None:
    if not path.is_file():
        return
    cfg = _load(path)
    _backup(path)
    tpl_models = template.get("models") or {}
    tpl_providers = tpl_models.get("providers") or {}
    merged = _merge_providers(cfg, tpl_providers)
    # Formato agente OpenClaw: chave "providers" na raiz (não models.providers).
    cfg["providers"] = merged
    cfg.pop("models", None)
    _save(path, cfg)
    print(f"OK: {path}")


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument(
        "--openclaw-json",
        type=Path,
        default=Path.home() / ".openclaw" / "openclaw.json",
        help="Caminho para openclaw.json",
    )
    ap.add_argument(
        "--template",
        type=Path,
        default=None,
        help="JSON com models.mode + models.providers",
    )
    ap.add_argument(
        "--agent-id",
        default="main",
        help="Agente cujo models.json sincronizar (predefinido: main)",
    )
    ap.add_argument(
        "--skip-agent-models",
        action="store_true",
        help="Não alterar ~/.openclaw/agents/<id>/agent/models.json",
    )
    ap.add_argument(
        "--skip-openclaw-json",
        action="store_true",
        help="Só atualizar agents/.../models.json (não tocar em openclaw.json)",
    )
    ap.add_argument(
        "--all-agents",
        action="store_true",
        help="Aplicar a todos os agentes com agents/*/agent/models.json",
    )
    ap.add_argument(
        "--no-agl-primary-flash",
        action="store_true",
        help="Não alterar primários dos agentes nem memorySearch (só substituir models.providers)",
    )
    args = ap.parse_args()

    if args.template is not None:
        tpl_path = args.template
    else:
        script = Path(__file__).resolve()
        repo = script.parents[2] if len(script.parents) > 2 else script.parent
        tpl_path = repo / "config" / "openclaw" / "openclaw-models-direct.providers.json"
    if not tpl_path.is_file():
        raise SystemExit(f"Template em falta: {tpl_path}")
    template = _load(tpl_path)

    oc = args.openclaw_json.expanduser()
    if not args.skip_openclaw_json:
        if not oc.is_file():
            raise SystemExit(f"openclaw.json não encontrado: {oc}")
        patch_openclaw_json(oc, template, agl_primary_flash=not args.no_agl_primary_flash)

    if args.skip_agent_models:
        return

    agents_root = Path.home() / ".openclaw" / "agents"
    if args.all_agents:
        for mp in sorted(agents_root.glob("*/agent/models.json")):
            patch_agent_models_json(mp, template)
    else:
        agent_models = agents_root / args.agent_id / "agent" / "models.json"
        patch_agent_models_json(agent_models, template)


if __name__ == "__main__":
    main()
