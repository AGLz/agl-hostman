#!/usr/bin/env bash
# Smoke Obsidian CLI no vault llm-wiki (Fase 5).
# STRICT_OBSIDIAN_CLI=1 → exit 1 se obsidian não estiver no PATH.
set -euo pipefail

LLM_WIKI_DIR="${LLM_WIKI_DIR:-/mnt/overpower/apps/dev/agl/llm-wiki}"
STRICT="${STRICT_OBSIDIAN_CLI:-0}"
FAIL=0

warn() { echo "  WARN $*"; }
fail() { echo "  FAIL $*"; FAIL=1; }
pass() { echo "  OK   $*"; }

echo "=== Smoke Obsidian CLI (llm-wiki) ==="
echo "vault: $LLM_WIKI_DIR"
echo ""

if [[ ! -f "$LLM_WIKI_DIR/wiki/index.md" ]]; then
  fail "wiki/index.md inacessível"
  exit 1
fi
pass "wiki/index.md"

if ! command -v obsidian >/dev/null 2>&1; then
  if [[ "$STRICT" == "1" ]]; then
    fail "obsidian CLI não no PATH (Obsidian Desktop 1.12+ com CLI activo)"
    exit 1
  fi
  warn "obsidian CLI não no PATH — activar no Obsidian desktop; smoke CLI adiado"
  exit 0
fi

pass "obsidian no PATH ($(obsidian version 2>/dev/null | head -1 || echo version-unknown))"

if obsidian search query="Six Repos" format=json 2>/dev/null | head -c 200 | grep -q .; then
  pass "search Six Repos"
else
  warn "search Six Repos sem resultados (vault default pode estar errado)"
fi

MARKER="smoke-six-repos-$(date +%Y%m%d-%H%M%S)"
if obsidian daily:append content="- [ ] $MARKER" 2>/dev/null; then
  pass "daily:append ($MARKER)"
else
  warn "daily:append falhou — verificar vault default (obsidian set-default)"
fi

echo ""
if [[ "$FAIL" -gt 0 ]]; then
  exit 1
fi
echo "Smoke Obsidian: PASS (ou WARN se CLI parcial)"
exit 0
