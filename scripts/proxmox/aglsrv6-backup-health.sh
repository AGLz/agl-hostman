#!/usr/bin/env bash
# Health check backups AGLSRV6 (man6) — VM620, PBS CT613, storages usb4tb vs man6-pbs.
#
# Uso:
#   bash aglsrv6-backup-health.sh              # local no man6
#   bash aglsrv6-backup-health.sh --remote     # SSH via Tailscale (aglsrv-vmid-map.env)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=aglsrv-vmid-map.env
source "${SCRIPT_DIR}/aglsrv-vmid-map.env"

REMOTE=false
FAIL=0

warn() { echo "WARN: $*"; }
fail() { echo "FAIL: $*"; FAIL=1; }
ok() { echo "OK: $*"; }
section() { echo; echo "=== $* ==="; }

usage() {
  echo "Uso: $0 [--remote]"
  exit 0
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --remote) REMOTE=true; shift ;;
    -h|--help) usage ;;
    *) echo "Opção desconhecida: $1" >&2; exit 1 ;;
  esac
done

run_check() {
  if [[ "${REMOTE}" == true ]]; then
    ssh -o ConnectTimeout=20 -o BatchMode=yes "${AGLSRV6_SSH}" "$@"
  else
    bash -c "$*"
  fi
}

section "Storages PVE"
run_check 'pvesm status 2>/dev/null | grep -E "^(man6-pbs|usb4tb-direct|Name)" || true'

section "Job backup-vm620-production"
run_check 'grep -A14 "^vzdump: backup-vm620-production" /etc/pve/jobs.cfg 2>/dev/null || fail "job backup-vm620-production ausente"'

STORAGE=$(run_check "grep -A14 '^vzdump: backup-vm620-production' /etc/pve/jobs.cfg | awk -F' ' '/^[[:space:]]*storage/{print \$2}' | head -1" || true)
ENABLED=$(run_check "grep -A14 '^vzdump: backup-vm620-production' /etc/pve/jobs.cfg | awk '/^[[:space:]]*enabled/{print \$2}' | head -1" || true)

if [[ "${STORAGE:-}" == "usb4tb-direct" ]]; then
  fail "VM620 aponta para usb4tb-direct (root host ~66GB) — usar man6-pbs"
elif [[ "${STORAGE:-}" == "man6-pbs" ]]; then
  ok "VM620 storage=man6-pbs"
else
  warn "VM620 storage=${STORAGE:-desconhecido}"
fi

if [[ "${ENABLED:-0}" != "1" ]]; then
  fail "Job backup-vm620-production desactivado"
else
  ok "Job backup-vm620-production activo"
fi

section "Espaço host /mnt/usb4tb-direct (vzdump dir — NÃO é o USB físico)"
run_check 'df -h /mnt/usb4tb-direct 2>/dev/null; ls -la /mnt/usb4tb-direct/dump/*.vma* 2>/dev/null | tail -3 || echo "(sem ficheiros .vma no host)"'

section "Últimas tasks VM620"
run_check 'pvesh get /nodes/man6/tasks --limit 15 2>/dev/null | grep -E "620|backup-vm620" | head -8 || true'

section "PBS CT613 — datastores e espaço"
run_check 'pct exec 613 -- df -h /mnt/backups /mnt/usb4tb-direct 2>/dev/null || warn "CT613 inacessível"'

section "VM620 estado"
run_check 'qm status 620 2>/dev/null; qm agent 620 ping 2>/dev/null && echo "OK: guest agent responde" || echo "WARN: guest agent VM620 não responde (sem fs-freeze)"'

section "Resumo"
if [[ "${FAIL}" -eq 0 ]]; then
  ok "Checks críticos passaram (ver WARN acima)"
  exit 0
else
  fail "Checks críticos falharam — ver docs/maint/AGLSRV6-BACKUP-PBS-TASK-FORCE.md Fase 0"
  exit 1
fi
