#!/usr/bin/env bash
# Reason: activar/desactivar site nginx :3737→:3000 sem editar manualmente sites-enabled
set -euo pipefail

PROXY_DIR="/opt/archon/proxy"
SITE_NAME="archon-v04-proxy"
SRC="${PROXY_DIR}/nginx-archon-v04-proxy.conf"
AVAIL="/etc/nginx/sites-available/${SITE_NAME}"
ENABLED="/etc/nginx/sites-enabled/${SITE_NAME}"

usage() {
    echo "Uso: $(basename "$0") enable|disable|status" >&2
    exit 1
}

require_root() {
    if [[ "${EUID}" -ne 0 ]]; then
        echo "Executar como root." >&2
        exit 1
    fi
}

enable_proxy() {
    install -D -m 644 "${SRC}" "${AVAIL}"
    ln -sfn "${AVAIL}" "${ENABLED}"
    nginx -t
    systemctl enable nginx.service
    systemctl start nginx.service
    systemctl reload nginx.service
    echo "OK: proxy activo em :3737 → :3000"
}

disable_proxy() {
    rm -f "${ENABLED}"
    if nginx -t 2>/dev/null; then
        systemctl reload nginx.service
    fi
    echo "OK: proxy desactivado (site removido de sites-enabled)"
}

status_proxy() {
    if [[ -L "${ENABLED}" ]]; then
        echo "enabled: ${ENABLED} -> $(readlink -f "${ENABLED}")"
    else
        echo "disabled"
        exit 1
    fi
}

main() {
    require_root
    [[ -f "${SRC}" ]] || { echo "Falta ${SRC}" >&2; exit 1; }
    case "${1:-}" in
        enable) enable_proxy ;;
        disable) disable_proxy ;;
        status) status_proxy ;;
        *) usage ;;
    esac
}

main "$@"
