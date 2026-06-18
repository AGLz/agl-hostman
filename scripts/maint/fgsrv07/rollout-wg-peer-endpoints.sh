#!/usr/bin/env bash
# Actualiza Endpoint do hub nos peers WireGuard conhecidos (FGSRV6 → FGSRV7).
# Novo hub: 191.252.93.227:51823 (CT576 wireguard6, IP mesh 10.6.0.5).
#
# Uso:
#   bash scripts/maint/fgsrv07/rollout-wg-peer-endpoints.sh
#   bash scripts/maint/fgsrv07/rollout-wg-peer-endpoints.sh --dry-run
set -euo pipefail

NEW_ENDPOINT="${WG_HUB_ENDPOINT:-191.252.93.227:51823}"
OLD_ENDPOINTS=("186.202.57.120:51823" "100.83.51.9:51823")
DRY_RUN=0

for arg in "$@"; do
    [[ "$arg" == "--dry-run" ]] && DRY_RUN=1
done

log() { printf '[%s] %s\n' "$(date +%H:%M:%S)" "$*"; }

# host:ssh_target:wg_conf_path
PEERS=(
    "AGLSRV1|root@100.107.113.33|/etc/wireguard/wg0.conf"
    "agldv03|root@100.94.221.87|/etc/wireguard/wg0.conf"
    "agldv04|root@100.113.9.98|/etc/wireguard/wg0.conf"
    "agldv05|root@100.119.41.63|/etc/wireguard/wg0.conf"
    "agldv07|root@100.80.30.59|/etc/wireguard/wg0.conf"
    "AGLSRV6|root@100.121.95.88|/etc/wireguard/wg0.conf"
    "FGSRV7-host|root@100.109.181.93|/etc/wireguard/wg0.conf"
)

patch_conf() {
    local conf="$1"
    local tmp
    tmp=$(mktemp) || {
        log "ERRO: mktemp falhou para ${conf}" >&2
        return 1
    }
    [[ -n "${tmp}" ]] || {
        log "ERRO: mktemp devolveu path vazio para ${conf}" >&2
        return 1
    }
    cp "${conf}" "${tmp}"
    for old in "${OLD_ENDPOINTS[@]}"; do
        sed -i "s|Endpoint = ${old}|Endpoint = ${NEW_ENDPOINT}|g" "${tmp}"
        sed -i "s|Endpoint=${old}|Endpoint=${NEW_ENDPOINT}|g" "${tmp}"
    done
    if ! grep -q "Endpoint = ${NEW_ENDPOINT}" "${tmp}" && grep -q '\[Peer\]' "${tmp}"; then
        # Secção [Peer] hub sem Endpoint — adicionar após PublicKey do hub (heurística)
        sed -i "/PublicKey.*hub\|# hub\|10\.6\.0\.5/a Endpoint = ${NEW_ENDPOINT}" "${tmp}" 2>/dev/null || true
    fi
    if diff -q "${conf}" "${tmp}" >/dev/null 2>&1; then
        rm -f "${tmp}"
        return 1
    fi
    mv "${tmp}" "${conf}"
    return 0
}

for entry in "${PEERS[@]}"; do
    IFS='|' read -r name target conf <<< "${entry}"
    log "${name} (${target})"
    if [[ "${DRY_RUN}" -eq 1 ]]; then
        ssh -o BatchMode=yes -o ConnectTimeout=10 "${target}" "grep -E 'Endpoint|10\.6\.0\.5' ${conf} 2>/dev/null | head -5" || echo "  (sem ${conf})"
        continue
    fi
    if ! ssh -o BatchMode=yes -o ConnectTimeout=10 "${target}" "test -f ${conf}" 2>/dev/null; then
        log "  skip — ${conf} não existe"
        continue
    fi
    if ssh -o BatchMode=yes "${target}" bash -s <<PATCH
set -euo pipefail
conf='${conf}'
new='${NEW_ENDPOINT}'
for old in 186.202.57.120:51823 100.83.51.9:51823; do
  sed -i "s|Endpoint = \${old}|Endpoint = \${new}|g" "\${conf}"
done
grep -q "Endpoint = \${new}" "\${conf}" || echo "WARN: Endpoint não actualizado em \${conf}"
wg-quick down wg0 2>/dev/null || true
wg-quick up wg0
wg show wg0 | grep -E 'endpoint|handshake' | head -3
PATCH
    then
        log "  OK"
    else
        log "  FALHOU"
    fi
done

log "Validar hub CT576:"
ssh -o BatchMode=yes root@100.109.181.93 'pct exec 576 -- wg show wg0 | grep -E "handshake" | wc -l; pct exec 576 -- wg show wg0 | grep "transfer" | grep -v "0 B received, 0 B" | head -10'
