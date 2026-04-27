#!/usr/bin/env python3
"""Lista SKILL.md com o mesmo nome de skill em mais de uma raiz."""
from __future__ import annotations

import os
from collections import defaultdict
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
HOME = Path.home()

ROOTS = [
    HOME / ".claude" / "skills",
    HOME / ".cursor" / "skills",
    HOME / ".cursor" / "skills-cursor",
    REPO / ".claude" / "skills",
    REPO / ".agents" / "skills",
]

by_name: dict[str, list[Path]] = defaultdict(list)

for root in ROOTS:
    if not root.is_dir():
        continue
    for p in root.rglob("SKILL.md"):
        if not p.is_file():
            continue
        name = p.parent.name
        by_name[name].append(p)

print("=== Skills com mesmo nome em mais de um caminho ===\n")
for name in sorted(by_name):
    paths = sorted(set(by_name[name]))
    if len(paths) < 2:
        continue
    print(f"{name} ({len(paths)}x):")
    for p in paths:
        print(f"  {p}")
    print()

gs = HOME / ".claude" / "skills" / "gstack"
if gs.is_dir():
    print("=== gstack: copias por host (ignorar no Cursor; usar ~/.cursor/skills/gstack*) ===\n")
    for h in ".factory .gbrain .hermes .kiro .openclaw .opencode .slate .agents".split():
        d = gs / h
        if d.is_dir():
            n = sum(1 for _ in d.rglob("SKILL.md"))
            if n:
                print(f"  {h}: {n} SKILL.md")
    cur = gs / ".cursor" / "skills"
    if cur.is_dir():
        n = sum(1 for _ in cur.rglob("SKILL.md"))
        print(f"  .cursor/skills: {n} SKILL.md (preferir para Cursor)")
