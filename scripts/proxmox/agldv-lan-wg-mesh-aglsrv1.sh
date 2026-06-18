#!/usr/bin/env bash
# Peers WireGuard LAN bidireccionais entre AGLDV no AGLSRV1 (CT174/179/181/185).
# Mantém hub FGSRV6 e peers LAN existentes (CT120, dokploy, etc.).
#
# Uso no AGLSRV1 (root):
#   bash scripts/proxmox/agldv-lan-wg-mesh-aglsrv1.sh
#   bash scripts/proxmox/agldv-lan-wg-mesh-aglsrv1.sh --dry-run
#
# CT185 (clone agldv03): se partilhar chave/IP com CT179, regenera identidade em 10.6.0.26.

set -euo pipefail

DRY_RUN=0
HUB_PUB="Dj8XsoPeDlgnqA4Ox++yDy+t4xGxYtEevxQh513fSA8="
HUB_EP="186.202.57.120:51823"
FGSRV6_TS="root@100.83.51.9"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help)
      sed -n '2,12p' "$0"
      exit 0
      ;;
    *) echo "Opção desconhecida: $1" >&2; exit 1 ;;
  esac
done

log() { echo "[INFO] $*"; }
ok() { echo "[OK] $*"; }
warn() { echo "[WARN] $*"; }

run_in_ct() {
  local vmid="$1"
  shift
  if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "  [dry-run] pct exec $vmid -- bash -lc $(printf '%q' "$*")"
    return 0
  fi
  pct exec "$vmid" -- bash -lc "$*"
}

# vmid hostname wg_ip listen_port lan_ip
NODES=(
  "174|agldv02|10.6.0.25|51825|192.168.0.174"
  "179|agldv03|10.6.0.19|51819|192.168.0.179"
  "181|agldv04|10.6.0.24|51260|192.168.0.181"
  "185|agldv12|10.6.0.26|51826|192.168.0.185"
)

command -v pct >/dev/null || { echo "ERRO: executar no Proxmox AGLSRV1." >&2; exit 1; }

fix_ct185_identity() {
  log "=== CT185: identidade WG única (10.6.0.26) ==="
  local inner='
set -euo pipefail
MARK="# AGLDV mesh managed — agldv12 identity"
if grep -q "Address = 10.6.0.19/24" /etc/wireguard/wg0.conf 2>/dev/null; then
  umask 077
  mkdir -p /etc/wireguard
  wg genkey | tee /etc/wireguard/privatekey | wg pubkey > /etc/wireguard/publickey
  PRIV=$(cat /etc/wireguard/privatekey)
  PUB=$(cat /etc/wireguard/publickey)
  cp /etc/wireguard/wg0.conf "/etc/wireguard/wg0.conf.bak.$(date +%Y%m%d%H%M%S)"
  wg_conf=/etc/wireguard/wg0.conf
  sed -i "s|^Address = 10.6.0.19/24|Address = 10.6.0.26/24|" "${wg_conf}" \
    && grep -q "^Address = 10.6.0.26/24" "${wg_conf}" \
    || { echo "ERRO: Address 10.6.0.26 não aplicado em ${wg_conf}" >&2; exit 1; }
  sed -i "s|^ListenPort = 51819|ListenPort = 51826|" "${wg_conf}" \
    && grep -q "^ListenPort = 51826" "${wg_conf}" \
    || { echo "ERRO: ListenPort 51826 não aplicado em ${wg_conf}" >&2; exit 1; }
  sed -i "s|^PrivateKey = .*|PrivateKey = ${PRIV}|" "${wg_conf}" \
    && grep -qF "PrivateKey = ${PRIV}" "${wg_conf}" \
    || { echo "ERRO: PrivateKey não aplicado em ${wg_conf}" >&2; exit 1; }
  systemctl restart wg-quick@wg0
  sleep 2
  echo "NEW_PUB=${PUB}"
else
  wg show wg0 public-key
fi
'
  run_in_ct 185 "$inner"
}

collect_pubkey() {
  local vmid="$1"
  run_in_ct "$vmid" "wg show wg0 public-key 2>/dev/null || cat /etc/wireguard/publickey"
}

add_lan_peers_in_ct() {
  local vmid="$1"
  local self_pub="$2"
  shift 2
  local peers_script="# AGLDV LAN mesh (aglsrv1) — $(date -Iseconds)
"
  while [[ $# -gt 0 ]]; do
    local entry="$1"
    shift
    IFS='|' read -r _host _wgip _port _lan _pub <<<"$entry"
    [[ "$_pub" == "$self_pub" ]] && continue
    peers_script+="[Peer]
# ${_host}
PublicKey = ${_pub}
AllowedIPs = ${_wgip}/32
Endpoint = ${_lan}:${_port}
PersistentKeepalive = 25

"
  done

  local inner
  inner=$(cat <<INNER
set -euo pipefail
MARK="# AGLDV LAN mesh (aglsrv1)"
CONF=/etc/wireguard/wg0.conf
TMP=\$(mktemp)
if grep -q "\$MARK" "\$CONF" 2>/dev/null; then
  awk -v mark="\$MARK" 'BEGIN{p=1} \$0==mark{p=0} p{print}' "\$CONF" | sed '/^$/N;/^\n$/d' > "\$TMP"
else
  cp "\$CONF" "\$TMP"
fi
cat >> "\$TMP" <<'PEERS'
${peers_script}
PEERS
mv "\$TMP" "\$CONF"
chmod 600 "\$CONF"
wg syncconf wg0 <(wg-quick strip wg0)
echo SYNC_OK
INNER
)
  run_in_ct "$vmid" "$inner"
}

update_hub_peer() {
  local wg_ip="$1"
  local pubkey="$2"
  local host="$3"
  log "Hub: peer ${host} ${wg_ip} ${pubkey:0:20}..."
  if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "  [dry-run] wg set on FGSRV6"
    return 0
  fi
  ssh -o BatchMode=yes -o ConnectTimeout=20 "$FGSRV6_TS" "bash -lc '
set -euo pipefail
PUB=\"$pubkey\"
IP=\"$wg_ip\"
HOST=\"$host\"
# Remover peer duplicado com mesmo pubkey mas IP diferente
wg set wg0 peer \"\$PUB\" remove 2>/dev/null || true
wg set wg0 peer \"\$PUB\" allowed-ips \"\${IP}/32\" persistent-keepalive 25
if ! grep -q \"\$PUB\" /etc/wireguard/wg0.conf; then
  cat >> /etc/wireguard/wg0.conf <<EOF

# \${HOST} (AGLSRV1 agldv mesh)
[Peer]
PublicKey = \$PUB
AllowedIPs = \${IP}/32
PersistentKeepalive = 25
EOF
fi
'"
}

log "=== AGLDV LAN mesh AGLSRV1 ==="

fix_ct185_identity

declare -A PUBKEYS
for entry in "${NODES[@]}"; do
  IFS='|' read -r vmid host wgip port lan <<<"$entry"
  pct status "$vmid" >/dev/null 2>&1 || { warn "CT${vmid} inexistente"; continue; }
  if ! pct status "$vmid" | grep -q running; then
    pct start "$vmid"
    sleep 4
  fi
  PUBKEYS[$vmid]=$(collect_pubkey "$vmid" | tr -d '\r\n' | tail -1)
  ok "CT${vmid} ${host} ${wgip} ${PUBKEYS[$vmid]:0:16}..."
done

for entry in "${NODES[@]}"; do
  IFS='|' read -r vmid host wgip port lan <<<"$entry"
  self="${PUBKEYS[$vmid]:-}"
  [[ -z "$self" ]] && continue
  others=()
  for e2 in "${NODES[@]}"; do
    IFS='|' read -r v2 h2 ip2 p2 l2 <<<"$e2"
    pub2="${PUBKEYS[$v2]:-}"
    [[ -z "$pub2" ]] && continue
    others+=("${h2}|${ip2}|${p2}|${l2}|${pub2}")
  done
  log "CT${vmid} ${host}: aplicar peers LAN"
  add_lan_peers_in_ct "$vmid" "$self" "${others[@]}"
  update_hub_peer "$wgip" "$self" "$host"
done

log "=== Verificação ping mesh (CT179 -> outros) ==="
if [[ "$DRY_RUN" -eq 0 ]]; then
  for ip in 10.6.0.25 10.6.0.24 10.6.0.26; do
    pct exec 179 -- ping -c1 -W2 "$ip" >/dev/null && ok "CT179 ping $ip" || warn "CT179 ping $ip falhou"
  done
fi

ok "AGLDV LAN mesh concluído"
