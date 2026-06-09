#!/usr/bin/env bash
# Verifica alinhamento de paths com modelo TRaSH (/mnt/overpower, categorias *arr*).
#
# Uso:
#   bash scripts/media/arr-data-paths-verify.sh

set -euo pipefail

AGLSRV1="${AGLSRV1:-root@100.107.113.33}"
run() { ssh -o ConnectTimeout=15 -o BatchMode=yes "$AGLSRV1" "$@"; }

echo "=== TRaSH paths — verificação AGLSRV1 ==="
echo ""

run "bash -s" <<'REMOTE'
set -euo pipefail

check_ct() {
  local vmid="$1" name="$2"
  echo "--- CT${vmid} (${name}) ---"
  if ! pct status "$vmid" | grep -q running; then
    echo "  WARN: CT parado"
    return
  fi
  pct config "$vmid" | grep '^mp1:' || echo "  WARN: sem mp1 overpower"
  pct exec "$vmid" -- bash -c '
    for p in /mnt/overpower /mnt/overpower/downs/torDownloading /mnt/overpower/downs/torFinished /mnt/storage; do
      if [[ -d "$p" ]]; then echo "  OK dir $p"; else echo "  MISS $p"; fi
    done
    df -h /mnt/overpower 2>/dev/null | tail -1 | sed "s/^/  /"
  ' 2>/dev/null || echo "  exec failed"
}

check_ct 121 "qBittorrent"
check_ct 123 "Radarr"
check_ct 124 "Sonarr"
check_ct 141 "SABnzbd"
check_ct 165 "aria2"

echo ""
echo "--- qBittorrent paths (CT121) ---"
pct exec 121 -- grep -E 'Session\\(DefaultSavePath|TempPath)' /.config/qBittorrent/qBittorrent.conf 2>/dev/null | head -5 || true

echo ""
echo "--- SAB paths (CT141) ---"
pct exec 141 -- grep -E '^(download_dir|complete_dir)' /root/.sabnzbd/sabnzbd.ini 2>/dev/null | head -5 || true

echo ""
echo "--- aria2 dir (CT165) ---"
pct exec 165 -- grep '^dir=' /root/aria2.daemon 2>/dev/null || true

echo ""
echo "--- Radarr root folders (amostra) ---"
pct exec 123 -- python3 -c "
import json, sqlite3
c = sqlite3.connect('/var/lib/radarr/radarr.db')
for row in c.execute('SELECT Path FROM RootFolders LIMIT 8'):
    p = row[0]
    import os
    ok = os.path.isdir(p)
    print(f\"  {'OK' if ok else 'MISS'} {p}\")
" 2>/dev/null || true

echo ""
echo "--- Download clients Radarr (activos) ---"
pct exec 123 -- python3 -c "
import json, sqlite3
c = sqlite3.connect('/var/lib/radarr/radarr.db')
for name, settings, enable in c.execute('SELECT Name, Settings, Enable FROM DownloadClients'):
    s = json.loads(settings)
    host = s.get('host') or s.get('Host') or '?'
    print(f\"  {'ON' if enable else 'OFF'} {name} host={host}\")
" 2>/dev/null || true

echo ""
echo "Referência TRaSH: downloads em /data/torrents e /data/usenet sob mesmo FS que /data/media"
echo "AGL: equivalente /mnt/overpower/downs/* e biblioteca /mnt/overpower/media ou /mnt/storage/*"
REMOTE
