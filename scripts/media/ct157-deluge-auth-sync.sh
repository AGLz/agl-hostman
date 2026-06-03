#!/usr/bin/env bash
# Sincroniza password Deluge daemon (CT157) com Radarr "Deluge AGLSRV1".
# Corrige web UI sem default_daemon e auth desalinhado.
#
# Uso:
#   bash scripts/media/ct157-deluge-auth-sync.sh --apply

set -euo pipefail

AGLSRV1="${AGLSRV1:-root@100.107.113.33}"
APPLY=false
for a in "$@"; do [[ "$a" == --apply ]] && APPLY=true; done

if [[ "$APPLY" != true ]]; then
  echo "Dry-run. Aplicar: bash scripts/media/ct157-deluge-auth-sync.sh --apply"
  exit 0
fi

ssh -o BatchMode=yes "$AGLSRV1" "bash -s" <<'REMOTE'
set -euo pipefail
VMID=157
PASS=$(pct exec 123 -- python3 -c "import json,sqlite3;c=sqlite3.connect('/var/lib/radarr/radarr.db');print(json.loads(c.execute(\"SELECT Settings FROM DownloadClients WHERE Name='Deluge AGLSRV1'\").fetchone()[0])['password'])")
DAEMON_ID="3c9e93c9615b40579e138a5fb8f273a1"

# Deluge auth file guarda password em texto plano (ver AuthManager.authorize)
pct exec "$VMID" -- bash -c "echo localclient:${PASS}:10 > /root/.config/deluge/auth"

# default_daemon no web.conf (segundo bloco JSON)
pct exec "$VMID" -- python3 <<'PY'
import json
from pathlib import Path

path = Path("/root/.config/deluge/web.conf")
raw = path.read_text()
parts = raw.split("}{")
objs = []
for i, ch in enumerate(parts):
    if i == 0:
        ch = ch + "}"
    elif i == len(parts) - 1:
        ch = "{" + ch
    else:
        ch = "{" + ch + "}"
    objs.append(json.loads(ch))
objs[1]["default_daemon"] = "3c9e93c9615b40579e138a5fb8f273a1"
path.write_text(json.dumps(objs[0], indent=4) + json.dumps(objs[1], indent=4))
print("default_daemon=", objs[1]["default_daemon"])
PY

pct exec "$VMID" -- systemctl restart deluged
sleep 2
pct exec "$VMID" -- systemctl restart deluge-web
echo "Deluge CT157 auth/web reiniciados (password alinhado com Radarr)."
REMOTE
