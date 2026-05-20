#!/usr/bin/env python3
"""ADW: Sincroniza evonexus.db → ai-docs/tasks/TASKS.md (fonte para Jarvis/agentes)."""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from evonexus_ops import sync_all_agent_docs  # noqa: E402
from runner import banner, run_script, summary  # noqa: E402


def main() -> None:
    banner("🔄 Goals / Tasks sync", "DB → TASKS.md + PROJECT_PLAN.md | systematic")

    def job() -> dict:
        return sync_all_agent_docs()

    results = [run_script(job, log_name="goals-tasks-sync", timeout=60)]
    summary(results, "Goals/Tasks sync")


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("\n⚠ Cancelado.")
