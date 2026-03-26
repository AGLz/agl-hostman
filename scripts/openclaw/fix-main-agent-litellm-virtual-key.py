#!/usr/bin/env python3
"""
Alinha auth do agent main com OpenClaw → LiteLLM (Virtual Key sk-...).

- auth-profiles.json: chave api_key = master literal (evita 401 no proxy).
- models.json: apiKey = marcador LITELLM_API_KEY (OpenClaw não expande "${LITELLM_MASTER_KEY}").

Reason: perfis com ZAI/Anthropic/OpenRouter keys reais como Bearer → 401 no proxy.
"""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path


def read_master() -> str:
    opt = Path("/opt/litellm/.env")
    if not opt.is_file():
        print("ERRO: /opt/litellm/.env inexistente", file=sys.stderr)
        sys.exit(1)
    text = opt.read_text(encoding="utf-8")
    m = re.search(r"^LITELLM_MASTER_KEY=(.+)$", text, re.MULTILINE)
    if not m:
        print("ERRO: LITELLM_MASTER_KEY não encontrado", file=sys.stderr)
        sys.exit(1)
    v = m.group(1).strip().strip('"').strip("'")
    if not v.startswith("sk-"):
        print("ERRO: LITELLM_MASTER_KEY deve começar por sk-", file=sys.stderr)
        sys.exit(1)
    return v


def load_json(p: Path) -> dict:
    raw = p.read_bytes()
    if raw.startswith(b"\xef\xbb\xbf"):
        raw = raw[3:]
    return json.loads(raw.decode("utf-8"))


def save_json(p: Path, data: dict) -> None:
    p.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


def main() -> int:
    master = read_master()
    agent_dir = Path("/root/.openclaw/agents/main/agent")
    ap = agent_dir / "auth-profiles.json"
    mp = agent_dir / "models.json"

    if ap.is_file():
        data = load_json(ap)
        profiles = data.setdefault("profiles", {})
        for _pid, prof in list(profiles.items()):
            if not isinstance(prof, dict):
                continue
            if prof.get("type") == "api_key" or prof.get("mode") == "api_key":
                prof["type"] = "api_key"
                prof["key"] = master
        # Reason: cooldown após 401 bloqueava zai até passar o período
        data["usageStats"] = {}
        save_json(ap, data)
        chmod600(ap)
        print(f"OK: {ap} — perfis api_key → Virtual Key LiteLLM")

    if mp.is_file():
        data = load_json(mp)
        provs = data.get("providers", {})
        if isinstance(provs, dict):
            for name, prov in provs.items():
                if name == "ollama":
                    continue
                if not isinstance(prov, dict):
                    continue
                if "apiKey" in prov and prov["apiKey"] == "ollama-local":
                    continue
                # Reason: OpenClaw só expande env por nome exacto (LITELLM_API_KEY); literal sk- aqui também funciona.
                prov["apiKey"] = "LITELLM_API_KEY"
        save_json(mp, data)
        chmod600(mp)
        print(f"OK: {mp} — apiKey → LITELLM_API_KEY (definir = master no openclaw.conf / litellm-gateway.env)")

    return 0


def chmod600(p: Path) -> None:
    try:
        p.chmod(0o600)
    except OSError:
        pass


if __name__ == "__main__":
    raise SystemExit(main())
