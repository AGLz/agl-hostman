#!/usr/bin/env bash
# Propaga arsenal de guerra + pack Cursor AGL para fg_antigo no CT549 (fg-legacy, fgsrv7).
#
# Uso (a partir de agldv com agl-hostman):
#   bash scripts/proxmox/propagate-arsenal-war-fg-legacy-ct549.sh
#   bash scripts/proxmox/propagate-arsenal-war-fg-legacy-ct549.sh --dry-run
#
# Padrão AGL: Tailscale SSH ao host Proxmox → pct exec no CT.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOSTMAN_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
FGSRV7_HOST="${FGSRV7_HOST:-root@100.109.181.93}"
CT_VMID="${CT_VMID:-549}"
FG_LEGACY_ROOT="${FG_LEGACY_ROOT:-/var/www/fg_antigo}"
STAGING="/tmp/agl-arsenal-bundle"
DRY_RUN=0

log() { printf '[fg-legacy-arsenal] %s\n' "$*"; }

usage() {
  cat <<USAGE
Usage: $(basename "$0") [--dry-run]

  Rsync agl-hostman → CT${CT_VMID} (${FG_LEGACY_ROOT}) e corre install-arsenal-war-skills-fg-legacy.sh.
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
  .cursor/rules/prompt-improve.mdc
  .cursor/rules/self-improve.mdc
  .cursor/rules/session-reflect.mdc
  .cursor/rules/memory.mdc
  .cursor/skills/reflect-yourself
  .cursor/skills/agl-video-analysis
  .cursor/skills/agl-architecture-diagram
  .cursor/skills/improve
  .cursor/skills/drawio-skill
  .cursor/skills/video-transcript-downloader
  .cursor/commands/reflect-yourself.md
  .agents/skills/video-transcript-downloader
  scripts/skills/scan-skill-security.sh
  scripts/skills/install-skillspector.sh
  scripts/skills/install-arsenal-war-skills-fg-legacy.sh
  .github/workflows/skill-security-scan.yml
)

if [[ "$DRY_RUN" == "1" ]]; then
  log "[dry-run] ssh $FGSRV7_HOST pct exec $CT_VMID — ${#BUNDLE_LIST[@]} paths de $HOSTMAN_ROOT"
  exit 0
fi

log "empacotar bundle agl-hostman"
TARFILE="$(mktemp /tmp/agl-arsenal-fg-XXXXXX.tar)"
trap 'rm -f "$TARFILE"' EXIT
tar -C "$HOSTMAN_ROOT" -cf "$TARFILE" "${BUNDLE_LIST[@]}" 2>/dev/null || {
  # fallback: só paths que existem
  tar -C "$HOSTMAN_ROOT" -cf "$TARFILE" $(printf '%s\n' "${BUNDLE_LIST[@]}" | while read -r p; do
    [[ -e "$HOSTMAN_ROOT/$p" ]] && echo "$p"
  done)
}

log "upload → CT${CT_VMID}:$STAGING"
ssh -o BatchMode=yes -o ConnectTimeout=30 "$FGSRV7_HOST" \
  "pct exec ${CT_VMID} -- bash -lc 'rm -rf ${STAGING} && mkdir -p ${STAGING}'"
scp -o BatchMode=yes -o ConnectTimeout=30 -q "$TARFILE" "${FGSRV7_HOST}:/tmp/agl-arsenal-fg.tar"
ssh -o BatchMode=yes -o ConnectTimeout=30 "$FGSRV7_HOST" \
  "pct push ${CT_VMID} /tmp/agl-arsenal-fg.tar /tmp/agl-arsenal-fg.tar && rm -f /tmp/agl-arsenal-fg.tar"
ssh -o BatchMode=yes -o ConnectTimeout=30 "$FGSRV7_HOST" \
  "pct exec ${CT_VMID} -- bash -lc 'tar -xf /tmp/agl-arsenal-fg.tar -C ${STAGING} && rm -f /tmp/agl-arsenal-fg.tar'"

log "instalar em ${FG_LEGACY_ROOT}"
ssh -o BatchMode=yes -o ConnectTimeout=120 "$FGSRV7_HOST" \
  "pct exec ${CT_VMID} -- bash -lc 'SKIP_SKILL_SCAN=1 AGL_SOURCE=${STAGING} FG_LEGACY_ROOT=${FG_LEGACY_ROOT} bash ${STAGING}/scripts/skills/install-arsenal-war-skills-fg-legacy.sh'"

log "verificação rápida"
ssh -o BatchMode=yes -o ConnectTimeout=30 "$FGSRV7_HOST" \
  "pct exec ${CT_VMID} -- bash -lc 'test -f ${FG_LEGACY_ROOT}/.cursor/rules/ponytail.mdc && test -f ${FG_LEGACY_ROOT}/.cursor/skills/improve/SKILL.md && echo OK_ARSENAL_FG'"

log "=== Arsenal propagado para ${FG_LEGACY_ROOT} no CT${CT_VMID} ==="
