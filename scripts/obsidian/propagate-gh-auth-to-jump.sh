#!/usr/bin/env bash
# Propaga gh auth para jump host (GCE) quando api.github.com está bloqueado na LAN AGL.
# O jump executa gh API; agldv04 usa scripts/obsidian/gh-agl-wrapper.sh.
set -euo pipefail

GH_JUMP_HOST="${GH_JUMP_HOST:-root@100.109.71.103}"
REPO="${AGL_HOSTMAN_DIR:-/mnt/overpower/apps/dev/agl/agl-hostman}"

log() { echo "[propagate-gh-jump] $*"; }

read_token() {
  if command -v gh >/dev/null 2>&1 && gh auth token &>/dev/null 2>&1; then
    gh auth token
    return 0
  fi
  if [[ -n "${GH_TOKEN:-}" ]]; then
    printf '%s\n' "${GH_TOKEN}"
    return 0
  fi
  if [[ -f /root/.config/gh-token ]]; then
    cat /root/.config/gh-token
    return 0
  fi
  python3 <<'PY'
import re, urllib.parse, sys
from pathlib import Path
p = Path("/root/.git-credentials")
if not p.exists():
    sys.exit(1)
line = next((ln for ln in p.read_text().splitlines() if "github.com" in ln), "")
m = re.search(r"https://([^:]+):([^@]+)@github\.com", line)
if not m:
    sys.exit(1)
print(urllib.parse.unquote(m.group(2)))
PY
}

log "garantir gh no jump ${GH_JUMP_HOST}..."
ssh -o BatchMode=yes -o ConnectTimeout=20 "${GH_JUMP_HOST}" \
  'export DEBIAN_FRONTEND=noninteractive; command -v gh >/dev/null || (apt-get update -qq && apt-get install -y -qq gh)'

log "propagar token → jump (sem imprimir)..."
if ! read_token | ssh -o BatchMode=yes -o ConnectTimeout=25 "${GH_JUMP_HOST}" 'gh auth login --with-token'; then
  echo "ERRO: falha ao autenticar gh no jump — token inválido ou rede" >&2
  exit 1
fi

log "validar API no jump..."
ssh -o BatchMode=yes "${GH_JUMP_HOST}" 'gh api user -q .login'

log "instalar wrapper gh local (agldv04)..."
bash "${REPO}/scripts/obsidian/setup-github-gh.sh" --install-only
install -m 0755 "${REPO}/scripts/obsidian/gh-agl-wrapper.sh" /usr/local/bin/gh

log "OK — usar gh no agldv04 (API via jump ${GH_JUMP_HOST})"
