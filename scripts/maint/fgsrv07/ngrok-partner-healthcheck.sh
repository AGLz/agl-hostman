#!/usr/bin/env bash
# Verifica CT244 (fg-ngrok): serviço, upstreams e endpoints públicos do partner.
# Executar no host FGSRV7 como root: bash scripts/maint/fgsrv07/ngrok-partner-healthcheck.sh
set -euo pipefail

CT_VMID="${CT_VMID:-244}"
ENDPOINTS_FILE="${ENDPOINTS_FILE:-/var/log/ngrok/endpoints.json}"

failures=0

log() { printf '[ngrok-health] %s\n' "$*"; }
fail() { log "FAIL: $*"; failures=$((failures + 1)); }
ok() { log "OK: $*"; }

if ! command -v pct >/dev/null 2>&1; then
  echo "pct não encontrado — correr no Proxmox FGSRV7." >&2
  exit 1
fi

status="$(pct status "${CT_VMID}" 2>/dev/null | awk '{print $2}')"
if [[ "${status}" != "running" ]]; then
  fail "CT${CT_VMID} status=${status:-unknown}"
  exit 1
fi
ok "CT${CT_VMID} running"

if ! pct exec "${CT_VMID}" -- systemctl is-active --quiet ngrok-fg-partner; then
  fail "ngrok-fg-partner não está active"
else
  ok "ngrok-fg-partner active"
fi

for target in "192.168.70.235:3306" "192.168.70.243:22"; do
  host="${target%%:*}"
  port="${target##*:}"
  if pct exec "${CT_VMID}" -- bash -c "nc -z -w3 ${host} ${port}" >/dev/null 2>&1; then
    ok "upstream ${target}"
  else
    fail "upstream ${target} inacessível a partir do CT244"
  fi
done

tunnels_json="$(pct exec "${CT_VMID}" -- curl -sf http://127.0.0.1:4040/api/tunnels 2>/dev/null || true)"
if [[ -z "${tunnels_json}" ]]; then
  fail "API local ngrok (127.0.0.1:4040) não responde"
  exit 1
fi

pct exec "${CT_VMID}" -- bash -c "mkdir -p $(dirname "${ENDPOINTS_FILE}") && cat > ${ENDPOINTS_FILE}" <<<"${tunnels_json}"

mysql_url="$(echo "${tunnels_json}" | python3 -c "
import json,sys
d=json.load(sys.stdin)
for t in d.get('tunnels',[]):
    if t.get('name')=='mysql7':
        print(t.get('public_url','').replace('tcp://',''))
" 2>/dev/null || true)"

ssh_url="$(echo "${tunnels_json}" | python3 -c "
import json,sys
d=json.load(sys.stdin)
for t in d.get('tunnels',[]):
    if t.get('name')=='fg-legacy-ssh':
        print(t.get('public_url','').replace('tcp://',''))
" 2>/dev/null || true)"

if [[ -z "${mysql_url}" ]]; then
  fail "túnel mysql7 ausente na API"
else
  ok "mysql7 public=${mysql_url}"
fi

if [[ -z "${ssh_url}" ]]; then
  fail "túnel fg-legacy-ssh ausente na API"
else
  ok "fg-legacy-ssh public=${ssh_url}"
fi

prev_file="${ENDPOINTS_FILE}.prev"
if pct exec "${CT_VMID}" -- test -f "${prev_file}" 2>/dev/null; then
  prev_json="$(pct exec "${CT_VMID}" -- cat "${prev_file}" 2>/dev/null || true)"
  if [[ -n "${prev_json}" && "${prev_json}" != "${tunnels_json}" ]]; then
    fail "endpoints públicos mudaram desde a última verificação — avisar o partner"
    log "Anterior: $(echo "${prev_json}" | python3 -c "import json,sys; d=json.load(sys.stdin); print(', '.join(t.get('name','')+':'+t.get('public_url','') for t in d.get('tunnels',[])))" 2>/dev/null || echo '?')"
    log "Actual:   $(echo "${tunnels_json}" | python3 -c "import json,sys; d=json.load(sys.stdin); print(', '.join(t.get('name','')+':'+t.get('public_url','') for t in d.get('tunnels',[])))" 2>/dev/null || echo '?')"
  fi
fi

pct exec "${CT_VMID}" -- bash -c "cp -f ${ENDPOINTS_FILE} ${prev_file}" >/dev/null 2>&1 || true

pct exec "${CT_VMID}" -- bash -c "printf '%s\n%s\n' '${mysql_url}' '${ssh_url}' > /var/log/ngrok/endpoints.txt" 2>/dev/null || true

if (( failures > 0 )); then
  log "Resultado: ${failures} problema(s)"
  exit 1
fi

log "Resultado: tudo OK"
exit 0
