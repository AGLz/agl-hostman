#!/usr/bin/env python3
"""
Benchmark comparativo: Ollama GPU (directo) vs providers LiteLLM.
Gera JSON + Markdown para docs/LITELLM-PROVIDER-BENCHMARK.md

Modelos: auto-descobertos de config/litellm/config.yaml (filtrados por keys disponíveis).

Uso (agldv03 ou host com LiteLLM):
  LITELLM_URL=http://127.0.0.1:4000 \\
  LITELLM_KEY=sk-... \\
  LITELLM_ENV_FILE=/opt/agl-litellm/.env \\
  BENCH_PROVIDERS=groq,openrouter,zai,anthropic,openai,ollama \\
  BENCH_PROMPTS=latency \\
  python3 scripts/litellm/benchmark-provider-comparison.py
"""
from __future__ import annotations

import json
import os
import sys
import time
import urllib.error
import urllib.request
from dataclasses import asdict, dataclass, field
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

_SCRIPT_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(_SCRIPT_DIR))

from litellm_config_models import (  # noqa: E402
    DEFAULT_CONFIG,
    load_env_file,
    load_models,
    models_for_benchmark_tuple,
    ollama_direct_targets,
)

LITELLM_URL = os.environ.get(
    "LITELLM_URL", "http://127.0.0.1:4000").rstrip("/")
LITELLM_KEY = os.environ.get("LITELLM_KEY", "")
OLLAMA_URL = os.environ.get(
    "OLLAMA_URL", "http://100.67.253.52:11434").rstrip("/")
_REPO_ROOT = Path(__file__).resolve().parents[2] if len(
    Path(__file__).resolve().parents) > 2 else Path("/tmp")
OUT_JSON = os.environ.get("OUT_JSON", "/tmp/litellm-provider-benchmark.json")
OUT_MD = os.environ.get(
    "OUT_MD",
    str(_REPO_ROOT / "docs" / "LITELLM-PROVIDER-BENCHMARK.md"),
)
TIMEOUT = int(os.environ.get("BENCH_TIMEOUT", "120"))

PROMPTS = {
    "latency": {
        "label": "Latência (PONG)",
        "content": "Responda apenas a palavra: PONG",
        "max_tokens": 8,
    },
    "reasoning": {
        "label": "Raciocínio",
        "content": "Quantas letras 'r' existem na palavra 'strawberry'? Responda só com o número.",
        "max_tokens": 16,
    },
    "json": {
        "label": "JSON estruturado",
        "content": 'Responde APENAS JSON válido: {"capital":"Lisboa","pais":"Portugal"}',
        "max_tokens": 64,
    },
    "pt": {
        "label": "Português",
        "content": "Em uma frase em português de Portugal, explica o que é inferência local com GPU.",
        "max_tokens": 80,
    },
}

BENCH_CONFIG = Path(os.environ.get("BENCH_CONFIG", str(DEFAULT_CONFIG)))
BENCH_TIER = os.environ.get("BENCH_TIER", "all").lower()
BENCH_PROMPTS = os.environ.get("BENCH_PROMPTS", "").strip()
BENCH_PROVIDERS = os.environ.get("BENCH_PROVIDERS", "").strip()
BENCH_REQUIRE_KEYS = os.environ.get(
    "BENCH_REQUIRE_KEYS", "1").lower() not in ("0", "false", "no")
BENCH_DELAY_SEC = float(os.environ.get("BENCH_DELAY_SEC", "0.5"))
BENCH_ENV_FILE = os.environ.get("LITELLM_ENV_FILE", "/opt/agl-litellm/.env")


@dataclass
class BenchResult:
    target: str
    model: str
    provider: str
    prompt_id: str
    ok: bool
    http_status: int
    latency_ms: int
    ttft_ms: int | None = None
    prompt_tokens: int | None = None
    completion_tokens: int | None = None
    tokens_per_s: float | None = None
    free_tier: bool = False
    tier: str = "unknown"
    error: str = ""
    preview: str = ""


@dataclass
class RunMeta:
    started_at: str = ""
    litellm_url: str = LITELLM_URL
    ollama_url: str = OLLAMA_URL
    host: str = ""
    results: list[dict[str, Any]] = field(default_factory=list)


def _post_json(url: str, payload: dict, headers: dict | None = None, timeout: int = TIMEOUT) -> tuple[int, dict]:
    data = json.dumps(payload).encode()
    req = urllib.request.Request(url, data=data, method="POST")
    req.add_header("Content-Type", "application/json")
    for k, v in (headers or {}).items():
        req.add_header(k, v)
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            body = resp.read().decode()
            return resp.status, json.loads(body) if body else {}
    except urllib.error.HTTPError as e:
        body = e.read().decode(errors="replace")
        try:
            parsed = json.loads(body)
        except json.JSONDecodeError:
            parsed = {"error": {"message": body[:500]}}
        return e.code, parsed
    except TimeoutError:
        return 408, {"error": {"message": f"timeout after {timeout}s"}}
    except urllib.error.URLError as e:
        return 0, {"error": {"message": str(e.reason)[:300]}}


def bench_ollama_direct(
    model: str,
    prompt_id: str,
    spec: dict,
    *,
    ollama_url: str | None = None,
) -> BenchResult:
    base = (ollama_url or OLLAMA_URL).rstrip("/")
    t0 = time.perf_counter()
    payload = {
        "model": model,
        "prompt": spec["content"],
        "stream": False,
        "options": {"num_predict": spec["max_tokens"], "temperature": 0.1},
    }
    status, data = _post_json(f"{base}/api/generate", payload)
    latency = int((time.perf_counter() - t0) * 1000)
    if status != 200 or data.get("error"):
        return BenchResult(
            target="ollama-direct",
            model=model,
            provider="ollama-gpu",
            prompt_id=prompt_id,
            ok=False,
            http_status=status,
            latency_ms=latency,
            free_tier=True,
            error=str(data.get("error", data)),
        )
    eval_d = data.get("eval_duration") or 0
    eval_c = data.get("eval_count") or 0
    tps = round(eval_c / (eval_d / 1e9), 2) if eval_d and eval_c else None
    load_d = data.get("load_duration") or 0
    ttft = int((load_d + (data.get("prompt_eval_duration") or 0)) /
               1e6) if load_d else None
    preview = (data.get("response") or "")[:120].replace("\n", " ")
    return BenchResult(
        target="ollama-direct",
        model=model,
        provider="ollama-gpu",
        prompt_id=prompt_id,
        ok=True,
        http_status=status,
        latency_ms=latency,
        ttft_ms=ttft,
        completion_tokens=eval_c,
        tokens_per_s=tps,
        free_tier=True,
        preview=preview,
    )


def bench_litellm(model: str, provider: str, tier: str, prompt_id: str, spec: dict) -> BenchResult:
    free = tier == "free"
    if not LITELLM_KEY:
        return BenchResult(
            target="litellm",
            model=model,
            provider=provider,
            prompt_id=prompt_id,
            ok=False,
            http_status=0,
            latency_ms=0,
            free_tier=free,
            tier=tier,
            error="LITELLM_KEY não definida",
        )
    t0 = time.perf_counter()
    payload = {
        "model": model,
        "messages": [{"role": "user", "content": spec["content"]}],
        "max_tokens": spec["max_tokens"],
        "temperature": 0.1,
        "stream": False,
    }
    status, data = _post_json(
        f"{LITELLM_URL}/v1/chat/completions",
        payload,
        headers={"Authorization": f"Bearer {LITELLM_KEY}"},
    )
    latency = int((time.perf_counter() - t0) * 1000)
    if status != 200:
        err = data.get("error", {})
        msg = err.get("message", str(data)) if isinstance(
            err, dict) else str(err)
        return BenchResult(
            target="litellm",
            model=model,
            provider=provider,
            prompt_id=prompt_id,
            ok=False,
            http_status=status,
            latency_ms=latency,
            free_tier=free,
            tier=tier,
            error=msg[:300],
        )
    choice = (data.get("choices") or [{}])[0]
    content = (choice.get("message") or {}).get("content") or ""
    usage = data.get("usage") or {}
    pt = usage.get("prompt_tokens")
    ct = usage.get("completion_tokens")
    tps = round(ct / (latency / 1000), 2) if ct and latency > 0 else None
    return BenchResult(
        target="litellm",
        model=model,
        provider=provider,
        prompt_id=prompt_id,
        ok=True,
        http_status=status,
        latency_ms=latency,
        prompt_tokens=pt,
        completion_tokens=ct,
        tokens_per_s=tps,
        free_tier=free,
        tier=tier,
        preview=content[:120].replace("\n", " "),
    )


def _provider_filter() -> set[str] | None:
    if not BENCH_PROVIDERS:
        return None
    return {p.strip().lower() for p in BENCH_PROVIDERS.split(",") if p.strip()}


def models_for_benchmark() -> list[tuple[str, str, str, str]]:
    tier = BENCH_TIER if BENCH_TIER in ("paid", "free", "local") else None
    entries = load_models(
        BENCH_CONFIG,
        providers=_provider_filter(),
        tier=tier,
        require_keys=BENCH_REQUIRE_KEYS,
    )
    models = models_for_benchmark_tuple(entries)
    if BENCH_TIER in ("paid", "free", "local"):
        models = [m for m in models if m[3] == BENCH_TIER]
    return models


def prompts_for_benchmark() -> dict[str, dict]:
    if not BENCH_PROMPTS:
        return PROMPTS
    ids = [p.strip() for p in BENCH_PROMPTS.split(",") if p.strip()]
    return {k: v for k, v in PROMPTS.items() if k in ids}


def score_capability(prompt_id: str, preview: str) -> str:
    p = preview.lower()
    if prompt_id == "latency":
        return "OK" if "pong" in p else "parcial"
    if prompt_id == "reasoning":
        return "OK" if "3" in preview.strip()[:5] else "fail"
    if prompt_id == "json":
        return "OK" if "lisboa" in p and "portugal" in p else "parcial"
    if prompt_id == "pt":
        return "OK" if any(w in p for w in ("gpu", "infer", "local", "modelo")) else "parcial"
    return "?"


def build_markdown(meta: RunMeta, results: list[BenchResult]) -> str:
    ok = [r for r in results if r.ok]
    fail = [r for r in results if not r.ok]
    lat = [r for r in ok if r.prompt_id == "latency"]
    lat.sort(key=lambda r: r.latency_ms)

    lines = [
        "# Benchmark comparativo — LiteLLM providers vs Ollama GPU (VM310)",
        "",
        f"**Gerado:** {meta.started_at}  ",
        f"**LiteLLM:** `{meta.litellm_url}`  ",
        f"**Ollama directo:** `{meta.ollama_url}`  ",
        f"**Config:** `{BENCH_CONFIG}`  ",
        f"**Host benchmark:** `{meta.host}`  ",
        f"**Filtro tier:** `{BENCH_TIER}`  ",
        f"**Filtro providers:** `{BENCH_PROVIDERS or 'all'}`  ",
        f"**Modelos LiteLLM:** `{len({r.model for r in results if r.target == 'litellm'})}`  ",
        "",
        "## Resumo executivo",
        "",
        f"- Testes OK: **{len(ok)}/{len(results)}**",
        f"- Falhas: **{len(fail)}**",
        "",
        "### Latência (prompt PONG) — ranking",
        "",
        "| Rank | Modelo | Provider | Tier | ms | tok/s | Preview |",
        "|------|--------|----------|------|-----|-------|---------|",
    ]
    for i, r in enumerate(lat[:20], 1):
        tps = f"{r.tokens_per_s:.1f}" if r.tokens_per_s else "—"
        lines.append(
            f"| {i} | `{r.model}` | {r.provider} | {r.tier} | {r.latency_ms} | {tps} | {r.preview[:40]} |")

    lines += [
        "",
        "## Capacidade por prompt",
        "",
        "| Modelo | Provider | Tier | PONG | Raciocínio | JSON | PT | Notas |",
        "|--------|----------|------|------|------------|------|-----|-------|",
    ]
    models_seen: dict[str, list[BenchResult]] = {}
    for r in results:
        models_seen.setdefault(r.model, []).append(r)
    for model, rs in sorted(models_seen.items()):
        by_p = {x.prompt_id: x for x in rs}
        prov = rs[0].provider
        tier = rs[0].tier
        notes = next((x.error for x in rs if x.error), "")
        if all(x.ok for x in rs):
            notes = "OK" if not notes else notes
        cols = []
        for pid in ("latency", "reasoning", "json", "pt"):
            if pid not in by_p or not by_p[pid].ok:
                cols.append("—")
            else:
                cols.append(score_capability(pid, by_p[pid].preview))
        lines.append(
            f"| `{model}` | {prov} | {tier} | {cols[0]} | {cols[1]} | {cols[2]} | {cols[3]} | {notes[:60]} |"
        )

    lines += [
        "",
        "## Falhas",
        "",
    ]
    if not fail:
        lines.append("_Nenhuma falha._")
    else:
        lines.append("| Modelo | Prompt | HTTP | Erro |")
        lines.append("|--------|--------|------|------|")
        for r in fail:
            lines.append(
                f"| `{r.model}` | {r.prompt_id} | {r.http_status} | {r.error[:80]} |")

    lines += [
        "",
        "## Limites de uso por provider (referência web, 2026)",
        "",
        "| Provider | Modelo(s) AGL | Limites típicos | Custo |",
        "|----------|---------------|-----------------|-------|",
        "| **Ollama VM310 dual-GPU** | `gemma4-qat`, `qwen3:8b` | Sem rate limit; GPU0+GPU1 RX580 | Grátis (hardware local) |",
        "| **Z.AI** | `glm-4.7-flash`, `glm-flash` | GLM-4.7-Flash API grátis; Coding Plan ~$18/mês com quotas 5h+7d; pico 14–18h UTC+8 consome 2–3× | Flash free; resto pay-per-token ou plano |",
        "| **Groq** | `groq-llama-31-8b` | ~30 RPM, 6K–12K TPM, 1K–14.4K RPD (por modelo) | Free tier |",
        "| **OpenRouter** | `or-*-free`, `openrouter-free` | 20 RPM; 50 RPD (sem créditos) ou 1000 RPD após $10 | Free variants |",
        "| **DeepSeek** | `deepseek`, `qwen-coder` | Concurrency-based; throttling em pico; sem RPM fixo público | Pay-per-use baixo |",
        "| **Google Gemini** | `gemini-lite` | Quotas GCP/AI Studio; free tier com limites diários | Free tier limitado |",
        "| **Moonshot/Kimi** | `kimi` | Rate limits por conta API | Pay-per-use |",
        "| **Anthropic** | `claude-*` | RPM/TPM por tier API | Pago (subscrição API) |",
        "| **OpenAI** | `gpt-5.4*`, `cursor-composer*` | Billing platform.openai.com | Pago (subscrição API) |",
        "| **Z.AI Coding** | `zai-coding-glm-4.7` | Quotas plano Coding (~5h/7d) | Plano ~\$18/mês |",
        "",
        "Matriz completa subscrições × ferramentas: `docs/LITELLM-MODEL-TIERS.md`.",
        "",
        "## Recomendações AGL",
        "",
        "- **Qualidade cloud paga:** `claude-sonnet`, `gpt-5.4-mini`, `glm-5`, `zai-coding-glm-4.7`.",
        "- **Privacidade / offline:** `agl-primary` (Ollama GPU).",
        "- **Burst free (último recurso):** `groq-llama-31-8b`, `glm-4.7-flash`, OpenRouter `:free`.",
        "- **Fallback:** paid → local → free (`config/litellm/config.yaml`).",
        "",
        "---",
        "",
        "_Script: `scripts/litellm/benchmark-provider-comparison.py`_",
    ]
    return "\n".join(lines) + "\n"


def main() -> int:
    import socket

    env_path = Path(BENCH_ENV_FILE)
    if env_path.is_file():
        load_env_file(env_path)

    if not LITELLM_KEY:
        for path in ("/opt/litellm/.env", os.path.expanduser("~/.hermes/config.yaml")):
            if not os.path.isfile(path):
                continue
            with open(path) as f:
                for line in f:
                    if "LITELLM_MASTER_KEY" in line or line.strip().startswith("api_key:"):
                        val = line.split(
                            "=", 1)[-1].split(":", 1)[-1].strip().strip('"')
                        if val and len(val) > 10:
                            globals()["LITELLM_KEY"] = val
                            break
            if LITELLM_KEY:
                break

    meta = RunMeta(
        started_at=datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M UTC"),
        host=socket.gethostname(),
    )
    results: list[BenchResult] = []

    print(f"Ollama directo: {OLLAMA_URL}")
    print(f"LiteLLM: {LITELLM_URL}")
    print(f"Config: {BENCH_CONFIG}")
    print(f"Tier filter: {BENCH_TIER}")
    print(f"Providers filter: {BENCH_PROVIDERS or 'all'}")
    print(f"Require keys: {BENCH_REQUIRE_KEYS}")
    print()

    prompt_set = prompts_for_benchmark()
    bench_models = models_for_benchmark()
    print(f"Modelos a testar: {len(bench_models)}")
    if not bench_models:
        print("AVISO: nenhum modelo — verificar BENCH_PROVIDERS / keys em LITELLM_ENV_FILE")
        return 1

    for prompt_id, spec in prompt_set.items():
        print(f"=== Prompt: {prompt_id} ({spec['label']}) ===")
        if BENCH_TIER in ("all", "local") and (
            not BENCH_PROVIDERS or "ollama" in BENCH_PROVIDERS or "local" in BENCH_PROVIDERS
        ):
            for ollama_model, ollama_base, gpu_label in ollama_direct_targets():
                r = bench_ollama_direct(
                    ollama_model, prompt_id, spec, ollama_url=ollama_base,
                )
                results.append(r)
                tag = f"ollama-direct/{ollama_model}@{gpu_label}"
                print(
                    f"  {tag}: {'OK' if r.ok else 'FAIL'} {r.latency_ms}ms {r.preview[:50]}")

        for model, _label, provider, tier in bench_models:
            r = bench_litellm(model, provider, tier, prompt_id, spec)
            results.append(r)
            status = "OK" if r.ok else "FAIL"
            print(
                f"  {model}: {status} {r.latency_ms}ms {r.preview[:40] if r.ok else r.error[:40]}")
            if BENCH_DELAY_SEC > 0:
                time.sleep(BENCH_DELAY_SEC)

    meta_dict = {
        "started_at": meta.started_at,
        "litellm_url": meta.litellm_url,
        "ollama_url": meta.ollama_url,
        "host": meta.host,
        "results": [asdict(r) for r in results],
    }
    Path(OUT_JSON).write_text(json.dumps(
        meta_dict, indent=2, ensure_ascii=False))
    md = build_markdown(meta, results)
    Path(OUT_MD).write_text(md, encoding="utf-8")
    print()
    print(f"JSON: {OUT_JSON}")
    print(f"Markdown: {OUT_MD}")
    return 0 if any(r.ok for r in results) else 1


if __name__ == "__main__":
    sys.exit(main())
