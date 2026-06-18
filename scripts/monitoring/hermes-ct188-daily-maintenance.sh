#!/usr/bin/env bash
# Manutenção diária Hermes CT188 — sem LLM (stdout → Telegram).
set -euo pipefail

DATE="$(date '+%Y-%m-%d %H:%M %Z')"
ALERTS=()
LEVEL="ok"

disk_line="$(df -P / 2>/dev/null | tail -1)"
disk_pct="$(echo "${disk_line}" | awk '{print $5}' | tr -d '%')"
disk_avail="$(echo "${disk_line}" | awk '{print $4}')"
load="$(awk '{print $1}' /proc/loadavg)"
mem_avail="$(awk '/MemAvailable/ {printf "%.1f", $2/1024/1024}' /proc/meminfo 2>/dev/null || echo "?")"

if [[ "${disk_pct}" -ge 92 ]]; then
  ALERTS+=("Disco CRÍTICO: ${disk_pct}%")
  LEVEL="urgent"
elif [[ "${disk_pct}" -ge 85 ]]; then
  ALERTS+=("Disco alto: ${disk_pct}%")
  LEVEL="heads_up"
fi

if command -v docker >/dev/null 2>&1 && [[ -S /var/run/docker.sock ]]; then
  mapfile -t hermes_cts < <(docker ps --format '{{.Names}}\t{{.Status}}' 2>/dev/null | grep 'agl-hermes-' || true)
  if [[ "${#hermes_cts[@]}" -lt 4 ]]; then
    ALERTS+=("Gateways Hermes: ${#hermes_cts[@]}/4+ visíveis")
    LEVEL="urgent"
  fi
else
  hermes_cts=()
fi

if ! curl -sf -m 8 http://127.0.0.1:8642/health >/dev/null 2>&1; then
  ALERTS+=("Jarvis :8642 health FAIL")
  LEVEL="urgent"
fi

err_24h=0
if [[ -f /opt/data/logs/errors.log ]]; then
  err_24h="$(grep -c "$(date '+%Y-%m-%d')" /opt/data/logs/errors.log 2>/dev/null || echo 0)"
  cron_perm="$(grep -c 'jobs.json.*Permission denied' /opt/data/logs/errors.log 2>/dev/null | tail -1 || echo 0)"
  if [[ "${cron_perm}" -gt 50 ]]; then
    ALERTS+=("cron jobs.json: erros de permissão (${cron_perm} linhas) — correr fix-hermes-cron-perms-ct188.sh")
    [[ "${LEVEL}" == "ok" ]] && LEVEL="heads_up"
  fi
fi

litellm_ok="?"
for url in http://192.168.0.186:4000/health/liveliness http://100.125.249.8:4000/health/liveliness; do
  if curl -sf -m 6 "${url}" >/dev/null 2>&1; then
    litellm_ok="OK (${url#http://})"
    break
  fi
done
[[ "${litellm_ok}" == "?" ]] && ALERTS+=("LiteLLM inacessível") && LEVEL="urgent"

hermes_ver=""
if [[ -x /opt/hermes/.venv/bin/hermes ]]; then
  hermes_ver="$(/opt/hermes/.venv/bin/hermes --version 2>/dev/null | head -1 || true)"
fi

if [[ "${LEVEL}" == "ok" ]] && [[ "${err_24h}" -lt 200 ]]; then
  echo "✅ Manutenção Hermes CT188 (${DATE})"
  echo "Disco ${disk_pct}% | load ${load} | RAM ${mem_avail}Gi | LiteLLM ${litellm_ok}"
  echo "Erros hoje (errors.log): ${err_24h} | Hermes: ${hermes_ver:-n/d}"
  exit 0
fi

icon="⚠️"
[[ "${LEVEL}" == "urgent" ]] && icon="🔴"
{
  echo "${icon} Manutenção Hermes CT188 (${DATE})"
  echo "Disco: ${disk_pct}% (${disk_avail}K livres) | load: ${load} | RAM: ${mem_avail}Gi"
  echo "LiteLLM: ${litellm_ok} | Erros hoje: ${err_24h}"
  [[ -n "${hermes_ver}" ]] && echo "Hermes: ${hermes_ver}"
  if [[ "${#hermes_cts[@]}" -gt 0 ]]; then
    echo "Containers:"
    printf '  %s\n' "${hermes_cts[@]}"
  fi
  for a in "${ALERTS[@]}"; do echo "• ${a}"; done
}
