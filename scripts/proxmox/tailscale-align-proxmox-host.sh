#!/usr/bin/env bash
# Alinha Tailscale num host Proxmox AGL (man6 / man6c / man6d).
#
# Documentação: docs/troubleshooting/AGLSRV6-CLOUDFLARED6-ETH2-TAILSCALE-2026-06.md
# Parâmetros canónicos (docs/INFRA.md):
#   --accept-dns=false    — não sobrescrever resolv.conf
#   --accept-routes=false — não injectar subnets na table 52 via tailscale0
#   --ssh                 — Tailscale SSH (ACLs na consola)
#
# Opcional: agl-lan-routes.service força LAN local via interface física (vmbr0/enp*).
#
# Uso local no host:
#   LAN_IF=vmbr0 TS_HOSTNAME=aglsrv6c bash tailscale-align-proxmox-host.sh
#   LAN_IF=enp2s0 TS_HOSTNAME=aglsrv6d bash tailscale-align-proxmox-host.sh --check-only

set -euo pipefail

CHECK_ONLY=false
LAN_IF="${LAN_IF:-}"
TS_HOSTNAME="${TS_HOSTNAME:-}"
LAN_ROUTES_SRC="${LAN_ROUTES_SRC:-}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --check-only) CHECK_ONLY=true ;;
    --lan-if) LAN_IF="${2:?}"; shift ;;
    --hostname) TS_HOSTNAME="${2:?}"; shift ;;
    -h | --help)
      echo "Uso: LAN_IF=vmbr0 TS_HOSTNAME=aglsrv6c $0 [--check-only]" >&2
      exit 0
      ;;
    *)
      echo "Argumento desconhecido: $1" >&2
      exit 1
      ;;
  esac
  shift
done

if [[ -z "${LAN_ROUTES_SRC}" ]]; then
  REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
  LAN_ROUTES_SRC="${REPO_ROOT}/scripts/proxmox/agl-lan-routes.sh"
fi

if [[ -z "${LAN_IF}" ]]; then
  if ip -4 link show vmbr0 &>/dev/null; then
    LAN_IF="vmbr0"
  elif ip -4 route show default 2>/dev/null | grep -qE ' dev enp'; then
    LAN_IF="$(ip -4 route show default | awk '/ dev / { print $5; exit }')"
  else
    LAN_IF="eth0"
  fi
fi

ts_prefs() {
  tailscale debug prefs 2>/dev/null | grep -iE 'RouteAll|CorpDNS|RunSSH|Hostname' | tr '\n' ' '
}

ts_bad_table52() {
  ip route show table 52 2>/dev/null | grep -E '192\.168\.0\.0/24.*tailscale0|10\.6\.0\.0/24.*tailscale0' || true
}

echo "=== Host $(hostname) LAN_IF=${LAN_IF} ==="
echo "  prefs (antes): $(ts_prefs)"
bad="$(ts_bad_table52)"
[[ -n "${bad}" ]] && echo "  PROBLEMA table52 (antes): ${bad}"

if [[ "${CHECK_ONLY}" == "true" ]]; then
  exit 0
fi

tailscale set --accept-dns=false --accept-routes=false

if [[ -n "${TS_HOSTNAME}" ]]; then
  if ! tailscale debug prefs 2>/dev/null | grep -q '"RunSSH": true'; then
    tailscale up \
      --hostname="${TS_HOSTNAME}" \
      --accept-dns=false \
      --accept-routes=false \
      --ssh \
      --accept-risk=lose-ssh
  fi
fi

echo "  prefs (depois): $(ts_prefs)"
bad="$(ts_bad_table52)"
[[ -n "${bad}" ]] && echo "  AVISO table52 ainda: ${bad}"

if [[ ! -f "${LAN_ROUTES_SRC}" ]]; then
  echo "  SKIP agl-lan-routes: ${LAN_ROUTES_SRC} não encontrado"
else
  install -m 0755 "${LAN_ROUTES_SRC}" /usr/local/sbin/agl-lan-routes.sh

  lan1_extra=""
  if ! ip -4 addr show 2>/dev/null | grep -qE 'inet 192\.168\.1\.[0-9]+/'; then
    lan1_extra=$'192.168.1.202\n192.168.1.233'
  fi

  cat >/etc/agl-lan-routes.conf <<EOF
192.168.0.1
192.168.0.202
192.168.0.233
192.168.0.234
192.168.0.117
${lan1_extra}
EOF

  cat >/etc/systemd/system/agl-lan-routes.service <<UNIT
[Unit]
Description=AGL LAN routes (Tailscale table 52 → ${LAN_IF})
After=tailscaled.service network-online.target
Wants=network-online.target

[Service]
Type=oneshot
RemainAfterExit=yes
Environment=LAN_IF=${LAN_IF}
ExecStart=/usr/local/sbin/agl-lan-routes.sh

[Install]
WantedBy=multi-user.target
UNIT

  systemctl daemon-reload
  systemctl enable --now agl-lan-routes.service
  LAN_IF="${LAN_IF}" /usr/local/sbin/agl-lan-routes.sh
  echo "  OK: agl-lan-routes.service (LAN_IF=${LAN_IF})"
fi

if ip link show wg0 &>/dev/null; then
  if ip route show table 52 2>/dev/null | grep -qE '10\.6\.0\.0/24.*tailscale0'; then
    ip route replace 10.6.0.0/24 dev wg0 table 52 2>/dev/null || true
    echo "  OK: 10.6.0.0/24 forçado via wg0 na table 52"
  fi
fi

echo ""
echo "Verificação:"
ping -c 1 -W 2 192.168.0.1 >/dev/null 2>&1 && echo "  ping gateway 192.168.0.1: OK" || echo "  ping gateway 192.168.0.1: FAIL"
if ip -4 addr show | grep -q '192.168.1.'; then
  ping -c 1 -W 2 192.168.1.202 >/dev/null 2>&1 && echo "  ping man6 192.168.1.202: OK" || echo "  ping man6 192.168.1.202: FAIL"
fi
if ip link show wg0 &>/dev/null; then
  ping -c 1 -W 2 10.6.0.12 >/dev/null 2>&1 && echo "  ping man6 wg 10.6.0.12: OK" || echo "  ping man6 wg 10.6.0.12: FAIL"
fi

echo ""
echo "Concluído."
