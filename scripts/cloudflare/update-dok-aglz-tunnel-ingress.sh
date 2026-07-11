#!/usr/bin/env bash
# dok.aglz.io → CT180 Dokploy (:3000) no túnel aglsrv1 (CT117).
set -euo pipefail

ACCOUNT_ID="${CLOUDFLARE_ACCOUNT_ID:-08e7b6e3a5084b4a3a2e0b3de153b02e}"
TUNNEL_ID="${AGLSRV1_TUNNEL_ID:-f7ab6239-5cbd-44ef-83b9-ee8bfb4965ce}"
TOKEN="${CLOUDFLARE_API_TOKEN:-${CF_API_TOKEN:-}}"
DOK_ORIGIN="${DOK_AGLZ_ORIGIN:-http://192.168.0.180:3000}"

if [[ -z "${TOKEN}" ]]; then
  echo "Erro: defina CLOUDFLARE_API_TOKEN ou CF_API_TOKEN" >&2
  exit 1
fi

response=$(DOK_ORIGIN="${DOK_ORIGIN}" ACCOUNT_ID="${ACCOUNT_ID}" TUNNEL_ID="${TUNNEL_ID}" TOKEN="${TOKEN}" python3 <<'PY'
import json, os, urllib.request

account = os.environ["ACCOUNT_ID"]
tunnel = os.environ["TUNNEL_ID"]
token = os.environ["TOKEN"]
origin = os.environ["DOK_ORIGIN"]
url = f"https://api.cloudflare.com/client/v4/accounts/{account}/cfd_tunnel/{tunnel}/configurations"

req = urllib.request.Request(url, headers={"Authorization": f"Bearer {token}"})
with urllib.request.urlopen(req) as r:
    data = json.load(r)

ingress = data["result"]["config"]["ingress"]
warp = data["result"]["config"].get("warp-routing", {"enabled": True})

for rule in ingress:
    if rule.get("hostname") == "dok.aglz.io":
        rule["service"] = origin
        rule["originRequest"] = {"disableChunkedEncoding": True}
        break
else:
    catch = ingress.pop()
    ingress.append({"hostname": "dok.aglz.io", "service": origin, "originRequest": {"disableChunkedEncoding": True}})
    ingress.append(catch)

payload = json.dumps({"config": {"warp-routing": warp, "ingress": ingress}}).encode()
req = urllib.request.Request(url, data=payload, method="PUT", headers={
    "Authorization": f"Bearer {token}",
    "Content-Type": "application/json",
})
with urllib.request.urlopen(req) as r:
    print(json.dumps(json.load(r)))
PY
)

if echo "${response}" | python3 -c "import sys,json; d=json.load(sys.stdin); sys.exit(0 if d.get('success') else 1)"; then
  echo "OK: dok.aglz.io → ${DOK_ORIGIN}"
else
  echo "Falha:" >&2
  echo "${response}" >&2
  exit 1
fi
