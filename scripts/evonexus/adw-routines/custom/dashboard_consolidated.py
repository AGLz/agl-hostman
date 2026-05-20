#!/usr/bin/env python3
"""ADW: Dashboard consolidado — skill prod-dashboard + notificação Telegram."""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from evonexus_ops import sync_all_agent_docs  # noqa: E402
from runner import banner, run_skill, summary  # noqa: E402


def main() -> None:
    banner("🖥️  Dashboard consolidado", "Visão 360 | prod-dashboard | @clawdia")
    sync = sync_all_agent_docs()
    print(sync.get("summary", sync))

    results = [
        run_skill(
            "prod-dashboard",
            log_name="dashboard-consolidated",
            timeout=600,
            agent="clawdia-assistant",
            notify_telegram=True,
        )
    ]
    summary(results, "Dashboard consolidado")


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("\n⚠ Cancelado.")
