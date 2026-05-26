#!/usr/bin/env bash
# Exporta endpoints ngrok actuais para o partner (CT244 fg-ngrok).
# Uso no FGSRV7: bash scripts/maint/fgsrv07/ngrok-partner-export-endpoints.sh
set -euo pipefail

CT_VMID="${CT_VMID:-244}"

pct exec "${CT_VMID}" -- bash -s <<'REMOTE'
set -euo pipefail
json=$(curl -sf http://127.0.0.1:4040/api/tunnels)
python3 - <<'PY' "$json"
import json, sys
from datetime import datetime, timezone

d = json.loads(sys.argv[1])
now = datetime.now(timezone.utc).isoformat()
print(f"FG partner ngrok endpoints — {now}\n")
for name in ("fg-legacy-web", "mysql7", "fg-legacy-ssh"):
    t = next((x for x in d.get("tunnels", []) if x.get("name") == name), None)
    if not t:
        print(f"{name}: INDISPONÍVEL")
        continue
    pub = t.get("public_url", "")
    if t.get("proto") == "http" or pub.startswith("https://"):
        print(f"{name}:")
        print(f"  url: {pub}")
        print(f"  upstream: {t.get('config', {}).get('addr', '?')}")
        print()
        continue
    pub = pub.replace("tcp://", "")
    host, port = pub.rsplit(":", 1)
    print(f"{name}:")
    print(f"  host: {host}")
    print(f"  port: {port}")
    print(f"  upstream: {t.get('config', {}).get('addr', '?')}")
    print()
PY
REMOTE
