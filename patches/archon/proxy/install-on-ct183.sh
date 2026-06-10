#!/usr/bin/env bash
# Instala archon-v04-proxy.service no CT183 (executar dentro do CT ou via pct exec).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET="/opt/archon/proxy"

require_root() {
    [[ "${EUID}" -eq 0 ]] || { echo "Executar como root." >&2; exit 1; }
}

main() {
    require_root
    install -d "${TARGET}"
    install -m 644 "${SCRIPT_DIR}/nginx-archon-v04-proxy.conf" "${TARGET}/"
    install -m 644 "${SCRIPT_DIR}/README.md" "${TARGET}/"
    install -m 755 "${SCRIPT_DIR}/manage-legacy-proxy.sh" "${TARGET}/"
    sed -i 's/\r$//' "${TARGET}/manage-legacy-proxy.sh"
    install -m 644 "${SCRIPT_DIR}/archon-v04-proxy.service" /etc/systemd/system/
    systemctl daemon-reload
    systemctl enable --now archon-v04-proxy.service
    systemctl status archon-v04-proxy.service --no-pager
    curl -sf -o /dev/null -w "3737 /api/health HTTP %{http_code}\n" http://127.0.0.1:3737/api/health
}

main "$@"
