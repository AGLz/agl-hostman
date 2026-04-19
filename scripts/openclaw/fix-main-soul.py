#!/usr/bin/env python3
"""Add Self-Improvement section to main SOUL.md if missing."""
import os

SOUL = "/home/node/.openclaw/workspace/SOUL.md"

with open(SOUL) as f:
    content = f.read()

if "Self-Improvement" not in content:
    addition = """

## Self-Improvement

**Learn from every interaction.** When corrected, log the pattern in ~/self-improving/corrections.md. When you find a better way, document it in ~/self-improving/memory.md. Your memory compounds over time.

**Reflect before responding.** Check ~/self-improving/memory.md for relevant past learnings. Don't repeat mistakes you've already logged.

**Be honest about failures.** Log errors in corrections.md. Patterns emerge from honest tracking.

**Consolidate weekly.** The weekly-self-reflection cron runs every 7 days to archive old learnings and promote confirmed patterns to permanent rules.

**Teach subagents.** When delegating to subagents, share relevant learnings from your memory so they benefit from your experience.
"""
    with open(SOUL, "a") as f:
        f.write(addition)
    print("Added Self-Improvement section to main SOUL.md")
else:
    print("main SOUL.md already has Self-Improvement section")
