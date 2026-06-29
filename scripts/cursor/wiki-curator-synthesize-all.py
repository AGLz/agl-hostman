#!/usr/bin/env python3
"""Síntese curada em lote: raw/cursor/live → wiki/2026-*-cursor-{sid8}.md."""

from __future__ import annotations

import argparse
import json
import re
from collections import defaultdict
from datetime import datetime, timezone
from pathlib import Path

import importlib.util


def _load_optimize():
    path = Path(__file__).resolve().parent / "wiki-curator-optimize.py"
    spec = importlib.util.spec_from_file_location(
        "wiki_curator_optimize", path)
    mod = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(mod)
    return mod


_opt = _load_optimize()
TOPIC_RULES = _opt.TOPIC_RULES
classify_topic = _opt.classify_topic
collect_agent_mds = _opt.collect_agent_mds
first_user_line = _opt.first_user_line
host_priority = _opt.host_priority
utc_date = _opt.utc_date

SKIP_QUERY_PREFIXES = (
    "the above subagent",
    "briefly inform the user",
    "multi-task result synthesis",
)


def is_real_user_query(q: str) -> bool:
    lower = q.strip().lower()
    if not lower or lower == "[redacted]":
        return False
    return not any(lower.startswith(p) for p in SKIP_QUERY_PREFIXES)


USER_QUERY_RE = re.compile(
    r"<user_query>\s*(.*?)\s*</user_query>", re.DOTALL | re.IGNORECASE
)
CMD_BLOCK_RE = re.compile(r"```(?:bash|sh|shell)?\n(.*?)```", re.DOTALL)
TABLE_LINE_RE = re.compile(r"^\|.+\|$")
HEADING_RE = re.compile(r"^#{1,3}\s+.+")

DEDICATED_PAGES: dict[str, str] = {
    "8e4fe6a0": "[[makemoney01]]",
    "a58944c9": "[[AGL Ollama Benchmark GPU vs CPU]]",
    "3a9537db": "[[Hermes Curator Agent]]",
    "3b3d2ce9": "[[Cursor — segundo cérebro AGL]]",
}


def all_user_queries(text: str) -> list[str]:
    queries: list[str] = []
    for match in USER_QUERY_RE.finditer(text):
        q = match.group(1).strip()
        if q and is_real_user_query(q):
            queries.append(q[:500])
    parts = re.split(r"^## user\s*$", text, flags=re.MULTILINE)
    for part in parts[1:]:
        chunk = re.split(r"^## assistant\s*$", part,
                         maxsplit=1, flags=re.MULTILINE)[0]
        chunk = chunk.strip()
        if chunk and is_real_user_query(chunk) and chunk not in queries:
            queries.append(chunk[:500])
    return queries[:5]


def extract_assistant_blocks(text: str) -> list[str]:
    blocks: list[str] = []
    current: list[str] = []
    in_assistant = False
    for line in text.splitlines():
        if line.startswith("## user"):
            if in_assistant and current:
                blocks.append("\n".join(current).strip())
            current = []
            in_assistant = False
            continue
        if line.startswith("## assistant"):
            if in_assistant and current:
                blocks.append("\n".join(current).strip())
            current = []
            in_assistant = True
            continue
        if not in_assistant:
            continue
        if line.strip() == "[REDACTED]":
            continue
        current.append(line)
    if in_assistant and current:
        blocks.append("\n".join(current).strip())
    return [b for b in blocks if len(b) > 80]


def score_block(block: str) -> int:
    score = len(block)
    if TABLE_LINE_RE.search(block):
        score += 500
    if HEADING_RE.search(block):
        score += 200
    if "```" in block:
        score += 100
    return score


def pick_summary(blocks: list[str], max_chars: int = 3500) -> str:
    if not blocks:
        return ""
    ranked = sorted(blocks, key=score_block, reverse=True)
    chosen: list[str] = []
    total = 0
    for block in ranked[:4]:
        if total + len(block) > max_chars and chosen:
            break
        chosen.append(block)
        total += len(block)
    body = "\n\n---\n\n".join(chosen)
    if len(body) > max_chars:
        body = body[: max_chars - 20].rstrip() + "\n\n…"
    return body


def extract_commands(text: str, limit: int = 8) -> list[str]:
    cmds: list[str] = []
    for match in CMD_BLOCK_RE.finditer(text):
        for line in match.group(1).splitlines():
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            if line not in cmds:
                cmds.append(line)
            if len(cmds) >= limit:
                return cmds
    return cmds


def wiki_page_path(wiki: Path, sid8: str, force_date: str | None) -> Path:
    existing = list((wiki / "wiki").glob(f"*-cursor-{sid8}.md"))
    if existing:
        return existing[0]
    date = force_date or utc_date()
    return wiki / "wiki" / f"{date}-cursor-{sid8}.md"


def build_page(
    sid: str,
    title: str,
    topic: str,
    rel: str,
    queries: list[str],
    summary: str,
    commands: list[str],
) -> str:
    sid8 = sid[:8]
    dedicated = DEDICATED_PAGES.get(sid8, "")
    lines = [
        "---",
        f'title: "Cursor — {title[:80]}"',
        "tags: [cursor, ingest, agl, síntese]",
        f"updated: {utc_date()}",
        "confidence: medium",
        "contested: false",
        f"session_id: {sid}",
        f"topic: {topic}",
        "sources:",
        f"  - {rel}",
        "---",
        "",
        f"# Cursor — {title[:80]}",
        "",
        f"**Tópico:** {topic} · **Sessão:** `{sid8}`",
        "",
    ]
    if dedicated:
        lines += [f"**Página dedicada:** {dedicated}", ""]

    lines += ["## Problema / pedido", ""]
    if queries:
        for i, q in enumerate(queries, 1):
            prefix = f"{i}. " if len(queries) > 1 else ""
            lines.append(f"{prefix}{q.replace(chr(10), ' ')[:400]}")
            lines.append("")
    else:
        lines += ["_(pedido não extraído — ver fonte raw)_", ""]

    lines += ["## Solução / factos", ""]
    if summary:
        lines.append(summary)
        lines.append("")
    else:
        lines += [
            "_Síntese automática sem blocos substanciais no export — consultar fonte raw._",
            "",
        ]

    if commands:
        lines += ["## Comandos (extraídos)", "", "```bash"]
        lines.extend(commands[:8])
        lines += ["```", ""]

    lines += [
        "## Fonte",
        "",
        f"- `{rel}`",
        "",
        "## Relacionado",
        "",
        f"- [[Cursor/Síntese — {topic}]]",
        "- [[Cursor — segundo cérebro AGL]]",
        "",
    ]
    if dedicated:
        lines.append(f"- {dedicated}")
        lines.append("")
    return "\n".join(lines)


def synthesize_all(wiki: Path, dry_run: bool, force: bool) -> dict[str, int]:
    by_sid = collect_agent_mds(wiki / "raw/cursor/live")
    stats = {"written": 0, "skipped": 0, "empty": 0}

    for sid, entries in sorted(by_sid.items()):
        ranked = sorted(entries, key=lambda x: host_priority(x[0]))
        _, md_path = ranked[0]
        rel = md_path.relative_to(wiki).as_posix()
        text = md_path.read_text(encoding="utf-8", errors="replace")
        title = first_user_line(md_path)
        topic = classify_topic(f"{title} {text[:8000]}")
        queries = all_user_queries(text)
        if not queries and title:
            queries = [title]
        blocks = extract_assistant_blocks(text)
        summary = pick_summary(blocks)
        commands = extract_commands(text)
        out = wiki_page_path(wiki, sid[:8], None)

        if out.is_file() and not force:
            existing = out.read_text(encoding="utf-8", errors="replace")
            if "## Solução / factos" in existing and "[REDACTED]" not in existing:
                if len(existing) > 800 and "Para o Curator" not in existing:
                    stats["skipped"] += 1
                    continue

        if not summary and not commands:
            stats["empty"] += 1

        body = build_page(sid, title, topic, rel, queries, summary, commands)
        if not dry_run:
            out.write_text(body, encoding="utf-8")
        stats["written"] += 1

    return stats


def rebuild_hubs(wiki: Path, dry_run: bool) -> int:
    by_sid = collect_agent_mds(wiki / "raw/cursor/live")
    by_topic: dict[str, list[tuple[str, str, str]]] = defaultdict(list)
    for sid, entries in by_sid.items():
        ranked = sorted(entries, key=lambda x: host_priority(x[0]))
        _, md_path = ranked[0]
        text = md_path.read_text(encoding="utf-8", errors="replace")
        title = first_user_line(md_path)
        topic = classify_topic(f"{title} {text[:8000]}")
        rel = md_path.relative_to(wiki).as_posix()
        wiki_link = f"[[{wiki_page_path(wiki, sid[:8], None).stem}]]"
        by_topic[topic].append((sid[:8], title[:70], wiki_link))

    hub_dir = wiki / "wiki/Cursor"
    count = 0
    if not dry_run:
        hub_dir.mkdir(parents=True, exist_ok=True)

    for topic, sessions in sorted(by_topic.items(), key=lambda x: -len(x[1])):
        hub_path = hub_dir / f"Síntese — {topic}.md"
        lines = [
            "---",
            f'title: "Síntese Cursor — {topic}"',
            "tags: [cursor, síntese, agl, ingest]",
            f"updated: {utc_date()}",
            f"confidence: medium",
            "---",
            "",
            f"# Síntese Cursor — {topic}",
            "",
            f"**{len(sessions)}** sessões exportadas. Páginas curadas por sessão + raw para detalhe.",
            "",
            "| Sessão | Resumo | Wiki |",
            "|--------|--------|------|",
        ]
        for sid8, title, wlink in sorted(sessions, key=lambda x: x[1]):
            safe_title = title.replace("|", "/")[:65]
            lines.append(f"| `{sid8}` | {safe_title} | {wlink} |")
        lines += [
            "",
            "## Relacionado",
            "",
            "- [[Cursor — segundo cérebro AGL]]",
            "- [[Cursor sync multi-host AGLDV]]",
            "",
        ]
        if not dry_run:
            hub_path.write_text("\n".join(lines), encoding="utf-8")
        count += 1
    return count


def append_log(wiki: Path, stats: dict[str, int], hubs: int) -> None:
    log_path = wiki / "wiki/log.md"
    entry = f"""
## [{utc_date()}] ingest | Cursor — síntese em lote ({stats.get('written', 0)} sessões)

- **Export:** full + snapshot (`sync-cursor-to-wiki.sh --full --snapshot`).
- **Síntese:** `wiki-curator-synthesize-all.py` — {stats.get('written', 0)} páginas actualizadas, {stats.get('skipped', 0)} skip, {stats.get('empty', 0)} sem conteúdo substancial.
- **Hubs:** {hubs} páginas em `wiki/Cursor/Síntese — *.md` com índice completo.
- **Páginas dedicadas:** makemoney01, Ollama benchmark, Hermes Curator, llm-wiki (cross-links).
"""
    with log_path.open("a", encoding="utf-8") as handle:
        handle.write(entry)


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Synthesize all Cursor sessions to wiki/")
    parser.add_argument("--wiki", type=Path,
                        default=Path("/mnt/overpower/apps/dev/agl/llm-wiki"))
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--force", action="store_true",
                        help="Reescrever páginas existentes")
    args = parser.parse_args()
    wiki = args.wiki.resolve()

    stats = synthesize_all(wiki, args.dry_run, args.force)
    hubs = rebuild_hubs(wiki, args.dry_run)
    if not args.dry_run:
        append_log(wiki, stats, hubs)
    print(json.dumps({"synthesis": stats, "hubs": hubs},
          indent=2, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
