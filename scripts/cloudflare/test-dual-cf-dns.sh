#!/usr/bin/env bash
# Testa credenciais Cloudflare AGLz (Bearer) e FGz (Global API Key) + listagem DNS falg.*
set -eo pipefail

ZSHRC="${HOME}/.zshrc"
if [[ -f "${ZSHRC}" ]]; then
    eval "$(python3 - "${ZSHRC}" <<'PY'
import re, sys
text = open(sys.argv[1]).read()
m = re.search(r"# >>> agl-hostman cloudflare credentials >>>(.*?)# <<< agl-hostman cloudflare credentials <<<", text, re.S)
if not m:
    raise SystemExit(0)
for line in m.group(1).splitlines():
    s = line.strip()
    if s.startswith("export "):
        print(s)
PY
)"
fi

python3 - <<'PY'
import json
import os
import sys
import urllib.error
import urllib.request

AGLZ = os.environ.get("CLOUDFLARE_API_TOKEN_AGLZ") or os.environ.get("CLOUDFLARE_API_TOKEN", "")
AGLZ_ACCT = os.environ.get("CLOUDFLARE_ACCOUNT_ID_AGLZ") or os.environ.get("CLOUDFLARE_ACCOUNT_ID", "")
FGZ_EMAIL = os.environ.get("CLOUDFLARE_EMAIL_FGZ") or os.environ.get("CF_EMAIL", "")
FGZ_KEY = os.environ.get("CLOUDFLARE_API_KEY_FGZ") or os.environ.get("CF_API_KEY", "")
ZONE_FALG = os.environ.get("CLOUDFLARE_ZONE_ID_FALG_COM_BR") or os.environ.get("CF_ZONE_ID", "")


def req(path, *, bearer=None, global_key=False):
    headers = {"Content-Type": "application/json"}
    if global_key:
        headers["X-Auth-Email"] = FGZ_EMAIL
        headers["X-Auth-Key"] = FGZ_KEY
    else:
        headers["Authorization"] = f"Bearer {bearer}"
    r = urllib.request.Request(f"https://api.cloudflare.com/client/v4{path}", headers=headers)
    with urllib.request.urlopen(r, timeout=25) as resp:
        return json.loads(resp.read())


def safe(label, fn):
    try:
        fn()
        return True
    except urllib.error.HTTPError as e:
        body = e.read().decode("utf-8", errors="replace")[:200]
        print(f"FAIL {label}: HTTP {e.code} {body}")
        return False
    except Exception as e:
        print(f"FAIL {label}: {e}")
        return False


print("=== AGLz (Bearer) ===")
if not AGLZ:
    print("FAIL: CLOUDFLARE_API_TOKEN_AGLZ vazio")
else:

    def aglz_verify():
        d = req("/user/tokens/verify", bearer=AGLZ)
        print(f"OK verify: {d.get('result', {}).get('status')}")

    safe("AGLz verify", aglz_verify)

    def aglz_zones():
        d = req("/zones?per_page=50", bearer=AGLZ)
        names = [z["name"] for z in d.get("result", [])]
        print(f"OK zones ({len(names)}): {', '.join(names[:8])}{'…' if len(names) > 8 else ''}")

    safe("AGLz zones", aglz_zones)

print("\n=== FGz (Global API Key cfk_*) ===")
if not FGZ_KEY:
    print("FAIL: CLOUDFLARE_API_KEY_FGZ vazio")
else:
    print(f"email={FGZ_EMAIL} key_prefix={FGZ_KEY[:8]}…")

    def fgz_user():
        d = req("/user", global_key=True)
        u = d.get("result", {})
        print(f"OK user: {u.get('email')} id={u.get('id')}")

    ok_user = safe("FGz user", fgz_user)

    def fgz_zones():
        d = req("/zones?per_page=50", global_key=True)
        falg = [z for z in d.get("result", []) if "falg" in z["name"] or "imoveis" in z["name"]]
        print(f"OK zones falg-related ({len(falg)}):")
        for z in falg:
            print(f"  - {z['name']} ({z['id']}) status={z.get('status')}")

    ok_zones = safe("FGz zones", fgz_zones)

    if ok_zones and ZONE_FALG:
        print("\n=== DNS amostra (zona falg.com.br) ===")

        def dns_sample():
            for name in (
                "falg.com.br",
                "www.falg.com.br",
                "falgimoveis.com",
                "www.falgimoveis.com",
            ):
                d = req(
                    f"/zones/{ZONE_FALG}/dns_records?name={name}",
                    global_key=True,
                )
                recs = d.get("result", [])
                if not recs:
                    print(f"  {name}: (sem registos nesta zona)")
                    continue
                for rec in recs:
                    print(
                        f"  {rec['type']} {rec['name']} -> {rec['content']} "
                        f"proxied={rec.get('proxied')}"
                    )

        safe("FGz DNS", dns_sample)

        # falgimoveis.com pode estar em zona separada
        def fgz_zone_imoveis():
            d = req("/zones?name=falgimoveis.com", global_key=True)
            zones = d.get("result", [])
            if not zones:
                print("  falgimoveis.com: zona não listada (conta ou permissão)")
                return
            zid = zones[0]["id"]
            d2 = req(f"/zones/{zid}/dns_records?name=falgimoveis.com", global_key=True)
            for rec in d2.get("result", []):
                print(
                    f"  {rec['type']} {rec['name']} -> {rec['content']} "
                    f"proxied={rec.get('proxied')}"
                )

        print("\n=== DNS falgimoveis.com (zona própria se existir) ===")
        safe("FGz falgimoveis zone", fgz_zone_imoveis)

PY
