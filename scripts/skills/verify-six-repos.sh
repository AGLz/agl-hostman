#!/usr/bin/env bash
# Verifica instalação dos 6 repos (plano Six Repos) nos harnesses AGL.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOSTMAN_ROOT="${HOSTMAN_ROOT_OVERRIDE:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
LLM_WIKI_DIR="${LLM_WIKI_DIR:-/mnt/overpower/apps/dev/agl/llm-wiki}"
SKIP_LLM_WIKI="${SKIP_LLM_WIKI:-0}"

STRICT_OBSIDIAN_CLI="${STRICT_OBSIDIAN_CLI:-0}"
FAIL=0
WARN=0

pass() { echo "  OK   $1"; }
fail() { echo "  FAIL $1"; FAIL=$((FAIL + 1)); }
warn() { echo "  WARN $1"; WARN=$((WARN + 1)); }

check_skill() {
  local label="$1"
  local path="$2"
  if [[ -f "$path/SKILL.md" ]]; then
    pass "$label -> $path/SKILL.md"
  else
    fail "$label -> SKILL.md em falta ($path)"
  fi
}

echo "=== Six Repos Verify ==="
echo "hostman: $HOSTMAN_ROOT"
echo "llm-wiki: $LLM_WIKI_DIR"
echo ""

echo "-- 1. superpowers --"
if [[ -d "$HOME/.claude/plugins/cache/superpowers-marketplace/superpowers" ]]; then
  pass "Claude plugin superpowers cache"
else
  warn "Claude plugin superpowers não encontrado (opcional se skills copiadas)"
fi
check_skill "superpowers/using-superpowers (claude)" "$HOME/.claude/skills/using-superpowers"

echo ""
echo "-- 2. everything-claude-code (ECC) --"
if [[ -f "$HOME/.claude/ecc/install-state.json" ]]; then
  pass "ECC Claude (~/.claude/ecc/install-state.json)"
elif [[ -f "$HOME/.claude/.ecc-install-pending" ]]; then
  warn "ECC pendente (legacy .ecc-install-pending — correr sync-six-repos --repo ecc)"
else
  warn "ECC Claude não detectado"
fi
if [[ -f "$HOME/.codex/ecc-install-state.json" ]]; then
  pass "ECC Codex (~/.codex/ecc-install-state.json)"
else
  warn "ECC Codex não detectado"
fi
if [[ -f "$HOSTMAN_ROOT/.cursor/ecc-install-state.json" ]]; then
  pass "ECC Cursor project (agl-hostman .cursor/ecc-install-state.json)"
else
  warn "ECC Cursor project não detectado em agl-hostman"
fi
if [[ -f "$LLM_WIKI_DIR/.claude/ecc/install-state.json" ]]; then
  pass "ECC llm-wiki claude-project"
else
  warn "ECC llm-wiki claude-project não detectado (opcional)"
fi

echo ""
echo "-- 3. ruflo --"
if [[ -d "$HOSTMAN_ROOT/.claude-flow" ]]; then
  pass "agl-hostman .claude-flow/"
else
  if [[ "$SKIP_LLM_WIKI" == "1" ]]; then
    warn "agl-hostman .claude-flow/ em falta (wk45 clone parcial)"
  else
    fail "agl-hostman .claude-flow/ em falta"
  fi
fi
if command -v ruflo >/dev/null 2>&1 || npx ruflo@latest --version >/dev/null 2>&1; then
  pass "ruflo CLI (global ou npx)"
else
  warn "ruflo CLI não no PATH — npx ruflo@latest ainda funciona"
fi

echo ""
echo "-- 4. open-design --"
OPEN_DESIGN_DIR="${OPEN_DESIGN_DIR:-$HOME/dev/open-design}"
if [[ -d "$OPEN_DESIGN_DIR/.git" ]]; then
  pass "open-design clone $OPEN_DESIGN_DIR"
else
  warn "open-design não clonado (correr sync-six-repos --repo open-design)"
fi
if [[ -f "$OPEN_DESIGN_DIR/.agl-sync-state.json" ]]; then
  pass "open-design .agl-sync-state.json"
else
  warn "open-design sync state em falta"
fi
check_skill "open-design/od-design-md (claude)" "$HOME/.claude/skills/od-design-md"
check_skill "open-design/od-frontend-design (cursor)" "$HOME/.cursor/skills/od-frontend-design"
check_skill "open-design/od-shadcn-ui (codex)" "$HOME/.codex/skills/od-shadcn-ui"

echo ""
echo "-- 5. Obsidian-CLI-skill --"
check_skill "obsidian-cli (claude)" "$HOME/.claude/skills/obsidian-cli"
check_skill "obsidian-cli (cursor)" "$HOME/.cursor/skills/obsidian-cli"
check_skill "obsidian-cli (codex)" "$HOME/.codex/skills/obsidian-cli"
check_skill "obsidian-cli (verdent)" "$HOME/.verdent/skills/obsidian-cli"
if [[ "$SKIP_LLM_WIKI" != "1" ]]; then
  check_skill "obsidian-cli (llm-wiki)" "$LLM_WIKI_DIR/.claude/skills/obsidian-cli"
  check_skill "obsidian-cli (hostman)" "$HOSTMAN_ROOT/.claude/skills/obsidian-cli"

  if [[ -f "$LLM_WIKI_DIR/.claude/settings.json" ]]; then
    pass "llm-wiki .claude/settings.json"
  else
    warn "llm-wiki .claude/settings.json em falta"
  fi

  if [[ -f "$LLM_WIKI_DIR/wiki/Obsidian CLI Skill.md" ]]; then
    pass "llm-wiki wiki/Obsidian CLI Skill.md"
  else
    warn "Página wiki Obsidian CLI Skill em falta"
  fi
else
  warn "SKIP_LLM_WIKI=1 — saltar checks llm-wiki project/vault"
fi

if command -v obsidian >/dev/null 2>&1; then
  pass "obsidian CLI no PATH ($(obsidian version 2>/dev/null | head -1))"
else
  if [[ "$STRICT_OBSIDIAN_CLI" == "1" ]]; then
    fail "obsidian CLI não no PATH (Obsidian 1.12+ desktop + CLI activo)"
  else
    warn "obsidian CLI não no PATH — skill instalada; activar CLI no Obsidian desktop"
  fi
fi

echo ""
echo "-- 6. karpathy-skills --"
if [[ -f "$HOSTMAN_ROOT/.cursor/rules/karpathy-skills.mdc" ]]; then
  pass "agl-hostman karpathy-skills.mdc"
else
  if [[ "$SKIP_LLM_WIKI" == "1" ]]; then
    warn "karpathy-skills.mdc em falta (clone wk45 pode estar desactualizado)"
  else
    fail "karpathy-skills.mdc em falta"
  fi
fi
if [[ -f "$HOSTMAN_ROOT/CLAUDE.md" ]] && grep -q "Karpathy Skills" "$HOSTMAN_ROOT/CLAUDE.md"; then
  pass "agl-hostman CLAUDE.md Karpathy section"
else
  warn "CLAUDE.md sem secção Karpathy"
fi
if [[ -f "$HOME/.claude/skills/andrej-karpathy-skills/SKILL.md" ]]; then
  pass "karpathy skill (claude)"
else
  warn "karpathy skill plugin em falta — CLAUDE.md + mdc cobrem parcialmente"
fi

echo ""
echo "-- 7. content-skills (humanizer, fact-check, prompt-improver) --"
if [[ -f "$HOSTMAN_ROOT/.cursor/content-skills-sync-state.json" ]]; then
  pass "content-skills sync state (.cursor/content-skills-sync-state.json)"
else
  warn "content-skills sync state em falta (correr sync-six-repos --repo content-skills)"
fi
check_skill "humanizer (hostman-cursor)" "$HOSTMAN_ROOT/.cursor/skills/humanizer"
check_skill "fact-check (hostman-cursor)" "$HOSTMAN_ROOT/.cursor/skills/fact-check"
check_skill "prompt-improver (hostman-cursor)" "$HOSTMAN_ROOT/.cursor/skills/prompt-improver"
if [[ -f "$HOME/.claude/skills/humanizer/SKILL.md" ]]; then
  pass "humanizer (claude global)"
else
  warn "humanizer (claude global) — opcional; correr sync-six-repos --repo content-skills"
fi
if [[ -f "$HOME/.claude/skills/fact-check/SKILL.md" ]]; then
  pass "fact-check (claude global)"
else
  warn "fact-check (claude global) — opcional; correr sync-six-repos --repo content-skills"
fi
if [[ -f "$HOME/.claude/skills/prompt-improver/SKILL.md" ]]; then
  pass "prompt-improver (claude global)"
else
  warn "prompt-improver (claude global) — opcional; correr sync-six-repos --repo content-skills"
fi
if [[ -f "$HOSTMAN_ROOT/.cursor/skills/fact-check/educational-tips.md" ]]; then
  pass "fact-check educational-tips.md (hostman-cursor)"
else
  warn "fact-check educational-tips.md em falta no project .cursor/skills"
fi
if [[ -d "$HOSTMAN_ROOT/.cursor/skills/prompt-improver/references" ]]; then
  pass "prompt-improver references/ (hostman-cursor)"
else
  warn "prompt-improver references/ em falta — skill parcial"
fi

echo ""
echo "-- 8. llm-wiki segundo cérebro (agl-hostman Cursor) --"
if [[ -f "$HOSTMAN_ROOT/.cursor/rules/llm-wiki-second-brain.mdc" ]]; then
  pass "agl-hostman .cursor/rules/llm-wiki-second-brain.mdc"
else
  fail "llm-wiki-second-brain.mdc em falta"
fi
if [[ -f "$HOSTMAN_ROOT/.cursor/skills/obsidian-cli/SKILL.md" ]]; then
  pass "obsidian-cli (hostman-cursor) -> $HOSTMAN_ROOT/.cursor/skills/obsidian-cli/SKILL.md"
else
  warn "obsidian-cli em falta em .cursor/skills/ — correr sync-six-repos --repo obsidian"
fi
if [[ -f "$HOSTMAN_ROOT/.cursor/mcp.json" ]]; then
  if grep -q '"llm-wiki-fs"' "$HOSTMAN_ROOT/.cursor/mcp.json" \
    && grep -q 'llm-wiki/wiki' "$HOSTMAN_ROOT/.cursor/mcp.json"; then
    pass "agl-hostman MCP llm-wiki-fs"
  else
    fail "MCP llm-wiki-fs em falta em .cursor/mcp.json"
  fi
  if grep -q '"archon"' "$HOSTMAN_ROOT/.cursor/mcp.json"; then
    warn "Archon MCP ainda em .cursor/mcp.json — cutover para llm-wiki pendente"
  else
    pass "Archon MCP removido de .cursor/mcp.json"
  fi
else
  fail ".cursor/mcp.json em falta"
fi
if [[ -x "$HOSTMAN_ROOT/scripts/skills/setup-obsidian-cli-llm-wiki.sh" ]]; then
  pass "setup-obsidian-cli-llm-wiki.sh executável"
else
  warn "setup-obsidian-cli-llm-wiki.sh em falta ou não executável"
fi

echo ""
echo "-- 9. mandatory delivery pipeline (global) --"
if [[ -f "$HOME/.cursor/rules/mandatory-delivery-pipeline.mdc" ]]; then
  pass "Cursor global mandatory-delivery-pipeline.mdc"
else
  warn "Cursor global delivery pipeline em falta — correr install-global-delivery-rules.sh"
fi
if [[ -f "$HOSTMAN_ROOT/.cursor/rules/mandatory-delivery-pipeline.mdc" ]]; then
  pass "agl-hostman mandatory-delivery-pipeline.mdc"
else
  warn "project mandatory-delivery-pipeline.mdc em falta"
fi
if [[ -f "$HOME/.claude/rules/mandatory-delivery-pipeline.md" ]]; then
  pass "Claude user mandatory-delivery-pipeline.md"
else
  warn "Claude delivery pipeline em falta — correr install-global-delivery-rules.sh"
fi

echo ""
if [[ "$SKIP_LLM_WIKI" != "1" ]]; then
  echo "-- llm-wiki vault --"
  if [[ -f "$LLM_WIKI_DIR/wiki/index.md" ]]; then
    pass "llm-wiki wiki/index.md"
  else
    fail "llm-wiki vault inacessível"
  fi
fi

echo ""
echo "=== Resultado: FAIL=$FAIL WARN=$WARN ==="
if [[ "$FAIL" -gt 0 ]]; then
  exit 1
fi
exit 0
