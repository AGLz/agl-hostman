#!/usr/bin/env bash
# Provisiona *.mm01.aglz.io no túnel archon (CT117) — NÃO aglsrv1 (f7ab6239).
# Origin: CT194 agl-makemoney01 @ 192.168.0.194:80 (nginx multi-vhost).
set -euo pipefail

ARCHON_TUNNEL_ID="${ARCHON_TUNNEL_ID:-908b1097-e182-4725-9960-626ecc003375}"
MM01_ORIGIN="${MM01_ORIGIN:-http://192.168.0.194:80}"
DOMAIN_BASE="${MM01_DOMAIN_BASE:-mm01.aglz.io}"
ZONE_NAME="${ZONE_NAME:-aglz.io}"
PROXMOX="${PROXMOX_SSH:-aglsrv1}"
CT_CLOUDFLARED="${CT_CLOUDFLARED:-117}"
CONFIG_PATH="/root/.cloudflared/config.yml"
SERVICE="cloudflared-archon.service"

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
MANIFEST="${MM01_MANIFEST:-${ROOT}/../makemoney01/config/niche-projects.json}"
if [[ ! -f "${MANIFEST}" ]]; then
  MANIFEST="/mnt/overpower/apps/dev/agl/makemoney01/config/niche-projects.json"
fi

TOKEN="${CLOUDFLARE_API_TOKEN:-${CF_API_TOKEN:-}}"
if [[ -z "${TOKEN}" ]]; then
  TOKEN="$(ssh -o BatchMode=yes "${PROXMOX}" "pct exec ${CT_CLOUDFLARED} -- python3 -c \"import json; print(json.load(open('/root/.cloudflared/cert.pem'))['apiToken'])\"" 2>/dev/null || true)"
fi
[[ -n "${TOKEN}" ]] || { echo "ERRO: CLOUDFLARE_API_TOKEN em falta" >&2; exit 1; }

export ARCHON_TUNNEL_ID MM01_ORIGIN DOMAIN_BASE MANIFEST CONFIG_PATH

HOSTNAMES="$(python3 <<'PY'
import json, os
from pathlib import Path
data = json.loads(Path(os.environ["MANIFEST"]).read_text())
base = data["ct"]["domain_base"]
slugs = [p["slug"] for p in data["projects"]]
hosts = [base] + [f"{s}.{base}" for s in slugs]
gw = Path(os.environ["MANIFEST"]).parent / "demo-gateway.json"
if gw.is_file():
    pub = json.loads(gw.read_text()).get("public_domain")
    if pub:
        hosts.append(pub)
saas = Path(os.environ["MANIFEST"]).parent / "saas-gateway.json"
if saas.is_file():
    staging = json.loads(saas.read_text()).get("staging_domain")
    if staging:
        hosts.append(staging)
print("\n".join(hosts))
PY
)"

echo "=== mm01 → túnel archon (${ARCHON_TUNNEL_ID}) ==="
echo "Origin: ${MM01_ORIGIN}"
echo "Hostnames: $(echo "${HOSTNAMES}" | wc -l)"

# --- 1) Actualizar config.yml local no CT117 (archon usa ficheiro, não token aglsrv1) ---
ssh -o BatchMode=yes "${PROXMOX}" "pct exec ${CT_CLOUDFLARED} -- env MM01_ORIGIN='${MM01_ORIGIN}' CONFIG_PATH='${CONFIG_PATH}' python3 -" <<PY
import os, re, sys
from pathlib import Path

origin = os.environ["MM01_ORIGIN"]
config_path = Path(os.environ["CONFIG_PATH"])
hosts = """${HOSTNAMES}""".strip().splitlines()

text = config_path.read_text()
if "ingress:" not in text:
    sys.exit("ingress: em falta em config.yml")

before, rest = text.split("ingress:", 1)
body = rest.lstrip("\n")
lines = body.splitlines()
catch_idx = next(
    (i for i, l in enumerate(lines) if re.match(r"\s*-\s+service:\s+http_status:", l)),
    len(lines),
)
existing = set()
for line in lines:
    m = re.search(r"hostname:\s*(\S+)", line)
    if m:
        existing.add(m.group(1))

new_blocks = []
for h in hosts:
    if h in existing:
        continue
    new_blocks.extend([
        f"  - hostname: {h}",
        f"    service: {origin}",
        "    originRequest:",
        "      disableChunkedEncoding: true",
        "",
    ])

if new_blocks:
    lines[catch_idx:catch_idx] = new_blocks
    config_path.write_text(before + "ingress:\n" + "\n".join(lines).rstrip() + "\n")
    print(f"OK config.yml: +{len(hosts) - len(existing & set(hosts))} hostnames")
else:
    print("OK config.yml: hostnames mm01 já presentes")
PY

ssh -o BatchMode=yes "${PROXMOX}" "pct exec ${CT_CLOUDFLARED} -- systemctl restart ${SERVICE}"
sleep 3
ssh -o BatchMode=yes "${PROXMOX}" "pct exec ${CT_CLOUDFLARED} -- systemctl is-active ${SERVICE}"

# --- 2) Ingress remoto API (sync Zero Trust) ---
export TOKEN ARCHON_TUNNEL_ID MM01_ORIGIN MANIFEST
python3 <<'PY'
import json, os, urllib.request
from pathlib import Path

token = os.environ["TOKEN"]
tunnel = os.environ["ARCHON_TUNNEL_ID"]
origin = os.environ["MM01_ORIGIN"]
account = os.environ.get("CLOUDFLARE_ACCOUNT_ID", "08e7b6e3a5084b4a3a2e0b3de153b02e")
manifest = Path(os.environ["MANIFEST"])
data = json.loads(manifest.read_text())
base = data["ct"]["domain_base"]
hosts = [base] + [f"{p['slug']}.{base}" for p in data["projects"]]
gw = manifest.parent / "demo-gateway.json"
if gw.is_file():
    pub = json.loads(gw.read_text()).get("public_domain")
    if pub:
        hosts.append(pub)

def api(method, path, body=None):
    req = urllib.request.Request(
        f"https://api.cloudflare.com/client/v4/accounts/{account}{path}",
        method=method,
        headers={"Authorization": f"Bearer {token}", "Content-Type": "application/json"},
        data=json.dumps(body).encode() if body is not None else None,
    )
    with urllib.request.urlopen(req) as r:
        return json.load(r)

cur = api("GET", f"/cfd_tunnel/{tunnel}/configurations")
ingress = cur["result"]["config"]["ingress"]
warp = cur["result"]["config"].get("warp-routing", {"enabled": True})
known = {r.get("hostname") for r in ingress if r.get("hostname")}
catch = [r for r in ingress if str(r.get("service", "")).startswith("http_status:")]
rest = [r for r in ingress if r not in catch]
for h in hosts:
    if h not in known:
        rest.append({
            "hostname": h,
            "service": origin,
            "originRequest": {"disableChunkedEncoding": True},
        })
ingress = rest + (catch or [{"service": "http_status:404"}])
out = api("PUT", f"/cfd_tunnel/{tunnel}/configurations", {"config": {"warp-routing": warp, "ingress": ingress}})
if not out.get("success"):
    raise SystemExit(json.dumps(out, indent=2))
print(f"OK API ingress archon: {len(hosts)} hostnames mm01")
PY

# --- 3) DNS CNAME → túnel archon ---
CONTENT="${ARCHON_TUNNEL_ID}.cfargotunnel.com"
export TOKEN ZONE_NAME CONTENT
echo "${HOSTNAMES}" | while read -r fqdn; do
  [[ -n "${fqdn}" ]] || continue
  RECORD_NAME="${fqdn}"
  zone_id="$(curl -sS "https://api.cloudflare.com/client/v4/zones?name=${ZONE_NAME}" \
    -H "Authorization: Bearer ${TOKEN}" | python3 -c "import json,sys; print(json.load(sys.stdin)['result'][0]['id'])")"
  existing="$(curl -sS "https://api.cloudflare.com/client/v4/zones/${zone_id}/dns_records?name=${RECORD_NAME}" \
    -H "Authorization: Bearer ${TOKEN}")"
  record_id="$(echo "${existing}" | python3 -c "import json,sys; r=json.load(sys.stdin).get('result',[]); print(r[0]['id'] if r else '')")"
  payload="$(python3 -c "import json; print(json.dumps({'type':'CNAME','name':'${RECORD_NAME}','content':'${CONTENT}','proxied':True,'ttl':1}))")"
  if [[ -n "${record_id}" ]]; then
    curl -sS -X PUT "https://api.cloudflare.com/client/v4/zones/${zone_id}/dns_records/${record_id}" \
      -H "Authorization: Bearer ${TOKEN}" -H "Content-Type: application/json" --data "${payload}" \
      | python3 -c "import json,sys; d=json.load(sys.stdin); sys.exit(0 if d.get('success') else 1)" \
      && echo "OK DNS update ${RECORD_NAME}" || echo "ERRO DNS ${RECORD_NAME}" >&2
  else
    curl -sS -X POST "https://api.cloudflare.com/client/v4/zones/${zone_id}/dns_records" \
      -H "Authorization: Bearer ${TOKEN}" -H "Content-Type: application/json" --data "${payload}" \
      | python3 -c "import json,sys; d=json.load(sys.stdin); sys.exit(0 if d.get('success') else 1)" \
      && echo "OK DNS create ${RECORD_NAME}" || echo "ERRO DNS ${RECORD_NAME}" >&2
  fi
done

echo ""
echo "=== smoke HTTPS (archon tunnel) ==="
for h in mm01.aglz.io crm-imobiliaria.mm01.aglz.io erp-estacionamento.mm01.aglz.io; do
  code="$(curl -sS -o /dev/null -w '%{http_code}' --connect-timeout 15 "https://${h}/" 2>/dev/null || echo 000)"
  echo "  https://${h}/ → ${code}"
done
echo ""
echo "OK mm01 no túnel archon (CT117) — não aglsrv1"
