#!/usr/bin/env bash
# Prepara share agl-home-sync no CT178 (aglfs1) — NFS + Samba.
# Executar NO host Proxmox (AGLSRV1) ou dentro do CT178.
#
# Uso (AGLSRV1):
#   ssh root@100.107.113.33 'bash -s' < scripts/dotfiles/prepare-aglfs1-home-sync-share.sh
# Ou dentro CT178:
#   pct exec 178 -- bash /mnt/overpower/apps/dev/agl/agl-hostman/scripts/dotfiles/prepare-aglfs1-home-sync-share.sh
#
# Tailscale aglfs1: 100.69.187.105
# Path canónico futuro: /mnt/shares/agl-home-sync (mount local em agldv* → /mnt/agl-home-sync)

set -euo pipefail

SHARE_ROOT="${SHARE_ROOT:-/mnt/shares/agl-home-sync}"
DRY_RUN=0

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

run() {
  if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "  [dry-run] $*"
  else
    "$@"
  fi
}

log "=== prepare agl-home-sync share ==="
log "SHARE_ROOT=$SHARE_ROOT"

run mkdir -p "$SHARE_ROOT"/{linux-root,win-administrator}
run chmod 770 "$SHARE_ROOT"
run chmod 770 "$SHARE_ROOT/linux-root" "$SHARE_ROOT/win-administrator" 2>/dev/null || true

# NFS export snippet (admin deve merge em /etc/exports)
EXPORT_LINE="${SHARE_ROOT} 192.168.0.0/24(rw,sync,no_subtree_check,no_root_squash) 100.64.0.0/10(rw,sync,no_subtree_check,no_root_squash)"

if [[ -f /etc/exports ]]; then
  if grep -qF "$SHARE_ROOT" /etc/exports 2>/dev/null; then
    ok "NFS export já presente em /etc/exports"
  else
    warn "Adicionar manualmente a /etc/exports:"
    echo "  $EXPORT_LINE"
    if [[ "$DRY_RUN" -eq 0 ]]; then
      echo "# AGL home sync — $(date -Iseconds)" >> /etc/exports
      echo "$EXPORT_LINE" >> /etc/exports
      exportfs -ra 2>/dev/null || warn "exportfs -ra falhou — rever /etc/exports"
      ok "export NFS adicionado"
    fi
  fi
else
  warn "/etc/exports não encontrado — configurar NFS manualmente"
fi

# Samba hint
if command -v testparm >/dev/null 2>&1; then
  ok "Samba presente — adicionar share [agl-home-sync] path=$SHARE_ROOT se necessário"
else
  warn "Samba não detectado neste host"
fi

cat <<EOF

Próximo passo em cada agldv* (fstab):
  192.168.0.178:$SHARE_ROOT /mnt/agl-home-sync nfs4 vers=4.2,rsize=1048576,wsize=1048576,hard,_netdev 0 0
  # fallback Tailscale:
  100.69.187.105:$SHARE_ROOT /mnt/agl-home-sync nfs4 vers=4.2,hard,_netdev 0 0

Depois:
  AGL_HOME_SYNC_ROOT=/mnt/agl-home-sync ./scripts/dotfiles/install-agl-home-sync.sh

Nota: overpower (/mnt/overpower/apps/dev/agl/agl-home-sync) continua válido até cutover.
EOF

ok "prepare concluído"
