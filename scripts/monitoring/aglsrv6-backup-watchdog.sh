#!/usr/bin/env bash
# Watchdog backups AGLSRV6 — vzdump preso, locks stale, falhas PBS, espaço hot.
# Integração Hermes Werner: [SILENT] se OK; stdout → Telegram em falha.
#
# Uso:
#   bash aglsrv6-backup-watchdog.sh
#   bash aglsrv6-backup-watchdog.sh --dry-run

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=hermes-notify-lib.sh
source "${SCRIPT_DIR}/hermes-notify-lib.sh"
MAP="${SCRIPT_DIR}/../proxmox/aglsrv-vmid-map.env"
# shellcheck source=/dev/null
[[ -f "${MAP}" ]] && source "${MAP}"

AGLSRV6_HOST="${AGLSRV6_SSH:-root@100.98.108.66}"
SSH_OPTS="-o BatchMode=yes -o ConnectTimeout=25 -o StrictHostKeyChecking=accept-new"
PBS_VMID="${AGLSRV6_PBS_VMID:-613}"
VZDUMP_MAX_CT_SEC="${VZDUMP_MAX_CT_SEC:-14400}"    # 4h
VZDUMP_MAX_VM_SEC="${VZDUMP_MAX_VM_SEC:-28800}"   # 8h
LOCK_MAX_SEC="${LOCK_MAX_SEC:-21600}"             # 6h
HOT_USE_PCT_MAX="${HOT_USE_PCT_MAX:-80}"

MODE="${1:-}"
ALERTS=()

remote() {
  ssh ${SSH_OPTS} "${AGLSRV6_HOST}" "$@"
}

if [[ "${MODE}" == "--dry-run" ]]; then
  hermes_notify_emit "🚨 AGLSRV6 backup watchdog (dry-run)

• vzdump CT611 há 7h (limite 4h)
• lock backup em CT611 sem progresso
• datastore backups 82% usado

Doc: docs/maint/AGLSRV6-BACKUP-RETENTION-POLICY.md"
  exit 0
fi

# --- vzdump processos presos ---
while IFS= read -r line; do
  [[ -n "${line}" ]] || continue
  pid=$(echo "${line}" | awk '{print $1}')
  etime=$(echo "${line}" | awk '{print $2}')
  cmd=$(echo "${line}" | cut -d' ' -f3-)
  # etime: [[dd-]hh:]mm:ss
  secs=0
  if [[ "${etime}" =~ ^([0-9]+)-([0-9]{2}):([0-9]{2}):([0-9]{2})$ ]]; then
    secs=$(( ${BASH_REMATCH[1]}*86400 + ${BASH_REMATCH[2]}*3600 + ${BASH_REMATCH[3]}*60 + ${BASH_REMATCH[4]} ))
  elif [[ "${etime}" =~ ^([0-9]{2}):([0-9]{2}):([0-9]{2})$ ]]; then
    secs=$(( ${BASH_REMATCH[1]}*3600 + ${BASH_REMATCH[2]}*60 + ${BASH_REMATCH[3]} ))
  elif [[ "${etime}" =~ ^([0-9]{2}):([0-9]{2})$ ]]; then
    secs=$(( ${BASH_REMATCH[1]}*60 + ${BASH_REMATCH[2]} ))
  fi
  limit="${VZDUMP_MAX_CT_SEC}"
  echo "${cmd}" | grep -qE 'vzdump [0-9]+' && limit="${VZDUMP_MAX_VM_SEC}"
  if [[ "${secs}" -gt "${limit}" ]]; then
    ALERTS+=("vzdump preso PID ${pid} há ${etime}: ${cmd:0:80}")
  fi
done < <(remote 'ps -eo pid,etime,cmd | grep -E "vzdump|proxmox-backup-client backup" | grep -v grep' 2>/dev/null || true)

# --- vzdump.lock stale ---
lock_info=$(remote 'if [[ -f /var/run/vzdump.lock ]]; then
  if pgrep -f "vzdump|proxmox-backup-client backup" >/dev/null 2>&1; then echo ACTIVE; else echo STALE; ls -l /var/run/vzdump.lock; fi
else echo NONE; fi' 2>/dev/null || echo ERR)
if [[ "${lock_info}" == STALE* ]]; then
  ALERTS+=("vzdump.lock stale sem backup activo")
fi

# --- locks backup em guests ---
while IFS= read -r entry; do
  [[ -n "${entry}" ]] || continue
  vmid=$(echo "${entry}" | awk '{print $1}')
  name=$(echo "${entry}" | awk '{print $2}')
  typ=$(echo "${entry}" | awk '{print $3}')
  # idade da task vzdump para este vmid
  task_line=$(remote "pvesh get /nodes/man6/tasks --limit 30 2>/dev/null" | grep -E "${typ}.*${vmid}.*vzdump.*running" || true)
  if [[ -z "${task_line}" ]]; then
    ALERTS+=("lock backup em ${typ} ${vmid} (${name}) sem task vzdump activa — investigar unlock")
  fi
done < <(remote 'qm list 2>/dev/null | awk "NR>1 && \$4==\"backup\"{print \$1,\$2,\"vm\"}"
  pct list 2>/dev/null | awk "NR>1 && \$4==\"backup\"{print \$1,\$2,\"ct\"}"' 2>/dev/null || true)

# --- PBS tasks longas ---
pbs_tasks=$(remote "pct exec ${PBS_VMID} -- proxmox-backup-manager task list --limit 5 2>/dev/null" || true)
if echo "${pbs_tasks}" | grep -q running; then
  start=$(echo "${pbs_tasks}" | grep running | head -1 | awk '{print $2,$3,$4,$5,$6}')
  if [[ -n "${start}" ]]; then
    start_epoch=$(remote "date -d \"${start}\" +%s 2>/dev/null" || echo 0)
    now_epoch=$(remote 'date +%s')
    if [[ "${start_epoch}" -gt 0 ]]; then
      age=$(( now_epoch - start_epoch ))
      if [[ "${age}" -gt "${VZDUMP_MAX_CT_SEC}" ]]; then
        ALERTS+=("PBS task running há $(( age / 3600 ))h — ${pbs_tasks##*|}")
      fi
    fi
  fi
fi

# --- último vzdump VM620 falhou nas 36h ---
vm620_fail=$(remote 'pvesh get /nodes/man6/tasks --limit 20 2>/dev/null | grep "620.*vzdump" | grep -E "job errors|failed|abort" | head -1' || true)
if [[ -n "${vm620_fail}" ]]; then
  endtime=$(echo "${vm620_fail}" | awk -F'|' '{print $(NF-1)}' | tr -d ' ')
  if [[ "${endtime}" =~ ^[0-9]+$ ]]; then
    now=$(remote 'date +%s')
    if [[ $(( now - endtime )) -lt 129600 ]]; then
      ALERTS+=("VM620 vzdump falhou recentemente — verificar tasks Proxmox")
    fi
  fi
fi

# --- espaço hot ---
use_pct=$(remote "pct exec ${PBS_VMID} -- df -P /mnt/backups 2>/dev/null | awk 'NR==2{print \$5}' | tr -d '%'" || echo 0)
if [[ "${use_pct}" -ge "${HOT_USE_PCT_MAX}" ]]; then
  ALERTS+=("PBS datastore backups ${use_pct}% usado (limite ${HOT_USE_PCT_MAX}%)")
fi

# --- sync cold desactivado (info se hot quase cheio) ---
sync_sched=$(remote "pct exec ${PBS_VMID} -- proxmox-backup-manager sync-job show sync-hot-to-cold 2>/dev/null | grep schedule || true" || true)
if [[ -z "${sync_sched}" && "${use_pct}" -ge 70 ]]; then
  ALERTS+=("Sync hot→cold sem schedule e backups >70% — migrar USB ext4 (Fase B)")
fi

if [[ ${#ALERTS[@]} -eq 0 ]]; then
  hermes_notify_silent
  exit 0
fi

TITLE="🚨 AGLSRV6 — backup watchdog $(TZ=America/Sao_Paulo date '+%Y-%m-%d %H:%M %Z')"
hermes_notify_if_alerts "${TITLE}" "${ALERTS[@]}"
echo ""
echo "Doc: agl-hostman/docs/maint/AGLSRV6-BACKUP-RETENTION-POLICY.md"
