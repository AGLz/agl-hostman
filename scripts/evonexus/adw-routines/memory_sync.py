#!/usr/bin/env python3
"""ADW: Memory Sync — sync EvoNexus DB → docs + consolidação memory/ via Clawdia."""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "custom"))

from evonexus_ops import sync_all_agent_docs  # noqa: E402
from runner import banner, run_claude, summary  # noqa: E402

PROMPT = """Run the memory consolidation routine:

1. Read the last 3 daily logs in 'workspace/daily-logs/' (most recent first)
2. Read the meeting summaries from the last 3 days in 'workspace/meetings/summaries/'
3. Analyze recent git log: `git log --oneline --since="3 days ago"` and `git diff --stat HEAD~10` to understand what changed in the workspace
4. For each source, extract:
   - Decisions made → save in memory/ as type 'project'
   - New people or new context about people → save as type 'user' or update existing
   - Feedback or approach corrections → save as type 'feedback'
   - New terms or external references → save as type 'reference'
   - Skills or routines created/changed → update references if relevant
5. Before saving, check if similar memory already exists — update instead of duplicating
6. **Ingest propagation** — when saving/updating a memory, check which OTHER memories reference the same entity and update them too.
7. Update MEMORY.md with pointers to new files
8. Update memory/index.md — ensure all files in memory/ are cataloged by category
9. Append operations to memory/log.md with format: [DATE] SYNC — summary of changes

Also read `ai-docs/tasks/TASKS.md` and `ai-docs/planning/PROJECT_PLAN.md` (synced from EvoNexus DB) for operational state.

Report at the end: how many memories created/updated by type, and how many cross-references propagated.
Be concise — don't create memories for obvious things or things already documented in code."""


def main() -> None:
    banner("🧠 Memory Sync", "DB → TASKS/PLAN • Logs → Memory | @clawdia")
    sync = sync_all_agent_docs()
    print(sync.get("summary", sync))
    results = [
        run_claude(PROMPT, log_name="memory-sync", timeout=600, agent="clawdia-assistant")
    ]
    summary(results, "Memory Sync")


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("\n⚠ Cancelado.")
