#!/usr/bin/env bash
# Verificação pack AGL makemoney01.
set -euo pipefail

MAKEMONEY01_ROOT="${MAKEMONEY01_ROOT:-/mnt/overpower/apps/dev/agl/makemoney01}"
LLM_WIKI_DIR="${LLM_WIKI_DIR:-/mnt/overpower/apps/dev/agl/llm-wiki}"
FAIL=0
WARN=0

pass() { echo "  OK   $1"; }
fail() { echo "  FAIL $1"; FAIL=$((FAIL + 1)); }
warn() { echo "  WARN $1"; WARN=$((WARN + 1)); }

check_skill() {
  [[ -f "$1/SKILL.md" ]] && pass "$2" || fail "$2"
}

echo "=== makemoney01 AGL pack verify ==="
echo "project: $MAKEMONEY01_ROOT"
echo ""

[[ -f "$LLM_WIKI_DIR/wiki/index.md" ]] && pass "llm-wiki vault" || fail "llm-wiki vault"
[[ -f "$LLM_WIKI_DIR/wiki/makemoney01.md" ]] && pass "wiki/makemoney01.md" || warn "wiki/makemoney01.md"

echo ""
echo "-- rules --"
for r in makemoney01-project.mdc learned-memories.mdc llm-wiki-second-brain.mdc \
  mandatory-delivery-pipeline.mdc ponytail.mdc karpathy-skills.mdc \
  self-improve.mdc prompt-improve.mdc; do
  [[ -f "$MAKEMONEY01_ROOT/.cursor/rules/$r" ]] && pass "$r" || fail "$r"
done

echo ""
echo "-- MCP + ingest --"
grep -q llm-wiki-fs "$MAKEMONEY01_ROOT/.cursor/mcp.json" 2>/dev/null && pass "MCP llm-wiki-fs" || fail "MCP llm-wiki-fs"
check_skill "$MAKEMONEY01_ROOT/.cursor/skills/llm-wiki-ingest" "llm-wiki-ingest"
check_skill "$MAKEMONEY01_ROOT/.cursor/skills/reflect-yourself" "reflect-yourself"

echo ""
echo "-- six repos --"
check_skill "$MAKEMONEY01_ROOT/.cursor/skills/humanizer" "humanizer"
check_skill "$MAKEMONEY01_ROOT/.cursor/skills/fact-check" "fact-check"
check_skill "$MAKEMONEY01_ROOT/.cursor/skills/prompt-improver" "prompt-improver"
check_skill "$MAKEMONEY01_ROOT/.cursor/skills/obsidian-cli" "obsidian-cli"
check_skill "$MAKEMONEY01_ROOT/.cursor/skills/using-superpowers" "using-superpowers"

echo ""
echo "-- makemoney native --"
check_skill "$MAKEMONEY01_ROOT/.cursor/skills/makemoney-pipeline" "makemoney-pipeline"
[[ -x "$MAKEMONEY01_ROOT/scripts/wiki/graphify-makemoney.sh" ]] && pass "graphify-makemoney.sh" || fail "graphify-makemoney.sh"
[[ -f "$MAKEMONEY01_ROOT/data/graph/graph.json" ]] && pass "data/graph/graph.json" || warn "graph.json (correr graphify)"

echo ""
echo "-- pipeline data --"
[[ -f "$MAKEMONEY01_ROOT/data/pipeline/board.json" ]] && pass "pipeline/board.json" || warn "board.json"
[[ -d "$MAKEMONEY01_ROOT/wiki-ingest" ]] && pass "wiki-ingest/" || fail "wiki-ingest/"

echo ""
echo "=== Resultado: FAIL=$FAIL WARN=$WARN ==="
[[ "$FAIL" -eq 0 ]]
