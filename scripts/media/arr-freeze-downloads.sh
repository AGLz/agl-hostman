#!/usr/bin/env bash
# Congela apenas DOWNLOADS no stack *arr (AGLSRV1).
# Grabs (Prowlarr RSS + pesquisa automática) mantêm-se activos por defeito.
#
# Uso:
#   arr-freeze-downloads.sh              # downloads OFF, grabs ON
#   arr-freeze-downloads.sh --verify-only
#   arr-freeze-downloads.sh --no-grabs   # downloads OFF + Prowlarr RSS/auto OFF
#
# Requer: ssh root@AGLSRV1 (Tailscale 100.107.113.33)

set -euo pipefail

AGLSRV1="${AGLSRV1:-root@100.107.113.33}"
MODE="${1:-}"

ssh "$AGLSRV1" bash -s -- "$MODE" <<'REMOTE'
set -euo pipefail
MODE="${1:-}"
NO_GRABS=false
VERIFY_ONLY=false

case "$MODE" in
  --verify-only) VERIFY_ONLY=true ;;
  --no-grabs) NO_GRABS=true ;;
  "") ;;
  *) echo "Uso: [--verify-only|--no-grabs]"; exit 2 ;;
esac

read_key() { pct exec "$1" -- grep -oP '(?<=<ApiKey>)[^<]+' "/var/lib/$3/config.xml" 2>/dev/null | head -1; }

RADARR_KEY=$(read_key 123 radarr radarr)
SONARR_KEY=$(read_key 124 sonarr sonarr)
PROWLARR_KEY=$(read_key 172 prowlarr prowlarr)

disable_clients() {
  local ct=$1 port=$2 key=$3 label=$4
  pct exec "$ct" -- python3 - "$port" "$key" "$label" "$VERIFY_ONLY" <<'PY'
import json, sys, urllib.request
port, key, label, verify = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
base = f"http://127.0.0.1:{port}/api/v3/downloadclient"
clients = json.load(urllib.request.urlopen(urllib.request.Request(base, headers={"X-Api-Key": key})))
enabled = [c for c in clients if c.get("enable")]
if verify:
    print(f"{label}: enabled={[c['name'] for c in enabled]}")
    raise SystemExit(0)
for c in enabled:
    c["enable"] = False
    body = json.dumps(c).encode()
    put = urllib.request.Request(
        f"{base}/{c['id']}", data=body,
        headers={"X-Api-Key": key, "Content-Type": "application/json"}, method="PUT",
    )
    urllib.request.urlopen(put)
    print(f"{label}: disabled {c['name']}")
if not enabled:
    print(f"{label}: downloads already frozen")
PY
}

prowlarr_set() {
  local rss=$1 auto=$2
  pct exec 172 -- python3 - "$PROWLARR_KEY" "$VERIFY_ONLY" "$rss" "$auto" <<'PY'
import json, sys, urllib.request
key, verify, rss, auto = sys.argv[1], sys.argv[2], sys.argv[3] == "true", sys.argv[4] == "true"
base = "http://127.0.0.1:9696/api/v1/appprofile"
profiles = json.load(urllib.request.urlopen(urllib.request.Request(base, headers={"X-Api-Key": key})))
for p in profiles:
    if p["name"] != "Standard":
        continue
    state = {k: p[k] for k in ("enableRss", "enableAutomaticSearch", "enableInteractiveSearch")}
    if verify:
        print(f"Prowlarr Standard: {state}")
        raise SystemExit(0)
    p["enableRss"] = rss
    p["enableAutomaticSearch"] = auto
    p["enableInteractiveSearch"] = True
    body = json.dumps(p).encode()
    put = urllib.request.Request(
        f"{base}/{p['id']}", data=body,
        headers={"X-Api-Key": key, "Content-Type": "application/json"}, method="PUT",
    )
    urllib.request.urlopen(put)
    print(f"Prowlarr Standard: RSS={'ON' if rss else 'OFF'}, AutoSearch={'ON' if auto else 'OFF'}, Interactive=ON")
PY
}

disable_clients 123 7878 "$RADARR_KEY" Radarr
disable_clients 124 8989 "$SONARR_KEY" Sonarr

if $NO_GRABS; then
  prowlarr_set false false
else
  prowlarr_set true true
fi

if $VERIFY_ONLY; then
  pct exec 144 -- systemctl is-active autobrr 2>/dev/null && echo "Autobrr: active (envia para qBit — parar manualmente)" || echo "Autobrr: inactive"
  exit 0
fi

pct exec 144 -- systemctl stop autobrr 2>/dev/null && echo "Autobrr: stopped" || echo "Autobrr: stop skipped"
if $NO_GRABS; then
  echo "Mode: downloads OFF + grabs OFF"
else
  echo "Mode: downloads OFF, grabs ON (Prowlarr RSS/auto)"
fi
echo "See docs/MEDIA-ARR-MAINTENANCE.md"
REMOTE

echo "Done."
