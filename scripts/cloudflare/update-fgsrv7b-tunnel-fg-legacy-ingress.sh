#!/usr/bin/env bash
# Actualiza ingress remoto do túnel fgsrv7b (CT571 cloudflared7b) no Zero Trust.
# Domínios PHP legado → CT549 fg-legacy (192.168.70.243:80).
#
# Auth: Bearer (CLOUDFLARE_API_TOKEN) ou Global API Key FGz (CLOUDFLARE_EMAIL_FGZ + CLOUDFLARE_API_KEY_FGZ).
# Conta FGz: CLOUDFLARE_ACCOUNT_ID_FGZ (default 275896c4…).
#
# HA FGSRV7: após actualizar fgsrv7b, espelhar os mesmos public hostnames no túnel fgsrv7 (CT570)
# via UI Zero Trust (conta aglz.io) para failover quando CT571 estiver parado para backup PBS.
#
# Uso:
#   source ~/.zshrc   # bloco agl-hostman cloudflare credentials
#   bash scripts/cloudflare/update-fgsrv7b-tunnel-fg-legacy-ingress.sh
#   bash scripts/cloudflare/update-fgsrv7b-tunnel-fg-legacy-ingress.sh --dry-run
set -euo pipefail

ACCOUNT_ID="${CLOUDFLARE_ACCOUNT_ID_FGZ:-${CLOUDFLARE_ACCOUNT_ID:-275896c4ed8b42fc3d4c62adcb5076ce}}"
TUNNEL_ID="${FGSRV7B_TUNNEL_ID:-850f2d28-367f-4bd2-a887-6998240828e3}"
ORIGIN="${FG_LEGACY_ORIGIN:-http://192.168.70.243}"
TOKEN="${CLOUDFLARE_API_TOKEN_FGZ:-${CLOUDFLARE_API_TOKEN:-${CF_API_TOKEN:-}}}"
CF_EMAIL="${CLOUDFLARE_EMAIL_FGZ:-${CF_EMAIL:-}}"
CF_KEY="${CLOUDFLARE_API_KEY_FGZ:-${CF_API_KEY:-}}"
DRY_RUN=0

for arg in "$@"; do
    case "$arg" in
        --dry-run) DRY_RUN=1 ;;
        -h | --help)
            sed -n '1,22p' "$0"
            exit 0
            ;;
        *)
            echo "Opção desconhecida: $arg" >&2
            exit 1
            ;;
    esac
done

USE_GLOBAL=0
if [[ -z "${TOKEN}" && -n "${CF_EMAIL}" && -n "${CF_KEY}" ]]; then
    USE_GLOBAL=1
elif [[ -z "${TOKEN}" ]]; then
    echo "Erro: defina CLOUDFLARE_API_TOKEN (Bearer) ou CLOUDFLARE_EMAIL_FGZ + CLOUDFLARE_API_KEY_FGZ" >&2
    exit 1
fi

api() {
    local method=$1
    local url=$2
    local data=${3:-}
    local curl_args=(-sS -X "${method}" "${url}" -H "Content-Type: application/json")
    if [[ "${USE_GLOBAL}" -eq 1 ]]; then
        curl_args+=(-H "X-Auth-Email: ${CF_EMAIL}" -H "X-Auth-Key: ${CF_KEY}")
    else
        curl_args+=(-H "Authorization: Bearer ${TOKEN}")
    fi
    if [[ -n "${data}" ]]; then
        curl "${curl_args[@]}" --data "${data}"
    else
        curl "${curl_args[@]}"
    fi
}

if [[ "${USE_GLOBAL}" -eq 0 ]]; then
    verify=$(api GET "https://api.cloudflare.com/client/v4/user/tokens/verify")
    if ! echo "${verify}" | python3 -c "import sys,json; d=json.load(sys.stdin); sys.exit(0 if d.get('success') else 1)"; then
        echo "Token Cloudflare inválido:" >&2
        echo "${verify}" >&2
        exit 1
    fi
else
    verify=$(api GET "https://api.cloudflare.com/client/v4/user")
    if ! echo "${verify}" | python3 -c "import sys,json; d=json.load(sys.stdin); sys.exit(0 if d.get('success') else 1)"; then
        echo "Global API Key FGz inválida:" >&2
        echo "${verify}" >&2
        exit 1
    fi
fi

cfg_url="https://api.cloudflare.com/client/v4/accounts/${ACCOUNT_ID}/cfd_tunnel/${TUNNEL_ID}/configurations"
current=$(api GET "${cfg_url}")
if ! echo "${current}" | python3 -c "import sys,json; d=json.load(sys.stdin); sys.exit(0 if d.get('success') else 1)"; then
    echo "Falha ao obter config remota do túnel ${TUNNEL_ID}:" >&2
    echo "${current}" >&2
    exit 1
fi

read -r payload added <<< "$(echo "${current}" | ORIGIN="${ORIGIN}" python3 -c "
import json, os, sys

origin = os.environ['ORIGIN']
names = [
    'falg.com.br',
    'www.falg.com.br',
    'falgimoveis.com',
    'www.falgimoveis.com',
    'alphavilletambore.com.br',
    'www.alphavilletambore.com.br',
    'portalalphavilletambore.com.br',
    'www.portalalphavilletambore.com.br',
]

data = json.load(sys.stdin)
ingress = data['result']['config'].get('ingress', [])
warp = data['result']['config'].get('warp-routing', {'enabled': False})

catch = None
rules = []
for rule in ingress:
    if rule.get('service') == 'http_status:404' or rule.get('hostname') is None:
        catch = rule
    else:
        rules.append(rule)

existing = {r.get('hostname') for r in rules}
added = [h for h in names if h not in existing]
for h in added:
    rules.append({
        'hostname': h,
        'service': origin,
        'originRequest': {'disableChunkedEncoding': True},
    })

if catch:
    rules.append(catch if catch.get('service') else {'service': 'http_status:404'})

payload = json.dumps({'config': {'ingress': rules, 'warp-routing': warp}}, separators=(',', ':'))
print(payload)
print(','.join(added))
")"

echo "Túnel: ${TUNNEL_ID} (fgsrv7b / CT571)"
echo "Conta: ${ACCOUNT_ID}"
echo "Origem: ${ORIGIN}"
if [[ -n "${added}" ]]; then
    echo "Hostnames a adicionar: ${added}"
else
    echo "Nenhum hostname novo (já presentes na config remota)."
fi

if [[ "${DRY_RUN}" -eq 1 ]]; then
    echo "${payload}" | python3 -m json.tool
    exit 0
fi

response=$(api PUT "${cfg_url}" "${payload}")
if echo "${response}" | python3 -c "import sys,json; d=json.load(sys.stdin); sys.exit(0 if d.get('success') else 1)"; then
    echo "OK: ingress remoto actualizado (fgsrv7b → CT549)."
else
    echo "Falha ao actualizar ingress remoto:" >&2
    echo "${response}" >&2
    exit 1
fi
