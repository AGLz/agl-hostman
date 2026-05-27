#!/usr/bin/env python3
"""Imprime comprimentos dos valores em /opt/litellm/.env (sem revelar segredos)."""
from pathlib import Path

p = Path("/opt/litellm/.env")
keys = (
    "OPENAI_API_KEY",
    "GEMINI_API_KEY",
    "ANTHROPIC_API_KEY",
    "LITELLM_MASTER_KEY",
)
data = {}
for ln in p.read_text(encoding="utf-8").splitlines():
    if "=" not in ln or ln.strip().startswith("#"):
        continue
    k, _, v = ln.partition("=")
    k, v = k.strip(), v.strip().strip('"')
    data[k] = len(v)

for k in keys:
    print(f"{k}: len={data.get(k, 'MISSING')}")
