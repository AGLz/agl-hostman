#!/usr/bin/env python3
"""Configura CT134 no Dokploy via API tRPC."""
from __future__ import annotations

import json
import os
import secrets
import subprocess
import urllib.parse
import urllib.request

base = os.environ["DOKPLOY_URL"].rstrip("/")
key = os.environ["DOKPLOY_API_KEY"]
org = os.environ["ORG_ID"]
app_id = os.environ["APP_ID"]
ct134_ip = os.environ["CT134_TS_IP"]
out = os.environ["OUT"]
aglsrv1 = os.environ["AGLSRV1"]
image = "harbor.aglz.io/agl-hostman-prod/hostman:prod-latest"


def trpc_post(proc: str, payload: dict):
    url = f"{base}/trpc/{proc}?batch=1"
    body = json.dumps({"0": {"json": payload}}).encode()
    req = urllib.request.Request(
        url, data=body, method="POST",
        headers={"Content-Type": "application/json", "x-api-key": key},
    )
    with urllib.request.urlopen(req, timeout=300) as r:
        data = json.loads(r.read())
    if "error" in data[0]:
        raise RuntimeError(f"{proc}: {data[0]['error']}")
    return data[0]["result"]["data"]["json"]


def trpc_get(proc: str, payload=None):
    inp = urllib.parse.quote(json.dumps({"0": {"json": payload}}))
    url = f"{base}/trpc/{proc}?batch=1&input={inp}"
    req = urllib.request.Request(url, headers={"x-api-key": key})
    with urllib.request.urlopen(req, timeout=120) as r:
        data = json.loads(r.read())
    if "error" in data[0]:
        raise RuntimeError(f"{proc}: {data[0]['error']}")
    return data[0]["result"]["data"]["json"]


def ssh_pct(cmd: str) -> str:
    r = subprocess.run(
        ["ssh", "-o", "BatchMode=yes", aglsrv1, cmd],
        capture_output=True, text=True, check=True,
    )
    return r.stdout.strip()


servers = trpc_get("server.all")
server = next((s for s in servers if s["name"] == "ct134-agl-hostman-prod"), None)
if not server:
    keys = trpc_post("sshKey.generate", {"name": "ct134-agl-hostman-prod"})
    trpc_post("sshKey.create", {
        "name": "ct134-agl-hostman-prod",
        "privateKey": keys["privateKey"],
        "publicKey": keys["publicKey"],
        "organizationId": org,
    })
    ssh_keys = trpc_get("sshKey.all") or []
    ssh_id = ssh_keys[-1]["sshKeyId"]
    pub = keys["publicKey"].strip()
    fp = pub.split()[1]
    subprocess.run([
        "ssh", "-o", "BatchMode=yes", aglsrv1,
        f"pct exec 134 -- bash -c 'mkdir -p /root/.ssh; grep -Fq {fp} /root/.ssh/authorized_keys 2>/dev/null || echo \"{pub}\" >> /root/.ssh/authorized_keys; chmod 600 /root/.ssh/authorized_keys'",
    ], check=False)
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

creds = ssh_pct("pct exec 182 -- sed -n '1,2p' /root/robot-ct134-credentials.txt").splitlines()
harbor_user = creds[0].split("=", 1)[-1].strip()
harbor_pass = creds[1].split("=", 1)[-1].strip()

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
ssh_pct(
    f"pct exec 180 -- docker exec dokploy-postgres psql -U dokploy -d dokploy -c "
    f"\"UPDATE application SET \\\"serverId\\\"='{server_id}', \\\"refreshToken\\\"='{app_token}' "
    f"WHERE \\\"applicationId\\\"='{app_id}';\""
)

webhook_app = f"{base.replace('/api', '')}/api/webhook/trigger/{app_id}/{app_token}"
result = {
    "serverId": server_id,
    "applicationId": app_id,
    "webhookApplication": webhook_app,
    "dokployUrl": base,
}
with open(out, "w") as f:
    json.dump(result, f, indent=2)
print(json.dumps(result, indent=2))
