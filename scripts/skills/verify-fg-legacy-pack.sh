#!/usr/bin/env bash
# Verificação unificada: arsenal + six-repos + essentials + runtime Cursor (CT549).
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
  [[ -f "$path/SKILL.md" ]] && pass "$label" || fail "$label"
}

echo "=== fg-legacy pack verify ==="
echo "project: $FG_LEGACY_ROOT"
echo ""

# six-repos (delegar se script existir)
if [[ -x "$FG_LEGACY_ROOT/scripts/skills/verify-six-repos-fg-legacy.sh" ]]; then
  echo "-- six-repos + llm-wiki --"
  FG_LEGACY_ROOT="$FG_LEGACY_ROOT" LLM_WIKI_DIR="$LLM_WIKI_DIR" \
    bash "$FG_LEGACY_ROOT/scripts/skills/verify-six-repos-fg-legacy.sh" || FAIL=$((FAIL + 1))
  echo ""
fi

echo "-- essentials rules --"
for r in learned-memories-fg-legacy.mdc mandatory-delivery-pipeline-fg-legacy.mdc \
  php-security-fg-legacy.mdc common-security-fg-legacy.mdc ponytail.mdc; do
  [[ -f "$FG_LEGACY_ROOT/.cursor/rules/$r" ]] && pass "$r" || fail "$r"
done

echo ""
echo "-- superpowers extra --"
check_skill "root-cause-tracing" "$FG_LEGACY_ROOT/.cursor/skills/root-cause-tracing"
check_skill "defense-in-depth" "$FG_LEGACY_ROOT/.cursor/skills/defense-in-depth"

echo ""
echo "-- fg-native skills --"
check_skill "php-dev-legacy" "$FG_LEGACY_ROOT/.cursor/skills/php-dev-legacy"
check_skill "nginx-csp-triage" "$FG_LEGACY_ROOT/.cursor/skills/nginx-csp-triage"

echo ""
echo "-- Cursor runtime (Node 20) --"
if [[ -x /usr/local/bin/node20 ]]; then
  pass "node20 $(/usr/local/bin/node20 -v 2>/dev/null)"
else
  warn "node20 ausente — bash scripts/maint/install-node20-ct549.sh"
fi
if [[ -f "$FG_LEGACY_ROOT/.cursor/mcp.json" ]]; then
  if grep -q 'npx20\|/usr/local/bin/npx' "$FG_LEGACY_ROOT/.cursor/mcp.json" 2>/dev/null; then
    pass "mcp.json usa npx20"
  elif grep -q llm-wiki-fs "$FG_LEGACY_ROOT/.cursor/mcp.json"; then
    warn "mcp.json sem npx20 explícito"
  else
    fail "mcp.json sem llm-wiki-fs"
  fi
fi

SKILL_COUNT="$(find "$FG_LEGACY_ROOT/.cursor/skills" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l)"
if [[ "$SKILL_COUNT" -gt 45 ]]; then
  warn "skills count alto ($SKILL_COUNT) — considerar prune-fg-legacy-skills.sh"
else
  pass "skills count $SKILL_COUNT"
fi

echo ""
echo "=== Resultado: FAIL=$FAIL WARN=$WARN ==="
[[ "$FAIL" -eq 0 ]]
