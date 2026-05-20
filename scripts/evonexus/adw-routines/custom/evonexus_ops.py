#!/usr/bin/env python3
"""Helpers partilhados pelas rotinas AGLz no EvoNexus (CT242)."""

from __future__ import annotations

import os
import sqlite3
import urllib.error
import urllib.parse
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

WORKSPACE = Path(os.environ.get("EVONEXUS_WORKSPACE", "/workspace"))
DB_PATH = Path(
    os.environ.get(
        "EVONEXUS_DB_PATH",
        str(WORKSPACE / "dashboard" / "data" / "evonexus.db"),
    )
)
ENV_PATH = WORKSPACE / "config" / ".env"
TASKS_PATHS = (
    WORKSPACE / "ai-docs" / "tasks" / "TASKS.md",
    WORKSPACE / "workspace" / "ai-docs" / "tasks" / "TASKS.md",
)
PROJECT_PLAN_PATHS = (
    WORKSPACE / "ai-docs" / "planning" / "PROJECT_PLAN.md",
    WORKSPACE / "workspace" / "ai-docs" / "planning" / "PROJECT_PLAN.md",
)


def load_dotenv() -> dict[str, str]:
    out: dict[str, str] = {}
    if not ENV_PATH.is_file():
        return out
    for line in ENV_PATH.read_text(encoding="utf-8", errors="replace").splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, _, val = line.partition("=")
        out[key.strip()] = val.strip().strip('"').strip("'")
    return out


def _now_iso() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def send_telegram(message: str) -> bool:
    env = {**load_dotenv(), **os.environ}
    token = env.get("TELEGRAM_BOT_TOKEN", "").strip()
    chat_id = env.get("TELEGRAM_CHAT_ID", "").strip()
    if not token or not chat_id:
        return False
    body = urllib.parse.urlencode(
        {"chat_id": chat_id, "text": message[:4000], "disable_web_page_preview": "true"}
    ).encode()
    req = urllib.request.Request(
        f"https://api.telegram.org/bot{token}/sendMessage",
        data=body,
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            return 200 <= resp.status < 300
    except (urllib.error.URLError, TimeoutError, OSError):
        return False


def sync_tasks_markdown() -> dict:
    """Exporta missions/projects/goals/tasks/tickets abertos para TASKS.md (fonte para agentes)."""
    if not DB_PATH.is_file():
        return {"ok": False, "summary": f"DB ausente: {DB_PATH}"}

    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    cur = conn.cursor()

    missions = cur.execute(
        "SELECT id, slug, title, status FROM missions ORDER BY id"
    ).fetchall()
    projects = cur.execute(
        "SELECT id, slug, mission_id, title, status FROM projects ORDER BY mission_id, id"
    ).fetchall()
    goals = cur.execute(
        """SELECT g.id, g.slug, g.title, g.status, g.metric_type, g.target_value,
                  g.current_value, g.due_date, p.slug AS project_slug
           FROM goals g
           JOIN projects p ON p.id = g.project_id
           ORDER BY p.slug, g.id"""
    ).fetchall()
    goal_tasks = cur.execute(
        """SELECT t.id, t.title, t.status, t.priority, t.assignee_agent, t.due_date,
                  g.slug AS goal_slug
           FROM goal_tasks t
           LEFT JOIN goals g ON g.id = t.goal_id
           ORDER BY t.priority DESC, t.id"""
    ).fetchall()
    tickets = cur.execute(
        """SELECT t.id, t.title, t.status, t.priority, t.assignee_agent, p.slug AS project_slug
           FROM tickets t
           LEFT JOIN projects p ON p.id = t.project_id
           WHERE t.status NOT IN ('closed', 'archived', 'resolved')
           ORDER BY t.priority_rank DESC, t.created_at DESC
           LIMIT 50"""
    ).fetchall()
    conn.close()

    lines = [
        "# TASKS — EvoNexus (sincronizado automaticamente)",
        "",
        f"> Gerado em `{_now_iso()}`. **Fonte canónica:** `dashboard/data/evonexus.db`.",
        "> Agentes (Jarvis, Atlas, etc.) devem alinhar trabalho a este ficheiro e ao dashboard.",
        "",
        "## Missões",
    ]
    for m in missions:
        lines.append(f"- **{m['slug']}** — {m['title']} (`{m['status']}`)")

    lines.extend(["", "## Projetos"])
    for p in projects:
        lines.append(
            f"- **{p['slug']}** (missão {p['mission_id']}) — {p['title']} (`{p['status']}`)"
        )

    lines.extend(["", "## Metas (goals)"])
    for g in goals:
        progress = ""
        if g["metric_type"] == "percentage":
            progress = f" — {g['current_value']:.0f}% / {g['target_value']:.0f}%"
        elif g["metric_type"] == "boolean":
            progress = f" — {'feito' if g['current_value'] >= 1 else 'pendente'}"
        else:
            progress = f" — {g['current_value']}/{g['target_value']}"
        lines.append(
            f"- [{g['project_slug']}] **{g['slug']}**: {g['title']}{progress} (`{g['status']}`)"
        )

    lines.extend(["", "## Tarefas de meta (goal_tasks)"])
    if goal_tasks:
        for t in goal_tasks:
            agent = f" @{t['assignee_agent']}" if t["assignee_agent"] else ""
            goal = f" → {t['goal_slug']}" if t["goal_slug"] else ""
            lines.append(
                f"- [P{t['priority']}] {t['title']}{goal}{agent} (`{t['status']}`)"
            )
    else:
        lines.append("- _(nenhuma)_")

    lines.extend(["", "## Tickets abertos (inbox operacional)"])
    if tickets:
        for t in tickets:
            agent = f" @{t['assignee_agent']}" if t["assignee_agent"] else ""
            proj = f" [{t['project_slug']}]" if t["project_slug"] else ""
            lines.append(
                f"- **{t['priority'].upper()}**{proj} {t['title']}{agent} (`{t['status']}`)"
            )
    else:
        lines.append("- _(nenhum)_")

    lines.append("")
    content = "\n".join(lines)

    written: list[str] = []
    for path in TASKS_PATHS:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content, encoding="utf-8")
        written.append(str(path))

    summary = (
        f"sync OK: {len(missions)} missões, {len(projects)} projetos, "
        f"{len(goals)} metas, {len(goal_tasks)} goal_tasks, {len(tickets)} tickets → "
        f"{len(written)} ficheiro(s)"
    )
    return {"ok": True, "summary": summary, "paths": written}


def sync_project_plan_markdown() -> dict:
    """Exporta missões e projetos para PROJECT_PLAN.md (referência Jarvis / agentes)."""
    if not DB_PATH.is_file():
        return {"ok": False, "summary": f"DB ausente: {DB_PATH}"}

    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    cur = conn.cursor()

    missions = cur.execute(
        "SELECT slug, title, description, status, target_metric, target_value, current_value FROM missions ORDER BY id"
    ).fetchall()
    projects = cur.execute(
        """SELECT p.slug, p.title, p.description, p.status, p.workspace_folder_path, m.slug AS mission_slug
           FROM projects p JOIN missions m ON m.id = p.mission_id ORDER BY m.slug, p.slug"""
    ).fetchall()
    conn.close()

    lines = [
        "# PROJECT_PLAN — EvoNexus (sincronizado automaticamente)",
        "",
        f"> Gerado em `{_now_iso()}`. Fonte: `dashboard/data/evonexus.db`.",
        "",
        "## Missões",
    ]
    for m in missions:
        lines.append(f"### {m['title']} (`{m['slug']}`)\n- Estado: `{m['status']}`")

    lines.extend(["", "## Projetos activos"])
    for p in projects:
        path = p["workspace_folder_path"] or "—"
        lines.append(
            f"- **{p['slug']}** [{p['mission_slug']}] — {p['title']} (`{p['status']}`) — `{path}`"
        )

    lines.append("")
    content = "\n".join(lines)
    written: list[str] = []
    for path in PROJECT_PLAN_PATHS:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content, encoding="utf-8")
        written.append(str(path))

    return {
        "ok": True,
        "summary": f"PROJECT_PLAN: {len(missions)} missões, {len(projects)} projetos → {len(written)} ficheiro(s)",
        "paths": written,
    }


def sync_all_agent_docs() -> dict:
    """TASKS.md + PROJECT_PLAN.md numa única chamada (rotinas e memory_sync)."""
    tasks = sync_tasks_markdown()
    plan = sync_project_plan_markdown()
    ok = tasks.get("ok") and plan.get("ok")
    return {
        "ok": ok,
        "summary": f"{tasks.get('summary', tasks)} | {plan.get('summary', plan)}",
    }


def build_operational_snapshot() -> str:
    """Resumo compacto para briefings (Good Morning / reports)."""
    if not DB_PATH.is_file():
        return f"(evonexus.db não encontrado em {DB_PATH})"

    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    cur = conn.cursor()

    open_tickets = cur.execute(
        """SELECT priority, COUNT(*) AS n FROM tickets
           WHERE status NOT IN ('closed','archived','resolved')
           GROUP BY priority ORDER BY priority_rank DESC"""
    ).fetchall()
    open_tasks = cur.execute(
        "SELECT COUNT(*) FROM goal_tasks WHERE status NOT IN ('done','cancelled')"
    ).fetchone()[0]
    active_goals = cur.execute(
        "SELECT COUNT(*) FROM goals WHERE status = 'active'"
    ).fetchone()[0]

    top_tickets = cur.execute(
        """SELECT t.title, t.priority, p.slug
           FROM tickets t LEFT JOIN projects p ON p.id = t.project_id
           WHERE t.status NOT IN ('closed','archived','resolved')
           ORDER BY t.priority_rank DESC LIMIT 5"""
    ).fetchall()

    mrr = cur.execute(
        """SELECT metric_name, metric_value FROM advanced_metrics
           WHERE metric_name LIKE '%mrr%' ORDER BY calculated_at DESC LIMIT 3"""
    ).fetchall()

    conn.close()

    lines = [
        f"- Metas activas: {active_goals}",
        f"- Goal tasks em aberto: {open_tasks}",
    ]
    if open_tickets:
        parts = [f"{r['priority']}={r['n']}" for r in open_tickets]
        lines.append(f"- Tickets abertos: {', '.join(parts)}")
    else:
        lines.append("- Tickets abertos: 0")

    if top_tickets:
        lines.append("- Top tickets:")
        for t in top_tickets:
            proj = f"[{t['slug']}] " if t["slug"] else ""
            lines.append(f"  - ({t['priority']}) {proj}{t['title']}")

    if mrr:
        lines.append("- MRR (advanced_metrics):")
        for m in mrr:
            lines.append(f"  - {m['metric_name']}: {m['metric_value']}")

    lines.append(f"- TASKS.md: {TASKS_PATHS[0]}")
    return "\n".join(lines)
