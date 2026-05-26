#!/usr/bin/env bash
# Hardening CT244 fg-ngrok para exposição 24/7 ao partner (mysql7 + fg-legacy SSH).
# Executar no host FGSRV7 como root.
#
# NOTA: remote_addr só funciona com TCP addresses reservadas no dashboard ngrok.
# mysql7 reservado: 1.tcp.sa.ngrok.io:22485 → 192.168.70.135:3306
# fg-legacy-ssh reservado: 1.tcp.sa.ngrok.io:22488 → 192.168.70.243:22
# Sem reserva, NÃO reiniciar ngrok à toa — portas públicas podem mudar.
set -euo pipefail

CT_VMID="${CT_VMID:-244}"

if ! command -v pct >/dev/null 2>&1; then
  echo "pct não encontrado — correr no Proxmox FGSRV7." >&2
  exit 1
fi

log() { printf '[ngrok-hardening] %s\n' "$*"; }

log "Aplicar logrotate, systemd e timer de healthcheck no CT${CT_VMID} (sem reiniciar ngrok por defeito)…"

pct exec "${CT_VMID}" -- bash -s <<'REMOTE'
set -euo pipefail

if grep -q '^log_level: debug' /etc/ngrok/ngrok.yml 2>/dev/null; then
  sed -i 's/^log_level: debug/log_level: info/' /etc/ngrok/ngrok.yml
fi

cat > /etc/logrotate.d/ngrok <<'LOGROTATE'
/var/log/ngrok/ngrok.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    copytruncate
}
LOGROTATE

cat > /etc/systemd/system/ngrok-fg-partner.service <<'UNIT'
[Unit]
Description=ngrok partner access for mysql7 and fg-legacy
After=network-online.target
Wants=network-online.target
StartLimitIntervalSec=300
StartLimitBurst=10

[Service]
Type=simple
ExecStart=/usr/local/bin/ngrok start --all --config /etc/ngrok/ngrok.yml
Restart=always
RestartSec=5
User=root
NoNewPrivileges=true
ProtectSystem=full
ProtectHome=true
ReadWritePaths=/var/log/ngrok

[Install]
WantedBy=multi-user.target
UNIT

cat > /usr/local/bin/ngrok-partner-healthcheck <<'HC'
#!/usr/bin/env bash
set -euo pipefail
ENDPOINTS_FILE=/var/log/ngrok/endpoints.json
failures=0
log(){ printf '[ngrok-health] %s\n' "$*"; }
fail(){ log "FAIL: $*"; failures=$((failures+1)); }
ok(){ log "OK: $*"; }

systemctl is-active --quiet ngrok-fg-partner || fail "ngrok-fg-partner down"
for t in 192.168.70.135:3306 192.168.70.243:22; do
  h=${t%%:*}; p=${t##*:}
  nc -z -w3 "$h" "$p" >/dev/null 2>&1 && ok "upstream $t" || fail "upstream $t"
done
json=$(curl -sf http://127.0.0.1:4040/api/tunnels) || { fail "ngrok API down"; exit 1; }
mkdir -p /var/log/ngrok
echo "$json" > "$ENDPOINTS_FILE"
echo "$json" | python3 -c "
import json, sys
d = json.load(sys.stdin)
for name in ('mysql7', 'fg-legacy-ssh'):
    for t in d.get('tunnels', []):
        if t.get('name') == name:
            print(f\"{name}: {t.get('public_url','').replace('tcp://','')}\")
" > /var/log/ngrok/endpoints.txt
prev=/var/log/ngrok/endpoints.json.prev
if [[ -f "$prev" && "$(cat "$prev")" != "$json" ]]; then
  fail "endpoints mudaram — notificar partner"
fi
cp -f "$ENDPOINTS_FILE" "$prev"
exit $failures
HC
chmod +x /usr/local/bin/ngrok-partner-healthcheck

cat > /etc/systemd/system/ngrok-partner-healthcheck.timer <<'TIMER'
[Unit]
Description=Periodic ngrok partner tunnel healthcheck

[Timer]
OnBootSec=2min
OnUnitActiveSec=5min
Persistent=true

[Install]
WantedBy=timers.target
TIMER

cat > /etc/systemd/system/ngrok-partner-healthcheck.service <<'SVC'
[Unit]
Description=ngrok partner tunnel healthcheck

[Service]
Type=oneshot
ExecStart=/usr/local/bin/ngrok-partner-healthcheck
SVC

systemctl daemon-reload
systemctl enable ngrok-fg-partner.service ngrok-partner-healthcheck.timer
systemctl start ngrok-partner-healthcheck.timer
REMOTE

log "Concluído (ngrok não foi reiniciado). Endpoints actuais:"
pct exec "${CT_VMID}" -- curl -s http://127.0.0.1:4040/api/tunnels \
  | python3 -c "import json,sys; d=json.load(sys.stdin); [print(f\"  {t['name']}: {t['public_url']}\") for t in d.get('tunnels',[])]" 2>/dev/null || true
