#!/usr/bin/env bash
# Copia /opt/agl-openclaw do CT187 → CT191 no mesmo nó Proxmox (sem segredos no git).
# Executar no AGLSRV1 como root.
set -euo pipefail

command -v pct >/dev/null || { echo "pct required" >&2; exit 1; }

echo "=== Parar gateway CT191 se existir ==="
pct exec 191 -- bash -c 'cd /opt/agl-openclaw 2>/dev/null && docker compose down 2>/dev/null || true' || true

echo "=== Stream /opt/agl-openclaw 187 → 191 ==="
pct exec 187 -- tar czf - -C /opt agl-openclaw | pct exec 191 -- tar xzf - -C /opt

pct exec 191 -- bash -c 'chown -R 1000:1000 /opt/agl-openclaw/config /opt/agl-openclaw/workspace 2>/dev/null || true'
echo "OK: OpenClaw copiado para CT191"
