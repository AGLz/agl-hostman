#!/usr/bin/env bash
# Reactiva apenas grabs (Prowlarr RSS + pesquisa automática).
# Não activa clientes de download — usar arr-unfreeze-downloads.sh para isso.
#
# Uso: arr-enable-grabs.sh [--verify-only]

set -euo pipefail

AGLSRV1="${AGLSRV1:-root@100.107.113.33}"
VERIFY_ONLY="${1:-}"

ssh "$AGLSRV1" bash -s -- "$VERIFY_ONLY" <<'REMOTE'
set -euo pipefail
VERIFY_ONLY="${1:-}"
PROWLARR_KEY=$(pct exec 172 -- grep -oP '(?<=<ApiKey>)[^<]+' /var/lib/prowlarr/config.xml | head -1)

pct exec 172 -- python3 - "$PROWLARR_KEY" "$VERIFY_ONLY" <<'PY'
import json, sys, urllib.request
key, verify = sys.argv[1], sys.argv[2] == "--verify-only"
base = "http://127.0.0.1:9696/api/v1/appprofile"
profiles = json.load(urllib.request.urlopen(urllib.request.Request(base, headers={"X-Api-Key": key})))
for p in profiles:
    if p["name"] != "Standard":
        continue
    state = {k: p[k] for k in ("enableRss", "enableAutomaticSearch", "enableInteractiveSearch")}
    if verify:
        print(f"Prowlarr Standard: {state}")
        raise SystemExit(0)
    p["enableRss"] = True
    p["enableAutomaticSearch"] = True
    p["enableInteractiveSearch"] = True
    body = json.dumps(p).encode()
    put = urllib.request.Request(
        f"{base}/{p['id']}", data=body,
        headers={"X-Api-Key": key, "Content-Type": "application/json"}, method="PUT",
    )
    urllib.request.urlopen(put)
    print("Prowlarr Standard: RSS=ON, AutoSearch=ON, Interactive=ON")
PY
REMOTE

echo "Done. Downloads continuam congelados até arr-unfreeze-downloads.sh"
