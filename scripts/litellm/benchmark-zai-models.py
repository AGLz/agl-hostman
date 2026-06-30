#!/usr/bin/env python3
"""
Benchmark dedicado aos modelos Z.AI (GLM) usados pelos workers Ruflo via LiteLLM.

Objetivo: descobrir qual alias Z.AI é a melhor opção para o Ruflo, medindo
latência, throughput (tokens/s), fidelidade de backend (se o pedido foi mesmo
servido pela Z.AI ou caiu num fallback OpenRouter/Nvidia/Groq) e qualidade
funcional em prompts representativos de coding/agentes.

Porquê medir via gateway LiteLLM e não via swarm Ruflo completo:
  Os workers Ruflo (Coder/Tester) chamam estes mesmos aliases LiteLLM através do
  Claude Code (ANTHROPIC_BASE_URL → :4000). Medir os aliases no gateway dá
  exatamente o sinal necessário — qual modelo escolher — sem o custo/lentidão de
  arrancar um hive-mind por modelo. Validação end-to-end no Ruflo faz-se depois,
  só com o(s) vencedor(es).

Uso (host com acesso ao gateway :4000):
  LITELLM_URL=http://100.125.249.8:4000 \\
  LITELLM_KEY="$(sh .claude/helpers/get-litellm-key.sh)" \\
  python3 scripts/litellm/benchmark-zai-models.py

Env principais:
  ZAI_MODELS          CSV de aliases a testar (default: lista curada Z.AI real)
  ZAI_INCLUDE_TRAPS   "1" inclui aliases com nome GLM mas backend não-Z.AI
  BENCH_REPEATS       repetições por (modelo,prompt) (default 2)
  BENCH_PROMPTS       subset CSV de prompt ids (default todos)
  BENCH_MAX_TOKENS    teto de tokens p/ prompts de geração (default 512)
  BENCH_TIMEOUT       timeout HTTP s (default 120)
  OUT_JSON / OUT_MD   caminhos de saída (default docs/litellm-battery/zai-*)
"""
from __future__ import annotations

import json
import os
import statistics
import sys
import time
import urllib.error
import urllib.request
from dataclasses import asdict, dataclass, field
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

_REPO_ROOT = Path(__file__).resolve().parents[2]

LITELLM_URL = os.environ.get("LITELLM_URL", "http://100.125.249.8:4000").rstrip("/")
LITELLM_KEY = os.environ.get("LITELLM_KEY", "")
TIMEOUT = int(os.environ.get("BENCH_TIMEOUT", "120"))
REPEATS = max(1, int(os.environ.get("BENCH_REPEATS", "2")))
MAX_TOKENS = int(os.environ.get("BENCH_MAX_TOKENS", "512"))
DELAY_SEC = float(os.environ.get("BENCH_DELAY_SEC", "0.6"))

_TS = datetime.now(timezone.utc).strftime("%Y%m%d-%H%M%S")
_OUT_DIR = _REPO_ROOT / "docs" / "litellm-battery"
OUT_JSON = os.environ.get("OUT_JSON", str(_OUT_DIR / f"zai-benchmark-{_TS}.json"))
OUT_MD = os.environ.get("OUT_MD", str(_OUT_DIR / f"zai-benchmark-{_TS}.md"))

# Lista curada: aliases cujo backend é mesmo api.z.ai (ver config/litellm/config.yaml).
DEFAULT_ZAI_MODELS = [
    "zai-glm-5",
    "zai-glm-flash",
    "zai-coding-glm-4.7",
    "glm-5",
    "glm-5-turbo",
    "glm-4.7",
    "glm-4.5",
    "glm-flash",
    "glm-air",
    "zai/glm-5",
    "zai/glm-4.7",
]

# Armadilhas: nome GLM/ZAI mas backend NÃO é Z.AI (OpenAI nano / OpenRouter).
# Incluídas só com ZAI_INCLUDE_TRAPS=1, para comparação/contraste.
TRAP_MODELS = ["glm-4.7-flash", "zai/glm-4.7-flash", "or-glm-air-free"]

# Prompts representativos do trabalho dos workers Ruflo (coding/agentes) + latência.
PROMPTS: dict[str, dict[str, Any]] = {
    "latency": {
        "label": "Latência (PONG)",
        "content": "Responde apenas a palavra: PONG",
        "max_tokens": 16,
        "check": lambda t: "PONG" in t.upper(),
    },
    "code": {
        "label": "Código Python",
        "content": (
            "Escreve uma função Python `is_prime(n: int) -> bool` correta e eficiente. "
            "Devolve APENAS o bloco de código, sem explicação."
        ),
        "max_tokens": MAX_TOKENS,
        "check": lambda t: "def is_prime" in t,
    },
    "json_tool": {
        "label": "Tool-call JSON",
        "content": (
            "Devolve APENAS JSON válido (sem markdown) com esta forma exata: "
            '{"tool":"read_file","args":{"path":"src/main.py"}}'
        ),
        "max_tokens": 128,
        "check": None,  # _json_tool_check atribuído após a definição da função
    },
    "refactor": {
        "label": "Refactor/raciocínio curto",
        "content": (
            "Em português, explica numa frase o bug em: "
            "`def soma(a, b): return a - b`  e dá a linha corrigida."
        ),
        "max_tokens": MAX_TOKENS,
        "check": lambda t: ("+" in t) and ("return" in t or "soma" in t.lower()),
    },
}


def _json_tool_check(text: str) -> bool:
    """Aceita JSON com a chave tool=read_file, tolerando cercas markdown."""
    cleaned = text.strip()
    if cleaned.startswith("```"):
        cleaned = cleaned.strip("`")
        nl = cleaned.find("\n")
        if nl != -1:
            cleaned = cleaned[nl + 1 :]
    start, end = cleaned.find("{"), cleaned.rfind("}")
    if start == -1 or end == -1 or end <= start:
        return False
    try:
        obj = json.loads(cleaned[start : end + 1])
    except json.JSONDecodeError:
        return False
    return obj.get("tool") == "read_file" and isinstance(obj.get("args"), dict)


PROMPTS["json_tool"]["check"] = _json_tool_check

# Padrões de backend Z.AI vs fallback (no campo `model` e `provider` da resposta).
_ZAI_MODEL_HINTS = ("glm",)
_ZAI_PROVIDER_HINTS = ("z.ai", "zai", "zhipu")
_FALLBACK_MODEL_HINTS = (
    "nemotron", "llama", "qwen", "minimax", "owl", "gpt", "gemini",
    "mistral", "gemma", "hermes", "deepseek", "kimi", "moonshot",
)
_FALLBACK_PROVIDER_HINTS = (
    "nvidia", "groq", "openrouter", "openai", "google", "cerebras", "venice",
)


def classify_backend(returned_model: str, provider: str) -> str:
    """Classifica o backend real da resposta: 'zai' | 'fallback' | 'unknown'.

    Reason: pedir um alias Z.AI não garante que a Z.AI respondeu — pode ter caído
    num fallback (ex.: zai-coding-glm-4.7 → Nemotron). O campo `model`/`provider`
    devolvido pelo gateway revela o backend efetivo.
    """
    m = (returned_model or "").lower()
    p = (provider or "").lower()
    if any(h in p for h in _ZAI_PROVIDER_HINTS):
        return "zai"
    if any(h in p for h in _FALLBACK_PROVIDER_HINTS):
        return "fallback"
    # Sem provider fiável → heurística pelo nome do modelo.
    if any(h in m for h in _FALLBACK_MODEL_HINTS):
        return "fallback"
    if any(h in m for h in _ZAI_MODEL_HINTS):
        return "zai"
    return "unknown"


@dataclass
class Sample:
    prompt_id: str
    ok: bool
    http_status: int
    latency_ms: int
    completion_tokens: int | None = None
    tokens_per_s: float | None = None
    returned_model: str = ""
    provider: str = ""
    backend: str = "unknown"
    quality_ok: bool | None = None
    error: str = ""
    preview: str = ""


@dataclass
class ModelReport:
    alias: str
    samples: list[dict[str, Any]] = field(default_factory=list)
    runs: int = 0
    ok_runs: int = 0
    zai_runs: int = 0
    fallback_runs: int = 0
    quality_ok: int = 0
    quality_total: int = 0
    median_latency_ms: int | None = None
    median_tokens_per_s: float | None = None
    backends_seen: list[str] = field(default_factory=list)


def _post(url: str, payload: dict, key: str) -> tuple[int, dict]:
    data = json.dumps(payload).encode()
    req = urllib.request.Request(url, data=data, method="POST")
    req.add_header("Content-Type", "application/json")
    if key:
        req.add_header("Authorization", f"Bearer {key}")
    try:
        with urllib.request.urlopen(req, timeout=TIMEOUT) as resp:
            body = resp.read().decode()
            return resp.status, (json.loads(body) if body else {})
    except urllib.error.HTTPError as e:
        body = e.read().decode(errors="replace")
        try:
            parsed = json.loads(body)
        except json.JSONDecodeError:
            parsed = {"error": {"message": body[:300]}}
        return e.code, parsed
    except (urllib.error.URLError, TimeoutError, OSError) as e:
        return 0, {"error": {"message": str(e)}}


def run_sample(alias: str, prompt_id: str) -> Sample:
    spec = PROMPTS[prompt_id]
    payload = {
        "model": alias,
        "messages": [{"role": "user", "content": spec["content"]}],
        "max_tokens": spec["max_tokens"],
        "temperature": 0,
    }
    start = time.perf_counter()
    status, body = _post(f"{LITELLM_URL}/v1/chat/completions", payload, LITELLM_KEY)
    latency_ms = int((time.perf_counter() - start) * 1000)

    if status != 200:
        msg = ""
        if isinstance(body, dict):
            err = body.get("error")
            msg = err.get("message", "") if isinstance(err, dict) else str(err or body)
        return Sample(prompt_id, False, status, latency_ms, error=msg[:200])

    try:
        choice = body["choices"][0]
        text = (choice.get("message", {}) or {}).get("content") or ""
    except (KeyError, IndexError, TypeError):
        return Sample(prompt_id, False, status, latency_ms, error="resposta sem choices")

    usage = body.get("usage", {}) or {}
    comp = usage.get("completion_tokens")
    tps = round(comp / (latency_ms / 1000), 1) if comp and latency_ms > 0 else None
    returned_model = body.get("model", "") or ""
    provider = str(body.get("provider", "") or "")
    backend = classify_backend(returned_model, provider)
    check = spec.get("check")
    quality_ok = bool(check(text)) if callable(check) else None

    return Sample(
        prompt_id=prompt_id,
        ok=True,
        http_status=status,
        latency_ms=latency_ms,
        completion_tokens=comp,
        tokens_per_s=tps,
        returned_model=returned_model,
        provider=provider,
        backend=backend,
        quality_ok=quality_ok,
        preview=" ".join(text.split())[:120],
    )


def benchmark_model(alias: str, prompt_ids: list[str]) -> ModelReport:
    rep = ModelReport(alias=alias)
    latencies: list[int] = []
    tps_list: list[float] = []
    backends: set[str] = set()
    for prompt_id in prompt_ids:
        for _ in range(REPEATS):
            s = run_sample(alias, prompt_id)
            rep.samples.append(asdict(s))
            rep.runs += 1
            if s.ok:
                rep.ok_runs += 1
                latencies.append(s.latency_ms)
                if s.tokens_per_s:
                    tps_list.append(s.tokens_per_s)
                backends.add(s.backend)
                if s.backend == "zai":
                    rep.zai_runs += 1
                elif s.backend == "fallback":
                    rep.fallback_runs += 1
                if s.quality_ok is not None:
                    rep.quality_total += 1
                    rep.quality_ok += 1 if s.quality_ok else 0
            time.sleep(DELAY_SEC)
    if latencies:
        rep.median_latency_ms = int(statistics.median(latencies))
    if tps_list:
        rep.median_tokens_per_s = round(statistics.median(tps_list), 1)
    rep.backends_seen = sorted(backends)
    return rep


def _fidelity(rep: ModelReport) -> float:
    return rep.zai_runs / rep.ok_runs if rep.ok_runs else 0.0


def _quality(rep: ModelReport) -> float:
    return rep.quality_ok / rep.quality_total if rep.quality_total else 0.0


def rank(reports: list[ModelReport]) -> list[ModelReport]:
    """Ordena: fidelidade Z.AI desc, qualidade desc, latência asc."""
    return sorted(
        reports,
        key=lambda r: (
            -_fidelity(r),
            -_quality(r),
            r.median_latency_ms if r.median_latency_ms is not None else 10**9,
        ),
    )


def render_md(reports: list[ModelReport]) -> str:
    ranked = rank(reports)
    lines = [
        "# Benchmark Z.AI (Ruflo via LiteLLM)",
        "",
        f"- Gerado: {datetime.now(timezone.utc).isoformat()}",
        f"- Gateway: `{LITELLM_URL}`",
        f"- Repetições por prompt: {REPEATS} · Prompts: {', '.join(PROMPTS)}",
        "",
        "> **Fidelidade** = % de respostas servidas mesmo pela Z.AI (resto caiu em fallback).",
        "> **Qualidade** = % de respostas que passaram o check funcional do prompt.",
        "",
        "## Ranking",
        "",
        "| # | Alias | Fidelidade Z.AI | Qualidade | Latência mediana | tok/s | Backends vistos |",
        "|---|-------|-----------------|-----------|------------------|-------|-----------------|",
    ]
    for i, r in enumerate(ranked, 1):
        lat = f"{r.median_latency_ms} ms" if r.median_latency_ms is not None else "—"
        tps = f"{r.median_tokens_per_s}" if r.median_tokens_per_s is not None else "—"
        lines.append(
            f"| {i} | `{r.alias}` | {_fidelity(r)*100:.0f}% ({r.zai_runs}/{r.ok_runs}) | "
            f"{_quality(r)*100:.0f}% ({r.quality_ok}/{r.quality_total}) | {lat} | {tps} | "
            f"{', '.join(r.backends_seen) or '—'} |"
        )

    zai_ok = [r for r in ranked if _fidelity(r) >= 0.99 and r.ok_runs]
    lines += ["", "## Recomendação", ""]
    if zai_ok:
        best = min(zai_ok, key=lambda r: (-_quality(r), r.median_latency_ms or 10**9))
        lines.append(
            f"**`{best.alias}`** — 100% servido pela Z.AI, qualidade "
            f"{_quality(best)*100:.0f}%, latência mediana "
            f"{best.median_latency_ms} ms ({best.median_tokens_per_s or '—'} tok/s)."
        )
        others = [r.alias for r in zai_ok if r.alias != best.alias]
        if others:
            lines.append("")
            lines.append("Alternativas 100% Z.AI: " + ", ".join(f"`{a}`" for a in others) + ".")
    else:
        lines.append(
            "_Nenhum alias serviu 100% pela Z.AI no período — ver coluna de fallback "
            "(provável rate-limit/quota Z.AI a empurrar para fallback)._"
        )

    fallbacks = [r for r in ranked if r.fallback_runs]
    if fallbacks:
        lines += ["", "## ⚠ Aliases que caíram em fallback", ""]
        for r in fallbacks:
            seen = ", ".join(r.backends_seen)
            lines.append(f"- `{r.alias}`: {r.fallback_runs}/{r.ok_runs} fallback (backends: {seen})")

    lines += ["", "## Detalhe por modelo", ""]
    for r in ranked:
        lines.append(f"### `{r.alias}`")
        lines.append("")
        lines.append("| Prompt | ok | HTTP | ms | tok/s | backend | qualidade | preview |")
        lines.append("|--------|----|------|----|-------|---------|-----------|---------|")
        for s in r.samples:
            q = "—" if s["quality_ok"] is None else ("✓" if s["quality_ok"] else "✗")
            prev = (s["preview"] or s["error"]).replace("|", "\\|")[:60]
            lines.append(
                f"| {s['prompt_id']} | {'✓' if s['ok'] else '✗'} | {s['http_status']} | "
                f"{s['latency_ms']} | {s['tokens_per_s'] or '—'} | {s['backend']} | {q} | {prev} |"
            )
        lines.append("")
    return "\n".join(lines)


def main() -> int:
    if not LITELLM_KEY:
        print("ERRO: LITELLM_KEY vazio. Use: LITELLM_KEY=\"$(sh .claude/helpers/get-litellm-key.sh)\"", file=sys.stderr)
        return 2

    models_env = os.environ.get("ZAI_MODELS", "").strip()
    models = [m.strip() for m in models_env.split(",") if m.strip()] if models_env else list(DEFAULT_ZAI_MODELS)
    if os.environ.get("ZAI_INCLUDE_TRAPS", "0").lower() in ("1", "true", "yes"):
        models += TRAP_MODELS

    prompts_env = os.environ.get("BENCH_PROMPTS", "").strip()
    prompt_ids = [p.strip() for p in prompts_env.split(",") if p.strip()] if prompts_env else list(PROMPTS)
    unknown = [p for p in prompt_ids if p not in PROMPTS]
    if unknown:
        print(f"ERRO: prompts desconhecidos: {unknown}. Válidos: {list(PROMPTS)}", file=sys.stderr)
        return 2

    print(f"Z.AI benchmark → {LITELLM_URL}")
    print(f"Modelos ({len(models)}): {', '.join(models)}")
    print(f"Prompts: {', '.join(prompt_ids)} · repetições: {REPEATS}\n")

    reports: list[ModelReport] = []
    for alias in models:
        print(f"  • {alias} ...", end=" ", flush=True)
        rep = benchmark_model(alias, prompt_ids)
        reports.append(rep)
        print(
            f"ok {rep.ok_runs}/{rep.runs} · zai {rep.zai_runs} · fb {rep.fallback_runs} · "
            f"{rep.median_latency_ms or '—'} ms"
        )

    payload = {
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "litellm_url": LITELLM_URL,
        "repeats": REPEATS,
        "prompts": prompt_ids,
        "models": [asdict(r) for r in reports],
    }
    Path(OUT_JSON).parent.mkdir(parents=True, exist_ok=True)
    Path(OUT_JSON).write_text(json.dumps(payload, indent=2, ensure_ascii=False), encoding="utf-8")
    Path(OUT_MD).write_text(render_md(reports), encoding="utf-8")
    print(f"\nJSON: {OUT_JSON}")
    print(f"MD:   {OUT_MD}")

    ranked = rank(reports)
    print("\n=== TOP (fidelidade Z.AI / qualidade / latência) ===")
    for i, r in enumerate(ranked[:5], 1):
        print(
            f"  {i}. {r.alias} — fidelidade {_fidelity(r)*100:.0f}% · "
            f"qualidade {_quality(r)*100:.0f}% · {r.median_latency_ms or '—'} ms"
        )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
