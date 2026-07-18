#!/usr/bin/env python3
"""Cria/atualiza regra WAF custom "skip" para o Docker Registry do Harbor.

Permite que os runners GitHub Actions (IPs Azure) facam login/push sem serem
bloqueados (403) pela seguranca de edge da Cloudflare (Bot Fight Mode / WAF
gerido / Security Level) na zona aglz.io.

Requer um token com escopo "Zone WAF: Edit". O token DNS+Tunnel usado no resto
do repo NAO chega (da 403 em /rulesets).

Uso:
    CF_WAF_TOKEN=<token-waf> python3 scripts/cloudflare/allow-harbor-ci-waf.py

Idempotente: se a regra ja existir (match por descricao), atualiza-a.
"""
from __future__ import annotations

import json
import os
import sys
import urllib.error
import urllib.request

API = "https://api.cloudflare.com/client/v4"
ZONE_ID = os.environ.get("CF_ZONE_ID_AGLZ", "f417320592ab0c54f04c553fe91e2b58")
HOST = os.environ.get("HARBOR_HOST", "harbor.aglz.io")
TOKEN = os.environ.get("CF_WAF_TOKEN") or os.environ.get("CLOUDFLARE_API_TOKEN", "")
DESC = "AGL: allow CI (GitHub Actions) -> Harbor registry"
PHASE = "http_request_firewall_custom"

# Paths do protocolo Docker Registry v2 + endpoints de token/auth do Harbor.
EXPR = (
    f'(http.host eq "{HOST}" and ('
    'starts_with(http.request.uri.path, "/v2") or '
    'starts_with(http.request.uri.path, "/service/token") or '
    'starts_with(http.request.uri.path, "/c/")))'
)

RULE = {
    "description": DESC,
    "expression": EXPR,
    "action": "skip",
    "action_parameters": {
        # Ignora WAF gerido, rate-limit e Super Bot Fight Mode + reputacao/UA.
        "phases": ["http_request_firewall_managed", "http_ratelimit", "http_request_sbfm"],
        "products": ["bic", "hot", "securityLevel", "uaBlock", "waf"],
    },
    "enabled": True,
}


def call(method: str, path: str, body: dict | None = None) -> dict:
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(
        f"{API}{path}",
        data=data,
        method=method,
        headers={
            "Authorization": f"Bearer {TOKEN}",
            "Content-Type": "application/json",
        },
    )
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            return json.loads(resp.read())
    except urllib.error.HTTPError as exc:
        try:
            return json.loads(exc.read())
        except (json.JSONDecodeError, OSError):
            return {"success": False, "errors": [{"message": f"HTTP {exc.code}"}]}


def die(msg: str, payload: dict | None = None) -> None:
    print(f"ERRO: {msg}", file=sys.stderr)
    if payload is not None:
        print(json.dumps(payload.get("errors", payload), indent=2), file=sys.stderr)
    sys.exit(1)


def main() -> None:
    if not TOKEN:
        die("define CF_WAF_TOKEN (token com escopo Zone WAF: Edit).")

    print(">> A obter entrypoint da phase", PHASE)
    ep = call("GET", f"/zones/{ZONE_ID}/rulesets/phases/{PHASE}/entrypoint")
    if not ep.get("success"):
        die("nao foi possivel ler o entrypoint (token sem escopo WAF?).", ep)

    result = ep["result"]
    ruleset_id = result.get("id")
    existing = next(
        (r["id"] for r in result.get("rules", []) if r.get("description") == DESC),
        None,
    )

    if not ruleset_id:
        print(">> Sem ruleset custom ainda; a criar entrypoint com a regra...")
        body = {"name": "default", "kind": "zone", "phase": PHASE, "rules": [RULE]}
        out = call("PUT", f"/zones/{ZONE_ID}/rulesets/phases/{PHASE}/entrypoint", body)
    elif existing:
        print(f">> Regra ja existe ({existing}); a atualizar...")
        out = call("PATCH", f"/zones/{ZONE_ID}/rulesets/{ruleset_id}/rules/{existing}", RULE)
    else:
        print(f">> A adicionar nova regra ao ruleset {ruleset_id}...")
        out = call("POST", f"/zones/{ZONE_ID}/rulesets/{ruleset_id}/rules", RULE)

    if out.get("success"):
        print(f">> OK. Regra WAF aplicada para {HOST} (/v2, /service/token, /c/).")
    else:
        die("falha ao aplicar a regra.", out)


if __name__ == "__main__":
    main()
