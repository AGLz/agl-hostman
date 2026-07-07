#!/usr/bin/env bash
# Configura CT134 produção no Dokploy via API tRPC (CT180).
# Requer: curl, python3, ssh aglsrv1, DOKPLOY_URL, DOKPLOY_API_KEY (ou sessão UI).
#
# Uso:
#   DOKPLOY_URL=http://192.168.0.180:3000/api \
#   DOKPLOY_API_KEY=... \
#   bash scripts/dokploy/setup-ct134-via-api.sh
#
# Gera /tmp/dokploy-ct134-ids.json com IDs (server, app, compose, webhooks).
set -euo pipefail

DOKPLOY_URL="${DOKPLOY_URL:-http://192.168.0.180:3000/api}"
DOKPLOY_API_KEY="${DOKPLOY_API_KEY:-}"
AGLSRV1="${AGLSRV1:-root@100.107.113.33}"
ORG_ID="${DOKPLOY_ORG_ID:-3MfNHnTdnNsZveKkjKsMy}"
PROJECT_ID="${DOKPLOY_PROJECT_ID:-gaKJ1iCnNXNZRukaeleqV}"
ENV_PROD="${DOKPLOY_ENV_PROD:-w7EumvSDLYorq1fjruuSR}"
APP_ID="${DOKPLOY_APP_ID:-app_prod_123456789}"
CT134_TS_IP="${CT134_TS_IP:-100.109.204.59}"
COMPOSE_FILE="${COMPOSE_FILE:-docker/dokploy/docker-compose.ct134.production.yml}"

if [[ -z "${DOKPLOY_API_KEY}" ]]; then
  echo "Erro: defina DOKPLOY_API_KEY (Settings → API Keys, metadata organizationId=${ORG_ID})" >&2
  exit 1
fi

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OUT="${DOKPLOY_SETUP_OUT:-/tmp/dokploy-ct134-ids.json}"

export DOKPLOY_URL DOKPLOY_API_KEY ORG_ID ENV_PROD APP_ID CT134_TS_IP COMPOSE_FILE ROOT OUT AGLSRV1

python3 <<'PY'
import json, os, subprocess, urllib.request, urllib.parse, secrets

base = os.environ["DOKPLOY_URL"].rstrip("/")
key = os.environ["DOKPLOY_API_KEY"]
org = os.environ["ORG_ID"]
env_prod = os.environ["ENV_PROD"]
app_id = os.environ["APP_ID"]
ct134_ip = os.environ["CT134_TS_IP"]
compose_path = os.path.join(os.environ["ROOT"], os.environ["COMPOSE_FILE"])
out = os.environ["OUT"]
aglsrv1 = os.environ["AGLSRV1"]

def trpc_post(proc, payload):
    url = f"{base}/trpc/{proc}?batch=1"
    body = json.dumps({"0": {"json": payload}}).encode()
    req = urllib.request.Request(url, data=body, method="POST", headers={
        "Content-Type": "application/json",
        "x-api-key": key,
    })
    with urllib.request.urlopen(req, timeout=300) as r:
        data = json.loads(r.read())
    if "error" in data[0]:
        raise RuntimeError(f"{proc}: {data[0]['error']}")
    return data[0]["result"]["data"]["json"]

def trpc_get(proc, payload=None):
    inp = urllib.parse.quote(json.dumps({"0": {"json": payload}}))
    url = f"{base}/trpc/{proc}?batch=1&input={inp}"
    req = urllib.request.Request(url, headers={"x-api-key": key})
    with urllib.request.urlopen(req, timeout=120) as r:
        data = json.loads(r.read())
    if "error" in data[0]:
        raise RuntimeError(f"{proc}: {data[0]['error']}")
    return data[0]["result"]["data"]["json"]

# SSH key + server CT134
keys = trpc_post("sshKey.generate", {"name": "ct134-agl-hostman-prod"})
trpc_post("sshKey.create", {
    "name": "ct134-agl-hostman-prod",
    "privateKey": keys["privateKey"],
    "publicKey": keys["publicKey"],
    "organizationId": org,
})
servers = trpc_get("server.all")
server = next((s for s in servers if s["name"] == "ct134-agl-hostman-prod"), None)
if not server:
    ssh_keys = trpc_get("sshKey.all") or []
    ssh_id = ssh_keys[-1]["sshKeyId"] if ssh_keys else None
    trpc_post("server.create", {
        "name": "ct134-agl-hostman-prod",
        "description": "CT134 agl-hostman production",
        "ipAddress": ct134_ip,
        "port": 22,
        "username": "root",
        "sshKeyId": ssh_id,
        "organizationId": org,
    })
    servers = trpc_get("server.all")
    server = next(s for s in servers if s["name"] == "ct134-agl-hostman-prod")
server_id = server["serverId"]

pub = keys["publicKey"].strip()
fp = pub.split()[1]
subprocess.run([
    "ssh", "-o", "BatchMode=yes", aglsrv1,
    f"pct exec 134 -- bash -c 'mkdir -p /root/.ssh; grep -Fq {fp} /root/.ssh/authorized_keys 2>/dev/null || echo \"{pub}\" >> /root/.ssh/authorized_keys; chmod 600 /root/.ssh/authorized_keys'"
], check=False)

# Harbor robot (CT182)
r = subprocess.run([
    "ssh", "-o", "BatchMode=yes", aglsrv1,
    "pct exec 182 -- sed -n '1,2p' /root/robot-ct134-credentials.txt"
], capture_output=True, text=True)
lines = [l.strip() for l in r.stdout.splitlines() if l.strip()]
harbor_user = lines[0].split("=", 1)[-1]
harbor_pass = lines[1].split("=", 1)[-1]

image = "harbor.aglz.io/agl-hostman-prod/hostman:prod-latest"
trpc_post("application.saveDockerProvider", {
    "applicationId": app_id,
    "dockerImage": image,
    "registryUrl": "harbor.aglz.io",
    "username": harbor_user,
    "password": harbor_pass,
})
trpc_post("application.update", {
    "applicationId": app_id,
    "serverId": server_id,
    "autoDeploy": True,
})

app_token = secrets.token_hex(24)
subprocess.run([
    "ssh", "-o", "BatchMode=yes", aglsrv1,
    f"pct exec 180 -- docker exec dokploy-postgres psql -U dokploy -d dokploy -c \"UPDATE application SET \\\"serverId\\\"='{server_id}', \\\"refreshToken\\\"='{app_token}' WHERE \\\"applicationId\\\"='{app_id}';\""
], check=True)

# Compose (stack app+horizon+scheduler) — domínio via Cloudflare, sem Traefik Dokploy
with open(compose_path) as f:
    compose_yaml = f.read()
composes = trpc_get("compose.getAllByEnvironment", {"environmentId": env_prod}) if False else []
compose_id = None
try:
    all_comp = trpc_get("project.one", {"projectId": os.environ.get("DOKPLOY_PROJECT_ID", "gaKJ1iCnNXNZRukaeleqV")})
except Exception:
    all_comp = None
# ponytail: criar compose se ainda não existir (nome fixo)
r = subprocess.run([
    "ssh", "-o", "BatchMode=yes", aglsrv1,
    "pct exec 180 -- docker exec dokploy-postgres psql -U dokploy -d dokploy -t -A -c \"SELECT \\\"composeId\\\" FROM compose WHERE name='agl-hostman-prod-compose' LIMIT 1;\""
], capture_output=True, text=True)
compose_id = r.stdout.strip() or None
if not compose_id:
    created = trpc_post("compose.create", {
        "name": "agl-hostman-prod-compose",
        "environmentId": env_prod,
        "serverId": server_id,
        "composeType": "docker-compose",
        "sourceType": "raw",
        "autoDeploy": True,
    })
    compose_id = created["composeId"] if created else None
    if not compose_id:
        r2 = subprocess.run([
            "ssh", "-o", "BatchMode=yes", aglsrv1,
            "pct exec 180 -- docker exec dokploy-postgres psql -U dokploy -d dokploy -t -A -c \"SELECT \\\"composeId\\\" FROM compose WHERE name='agl-hostman-prod-compose' LIMIT 1;\""
        ], capture_output=True, text=True)
        compose_id = r2.stdout.strip()

if compose_id:
    env_ct134 = subprocess.run([
        "ssh", "-o", "BatchMode=yes", aglsrv1, "pct exec 134 -- cat /opt/agl-hostman-prod/.env"
    ], capture_output=True, text=True).stdout
    trpc_post("compose.update", {
        "composeId": compose_id,
        "composeFile": compose_yaml,
        "sourceType": "raw",
        "serverId": server_id,
        "env": env_ct134,
    })
    compose_token = secrets.token_hex(24)
    subprocess.run([
        "ssh", "-o", "BatchMode=yes", aglsrv1,
        f"pct exec 180 -- docker exec dokploy-postgres psql -U dokploy -d dokploy -c \"UPDATE compose SET \\\"refreshToken\\\"='{compose_token}' WHERE \\\"composeId\\\"='{compose_id}';\""
    ], check=True)
else:
    compose_token = None

webhook_app = f"{base.replace('/api', '')}/api/webhook/trigger/{app_id}/{app_token}"
webhook_compose = f"{base.replace('/api', '')}/api/webhook/trigger/{compose_id}/{compose_token}" if compose_id else None

result = {
    "serverId": server_id,
    "applicationId": app_id,
    "composeId": compose_id,
    "webhookApplication": webhook_app,
    "webhookCompose": webhook_compose,
    "dokployUrl": base,
}
with open(out, "w") as f:
    json.dump(result, f, indent=2)
print(json.dumps(result, indent=2))
PY

echo "OK: IDs em ${OUT}"
echo "Próximo: bash scripts/dokploy/trigger-ct134-deploy.sh (deploy real no CT134 via SSH)"
echo "GitHub: gh secret set DOKPLOY_API_KEY --repo AGLz/agl-hostman"
echo "        gh secret set DOKPLOY_PROD_WEBHOOK_URL --body \"\$(jq -r .webhookApplication ${OUT})\""
