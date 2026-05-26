#!/usr/bin/env bash
# Garante llm-wiki em /opt/agl-llm-wiki no CT188 (symlink NFS ou clone).
# Uso (root no CT188): bash ensure-llm-wiki-ct188.sh
set -euo pipefail

WIKI_DIR="${WIKI_DIR:-/opt/agl-llm-wiki}"
WIKI_NFS="${WIKI_NFS:-/mnt/overpower/apps/dev/agl/llm-wiki}"

if [[ -d "${WIKI_NFS}/wiki" ]]; then
  rm -rf "${WIKI_DIR}"
  ln -sfn "${WIKI_NFS}" "${WIKI_DIR}"
  echo "OK llm-wiki → NFS ${WIKI_NFS}"
elif [[ -d "${WIKI_DIR}/wiki" ]]; then
  echo "OK llm-wiki já presente em ${WIKI_DIR}"
else
  echo "AVISO: clone manual necessário (repo privado AGLz)" >&2
  echo "  agldv03: gh repo clone AGLz/llm-wiki ${WIKI_NFS}" >&2
  echo "  depois: ln -sfn ${WIKI_NFS} ${WIKI_DIR}" >&2
  exit 1
fi

test -r "${WIKI_DIR}/wiki/index.md"
