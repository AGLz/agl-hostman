#!/usr/bin/env python3
"""
Smoke test: vários --agent com o ou mais modelos (env Anthropic a partir de providers.json).
Correr dentro de evonexus-dashboard, cwd /workspace.

Uso:
  python3 claude-agents-smoke.py [modelo] [agente ...]
  EVONEXUS_SMOKE_MODELS="glm-5,qwen3.5-plus" EVONEXUS_SMOKE_AGENTS="jarvis,atlas-project" \\
    EVONEXUS_SMOKE_PROMPT="..." python3 claude-agents-smoke.py

Se EVONEXUS_SMOKE_MODELS estiver definido, lista separada por vírgula; senão argv[1] ou qwen3.5-plus.
Se EVONEXUS_SMOKE_AGENTS estiver definido, vírgulas; senão argv[2:] ou default atlas-project,hawk-debugger,jarvis.
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
DEFAULT_AGENTS = ("atlas-project", "hawk-debugger", "jarvis")
DEFAULT_PROMPT = (
    "Em português, responde em **uma frase**: qual é o teu papel principal neste workspace?"
)


def load_anthropic_env() -> dict[str, str]:
    cfg = json.loads(PROVIDERS.read_text())
    ev = cfg.get("providers", {}).get("anthropic", {}).get("env_vars") or {}
    return {k: v.strip() for k, v in ev.items() if isinstance(v, str) and v.strip()}


def _split_csv(key: str) -> list[str]:
    raw = (os.environ.get(key) or "").strip()
    if not raw:
        return []
    return [x.strip() for x in raw.split(",") if x.strip()]


def main() -> None:
    prompt = (os.environ.get("EVONEXUS_SMOKE_PROMPT") or "").strip() or DEFAULT_PROMPT
    models = _split_csv("EVONEXUS_SMOKE_MODELS")
    if not models:
        models = [sys.argv[1]] if len(sys.argv) > 1 else ["qwen3.5-plus"]
    if not models:
        models = ["qwen3.5-plus"]
    agents = _split_csv("EVONEXUS_SMOKE_AGENTS")
    if not agents:
        agents = list(sys.argv[2:]) if len(sys.argv) > 2 else list(DEFAULT_AGENTS)

    env = load_anthropic_env()
    print(f"models={', '.join(models)}")
    print(f"agents={', '.join(agents)}")
    print(f"prompt={prompt[:100]}{'…' if len(prompt) > 100 else ''}")

    for model in models:
        print(f"\n=== model={model} ===")
        for agent in agents:
            log = Path(f"/tmp/claude-agent-smoke-{model.replace('/', '_')}-{agent}.log")
            cmd = [
                "claude",
                "-p",
                prompt,
                "--agent",
                agent,
                "--model",
                model,
                "--dangerously-skip-permissions",
                "--permission-mode",
                "bypassPermissions",
                "--no-session-persistence",
                "--debug-file",
                str(log),
            ]
            t0 = time.time()
            p = subprocess.run(
                cmd,
                cwd=str(WORKDIR),
                env={**os.environ, **env, "TERM": "dumb", "FORCE_COLOR": "0"},
                capture_output=True,
                text=True,
                timeout=420,
            )
            dt = time.time() - t0
            out = (p.stdout or "").replace("\n", " ")[:220]
            print(f"  {agent:20} exit={p.returncode:3} {dt:5.1f}s {out!r}")


if __name__ == "__main__":
    main()
