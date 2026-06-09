#!/usr/bin/env bash
# Replica mp0–mp9 dos *arr (CT123 Radarr / CT124 Sonarr) nos CTs de download.
# Alinha paths com Radarr/Sonarr: /mnt/overpower, /mnt/power, /mnt/storage, legacy Extracted.
#
# CT165 (aria2): troca mp0 /overpower → perfil completo; dir=/mnt/overpower/downs passa a
# /overpower/base/downs no host (igual qBit/Deluge/SAB).
#
# NOTA: Não altera quota no pool — reorganização de dados aguarda AGLSRV3.
#
# Uso:
#   bash scripts/media/ct-download-mounts-apply.sh              # dry-run
#   bash scripts/media/ct-download-mounts-apply.sh --apply
#   bash scripts/media/ct-download-mounts-apply.sh --apply --verify

set -euo pipefail

AGLSRV1="${AGLSRV1:-root@100.107.113.33}"
APPLY=false
VERIFY_ONLY=false
for a in "$@"; do
  [[ "$a" == --apply ]] && APPLY=true
  [[ "$a" == --verify ]] && VERIFY_ONLY=true
done

# Igual CT123 (Radarr) — fonte: pct config 123
VMIDS=(121 141 157 165)
REF_VMID=123

run() { ssh -o ConnectTimeout=15 -o BatchMode=yes "$AGLSRV1" "$@"; }

section() { echo ""; echo "=== $1 ==="; }

section "Referência CT${REF_VMID} (*arr)"
run "pct config ${REF_VMID} | grep '^mp' || true"

section "Estado actual (download CTs)"
for v in "${VMIDS[@]}"; do
  echo "--- CT${v} ---"
  run "pct config $v | grep '^mp' || echo '(sem mp)'"
done

if [[ "$APPLY" != true ]]; then
  echo ""
  echo "Plano: parar cada CT, remover mp* existentes, aplicar mp0–mp9 como CT${REF_VMID}."
  echo "Aplicar: bash scripts/media/ct-download-mounts-apply.sh --apply"
  exit 0
fi

section "Aplicar mounts (CT121 141 157 165)"
run "bash -s" <<REMOTE
set -euo pipefail
REF=123
VMIDS=(121 141 157 165)

apply_mp_profile() {
  local VMID="\$1"
  echo ""
  echo ">>> CT\${VMID}"
  if ! pct status "\$VMID" | grep -q running; then
    pct start "\$VMID" 2>/dev/null || true
    sleep 2
  fi
  pct stop "\$VMID" || true
  sleep 2

  # Remover binds antigos (mp0 só overpower ou /overpower legado)
  while pct config "\$VMID" | grep -q '^mp[0-9]'; do
    SLOT=\$(pct config "\$VMID" | grep -oP '^mp\K[0-9]+' | head -1)
    echo "  delete mp\${SLOT}"
    pct set "\$VMID" -delete "mp\${SLOT}"
  done

  # Perfil idêntico ao CT123
  pct set "\$VMID" -mp0 /mnt/shares,mp=/mnt/shares
  pct set "\$VMID" -mp1 /overpower/base,mp=/mnt/overpower
  pct set "\$VMID" -mp2 /spark/base,mp=/mnt/power
  pct set "\$VMID" -mp5 /mnt/storage,mp=/mnt/storage
  pct set "\$VMID" -mp6 /mnt/storage/Extracted,mp=/mnt/disks/gd/BB/Extracted
  pct set "\$VMID" -mp7 /mnt/storage/Extracted,mp=/mnt/pve/common/media/Extracted
  pct set "\$VMID" -mp8 /mnt/storage/Extracted_New,mp=/mnt/disks/gd/BB/Extracted_New
  pct set "\$VMID" -mp9 /mnt/storage/Extracted_New,mp=/mnt/pve/common/media/Extracted_New

  pct start "\$VMID"
  sleep 4
  pct config "\$VMID" | grep '^mp'
}

for VMID in "\${VMIDS[@]}"; do
  apply_mp_profile "\$VMID"
done

echo ""
echo ">>> Verificação paths (downloads *arr*)"
for VMID in "\${VMIDS[@]}"; do
  echo "CT\${VMID}:"
  pct exec "\$VMID" -- bash -c '
    set -e
    test -d /mnt/overpower/downs
    test -d /mnt/shares
    df -h /mnt/overpower | tail -1
    ls -ld /mnt/overpower/downs/torDownloading /mnt/overpower/downs/torFinished 2>/dev/null || ls -ld /mnt/overpower/downs/* 2>/dev/null | head -5
  ' || echo "  FALHA verificação CT'\$VMID'"
done
REMOTE

if [[ "$VERIFY_ONLY" == true ]] || [[ "$APPLY" == true ]]; then
  section "Comparar com CT${REF_VMID}"
  for v in "${VMIDS[@]}"; do
    echo "--- CT${v} vs ref ---"
    run "bash -c 'diff <(pct config ${REF_VMID} | grep \"^mp\" | sort) <(pct config $v | grep \"^mp\" | sort) && echo OK: mp idênticos' || diff <(pct config ${REF_VMID} | grep '^mp' | sort) <(pct config $v | grep '^mp' | sort)"
  done
fi

echo ""
echo "Concluído. Benchmark: bash scripts/media/download-clients-perf-benchmark.sh --skip-optimize"
