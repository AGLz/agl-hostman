#!/usr/bin/env bash
# Actualiza ingress remoto do túnel archon: ah.aglz.io → CT134 prod (:80).
# Opcional: ah-dev.aglz.io → origin dev (CT179).
#
# Requer CLOUDFLARE_API_TOKEN com Cloudflare Tunnel Edit + Account read.
set -euo pipefail

ACCOUNT_ID="${CLOUDFLARE_ACCOUNT_ID:-08e7b6e3a5084b4a3a2e0b3de153b02e}"
# DNS ah.aglz.io → f7ab6239 (aglsrv1, CT117). Não usar aglsrv1b/archon (908b1097).
TUNNEL_ID="${AGLSRV1_TUNNEL_ID:-f7ab6239-5cbd-44ef-83b9-ee8bfb4965ce}"
TOKEN="${CLOUDFLARE_API_TOKEN:-${CF_API_TOKEN:-}}"
AH_ORIGIN="${AH_AGLZ_ORIGIN:-http://192.168.0.134:80}"
AH_DEV_ORIGIN="${AH_DEV_AGLZ_ORIGIN:-http://192.168.0.181:8055}"

if [[ -z "${TOKEN}" ]]; then
    echo "Erro: defina CLOUDFLARE_API_TOKEN ou CF_API_TOKEN" >&2
    exit 1
fi

response=$(AH_ORIGIN="${AH_ORIGIN}" AH_DEV_ORIGIN="${AH_DEV_ORIGIN}" ACCOUNT_ID="${ACCOUNT_ID}" TUNNEL_ID="${TUNNEL_ID}" TOKEN="${TOKEN}" python3 <<'PY'
import json
import os
import urllib.request

account = os.environ["ACCOUNT_ID"]
tunnel = os.environ["TUNNEL_ID"]
token = os.environ["TOKEN"]
ah = os.environ["AH_ORIGIN"]
ah_dev = os.environ["AH_DEV_ORIGIN"]
url = f"https://api.cloudflare.com/client/v4/accounts/{account}/cfd_tunnel/{tunnel}/configurations"

req = urllib.request.Request(url, headers={"Authorization": f"Bearer {token}"})
with urllib.request.urlopen(req) as r:
    data = json.load(r)

ingress = data["result"]["config"]["ingress"]
warp = data["result"]["config"].get("warp-routing", {"enabled": True})

def patch(hostname, service):
    for rule in ingress:
        if rule.get("hostname") == hostname:
            rule["service"] = service
            rule["originRequest"] = {"disableChunkedEncoding": True}
            return True
    catch = ingress.pop()
    ingress.append({"hostname": hostname, "service": service, "originRequest": {"disableChunkedEncoding": True}})
    ingress.append(catch)
    return False

patch("ah.aglz.io", ah)
patch("ah-dev.aglz.io", ah_dev)

payload = json.dumps({"config": {"warp-routing": warp, "ingress": ingress}}).encode()
req = urllib.request.Request(
    url, data=payload, method="PUT",
    headers={"Authorization": f"Bearer {token}", "Content-Type": "application/json"},
)
with urllib.request.urlopen(req) as r:
    out = json.load(r)

print(json.dumps(out))
PY
)

if echo "${response}" | python3 -c "import sys,json; d=json.load(sys.stdin); sys.exit(0 if d.get('success') else 1)"; then
    echo "OK: tunnel ${TUNNEL_ID}"
    echo "OK: ah.aglz.io → ${AH_ORIGIN}"
    echo "OK: ah-dev.aglz.io → ${AH_DEV_ORIGIN}"
    echo "Nota: reiniciar cloudflared no CT117 se o origin não actualizar em ~30s"
else
    echo "Falha ao actualizar ingress remoto:" >&2
    echo "${response}" >&2
    exit 1
fi
