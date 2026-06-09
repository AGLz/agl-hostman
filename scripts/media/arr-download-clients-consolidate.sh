#!/usr/bin/env bash
# Fase C — qBittorrent único cliente torrent nos *arr (Radarr/Sonarr AGLSRV1).
# Deluge/Aria2 e clientes remotos permanecem desactivados.
# SABnzbd mantém-se para Usenet (activo só no unfreeze).
#
# Uso:
#   bash scripts/media/arr-download-clients-consolidate.sh              # dry-run
#   bash scripts/media/arr-download-clients-consolidate.sh --apply
#
# Não reactiva downloads — compatível com arr-freeze-downloads.

set -euo pipefail

AGLSRV1="${AGLSRV1:-root@100.107.113.33}"
APPLY=false
for a in "$@"; do
  [[ "$a" == --apply ]] && APPLY=true
done

run() { ssh -o ConnectTimeout=15 -o BatchMode=yes "$AGLSRV1" "$@"; }

echo "=== Consolidar download clients (*arr AGLSRV1) ==="
echo "Torrent activo alvo: qBittorrent AGLSRV1 (CT121)"
echo "Desactivar: Deluge, Aria2, clientes remotos (AGLLX06, AGLWK06, …)"
echo "Usenet: SABnzbd AGLSRV1 (mantém config; enable só no unfreeze)"
echo "Modo: $([[ "$APPLY" == true ]] && echo APPLY || echo dry-run)"
echo ""

run "bash -s" "$APPLY" <<'REMOTE'
set -euo pipefail
APPLY="${1:-false}"

read_key() { pct exec "$1" -- grep -oP '(?<=<ApiKey>)[^<]+' "/var/lib/$3/config.xml" 2>/dev/null | head -1; }

RADARR_KEY=$(read_key 123 radarr radarr)
SONARR_KEY=$(read_key 124 sonarr sonarr)

# Nome exacto → enable no unfreeze; priority torrent (menor = preferido)
TORRENT_PRIMARY="qBittorrent AGLSRV1"
USENET_PRIMARY="SABnzbd AGLSRV1"
# Sempre OFF nos *arr AGLSRV1 (backup/bench)
TORRENT_DISABLE=(
  "Deluge AGLSRV1"
  "Aria2 AGLSRV1"
  "qBittorrent AGLLX06"
  "Deluge AGLWK06"
)

consolidate() {
  local ct=$1 port=$2 key=$3 label=$4
  pct exec "$ct" -- python3 - "$port" "$key" "$label" "$APPLY" "$TORRENT_PRIMARY" "$USENET_PRIMARY" <<'PY'
import json, sys, urllib.request

port, key, label, apply = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4] == "true"
torrent_primary, usenet_primary = sys.argv[5], sys.argv[6]
disable_names = {
    "Deluge AGLSRV1", "Aria2 AGLSRV1",
    "qBittorrent AGLLX06", "Deluge AGLWK06",
}

base = f"http://127.0.0.1:{port}/api/v3/downloadclient"
req = urllib.request.Request(base, headers={"X-Api-Key": key})
clients = json.load(urllib.request.urlopen(req))

def is_torrent(c):
    impl = (c.get("implementation") or "").lower()
    return "torrent" in impl or "qbittorrent" in impl or "deluge" in impl or "aria2" in impl

def is_usenet(c):
    impl = (c.get("implementation") or "").lower()
    return "sabnzbd" in impl or "nzbget" in impl

changes = []
for c in clients:
    name = c["name"]
    # Mantém freeze: nunca activar aqui (só arr-unfreeze-downloads.sh)
    want_enable = False
    if name == torrent_primary:
        c["priority"] = 1
    elif is_torrent(c):
        c["priority"] = 50
    if name in disable_names:
        want_enable = False
    old = f"enable={c.get('enable')} prio={c.get('priority')}"
    if c.get("enable"):
        c["enable"] = False
    if name == torrent_primary and c.get("priority") != 1:
        c["priority"] = 1
    elif is_torrent(c) and name != torrent_primary and c.get("priority") != 50:
        c["priority"] = 50
    new = f"enable={c.get('enable')} prio={c.get('priority')}"
    if old != new:
        changes.append((name, old, new))
        if apply:
            body = json.dumps(c).encode()
            put = urllib.request.Request(
                f"{base}/{c['id']}", data=body,
                headers={"X-Api-Key": key, "Content-Type": "application/json"},
                method="PUT",
            )
            urllib.request.urlopen(put)

print(f"--- {label} ---")
for c in sorted(clients, key=lambda x: (x.get("priority", 99), x["name"])):
    proto = "usenet" if is_usenet(c) else ("torrent" if is_torrent(c) else "?")
    print(f"  {c['name']}: enable={c.get('enable')} priority={c.get('priority')} ({proto})")

if not changes:
    print(f"{label}: já consolidado")
else:
    for name, old, new in changes:
        action = "APPLY" if apply else "would"
        print(f"{label}: {action} {name}: {old} -> {new}")
PY
}

consolidate 123 7878 "$RADARR_KEY" Radarr
consolidate 124 8989 "$SONARR_KEY" Sonarr
echo ""
echo "Unfreeze futuro: apenas qBittorrent AGLSRV1 + SABnzbd AGLSRV1 (ver arr-unfreeze-downloads.sh)"
REMOTE
