#!/usr/bin/env bash
# Instala aglsrv3-host-root-backup.sh + cron no host AGLSRV3.
#
# Uso local no aglsrv3:
#   bash aglsrv3-host-backup-install.sh
#
# Remoto (agldv03):
#   bash aglsrv3-host-backup-install.sh --remote

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REMOTE=false
AGLSRV3_SSH="${AGLSRV3_SSH:-root@100.123.5.81}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --remote) REMOTE=true; shift ;;
    -h|--help)
      echo "Uso: $0 [--remote]"
      exit 0
      ;;
    *) echo "Opção desconhecida: $1" >&2; exit 1 ;;
  esac
done

die() {
  echo "ERRO: $*" >&2
  exit 1
}

install_on_host() {
  local backup_src="/tmp/aglsrv3-host-root-backup.sh"
  if [[ ! -f "${backup_src}" ]]; then
    backup_src="${SCRIPT_DIR}/aglsrv3-host-root-backup.sh"
  fi
  [[ -f "${backup_src}" ]] || die "Ficheiro backup não encontrado: ${backup_src}"

  install -d -m 0755 /usr/local/sbin /etc/aglsrv3
  install -m 0755 "${backup_src}" /usr/local/sbin/aglsrv3-host-root-backup.sh

  if [[ ! -f /etc/aglsrv3/host-backup.env ]]; then
    cat > /etc/aglsrv3/host-backup.env <<'EOF'
# AGLSRV3 — backup disco principal (pve-root)
AGLSRV3_HOST_BACKUP_ROOT=/aglsrv3-tb/backups/host-root
AGLSRV3_PBS_VMID=318
AGLSRV3_PBS_IP=192.168.15.118
AGLSRV3_PBS_HOST_DATASTORE=aglsrv3-tb
AGLSRV3_HOST_CONFIG_RETAIN_DAYS=14
AGLSRV3_HOST_LV_RETAIN_WEEKS=8
EOF
  fi

  zfs list aglsrv3-tb/backups >/dev/null 2>&1 || zfs create aglsrv3-tb/backups
  mkdir -p /aglsrv3-tb/backups/host-root

  cat > /etc/cron.d/aglsrv3-host-root-backup <<'EOF'
# Backup disco principal Proxmox (config + manifest + PBS pxar)
30 3 * * * root /usr/local/sbin/aglsrv3-host-root-backup.sh daily >> /var/log/aglsrv3-host-root-backup.log 2>&1
# Dump semanal snapshot LVM pve/root (requer --prepare-lv na 1ª execução se root-snap-pre-pve9 existir)
0 3 * * 0 root /usr/local/sbin/aglsrv3-host-root-backup.sh weekly --prepare-lv >> /var/log/aglsrv3-host-root-backup.log 2>&1
EOF
  chmod 644 /etc/cron.d/aglsrv3-host-root-backup

  echo "Instalado: /usr/local/sbin/aglsrv3-host-root-backup.sh"
  echo "Cron: /etc/cron.d/aglsrv3-host-root-backup"
}

if [[ "${REMOTE}" == true ]]; then
  scp -q "${SCRIPT_DIR}/aglsrv3-host-root-backup.sh" "${AGLSRV3_SSH}:/tmp/aglsrv3-host-root-backup.sh"
  scp -q "${SCRIPT_DIR}/aglsrv3-host-backup-install.sh" "${AGLSRV3_SSH}:/tmp/aglsrv3-host-backup-install.sh"
  ssh -o ConnectTimeout=20 "${AGLSRV3_SSH}" "bash /tmp/aglsrv3-host-backup-install.sh"
else
  install_on_host
fi
