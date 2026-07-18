#!/usr/bin/env bash
# Health check backups AGLSRV6 — política PBS-only + retenção hot/cold.
# Uso: bash aglsrv6-backup-health.sh [--remote]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=aglsrv-vmid-map.env
source "${SCRIPT_DIR}/aglsrv-vmid-map.env"

REMOTE=false
FAIL=0
warn() { echo "WARN: $*"; }
fail() { echo "FAIL: $*"; FAIL=1; }
ok() { echo "OK: $*"; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --remote) REMOTE=true; shift ;;
    -h|--help) echo "Uso: $0 [--remote]"; exit 0 ;;
    *) echo "Opção: $1" >&2; exit 1 ;;
  esac
done

run_check() {
  if [[ "${REMOTE}" == true ]]; then
    ssh -o BatchMode=yes -o ConnectTimeout=20 "${AGLSRV6_SSH}" "$@"
  else
    bash -c "$*"
  fi
}

echo "=== Jobs → man6-pbs ==="
for j in backup-vm620-production backup-pbs-tier1-sql-6h backup-pbs-tier2-infra-12h backup-pbs-tier3-daily; do
  st=$(run_check "grep -A14 '^vzdump: ${j}' /etc/pve/jobs.cfg | awk '/storage/{print \$2}' | head -1" || true)
  en=$(run_check "grep -A14 '^vzdump: ${j}' /etc/pve/jobs.cfg | awk '/enabled/{print \$2}' | head -1" || true)
  if [[ "${en}" == "1" && "${st}" == "man6-pbs" ]]; then ok "${j}"; else [[ "${en}" == "1" ]] && fail "${j} storage=${st:-?}"; fi
done

echo "=== Prune hot (keep-last=1) ==="
prune_out=$(run_check 'pct exec 613 -- proxmox-backup-manager prune-job show prune-hot-backups 2>/dev/null' || true)
if echo "${prune_out}" | grep -qE 'keep-last\s*\|\s*1|keep-last[[:space:]]+1'; then
  ok "prune-hot keep-last=1"
elif echo "${prune_out}" | grep -q keep-last; then
  warn "prune-hot presente mas keep-last != 1"
  echo "${prune_out}"
else
  fail "prune-hot ausente"
fi

echo "=== Cold USB (exFAT vzdump) ==="
if run_check 'mountpoint -q /mnt/usb4tb-direct && test -x /root/aglsrv6-usb-cold-export.sh'; then
  ok "USB montado + cold-export"
else
  warn "USB ou cold-export ausente"
fi
if run_check 'test -f /etc/cron.d/aglsrv6-usb-cold-export'; then
  ok "cron cold-export activo"
else
  warn "cron cold-export inactivo"
fi

echo "=== Espaço hot (ZFS) + USB ==="
run_check 'pct exec 613 -- df -h /mnt/backups; df -hT /mnt/usb4tb-direct 2>/dev/null || true'

[[ "${FAIL}" -eq 0 ]] && ok "Health PBS-only OK" || fail "Ver AGLSRV6-BACKUP-RETENTION-POLICY.md"
exit "${FAIL}"
