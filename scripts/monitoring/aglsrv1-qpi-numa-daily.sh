#!/usr/bin/env bash
# Watchdog AGLSRV1: QPI, VM104 NUMA, meshagent, memória, swap.
# Só escreve stdout (→ Telegram via Hermes --no-agent) quando há falhas.
#
# Uso:
#   bash scripts/monitoring/aglsrv1-qpi-numa-daily.sh           # silencioso se OK
#   bash scripts/monitoring/aglsrv1-qpi-numa-daily.sh --dry-run # exemplo de alerta (testes)
#   bash scripts/monitoring/aglsrv1-qpi-numa-daily.sh --dry-run-ok  # silencioso (testes)
#
# Env (opcional):
#   AGLSRV1_HOST VMID HOST_CORES MESHAGENT_LEAK_RSS_KB VM_CPU_ALERT_PCT
#   LOAD_ALERT_MULT MEM_AVAIL_MIN_GB SWAP_USED_PCT_MAX VM_LAN_IP EXPECTED_NUMA

set -euo pipefail

AGLSRV1_HOST="${AGLSRV1_HOST:-root@100.107.113.33}"
VMID="${VMID:-104}"
VM_LAN_IP="${VM_LAN_IP:-192.168.0.33}"
HOST_CORES="${HOST_CORES:-24}"
EXPECTED_NUMA="${EXPECTED_NUMA:-1}"
MESHAGENT_LEAK_RSS_KB="${MESHAGENT_LEAK_RSS_KB:-1000000}"
VM_CPU_ALERT_PCT="${VM_CPU_ALERT_PCT:-1000}"
LOAD_ALERT_MULT="${LOAD_ALERT_MULT:-2}"
MEM_AVAIL_MIN_GB="${MEM_AVAIL_MIN_GB:-10}"
SWAP_USED_PCT_MAX="${SWAP_USED_PCT_MAX:-60}"

MODE="${1:-}"

remote() {
  ssh -o BatchMode=yes -o ConnectTimeout=20 -o StrictHostKeyChecking=accept-new "${AGLSRV1_HOST}" "$@"
}

if [[ "${MODE}" == "--dry-run" ]]; then
  cat <<EOF
🚨 AGLSRV1 — alerta (dry-run)
$(TZ=America/Sao_Paulo date '+%Y-%m-%d %H:%M %Z')

⚠️ Guest Agent VM104 DOWN
⚠️ meshagent LEAK: PID 12345 RSS 15360MB

VM104 (aglwk45)
• status: running | GA: FAIL | ping LAN: FAIL
• numa: 1 | CPU KVM: 1200% | PSR: 42

QPI
• Uncorrected_error: 0 | 24h CRC corrigidos: 2911

Host
• load (1/5/15m): 146 / 120 / 90 (cores ${HOST_CORES})
• RAM avail: 8Gi (< ${MEM_AVAIL_MIN_GB}Gi)
• swap: 72% usado
• meshagent: 32 proc, 2 leak, 28GB RSS leak total

Doc: agl-hostman/docs/AGLSRV1-NUMA-QPI-OPTIMIZATION.md
EOF
  exit 0
fi

if [[ "${MODE}" == "--dry-run-ok" ]]; then
  exit 0
fi

read -r -d '' REMOTE_SCRIPT <<EOS || true
set -euo pipefail
VMID="\${1:?}"
VM_LAN_IP="\${2:?}"
HOST_CORES="\${3:?}"
MESHAGENT_LEAK_RSS_KB="\${4:?}"

vm_status="\$(qm status "\${VMID}" 2>/dev/null | awk '{print \$2}' || echo unknown)"
ga_status="FAIL"
if qm agent "\${VMID}" ping >/dev/null 2>&1; then ga_status="OK"; fi

ping_lan="FAIL"
if ping -c 1 -W 2 "\${VM_LAN_IP}" >/dev/null 2>&1; then ping_lan="OK"; fi

vm_numa="\$(qm config "\${VMID}" 2>/dev/null | awk -F': ' '/^numa:/{print \$2; exit}')"
vm_affinity="\$(qm config "\${VMID}" 2>/dev/null | awk -F': ' '/^affinity:/{print \$2; exit}')"
kvm_cpu="\$(ps aux | grep "kvm.*-id \${VMID} " | grep -v grep | awk '{print \$3}' | head -1)"
kvm_cpu="\${kvm_cpu:-0}"

qpi_24h="\$(journalctl -u rasdaemon --since '24 hours ago' --no-pager 2>/dev/null | grep -c 'CRC error' || echo 0)"
qpi_1h="\$(journalctl -u rasdaemon --since '1 hour ago' --no-pager 2>/dev/null | grep -c 'CRC error' || echo 0)"
qpi_uncorr="\$(ras-mc-ctl --errors 2>/dev/null | tail -50 | grep -c Uncorrected_error || echo 0)"

mem_summary="\$(ras-mc-ctl --summary 2>/dev/null | grep -iE 'memory error|pcie aer' | head -3 | tr '\n' '; ')"
mem_summary="\${mem_summary:-ok}"

load1="\$(awk '{print \$1}' /proc/loadavg)"
load_avg="\$(awk '{print \$1" / "\$2" / "\$3}' /proc/loadavg)"
mem_avail_gb="\$(free -g | awk '/^Mem:/{print \$7}')"
mem_line="\$(free -h | awk '/^Mem:/{print \$3"/"\$2" usada, "\$7" avail"}')"
swap_total_kb="\$(free | awk '/^Swap:/{print \$2}')"
swap_used_kb="\$(free | awk '/^Swap:/{print \$3}')"
swap_pct=0
if [[ "\${swap_total_kb}" -gt 0 ]]; then
  swap_pct=\$(( swap_used_kb * 100 / swap_total_kb ))
fi
swap_line="\$(free -h | awk '/^Swap:/{print \$3"/"\$2" ("\$3")"}')"
microcode="\$(grep -m1 microcode /proc/cpuinfo | awk '{print \$3}')"

meshagent_count="\$(pgrep -c meshagent 2>/dev/null || echo 0)"
meshagent_leaks="\$(ps aux | grep meshagent | grep -v grep | awk -v lim="\${MESHAGENT_LEAK_RSS_KB}" '{if (\$6 > lim) print \$2":"int(\$6/1024)"MB"}' | paste -sd, -)"
meshagent_leak_n="\$(ps aux | grep meshagent | grep -v grep | awk -v lim="\${MESHAGENT_LEAK_RSS_KB}" '{if (\$6 > lim) c++} END{print c+0}')"
meshagent_leak_rss_mb="\$(ps aux | grep meshagent | grep -v grep | awk -v lim="\${MESHAGENT_LEAK_RSS_KB}" '{if (\$6 > lim) s+=\$6} END{print int(s/1024)}')"

kvm_pid="\$(pgrep -f "kvm.*-id \${VMID} " | head -1 || true)"
kvm_psr="n/a"
if [[ -n "\${kvm_pid}" ]]; then
  kvm_psr="\$(ps -o psr= -p "\${kvm_pid}" 2>/dev/null | xargs || echo n/a)"
fi

printf '%s\n' \
  "vm_status=\${vm_status}" \
  "ga_status=\${ga_status}" \
  "ping_lan=\${ping_lan}" \
  "vm_numa=\${vm_numa}" \
  "vm_affinity=\${vm_affinity}" \
  "kvm_cpu=\${kvm_cpu}" \
  "kvm_psr=\${kvm_psr}" \
  "qpi_24h=\${qpi_24h}" \
  "qpi_1h=\${qpi_1h}" \
  "qpi_uncorr=\${qpi_uncorr}" \
  "mem_summary=\${mem_summary}" \
  "load1=\${load1}" \
  "load_avg=\${load_avg}" \
  "mem_avail_gb=\${mem_avail_gb}" \
  "mem_line=\${mem_line}" \
  "swap_pct=\${swap_pct}" \
  "swap_line=\${swap_line}" \
  "microcode=\${microcode}" \
  "meshagent_count=\${meshagent_count}" \
  "meshagent_leak_n=\${meshagent_leak_n}" \
  "meshagent_leaks=\${meshagent_leaks}" \
  "meshagent_leak_rss_mb=\${meshagent_leak_rss_mb}" \
  "host_cores=\${HOST_CORES}"
EOS

mapfile -t kv < <(remote bash -s -- "${VMID}" "${VM_LAN_IP}" "${HOST_CORES}" "${MESHAGENT_LEAK_RSS_KB}" <<<"${REMOTE_SCRIPT}")

declare -A M=()
for line in "${kv[@]}"; do
  [[ "${line}" == *"="* ]] || continue
  M["${line%%=*}"]="${line#*=}"
done

issues=()

add_issue() {
  issues+=("$1")
}

if [[ "${M[vm_status]:-}" != "running" ]]; then
  add_issue "🚨 VM${VMID} status: ${M[vm_status]:-unknown} (esperado: running)"
fi
if [[ "${M[ga_status]:-}" != "OK" ]]; then
  add_issue "⚠️ Guest Agent VM${VMID} DOWN"
fi
if [[ "${M[ping_lan]:-}" != "OK" ]]; then
  add_issue "⚠️ VM${VMID} sem ping LAN (${VM_LAN_IP})"
fi
if [[ "${M[vm_numa]:-}" != "${EXPECTED_NUMA}" ]]; then
  add_issue "⚠️ VM${VMID} numa=${M[vm_numa]:-?} (esperado: ${EXPECTED_NUMA})"
fi

if [[ "${M[qpi_uncorr]:-0}" =~ ^[0-9]+$ ]] && [[ "${M[qpi_uncorr]}" -gt 0 ]]; then
  add_issue "🚨 QPI Uncorrected_error: ${M[qpi_uncorr]} (últimas 50 entradas)"
fi
if [[ "${M[mem_summary]:-}" != "ok" ]] && [[ "${M[mem_summary]:-}" != *"No Memory errors"* ]]; then
  if [[ "${M[mem_summary]:-}" == *"Memory errors"* ]] || [[ "${M[mem_summary]:-}" == *"PCIe AER"* ]]; then
    add_issue "🚨 RAS: ${M[mem_summary]}"
  fi
fi

kvm_cpu_int="${M[kvm_cpu]:-0}"
if [[ "${kvm_cpu_int}" =~ ^[0-9.]+$ ]]; then
  kvm_cpu_int="${kvm_cpu_int%.*}"
  if [[ "${kvm_cpu_int}" -gt "${VM_CPU_ALERT_PCT}" ]]; then
    add_issue "⚠️ VM${VMID} CPU KVM ${kvm_cpu_int}% (limite ${VM_CPU_ALERT_PCT}%)"
  fi
fi

load1="${M[load1]:-0}"
if [[ "${load1}" =~ ^[0-9.]+$ ]]; then
  load_thresh="$(awk -v c="${HOST_CORES}" -v m="${LOAD_ALERT_MULT}" 'BEGIN{printf "%d", c*m}')"
  load1_int="${load1%.*}"
  if [[ "${load1_int}" -gt "${load_thresh}" ]]; then
    add_issue "⚠️ Load 1m ${load1} > ${load_thresh} (${HOST_CORES} cores × ${LOAD_ALERT_MULT})"
  fi
fi

if [[ "${M[mem_avail_gb]:-99}" =~ ^[0-9]+$ ]] && [[ "${M[mem_avail_gb]}" -lt "${MEM_AVAIL_MIN_GB}" ]]; then
  add_issue "⚠️ RAM avail ${M[mem_avail_gb]}Gi < ${MEM_AVAIL_MIN_GB}Gi"
fi

if [[ "${M[swap_pct]:-0}" =~ ^[0-9]+$ ]] && [[ "${M[swap_pct]}" -gt "${SWAP_USED_PCT_MAX}" ]]; then
  add_issue "⚠️ Swap ${M[swap_pct]}% usado (limite ${SWAP_USED_PCT_MAX}%)"
fi

if [[ "${M[meshagent_leak_n]:-0}" =~ ^[0-9]+$ ]] && [[ "${M[meshagent_leak_n]}" -gt 0 ]]; then
  add_issue "🚨 meshagent LEAK: ${M[meshagent_leak_n]} proc, ${M[meshagent_leak_rss_mb]:-?}MB RSS — ${M[meshagent_leaks]:-?}"
fi

# Sem falhas → silêncio (Hermes --no-agent não envia Telegram)
if [[ ${#issues[@]} -eq 0 ]]; then
  exit 0
fi

TZ_BRT="$(TZ=America/Sao_Paulo date '+%Y-%m-%d %H:%M %Z')"
qpi_rate=""
if [[ "${M[qpi_1h]:-0}" =~ ^[0-9]+$ ]] && [[ "${M[qpi_1h]}" -gt 0 ]]; then
  qpi_rate=" (~$(( M[qpi_1h] / 60 ))/min na última hora)"
fi

{
  echo "🚨 AGLSRV1 — alerta"
  echo "${TZ_BRT}"
  echo
  for item in "${issues[@]}"; do
    echo "${item}"
  done
  echo
  echo "VM${VMID} (aglwk45)"
  echo "• status: ${M[vm_status]:-?} | GA: ${M[ga_status]:-?} | ping LAN: ${M[ping_lan]:-?}"
  echo "• numa: ${M[vm_numa]:-?} | CPU KVM: ${M[kvm_cpu]:-?}% | PSR: ${M[kvm_psr]:-?}"
  echo "• affinity: ${M[vm_affinity]:-?}"
  echo
  echo "QPI (baseline CRC corrigido não alerta)"
  echo "• Uncorrected: ${M[qpi_uncorr]:-0} | 24h CRC corrigidos: ${M[qpi_24h]:-?}${qpi_rate}"
  echo "• RAS: ${M[mem_summary]:-ok}"
  echo
  echo "Host"
  echo "• load (1/5/15m): ${M[load_avg]:-?} (cores ${HOST_CORES})"
  echo "• RAM: ${M[mem_line]:-?}"
  echo "• swap: ${M[swap_line]:-?} (${M[swap_pct]:-0}% usado)"
  echo "• microcode: ${M[microcode]:-?}"
  echo "• meshagent: ${M[meshagent_count]:-0} processos"
  echo
  echo "Runbook: docs/AGLSRV1-TROUBLESHOOTING.md"
}
