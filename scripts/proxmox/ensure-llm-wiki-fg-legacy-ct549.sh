#!/usr/bin/env bash
# Garante llm-wiki em /opt/agl-llm-wiki no CT fg-legacy (549).
#
# Ordem: vault já presente → bundle tar (propagate agldv) → git SSH → erro.
# Uso (root no CT549): bash ensure-llm-wiki-fg-legacy-ct549.sh
set -euo pipefail

WIKI_DIR="${WIKI_DIR:-/opt/agl-llm-wiki}"
WIKI_BUNDLE="${WIKI_BUNDLE:-/tmp/agl-llm-wiki-bundle.tar}"
WIKI_REPO_SSH="${WIKI_REPO_SSH:-git@github.com:AGLz/llm-wiki.git}"

log() { printf '[llm-wiki-fg] %s\n' "$*"; }

if [[ -f "${WIKI_BUNDLE}" ]]; then
  log "extrair bundle ${WIKI_BUNDLE} → ${WIKI_DIR}"
  rm -rf "${WIKI_DIR}"
  mkdir -p "${WIKI_DIR}"
  tar --no-same-owner -xf "${WIKI_BUNDLE}" -C "${WIKI_DIR}"
elif [[ -r "${WIKI_DIR}/wiki/index.md" ]]; then
  log "OK wiki presente: ${WIKI_DIR}"
elif command -v git >/dev/null 2>&1; then
  log "tentar clone SSH ${WIKI_REPO_SSH}"
  if GIT_SSH_COMMAND="ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new" \
    git clone --depth 1 "${WIKI_REPO_SSH}" "${WIKI_DIR}" 2>/dev/null; then
    log "clone SSH OK"
  else
    log "clone SSH falhou — usar propagate-six-repos-fg-legacy-ct549.sh a partir de agldv" >&2
    exit 1
  fi
else
  log "llm-wiki em falta — correr propagate a partir de agldv com NFS" >&2
  exit 1
fi

test -r "${WIKI_DIR}/wiki/index.md"
log "OK llm-wiki: ${WIKI_DIR}/wiki/index.md"
