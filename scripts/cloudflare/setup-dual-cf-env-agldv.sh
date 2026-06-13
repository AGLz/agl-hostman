#!/usr/bin/env bash
# Configura credenciais Cloudflare duplas (AGLz + FGz) em ~/.zshrc nos CTs agldv.
#
# AGLz: User API Token (Bearer) — aglz.io, túnel fgsrv7 / CT570
# FGz:  Global User API Key (cfk_*) + email — falg.com.br, falgimoveis.com, túnel fgsrv7b / CT571
#
# Uso (local ou via SSH no CT):
#   bash scripts/cloudflare/setup-dual-cf-env-agldv.sh
#   bash scripts/cloudflare/setup-dual-cf-env-agldv.sh --dry-run
#
# Propagação remota (a partir de agldv03 ou workstation com SSH):
#   bash scripts/cloudflare/propagate-dual-cf-env-agldv.sh
set -euo pipefail

DRY_RUN=0
for arg in "$@"; do
    case "$arg" in
        --dry-run) DRY_RUN=1 ;;
        -h | --help)
            sed -n '1,18p' "$0"
            exit 0
            ;;
        *)
            echo "Opção desconhecida: $arg" >&2
            exit 1
            ;;
    esac
done

ZSHRC="${HOME}/.zshrc"
MARK_BEGIN="# >>> agl-hostman cloudflare credentials >>>"
MARK_END="# <<< agl-hostman cloudflare credentials <<<"

extract_aglz_from_cert() {
    if [[ ! -f "${HOME}/.cloudflared/cert.pem" ]]; then
        return 1
    fi
    python3 - <<'PY'
import base64, json, re, sys

raw = open("/root/.cloudflared/cert.pem").read()
m = re.search(r"BEGIN ARGO TUNNEL TOKEN-----\n(.+)\n-----END", raw, re.S)
if not m:
    sys.exit(1)
cert = json.loads(base64.b64decode(m.group(1).replace("\n", "") + "=="))
print(cert["apiToken"])
print(cert["accountID"])
PY
}

AGLZ_TOKEN="${CLOUDFLARE_API_TOKEN_AGLZ:-}"
AGLZ_ACCOUNT="${CLOUDFLARE_ACCOUNT_ID_AGLZ:-08e7b6e3a5084b4a3a2e0b3de153b02e}"

if [[ -z "${AGLZ_TOKEN}" ]]; then
    if mapfile -t _cert_vals < <(extract_aglz_from_cert 2>/dev/null); then
        AGLZ_TOKEN="${_cert_vals[0]}"
        AGLZ_ACCOUNT="${_cert_vals[1]:-${AGLZ_ACCOUNT}}"
    fi
fi

FGZ_EMAIL="${CLOUDFLARE_EMAIL_FGZ:-agnaldofalg@hotmail.com}"
FGZ_KEY="${CLOUDFLARE_API_KEY_FGZ:-cfk_cUdHRU2jU9aamVdQAV4gfK8naUYqOQtEwid653hY2d21e230}"
FGZ_ACCOUNT="${CLOUDFLARE_ACCOUNT_ID_FGZ:-275896c4ed8b42fc3d4c62adcb5076ce}"
FGZ_ZONE_FALG="${CLOUDFLARE_ZONE_ID_FALG_COM_BR:-01ce76a70c797ca510bb56bf61f3a75e}"
FGZ_ZONE_IMOVEIS="${CLOUDFLARE_ZONE_ID_FALGIMOVEIS_COM:-d92942587a928b462208d154bb9c8ccf}"

if [[ -z "${AGLZ_TOKEN}" ]]; then
    echo "Erro: defina CLOUDFLARE_API_TOKEN_AGLZ ou tenha ~/.cloudflared/cert.pem" >&2
    exit 1
fi

BLOCK=$(cat <<EOF
${MARK_BEGIN}
# Conta AGLz (aglz.io, aguileraz.net) — Bearer User API Token
export CLOUDFLARE_API_TOKEN_AGLZ="${AGLZ_TOKEN}"
export CLOUDFLARE_ACCOUNT_ID_AGLZ="${AGLZ_ACCOUNT}"
# Compatibilidade com scripts legados (conta AGLz por defeito)
export CLOUDFLARE_API_TOKEN="${AGLZ_TOKEN}"
export CLOUDFLARE_ACCOUNT_ID="${AGLZ_ACCOUNT}"

# Conta FGz (falg.com.br, falgimoveis.com, …) — Global User API Key (cfk_*)
export CLOUDFLARE_EMAIL_FGZ="${FGZ_EMAIL}"
export CLOUDFLARE_API_KEY_FGZ="${FGZ_KEY}"
export CLOUDFLARE_ACCOUNT_ID_FGZ="${FGZ_ACCOUNT}"
export CLOUDFLARE_ZONE_ID_FALG_COM_BR="${FGZ_ZONE_FALG}"
export CLOUDFLARE_ZONE_ID_FALGIMOVEIS_COM="${FGZ_ZONE_IMOVEIS}"
# Alias legado mysql-ha / scripts DNS falg
export CF_EMAIL="${FGZ_EMAIL}"
export CF_API_KEY="${FGZ_KEY}"
export CF_ZONE_ID="${FGZ_ZONE_FALG}"
${MARK_END}
EOF
)

if [[ "${DRY_RUN}" -eq 1 ]]; then
    echo "${BLOCK}"
    exit 0
fi

touch "${ZSHRC}"
cp -a "${ZSHRC}" "${ZSHRC}.bak.$(date +%Y%m%d_%H%M%S)"

BLOCK_FILE="$(mktemp)"
printf '%s\n' "${BLOCK}" > "${BLOCK_FILE}"
python3 - "${ZSHRC}" "${MARK_BEGIN}" "${MARK_END}" "${BLOCK_FILE}" <<'PY'
import sys

path, begin, end, block_file = sys.argv[1:5]
block = open(block_file).read()
lines = open(path).read().splitlines(keepends=True)
out = []
i = 0
while i < len(lines):
    line = lines[i]
    if line.strip() == begin:
        while i < len(lines) and lines[i].strip() != end:
            i += 1
        if i < len(lines):
            i += 1
        continue
    stripped = line.strip()
    if stripped.startswith("export CLOUDFLARE_") or stripped.startswith("export CF_"):
        if any(
            k in stripped
            for k in (
                "CLOUDFLARE_API_TOKEN",
                "CLOUDFLARE_ACCOUNT_ID",
                "CLOUDFLARE_EMAIL",
                "CLOUDFLARE_API_KEY",
                "CLOUDFLARE_ZONE",
                "CF_EMAIL",
                "CF_API_KEY",
                "CF_ZONE_ID",
            )
        ):
            i += 1
            continue
    out.append(line)
    i += 1

if out and not out[-1].endswith("\n"):
    out[-1] += "\n"
out.append("\n")
out.append(block)
if not block.endswith("\n"):
    out.append("\n")
open(path, "w").writelines(out)
PY
rm -f "${BLOCK_FILE}"

echo "OK: bloco Cloudflare actualizado em ${ZSHRC}"
