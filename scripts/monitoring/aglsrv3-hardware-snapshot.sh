#!/usr/bin/env bash
# Snapshot hardware AGLSRV3: temperatura, potência (RAPL), discos SMART, carga.
# Executar no host (cron cada 5 min) ou via SSH remoto.
#
# Uso:
#   bash scripts/monitoring/aglsrv3-hardware-snapshot.sh
#   bash scripts/monitoring/aglsrv3-hardware-snapshot.sh --json
set -euo pipefail

JSON=false
LOG="${AGLSRV3_HW_LOG:-/var/log/hostman/aglsrv3-hardware.log}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --json) JSON=true; shift ;;
    -h|--help)
      sed -n '2,8p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *) echo "Opção desconhecida: $1" >&2; exit 2 ;;
  esac
done

mkdir -p "$(dirname "$LOG")"
ts="$(date -Iseconds)"

read_cpu_pkg_temp() {
  sensors coretemp-isa-0000 2>/dev/null \
    | awk '/Package id 0:/ {for (i = 1; i <= NF; i++) if ($i ~ /^\+/) {gsub(/^\+/, "", $i); print $i; exit}}' \
    || echo "null"
}

read_rapl_watts() {
  local base="/sys/class/powercap/intel-rapl/intel-rapl:0"
  [[ -f "${base}/energy_uj" ]] || { echo "null"; return; }
  local e1 t1 e2 t2
  e1=$(<"${base}/energy_uj")
  t1=$(date +%s%N)
  sleep 1
  e2=$(<"${base}/energy_uj")
  t2=$(date +%s%N)
  awk -v e1="$e1" -v e2="$e2" -v t1="$t1" -v t2="$t2" 'BEGIN {
    dt=(t2-t1)/1e9; if (dt<=0) {print "null"; exit}
    w=(e2-e1)/1e6/dt; printf "%.1f", w
  }'
}

read_disk_temps() {
  local out=""
  for dev in /dev/sd?; do
    [[ -b "$dev" ]] || continue
    local t
    t=$(smartctl -A -d sat "$dev" 2>/dev/null | awk '/Temperature_Celsius/ {print $10; exit}' || true)
    [[ -n "$t" ]] || continue
    out+="${dev##*/}:${t}C "
  done
  echo "${out:-none}"
}

read_gpu_temps() {
  local out=""
  for card in /sys/class/drm/card[0-9]/device/hwmon/hwmon*/temp*_input; do
    [[ -f "$card" ]] || continue
    local t=$(( $(<"$card") / 1000 ))
    out+="$(basename "$(dirname "$card")"):${t}C "
  done
  echo "${out:-none}"
}

loadavg="$(awk '{print $1" "$2" "$3}' /proc/loadavg)"
mem_avail_kb="$(awk '/MemAvailable/ {print $2}' /proc/meminfo)"
swap_used_kb="$(awk '/SwapTotal/ {t=$2} /SwapFree/ {f=$2} END {print t-f}' /proc/meminfo)"
cpu_pkg="$(read_cpu_pkg_temp)"
rapl_w="$(read_rapl_watts)"
disk_t="$(read_disk_temps)"
gpu_t="$(read_gpu_temps)"
bios_ver="$(dmidecode -s bios-version 2>/dev/null || echo unknown)"
zpool_h="$(zpool list -H -o health aglsrv3-tb 2>/dev/null || echo unknown)"

line="ts=${ts} load=${loadavg} mem_avail_mb=$((mem_avail_kb/1024)) swap_used_mb=$((swap_used_kb/1024)) cpu_pkg_c=${cpu_pkg} rapl_w=${rapl_w} disks=${disk_t} gpu=${gpu_t} zfs=${zpool_h} bios=${bios_ver}"

if [[ "$JSON" == true ]]; then
  python3 - <<PY
import json
print(json.dumps({
  "ts": "$ts",
  "load": "$loadavg",
  "mem_avail_mb": $((mem_avail_kb/1024)),
  "swap_used_mb": $((swap_used_kb/1024)),
  "cpu_pkg_c": None if "$cpu_pkg"=="null" else float("$cpu_pkg"),
  "rapl_w": None if "$rapl_w"=="null" else float("$rapl_w"),
  "disk_temps": "$disk_t",
  "gpu_temps": "$gpu_t",
  "zfs_health": "$zpool_h",
  "bios": "$bios_ver",
}))
PY
else
  echo "$line" | tee -a "$LOG"
fi
