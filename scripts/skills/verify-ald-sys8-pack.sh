#!/usr/bin/env bash
# Verificação pack AGL para ald-sys8 (segundo cérebro + Six Repos + regras).
set -euo pipefail

ALD_SYS8_ROOT="${ALD_SYS8_ROOT:-/mnt/overpower/apps/dev/ald/ald-sys8}"
LLM_WIKI_DIR="${LLM_WIKI_DIR:-/mnt/overpower/apps/dev/agl/llm-wiki}"
FAIL=0
WARN=0

pass() { echo "  OK   $1"; }
fail() { echo "  FAIL $1"; FAIL=$((FAIL + 1)); }
warn() { echo "  WARN $1"; WARN=$((WARN + 1)); }

check_skill() {
  local label="$1" path="$2"
  [[ -f "$path/SKILL.md" ]] && pass "$label" || fail "$label — SKILL.md em falta ($path)"
}

echo "=== ald-sys8 AGL pack verify ==="
echo "project: $ALD_SYS8_ROOT"
echo "llm-wiki: $LLM_WIKI_DIR"
echo ""

echo "-- llm-wiki vault --"
[[ -f "$LLM_WIKI_DIR/wiki/index.md" ]] && pass "wiki/index.md" || fail "llm-wiki vault inacessível"

echo ""
echo "-- core rules --"
for r in learned-memories.mdc llm-wiki-second-brain.mdc mandatory-delivery-pipeline.mdc \
  ponytail.mdc karpathy-skills.mdc; do
  [[ -f "$ALD_SYS8_ROOT/.cursor/rules/$r" ]] && pass "$r" || fail "$r"
done

echo ""
echo "-- second brain --"
if [[ -f "$ALD_SYS8_ROOT/.cursor/mcp.json" ]] && grep -q llm-wiki-fs "$ALD_SYS8_ROOT/.cursor/mcp.json"; then
  pass "MCP llm-wiki-fs (merge)"
else
  fail "MCP llm-wiki-fs em .cursor/mcp.json"
fi
check_skill "llm-wiki-ingest" "$ALD_SYS8_ROOT/.cursor/skills/llm-wiki-ingest"

echo ""
echo "-- six repos subset --"
check_skill "obsidian-cli" "$ALD_SYS8_ROOT/.cursor/skills/obsidian-cli"
check_skill "humanizer" "$ALD_SYS8_ROOT/.cursor/skills/humanizer"
check_skill "fact-check" "$ALD_SYS8_ROOT/.cursor/skills/fact-check"
check_skill "prompt-improver" "$ALD_SYS8_ROOT/.cursor/skills/prompt-improver"
check_skill "using-superpowers" "$ALD_SYS8_ROOT/.cursor/skills/using-superpowers"
check_skill "systematic-debugging" "$ALD_SYS8_ROOT/.cursor/skills/systematic-debugging"
check_skill "verification-before-completion" "$ALD_SYS8_ROOT/.cursor/skills/verification-before-completion"
check_skill "root-cause-tracing" "$ALD_SYS8_ROOT/.cursor/skills/root-cause-tracing"
[[ -f "$ALD_SYS8_ROOT/.cursor/content-skills-sync-state.json" ]] && pass "content-skills-sync-state.json" || warn "content-skills state em falta"

echo ""
echo "-- arsenal subset --"
check_skill "improve" "$ALD_SYS8_ROOT/.cursor/skills/improve"
check_skill "drawio-skill" "$ALD_SYS8_ROOT/.cursor/skills/drawio-skill"
if [[ -f "$ALD_SYS8_ROOT/.cursor/skills/agl-architecture-diagram/SKILL.md" ]]; then
  pass "agl-architecture-diagram"
else
  warn "agl-architecture-diagram em falta (opcional)"
fi

echo ""
echo "-- ald-native (não sobrescrever) --"
check_skill "ald-migration-parity" "$ALD_SYS8_ROOT/.cursor/skills/ald-migration-parity"
check_skill "ald-legacy-sqlserver" "$ALD_SYS8_ROOT/.cursor/skills/ald-legacy-sqlserver"
[[ -f "$ALD_SYS8_ROOT/.cursor/rules/ald-sys8-project.mdc" ]] && pass "ald-sys8-project.mdc" || fail "ald-sys8-project.mdc"
[[ -f "$ALD_SYS8_ROOT/.cursor/rules/ecc-skills-routing.mdc" ]] && pass "ecc-skills-routing.mdc" || warn "ecc-skills-routing em falta"

echo ""
echo "-- MCP existentes (preservados) --"
for srv in laraplugins task-master-ai github context7 playwright; do
  if grep -q "\"$srv\"" "$ALD_SYS8_ROOT/.cursor/mcp.json" 2>/dev/null; then
    pass "MCP $srv preservado"
  else
    warn "MCP $srv ausente (pode ser intencional)"
  fi
done

echo ""
echo "=== Resultado: FAIL=$FAIL WARN=$WARN ==="
[[ "$FAIL" -eq 0 ]]
