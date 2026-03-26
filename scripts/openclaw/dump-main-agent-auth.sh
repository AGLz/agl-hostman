#!/usr/bin/env bash
set -euo pipefail
D=/root/.openclaw/agents/main/agent
ls -la "$D"
echo "=== models.json ==="
sed -E 's/(sk-[A-Za-z0-9_-]{8})[A-Za-z0-9_-]*/\1...REDACTED/g' "$D/models.json" 2>/dev/null || echo missing
echo "=== auth-profiles.json ==="
sed -E 's/(sk-[A-Za-z0-9_-]{8})[A-Za-z0-9_-]*/\1...REDACTED/g; s/AIza[A-Za-z0-9_-]{10}/AIzaREDACTED/g' "$D/auth-profiles.json" 2>/dev/null || echo missing
