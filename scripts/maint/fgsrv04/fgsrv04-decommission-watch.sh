#!/usr/bin/env bash
# Monitoriza FGSRV04 pós-descomissionamento — nginx/php5.6 devem permanecer parados/masked.
# Instalar cron no agldv03 (ex.: diário 08:05) por 1 semana após phase 3.
#
# Uso:
#   bash scripts/maint/fgsrv04/fgsrv04-decommission-watch.sh
#   bash scripts/maint/fgsrv04/fgsrv04-decommission-watch.sh --install-cron
set -euo pipefail

FGSRV04="${FGSRV04_SSH:-root@100.111.79.2}"
LOG="${FGSRV04_WATCH_LOG:-/var/log/fgsrv04-decommission-watch.log}"
INSTALL_CRON=0
[[ "${1:-}" == "--install-cron" ]] && INSTALL_CRON=1

check_remote() {
  ssh -o ConnectTimeout=15 -o BatchMode=yes "${FGSRV04}" bash -s <<'REMOTE'
nginx_state=$(systemctl is-active nginx 2>/dev/null || true)
php_state=$(systemctl is-active php5.6-fpm 2>/dev/null || true)
nginx_enabled=$(systemctl is-enabled nginx 2>/dev/null || true)
php_enabled=$(systemctl is-enabled php5.6-fpm 2>/dev/null || true)
monitor_active=0
for s in service-monitor.sh ssl-monitor.sh disk-monitor.sh performance-monitor.sh; do
  [[ -x "/usr/local/bin/${s}" ]] && monitor_active=1
done
printf 'nginx=%s php5.6=%s nginx_enabled=%s php_enabled=%s monitor_scripts=%s\n' \
  "${nginx_state:-unknown}" "${php_state:-unknown}" "${nginx_enabled:-unknown}" \
  "${php_enabled:-unknown}" "${monitor_active}"
REMOTE
}

line="$(date -Is) $(check_remote)"
mkdir -p "$(dirname "${LOG}")"
echo "${line}" >> "${LOG}"

if echo "${line}" | grep -qE 'nginx=active|php5\.6=active'; then
  echo "ALERTA: serviço de produção activo no FGSRV04 — ${line}" >&2
  exit 1
fi

echo "OK: ${line}"

if [[ "${INSTALL_CRON}" -eq 1 ]]; then
  SCRIPT="/mnt/overpower/apps/dev/agl/agl-hostman/scripts/maint/fgsrv04/fgsrv04-decommission-watch.sh"
  CRON_LINE="5 8 * * * ${SCRIPT} >> ${LOG} 2>&1"
  (crontab -l 2>/dev/null | grep -v 'fgsrv04-decommission-watch' || true; echo "${CRON_LINE}") | crontab -
  echo "Cron instalado: ${CRON_LINE}"
fi
