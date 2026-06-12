#!/usr/bin/env bash
# Propaga gh auth do host actual (ex. agldv03) para CT193 via SSH — sem imprimir token.
set -euo pipefail

CTID="${CTID:-193}"
PROXMOX_HOST="${PROXMOX_HOST:-100.107.113.33}"
REPO="${AGL_HOSTMAN_DIR:-/mnt/overpower/apps/dev/agl/agl-hostman}"

log() { echo "[propagate-gh] $*"; }

if ! command -v gh >/dev/null; then
  echo "ERRO: gh não encontrado no host fonte" >&2
  exit 1
fi

if ! gh auth token &>/dev/null; then
  echo "ERRO: gh sem token no host fonte — correr: gh auth login -h github.com" >&2
  exit 1
fi

log "instalar gh no CT${CTID} (se necessário)..."
ssh -o ConnectTimeout=15 "root@${PROXMOX_HOST}" \
  "pct exec ${CTID} -- bash ${REPO}/scripts/obsidian/setup-github-gh.sh --install-only"

log "propagar credenciais gh → CT${CTID}..."
if gh auth token | ssh -o ConnectTimeout=15 "root@${PROXMOX_HOST}" \
  "pct exec ${CTID} -- gh auth login --with-token" 2>/dev/null; then
  log "auth via token pipe OK"
else
  log "token pipe falhou (API GitHub no CT?) — copiar ~/.config/gh do host fonte"
  install -d -m 0700 /tmp/gh-config-copy
  cp -a "${HOME}/.config/gh/." /tmp/gh-config-copy/
  tar -C /tmp/gh-config-copy -cf - . \
    | ssh -o ConnectTimeout=15 "root@${PROXMOX_HOST}" \
      "pct exec ${CTID} -- bash -c 'install -d -m 0700 /root/.config/gh && tar -xf - -C /root/.config/gh'"
  rm -rf /tmp/gh-config-copy
fi

log "configurar git (sem verify API se rede bloqueada)..."
ssh "root@${PROXMOX_HOST}" \
  "pct exec ${CTID} -- env VERIFY_GH_REPO=0 bash ${REPO}/scripts/obsidian/setup-github-gh.sh"

log "OK — CT${CTID} pronto para bridge git (gh)"
