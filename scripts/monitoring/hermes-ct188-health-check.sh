#!/usr/bin/env bash
# Health check leve Hermes CT188 — sem LLM (evita rate limit / truncamento).
# Uso: hermes cron --no-agent --script hermes-ct188-health-check.sh
set -euo pipefail

DISK_WARN_PCT="${DISK_WARN_PCT:-85}"
DISK_URGENT_PCT="${DISK_URGENT_PCT:-92}"
ALERTS=()
LEVEL="ok"

disk_line="$(df -P / /opt/agl-hermes 2>/dev/null | tail -1)"
disk_pct="$(echo "${disk_line}" | awk '{print $5}' | tr -d '%')"
disk_avail="$(echo "${disk_line}" | awk '{print $4}')"
if [[ "${disk_pct}" -ge "${DISK_URGENT_PCT}" ]]; then
  ALERTS+=("DISCO URGENTE: ${disk_pct}% usado (${disk_avail}K livres)")
  LEVEL="urgent"
elif [[ "${disk_pct}" -ge "${DISK_WARN_PCT}" ]]; then
  ALERTS+=("Disco: ${disk_pct}% usado")
  LEVEL="heads_up"
fi

tmp_gb="$(du -sm /tmp 2>/dev/null | awk '{printf "%.1f", $1/1024}')"
if awk "BEGIN {exit !(${tmp_gb} > 2)}"; then
  ALERTS+=("/tmp no contentor: ${tmp_gb}GB — correr cleanup-hermes-disk-ct188.sh")
  [[ "${LEVEL}" == "ok" ]] && LEVEL="heads_up"
fi

down=()
for c in agl-hermes-jarvis agl-hermes-elon agl-hermes-satya agl-hermes-werner; do
  if ! docker inspect -f '{{.State.Health.Status}}' "${c}" 2>/dev/null | grep -q healthy; then
    if ! docker ps --format '{{.Names}}' | grep -qx "${c}"; then
      down+=("${c}")
    fi
  fi
done
if ((${#down[@]})); then
  ALERTS+=("Containers down: ${down[*]}")
  LEVEL="urgent"
fi

if ! curl -sf -m 8 http://127.0.0.1:8642/health >/dev/null 2>&1; then
  ALERTS+=("Jarvis gateway :8642 health FAIL")
  LEVEL="urgent"
fi

load="$(awk '{print $1}' /proc/loadavg)"
mem_avail="$(awk '/MemAvailable/ {printf "%.0f", $2/1024/1024}' /proc/meminfo 2>/dev/null || echo "?")"

if [[ "${LEVEL}" == "ok" ]]; then
  echo "✅ Hermes CT188 OK | disco ${disk_pct}% | load ${load} | RAM avail ${mem_avail}Gi | /tmp ${tmp_gb}GB"
  exit 0
fi

icon="⚠️"
[[ "${LEVEL}" == "urgent" ]] && icon="🔴"
{
  echo "${icon} Hermes Health (${LEVEL})"
  echo "Disco: ${disk_pct}% | load: ${load} | RAM avail: ${mem_avail}Gi"
  for a in "${ALERTS[@]}"; do echo "• ${a}"; done
} 
