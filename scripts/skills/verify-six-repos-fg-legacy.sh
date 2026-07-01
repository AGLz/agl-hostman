#!/usr/bin/env bash
# Verifica Six Repos + llm-wiki no fg_antigo (CT549).
set -euo pipefail

FG_LEGACY_ROOT="${FG_LEGACY_ROOT:-/var/www/fg_antigo}"
LLM_WIKI_DIR="${LLM_WIKI_DIR:-/opt/agl-llm-wiki}"
FAIL=0
WARN=0

pass() { echo "  OK   $1"; }
fail() { echo "  FAIL $1"; FAIL=$((FAIL + 1)); }
warn() { echo "  WARN $1"; WARN=$((WARN + 1)); }

check_skill() {
  local label="$1" path="$2"
  if [[ -f "$path/SKILL.md" ]]; then
    pass "$label"
  else
    fail "$label — SKILL.md em falta ($path)"
  fi
}

echo "=== Six Repos + Second Brain Verify (fg-legacy) ==="
echo "project: $FG_LEGACY_ROOT"
echo "llm-wiki: $LLM_WIKI_DIR"
echo ""

echo "-- llm-wiki vault --"
if [[ -f "$LLM_WIKI_DIR/wiki/index.md" ]]; then
  pass "wiki/index.md"
else
  fail "llm-wiki vault inacessível"
fi

echo ""
echo "-- second brain (project) --"
[[ -f "$FG_LEGACY_ROOT/.cursor/rules/llm-wiki-second-brain.mdc" ]] && pass "llm-wiki-second-brain.mdc" || fail "llm-wiki-second-brain.mdc"
if [[ -f "$FG_LEGACY_ROOT/.cursor/mcp.json" ]] && grep -q llm-wiki-fs "$FG_LEGACY_ROOT/.cursor/mcp.json"; then
  pass "MCP llm-wiki-fs"
else
  fail "MCP llm-wiki-fs em .cursor/mcp.json"
fi
check_skill "llm-wiki-ingest" "$FG_LEGACY_ROOT/.cursor/skills/llm-wiki-ingest"

echo ""
echo "-- six repos (subset CT549) --"
check_skill "obsidian-cli" "$FG_LEGACY_ROOT/.cursor/skills/obsidian-cli"
check_skill "humanizer" "$FG_LEGACY_ROOT/.cursor/skills/humanizer"
check_skill "fact-check" "$FG_LEGACY_ROOT/.cursor/skills/fact-check"
check_skill "prompt-improver" "$FG_LEGACY_ROOT/.cursor/skills/prompt-improver"
check_skill "using-superpowers" "$FG_LEGACY_ROOT/.cursor/skills/using-superpowers"
[[ -f "$FG_LEGACY_ROOT/.cursor/content-skills-sync-state.json" ]] && pass "content-skills-sync-state.json" || warn "content-skills state em falta"

echo ""
echo "-- arsenal (cross-check) --"
[[ -f "$FG_LEGACY_ROOT/.cursor/rules/ponytail.mdc" ]] && pass "ponytail.mdc" || warn "ponytail.mdc em falta"
check_skill "improve" "$FG_LEGACY_ROOT/.cursor/skills/improve"

echo ""
echo "=== Resultado: FAIL=$FAIL WARN=$WARN ==="
[[ "$FAIL" -eq 0 ]]
