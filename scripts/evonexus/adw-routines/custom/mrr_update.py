#!/usr/bin/env python3
"""ADW: Atualização MRR — lê métricas da DB, regista snapshot diário, Telegram."""

from __future__ import annotations

import os
import sqlite3
import sys
from datetime import date, datetime, timezone

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from evonexus_ops import DB_PATH, send_telegram  # noqa: E402
from runner import banner, run_script, summary  # noqa: E402


def _mrr_job() -> dict:
    if not DB_PATH.is_file():
        return {"ok": False, "summary": f"DB ausente: {DB_PATH}"}

    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    cur = conn.cursor()

    rows = cur.execute(
        """SELECT metric_name, metric_value, calculated_at, notes
           FROM advanced_metrics
           WHERE metric_name LIKE '%mrr%'
           ORDER BY calculated_at DESC"""
    ).fetchall()

    today = date.today().isoformat()
    mrr_current = 0.0
    for r in rows:
        if r["metric_name"] in ("mrr_current", "total_mrr", "mrr_total"):
            mrr_current = float(r["metric_value"] or 0)
            break
    if mrr_current == 0.0 and rows:
        mrr_current = float(rows[0]["metric_value"] or 0)

    existing = cur.execute(
        "SELECT id FROM growth_metrics WHERE date_recorded = ?", (today,)
    ).fetchone()
    now = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S")
    if existing:
        cur.execute(
            "UPDATE growth_metrics SET mrr_current = ?, created_at = ? WHERE date_recorded = ?",
            (mrr_current, now, today),
        )
    else:
        cur.execute(
            """INSERT INTO growth_metrics
               (date_recorded, mrr_current, mrr_target, mrr_growth_rate,
                new_customers, churn_rate, created_at)
               VALUES (?, ?, 0, 0, 0, 0, ?)""",
            (today, mrr_current, now),
        )

    # Alinha metas com target_metric mrr
    cur.execute(
        """UPDATE goals SET current_value = ?, updated_at = ?
           WHERE LOWER(COALESCE(target_metric, '')) LIKE '%mrr%'
             AND status = 'active'""",
        (mrr_current, datetime.now(timezone.utc).isoformat()),
    )
    conn.commit()
    conn.close()

    lines = [f"MRR corrente (DB): R$ {mrr_current:,.2f}", f"Snapshot: {today}"]
    if rows:
        lines.append("Métricas advanced_metrics:")
        for r in rows[:5]:
            lines.append(f"  • {r['metric_name']}: {r['metric_value']}")

    text = "\n".join(lines)
    sent = send_telegram(f"💰 MRR Update ({today})\n{text}")
    suffix = " | Telegram ✓" if sent else " | Telegram omitido (sem token/chat_id)"
    return {"ok": True, "summary": f"MRR {mrr_current:.2f}{suffix}", "data": text}


def main() -> None:
    banner("💰 Atualização MRR", "growth_metrics + advanced_metrics | systematic")
    results = [run_script(_mrr_job, log_name="mrr-update", timeout=120)]
    summary(results, "Atualização MRR")


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("\n⚠ Cancelado.")
