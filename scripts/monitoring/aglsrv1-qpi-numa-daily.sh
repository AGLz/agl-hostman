#!/usr/bin/env bash
# Relatório diário AGLSRV1: QPI (rasdaemon), VM104 NUMA, host vitals.
# Destino: stdout → Hermes Werner cron (--no-agent) → Telegram.
#
# Uso:
#   bash scripts/monitoring/aglsrv1-qpi-numa-daily.sh
#   bash scripts/monitoring/aglsrv1-qpi-numa-daily.sh --dry-run
#
# Env:
#   AGLSRV1_HOST  default root@100.107.113.33
#   VMID          default 104

set -euo pipefail

AGLSRV1_HOST="${AGLSRV1_HOST:-root@100.107.113.33}"
VMID="${VMID:-104}"
DRY_RUN=0

if [[ "${1:-}" == "--dry-run" ]]; then
  DRY_RUN=1
fi

remote() {
  if [[ "${DRY_RUN}" -eq 1 ]]; then
    return 0
  fi
  ssh -o BatchMode=yes -o ConnectTimeout=20 -o StrictHostKeyChecking=accept-new "${AGLSRV1_HOST}" "$@"
}

if [[ "${DRY_RUN}" -eq 1 ]]; then
  cat <<EOF
📊 AGLSRV1 — relatório diário (dry-run)
$(date '+%Y-%m-%d %H:%M %Z')

VM${VMID} (aglwk45)
• status: running | GA: OK
• numa: 1 | affinity: 14-27,42-55

QPI (24h)
• erros CRC corrigidos: (dry-run)

Host
• load: (dry-run)
• RAM: (dry-run)
• microcode: (dry-run)
EOF
  exit 0
fi

TZ_BRT="$(TZ=America/Sao_Paulo date '+%Y-%m-%d %H:%M %Z')"

read -r -d '' REMOTE_SCRIPT <<'EOS' || true
set -euo pipefail
VMID="${1:?}"

vm_status="$(qm status "${VMID}" 2>/dev/null | awk '{print $2}' || echo unknown)"
ga_status="FAIL"
if qm agent "${VMID}" ping >/dev/null 2>&1; then ga_status="OK"; fi

vm_numa="$(qm config "${VMID}" 2>/dev/null | awk -F': ' '/^numa:/{print $2; exit}')"
vm_affinity="$(qm config "${VMID}" 2>/dev/null | awk -F': ' '/^affinity:/{print $2; exit}')"
kvm_cpu="$(ps aux | grep "kvm.*-id ${VMID} " | grep -v grep | awk '{print $3}' | head -1)"
kvm_cpu="${kvm_cpu:-n/a}"

qpi_24h="$(journalctl -u rasdaemon --since '24 hours ago' --no-pager 2>/dev/null | grep -c 'CRC error' || echo 0)"
qpi_1h="$(journalctl -u rasdaemon --since '1 hour ago' --no-pager 2>/dev/null | grep -c 'CRC error' || echo 0)"
qpi_last="$(ras-mc-ctl --errors 2>/dev/null | tail -1 | sed 's/^[0-9]* //' | cut -c1-120)"
qpi_last="${qpi_last:-nenhum}"

mem_err="$(ras-mc-ctl --summary 2>/dev/null | grep -i 'memory error' | head -1 || true)"
mem_err="${mem_err:-No Memory errors.}"

load_avg="$(awk '{print $1" / "$2" / "$3}' /proc/loadavg)"
mem_line="$(free -h | awk '/^Mem:/{print $3"/"$2" usada, "$7" avail"}')"
microcode="$(grep -m1 microcode /proc/cpuinfo | awk '{print $3}')"
ram_cfg="$(dmidecode -t 17 2>/dev/null | awk -F': ' '/Configured Memory Speed/{print $2; exit}' | xargs)"
ram_cfg="${ram_cfg:-desconhecido}"

kvm_pid="$(pgrep -f "kvm.*-id ${VMID} " | head -1 || true)"
kvm_psr="n/a"
if [[ -n "${kvm_pid}" ]]; then
  kvm_psr="$(ps -o psr= -p "${kvm_pid}" 2>/dev/null | xargs || echo n/a)"
fi

printf '%s\n' \
  "vm_status=${vm_status}" \
  "ga_status=${ga_status}" \
  "vm_numa=${vm_numa}" \
  "vm_affinity=${vm_affinity}" \
  "kvm_cpu=${kvm_cpu}" \
  "kvm_psr=${kvm_psr}" \
  "qpi_24h=${qpi_24h}" \
  "qpi_1h=${qpi_1h}" \
  "qpi_last=${qpi_last}" \
  "mem_err=${mem_err}" \
  "load_avg=${load_avg}" \
  "mem_line=${mem_line}" \
  "microcode=${microcode}" \
  "ram_cfg=${ram_cfg}"
EOS

mapfile -t kv < <(remote bash -s -- "${VMID}" <<<"${REMOTE_SCRIPT}")

declare -A M=()
for line in "${kv[@]}"; do
  key="${line%%=*}"
  val="${line#*=}"
  M["${key}"]="${val}"
done

alert=""
if [[ "${M[ga_status]:-}" != "OK" ]]; then
  alert="${alert}⚠️ Guest Agent VM${VMID} DOWN\n"
fi
if [[ "${M[mem_err]:-}" != *"No Memory errors"* ]]; then
  alert="${alert}⚠️ Erros de memória ECC detectados\n"
fi
uncorr_count="$(remote bash -lc 'ras-mc-ctl --errors 2>/dev/null | tail -30 | grep -c Uncorrected_error || true')"
if [[ "${uncorr_count:-0}" -gt 0 ]]; then
  alert="${alert}🚨 QPI Uncorrected_error nas últimas entradas\n"
fi

qpi_1h="${M[qpi_1h]:-0}"
qpi_rate=""
if [[ "${qpi_1h}" =~ ^[0-9]+$ ]] && [[ "${qpi_1h}" -gt 0 ]]; then
  qpi_rate=" (~$(( qpi_1h / 60 ))/min na última hora)"
fi

{
  echo "📊 AGLSRV1 — relatório diário"
  echo "${TZ_BRT}"
  echo
  if [[ -n "${alert}" ]]; then
    echo -e "${alert}"
  fi
  echo "VM${VMID} (aglwk45)"
  echo "• status: ${M[vm_status]:-?} | GA: ${M[ga_status]:-?}"
  echo "• numa: ${M[vm_numa]:-?} | CPU KVM: ${M[kvm_cpu]:-?}% | PSR: ${M[kvm_psr]:-?}"
  echo "• affinity: ${M[vm_affinity]:-?}"
  echo
  echo "QPI (rasdaemon)"
  echo "• 24h: ${M[qpi_24h]:-?} erros CRC corrigidos${qpi_rate}"
  echo "• último: ${M[qpi_last]:-?}"
  echo "• RAM ECC: ${M[mem_err]:-?}"
  echo
  echo "Host"
  echo "• load (1/5/15m): ${M[load_avg]:-?}"
  echo "• RAM: ${M[mem_line]:-?}"
  echo "• microcode: ${M[microcode]:-?} (reboot host pendente se pacote novo)"
  echo "• RAM configured: ${M[ram_cfg]:-?}"
  echo
  echo "Doc: agl-hostman/docs/AGLSRV1-NUMA-QPI-OPTIMIZATION.md"
} 
