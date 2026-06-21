#!/usr/bin/env bash
# Smoke Fase 4: harness dispatch + agent-os-ruflo sobre spec wireguard.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

echo "=== smoke harness-agent-os ==="

bash scripts/agl/harness-dispatch.sh --dry-run --harness ruflo --auth litellm \
  --task "smoke" --skip-probe >/dev/null
echo "OK harness-dispatch ruflo dry-run"

bash scripts/agl/agent-os-ruflo-dispatch.sh \
  --spec infrastructure/wireguard-peer-setup --dry-run --json \
  | python3 -c "import json,sys; d=json.load(sys.stdin); assert d['spec']=='wireguard-peer-setup'; assert d['task_groups']"
echo "OK agent-os-ruflo-dispatch json"

python3 scripts/agl/lib/parse-agent-os-tasks.py \
  agent-os/specs/infrastructure/wireguard-peer-setup/tasks.md \
  | python3 -c "import json,sys; d=json.load(sys.stdin); assert d['summary']['groups']>=5"
echo "OK parse-agent-os-tasks"

echo "=== smoke concluído ==="
