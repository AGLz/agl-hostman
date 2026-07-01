#!/usr/bin/env bash
# Instala Node.js 20 LTS no CT fg-legacy (549) para Cursor MCP, npx e video-transcript.
#
# Uso (root no CT549):
#   bash scripts/maint/install-node20-ct549.sh
#   bash scripts/maint/install-node20-ct549.sh --check-only
#
# Cria symlinks em /usr/local/bin: node20, npm20, npx20 (não remove /usr/bin/node do Ubuntu).
set -euo pipefail

NODE_MAJOR="${NODE_MAJOR:-20}"
CHECK_ONLY=0
PREFIX="/usr/local"

log() { printf '[node20-ct549] %s\n' "$*"; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --check-only) CHECK_ONLY=1; shift ;;
    -h|--help)
      echo "Usage: $0 [--check-only]"
      exit 0
      ;;
    *) echo "Opção desconhecida: $1" >&2; exit 2 ;;
  esac
done

resolve_npx20() {
  if [[ -x "${PREFIX}/bin/npx20" ]]; then
    echo "${PREFIX}/bin/npx20"
  elif [[ -x "${PREFIX}/bin/npx" ]] && "${PREFIX}/bin/node" -v 2>/dev/null | grep -qE '^v(1[89]|[2-9][0-9])'; then
    echo "${PREFIX}/bin/npx"
  else
    echo ""
  fi
}

if [[ "$CHECK_ONLY" == "1" ]]; then
  np="$(resolve_npx20)"
  if [[ -n "$np" ]]; then
    log "OK npx Cursor: $np ($($np --version 2>/dev/null || echo '?'))"
    "${PREFIX}/bin/node20" -v 2>/dev/null || "${PREFIX}/bin/node" -v
    exit 0
  fi
  log "Node 20 LTS não instalado (esperado ${PREFIX}/bin/npx20)"
  exit 1
fi

if [[ -x "${PREFIX}/bin/node20" ]]; then
  log "já instalado: $(${PREFIX}/bin/node20 -v)"
  exit 0
fi

export DEBIAN_FRONTEND=noninteractive
log "dependências base"
apt-get update -qq
apt-get install -y -qq ca-certificates curl gnupg

log "NodeSource ${NODE_MAJOR}.x"
# Reason: libnode-dev (Ubuntu node 12) bloqueia overwrite do pacote nodesource
apt-get remove -y -qq libnode-dev nodejs-doc 2>/dev/null || true
apt-get autoremove -y -qq 2>/dev/null || true
install -d -m 0755 /etc/apt/keyrings
if [[ ! -f /etc/apt/keyrings/nodesource.gpg ]]; then
  curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key \
    | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg
fi
echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_${NODE_MAJOR}.x nodistro main" \
  >/etc/apt/sources.list.d/nodesource.list
apt-get update -qq
apt-get install -y -qq nodejs

# NodeSource instala em /usr/bin — preservar nome node20 para MCP explícito
NODE_BIN="$(command -v node)"
NPM_BIN="$(command -v npm)"
NPX_BIN="$(command -v npx)"
[[ -x "$NODE_BIN" ]] || { log "node não encontrado após install"; exit 1; }

ln -sf "$NODE_BIN" "${PREFIX}/bin/node20"
ln -sf "$NPM_BIN" "${PREFIX}/bin/npm20"
ln -sf "$NPX_BIN" "${PREFIX}/bin/npx20"

log "versões:"
"${PREFIX}/bin/node20" -v
"${PREFIX}/bin/npm20" -v
"${PREFIX}/bin/npx20" -v

log "OK Node ${NODE_MAJOR} — usar npx20 no .cursor/mcp.json"
