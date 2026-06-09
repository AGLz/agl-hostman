#!/usr/bin/env bash
# Alinha Tailscale no host AGLSRV6 (man6) e CTs com LAN local.
#
# Documentação: docs/troubleshooting/AGLSRV6-CLOUDFLARED6-ETH2-TAILSCALE-2026-06.md
# Parâmetros canónicos (docs/INFRA.md, docs/troubleshooting/CT181-DNS-ROUTING-FIX.md):
#   --accept-dns=false   — não sobrescrever resolv.conf com MagicDNS
#   --accept-routes=false — não injectar 192.168.0.0/24 na table 52 via tailscale0
#   --ssh                — Tailscale SSH (ACLs na consola)
#
# CTs com eth0 em 192.168.0.x também recebem agl-lan-routes.service (fallback table 52).
#
# Uso (no host AGLSRV6):
#   bash scripts/proxmox/pct-tailscale-align-aglsrv6.sh
#   bash scripts/proxmox/pct-tailscale-align-aglsrv6.sh --check-only

set -euo pipefail

CHECK_ONLY=false
for arg in "$@"; do
  case "$arg" in
    --check-only) CHECK_ONLY=true ;;
    -h | --help)
      echo "Uso: $0 [--check-only]" >&2
      exit 0
      ;;
    *)
      echo "Argumento desconhecido: $arg" >&2
      exit 1
      ;;
  esac
done

command -v pct >/dev/null || {
  echo "ERRO: executar no Proxmox AGLSRV6 (pct)." >&2
  exit 1
}

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LAN_ROUTES_SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/agl-lan-routes.sh"
if [[ ! -f "${LAN_ROUTES_SRC}" ]]; then
  LAN_ROUTES_SRC="${REPO_ROOT}/scripts/proxmox/agl-lan-routes.sh"
fi

# CTs AGLSRV6 com tailscaled (vmid:hostname TS documentado)
declare -A TS_CT_HOSTS=(
  [101]="aglsrv6-cloudflared6"
  [108]="aglsrv6-agldv06"
  [110]="aglsrv6-mssql6"
  [111]="aglsrv6-aluzdivina"
  [113]="aglsrv6-pbs"
  [114]="aglsrv6-cloudflared6b"
  [121]="aglsrv6-wireguard"
)

# CTs na LAN 192.168.0.x — instalar agl-lan-routes
LAN_ROUTE_VMIDS=(101 108 110 111 113 114 121)

ts_prefs() {
  tailscale debug prefs 2>/dev/null | grep -iE 'RouteAll|CorpDNS|RunSSH' | tr '\n' ' '
}

ts_bad_table52() {
  ip route show table 52 2>/dev/null | grep -E '192\.168\.0\.0/24.*tailscale0' || true
}

apply_host() {
  echo "=== Host $(hostname) (aglsrv6) ==="
  if [[ "${CHECK_ONLY}" == "true" ]]; then
    echo "  prefs: $(ts_prefs)"
    local bad
    bad="$(ts_bad_table52)"
    if [[ -n "${bad}" ]]; then
      echo "  PROBLEMA table52: ${bad}"
    fi
    return 0
  fi
  tailscale set --accept-dns=false --accept-routes=false
  systemctl is-active tailscaled >/dev/null && true
  echo "  OK: accept-dns=false accept-routes=false (advertise-routes mantidas)"
  echo "  prefs: $(ts_prefs)"
}

apply_ct() {
  local vmid="$1"
  local ts_host="${TS_CT_HOSTS[${vmid}]:-}"

  if ! pct status "${vmid}" 2>/dev/null | grep -q running; then
    echo "=== CT${vmid}: SKIP (não running) ==="
    return 0
  fi
  if ! pct exec "${vmid}" -- which tailscale >/dev/null 2>&1; then
    echo "=== CT${vmid}: SKIP (sem tailscale) ==="
    return 0
  fi

  echo "=== CT${vmid} (${ts_host:-?}) ==="
  if [[ "${CHECK_ONLY}" == "true" ]]; then
    pct exec "${vmid}" -- bash -c "$(declare -f ts_prefs ts_bad_table52); ts_prefs; bad=\$(ts_bad_table52); [[ -n \"\$bad\" ]] && echo \"PROBLEMA table52: \$bad\""
    return 0
  fi

  pct exec "${vmid}" -- tailscale set --accept-routes=false --accept-dns=false

  if ! pct exec "${vmid}" -- tailscale debug prefs 2>/dev/null | grep -q '"RunSSH": true'; then
    if [[ -n "${ts_host}" ]]; then
      pct exec "${vmid}" -- tailscale up \
        --hostname="${ts_host}" \
        --accept-dns=false \
        --accept-routes=false \
        --ssh \
        --accept-risk=lose-ssh
    else
      pct exec "${vmid}" -- tailscale up \
        --accept-dns=false \
        --accept-routes=false \
        --ssh \
        --accept-risk=lose-ssh
    fi
  fi

  echo "  prefs: $(pct exec "${vmid}" -- tailscale debug prefs 2>/dev/null | grep -iE 'RouteAll|CorpDNS|RunSSH' | tr '\n' ' ')"
  local bad
  bad="$(pct exec "${vmid}" -- ip route show table 52 2>/dev/null | grep '192.168.0.0/24.*tailscale0' || true)"
  if [[ -n "${bad}" ]]; then
    echo "  AVISO table52 ainda: ${bad} — a correr agl-lan-routes"
  fi
}

install_lan_routes() {
  local vmid="$1"
  [[ "${CHECK_ONLY}" == "true" ]] && return 0
  [[ -f "${LAN_ROUTES_SRC}" ]] || {
    echo "  SKIP agl-lan-routes: ${LAN_ROUTES_SRC} não encontrado no host"
    return 0
  }

  pct push "${vmid}" "${LAN_ROUTES_SRC}" /usr/local/sbin/agl-lan-routes.sh
  pct exec "${vmid}" -- chmod 0755 /usr/local/sbin/agl-lan-routes.sh
  # 192.168.1.x só via eth0/table52 se o CT não tiver NIC local em 192.168.1.0/24 (ex. eth2/vmbr2).
  local lan1_extra=""
  if ! pct exec "${vmid}" -- ip -4 addr show 2>/dev/null | grep -qE 'inet 192\.168\.1\.[0-9]+/'; then
    lan1_extra=$'192.168.1.202\n192.168.1.233'
  fi
  pct exec "${vmid}" -- bash -c "cat >/etc/agl-lan-routes.conf <<EOF
192.168.0.1
192.168.0.202
192.168.0.233
192.168.0.234
192.168.0.117
${lan1_extra}
EOF"
  pct exec "${vmid}" -- bash -c 'cat >/etc/systemd/system/agl-lan-routes.service <<'\''UNIT'\''
[Unit]
Description=AGL LAN routes (Tailscale table 52 → eth0)
After=tailscaled.service network-online.target
Wants=network-online.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/local/sbin/agl-lan-routes.sh

[Install]
WantedBy=multi-user.target
UNIT'
  pct exec "${vmid}" -- systemctl daemon-reload
  pct exec "${vmid}" -- systemctl enable --now agl-lan-routes.service
  pct exec "${vmid}" -- /usr/local/sbin/agl-lan-routes.sh
  echo "  OK: agl-lan-routes.service"
}

apply_host

for vmid in $(printf '%s\n' "${!TS_CT_HOSTS[@]}" | sort -n); do
  apply_ct "${vmid}"
done

if [[ "${CHECK_ONLY}" == "false" ]]; then
  echo ""
  echo "=== agl-lan-routes.service ==="
  for vmid in "${LAN_ROUTE_VMIDS[@]}"; do
    echo "--- CT${vmid} ---"
    install_lan_routes "${vmid}"
  done
fi

echo ""
echo "Verificação rápida (CT101 → LAN man6):"
if pct status 101 2>/dev/null | grep -q running; then
  pct exec 101 -- ping -I eth0 -c 1 -W 2 192.168.0.202 >/dev/null 2>&1 \
    && echo "  ping 192.168.0.202 via eth0: OK" \
    || echo "  ping 192.168.0.202 via eth0: FAIL"
  if pct exec 101 -- ip route show table 52 2>/dev/null | grep -q '192.168.0.0/24.*tailscale0'; then
    echo "  table52 192.168.0.0/24 via tailscale0: AINDA PRESENTE"
  else
    echo "  table52 192.168.0.0/24 via tailscale0: ausente (OK)"
  fi
fi

echo ""
echo "Concluído."
