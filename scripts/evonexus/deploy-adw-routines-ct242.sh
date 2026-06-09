#!/usr/bin/env bash
# Deploy rotinas AGLz + patch runner no EvoNexus CT548 (fgsrv7; antes CT242).
set -euo pipefail

CTID="${CTID:-548}"
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
STAGING="${STAGING:-/opt/evonexus/adw-routines}"
HOST="${HOST:-root@191.252.93.227}"

CONTAINERS=(evonexus-scheduler evonexus-dashboard)

echo "==> Stage no host Proxmox e stream para CT${CTID} (pct push não aceita diretório)"
HOST_STAGING="${HOST_STAGING:-/opt/evonexus}"
mkdir -p "$HOST_STAGING/adw-routines/custom"
cp -a "$REPO_ROOT/scripts/evonexus/adw-routines/"* "$HOST_STAGING/adw-routines/" 2>/dev/null || true
cp -a "$REPO_ROOT/scripts/evonexus/adw-routines/custom/." "$HOST_STAGING/adw-routines/custom/"
cp "$REPO_ROOT/scripts/evonexus/patch-adw-runner-provider-env.py" \
   "$REPO_ROOT/scripts/evonexus/sync-providers-anthropic-from-env.py" \
   "$REPO_ROOT/scripts/evonexus/config/routines.aglz.yaml" "$HOST_STAGING/"
(cd "$HOST_STAGING" && tar czf - adw-routines patch-adw-runner-provider-env.py sync-providers-anthropic-from-env.py routines.aglz.yaml) \
  | pct exec "$CTID" -- tar xzf - -C /opt/evonexus

echo "==> Copiar para contentores"
for c in "${CONTAINERS[@]}"; do
  pct exec "$CTID" -- docker cp "${STAGING}/custom/." "${c}:/workspace/ADWs/routines/custom/"
  pct exec "$CTID" -- docker cp "${STAGING}/good_morning.py" "${c}:/workspace/ADWs/routines/good_morning.py"
  pct exec "$CTID" -- docker cp "${STAGING}/memory_sync.py" "${c}:/workspace/ADWs/routines/memory_sync.py"
  pct exec "$CTID" -- docker cp /opt/evonexus/patch-adw-runner-provider-env.py "${c}:/tmp/patch-adw-runner-provider-env.py"
  pct exec "$CTID" -- docker exec "$c" python3 /tmp/patch-adw-runner-provider-env.py /workspace/ADWs/runner.py
  pct exec "$CTID" -- docker exec -w /workspace/ADWs "$c" uv run python3 -c "from runner import _get_provider_config; print(_get_provider_config()[0], sorted(_get_provider_config()[1].keys()))"
  pct exec "$CTID" -- docker cp /opt/evonexus/sync-providers-anthropic-from-env.py "${c}:/tmp/sync-providers-anthropic-from-env.py"
  pct exec "$CTID" -- docker exec -w /workspace "$c" python3 /tmp/sync-providers-anthropic-from-env.py
done

pct exec "$CTID" -- docker cp /opt/evonexus/routines.aglz.yaml evonexus-scheduler:/workspace/config/routines.aglz.yaml

echo "==> Merge routines.yaml (preserva entradas existentes; sobrescreve daily/weekly AGLz)"
pct exec "$CTID" -- docker exec -w /workspace evonexus-scheduler uv run python3 << 'PY'
import yaml
from pathlib import Path

cfg = Path("/workspace/config/routines.yaml")
agl = Path("/opt/evonexus/routines.aglz.yaml")
if not agl.exists():
    agl = Path("/workspace/config/routines.aglz.yaml")

base = {}
if cfg.exists():
    base = yaml.safe_load(cfg.read_text()) or {}
overlay = yaml.safe_load(agl.read_text()) or {}

# daily: replace scripts we manage
managed_daily = {r["script"] for r in overlay.get("daily", [])}
base["daily"] = [r for r in base.get("daily", []) if r.get("script") not in managed_daily]
base.setdefault("daily", []).extend(overlay.get("daily", []))

managed_weekly = {r["script"] for r in overlay.get("weekly", [])}
base["weekly"] = [r for r in base.get("weekly", []) if r.get("script") not in managed_weekly]
base.setdefault("weekly", []).extend(overlay.get("weekly", []))

cfg.write_text(yaml.dump(base, allow_unicode=True, sort_keys=False))
print("routines.yaml atualizado:", cfg)
PY

echo "==> Sync inicial TASKS.md + testes rápidos"
pct exec "$CTID" -- docker exec -w /workspace evonexus-scheduler uv run python3 /workspace/ADWs/routines/custom/goals_tasks_sync.py
pct exec "$CTID" -- docker exec -w /workspace evonexus-scheduler uv run python3 /workspace/ADWs/routines/custom/mrr_update.py

echo "==> Reload scheduler (SIGHUP)"
pct exec "$CTID" -- docker exec evonexus-scheduler sh -c 'kill -HUP "$(cat /workspace/ADWs/logs/scheduler.pid 2>/dev/null)" 2>/dev/null || docker restart evonexus-scheduler'

echo "OK deploy CT${CTID}"
