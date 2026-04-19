#!/bin/bash
# Instala scripts NFS e timer no host Proxmox AGLSRV5 (executar a partir da máquina com SSH ao aglsrv5).
#
# Uso:
#   ./install-nfs-local-aglsrv5.sh [user@]100.119.223.113
#   ./install-nfs-local-aglsrv5.sh --uninstall [user@]host
#
# Requer: ssh com acesso root ao destino, rsync ou scp.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${SCRIPT_DIR}/../.."
REMOTE_LIB="/usr/local/lib/agl-nfs-monitor"
REMOTE_LOG="/var/log/agl-nfs-monitor"
SYSTEMD_DIR="/etc/systemd/system"

UNINSTALL=false
TARGET=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --uninstall)
      UNINSTALL=true
      shift
      ;;
    *)
      TARGET="$1"
      shift
      ;;
  esac
done

if [[ -z "${TARGET}" ]]; then
  echo "Uso: $0 [--uninstall] root@100.119.223.113"
  exit 1
fi

ssh_base=(ssh -o BatchMode=yes -o ConnectTimeout=15 -o StrictHostKeyChecking=no "${TARGET}")

if [[ "${UNINSTALL}" == "true" ]]; then
  echo "A desinstalar timer no ${TARGET}..."
  "${ssh_base[@]}" bash -s <<'REMOTE'
set -euo pipefail
systemctl stop agl-nfs-aglsrv5-local.timer 2>/dev/null || true
systemctl disable agl-nfs-aglsrv5-local.timer 2>/dev/null || true
rm -f /etc/systemd/system/agl-nfs-aglsrv5-local.service
rm -f /etc/systemd/system/agl-nfs-aglsrv5-local.timer
systemctl daemon-reload
echo "Removido timer agl-nfs-aglsrv5-local (ficheiros em /usr/local/lib/agl-nfs-monitor mantidos)."
REMOTE
  exit 0
fi

echo "A instalar em ${TARGET} → ${REMOTE_LIB}"
"${ssh_base[@]}" "mkdir -p '${REMOTE_LIB}' '${REMOTE_LOG}'"

for f in nfs-tailscale-recovery.sh nfs-aglsrv5-local-remount.sh; do
  scp -o BatchMode=yes -o ConnectTimeout=15 -o StrictHostKeyChecking=no \
    "${SCRIPT_DIR}/${f}" "${TARGET}:${REMOTE_LIB}/${f}"
done

chmod_remote="chmod +x '${REMOTE_LIB}/nfs-tailscale-recovery.sh' '${REMOTE_LIB}/nfs-aglsrv5-local-remount.sh'"

scp -o BatchMode=yes -o ConnectTimeout=15 -o StrictHostKeyChecking=no \
  "${PROJECT_ROOT}/config/systemd/agl-nfs-aglsrv5-local.service" \
  "${PROJECT_ROOT}/config/systemd/agl-nfs-aglsrv5-local.timer" \
  "${TARGET}:${SYSTEMD_DIR}/"

"${ssh_base[@]}" bash -s <<REMOTE
set -euo pipefail
${chmod_remote}
mkdir -p '${REMOTE_LOG}'
systemctl daemon-reload
systemctl enable --now agl-nfs-aglsrv5-local.timer
systemctl list-timers agl-nfs-aglsrv5-local.timer --no-pager || true
echo "Instalação concluída. Logs: journalctl -u agl-nfs-aglsrv5-local.service -f"
REMOTE
