#!/usr/bin/env bash
# FGSRV7 (Proxmox root): aplica timezone/locale nos CT243 e CT235 após clone ou recriação.
#
# Uso:
#   bash scripts/maint/fgsrv07/pct-bootstrap-fg-stack-locale.sh
#   bash scripts/maint/fgsrv07/pct-bootstrap-fg-stack-locale.sh --ct 243
#   EXPECT_HOSTNAME=fgsrv7 bash …
#
# Copia scripts para /root/agl-fg-bootstrap/ no CT e executa.

set -euo pipefail

EXPECT_HOSTNAME="${EXPECT_HOSTNAME:-fgsrv7}"
REPO_ROOT="${REPO_ROOT:-}"
ONLY_CT=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --ct)
            ONLY_CT="${2:?}"
            shift 2
            ;;
        --repo)
            REPO_ROOT="${2:?}"
            shift 2
            ;;
        *)
            echo "Uso: $0 [--ct 243|235] [--repo /path/agl-hostman]" >&2
            exit 1
            ;;
    esac
done

if ! command -v pct >/dev/null 2>&1; then
    echo "Erro: pct não encontrado — correr como root no FGSRV7." >&2
    exit 1
fi

if [[ -n "${EXPECT_HOSTNAME}" ]] && [[ "$(hostname -s)" != "${EXPECT_HOSTNAME}" ]]; then
    echo "Erro: hostname ($(hostname -s)) != EXPECT_HOSTNAME=${EXPECT_HOSTNAME}" >&2
    exit 1
fi

if [[ -z "${REPO_ROOT}" ]]; then
    REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
fi

MAINT="${REPO_ROOT}/scripts/maint/fgsrv07"
for f in \
    lib/ct-set-timezone-sao-paulo.sh \
    lib/ct243-locale-php-pt-br.sh \
    ct243-post-create-bootstrap.sh \
    ct235-post-create-bootstrap.sh; do
    if [[ ! -f "${MAINT}/${f}" ]]; then
        echo "Erro: falta ${MAINT}/${f}" >&2
        exit 1
    fi
done

REMOTE_DIR="/root/agl-fg-bootstrap"

_run_ct() {
    local vmid="$1"
    local entry="$2"
    echo "==> CT${vmid}: ${entry}"
    if ! pct status "${vmid}" 2>&1 | grep -qi running; then
        echo "   a iniciar CT${vmid}…"
        pct start "${vmid}"
        sleep 5
    fi
    pct exec "${vmid}" -- mkdir -p "${REMOTE_DIR}/lib"
    pct push "${vmid}" "${MAINT}/lib/ct-set-timezone-sao-paulo.sh" "${REMOTE_DIR}/lib/ct-set-timezone-sao-paulo.sh"
  if [[ "${entry}" == *243* ]]; then
        pct push "${vmid}" "${MAINT}/lib/ct243-locale-php-pt-br.sh" "${REMOTE_DIR}/lib/ct243-locale-php-pt-br.sh"
    fi
    pct push "${vmid}" "${MAINT}/${entry}" "${REMOTE_DIR}/${entry}"
    pct exec "${vmid}" -- bash -c "chmod +x '${REMOTE_DIR}/${entry}' '${REMOTE_DIR}/lib/'*.sh 2>/dev/null; chmod +x '${REMOTE_DIR}/lib/ct-set-timezone-sao-paulo.sh'"
    if [[ "${entry}" == *243* ]]; then
        pct exec "${vmid}" -- chmod +x "${REMOTE_DIR}/lib/ct243-locale-php-pt-br.sh"
    fi
    pct exec "${vmid}" -- bash "${REMOTE_DIR}/${entry}"
}

bootstrap_243() {
    _run_ct 243 "ct243-post-create-bootstrap.sh"
}

bootstrap_235() {
    _run_ct 235 "ct235-post-create-bootstrap.sh"
}

case "${ONLY_CT}" in
    "")
        bootstrap_243
        bootstrap_235
        ;;
    243)
        bootstrap_243
        ;;
    235)
        bootstrap_235
        ;;
    *)
        echo "Erro: --ct deve ser 243 ou 235" >&2
        exit 1
        ;;
esac

echo "==> Concluído."
