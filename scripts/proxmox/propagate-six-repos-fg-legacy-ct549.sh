#!/usr/bin/env bash
# Propaga Six Repos + segundo cérebro (llm-wiki) para fg_antigo no CT549 (fgsrv7).
#
# Uso (a partir de agldv com agl-hostman):
#   bash scripts/proxmox/propagate-six-repos-fg-legacy-ct549.sh
#   bash scripts/proxmox/propagate-six-repos-fg-legacy-ct549.sh --dry-run
#
# Padrão AGL: Tailscale SSH ao host Proxmox → pct exec / pct push no CT.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOSTMAN_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
LLM_WIKI_SOURCE="${LLM_WIKI_SOURCE:-/mnt/overpower/apps/dev/agl/llm-wiki}"
FGSRV7_HOST="${FGSRV7_HOST:-root@100.109.181.93}"
CT_VMID="${CT_VMID:-549}"
FG_LEGACY_ROOT="${FG_LEGACY_ROOT:-/var/www/fg_antigo}"
STAGING="/tmp/agl-six-repos-bundle"
DRY_RUN=0

log() { printf '[fg-legacy-six-repos] %s\n' "$*"; }

usage() {
  cat <<USAGE
Usage: $(basename "$0") [--dry-run]

  Empacota scripts + regras agl-hostman → CT${CT_VMID}, garante llm-wiki em /opt/agl-llm-wiki,
  corre install-six-repos-secondbrain-fg-legacy.sh e verify.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Opção desconhecida: $1" >&2; usage; exit 2 ;;
  esac
done

BUNDLE_LIST=(
  .cursor/rules/llm-wiki-second-brain-fg-legacy.mdc
  .cursor/rules/llm-wiki-second-brain.mdc
  .cursor/rules/karpathy-skills.mdc
  .cursor/skills/llm-wiki-ingest
  .cursor/commands/llm-wiki-ingest.md
  scripts/proxmox/ensure-llm-wiki-fg-legacy-ct549.sh
  scripts/skills/install-six-repos-secondbrain-fg-legacy.sh
  scripts/skills/verify-six-repos-fg-legacy.sh
)

if [[ "$DRY_RUN" == "1" ]]; then
  log "[dry-run] ssh $FGSRV7_HOST pct exec $CT_VMID — ${#BUNDLE_LIST[@]} paths"
  exit 0
fi

log "empacotar bundle six-repos"
TARFILE="$(mktemp /tmp/agl-six-repos-fg-XXXXXX.tar)"
trap 'rm -f "$TARFILE"' EXIT
tar -C "$HOSTMAN_ROOT" -cf "$TARFILE" $(printf '%s\n' "${BUNDLE_LIST[@]}" | while read -r p; do
  [[ -e "$HOSTMAN_ROOT/$p" ]] && echo "$p"
done)

log "upload → CT${CT_VMID}:$STAGING"
ssh -o BatchMode=yes -o ConnectTimeout=30 "$FGSRV7_HOST" \
  "pct exec ${CT_VMID} -- bash -lc 'rm -rf ${STAGING} && mkdir -p ${STAGING}'"
scp -o BatchMode=yes -o ConnectTimeout=30 -q "$TARFILE" "${FGSRV7_HOST}:/tmp/agl-six-repos-fg.tar"
ssh -o BatchMode=yes -o ConnectTimeout=30 "$FGSRV7_HOST" \
  "pct push ${CT_VMID} /tmp/agl-six-repos-fg.tar /tmp/agl-six-repos-fg.tar && rm -f /tmp/agl-six-repos-fg.tar"
ssh -o BatchMode=yes -o ConnectTimeout=30 "$FGSRV7_HOST" \
  "pct exec ${CT_VMID} -- bash -lc 'tar -xf /tmp/agl-six-repos-fg.tar -C ${STAGING} && rm -f /tmp/agl-six-repos-fg.tar'"

if [[ -r "${LLM_WIKI_SOURCE}/wiki/index.md" ]]; then
  log "empacotar llm-wiki de ${LLM_WIKI_SOURCE}"
  WIKI_TAR="$(mktemp /tmp/agl-llm-wiki-fg-XXXXXX.tar)"
  tar --owner=0 --group=0 -C "${LLM_WIKI_SOURCE}" -cf "$WIKI_TAR" \
    --exclude='.git' \
    --exclude='.obsidian/workspace.json' \
    --exclude='.obsidian/workspace-mobile.json' \
    wiki raw AGENTS.md README.md .claude 2>/dev/null || \
    tar --owner=0 --group=0 -C "${LLM_WIKI_SOURCE}" -cf "$WIKI_TAR" wiki raw AGENTS.md README.md
  scp -o BatchMode=yes -o ConnectTimeout=60 -q "$WIKI_TAR" "${FGSRV7_HOST}:/tmp/agl-llm-wiki-fg.tar"
  ssh -o BatchMode=yes -o ConnectTimeout=60 "$FGSRV7_HOST" \
    "pct push ${CT_VMID} /tmp/agl-llm-wiki-fg.tar /tmp/agl-llm-wiki-bundle.tar && rm -f /tmp/agl-llm-wiki-fg.tar"
  rm -f "$WIKI_TAR"
else
  log "AVISO: ${LLM_WIKI_SOURCE}/wiki/index.md em falta — llm-wiki no CT pode falhar"
fi

log "instalar six-repos + llm-wiki em ${FG_LEGACY_ROOT}"
ssh -o BatchMode=yes -o ConnectTimeout=300 "$FGSRV7_HOST" \
  "pct exec ${CT_VMID} -- bash -lc 'chmod +x ${STAGING}/scripts/proxmox/ensure-llm-wiki-fg-legacy-ct549.sh ${STAGING}/scripts/skills/install-six-repos-secondbrain-fg-legacy.sh ${STAGING}/scripts/skills/verify-six-repos-fg-legacy.sh && SKIP_RUFLO_SYNC=1 AGL_SOURCE=${STAGING} FG_LEGACY_ROOT=${FG_LEGACY_ROOT} bash ${STAGING}/scripts/skills/install-six-repos-secondbrain-fg-legacy.sh'"

log "copiar scripts para o repo fg_antigo (versionados)"
ssh -o BatchMode=yes -o ConnectTimeout=60 "$FGSRV7_HOST" \
  "pct exec ${CT_VMID} -- bash -lc 'mkdir -p ${FG_LEGACY_ROOT}/scripts/proxmox ${FG_LEGACY_ROOT}/scripts/skills && cp -f ${STAGING}/scripts/proxmox/ensure-llm-wiki-fg-legacy-ct549.sh ${FG_LEGACY_ROOT}/scripts/proxmox/ && cp -f ${STAGING}/scripts/skills/install-six-repos-secondbrain-fg-legacy.sh ${FG_LEGACY_ROOT}/scripts/skills/ && cp -f ${STAGING}/scripts/skills/verify-six-repos-fg-legacy.sh ${FG_LEGACY_ROOT}/scripts/skills/ && chmod +x ${FG_LEGACY_ROOT}/scripts/proxmox/*.sh ${FG_LEGACY_ROOT}/scripts/skills/*.sh'"

log "verificação"
ssh -o BatchMode=yes -o ConnectTimeout=60 "$FGSRV7_HOST" \
  "pct exec ${CT_VMID} -- bash -lc 'FG_LEGACY_ROOT=${FG_LEGACY_ROOT} bash ${FG_LEGACY_ROOT}/scripts/skills/verify-six-repos-fg-legacy.sh'"

log "=== Six Repos + secondbrain propagados para ${FG_LEGACY_ROOT} no CT${CT_VMID} ==="
