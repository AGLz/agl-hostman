#!/usr/bin/env python3
"""Parse agent-os tasks.md phases into task groups for Ruflo dispatch."""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path


def slugify(title: str) -> str:
    s = title.lower().strip()
    s = re.sub(r"\([^)]*\)", "", s)
    s = re.sub(r"[^a-z0-9]+", "-", s)
    return s.strip("-")


def infer_worker(name: str, title: str) -> str:
    blob = f"{name} {title}".lower()
    if any(x in blob for x in ("valid", "prereq", "pre-", "research", "analys")):
        return "Researcher"
    if any(x in blob for x in ("verif", "test", "smoke", "check")):
        return "Tester"
    if any(x in blob for x in ("doc", "readme", "wiki", "update")):
        return "Documenter"
    if any(x in blob for x in ("architect", "design", "plan")):
        return "Architect"
    if any(x in blob for x in ("review", "audit")):
        return "Reviewer"
    return "Coder"


def parse_tasks_md(path: Path) -> dict:
    text = path.read_text(encoding="utf-8")
    lines = text.splitlines()
    groups: list[dict] = []
    current: dict | None = None

    phase_re = re.compile(r"^##\s+Phase\s+\d+:\s+(.+)$", re.I)

    for line in lines:
        m = phase_re.match(line.strip())
        if m:
            title = m.group(1).strip()
            name = slugify(title)
            current = {
                "name": name,
                "title": title,
                "ruflo_worker": infer_worker(name, title),
                "tasks_total": 0,
                "tasks_done": 0,
                "tasks_open": 0,
            }
            groups.append(current)
            continue
        if current is None:
            continue
        if re.match(r"^\s*-\s+\[[ xX]\]", line):
            current["tasks_total"] += 1
            if re.match(r"^\s*-\s+\[[xX]\]", line):
                current["tasks_done"] += 1
            else:
                current["tasks_open"] += 1

    return {
        "spec_tasks": str(path),
        "task_groups": groups,
        "summary": {
            "groups": len(groups),
            "tasks_total": sum(g["tasks_total"] for g in groups),
            "tasks_done": sum(g["tasks_done"] for g in groups),
            "tasks_open": sum(g["tasks_open"] for g in groups),
        },
    }


def main() -> int:
    if len(sys.argv) != 2:
        print("usage: parse-agent-os-tasks.py <tasks.md>", file=sys.stderr)
        return 2
    path = Path(sys.argv[1])
    if not path.is_file():
        print(f"ERRO: ficheiro em falta: {path}", file=sys.stderr)
        return 1
    print(json.dumps(parse_tasks_md(path), indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
