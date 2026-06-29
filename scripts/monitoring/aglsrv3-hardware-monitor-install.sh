#!/usr/bin/env bash
# Instala monitorização hardware no AGLSRV3 (temp, RAPL power, SMART discos).
# Sem IPMI/BMC nesta placa — usa lm-sensors + intel-rapl + smartmontools.
#
# Uso local no host:
#   bash scripts/monitoring/aglsrv3-hardware-monitor-install.sh --apply
# Remoto (agldv03):
#   bash scripts/monitoring/aglsrv3-hardware-monitor-install.sh --apply --remote

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
# shellcheck source=../proxmox/aglsrv-vmid-map.env
[[ -f "${SCRIPT_DIR}/../proxmox/aglsrv-vmid-map.env" ]] && source "${SCRIPT_DIR}/../proxmox/aglsrv-vmid-map.env"

APPLY=false
REMOTE=false
AGLSRV3_SSH="${AGLSRV3_SSH:-root@100.123.5.81}"

log() { echo "[$(date +%H:%M:%S)] $*"; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --apply) APPLY=true; shift ;;
    --remote) REMOTE=true; shift ;;
    -h|--help)
      sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *) echo "Opção desconhecida: $1" >&2; exit 2 ;;
  esac
done

install_local() {
  log "Pacotes: lm-sensors smartmontools sysstat (ipmitool se BMC existir)"
  if [[ "$APPLY" == true ]]; then
    apt-get update -qq
    DEBIAN_FRONTEND=noninteractive apt-get install -y lm-sensors smartmontools sysstat ipmitool 2>/dev/null || \
      DEBIAN_FRONTEND=noninteractive apt-get install -y lm-sensors smartmontools sysstat
    sensors-detect --auto >/dev/null 2>&1 || true
    modprobe coretemp 2>/dev/null || true
    systemctl enable smartd 2>/dev/null || true
    systemctl restart smartd 2>/dev/null || true
  else
    log "DRY-RUN: apt install lm-sensors smartmontools sysstat"
  fi

  log "Deploy snapshot script"
  if [[ "$APPLY" == true ]]; then
    install -d /usr/local/sbin /var/log/hostman /etc/cron.d
    local snap="${SCRIPT_DIR}/aglsrv3-hardware-snapshot.sh"
    [[ -f "$snap" ]] || snap="${REPO_ROOT}/scripts/monitoring/aglsrv3-hardware-snapshot.sh"
    install -m 0755 "$snap" /usr/local/sbin/aglsrv3-hardware-snapshot.sh
    cat >/etc/cron.d/aglsrv3-hardware-monitor <<'CRON'
# AGLSRV3 — temp / RAPL / SMART (5 min)
*/5 * * * * root /usr/local/sbin/aglsrv3-hardware-snapshot.sh >> /var/log/hostman/aglsrv3-hardware.log 2>&1
CRON
  fi

  log "Teste:"
  if [[ "$APPLY" == true ]]; then
    /usr/local/sbin/aglsrv3-hardware-snapshot.sh || true
    sensors 2>/dev/null | head -8 || true
    ipmitool mc info 2>/dev/null | head -3 || log "Sem BMC/IPMI (esperado X99-F8)"
  fi
}

if [[ "$REMOTE" == true ]]; then
  scp -q "${REPO_ROOT}/scripts/monitoring/aglsrv3-hardware-snapshot.sh" \
    "${REPO_ROOT}/scripts/monitoring/aglsrv3-hardware-monitor-install.sh" \
    "${AGLSRV3_SSH}:/root/"
  ssh -o BatchMode=yes "${AGLSRV3_SSH}" "REPO_ROOT=/root bash /root/aglsrv3-hardware-monitor-install.sh $([[ $APPLY == true ]] && echo --apply)"
else
  install_local
fi
