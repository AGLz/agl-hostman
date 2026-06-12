#!/usr/bin/env bash
# Smoke CT193 agl-obsidian — CouchDB, NFS, systemd, Obsidian CLI (se activo).
set -euo pipefail

export PATH="/usr/local/bin:${PATH}"

LLM_WIKI_DIR="${LLM_WIKI_DIR:-/mnt/overpower/apps/dev/agl/llm-wiki}"
COUCHDB_URL="${COUCHDB_URL:-http://127.0.0.1:5984/_up}"
STRICT_CLI="${STRICT_OBSIDIAN_CLI:-0}"
FAIL=0

pass() { echo "  OK   $*"; }
warn() { echo "  WARN $*"; }
fail() { echo "  FAIL $*"; FAIL=1; }

echo "=== verify-obsidian-ct (CT193) ==="

if [[ -f "${LLM_WIKI_DIR}/wiki/index.md" ]]; then
  pass "llm-wiki NFS (${LLM_WIKI_DIR})"
else
  fail "llm-wiki inacessível"
fi

if curl -fsS "${COUCHDB_URL}" >/dev/null 2>&1; then
  pass "CouchDB ${COUCHDB_URL}"
else
  fail "CouchDB não responde em ${COUCHDB_URL}"
fi

if docker ps --format '{{.Names}}' 2>/dev/null | grep -q agl-obsidian-couchdb; then
  pass "container agl-obsidian-couchdb"
else
  warn "container agl-obsidian-couchdb não listado (docker pode estar noutro host)"
fi

for unit in obsidian-hub agl-llm-wiki-bridge agl-llm-wiki-bridge.timer; do
  if systemctl is-active --quiet "${unit}" 2>/dev/null; then
    pass "systemd ${unit}"
  else
    warn "systemd ${unit} não active"
  fi
done

if [[ -x /opt/obsidian/obsidian ]]; then
  pass "binário /opt/obsidian/obsidian"
else
  warn "/opt/obsidian/obsidian ausente — correr install-obsidian-hub.sh"
fi

if command -v obsidian >/dev/null 2>&1; then
  pass "obsidian CLI ($(obsidian version 2>/dev/null | head -1 || echo unknown))"
  if timeout 20 obsidian read path="wiki/Obsidian CT AGL.md" vault=llm-wiki 2>/dev/null | head -c 40 | grep -q .; then
    pass "obsidian read (wiki/Obsidian CT AGL.md)"
  elif timeout 30 obsidian search query="Obsidian" vault=llm-wiki format=text 2>/dev/null | head -c 20 | grep -q .; then
    pass "obsidian search"
  else
    warn "obsidian read/search lento — índice ainda a construir?"
  fi
elif [[ "${STRICT_CLI}" == "1" ]]; then
  fail "obsidian CLI não no PATH"
else
  warn "obsidian CLI não no PATH (activar após primeiro setup do hub)"
fi

if [[ -d "${LLM_WIKI_DIR}/.git" ]]; then
  pass "git repo"
  git -C "${LLM_WIKI_DIR}" remote -v | head -1 || true
else
  fail "sem .git em llm-wiki"
fi

if command -v gh >/dev/null 2>&1; then
  if gh auth status -h github.com &>/dev/null 2>&1; then
    pass "gh auth github.com"
  elif [[ -f /root/.config/gh/hosts.yml ]] && grep -q 'oauth_token:' /root/.config/gh/hosts.yml 2>/dev/null; then
    pass "gh hosts.yml (credenciais locais)"
  else
    warn "gh instalado mas não autenticado — setup-github-gh.sh"
  fi
else
  warn "gh não instalado — bridge git precisa setup-github-gh.sh"
fi

echo ""
if [[ "${FAIL}" -gt 0 ]]; then
  echo "verify-obsidian-ct: FAIL"
  exit 1
fi
echo "verify-obsidian-ct: PASS (WARNs aceitáveis em bootstrap inicial)"
exit 0
