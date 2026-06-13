#!/usr/bin/env bash
# Garante ingress remoto harbor.aglz.io no túnel aglsrv1 (CT117 token / f7ab6239).
# Requer CLOUDFLARE_API_TOKEN com Cloudflare Tunnel Edit + Account read.
set -euo pipefail

ACCOUNT_ID="${CLOUDFLARE_ACCOUNT_ID:-08e7b6e3a5084b4a3a2e0b3de153b02e}"
TUNNEL_ID="${AGLSRV1_TUNNEL_ID:-f7ab6239-5cbd-44ef-83b9-ee8bfb4965ce}"
HARBOR_ORIGIN="${HARBOR_ORIGIN:-https://192.168.0.182:443}"
TOKEN="${CLOUDFLARE_API_TOKEN:-${CF_API_TOKEN:-}}"

if [[ -z "${TOKEN}" ]]; then
    echo "Erro: defina CLOUDFLARE_API_TOKEN ou CF_API_TOKEN" >&2
    exit 1
fi

export ACCOUNT_ID TUNNEL_ID TOKEN HARBOR_ORIGIN

python3 <<'PY'
import json, os, sys, urllib.request

account = os.environ["ACCOUNT_ID"]
token = os.environ["TOKEN"]
tunnel = os.environ["TUNNEL_ID"]
origin = os.environ["HARBOR_ORIGIN"]

def api(method, path, data=None):
    req = urllib.request.Request(
        f"https://api.cloudflare.com/client/v4/accounts/{account}{path}",
        method=method,
        headers={"Authorization": f"Bearer {token}", "Content-Type": "application/json"},
        data=json.dumps(data).encode() if data is not None else None,
    )
    with urllib.request.urlopen(req) as resp:
        return json.load(resp)

current = api("GET", f"/cfd_tunnel/{tunnel}/configurations")
if not current.get("success"):
    print(json.dumps(current, indent=2), file=sys.stderr)
    sys.exit(1)

config = current["result"]["config"]
ingress = [r for r in config.get("ingress", []) if r.get("hostname") != "harbor.aglz.io"]
harbor_rule = {
    "hostname": "harbor.aglz.io",
    "service": origin,
    "originRequest": {"noTLSVerify": True, "disableChunkedEncoding": True},
}
catch_idx = next(
    (i for i, r in enumerate(ingress) if str(r.get("service", "")).startswith("http_status:")),
    len(ingress),
)
ingress.insert(catch_idx, harbor_rule)

payload = {
    "config": {
        "warp-routing": config.get("warp-routing", {"enabled": True}),
        "ingress": ingress,
    }
}
result = api("PUT", f"/cfd_tunnel/{tunnel}/configurations", payload)
if not result.get("success"):
    print(json.dumps(result, indent=2), file=sys.stderr)
    sys.exit(1)
print(f"OK: harbor.aglz.io → {origin} (posição {catch_idx})")
PY
