#!/usr/bin/env python3
"""Optimização llm-wiki: dedupe Cursor raw, feed Curator ingest, lint, síntese tópicos."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import shutil
from collections import defaultdict
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

SESSION_ID_RE = re.compile(
    r"([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})$", re.I
)
WIKILINK_RE = re.compile(r"\[\[([^\]|#]+)")
USER_QUERY_RE = re.compile(
    r"<user_query>\s*(.*?)\s*</user_query>", re.DOTALL | re.IGNORECASE
)
TOPIC_RULES: list[tuple[str, tuple[str, ...]]] = [
    ("Cursor e llm-wiki", ("llm-wiki", "segundo cérebro", "wiki-ingest", "curator")),
    ("LiteLLM e modelos", ("litellm", "virtual key",
     "quota", "fallback", "cursor-composer")),
    ("OpenClaw e gateway", ("openclaw", "telegram", "gateway", "jarvis")),
    ("Hermes e agency", ("hermes", "ct188", "curator", "makemoney", "agency")),
    ("Proxmox e infra AGL", ("proxmox", "pbs", "ct5", "aglsrv", "numa", "badblocks")),
    ("Six Repos e harness", ("six-repos", "harness",
     "ruflo", "dotfiles", "obsidian cli")),
    ("Media e ARR", ("sonarr", "radarr", "prowlarr", "jellyfin", "*arr")),
]


def utc_date() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%d")


def sha256_path(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def session_id_from_stem(stem: str) -> str | None:
    match = SESSION_ID_RE.search(stem)
    return match.group(1) if match else None


def host_priority(host: str) -> int:
    order = {"linux-root": 0, "agldv04": 1, "agldv03": 2,
             "agldv06": 3, "agldv12": 4, "flat": 5}
    return order.get(host, 9)


def collect_agent_mds(live: Path) -> dict[str, list[tuple[str, Path]]]:
    by_sid: dict[str, list[tuple[str, Path]]] = defaultdict(list)
    root = live / "agent-transcripts"
    if not root.is_dir():
        return by_sid
    for md in root.rglob("*.md"):
        if "/agent-transcripts/raw/" in md.as_posix():
            continue
        host = md.parent.name if md.parent != root else "flat"
        sid = session_id_from_stem(md.stem)
        if sid:
            by_sid[sid].append((host, md))
    return by_sid


def dedupe_and_migrate(wiki: Path, dry_run: bool) -> dict[str, int]:
    live = wiki / "raw/cursor/live"
    root = live / "agent-transcripts"
    stats = {"removed_dupes": 0, "migrated_flat": 0, "canonical": 0}
    by_sid = collect_agent_mds(live)

    for sid, entries in by_sid.items():
        ranked = sorted(entries, key=lambda x: (host_priority(x[0]), x[1]))
        canonical_host, canonical_path = ranked[0]
        stats["canonical"] += 1

        if canonical_host == "flat":
            target = root / "linux-root" / canonical_path.name
            if not target.exists():
                if not dry_run:
                    target.parent.mkdir(parents=True, exist_ok=True)
                    shutil.move(str(canonical_path), str(target))
                stats["migrated_flat"] += 1
                canonical_path = target
                canonical_host = "linux-root"

        for host, path in ranked[1:]:
            if path == canonical_path:
                continue
            if not dry_run:
                path.unlink(missing_ok=True)
                raw_jsonl = (
                    live
                    / "agent-transcripts/raw"
                    / host
                    / f"{path.stem}.jsonl"
                )
                raw_jsonl.unlink(missing_ok=True)
            stats["removed_dupes"] += 1

    return stats


def first_user_line(md_path: Path) -> str:
    text = md_path.read_text(encoding="utf-8", errors="replace")
    match = USER_QUERY_RE.search(text)
    if match:
        return match.group(1).strip().splitlines()[0][:120]
    parts = re.split(r"^## user\s*$", text, maxsplit=1, flags=re.MULTILINE)
    body = parts[1] if len(parts) > 1 else text
    for line in body.splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        if line == "[REDACTED]":
            continue
        return line[:120]
    stem = md_path.stem
    if "_" in stem:
        return stem.split("_", 1)[-1].replace("_", " ")[:120]
    return stem[:60]


def classify_topic(text: str) -> str:
    lower = text.lower()
    for label, keys in TOPIC_RULES:
        if any(k in lower for k in keys):
            return label
    return "AGL geral"


def feed_curator_ingest(wiki: Path, dry_run: bool) -> dict[str, int]:
    live = wiki / "raw/cursor/live"
    ingest_dir = wiki / "raw/wiki-ingest/cursor"
    queue_path = wiki / "raw/cursor/ingest-queue.jsonl"
    stats = {"stubs_created": 0, "stubs_skipped": 0}

    by_sid = collect_agent_mds(live)
    wiki_text = " ".join(
        p.read_text(encoding="utf-8", errors="replace")
        for p in (wiki / "wiki").rglob("*.md")
    )

    if not dry_run:
        ingest_dir.mkdir(parents=True, exist_ok=True)

    for sid, entries in sorted(by_sid.items()):
        ranked = sorted(entries, key=lambda x: host_priority(x[0]))
        _, md_path = ranked[0]
        rel = md_path.relative_to(wiki).as_posix()
        if sid in wiki_text or rel in wiki_text:
            stats["stubs_skipped"] += 1
            continue

        title = first_user_line(md_path)
        topic = classify_topic(title)
        stub_name = f"{utc_date()}-cursor-{sid[:8]}.md"
        stub_path = ingest_dir / stub_name
        if stub_path.exists():
            stats["stubs_skipped"] += 1
            continue

        body = f"""---
title: "Cursor — {title[:80]}"
tags: [cursor, ingest, agl, fonte]
confidence: medium
contested: false
source: cursor-agent-transcript
session_id: {sid}
topic: {topic}
sources:
  - {rel}
---

# Cursor — {title[:80]}

**Tópico sugerido:** {topic}

## Para o Curator (llm-wiki skill)

1. Ler fonte raw (não copiar transcript completo para `wiki/`).
2. Extrair **problema**, **decisões**, **solução**, **verificação**.
3. Criar ou actualizar página em `wiki/`; actualizar `index.md` e `log.md`.
4. Marcar `confidence: high` quando factos confirmados no repo.

## Fonte

- `{rel}`
"""
        if not dry_run:
            stub_path.write_text(body, encoding="utf-8")
        stats["stubs_created"] += 1

    if queue_path.is_file() and not dry_run:
        marker = ingest_dir / ".ingest-queue-processed.json"
        marker.write_text(
            json.dumps({"processed_at": utc_date(),
                       "sessions": len(by_sid)}, indent=2)
            + "\n",
            encoding="utf-8",
        )

    return stats


def wiki_titles(wiki: Path) -> set[str]:
    titles: set[str] = set()
    for p in (wiki / "wiki").rglob("*.md"):
        titles.add(p.stem)
        rel = p.relative_to(wiki / "wiki").with_suffix("")
        titles.add(rel.as_posix())
    return titles


def link_target_exists(wiki: Path, target: str, titles: set[str]) -> bool:
    if target in titles:
        return True
    if (wiki / "wiki" / f"{target}.md").is_file():
        return True
    return False


def lint_wiki(wiki: Path, dry_run: bool) -> dict[str, Any]:
    titles = wiki_titles(wiki)
    index_text = (
        wiki / "wiki/index.md").read_text(encoding="utf-8", errors="replace")
    broken: list[tuple[str, str]] = []
    orphans: list[str] = []

    skip_targets = {"Nome da Página", "wikilinks",
                    "index.md", "log.md", "CrewAI", "Phidata"}

    for md in (wiki / "wiki").rglob("*.md"):
        if md.name == "log.md":
            continue
        rel = md.relative_to(wiki / "wiki").as_posix()
        if md.stem not in index_text and md.name not in ("index.md", "log.md"):
            orphans.append(rel)
        for match in WIKILINK_RE.finditer(md.read_text(encoding="utf-8", errors="replace")):
            target = match.group(1).strip()
            if target in skip_targets:
                continue
            if not link_target_exists(wiki, target, titles):
                broken.append((rel, target))

    fixes = {
        ("makemoney01.md", "Hermes Agency Agents"): "Hermes Agent",
        ("Ecossistema Harness Router AGL.md", "llm-wiki"): "Cursor — segundo cérebro AGL",
    }
    # wikilinks com subpath usam stem relativo
    if not (wiki / "wiki/AI-Tools/installed-repos.md").is_file():
        fixes[("index.md", "AI-Tools/installed-repos")
              ] = "AI-Tools installed-repos"
    fixed = 0
    for (src, old), new in fixes.items():
        path = wiki / "wiki" / src
        if not path.is_file():
            continue
        content = path.read_text(encoding="utf-8")
        old_link = f"[[{old}]]"
        new_link = f"[[{new}]]"
        if old_link in content:
            if not dry_run:
                path.write_text(content.replace(
                    old_link, new_link), encoding="utf-8")
            fixed += 1

    lint_log = wiki / "raw/logs/wiki-lint"
    if not dry_run:
        lint_log.mkdir(parents=True, exist_ok=True)
        report = lint_log / \
            f"curator-{datetime.now(timezone.utc).strftime('%Y%m%d-%H%M%S')}.log"
        lines = [
            f"# Wiki lint {utc_date()}",
            f"broken_links: {len(broken)}",
            f"orphans_not_in_index: {len(orphans)}",
            f"auto_fixed: {fixed}",
            "",
            "## Broken links",
        ]
        for src, tgt in broken[:40]:
            lines.append(f"- {src} → [[{tgt}]]")
        lines.append("\n## Orphans (not in index.md)")
        for o in orphans[:40]:
            lines.append(f"- {o}")
        report.write_text("\n".join(lines) + "\n", encoding="utf-8")

    return {
        "broken_links": len(broken),
        "orphans": len(orphans),
        "fixed_links": fixed,
        "broken_sample": broken[:10],
    }


def synthesize_topic_hubs(wiki: Path, dry_run: bool) -> dict[str, int]:
    live = wiki / "raw/cursor/live"
    by_topic: dict[str, list[tuple[str, str, str]]] = defaultdict(list)
    by_sid = collect_agent_mds(live)

    for sid, entries in by_sid.items():
        ranked = sorted(entries, key=lambda x: host_priority(x[0]))
        host, md_path = ranked[0]
        title = first_user_line(md_path)
        topic = classify_topic(title)
        rel = md_path.relative_to(wiki).as_posix()
        by_topic[topic].append((sid[:8], title[:80], rel))

    stats = {"hubs_updated": 0}
    hub_dir = wiki / "wiki/Cursor"
    if not dry_run:
        hub_dir.mkdir(parents=True, exist_ok=True)

    for topic, sessions in sorted(by_topic.items(), key=lambda x: -len(x[1])):
        if len(sessions) < 2:
            continue
        safe = re.sub(r"[^\w\-]+", "-", topic).strip("-")[:50]
        hub_path = hub_dir / f"Síntese — {topic}.md"
        lines = [
            "---",
            f'title: "Síntese Cursor — {topic}"',
            "tags: [cursor, síntese, agl, ingest]",
            f"updated: {utc_date()}",
            "confidence: medium",
            "---",
            "",
            f"# Síntese Cursor — {topic}",
            "",
            f"Sessões AGL exportadas ({len(sessions)}). Ver raw para detalhe; Curator mantém factos em páginas dedicadas.",
            "",
            "| Sessão | Resumo | Fonte |",
            "|--------|--------|-------|",
        ]
        for sid8, title, rel in sessions[:25]:
            lines.append(f"| `{sid8}` | {title} | `{rel}` |")
        if len(sessions) > 25:
            lines.append(
                f"\n_+{len(sessions) - 25} sessões adicionais em raw/cursor/live._")
        lines.append(
            "\n## Relacionado\n\n- [[Cursor — segundo cérebro AGL]]\n- [[Cursor sync multi-host AGLDV]]\n")
        if not dry_run:
            hub_path.write_text("\n".join(lines), encoding="utf-8")
        stats["hubs_updated"] += 1

    return stats


def append_log(wiki: Path, summary: dict[str, Any], dry_run: bool) -> None:
    if dry_run:
        return
    log_path = wiki / "wiki/log.md"
    entry = f"""
## [{utc_date()}] lint | Curator optimize — Cursor raw + wiki-ingest

- Dedupe: removidos {summary.get('dedupe', {}).get('removed_dupes', 0)} duplicados multi-host; migrados {summary.get('dedupe', {}).get('migrated_flat', 0)} flat→linux-root.
- Ingest stubs: {summary.get('feed', {}).get('stubs_created', 0)} novos em `raw/wiki-ingest/cursor/`.
- Lint: {summary.get('lint', {}).get('broken_links', 0)} links quebrados, {summary.get('lint', {}).get('orphans', 0)} órfãos index; {summary.get('lint', {}).get('fixed_links', 0)} correcções auto.
- Hubs síntese: {summary.get('hubs', {}).get('hubs_updated', 0)} páginas em `wiki/Cursor/`.
"""
    with log_path.open("a", encoding="utf-8") as handle:
        handle.write(entry)


def update_index_orphans(wiki: Path, dry_run: bool) -> int:
    """Adiciona páginas Fonte/* órfãs à secção Fontes do index.md."""
    index_path = wiki / "wiki/index.md"
    text = index_path.read_text(encoding="utf-8")
    marker = "## Síntese e análises"
    if marker not in text:
        return 0
    new_rows: list[str] = []
    for md in sorted((wiki / "wiki").glob("Fonte - *.md")):
        stem = md.stem
        if stem in text:
            continue
        new_rows.append(
            f"| `wiki/{md.name}` | [[{stem}]] — página fonte dedicada. |"
        )
    if not new_rows:
        return 0
    block = "\n".join(new_rows) + "\n\n"
    if not dry_run:
        index_path.write_text(text.replace(
            marker, block + marker), encoding="utf-8")
    return len(new_rows)


def update_index_cursor_section(wiki: Path, dry_run: bool) -> None:
    index_path = wiki / "wiki/index.md"
    text = index_path.read_text(encoding="utf-8")
    hub_dir = wiki / "wiki/Cursor"
    if not hub_dir.is_dir():
        return
    marker = "| [[Cursor sync multi-host AGLDV]]"
    new_rows = []
    for hub in sorted(hub_dir.glob("Síntese — *.md")):
        row = f"| [[Cursor/{hub.stem}]] | Hub síntese sessões Cursor — {hub.stem.replace('Síntese — ', '')}. |"
        if hub.stem not in text:
            new_rows.append(row)
    if not new_rows or marker not in text:
        return
    if not dry_run:
        index_path.write_text(
            text.replace(marker, "\n".join(new_rows) + "\n" + marker),
            encoding="utf-8",
        )


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Wiki Curator optimize pipeline")
    parser.add_argument("--wiki", type=Path,
                        default=Path("/mnt/overpower/apps/dev/agl/llm-wiki"))
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()
    wiki = args.wiki.resolve()

    summary: dict[str, Any] = {}
    summary["dedupe"] = dedupe_and_migrate(wiki, args.dry_run)
    summary["feed"] = feed_curator_ingest(wiki, args.dry_run)
    summary["hubs"] = synthesize_topic_hubs(wiki, args.dry_run)
    if not args.dry_run:
        summary["index_orphans_added"] = update_index_orphans(
            wiki, args.dry_run)
        update_index_cursor_section(wiki, args.dry_run)
    summary["lint"] = lint_wiki(wiki, args.dry_run)
    if not args.dry_run:
        append_log(wiki, summary, args.dry_run)

    print(json.dumps(summary, indent=2, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
