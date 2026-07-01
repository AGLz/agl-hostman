#!/usr/bin/env bash
# Propagação completa fg-legacy: arsenal + six-repos + essentials + Node 20 + verify.
#
# Uso (agl-hostman em agldv):
#   bash scripts/proxmox/propagate-fg-legacy-full-ct549.sh
#   bash scripts/proxmox/propagate-fg-legacy-full-ct549.sh --skip-node
#   bash scripts/proxmox/propagate-fg-legacy-full-ct549.sh --prune-skills
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOSTMAN_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
FGSRV7_HOST="${FGSRV7_HOST:-root@100.109.181.93}"
CT_VMID="${CT_VMID:-549}"
FG_LEGACY_ROOT="${FG_LEGACY_ROOT:-/var/www/fg_antigo}"
STAGING="/tmp/agl-fg-full-bundle"
SKIP_NODE=0
PRUNE_SKILLS=0
DRY_RUN=0

log() { printf '[fg-legacy-full] %s\n' "$*"; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-node) SKIP_NODE=1; shift ;;
    --prune-skills) PRUNE_SKILLS=1; shift ;;
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help)
      echo "Usage: $(basename "$0") [--skip-node] [--prune-skills] [--dry-run]"
      exit 0
      ;;
    *) echo "Opção: $1" >&2; exit 2 ;;
  esac
done

if [[ "$DRY_RUN" == "1" ]]; then
  log "[dry-run] arsenal + six-repos + essentials + node=$([[ $SKIP_NODE -eq 1 ]] && echo skip || echo install)"
  exit 0
fi

# Fases 1–2: scripts existentes
bash "$HOSTMAN_ROOT/scripts/proxmox/propagate-arsenal-war-fg-legacy-ct549.sh"
bash "$HOSTMAN_ROOT/scripts/proxmox/propagate-six-repos-fg-legacy-ct549.sh"

log "bundle essentials"
BUNDLE_LIST=(
  .cursor/rules/learned-memories-fg-legacy.mdc
  .cursor/rules/common-security-fg-legacy.mdc
  .cursor/rules/php-security-fg-legacy.mdc
  .cursor/rules/mandatory-delivery-pipeline-fg-legacy.mdc
  .cursor/rules/common-git-workflow.mdc
  scripts/skills/install-fg-legacy-essentials.sh
  scripts/skills/prune-fg-legacy-skills.sh
  scripts/skills/verify-fg-legacy-pack.sh
  scripts/maint/install-node20-ct549.sh
  scripts/maint/prepare-cursor-runtime-ct549.sh
  scripts/maint/fgsrv07/lib/ct243-locale-php-pt-br.sh
)

TARFILE="$(mktemp /tmp/agl-fg-full-XXXXXX.tar)"
trap 'rm -f "$TARFILE"' EXIT
tar -C "$HOSTMAN_ROOT" -cf "$TARFILE" $(printf '%s\n' "${BUNDLE_LIST[@]}" | while read -r p; do
  [[ -e "$HOSTMAN_ROOT/$p" ]] && echo "$p"
done)

ssh -o BatchMode=yes -o ConnectTimeout=30 "$FGSRV7_HOST" \
  "pct exec ${CT_VMID} -- bash -lc 'rm -rf ${STAGING} && mkdir -p ${STAGING}'"
scp -o BatchMode=yes -q "$TARFILE" "${FGSRV7_HOST}:/tmp/agl-fg-full.tar"
ssh -o BatchMode=yes "$FGSRV7_HOST" \
  "pct push ${CT_VMID} /tmp/agl-fg-full.tar /tmp/agl-fg-full.tar && rm -f /tmp/agl-fg-full.tar"
ssh -o BatchMode=yes "$FGSRV7_HOST" \
  "pct exec ${CT_VMID} -- bash -lc 'tar -xf /tmp/agl-fg-full.tar -C ${STAGING} && rm -f /tmp/agl-fg-full.tar'"

INSTALL_NODE_FLAG=0
[[ "$SKIP_NODE" == "0" ]] && INSTALL_NODE_FLAG=1

ssh -o BatchMode=yes -o ConnectTimeout=600 "$FGSRV7_HOST" \
  "pct exec ${CT_VMID} -- bash -lc '\
    chmod +x ${STAGING}/scripts/skills/*.sh ${STAGING}/scripts/maint/*.sh ${STAGING}/scripts/maint/fgsrv07/lib/*.sh 2>/dev/null; \
    mkdir -p ${FG_LEGACY_ROOT}/scripts/skills ${FG_LEGACY_ROOT}/scripts/maint/fgsrv07/lib; \
    cp -f ${STAGING}/scripts/skills/install-fg-legacy-essentials.sh ${STAGING}/scripts/skills/prune-fg-legacy-skills.sh ${STAGING}/scripts/skills/verify-fg-legacy-pack.sh ${FG_LEGACY_ROOT}/scripts/skills/; \
    cp -f ${STAGING}/scripts/maint/*.sh ${FG_LEGACY_ROOT}/scripts/maint/ 2>/dev/null; \
    cp -f ${STAGING}/scripts/maint/fgsrv07/lib/*.sh ${FG_LEGACY_ROOT}/scripts/maint/fgsrv07/lib/ 2>/dev/null; \
    chmod +x ${FG_LEGACY_ROOT}/scripts/skills/*.sh ${FG_LEGACY_ROOT}/scripts/maint/*.sh; \
    PRUNE_SKILLS=${PRUNE_SKILLS} INSTALL_NODE=${INSTALL_NODE_FLAG} AGL_SOURCE=${STAGING} FG_LEGACY_ROOT=${FG_LEGACY_ROOT} bash ${STAGING}/scripts/skills/install-fg-legacy-essentials.sh'"

log "verificação pack"
ssh -o BatchMode=yes -o ConnectTimeout=120 "$FGSRV7_HOST" \
  "pct exec ${CT_VMID} -- bash -lc 'FG_LEGACY_ROOT=${FG_LEGACY_ROOT} bash ${FG_LEGACY_ROOT}/scripts/skills/verify-fg-legacy-pack.sh'"

log "=== fg-legacy full propagate concluído CT${CT_VMID} ==="
