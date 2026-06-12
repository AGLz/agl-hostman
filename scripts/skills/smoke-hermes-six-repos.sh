#!/usr/bin/env bash
# Smoke CT188 Hermes — llm-wiki Six Repos (leitura; sem superpowers no contentor).
# Correr no CT188 (root) ou via: ssh AGLSRV1 'pct exec 188 -- bash -s' < smoke-hermes-six-repos.sh
set -euo pipefail

WIKI_HOST="${WIKI_HOST:-/opt/agl-llm-wiki}"
WIKI_CONTAINER="${WIKI_CONTAINER:-/opt/llm-wiki}"
HERMES_CONTAINER="${HERMES_CONTAINER:-agl-hermes-jarvis}"
FAIL=0

ok() { echo "  OK   $*"; }
bad() { echo "  FAIL $*"; FAIL=1; }

echo "=== Smoke Hermes Six Repos (CT188) ==="

PAGES=(
  "Plano Six Repos Multi-Agente.md"
  "Superpowers.md"
  "Everything Claude Code (ECC).md"
  "Open Design.md"
  "Obsidian CLI Skill.md"
  "Obsidian CT AGL.md"
  "Karpathy Skills.md"
  "Unraid.md"
  "AGLSRV5 Unraid VM127.md"
)

if [[ -r "$WIKI_HOST/wiki/index.md" ]]; then
  ok "host wiki index ($WIKI_HOST)"
else
  bad "host wiki index ($WIKI_HOST)"
fi

for page in "${PAGES[@]}"; do
  if [[ -r "$WIKI_HOST/wiki/$page" ]]; then
    ok "host wiki/$page"
  else
    bad "host wiki/$page"
  fi
done

if command -v docker >/dev/null 2>&1; then
  if docker exec "$HERMES_CONTAINER" test -r "$WIKI_CONTAINER/wiki/index.md" 2>/dev/null; then
    ok "docker $HERMES_CONTAINER → $WIKI_CONTAINER/wiki/index.md"
  else
    bad "docker mount $HERMES_CONTAINER → $WIKI_CONTAINER"
  fi
  for page in "${PAGES[@]}"; do
    if docker exec "$HERMES_CONTAINER" test -r "$WIKI_CONTAINER/wiki/$page" 2>/dev/null; then
      ok "docker wiki/$page"
    else
      bad "docker wiki/$page"
    fi
  done
else
  echo "  WARN docker não disponível — saltar checks contentor"
fi

echo ""
if [[ "$FAIL" -gt 0 ]]; then
  echo "Smoke Hermes Six Repos: FAIL"
  exit 1
fi
echo "Smoke Hermes Six Repos: PASS"
exit 0
