#!/usr/bin/env bash
# FGSRV04 — shutdown faseado antes do descomissionamento (vps22826)
#
# Uso:
#   bash fgsrv04-stop-services.sh --phase 1              # staging + NFS (seguro)
#   bash fgsrv04-stop-services.sh --phase 2              # auxiliares
#   bash fgsrv04-stop-services.sh --phase 3 --confirm-production  # nginx/php5 produção
#   bash fgsrv04-stop-services.sh --phase 4 --confirm-production  # VPN/agents
#   bash fgsrv04-stop-services.sh --dry-run --phase 1
#
# Ver: docs/maint/FGSRV04-DECOMMISSION-INVENTORY.md

set -euo pipefail

PHASE=""
DRY_RUN=false
CONFIRM_PRODUCTION=false

usage() {
  sed -n '3,10p' "$0" | tr -d '#'
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --phase) PHASE="${2:-}"; shift 2 ;;
    --dry-run) DRY_RUN=true; shift ;;
    --confirm-production) CONFIRM_PRODUCTION=true; shift ;;
    -h|--help) usage ;;
    *) echo "Argumento desconhecido: $1" >&2; usage ;;
  esac
done

[[ -n "$PHASE" ]] || usage

run() {
  if $DRY_RUN; then
    echo "[dry-run] $*"
  else
    echo "[exec] $*"
    "$@"
  fi
}

disable_nginx_site() {
  local site="$1"
  if [[ -f "/etc/nginx/sites-enabled/${site}" ]]; then
    run rm -f "/etc/nginx/sites-enabled/${site}"
    echo "Desactivado vhost: ${site}"
  else
    echo "Vhost já ausente: ${site}"
  fi
}

phase1() {
  echo "=== Fase 1: staging (fg_old2/3) + NFS ==="
  disable_nginx_site fg_old2
  disable_nginx_site fg_old3
  run nginx -t
  run systemctl reload nginx
  for unit in nfs-server nfs-kernel-server; do
    if systemctl is-active --quiet "$unit" 2>/dev/null; then
      run systemctl stop "$unit"
      run systemctl disable "$unit" 2>/dev/null || true
    fi
  done
  echo "Fase 1 concluída."
}

phase2() {
  echo "=== Fase 2: serviços auxiliares + desactivar auto-heal ==="
  if systemctl is-active --quiet php8.2-fpm 2>/dev/null; then
    run systemctl stop php8.2-fpm
    run systemctl disable php8.2-fpm 2>/dev/null || true
  fi
  if systemctl is-active --quiet docker 2>/dev/null; then
    run systemctl stop docker
  fi
  for f in /etc/cron.d/ssl-monitor /etc/cron.d/disk-monitor; do
    [[ -f "$f" ]] && run rm -f "$f"
  done
  # Crontab root com scripts /usr/local/bin/*monitor* — comentar entradas
  if crontab -l -u root 2>/dev/null | grep -q '/usr/local/bin/.*monitor'; then
    if ! $DRY_RUN; then
      crontab -l -u root | sed 's|^\([^#].*/usr/local/bin/.*monitor.*\)|# decommission \1|' | crontab -u root -
      echo "Crons de monitor comentados em root."
    else
      echo "[dry-run] Comentar crons monitor em root"
    fi
  fi
  # Impedir service-monitor de relançar nginx/php se alguém invocar manualmente
  for script in service-monitor.sh ssl-monitor.sh disk-monitor.sh performance-monitor.sh; do
    if [[ -x "/usr/local/bin/${script}" ]]; then
      run chmod -x "/usr/local/bin/${script}"
      run mv "/usr/local/bin/${script}" "/usr/local/bin/${script}.disabled-decommission"
      echo "Desactivado: ${script}"
    fi
  done
  echo "Fase 2 concluída."
}

phase3() {
  echo "=== Fase 3: stack web produção (fg_old) ==="
  if ! $CONFIRM_PRODUCTION; then
    echo "ERRO: cutover DNS deve estar concluído antes de parar produção neste host." >&2
    echo "Use --confirm-production após validar túnel fgsrv7b → CT549." >&2
    exit 2
  fi
  run systemctl stop nginx
  run systemctl stop php5.6-fpm
  run systemctl disable nginx php5.6-fpm 2>/dev/null || true
  # mask impede restart por monitor/cron até unmask manual
  run systemctl mask nginx php5.6-fpm
  echo "Fase 3 concluída — nginx/php5.6 masked (sem auto-restart)."
  echo "Marca de descomissionamento: $(date -Is)" | run tee /var/lib/fgsrv04-decommission.phase3
}

phase4() {
  echo "=== Fase 4: VPN e agentes ==="
  if ! $CONFIRM_PRODUCTION; then
    echo "ERRO: use --confirm-production para fase 4." >&2
    exit 2
  fi
  run systemctl stop tailscaled 2>/dev/null || true
  run systemctl stop wg-quick@wg0 2>/dev/null || true
  run systemctl stop zabbix-agent 2>/dev/null || true
  run systemctl stop meshagent 2>/dev/null || true
  run systemctl stop glances 2>/dev/null || true
  echo "Fase 4 concluída."
}

case "$PHASE" in
  1) phase1 ;;
  2) phase2 ;;
  3) phase3 ;;
  4) phase4 ;;
  *) echo "Fase inválida: $PHASE (use 1-4)" >&2; exit 1 ;;
esac
