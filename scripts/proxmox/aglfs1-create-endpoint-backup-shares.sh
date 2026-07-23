#!/usr/bin/env bash
# Cria shares Samba guest-images / timemachine no CT178 (aglfs1) + users bkp-win / bkp-mac.
# Executar no host Proxmox AGLSRV1 (root).
#
# Uso:
#   bash scripts/proxmox/aglfs1-create-endpoint-backup-shares.sh --dry-run
#   bash scripts/proxmox/aglfs1-create-endpoint-backup-shares.sh --apply
#   bash scripts/proxmox/aglfs1-create-endpoint-backup-shares.sh --apply --quota 50G
#
# Nota: quotas baixas por defeito — expandir após migração de dados para AGLSRV3.
# Credenciais: /root/aglfs1-bkp-share-credentials.txt no AGLSRV1 (chmod 600).

set -euo pipefail

CT=178
QUOTA="${QUOTA:-50G}"
DRY_RUN=0
APPLY=0
WIN_PATH="/spark/base/guest-images"
MAC_PATH="/spark/base/timemachine"
CRED_FILE="/root/aglfs1-bkp-share-credentials.txt"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=1; shift ;;
    --apply) APPLY=1; shift ;;
    --quota) QUOTA="$2"; shift 2 ;;
    -h|--help)
      sed -n '2,14p' "$0"
      exit 0
      ;;
    *) echo "Opção desconhecida: $1" >&2; exit 1 ;;
  esac
done

if [[ "$DRY_RUN" -eq 0 && "$APPLY" -eq 0 ]]; then
  echo "Indicar --dry-run ou --apply" >&2
  exit 1
fi

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

rand_pw() {
  # Reason: 24 hex chars; sem pipe para head (evita SIGPIPE com pipefail)
  openssl rand -hex 12
}

if [[ "$(hostname -s)" != "aglsrv1" ]] && [[ ! -f /etc/pve/lxc/${CT}.conf ]]; then
  warn "Este script espera o host AGLSRV1 (pct ${CT}). hostname=$(hostname)"
fi

log "=== aglfs1 endpoint backup shares (quota=${QUOTA}) ==="

# --- paths no host (visíveis no CT como /mnt/power/... via mp2 /spark/base) ---
# ponytail: dirs sob spark/base evitam restart do CT; datasets ZFS dedicados = manutenção futura
for p in "$WIN_PATH" "$MAC_PATH"; do
  run mkdir -p "$p"
  if [[ "$DRY_RUN" -eq 0 ]]; then
    chmod 2770 "$p"
    # Reason: sticky group para escrita Samba
    chown root:root "$p"
  fi
done

if [[ "$DRY_RUN" -eq 0 ]]; then
  cat >"${WIN_PATH}/README-AGL.txt" <<EOF
AGL guest-images — destino Macrium Reflect (Windows).
Share: \\\\aglfs1\\guest-images  user: bkp-win
Path CT178: /mnt/power/guest-images
Espaço: quota operacional baixa até migração AGLSRV3 libertar capacidade.
Não colocar no datastore PBS (spark/pbs).
EOF
  cat >"${MAC_PATH}/README-AGL.txt" <<EOF
AGL timemachine — destino Time Machine (macOS).
Share: smb://aglfs1/timemachine  user: bkp-mac
Path CT178: /mnt/power/timemachine
Samba fruit:time machine = yes. Deixar o macOS criar o sparsebundle.
Espaço: quota operacional baixa até migração AGLSRV3.
EOF
  ok "README em $WIN_PATH e $MAC_PATH"
fi

# --- users Linux + Samba no CT ---
setup_user() {
  local user="$1" pw="$2" home="$3"
  pct exec "$CT" -- bash -lc "
    set -e
    if ! id '$user' &>/dev/null; then
      useradd -r -m -d '$home' -s /usr/sbin/nologin '$user'
    fi
    mkdir -p '$home'
    chown '$user:$user' '$home'
    chmod 700 '$home'
    printf '%s\n%s\n' '$pw' '$pw' | smbpasswd -a -s '$user'
    smbpasswd -e '$user'
  "
}

WIN_PW=""
MAC_PW=""
if [[ "$DRY_RUN" -eq 1 ]]; then
  log "Criaria users bkp-win / bkp-mac + smbpasswd"
else
  if [[ -f "$CRED_FILE" ]]; then
    # Reason: reaplicar shares sem regenerar passwords se ficheiro já existe
    # shellcheck disable=SC1090
    source "$CRED_FILE"
    WIN_PW="${BKP_WIN_PASSWORD:?}"
    MAC_PW="${BKP_MAC_PASSWORD:?}"
    ok "A reutilizar passwords de $CRED_FILE"
  else
    WIN_PW="$(rand_pw)"
    MAC_PW="$(rand_pw)"
    umask 077
    cat >"$CRED_FILE" <<EOF
# aglfs1 endpoint backup — $(date -Iseconds)
# NÃO commit; chmod 600
BKP_WIN_USER=bkp-win
BKP_WIN_PASSWORD=${WIN_PW}
BKP_MAC_USER=bkp-mac
BKP_MAC_PASSWORD=${MAC_PW}
GUEST_IMAGES_UNC=\\\\192.168.0.178\\guest-images
TIMEMACHINE_URL=smb://192.168.0.178/timemachine
EOF
    chmod 600 "$CRED_FILE"
    ok "Credenciais gravadas em $CRED_FILE"
  fi
  setup_user bkp-win "$WIN_PW" /var/lib/aglbkp/bkp-win
  setup_user bkp-mac "$MAC_PW" /var/lib/aglbkp/bkp-mac
  # Ownership dos destinos para os users Samba
  pct exec "$CT" -- bash -lc "
    chown bkp-win:bkp-win /mnt/power/guest-images
    chmod 2770 /mnt/power/guest-images
    chown bkp-mac:bkp-mac /mnt/power/timemachine
    chmod 2770 /mnt/power/timemachine
  "
  ok "Users Samba bkp-win / bkp-mac"
fi

# --- smb.conf snippets (idempotente) ---
SMB_SNIPPET=$(cat <<'EOF'

# --- AGL endpoint backups (Macrium + Time Machine) ---
[guest-images]
   comment = AGL Macrium Reflect (Windows fleet)
   path = /mnt/power/guest-images
   browseable = yes
   read only = no
   guest ok = no
   valid users = bkp-win
   force user = bkp-win
   force group = bkp-win
   create mask = 0660
   directory mask = 0770
   vfs objects = aio_pthread

[timemachine]
   comment = AGL Time Machine (macOS fleet)
   path = /mnt/power/timemachine
   browseable = yes
   read only = no
   guest ok = no
   valid users = bkp-mac
   force user = bkp-mac
   force group = bkp-mac
   create mask = 0660
   directory mask = 0770
   vfs objects = catia fruit streams_xattr aio_pthread
   fruit:time machine = yes
   fruit:time machine max size = 50G
   fruit:metadata = stream
   fruit:encoding = native
# --- fim AGL endpoint backups ---
EOF
)

if [[ "$DRY_RUN" -eq 1 ]]; then
  log "Adicionaria shares [guest-images] e [timemachine] ao smb.conf"
  echo "$SMB_SNIPPET"
else
  pct exec "$CT" -- bash -lc '
    set -e
    conf=/etc/samba/smb.conf
    cp -a "$conf" "${conf}.bak-agl-endpoint-$(date +%Y%m%d%H%M%S)"
    if grep -q "^\[guest-images\]" "$conf"; then
      echo "[OK] shares já presentes — a substituir bloco AGL"
      # Remove bloco anterior entre marcadores
      awk "
        /# --- AGL endpoint backups/ {skip=1}
        /# --- fim AGL endpoint backups/ {skip=0; next}
        !skip {print}
      " "$conf" > /tmp/smb.conf.new
      mv /tmp/smb.conf.new "$conf"
    fi
  '
  # Append snippet via host → CT
  printf '%s\n' "$SMB_SNIPPET" | pct exec "$CT" -- tee -a /etc/samba/smb.conf >/dev/null
  # Ajustar fruit max size à quota pedida
  pct exec "$CT" -- sed -i "s/fruit:time machine max size = .*/fruit:time machine max size = ${QUOTA}/" /etc/samba/smb.conf
  pct exec "$CT" -- testparm -s >/dev/null
  pct exec "$CT" -- systemctl reload smbd
  ok "smbd reloaded; shares guest-images + timemachine"
fi

# Nota sobre quota ZFS (opcional, datasets futuros)
log "Espaço actual spark: $(zfs list -H -o avail spark 2>/dev/null || echo n/a)"
warn "Dirs em $WIN_PATH / $MAC_PATH (sem dataset ZFS dedicado ainda)."
warn "Após migração AGLSRV3: zfs create spark/guest-images + spark/timemachine com quota maior e cutover."

cat <<EOF

URLs:
  Windows: \\\\192.168.0.178\\guest-images   (ou \\\\aglfs1\\guest-images)
  macOS:   smb://192.168.0.178/timemachine (ou smb://aglfs1/timemachine)
Credenciais: $CRED_FILE no AGLSRV1
EOF

ok "concluído"
