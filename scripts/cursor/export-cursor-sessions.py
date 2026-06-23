#!/usr/bin/env python3
"""Exporta conversas Cursor (agent-transcripts + Composer) para llm-wiki/raw/cursor/."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import shutil
import socket
import sqlite3
import sys
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Iterator

AGL_KEYWORDS = (
    "agl",
    "hermes",
    "litellm",
    "openclaw",
    "llm-wiki",
    "proxmox",
    "ct188",
    "ct193",
    "ct186",
    "aglsrv",
    "tailscale",
    "dokploy",
    "obsidian",
    "honcho",
    "linear",
    "six-repos",
    "hostman",
    "evonexus",
    "openhuman",
    "cloudflare",
    "pbs",
    "unraid",
)

USER_QUERY_RE = re.compile(
    r"<user_query>\s*(.*?)\s*</user_query>", re.DOTALL | re.IGNORECASE)
SAFE_NAME_RE = re.compile(r"[^\w\-]+", re.UNICODE)


@dataclass
class TranscriptRoot:
    host: str
    path: Path


@dataclass
class TranscriptSource:
    host: str
    session_id: str
    project_slug: str
    jsonl_path: Path
    mtime_ns: int
    size: int


def utc_now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def slugify(value: str, max_len: int = 80) -> str:
    value = SAFE_NAME_RE.sub("_", value.strip())
    value = re.sub(r"_+", "_", value).strip("_")
    return (value or "session")[:max_len]


def default_wiki_dir() -> Path:
    env = os.environ.get("LLM_WIKI_DIR")
    if env:
        return Path(env)
    return Path("/mnt/overpower/apps/dev/agl/llm-wiki")


def export_host_label() -> str:
    explicit = os.environ.get("CURSOR_EXPORT_HOST", "").strip()
    if explicit:
        return slugify(explicit, max_len=32)
    return slugify(socket.gethostname().split(".")[0] or "unknown", max_len=32)


def discover_transcript_roots() -> list[TranscriptRoot]:
    roots: list[TranscriptRoot] = []
    seen: set[Path] = set()

    def add(host: str, path: Path) -> None:
        resolved = path.expanduser().resolve()
        if resolved.is_dir() and resolved not in seen:
            seen.add(resolved)
            roots.append(TranscriptRoot(host=slugify(host, max_len=32), path=resolved))

    add(export_host_label(), Path.home() / ".cursor" / "projects")

    sync_root = Path(
        os.environ.get("AGL_HOME_SYNC_ROOT", "/mnt/overpower/apps/dev/agl/agl-home-sync")
    )
    scan_all_hosts = os.environ.get("CURSOR_EXPORT_ALL_HOSTS", "1") != "0"
    explicit_user = os.environ.get("AGL_HOME_USER", "").strip()

    if sync_root.is_dir():
        if explicit_user:
            add(
                explicit_user,
                sync_root / explicit_user / "cursor" / "dot-cursor" / "projects",
            )
        if scan_all_hosts:
            for child in sorted(sync_root.iterdir()):
                if not child.is_dir() or child.name.startswith("."):
                    continue
                add(
                    child.name,
                    child / "cursor" / "dot-cursor" / "projects",
                )
        else:
            add(
                "linux-root",
                sync_root / "linux-root" / "cursor" / "dot-cursor" / "projects",
            )

    extra = os.environ.get("CURSOR_PROJECTS_DIRS", "")
    for part in extra.split(os.pathsep):
        part = part.strip()
        if not part:
            continue
        if "|" in part:
            host, rel = part.split("|", 1)
            add(host.strip(), Path(rel.strip()))
        else:
            add(export_host_label(), Path(part))

    return roots


def discover_vscdb_paths() -> list[tuple[str, Path]]:
    paths: list[tuple[str, Path]] = []
    seen: set[Path] = set()

    def add(host: str, path: Path) -> None:
        if path.is_file() and path not in seen:
            seen.add(path)
            paths.append((slugify(host, max_len=32), path))

    add(export_host_label(), Path.home() / ".config" / "Cursor" / "User" / "globalStorage" / "state.vscdb")
    appdata = os.environ.get("APPDATA", "")
    if appdata:
        add(
            "win-administrator",
            Path(appdata) / "Cursor" / "User" / "globalStorage" / "state.vscdb",
        )
    explicit_vscdb = os.environ.get("CURSOR_STATE_VSCDB", "").strip()
    if explicit_vscdb:
        add(export_host_label(), Path(explicit_vscdb))

    sync_root = Path(
        os.environ.get("AGL_HOME_SYNC_ROOT", "/mnt/overpower/apps/dev/agl/agl-home-sync")
    )
    if sync_root.is_dir() and os.environ.get("CURSOR_EXPORT_ALL_HOSTS", "1") != "0":
        for child in sorted(sync_root.iterdir()):
            if not child.is_dir() or child.name.startswith("."):
                continue
            add(child.name, child / "cursor" / "globalStorage" / "state.vscdb")

    return paths


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def load_state(path: Path) -> dict[str, Any]:
    if not path.is_file():
        return {"version": 1, "sessions": {}}
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        return {"version": 1, "sessions": {}}


def save_state(path: Path, state: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(state, indent=2,
                    ensure_ascii=False) + "\n", encoding="utf-8")


def load_merged_state(cursor_raw: Path) -> dict[str, Any]:
    merged: dict[str, Any] = {"version": 1, "sessions": {}}
    for path in sorted(cursor_raw.glob(".export-state*.json")):
        part = load_state(path)
        merged["sessions"].update(part.get("sessions", {}))
    legacy = cursor_raw / ".export-state.json"
    if legacy.is_file():
        merged["sessions"].update(load_state(legacy).get("sessions", {}))
    return merged


def state_path_for_host(cursor_raw: Path, host: str) -> Path:
    return cursor_raw / f".export-state-{slugify(host, max_len=32)}.json"


def read_previous_state(
    state: dict[str, Any],
    cursor_raw: Path,
    host: str,
    modern: str,
    legacy: str,
) -> dict[str, Any]:
    host_state = load_state(state_path_for_host(cursor_raw, host))
    if modern in host_state["sessions"]:
        return host_state["sessions"][modern]
    if legacy in host_state["sessions"]:
        return host_state["sessions"][legacy]
    if modern in state["sessions"]:
        return state["sessions"][modern]
    if legacy in state["sessions"]:
        return state["sessions"][legacy]
    return {}


def write_session_state(
    cursor_raw: Path,
    host: str,
    state_key: str,
    meta: dict[str, Any],
    legacy_key: str | None = None,
) -> None:
    path = state_path_for_host(cursor_raw, host)
    host_state = load_state(path)
    host_state["sessions"][state_key] = meta
    if legacy_key and legacy_key in host_state["sessions"] and legacy_key != state_key:
        del host_state["sessions"][legacy_key]
    save_state(path, host_state)


def append_ingest_queue(queue_path: Path, entry: dict[str, Any]) -> None:
    queue_path.parent.mkdir(parents=True, exist_ok=True)
    with queue_path.open("a", encoding="utf-8") as handle:
        handle.write(json.dumps(entry, ensure_ascii=False) + "\n")


def project_slug_from_path(jsonl_path: Path) -> str:
    parts = jsonl_path.parts
    if "projects" in parts:
        idx = parts.index("projects")
        if idx + 1 < len(parts):
            return parts[idx + 1]
    return slugify(jsonl_path.parent.parent.name)


def agent_state_keys(source: TranscriptSource) -> tuple[str, str]:
    modern = f"agent:{source.host}:{source.project_slug}:{source.session_id}"
    legacy = f"agent:{source.project_slug}:{source.session_id}"
    return modern, legacy


def iter_transcript_files(roots: list[TranscriptRoot]) -> Iterator[TranscriptSource]:
    seen_jsonl: set[Path] = set()
    for root in roots:
        if not root.path.is_dir():
            continue
        for jsonl_path in root.path.glob("**/agent-transcripts/**/*.jsonl"):
            if "/subagents/" in jsonl_path.as_posix():
                continue
            resolved = jsonl_path.resolve()
            if resolved in seen_jsonl:
                continue
            session_id = jsonl_path.stem
            project_slug = project_slug_from_path(jsonl_path)
            stat = jsonl_path.stat()
            seen_jsonl.add(resolved)
            yield TranscriptSource(
                host=root.host,
                session_id=session_id,
                project_slug=project_slug,
                jsonl_path=jsonl_path,
                mtime_ns=stat.st_mtime_ns,
                size=stat.st_size,
            )


def extract_text_blocks(content: list[Any]) -> str:
    chunks: list[str] = []
    for block in content or []:
        if not isinstance(block, dict):
            continue
        if block.get("type") == "text":
            text = block.get("text", "")
            if text:
                chunks.append(text)
    return "\n".join(chunks).strip()


def parse_transcript_messages(jsonl_path: Path) -> list[tuple[str, str]]:
    messages: list[tuple[str, str]] = []
    for line in jsonl_path.read_text(encoding="utf-8", errors="replace").splitlines():
        line = line.strip()
        if not line:
            continue
        try:
            obj = json.loads(line)
        except json.JSONDecodeError:
            continue
        role = str(obj.get("role", "unknown"))
        message = obj.get("message") or {}
        text = extract_text_blocks(message.get("content") or [])
        if not text:
            continue
        if role == "user":
            match = USER_QUERY_RE.search(text)
            if match:
                text = match.group(1).strip()
        messages.append((role, text))
    return messages


def session_matches_agl(source: TranscriptSource, messages: list[tuple[str, str]]) -> bool:
    if "agl" in source.project_slug.lower():
        return True
    haystack = " ".join(
        [source.project_slug, source.session_id]
        + [text for _, text in messages[:6]]
    ).lower()
    return any(keyword in haystack for keyword in AGL_KEYWORDS)


def first_user_title(messages: list[tuple[str, str]], fallback: str) -> str:
    for role, text in messages:
        if role == "user" and text.strip():
            line = text.strip().splitlines()[0]
            return slugify(line, max_len=60) or fallback
    return fallback


def render_agent_markdown(
    source: TranscriptSource,
    messages: list[tuple[str, str]],
    exported_at: str,
) -> str:
    title = first_user_title(messages, source.session_id[:8])
    lines = [
        "---",
        f'title: "Cursor Agent — {title}"',
        "tags: [cursor, agent-transcript, agl, fonte]",
        f'updated: "{exported_at[:10]}"',
        f'sources: ["{source.jsonl_path.as_posix()}"]',
        "harness: cursor",
        f"project: {source.project_slug}",
        f"host: {source.host}",
        f"session_id: {source.session_id}",
        "---",
        "",
        f"# Agent transcript `{source.session_id}`",
        "",
        f"- **host:** `{source.host}`",
        f"- **projeto:** `{source.project_slug}`",
        f"- **ficheiro:** `{source.jsonl_path}`",
        f"- **modificado:** {datetime.fromtimestamp(source.mtime_ns / 1e9).strftime('%Y-%m-%d %H:%M')}",
        f"- **exportado:** {exported_at}",
        "",
        "---",
        "",
    ]
    for role, text in messages:
        lines.append(f"## {role}")
        lines.append("")
        lines.append(text)
        lines.append("")
    return "\n".join(lines).rstrip() + "\n"


def export_agent_transcript(
    source: TranscriptSource,
    live_dir: Path,
    cursor_raw: Path,
    state: dict[str, Any],
    ingest_queue: Path,
    filter_mode: str,
    force: bool,
) -> bool:
    messages = parse_transcript_messages(source.jsonl_path)
    if filter_mode == "agl" and not session_matches_agl(source, messages):
        return False

    digest = sha256_file(source.jsonl_path)
    modern_key, legacy_key = agent_state_keys(source)
    previous = read_previous_state(state, cursor_raw, source.host, modern_key, legacy_key)
    if (
        not force
        and previous.get("sha256") == digest
        and previous.get("size") == source.size
    ):
        return False

    title = first_user_title(messages, source.session_id[:8])
    base_name = f"{source.project_slug}_{source.session_id}"
    md_rel = Path("agent-transcripts") / source.host / f"{base_name}.md"
    raw_rel = Path("agent-transcripts/raw") / source.host / f"{base_name}.jsonl"
    md_path = live_dir / md_rel
    raw_path = live_dir / raw_rel
    md_path.parent.mkdir(parents=True, exist_ok=True)
    raw_path.parent.mkdir(parents=True, exist_ok=True)

    exported_at = utc_now_iso()
    md_path.write_text(
        render_agent_markdown(source, messages, exported_at),
        encoding="utf-8",
    )
    shutil.copy2(source.jsonl_path, raw_path)

    write_session_state(cursor_raw, source.host, modern_key, {
        "sha256": digest,
        "size": source.size,
        "mtime_ns": source.mtime_ns,
        "exported_at": exported_at,
        "host": source.host,
        "markdown": str(md_rel),
        "raw": str(raw_rel),
        "source": str(source.jsonl_path),
    }, legacy_key)
    state["sessions"][modern_key] = state["sessions"].get(modern_key) or {
        "host": source.host,
        "markdown": str(md_rel),
    }

    append_ingest_queue(
        ingest_queue,
        {
            "ts": exported_at,
            "source": "agent-transcript",
            "host": source.host,
            "project": source.project_slug,
            "session_id": source.session_id,
            "markdown": f"raw/cursor/live/{md_rel.as_posix()}",
            "title": title,
        },
    )
    return True


def extract_composer_outline(data: dict[str, Any]) -> list[tuple[str, str]]:
    outline: list[tuple[str, str]] = []
    headers = data.get("fullConversationHeadersOnly") or []
    for header in headers:
        grouping = header.get("grouping") or {}
        title = grouping.get("simulatedMessageMetadataTitle")
        if title:
            outline.append(("task", str(title)))
            continue
        if grouping.get("hasText"):
            outline.append(("message", header.get("bubbleId", "bubble")))
    if not outline and data.get("subtitle"):
        outline.append(("subtitle", str(data["subtitle"])))
    if not outline and data.get("name"):
        outline.append(("name", str(data["name"])))
    return outline


def export_composer_sessions(
    vscdb_path: Path,
    host: str,
    live_dir: Path,
    cursor_raw: Path,
    state: dict[str, Any],
    ingest_queue: Path,
    filter_mode: str,
    force: bool,
) -> int:
    exported = 0
    connection = sqlite3.connect(f"file:{vscdb_path}?mode=ro", uri=True)
    rows = connection.execute(
        "SELECT key, value FROM ItemTable WHERE key LIKE 'composer.composerData:%'"
    ).fetchall()
    connection.close()

    for key, value in rows:
        try:
            data = json.loads(value)
        except (json.JSONDecodeError, TypeError):
            continue
        composer_id = str(data.get("composerId") or key.rsplit(":", 1)[-1])
        name = str(data.get("name") or composer_id[:8])
        created_ms = int(data.get("createdAt") or 0)
        created_at = (
            datetime.fromtimestamp(
                created_ms / 1000, tz=timezone.utc).strftime("%Y-%m-%d %H:%M")
            if created_ms
            else "unknown"
        )
        outline = extract_composer_outline(data)
        haystack = " ".join([name, composer_id] +
                            [text for _, text in outline]).lower()
        if filter_mode == "agl" and not any(k in haystack for k in AGL_KEYWORDS):
            continue

        raw_bytes = value if isinstance(
            value, (bytes, bytearray)) else str(value).encode("utf-8")
        digest = hashlib.sha256(raw_bytes).hexdigest()
        state_key = f"composer:{host}:{composer_id}"
        legacy_key = f"composer:{composer_id}"
        previous = read_previous_state(state, cursor_raw, host, state_key, legacy_key)
        if not force and previous.get("sha256") == digest:
            continue

        stamp = datetime.fromtimestamp(
            created_ms / 1000, tz=timezone.utc).strftime("%Y-%m-%d_%H-%M") if created_ms else "unknown"
        safe_name = slugify(name)
        base = f"{stamp}_{safe_name}_{composer_id[:8]}"
        raw_rel = Path("composer/raw") / host / f"{composer_id}.json"
        md_rel = Path("composer") / host / f"{base}.md"
        raw_path = live_dir / raw_rel
        md_path = live_dir / md_rel
        raw_path.parent.mkdir(parents=True, exist_ok=True)
        md_path.parent.mkdir(parents=True, exist_ok=True)
        raw_path.write_bytes(raw_bytes if isinstance(
            value, (bytes, bytearray)) else str(value).encode("utf-8"))

        exported_at = utc_now_iso()
        md_lines = [
            "---",
            f'title: "Cursor Composer — {name}"',
            "tags: [cursor, composer, agl, fonte]",
            f'updated: "{exported_at[:10]}"',
            f'sources: ["{raw_rel.as_posix()}"]',
            "harness: cursor",
            f"composer_id: {composer_id}",
            f"host: {host}",
            "---",
            "",
            f"# {name}",
            "",
            f"- **composerId:** `{composer_id}`",
            f"- **criado:** {created_at}",
            f"- **exportado:** {exported_at}",
            "",
            "---",
            "",
        ]
        for role, text in outline:
            md_lines.append(f"## {role}")
            md_lines.append("")
            md_lines.append(text)
            md_lines.append("")
        md_path.write_text("\n".join(md_lines).rstrip() +
                           "\n", encoding="utf-8")

        write_session_state(cursor_raw, host, state_key, {
            "sha256": digest,
            "exported_at": exported_at,
            "host": host,
            "markdown": str(md_rel),
            "raw": str(raw_rel),
            "name": name,
        }, legacy_key)
        append_ingest_queue(
            ingest_queue,
            {
                "ts": exported_at,
                "source": "composer",
                "host": host,
                "session_id": composer_id,
                "markdown": f"raw/cursor/live/{md_rel.as_posix()}",
                "title": name,
            },
        )
        exported += 1
    return exported


def write_manifest(live_dir: Path, state: dict[str, Any]) -> None:
    sessions = []
    for key, meta in sorted(state.get("sessions", {}).items()):
        parts = key.split(":")
        if parts[0] == "agent":
            if len(parts) == 4:
                host, project, sid = parts[1], parts[2], parts[3]
            else:
                host = meta.get("host", "unknown")
                project, sid = parts[1], parts[2]
            sessions.append(
                {
                    "source": "agent-transcript",
                    "host": host,
                    "id": sid,
                    "project": project,
                    "markdown": meta.get("markdown"),
                    "raw": meta.get("raw"),
                    "exported_at": meta.get("exported_at"),
                }
            )
        elif parts[0] == "composer":
            if len(parts) == 3:
                host, session_id = parts[1], parts[2]
            else:
                host = meta.get("host", "unknown")
                session_id = parts[1]
            sessions.append(
                {
                    "source": "composer",
                    "host": host,
                    "id": session_id,
                    "name": meta.get("name"),
                    "markdown": meta.get("markdown"),
                    "raw": meta.get("raw"),
                    "exported_at": meta.get("exported_at"),
                }
            )
    manifest = {
        "exportedAt": utc_now_iso(),
        "harness": "cursor",
        "mode": "live",
        "exportHost": export_host_label(),
        "count": len(sessions),
        "sessions": sessions,
    }
    (live_dir / "manifest.json").write_text(
        json.dumps(manifest, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )


def snapshot_live_export(live_dir: Path, wiki_dir: Path) -> Path | None:
    if not live_dir.is_dir():
        return None
    stamp = datetime.now(timezone.utc).strftime("%Y-%m-%d")
    target = wiki_dir / "raw" / "cursor" / "exports" / stamp
    if target.exists():
        return target
    try:
        shutil.copytree(live_dir, target)
    except FileExistsError:
        return target
    return target


def resolve_session_filter(session_arg: str | None) -> tuple[str | None, str | None]:
    if not session_arg:
        return None, None
    path = Path(session_arg)
    if path.is_file():
        session_id = path.stem
        project_slug = project_slug_from_path(path)
        return project_slug, session_id
    return None, session_arg


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Export Cursor sessions to llm-wiki raw/cursor")
    parser.add_argument("--wiki", type=Path,
                        default=default_wiki_dir(), help="llm-wiki vault root")
    parser.add_argument(
        "--filter", choices=["agl", "all"], default="agl", help="Session filter")
    parser.add_argument("--full", action="store_true",
                        help="Re-export all matching sessions")
    parser.add_argument("--snapshot", action="store_true",
                        help="Copy live/ to exports/YYYY-MM-DD/")
    parser.add_argument(
        "--session", help="Transcript path or session UUID (hook)")
    parser.add_argument("--quiet", action="store_true")
    parser.set_defaults(incremental=True)
    args = parser.parse_args()

    wiki_dir = args.wiki.expanduser().resolve()
    cursor_raw = wiki_dir / "raw" / "cursor"
    live_dir = cursor_raw / "live"
    ingest_queue = cursor_raw / "ingest-queue.jsonl"
    live_dir.mkdir(parents=True, exist_ok=True)

    state = load_merged_state(cursor_raw)
    force = args.full
    project_filter, session_filter = resolve_session_filter(args.session)

    exported_agents = 0
    for source in iter_transcript_files(discover_transcript_roots()):
        if project_filter and source.project_slug != project_filter:
            continue
        if session_filter and source.session_id != session_filter:
            continue
        if export_agent_transcript(
            source,
            live_dir,
            cursor_raw,
            state,
            ingest_queue,
            args.filter,
            force,
        ):
            exported_agents += 1

    exported_composers = 0
    for host, vscdb in discover_vscdb_paths():
        exported_composers += export_composer_sessions(
            vscdb,
            host,
            live_dir,
            cursor_raw,
            state,
            ingest_queue,
            args.filter,
            force,
        )

    state["last_run"] = utc_now_iso()
    state["last_host"] = export_host_label()
    manifest_state_path = cursor_raw / ".export-state.json"
    save_state(manifest_state_path, state)
    write_manifest(live_dir, state)

    snapshot_path = None
    if args.snapshot:
        snapshot_path = snapshot_live_export(live_dir, wiki_dir)

    if not args.quiet:
        print(
            json.dumps(
                {
                    "wiki": str(wiki_dir),
                    "export_host": export_host_label(),
                    "exported_agents": exported_agents,
                    "exported_composers": exported_composers,
                    "live_dir": str(live_dir),
                    "state": str(manifest_state_path),
                    "ingest_queue": str(ingest_queue),
                    "snapshot": str(snapshot_path) if snapshot_path else None,
                },
                indent=2,
            )
        )
    return 0


if __name__ == "__main__":
    sys.exit(main())
