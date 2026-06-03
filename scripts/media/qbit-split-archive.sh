#!/usr/bin/env bash
# CT121 qBittorrent: inventário, clone arquivo, limpeza produção.
#
# Uso:
#   bash scripts/media/qbit-split-archive.sh inventory
#   bash scripts/media/qbit-split-archive.sh snapshot [--apply]
#   bash scripts/media/qbit-split-archive.sh clone --archive-vmid 221 --archive-ip 192.168.0.221/24 [--apply]
#   bash scripts/media/qbit-split-archive.sh clean-production [--apply]
#
# Sem --apply: dry-run (excepto inventory).

set -euo pipefail

AGLSRV1="${AGLSRV1:-root@100.107.113.33}"
PROD_VMID=121
ARCHIVE_VMID=""
ARCHIVE_IP=""
APPLY=false
CMD="${1:-}"

shift || true
while [[ $# -gt 0 ]]; do
  case "$1" in
    --apply) APPLY=true ;;
    --archive-vmid) ARCHIVE_VMID="$2"; shift ;;
    --archive-ip) ARCHIVE_IP="$2"; shift ;;
    *) echo "Argumento desconhecido: $1" >&2; exit 1 ;;
  esac
  shift
done

run() { ssh -o ConnectTimeout=15 -o BatchMode=yes "$AGLSRV1" "$@"; }

inventory() {
  echo "=== Inventário CT${PROD_VMID} (leitura) ==="
  run "pct config ${PROD_VMID} | grep -E '^(hostname|memory|rootfs|mp0|net0)'"
  run "pct exec ${PROD_VMID} -- bash -c '
    echo BT_backup: \$(find /.config/qBittorrent/BT_backup -maxdepth 1 -type f 2>/dev/null | wc -l) ficheiros
    du -sh /.config/qBittorrent/BT_backup /.config/qBittorrent 2>/dev/null
    systemctl is-active qbittorrent-nox 2>/dev/null || systemctl is-active qbittorrent 2>/dev/null || true
  '"
  echo ""
  echo "Nota: API torrents/info completa ~225MB com esta sessão — clone+limpeza recomendado."
}

snapshot() {
  local snap="pre-qbit-split-$(date +%Y%m%d)"
  local zfs_ds="rpool/data/subvol-${PROD_VMID}-disk-0"
  if [[ "$APPLY" != true ]]; then
    echo "Dry-run: zfs snapshot ${zfs_ds}@${snap} (pct snapshot LXC indisponível neste host)"
    return 0
  fi
  echo "A criar ZFS snapshot ${zfs_ds}@${snap}..."
  if run "pct snapshot ${PROD_VMID} ${snap}" 2>/dev/null; then
    echo "OK: pct snapshot ${snap}"
    return 0
  fi
  run "zfs snapshot ${zfs_ds}@${snap}"
  echo "OK: zfs snapshot ${zfs_ds}@${snap}"
}

clone_ct() {
  if [[ -z "$ARCHIVE_VMID" || -z "$ARCHIVE_IP" ]]; then
    echo "Obrigatório: --archive-vmid e --archive-ip (ex. 221 e 192.168.0.221/24)" >&2
    exit 1
  fi
  if run "pct status ${ARCHIVE_VMID}" 2>/dev/null | grep -q running; then
    echo "CT${ARCHIVE_VMID} já existe" >&2
    exit 1
  fi
  if [[ "$APPLY" != true ]]; then
    echo "Dry-run:"
    echo "  pct clone ${PROD_VMID} ${ARCHIVE_VMID} --hostname qbittorrent-archive --full"
    echo "  pct set ${ARCHIVE_VMID} -net0 name=eth0,bridge=vmbr0,gw=192.168.0.1,ip=${ARCHIVE_IP},type=veth"
    echo "  pct set ${ARCHIVE_VMID} -description 'Arquivo qBit legado (clone CT121). Manter parado.'"
    echo "  (CT${PROD_VMID} produção inalterado até clean-production)"
    return 0
  fi
  snapshot
  echo "A clonar CT${PROD_VMID} → CT${ARCHIVE_VMID} (zfs clone + config; bind mp0 não suporta pct clone)..."
  run "bash -s" "${PROD_VMID}" "${ARCHIVE_VMID}" "${ARCHIVE_IP}" <<'CLONE'
set -euo pipefail
SRC="$1"
DST="$2"
ARCHIVE_IP="$3"
SNAP="pre-qbit-split-$(date +%Y%m%d)"
ZFS_SRC="rpool/data/subvol-${SRC}-disk-0"
ZFS_DST="rpool/data/subvol-${DST}-disk-0"
if zfs list "$ZFS_DST" &>/dev/null; then
  echo "ZFS ${ZFS_DST} já existe"
else
  zfs clone "${ZFS_SRC}@${SNAP}" "$ZFS_DST" 2>/dev/null || zfs clone "${ZFS_SRC}@$(zfs list -t snapshot -o name -s creation -H "${ZFS_SRC}" | tail -1 | cut -d@ -f2)" "$ZFS_DST"
fi
if [[ -f "/etc/pve/lxc/${DST}.conf" ]]; then
  echo "Config CT${DST} já existe"
else
  cp "/etc/pve/lxc/${SRC}.conf" "/etc/pve/lxc/${DST}.conf"
  sed -i \
    -e "s/subvol-${SRC}-disk-0/subvol-${DST}-disk-0/" \
    -e "s/^hostname: qbittorrent$/hostname: qbittorrent-archive/" \
    -e "s/ip=192.168.0.${SRC}\\/24/ip=${ARCHIVE_IP}/" \
    -e "s/^onboot: 1$/onboot: 0/" \
    "/etc/pve/lxc/${DST}.conf"
  printf '\n# Arquivo qBit legado (clone CT%s). Manter parado; nao usar nos arr.\n' "$SRC" >>"/etc/pve/lxc/${DST}.conf"
fi
pct config "$DST" | grep -E '^(hostname|rootfs|net0|onboot|mp0)'
CLONE
  echo "Clone criado. CT${ARCHIVE_VMID} fica **parado**. Validar antes de clean-production:"
  echo "  ssh ${AGLSRV1} 'pct start ${ARCHIVE_VMID}'  # só para inspeção WebUI"
  echo "  ssh ${AGLSRV1} 'pct stop ${ARCHIVE_VMID}'"
}

clean_production() {
  local stamp
  stamp="$(date +%Y%m%d-%H%M%S)"
  if [[ "$APPLY" != true ]]; then
    echo "Dry-run clean-production CT${PROD_VMID}:"
    echo "  - parar qbittorrent"
    echo "  - mv BT_backup → BT_backup.archive-${stamp}"
    echo "  - mkdir BT_backup vazio; arrancar serviço"
    echo "  - cópia opcional para /mnt/overpower/qbit-legacy/BT_backup.archive-${stamp}"
    echo "CONFIRMA: clone CT arquivo já validado."
    return 0
  fi
  run "bash -s" "$stamp" <<'REMOTE'
set -euo pipefail
VMID=121
STAMP="$1"
LEGACY_DST="/mnt/overpower/qbit-legacy/BT_backup.archive-${STAMP}"

pct exec "$VMID" -- bash -s "$STAMP" "$LEGACY_DST" <<'IN'
set -euo pipefail
STAMP="$1"
LEGACY_DST="$2"
QDIR=/.config/qBittorrent
ARCH="${QDIR}/BT_backup.archive-${STAMP}"

for svc in qbittorrent-nox qbittorrent; do
  if systemctl is-active --quiet "$svc" 2>/dev/null; then
    systemctl stop "$svc"
    break
  fi
done

if [[ ! -d "${QDIR}/BT_backup" ]]; then
  echo "ERRO: ${QDIR}/BT_backup não existe"
  exit 1
fi

mv "${QDIR}/BT_backup" "$ARCH"
mkdir -p "${QDIR}/BT_backup"
chmod 700 "${QDIR}/BT_backup"

LOCAL_Q="/root/.local/share/qBittorrent"
if [[ -d "${LOCAL_Q}/BT_backup" ]]; then
  LOCAL_ARCH="${LOCAL_Q}/BT_backup.archive-${STAMP}"
  mv "${LOCAL_Q}/BT_backup" "$LOCAL_ARCH"
  mkdir -p "${LOCAL_Q}/BT_backup"
  echo "Arquivado também ${LOCAL_Q}/BT_backup → $(basename "$LOCAL_ARCH")"
fi

if mountpoint -q /mnt/overpower && [[ -w /mnt/overpower ]]; then
  mkdir -p "$(dirname "$LEGACY_DST")"
  cp -a "$ARCH" "$LEGACY_DST" 2>/dev/null || echo "AVISO: cópia para overpower falhou (espaço?); arquivo no rootfs: $ARCH"
  if [[ -d "$LOCAL_ARCH" ]]; then
    cp -a "$LOCAL_ARCH" "/mnt/overpower/qbit-legacy/$(basename "$LOCAL_ARCH")-local-share" 2>/dev/null || true
  fi
fi

for svc in qbittorrent-nox qbittorrent; do
  if systemctl list-unit-files "$svc.service" 2>/dev/null | grep -q enabled; then
    systemctl start "$svc"
    systemctl is-active "$svc"
    exit 0
  fi
done
echo "AVISO: serviço qBittorrent não encontrado — iniciar manualmente"
IN
REMOTE
  echo "CT${PROD_VMID} com sessão vazia. Testar: curl -sf http://192.168.0.121:8090/"
}

case "$CMD" in
  inventory) inventory ;;
  snapshot) snapshot ;;
  clone) clone_ct ;;
  clean-production) clean_production ;;
  *)
    echo "Comando: inventory | snapshot [--apply] | clone ... | clean-production [--apply]"
    exit 1
    ;;
esac
