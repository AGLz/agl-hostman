#!/usr/bin/env bash
# Garante makemoney01 no mount NFS + symlink CT188 + clone GitHub AGLz.
# Uso (root no CT188 ou agldv03):
#   bash ensure-makemoney01-ct188.sh [/caminho/agl-hostman]
set -euo pipefail

AGL_HOSTMAN="${1:-/mnt/overpower/apps/dev/agl/agl-hostman}"
MAKEMONEY_NFS="${MAKEMONEY_NFS:-/mnt/overpower/apps/dev/agl/makemoney01}"
MAKEMONEY_HOST="${MAKEMONEY_HOST:-/opt/agl-makemoney01}"
GITHUB_ORG="${GITHUB_ORG:-AGLz}"
GITHUB_REPO="${GITHUB_REPO:-makemoney01}"
HERMES_ROOT="${HERMES_ROOT:-/opt/agl-hermes}"

if [[ ! -d "${MAKEMONEY_NFS}/data" ]]; then
  if command -v gh >/dev/null 2>&1 && gh repo view "${GITHUB_ORG}/${GITHUB_REPO}" >/dev/null 2>&1; then
    echo "Clone ${GITHUB_ORG}/${GITHUB_REPO} → ${MAKEMONEY_NFS}"
    parent="$(dirname "${MAKEMONEY_NFS}")"
    mkdir -p "${parent}"
    gh repo clone "${GITHUB_ORG}/${GITHUB_REPO}" "${MAKEMONEY_NFS}" 2>/dev/null || true
  else
    echo "AVISO: scaffold local em ${MAKEMONEY_NFS}" >&2
    mkdir -p "${MAKEMONEY_NFS}/data/"{cron-sync,opportunities,pipeline,hermes-archive} \
      "${MAKEMONEY_NFS}/wiki-ingest" "${MAKEMONEY_NFS}/scripts"
  fi
fi

if [[ -d "${MAKEMONEY_NFS}" ]]; then
  ln -sfn "${MAKEMONEY_NFS}" "${MAKEMONEY_HOST}" 2>/dev/null || true
  echo "OK symlink ${MAKEMONEY_HOST} → ${MAKEMONEY_NFS}"
fi

# wiki-ingest Jarvis → makemoney01 (canónico)
if [[ -d "${HERMES_ROOT}/data" ]]; then
  wiki_mm="${MAKEMONEY_NFS}/wiki-ingest"
  wiki_hermes="${HERMES_ROOT}/data/wiki-ingest"
  mkdir -p "${wiki_mm}"
  if [[ -e "${wiki_hermes}" && ! -L "${wiki_hermes}" ]]; then
    rm -rf "${wiki_hermes}"
  fi
  ln -sfn "${wiki_mm}" "${wiki_hermes}" 2>/dev/null || true
  echo "OK Hermes wiki-ingest → ${wiki_mm}"
fi

test -r "${MAKEMONEY_NFS}/README.md" || {
  echo "ERRO: README em falta — projecto incompleto" >&2
  exit 1
}

chmod -R a+rwX "${MAKEMONEY_NFS}/data" "${MAKEMONEY_NFS}/wiki-ingest" 2>/dev/null || true
echo "OK makemoney01 pronto (${MAKEMONEY_NFS})"
