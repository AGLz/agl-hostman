#!/usr/bin/env bash
set -euo pipefail
cd /root/.openclaw/agents/main/sessions || exit 1
ls -t ./*.jsonl 2>/dev/null | head -2 | while read -r f; do
  echo "=== $f ==="
  tail -20 "$f"
  echo ""
done
