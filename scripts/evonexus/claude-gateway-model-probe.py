#!/usr/bin/env python3
"""
Diagnóstico EvoNexus: corre `claude -p` com vários --model no gateway Anthropic (LiteLLM),
com --debug-file por modelo. Destinado a correr **dentro** do contentor `evonexus-dashboard`
(cwd típico /workspace).

Uso (no CT242, após copiar para o contentor):
  docker exec -w /workspace evonexus-dashboard python3 /tmp/claude-gateway-model-probe.py

Não imprime API keys — só resumo de exit code e tamanho da saída.
"""
from __future__ import annotations

import json
import os
import subprocess
import sys
import time
from pathlib import Path

PROVIDERS = Path("/workspace/config/providers.json")
WORKDIR = Path("/workspace")
DEBUG_DIR = Path("/tmp/claude-probe-logs")
# Aliases esperados no LiteLLM AGL (`config/litellm/config.yaml`). Passar outros nomes via argv.
DEFAULT_MODELS = (
    "glm-5-turbo",
    "glm-5",
    "glm-4.7",
    "glm-4.7-flash",
    "gpt-5.5",
    "gpt-5.4",
    "gpt-5.4-mini",
    "claude-opus-4-7",
    "deepseek-4",
    "qwen3.5-plus",
    "qwen-coder",
)


def load_anthropic_env() -> dict[str, str]:
    if not PROVIDERS.exists():
        raise SystemExit(f"Missing {PROVIDERS}")
    cfg = json.loads(PROVIDERS.read_text())
    ev = cfg.get("providers", {}).get("anthropic", {}).get("env_vars") or {}
    out: dict[str, str] = {}
    for k, v in ev.items():
        if isinstance(v, str) and v.strip():
            out[k] = v.strip()
    if not out.get("ANTHROPIC_AUTH_TOKEN") and not out.get("ANTHROPIC_API_KEY"):
        raise SystemExit("anthropic env_vars: missing ANTHROPIC_AUTH_TOKEN / ANTHROPIC_API_KEY")
    return out


def _timeout_seconds(model: str) -> int:
    m = model.lower()
    if "opus" in m or "gpt-5.5" in m or "gpt-5.4" in m:
        return 420
    return 300


def run_one(
    model: str,
    prompt: str,
    extra_args: list[str],
    env: dict[str, str],
    log_path: Path,
) -> tuple[int, str, str]:
    log_path.parent.mkdir(parents=True, exist_ok=True)
    cmd = [
        "claude",
        "-p",
        prompt,
        "--model",
        model,
        "--dangerously-skip-permissions",
        "--permission-mode",
        "bypassPermissions",
        "--debug-file",
        str(log_path),
        "--no-session-persistence",
        *extra_args,
    ]
    t0 = time.time()
    timeout_sec = _timeout_seconds(model)
    p = subprocess.run(
        cmd,
        cwd=str(WORKDIR),
        env={**os.environ, **env, "FORCE_COLOR": "0", "TERM": "dumb"},
        capture_output=True,
        text=True,
        timeout=timeout_sec,
    )
    elapsed = time.time() - t0
    out = (p.stdout or "")[:4000]
    err = (p.stderr or "")[:4000]
    meta = f"elapsed_s={elapsed:.1f}\n"
    return p.returncode, out, meta + err


def main() -> None:
    models = list(DEFAULT_MODELS)
    if len(sys.argv) > 1:
        models = sys.argv[1:]

    env = load_anthropic_env()
    DEBUG_DIR.mkdir(parents=True, exist_ok=True)

    # No EvoNexus o cwd é /workspace (repo Atlas), não agl-hostman — evitar paths inexistentes.
    prompts: list[tuple[str, str, list[str]]] = [
        (
            "no_tools",
            "Responde exactamente uma linha: PROBE_OK",
            [],
        ),
        (
            "read_claude_md",
            "Usa a ferramenta Read uma vez no ficheiro CLAUDE.md na raiz do workspace. "
            "Responde em português com 2–4 frases: primeiras ideias do ficheiro (título ou propósito).",
            [],
        ),
        (
            "agent_jarvis",
            "Em português, uma frase: confirmas que estás a operar como o agente Jarvis nesta sessão?",
            ["--agent", "jarvis"],
        ),
    ]
    if os.environ.get("QUICK_PROBE") == "1":
        prompts = [prompts[0]]

    print("=== Claude gateway model probe ===")
    print(f"models: {', '.join(models)}")
    print(f"ANTHROPIC_BASE_URL set: {bool(env.get('ANTHROPIC_BASE_URL'))}")
    print()

    for pname, prompt, extra in prompts:
        print(f"--- prompt={pname} ---")
        for model in models:
            log = DEBUG_DIR / f"{pname}-{model.replace('/', '_')}.log"
            try:
                code, out, err = run_one(model, prompt, extra, env, log)
                olen = len(out or "")
                elen = len(err or "")
                preview = (out or "").replace("\n", " ")[:120]
                status = "OK" if code == 0 and olen > 0 else "FAIL"
                print(f"  {model:32} exit={code:3} stdout={olen:5} stderr_meta={elen:4} [{status}] {preview!r}")
            except subprocess.TimeoutExpired:
                print(f"  {model:32} TIMEOUT (>{_timeout_seconds(model)}s) log={log}")
            except Exception as e:
                print(f"  {model:32} ERROR {type(e).__name__}: {e}")
        print()

    print(f"Debug logs under: {DEBUG_DIR}")
    print("Rever no contentor: grep -i error /tmp/claude-probe-logs/*.log | tail -40")


if __name__ == "__main__":
    main()
