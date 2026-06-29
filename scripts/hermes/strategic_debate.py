#!/usr/bin/env python3
"""Debate estratégico no-logging para Jarvis (Opção B — AGLz Agency).

Duas personas (Advocate + Skeptic) com modelos free no-logging via LiteLLM,
seguidas de síntese neutra. Não carrega wiki/repos automaticamente — só o
contexto que o Jarvis passa explicitamente.
"""
from __future__ import annotations

import argparse
import json
import os
import re
import sys
import urllib.error
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

ADVOCATE_MODEL = os.environ.get(
    "STRATEGIC_DEBATE_ADVOCATE_MODEL", "or-qwen3-coder-free"
)
SKEPTIC_MODEL = os.environ.get("STRATEGIC_DEBATE_SKEPTIC_MODEL", "or-hermes-free")
SYNTHESIS_MODEL = os.environ.get(
    "STRATEGIC_DEBATE_SYNTHESIS_MODEL", "or-qwen3-next-free"
)
TIMEOUT = int(os.environ.get("STRATEGIC_DEBATE_TIMEOUT", "300"))

# Providers stealth que logam prompts — bloqueados salvo --allow-logging
LOGGING_MODEL_PATTERNS = (
    r"or-owl-alpha",
    r"or-nemotron",
    r"sonoma",
    r"horizon",
    r"nemotron-3",
)


def _load_dotenv(path: Path) -> dict[str, str]:
    out: dict[str, str] = {}
    if not path.is_file():
        return out
    for line in path.read_text(encoding="utf-8", errors="replace").splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        k, _, v = line.partition("=")
        out[k.strip()] = v.strip().strip('"')
    return out


def load_litellm() -> tuple[str, str]:
    """Return (base_url, api_key)."""
    home = Path(os.environ.get("HERMES_HOME", "/opt/data"))
    env = {**_load_dotenv(home / ".env"), **os.environ}
    base = env.get("LITELLM_URL") or ""
    token = (
        env.get("LITELLM_API_KEY")
        or env.get("OPENAI_API_KEY")
        or env.get("API_KEY")
        or ""
    )
    cfg_path = home / "config.yaml"
    if cfg_path.is_file():
        try:
            import yaml  # type: ignore

            cfg = yaml.safe_load(cfg_path.read_text(encoding="utf-8")) or {}
            m = cfg.get("model") or {}
            if not base:
                base = str(m.get("base_url") or "")
            cfg_key = str(m.get("api_key") or "")
            if cfg_key.startswith("sk-"):
                token = cfg_key
        except Exception:
            pass
    if not base:
        base = "http://100.125.249.8:4000"
    return base.rstrip("/"), token


def assert_no_logging_models(models: list[str], *, allow_logging: bool) -> None:
    if allow_logging:
        return
    for model in models:
        low = model.lower()
        for pat in LOGGING_MODEL_PATTERNS:
            if re.search(pat, low):
                raise SystemExit(
                    f"ERRO: modelo '{model}' pode logar prompts. "
                    "Use modelos no-logging (or-qwen3-coder-free, or-hermes-free, "
                    "or-qwen3-next-free) ou --allow-logging para opt-in explícito."
                )


def chat(
    base: str,
    token: str,
    model: str,
    prompt: str,
    *,
    max_tokens: int = 1800,
    temperature: float = 0.45,
    dry_run: bool = False,
) -> str:
    if dry_run:
        return f"[DRY-RUN {model}] prompt_len={len(prompt)}"
    body = json.dumps(
        {
            "model": model,
            "messages": [{"role": "user", "content": prompt}],
            "max_tokens": max_tokens,
            "temperature": temperature,
        }
    ).encode()
    req = urllib.request.Request(
        f"{base}/v1/chat/completions",
        data=body,
        headers={
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/json",
        },
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=TIMEOUT) as resp:
            data = json.loads(resp.read().decode())
    except urllib.error.HTTPError as e:
        detail = e.read().decode(errors="replace")[:600]
        raise RuntimeError(f"LiteLLM HTTP {e.code} ({model}): {detail}") from e
    return str(data["choices"][0]["message"]["content"]).strip()


ADVOCATE_SYSTEM = """Tu és o **Advocate** num debate estratégico da AGLz AI Agency.
Defendes a direcção proposta com argumentos fortes, oportunidades e fit com capacidades
existentes (Hermes, LiteLLM, llm-wiki, agl-hostman, agency-agents).
Tom: analítico, pt-BR, acionável. Não inventes métricas — marca [VALIDAR]."""


SKEPTIC_SYSTEM = """Tu és o **Skeptic** num debate estratégico da AGLz AI Agency.
Desafias premissas, expões riscos, custos ocultos, alternativas e falácias.
Tom: construtivo mas rigoroso, pt-BR. Não inventes dados — marca [VALIDAR]."""


SYNTHESIS_SYSTEM = """Tu és o **facilitador de síntese** após debate Advocate vs Skeptic (AGLz).
Produz recomendação equilibrada para o CEO Jarvis: o que fazer, o que adiar, o que validar.
Inclui 3–5 bullets "Decisão humana necessária" quando aplicável. pt-BR, conciso."""


def build_debate(
    question: str,
    context: str,
    *,
    base: str,
    token: str,
    dry_run: bool,
) -> dict[str, str]:
    ctx_block = context.strip() or "(sem contexto adicional)"
    shared = f"""## Questão estratégica
{question.strip()}

## Contexto (fornecido pelo Jarvis)
{ctx_block}
"""

    advocate_prompt = f"""{ADVOCATE_SYSTEM}

{shared}

## Tarefa
Argumenta **a favor** da direcção implícita na questão (ou da melhor interpretação estratégica).
Estrutura: 1) Tese 2) Oportunidade 3) Fit AGLz 4) Próximos passos 48h (máx ~900 palavras)."""

    advocate = chat(
        base, token, ADVOCATE_MODEL, advocate_prompt, dry_run=dry_run
    )

    skeptic_prompt = f"""{SKEPTIC_SYSTEM}

{shared}

## Posição do Advocate
{advocate}

## Tarefa
Contra-argumenta: riscos, premissas frágeis, alternativas, custo de oportunidade.
Estrutura: 1) Contra-tese 2) Riscos top 3) O que o Advocate subestima 4) Condições para mudar de ideia (máx ~900 palavras)."""

    skeptic = chat(base, token, SKEPTIC_MODEL, skeptic_prompt, dry_run=dry_run)

    synthesis_prompt = f"""{SYNTHESIS_SYSTEM}

{shared}

## Advocate ({ADVOCATE_MODEL})
{advocate}

## Skeptic ({SKEPTIC_MODEL})
{skeptic}

## Tarefa
Síntese em markdown:
### Recomendação
### Consenso
### Divergências materiais
### Decisão humana necessária (bullets)
### Próximo passo concreto (48h)
(máx ~700 palavras)"""

    synthesis = chat(
        base, token, SYNTHESIS_MODEL, synthesis_prompt, dry_run=dry_run
    )

    return {
        "advocate": advocate,
        "skeptic": skeptic,
        "synthesis": synthesis,
    }


def render_markdown(question: str, context: str, parts: dict[str, str]) -> str:
    ts = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M UTC")
    title = question.strip().split("\n")[0][:120]
    return f"""# Debate estratégico — {title}

_Gerado: {ts} · Advocate: `{ADVOCATE_MODEL}` · Skeptic: `{SKEPTIC_MODEL}` · Síntese: `{SYNTHESIS_MODEL}` · política: no-logging_

## Questão

{question.strip()}

## Contexto

{context.strip() or "_(nenhum)_"}

## Advocate

{parts["advocate"]}

## Skeptic

{parts["skeptic"]}

## Síntese

{parts["synthesis"]}
"""


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Debate estratégico no-logging (Jarvis / AGLz)"
    )
    parser.add_argument(
        "--question", "-q", required=True, help="Questão ou decisão estratégica"
    )
    parser.add_argument(
        "--context",
        "-c",
        default="",
        help="Contexto adicional (wiki, pipeline, constraints)",
    )
    parser.add_argument(
        "--context-file", help="Ficheiro com contexto (UTF-8)"
    )
    parser.add_argument("--output", "-o", help="Gravar markdown neste path")
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Não chama LiteLLM (smoke/test)",
    )
    parser.add_argument(
        "--allow-logging",
        action="store_true",
        help="Permite modelos que logam (opt-in; não usar com dados AGL)",
    )
    parser.add_argument(
        "--json", action="store_true", help="Emitir JSON em stdout"
    )
    args = parser.parse_args()

    context = args.context
    if args.context_file:
        context = Path(args.context_file).read_text(encoding="utf-8")

    models = [ADVOCATE_MODEL, SKEPTIC_MODEL, SYNTHESIS_MODEL]
    assert_no_logging_models(models, allow_logging=args.allow_logging)

    base, token = load_litellm()
    if not token and not args.dry_run:
        print("ERRO: API key LiteLLM em falta", file=sys.stderr)
        return 1

    parts = build_debate(
        args.question, context, base=base, token=token, dry_run=args.dry_run
    )
    md = render_markdown(args.question, context, parts)

    if args.output:
        out = Path(args.output)
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_text(md + "\n", encoding="utf-8")
        print(f"OK debate → {out}")

    if args.json:
        print(
            json.dumps(
                {
                    "question": args.question,
                    "models": {
                        "advocate": ADVOCATE_MODEL,
                        "skeptic": SKEPTIC_MODEL,
                        "synthesis": SYNTHESIS_MODEL,
                    },
                    "parts": parts,
                    "markdown": md,
                },
                ensure_ascii=False,
                indent=2,
            )
        )
    elif not args.output:
        print(md)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
