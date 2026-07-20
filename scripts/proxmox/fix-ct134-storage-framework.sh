#!/usr/bin/env bash
# Reason: garantir dirs storage Laravel no volume Docker CT134 (evita 500 Blade cache)
set -euo pipefail

CT="${CT134_VMID:-134}"
PROXMOX_HOST="${PROXMOX_HOST:-100.107.113.33}"

ssh -o ConnectTimeout=10 "root@${PROXMOX_HOST}" "pct exec ${CT} -- docker exec -u root agl-hostman-prod-app sh -c '
  rm -rf \"/var/www/html/storage/framework/{cache,sessions,views,testing}\"
  mkdir -p /var/www/html/storage/framework/cache/data \
    /var/www/html/storage/framework/sessions \
    /var/www/html/storage/framework/views \
    /var/www/html/storage/framework/testing \
    /var/www/html/storage/logs
  chown -R laravel:www-data /var/www/html/storage/framework /var/www/html/storage/logs
  chmod -R ug+rwx /var/www/html/storage/framework /var/www/html/storage/logs
  curl -sS -o /dev/null -w \"root=%{http_code}\\n\" http://127.0.0.1/
  curl -sS http://127.0.0.1/health/; echo
'"
