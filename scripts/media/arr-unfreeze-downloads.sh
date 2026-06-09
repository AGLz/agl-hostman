#!/usr/bin/env bash
# Reactiva downloads no stack *arr (após confirmar espaço em storage).
# Uso: arr-unfreeze-downloads.sh
# ATENÇÃO: só correr quando root folders tiverem espaço livre.

set -euo pipefail

AGLSRV1="${AGLSRV1:-root@100.107.113.33}"

read -r -p "Confirmas espaço livre no storage e queres reactivar downloads? [y/N] " ans
if [[ "${ans,,}" != "y" && "${ans,,}" != "yes" ]]; then
  echo "Abortado."
  exit 1
fi

ssh "$AGLSRV1" "bash -s" <<'REMOTE'
set -euo pipefail

read_key() { pct exec "$1" -- grep -oP '(?<=<ApiKey>)[^<]+' "/var/lib/$3/config.xml" 2>/dev/null | head -1; }

RADARR_KEY=$(read_key 123 radarr radarr)
SONARR_KEY=$(read_key 124 sonarr sonarr)
PROWLARR_KEY=$(read_key 172 prowlarr prowlarr)

# Clientes AGLSRV1 após consolidate (torrent: só qBit; Usenet: SAB)
ENABLE_NAMES=("qBittorrent AGLSRV1" "SABnzbd AGLSRV1")

enable_clients() {
  local ct=$1 port=$2 key=$3 label=$4
  pct exec "$ct" -- python3 - "$port" "$key" "$label" <<'PY'
import json, sys, urllib.request
port, key, label = sys.argv[1], sys.argv[2], sys.argv[3]
want = {"qBittorrent AGLSRV1", "SABnzbd AGLSRV1"}
base = f"http://127.0.0.1:{port}/api/v3/downloadclient"
clients = json.load(urllib.request.urlopen(urllib.request.Request(base, headers={"X-Api-Key": key})))
for c in clients:
    if c["name"] not in want:
        continue
    c["enable"] = True
    body = json.dumps(c).encode()
    put = urllib.request.Request(
        f"{base}/{c['id']}", data=body,
        headers={"X-Api-Key": key, "Content-Type": "application/json"}, method="PUT",
    )
    urllib.request.urlopen(put)
    print(f"{label}: enabled {c['name']}")
PY
}

prowlarr_unfreeze() {
  pct exec 172 -- python3 - "$PROWLARR_KEY" <<'PY'
import json, sys, urllib.request
key = sys.argv[1]
base = "http://127.0.0.1:9696/api/v1/appprofile"
profiles = json.load(urllib.request.urlopen(urllib.request.Request(base, headers={"X-Api-Key": key})))
for p in profiles:
    if p["name"] != "Standard":
        continue
    p["enableRss"] = True
    p["enableAutomaticSearch"] = True
    p["enableInteractiveSearch"] = True
    body = json.dumps(p).encode()
    put = urllib.request.Request(
        f"{base}/{p['id']}", data=body,
        headers={"X-Api-Key": key, "Content-Type": "application/json"}, method="PUT",
    )
    urllib.request.urlopen(put)
    print("Prowlarr Standard: RSS=ON, AutoSearch=ON")
PY
}

prowlarr_unfreeze
enable_clients 123 7878 "$RADARR_KEY" Radarr
enable_clients 124 8989 "$SONARR_KEY" Sonarr
pct exec 144 -- systemctl start autobrr 2>/dev/null && echo "Autobrr: started" || echo "Autobrr: start skipped"
echo "Unfreeze applied. Monitor queue and disk usage."
REMOTE

echo "Done."
