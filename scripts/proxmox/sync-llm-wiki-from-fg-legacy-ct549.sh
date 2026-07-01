#!/usr/bin/env bash
# Pull llm-wiki de /opt/agl-llm-wiki (CT549 fg-legacy) → vault NFS local.
#
# Inverso de propagate-six-repos-fg-legacy-ct549.sh (que empurra agldv → CT549).
# O CT549 não tem Git no vault; sync via tar + rsync --update (fg ganha se mais novo).
#
# Uso (a partir de agldv com NFS llm-wiki):
#   bash scripts/proxmox/sync-llm-wiki-from-fg-legacy-ct549.sh
#   bash scripts/proxmox/sync-llm-wiki-from-fg-legacy-ct549.sh --dry-run
#
# Variáveis:
#   LLM_WIKI_TARGET  — default /mnt/overpower/apps/dev/agl/llm-wiki
#   FGSRV7_HOST      — default root@100.109.181.93
#   CT_VMID          — default 549
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LLM_WIKI_TARGET="${LLM_WIKI_TARGET:-/mnt/overpower/apps/dev/agl/llm-wiki}"
FGSRV7_HOST="${FGSRV7_HOST:-root@100.109.181.93}"
CT_VMID="${CT_VMID:-549}"
FG_WIKI_DIR="/opt/agl-llm-wiki"
DRY_RUN=0

log() { printf '[sync-wiki-from-fg] %s\n' "$*"; }

usage() {
  cat <<USAGE
Usage: $(basename "$0") [--dry-run]

  Extrai wiki/ e raw/ do CT${CT_VMID} e aplica rsync --update em \${LLM_WIKI_TARGET}.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Opção desconhecida: $1" >&2; usage; exit 2 ;;
  esac
done

if [[ ! -d "${LLM_WIKI_TARGET}/wiki" ]]; then
  log "ERRO: ${LLM_WIKI_TARGET}/wiki em falta" >&2
  exit 1
fi

STAGING="$(mktemp /tmp/agl-llm-wiki-from-fg-XXXXXX.tar)"
TMPDIR="$(mktemp -d)"
trap 'rm -f "$STAGING"; rm -rf "$TMPDIR"' EXIT

log "pull ${FG_WIKI_DIR} do CT${CT_VMID} via ${FGSRV7_HOST}"
ssh -o BatchMode=yes -o ConnectTimeout=60 "${FGSRV7_HOST}" \
  "pct exec ${CT_VMID} -- bash -lc 'test -r ${FG_WIKI_DIR}/wiki/index.md && tar -C ${FG_WIKI_DIR} --owner=0 --group=0 -cf - wiki raw'" \
  > "${STAGING}"

tar -xf "${STAGING}" -C "${TMPDIR}"

if [[ "$DRY_RUN" == "1" ]]; then
  log "[dry-run] diff wiki (fg → local):"
  diff -qr "${TMPDIR}/wiki" "${LLM_WIKI_TARGET}/wiki" || true
  log "[dry-run] raw novos no fg:"
  comm -23 \
    <(cd "${TMPDIR}/raw" && find . -type f | sort) \
    <(cd "${LLM_WIKI_TARGET}/raw" && find . -type f | sort) \
    | head -20 || true
  exit 0
fi

log "rsync wiki/ → ${LLM_WIKI_TARGET}/wiki/"
rsync -a --update "${TMPDIR}/wiki/" "${LLM_WIKI_TARGET}/wiki/"

log "rsync raw/ → ${LLM_WIKI_TARGET}/raw/"
rsync -a --update "${TMPDIR}/raw/" "${LLM_WIKI_TARGET}/raw/"

log "OK — rever git status em ${LLM_WIKI_TARGET} e commit/push se aplicável"
