#!/usr/bin/env bash
# Monta aglfs1 (AGLSRV1) no AGLSRV3 via Tailscale — NFS host + gateway Samba no CT338.
#
# Uso:
#   bash scripts/proxmox/aglsrv3-aglfs1-client-link.sh --dry-run
#   bash scripts/proxmox/aglsrv3-aglfs1-client-link.sh --apply
#   bash scripts/proxmox/aglsrv3-aglfs1-client-link.sh --apply --gateway-ct338
#   bash scripts/proxmox/aglsrv3-aglfs1-client-link.sh --apply --remote
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=aglsrv-vmid-map.env
source "${SCRIPT_DIR}/aglsrv-vmid-map.env"

AGLSRV3_SSH="${AGLSRV3_SSH:-root@100.123.5.81}"
AGLFS1_SERVER="${AGLFS1_TS_IP:-100.69.187.105}"
AGLFS3_VMID="${AGLSRV3_AGLFS3_VMID:-338}"
APPLY=false
REMOTE=false
GATEWAY_CT=false

MOUNTS=(
  "aglfs1-shares|/mnt/shares|/mnt/shares"
  "aglfs1-overpower|/mnt/overpower|/mnt/overpower"
  "aglfs1-power|/mnt/power|/mnt/power"
  "aglfs1-storage|/mnt/storage|/mnt/storage"
)

log() { echo "[$(date +%H:%M:%S)] $*"; }
die() { echo "ERRO: $*" >&2; exit 1; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --apply) APPLY=true; shift ;;
    --dry-run) APPLY=false; shift ;;
    --remote) REMOTE=true; shift ;;
    --gateway-ct338) GATEWAY_CT=true; shift ;;
    -h|--help)
      sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *) die "Opção desconhecida: $1" ;;
  esac
done

run_host() {
  if [[ "$REMOTE" == true ]]; then
    ssh -o BatchMode=yes "$AGLSRV3_SSH" "$@"
  else
    "$@"
  fi
}

add_pvesm_nfs() {
  local sid="$1" export_path="$2"
  local host_path="/mnt/pve/${sid}"

  if run_host grep -qE "^nfs: ${sid}$" /etc/pve/storage.cfg 2>/dev/null; then
    log "pvesm existe: ${sid}"
    run_host pvesm set "${sid}" --disable 0 2>/dev/null || true
    return 0
  fi

  if [[ "$APPLY" != true ]]; then
    log "DRY-RUN: pvesm add nfs ${sid} server=${AGLFS1_SERVER} export=${export_path}"
    return 0
  fi

  run_host mkdir -p "${host_path}"
  run_host pvesm add nfs "${sid}" \
    --server "${AGLFS1_SERVER}" \
    --export "${export_path}" \
    --path "${host_path}" \
    --content backup,iso,vztmpl,images,snippets \
    --options "nfsvers=3,nolock" \
    && log "NFS host: ${sid}" \
    || log "AVISO: pvesm add ${sid} falhou"
}

setup_ct338_gateway() {
  [[ "$GATEWAY_CT" == true ]] || return 0

  log "Gateway CT${AGLFS3_VMID}: mounts aglfs1 + Samba re-export"

  if [[ "$APPLY" != true ]]; then
    log "DRY-RUN: gateway CT338 fstab + smb shares aglfs1-*"
    return 0
  fi

  run_host pct exec "${AGLFS3_VMID}" -- env AGLFS1="${AGLFS1_SERVER}" bash -s <<'GATEWAY'
set -euo pipefail
sed -i '/\/mnt\/\/mnt\//d' /etc/fstab
for pair in shares:/mnt/shares overpower:/mnt/overpower power:/mnt/power storage:/mnt/storage; do
  sid="aglfs1-${pair%%:*}"
  remote="${pair#*:}"
  ct_mp="/mnt/${sid}"
  mkdir -p "${ct_mp}"
  grep -q "${AGLFS1}:${remote}" /etc/fstab || \
    echo "${AGLFS1}:${remote} ${ct_mp} nfs vers=3,nolock,hard,_netdev,rsize=1048576,wsize=1048576 0 0" >> /etc/fstab
  mountpoint -q "${ct_mp}" || mount "${ct_mp}"
done
for s in aglfs1-shares aglfs1-overpower aglfs1-power aglfs1-storage; do
  grep -qF "[${s}]" /etc/samba/smb.conf && continue
  mp="/mnt/${s}"
  {
    echo ""
    echo "[${s}]"
    echo "  path = ${mp}"
    echo "  browseable = yes"
    echo "  read only = no"
    echo "  guest ok = no"
    echo "  create mask = 0664"
    echo "  directory mask = 0775"
  } >> /etc/samba/smb.conf
done
systemctl reload smbd 2>/dev/null || systemctl restart smbd
GATEWAY
}

main() {
  log "AGLSRV3 ← aglfs1 @ ${AGLFS1_SERVER} (gateway_ct=${GATEWAY_CT})"

  if ! run_host ping -c1 -W4 "${AGLFS1_SERVER}" &>/dev/null; then
    die "Sem ping a aglfs1 ${AGLFS1_SERVER}"
  fi

  for entry in "${MOUNTS[@]}"; do
    local sid="${entry%%|*}"
    local export_path="${entry#*|}"; export_path="${export_path%%|*}"
    add_pvesm_nfs "${sid}" "${export_path}"
    if [[ "$APPLY" == true ]]; then
      run_host "mountpoint -q /mnt/pve/${sid} || pvesm scan nfs ${sid}" 2>/dev/null || true
    fi
  done

  setup_ct338_gateway

  if [[ "$APPLY" == true ]]; then
    log "=== pvesm aglfs1-* ==="
    run_host "pvesm status 2>/dev/null | grep aglfs1 || true"
  fi
}

if [[ "$REMOTE" == true && "$(hostname -s 2>/dev/null)" != "aglsrv3" ]]; then
  remote_args=""
  [[ "$APPLY" == true ]] && remote_args+=" --apply"
  [[ "$GATEWAY_CT" == true ]] && remote_args+=" --gateway-ct338"
  scp -q "${SCRIPT_DIR}/aglsrv3-aglfs1-client-link.sh" \
    "${SCRIPT_DIR}/aglsrv-vmid-map.env" \
    "${AGLSRV3_SSH}:/root/"
  ssh -o BatchMode=yes "$AGLSRV3_SSH" "bash /root/aglsrv3-aglfs1-client-link.sh${remote_args}"
else
  main
fi
