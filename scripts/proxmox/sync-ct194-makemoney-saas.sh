#!/usr/bin/env bash
# sync-ct194-makemoney-saas.sh — nginx path /s/, PHP 8.4, systemd todos os nichos
# Uso (agldv12): bash agl-hostman/scripts/proxmox/sync-ct194-makemoney-saas.sh
set -euo pipefail

VMID="${MAKEMONEY_CT_VMID:-194}"
PVE_HOST="${MAKEMONEY_PVE_HOST:-aglsrv1}"
AGL_ROOT="${AGL_ROOT:-/mnt/overpower/apps/dev/agl}"
HOSTMAN="${AGL_ROOT}/agl-hostman"
MM="${AGL_ROOT}/makemoney01"

pct() {
  ssh -o BatchMode=yes "root@${PVE_HOST}" "pct exec ${VMID} -- bash -lc $(printf '%q' "$1")"
}

echo "==> CT${VMID} via ${PVE_HOST}: PHP 8.4 (se necessário)"
pct '
set -e
if ! command -v php8.4 >/dev/null 2>&1; then
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -qq
  apt-get install -y -qq ca-certificates curl lsb-release apt-transport-https gnupg
  curl -sSLo /tmp/debsury.gpg https://packages.sury.org/php/apt.gpg
  gpg --dearmor -o /usr/share/keyrings/deb.sury.org-php.gpg /tmp/debsury.gpg
  echo "deb [signed-by=/usr/share/keyrings/deb.sury.org-php.gpg] https://packages.sury.org/php/ $(lsb_release -sc) main" \
    > /etc/apt/sources.list.d/php-sury.list
  apt-get update -qq
  apt-get install -y -qq php8.4-cli php8.4-mbstring php8.4-xml php8.4-sqlite3 php8.4-curl php8.4-zip php8.4-bcmath \
    || apt-get install -y -qq -f
fi
php8.4 -v | head -1
'

echo "==> nginx configs (mm01 path-based SaaS — 12 nichos)"
pct "
set -e
for f in mm01-landing.conf demo-gateway.conf assistencia-saas.conf; do
  src='${HOSTMAN}/config/nginx/makemoney01-ct/'\"\$f\"
  if [ -f \"\$src\" ]; then
    cp \"\$src\" /etc/nginx/sites-available/
    ln -sf /etc/nginx/sites-available/\"\$f\" /etc/nginx/sites-enabled/
  fi
done
nginx -t
systemctl reload nginx
"

echo "==> systemd units (SaaS + lead_reply + 12 nichos)"
pct "
set -e
for u in makemoney-lead-reply-api makemoney-whatsapp-webhook; do
  cp '${HOSTMAN}/config/systemd/makemoney01-ct/'\"\${u}\".service /etc/systemd/system/
done
for u in '${HOSTMAN}'/config/systemd/makemoney01-ct/makemoney-*.service; do
  cp \"\$u\" /etc/systemd/system/
done
systemctl daemon-reload
systemctl enable makemoney-lead-reply-api makemoney-whatsapp-webhook
for u in /etc/systemd/system/makemoney-*.service; do
  systemctl enable \"\$(basename \"\$u\" .service)\"
done
mkdir -p /etc/makemoney
if [ ! -f /etc/makemoney/whatsapp-webhook.env ]; then
  secret=\$(python3 -c 'import secrets; print(secrets.token_urlsafe(32))')
  printf 'MAKEMONEY_WHATSAPP_WEBHOOK_SECRET=%s\n' \"\$secret\" > /etc/makemoney/whatsapp-webhook.env
  chmod 640 /etc/makemoney/whatsapp-webhook.env
  chown root:nogroup /etc/makemoney/whatsapp-webhook.env
  echo \"criado /etc/makemoney/whatsapp-webhook.env\"
fi
"

echo "==> Laravel local data (/var/lib — NFS read-only no CT)"
pct "
set -e
init_local_app() {
  local name=\"\$1\"
  local seeder=\"\${2:-}\"
  local local=\"/var/lib/makemoney/\${name}\"
  local src='${AGL_ROOT}/'\"\${name}\"/src
  [ -d \"\${src}\" ] || return 0
  [ -f \"\${src}/artisan\" ] || return 0
  mkdir -p \"\${local}/storage/framework/cache/data\" \"\${local}/storage/framework/sessions\"
  mkdir -p \"\${local}/storage/framework/views\" \"\${local}/storage/logs\" \"\${local}/tmp\"
  chown -R nobody:nogroup \"\${local}\"
  chmod -R u+rwX,g+rwX \"\${local}\"
  export MAKEMONEY_ROOT='${MM}'
  export DB_CONNECTION=sqlite
  export DB_DATABASE=\"\${local}/database.sqlite\"
  export LARAVEL_STORAGE_PATH=\"\${local}/storage\"
  export TMPDIR=\"\${local}/tmp\"
  cd \"\${src}\"
  if [ ! -f \"\${local}/database.sqlite\" ]; then
    php8.4 artisan migrate --force --no-interaction
    if [ -n \"\${seeder}\" ]; then
      php8.4 artisan db:seed --class=\"\${seeder}\" --force --no-interaction
    fi
  else
    php8.4 artisan migrate --force --no-interaction 2>/dev/null || true
  fi
  chown -R nobody:nogroup \"\${local}\"
  chmod -R u+rwX,g+rwX \"\${local}\"
}
init_local_app erp-assistencia AssistenciaPilotSeeder
init_local_app crm-imobiliaria ImobiliariaPilotSeeder
for app in crm-clinica crm-dentista erp-padaria crm-beleza erp-estacionamento erp-supermercado crm-academia erp-restaurante erp-farmacia; do
  init_local_app \"\$app\"
done
if command -v npm >/dev/null 2>&1; then
  cd '${AGL_ROOT}/crm-imobiliaria/src' && npm ci --ignore-scripts 2>/dev/null || npm install --ignore-scripts
  npm run build
fi
python3 '${MM}/scripts/sync_mm01_landing.py'
"

echo "==> restart services"
pct "
set -e
systemctl restart makemoney-lead-reply-api makemoney-whatsapp-webhook
for u in /etc/systemd/system/makemoney-*.service; do
  base=\$(basename \"\$u\" .service)
  case \"\$base\" in
    makemoney-lead-reply-api|makemoney-whatsapp-webhook) continue ;;
  esac
  systemctl restart \"\$base\"
done
sleep 8
systemctl is-active makemoney-lead-reply-api makemoney-whatsapp-webhook nginx
for u in /etc/systemd/system/makemoney-*.service; do
  base=\$(basename \"\$u\" .service)
  case \"\$base\" in
    makemoney-lead-reply-api|makemoney-whatsapp-webhook) continue ;;
  esac
  systemctl is-active \"\$base\" || echo \"WARN inactive: \$base\"
done
curl -sf -o /dev/null -w 'lead_reply:%{http_code}\n' -X POST http://127.0.0.1:8765/reply \
  -H 'Content-Type: application/json' \
  -d '{\"client\":\"demo-assistencia\",\"message\":\"ping\"}' || echo lead_reply:fail
secret=\$(grep -E '^MAKEMONEY_WHATSAPP_WEBHOOK_SECRET=' /etc/makemoney/whatsapp-webhook.env | cut -d= -f2-)
curl -sf -o /dev/null -w 'whatsapp_webhook:%{http_code}\n' -X POST http://127.0.0.1:8766/webhook/whatsapp \
  -H \"Content-Type: application/json\" -H \"X-Webhook-Secret: \${secret}\" \
  -d '{\"instance_id\":\"demo-imobiliaria\",\"from\":\"5511999999999\",\"message\":\"ping\"}' || echo whatsapp_webhook:fail
check() {
  local label=\"\$1\" port=\"\$2\" path=\"\${3:-/}\"
  curl -sf -o /dev/null -w \"\${label}:%{http_code}\n\" \"http://127.0.0.1:\${port}\${path}\" || echo \"\${label}:fail\"
}
check assistencia 8105 /login
check imobiliaria 8101 /login
check clinica 8102 /
check dentista 8103 /
check padaria 8104 /
check beleza 8106 /
check pme_finance 8107 /
check estacionamento 8108 /
check supermercado 8109 /
check academia 8110 /
check restaurante 8111 /
check farmacia 8112 /
curl -sf -o /dev/null -w 'mm01_s_assist:%{http_code}\n' http://127.0.0.1/s/assistencia/login -H 'Host: mm01.aglz.io' || echo mm01_s_assist:fail
curl -sf -o /dev/null -w 'mm01_s_imob:%{http_code}\n' http://127.0.0.1/s/imobiliaria/login -H 'Host: mm01.aglz.io' || echo mm01_s_imob:fail
curl -sf -o /dev/null -w 'mm01_s_clinica:%{http_code}\n' http://127.0.0.1/s/clinica/ -H 'Host: mm01.aglz.io' || echo mm01_s_clinica:fail
curl -sf -o /dev/null -w 'mm01_s_pme:%{http_code}\n' http://127.0.0.1/s/pme-finance/ -H 'Host: mm01.aglz.io' || echo mm01_s_pme:fail
"

echo "OK sync CT${VMID} SaaS (12 nichos)"
