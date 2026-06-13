#!/usr/bin/env bash
# DNS + ingress fgsrv7b para domínios legado FGz (CT549).
# Requer ~/.zshrc com bloco agl-hostman cloudflare credentials (FGz).
#
# Uso:
#   bash scripts/cloudflare/cutover-fgz-legacy-domains-dns.sh
#   bash scripts/cloudflare/cutover-fgz-legacy-domains-dns.sh --dry-run
set -euo pipefail

DRY_RUN=0
[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=1

eval "$(python3 - <<'PY'
import re
text = open("/root/.zshrc").read()
m = re.search(r"# >>> agl-hostman cloudflare credentials >>>(.*?)# <<<", text, re.S)
if not m:
    raise SystemExit("bloco cloudflare ausente em ~/.zshrc")
for line in m.group(1).splitlines():
    s = line.strip()
    if s.startswith("export "):
        print(s)
PY
)"

export DRY_RUN
python3 <<'PY'
import json
import os
import sys
import urllib.error
import urllib.request

email = os.environ["CLOUDFLARE_EMAIL_FGZ"]
key = os.environ["CLOUDFLARE_API_KEY_FGZ"]
acct = os.environ.get("CLOUDFLARE_ACCOUNT_ID_FGZ", "275896c4ed8b42fc3d4c62adcb5076ce")
tunnel = os.environ.get("FGSRV7B_TUNNEL_ID", "850f2d28-367f-4bd2-a887-6998240828e3")
tunnel_cname = tunnel + ".cfargotunnel.com"
origin = os.environ.get("FG_LEGACY_ORIGIN", "http://192.168.70.243")
dry = os.environ.get("DRY_RUN", "0") == "1"

# zonas FGz (portalalphaville.com.br não está nesta conta — usar portalalphavilletambore.com.br)
ZONES = {
    "alphavilletambore.com.br": "1e19336f26b9744ee4ff6005626c607c",
    "portalalphavilletambore.com.br": "c01c36e0ec52494d7a6e1b69293ca5e6",
}

INGRESS_HOSTS = [
    "falg.com.br",
    "www.falg.com.br",
    "falgimoveis.com",
    "www.falgimoveis.com",
    "alphavilletambore.com.br",
    "www.alphavilletambore.com.br",
    "portalalphavilletambore.com.br",
    "www.portalalphavilletambore.com.br",
]


def api(path, method="GET", data=None):
    headers = {"X-Auth-Email": email, "X-Auth-Key": key, "Content-Type": "application/json"}
    body = json.dumps(data).encode() if data is not None else None
    req = urllib.request.Request(
        "https://api.cloudflare.com/client/v4" + path, data=body, method=method, headers=headers
    )
    with urllib.request.urlopen(req, timeout=45) as r:
        return json.loads(r.read())


def cutover_zone(zname, zid):
    print(f"\n=== Zona {zname} ===")
    recs = api(f"/zones/{zid}/dns_records?per_page=100")
    targets = {zname, f"www.{zname}"}
    for rec in recs.get("result", []):
        if rec["name"] not in targets:
            continue
        if rec["type"] in ("A", "AAAA"):
            print(f"  DELETE {rec['type']} {rec['name']} -> {rec['content']}")
            if not dry:
                api(f"/zones/{zid}/dns_records/{rec['id']}", "DELETE")

    for name in (zname, f"www.{zname}"):
        existing = api(f"/zones/{zid}/dns_records?name={name}")
        cnames = [r for r in existing.get("result", []) if r["type"] == "CNAME"]
        content = tunnel_cname if name == zname else zname
        payload = {"type": "CNAME", "name": name, "content": content, "proxied": True}
        if cnames:
            rid = cnames[0]["id"]
            print(f"  PUT CNAME {name} -> {content} (proxied)")
            if not dry:
                api(f"/zones/{zid}/dns_records/{rid}", "PUT", payload)
        else:
            print(f"  POST CNAME {name} -> {content} (proxied)")
            if not dry:
                api(f"/zones/{zid}/dns_records", "POST", payload)


def update_tunnel():
    print("\n=== Ingress fgsrv7b ===")
    cfg_url = f"/accounts/{acct}/cfd_tunnel/{tunnel}/configurations"
    current = api(cfg_url)
    ingress = current["result"]["config"].get("ingress", [])
    warp = current["result"]["config"].get("warp-routing", {"enabled": False})
    catch = None
    rules = []
    for rule in ingress:
        if rule.get("service") == "http_status:404" or rule.get("hostname") is None:
            catch = rule
        else:
            rules.append(rule)
    existing = {r.get("hostname") for r in rules}
    added = []
    for h in INGRESS_HOSTS:
        if h not in existing:
            rules.append(
                {
                    "hostname": h,
                    "service": origin,
                    "originRequest": {"disableChunkedEncoding": True},
                }
            )
            added.append(h)
    rules.append(catch if catch else {"service": "http_status:404"})
    print("  novos hostnames:", added or "(nenhum)")
    if dry:
        return
    resp = api(cfg_url, "PUT", {"config": {"ingress": rules, "warp-routing": warp}})
    if not resp.get("success"):
        raise SystemExit("Falha PUT tunnel: " + json.dumps(resp))


for zname, zid in ZONES.items():
    cutover_zone(zname, zid)

update_tunnel()
print("OK" if not dry else "DRY-RUN OK")
PY
