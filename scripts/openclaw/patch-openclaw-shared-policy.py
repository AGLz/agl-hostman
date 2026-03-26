#!/usr/bin/env python3
"""
Aplica políticas partilhadas OpenClaw (alinhadas aglwk45) num openclaw.json:
  - agents.defaults.compaction (safeguard + zai/glm-4.7-flash)
  - agents.defaults.memorySearch → LiteLLM /v1/ + mesma apiKey que providers (fallback local)
  - tools.web.search → duckduckgo + limites de cache/timeout
  - plugins.entries.duckduckgo (região configurável)
  - plugins.entries.brave.enabled → false se existir entrada brave
  - agents.list: substitui openai/gpt-4.1 por zai/glm-4.7-flash em primary/fallbacks
  - channels.telegram.commands.native → false se existir telegram

Uso:
  python3 patch-openclaw-shared-policy.py /root/.openclaw/openclaw.json

Ambiente opcional:
  OPENCLAW_DDG_REGION=pt-pt
  OPENCLAW_LITELLM_V1_BASE=https://proxy.example:4000/v1/  (sobrepor URL de embeddings)
  OPENCLAW_LITELLM_MASTER_KEY=sk-...  (se não existir apiKey nos providers)
"""
from __future__ import annotations

import json
import os
import shutil
import sys
import time
from pathlib import Path
from typing import Any


def _read_json(path: Path) -> dict[str, Any]:
    raw = path.read_bytes()
    if raw.startswith(b"\xef\xbb\xbf"):
        raw = raw[3:]
    return json.loads(raw.decode("utf-8"))


def _write_json(path: Path, data: dict[str, Any]) -> None:
    path.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


def _infer_master_key(data: dict[str, Any]) -> str:
    env = os.environ.get("OPENCLAW_LITELLM_MASTER_KEY", "").strip()
    if env:
        return env
    providers = data.get("models", {}).get("providers", {})
    for prov in providers.values():
        if not isinstance(prov, dict):
            continue
        k = prov.get("apiKey")
        if isinstance(k, str) and k.startswith("sk-"):
            return k
    return "sk-your-secure-master-key"


def _infer_litellm_v1_base(data: dict[str, Any]) -> str:
    env = os.environ.get("OPENCLAW_LITELLM_V1_BASE", "").strip()
    if env:
        e = env.rstrip("/")
        if e.endswith("/v1"):
            return e + "/"
        return e + "/v1/"
    zai = data.get("models", {}).get("providers", {}).get("zai", {})
    base = zai.get("baseUrl", "") if isinstance(zai, dict) else ""
    base = str(base).rstrip("/")
    if base:
        return base + "/v1/"
    return "http://100.94.221.87:4000/v1/"


def _patch_agent_models(agent: dict[str, Any]) -> None:
    m = agent.get("model")
    if not isinstance(m, dict):
        return
    if m.get("primary") == "openai/gpt-4.1":
        m["primary"] = "zai/glm-4.7-flash"
    fbs = m.get("fallbacks")
    if isinstance(fbs, list):
        m["fallbacks"] = [
            "zai/glm-4.7-flash" if x == "openai/gpt-4.1" else x for x in fbs
        ]


def main() -> int:
    if len(sys.argv) != 2:
        print(__doc__.strip(), file=sys.stderr)
        return 2
    target = Path(sys.argv[1])
    if not target.is_file():
        print(f"ERRO: ficheiro inexistente: {target}", file=sys.stderr)
        return 1

    data = _read_json(target)
    ddg_region = os.environ.get("OPENCLAW_DDG_REGION", "pt-pt").strip() or "pt-pt"
    master = _infer_master_key(data)
    v1 = _infer_litellm_v1_base(data)
    if not v1.endswith("/"):
        v1 += "/"

    defaults = data.setdefault("agents", {}).setdefault("defaults", {})
    comp = defaults.setdefault("compaction", {})
    comp["mode"] = "safeguard"
    comp["model"] = "zai/glm-4.7-flash"

    defaults["memorySearch"] = {
        "provider": "openai",
        "model": "text-embedding-3-small",
        "remote": {"baseUrl": v1, "apiKey": master},
        "fallback": "local",
    }

    tw = data.setdefault("tools", {}).setdefault("web", {})
    tw["search"] = {
        "enabled": True,
        "provider": "duckduckgo",
        "maxResults": 5,
        "timeoutSeconds": 30,
        "cacheTtlMinutes": 15,
    }

    plugins = data.setdefault("plugins", {}).setdefault("entries", {})
    plugins["duckduckgo"] = {
        "enabled": True,
        "config": {"webSearch": {"region": ddg_region, "safeSearch": "moderate"}},
    }
    if "brave" in plugins and isinstance(plugins["brave"], dict):
        plugins["brave"]["enabled"] = False

    alist = data.get("agents", {}).get("list")
    if isinstance(alist, list):
        for agent in alist:
            if isinstance(agent, dict):
                _patch_agent_models(agent)

    ch = data.get("channels")
    if isinstance(ch, dict):
        tg = ch.get("telegram")
        if isinstance(tg, dict):
            tg.setdefault("commands", {})["native"] = False

    backup = target.with_suffix(target.suffix + f".bak.{int(time.time())}")
    shutil.copy2(target, backup)
    _write_json(target, data)
    print(f"OK: {target}")
    print(f"     backup: {backup}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
