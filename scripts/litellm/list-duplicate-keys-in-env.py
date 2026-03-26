#!/usr/bin/env python3
"""Lista chaves duplicadas em /opt/litellm/.env."""
from pathlib import Path
from collections import Counter

lines = Path("/opt/litellm/.env").read_text(encoding="utf-8").splitlines()
keys = []
for i, ln in enumerate(lines, 1):
    if "=" not in ln or ln.strip().startswith("#"):
        continue
    k = ln.split("=", 1)[0].strip()
    keys.append((i, k))

c = Counter(k for _, k in keys)
dups = {k: n for k, n in c.items() if n > 1}
if not dups:
    print("Sem chaves duplicadas.")
else:
    print("Duplicadas:", dups)
    for i, k in keys:
        if k in dups:
            print(f"  linha {i}: {k}")
