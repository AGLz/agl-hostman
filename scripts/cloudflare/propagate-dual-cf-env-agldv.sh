#!/usr/bin/env bash
# Propaga setup-dual-cf-env-agldv.sh para agldv03, 04, 05, 06, 07, 12.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SETUP="${ROOT}/scripts/cloudflare/setup-dual-cf-env-agldv.sh"
DRY_RUN=0

for arg in "$@"; do
    case "$arg" in
        --dry-run) DRY_RUN=1 ;;
    esac
done

# Extrair AGLz do agldv03 cert.pem (fonte canónica)
read -r AGLZ_TOKEN AGLZ_ACCOUNT < <(
    ssh -o ConnectTimeout=15 root@100.94.221.87 'python3 - << "PY"
import base64, json, re
raw = open("/root/.cloudflared/cert.pem").read()
m = re.search(r"BEGIN ARGO TUNNEL TOKEN-----\n(.+)\n-----END", raw, re.S)
cert = json.loads(base64.b64decode(m.group(1).replace("\n", "") + "=="))
print(cert["apiToken"], cert["accountID"])
PY'
)

run_direct() {
    local host=$1
    local ip=$2
    echo "=== ${host} (${ip}) ==="
    scp -q -o ConnectTimeout=15 "${SETUP}" "root@${ip}:/tmp/setup-dual-cf-env-agldv.sh"
    local extra=()
    [[ "${DRY_RUN}" -eq 1 ]] && extra+=(--dry-run)
    ssh -o ConnectTimeout=15 "root@${ip}" \
        "CLOUDFLARE_API_TOKEN_AGLZ='${AGLZ_TOKEN}' CLOUDFLARE_ACCOUNT_ID_AGLZ='${AGLZ_ACCOUNT}' bash /tmp/setup-dual-cf-env-agldv.sh ${extra[*]}"
}

run_pct() {
    local host=$1
    local prox_ip=$2
    local vmid=$3
    echo "=== ${host} (pct ${vmid} @ ${prox_ip}) ==="
    scp -q -o ConnectTimeout=15 "${SETUP}" "root@${prox_ip}:/tmp/setup-dual-cf-env-agldv.sh"
    local extra=()
    [[ "${DRY_RUN}" -eq 1 ]] && extra+=(--dry-run)
    ssh -o ConnectTimeout=15 "root@${prox_ip}" \
        "pct push ${vmid} /tmp/setup-dual-cf-env-agldv.sh /tmp/setup-dual-cf-env-agldv.sh && \
         pct exec ${vmid} -- env CLOUDFLARE_API_TOKEN_AGLZ='${AGLZ_TOKEN}' CLOUDFLARE_ACCOUNT_ID_AGLZ='${AGLZ_ACCOUNT}' bash /tmp/setup-dual-cf-env-agldv.sh ${extra[*]}"
}

run_direct agldv02 100.95.204.85
run_direct agldv03 100.94.221.87
run_direct agldv04 100.113.9.98
run_direct agldv06 100.71.229.12
run_direct agldv12 100.71.217.115
run_pct agldv05 100.119.223.113 536
run_pct agldv07 100.109.181.93 547

echo "Propagação concluída."
