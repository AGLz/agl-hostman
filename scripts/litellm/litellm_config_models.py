#!/usr/bin/env python3
"""Carrega modelos do config LiteLLM (sem PyYAML) para benchmarks e baterias."""
from __future__ import annotations

import os
import re
from dataclasses import dataclass, field
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
DEFAULT_CONFIG = REPO_ROOT / "config" / "litellm" / "config.yaml"

PROVIDER_ALIASES: dict[str, tuple[str, ...]] = {
    "zai": ("zai",),
    "groq": ("groq",),
    "openrouter": ("openrouter",),
    "anthropic": ("anthropic",),
    "openai": ("openai",),
    "google": ("google", "gemini"),
    "gemini": ("google", "gemini"),
    "deepseek": ("deepseek",),
    "moonshot": ("moonshot", "kimi"),
    "kimi": ("moonshot", "kimi"),
    "ollama": ("ollama", "local"),
    "local": ("ollama", "local"),
    "alibaba": ("alibaba", "dashscope", "zai"),
    "dashscope": ("alibaba", "dashscope"),
    "qwen": ("zai", "qwen"),
}

QUICK_MODELS = frozenset({
    "agl-primary",
    "agl-primary-strong",
    "ollama-gemma4-qat",
    "glm-flash",
    "glm-4.7-flash",
    "groq-llama-31-8b",
    "gpt-5.4-mini",
    "gemini-lite",
})

SKIP_BENCHMARK_IDS = frozenset({
    "infra-agent",
})

STANDARD_SKIP_IDS = frozenset({
    "infra-agent",
})


@dataclass(frozen=True)
class LiteLLMModelEntry:
    model_name: str
    litellm_model: str
    api_base: str
    api_key: str
    env_keys: tuple[str, ...] = field(default_factory=tuple)
    provider: str = "other"
    tier: str = "paid"
    free_tier: bool = False
    label: str = ""

    def __post_init__(self) -> None:
        object.__setattr__(self, "label", self.label or self.model_name)


def _extract_scalar(block: str, key: str) -> str:
    match = re.search(
        rf"^\s{{4,8}}{re.escape(key)}:\s*(.+)$", block, re.MULTILINE)
    if not match:
        return ""
    raw = match.group(1).strip()
    if raw.startswith('"') and raw.endswith('"'):
        return raw[1:-1]
    if raw.startswith("'") and raw.endswith("'"):
        return raw[1:-1]
    return raw


def _extract_bool(block: str, key: str) -> bool | None:
    val = _extract_scalar(block, key)
    if val.lower() == "true":
        return True
    if val.lower() == "false":
        return False
    return None


def parse_model_list(text: str) -> list[LiteLLMModelEntry]:
    start = text.find("model_list:")
    if start < 0:
        return []
    section = text[start:]
    chunks = re.split(r"\n(?=\s+- litellm_params:)", section)
    entries: list[LiteLLMModelEntry] = []
    for chunk in chunks[1:]:
        model_name = _extract_scalar(chunk, "model_name")
        if not model_name:
            continue
        litellm_model = _extract_scalar(chunk, "model")
        api_base = _extract_scalar(chunk, "api_base")
        api_key = _extract_scalar(chunk, "api_key")
        free_tier = _extract_bool(chunk, "free_tier") is True
        env_keys = _env_keys_from_block(chunk)
        provider = infer_provider(litellm_model, api_base, api_key, model_name)
        tier = infer_tier(provider, free_tier, model_name, litellm_model)
        entries.append(
            LiteLLMModelEntry(
                model_name=model_name,
                litellm_model=litellm_model,
                api_base=api_base,
                api_key=api_key,
                env_keys=env_keys,
                provider=provider,
                tier=tier,
                free_tier=free_tier,
            ),
        )
    return entries


def _env_keys_from_api_key(api_key: str) -> tuple[str, ...]:
    if not api_key:
        return ()
    match = re.match(r"^os\.environ/([A-Z0-9_]+)$", api_key.strip())
    if match:
        return (match.group(1),)
    return ()


def _env_keys_from_block(block: str) -> tuple[str, ...]:
    keys: list[str] = []
    for match in re.finditer(r"^[\s]+(?:api_key|vertex_project|vertex_location):\s*os\.environ/([A-Z0-9_]+)$", block, re.MULTILINE):
        keys.append(match.group(1))
    if keys:
        return tuple(dict.fromkeys(keys))
    return _env_keys_from_api_key(_extract_scalar(block, "api_key"))


def infer_provider(litellm_model: str, api_base: str, api_key: str, model_name: str) -> str:
    base = api_base.lower()
    model = litellm_model.lower()
    name = model_name.lower()

    if api_key == "ollama" or model.startswith("ollama/") or ":11434" in base or ":11435" in base:
        return "ollama"
    if "groq.com" in base or name.startswith("groq-"):
        return "groq"
    if "openrouter.ai" in base or name.startswith("or-") or name.startswith("openrouter/") or model.startswith("openrouter/"):
        return "openrouter"
    if "dashscope.aliyuncs.com" in base or "dashscope" in model:
        return "alibaba"
    if "api.z.ai" in base or name.startswith("zai") or name.startswith("glm"):
        return "zai"
    if "anthropic" in model or name.startswith("claude") or name.startswith("cursor-claude"):
        return "anthropic"
    if "deepseek" in model or name.startswith("deepseek") or name in {"deepseek", "r1", "cursor-deepseek"}:
        return "deepseek"
    if "aiplatform.googleapis.com" in base or model.startswith("vertex_ai/"):
        return "google"
    if "generativelanguage.googleapis.com" in base or (model.startswith("gemini/") and not model.startswith("vertex_ai/")) or name.startswith("gemini") or name.startswith("google/"):
        return "google"
    if "moonshot" in model or name.startswith("kimi") or name.startswith("moonshot"):
        return "moonshot"
    if name.startswith("qwen") or name.startswith("qwen/"):
        return "zai"
    if name.startswith("cursor-composer") or name.startswith("gpt") or name == "gpt":
        return "openai"
    if name.startswith("cursor-glm"):
        return "zai"
    if model.startswith("openai/") and "api.z.ai" in base:
        return "zai"
    if model.startswith("openai/"):
        return "openai"
    return "other"


def infer_tier(provider: str, free_tier: bool, model_name: str, litellm_model: str) -> str:
    if provider == "ollama":
        return "local"
    name = model_name.lower()
    if free_tier or ":free" in name or name.startswith("or-"):
        return "free"
    if provider == "groq":
        return "free"
    return "paid"


def env_keys_available(env_keys: tuple[str, ...]) -> bool:
    if not env_keys:
        return True
    for key in env_keys:
        val = os.environ.get(key, "").strip()
        if val:
            return True
    return False


def load_env_file(path: Path) -> None:
    if not path.is_file():
        return
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, _, val = line.partition("=")
        key = key.strip()
        val = val.strip().strip('"').strip("'")
        if key and val and key not in os.environ:
            os.environ[key] = val


def load_models(
    config_path: Path | None = None,
    *,
    providers: set[str] | None = None,
    tier: str | None = None,
    require_keys: bool = True,
    skip_ids: set[str] | None = None,
) -> list[LiteLLMModelEntry]:
    path = config_path or DEFAULT_CONFIG
    text = path.read_text(encoding="utf-8")
    models = parse_model_list(text)
    skip = skip_ids or SKIP_BENCHMARK_IDS
    provider_filter = _normalize_provider_filter(
        providers) if providers else None

    out: list[LiteLLMModelEntry] = []
    for entry in models:
        if entry.model_name in skip:
            continue
        if provider_filter and entry.provider not in provider_filter:
            continue
        if tier and entry.tier != tier:
            continue
        if require_keys and entry.env_keys and not env_keys_available(entry.env_keys):
            continue
        out.append(entry)
    return out


def _normalize_provider_filter(providers: set[str]) -> set[str]:
    expanded: set[str] = set()
    for p in providers:
        key = p.strip().lower()
        if key in PROVIDER_ALIASES:
            expanded.update(PROVIDER_ALIASES[key])
        else:
            expanded.add(key)
    return expanded


def models_for_benchmark_tuple(
    entries: list[LiteLLMModelEntry],
) -> list[tuple[str, str, str, str]]:
    return [(e.model_name, e.label, e.provider, e.tier) for e in entries]


def manifest_timeout_sec(entry: LiteLLMModelEntry) -> int:
    name = entry.model_name
    if entry.provider == "ollama":
        return 180 if "8b" in name or "strong" in name else 120
    if entry.provider == "openrouter":
        return 150 if entry.tier == "free" else 90
    if entry.provider == "groq" and "120b" in name:
        return 95
    if entry.provider == "groq":
        return 55
    if entry.provider == "anthropic" and "opus" in name:
        return 90
    if entry.provider == "openai" and any(x in name for x in ("5.4", "5.5", "composer")):
        return 90
    if entry.provider == "google":
        return 75
    return 70


def manifest_max_tokens(entry: LiteLLMModelEntry) -> int:
    if entry.provider == "openrouter" and entry.tier == "free":
        return 256
    if entry.provider == "ollama":
        return 48
    if entry.provider == "groq" and "gpt-oss" in entry.model_name:
        return 512
    if entry.provider == "groq" and "120b" in entry.model_name:
        return 48
    return 32


def manifest_run_for(entry: LiteLLMModelEntry) -> list[str]:
    tiers: list[str] = []
    if entry.model_name in QUICK_MODELS:
        tiers.append("quick")
    if entry.model_name not in STANDARD_SKIP_IDS and not entry.model_name.startswith("openrouter/"):
        tiers.append("standard")
    tiers.append("full")
    return sorted(set(tiers), key=lambda t: ("quick", "standard", "full").index(t))


def manifest_optional(entry: LiteLLMModelEntry) -> bool:
    if entry.provider == "ollama":
        return True
    if entry.tier == "free":
        return True
    if entry.model_name.startswith("cursor-"):
        return False
    return entry.provider in {"openrouter", "groq", "google"}


def entry_to_manifest_row(entry: LiteLLMModelEntry) -> dict[str, object]:
    return {
        "id": entry.model_name,
        "runFor": manifest_run_for(entry),
        "timeoutSec": manifest_timeout_sec(entry),
        "maxTokens": manifest_max_tokens(entry),
        "expectUsage": entry.provider != "ollama",
        "optional": manifest_optional(entry),
        "provider": entry.provider,
        "tier": entry.tier,
    }


def build_battery_manifest(
    config_path: Path | None = None,
    *,
    require_keys: bool = False,
) -> dict[str, object]:
    models = load_models(config_path, require_keys=require_keys)
    rows = [entry_to_manifest_row(m) for m in models]
    providers = sorted({m.provider for m in models})
    return {
        "generatedFrom": str(config_path or DEFAULT_CONFIG),
        "providers": providers,
        "models": rows,
    }


def ollama_direct_targets() -> list[tuple[str, str, str]]:
    """(model, url, label) — GPUs VM310."""
    gpu0 = os.environ.get("VM310_OLLAMA_GPU0",
                          "http://100.67.253.52:11434").rstrip("/")
    gpu1 = os.environ.get("VM310_OLLAMA_GPU1",
                          "http://100.67.253.52:11435").rstrip("/")
    return [
        ("gemma4-qat", gpu0, "VM310 GPU0"),
        ("qwen3:8b", gpu1, "VM310 GPU1"),
    ]
