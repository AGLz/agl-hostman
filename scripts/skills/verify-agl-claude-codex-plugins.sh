#!/usr/bin/env bash
# Verifica plugins Claude Code + preparação Codex após install-agl-claude-codex-plugins.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOSTMAN_ROOT="${HOSTMAN_ROOT_OVERRIDE:-$(cd "$SCRIPT_DIR/../.." && pwd)}"

FAIL=0
WARN=0

pass() { echo "  OK   $1"; }
fail() { echo "  FAIL $1"; FAIL=$((FAIL + 1)); }
warn() { echo "  WARN $1"; WARN=$((WARN + 1)); }

claude_plugin_ok() {
  local pattern="$1"
  local label="$2"
  if ! command -v claude >/dev/null 2>&1; then
    warn "$label — claude CLI ausente"
    return 0
  fi
  if claude plugin list 2>/dev/null | awk -v id="$pattern" '
    index($0, id) { block=1 }
    block && /Status: ✔ enabled/ { found=1; exit }
    block && /^  ❯/ && index($0, id) == 0 { block=0 }
    END { exit !found }
  '; then
    pass "$label"
  elif claude plugin list 2>/dev/null | grep -qF "$pattern"; then
    fail "$label (instalado mas disabled)"
  else
    fail "$label (não instalado)"
  fi
}

echo "=== Verify AGL Claude/Codex Plugins ==="
echo "host: $(hostname -s 2>/dev/null || hostname)"
echo ""

echo "-- Claude Code plugins --"
claude_plugin_ok 'superpowers@superpowers-marketplace' 'superpowers marketplace enabled'
claude_plugin_ok 'github@claude-plugins-official' 'github official enabled'
claude_plugin_ok 'context7@claude-plugins-official' 'context7 official enabled'
claude_plugin_ok 'code-review@claude-plugins-official' 'code-review official enabled'
claude_plugin_ok 'commit-commands@claude-plugins-official' 'commit-commands official enabled'
claude_plugin_ok 'feature-dev@claude-plugins-official' 'feature-dev official enabled'
claude_plugin_ok 'frontend-design@claude-plugins-official' 'frontend-design official enabled'

echo ""
echo "-- ECC + open-design --"
if [[ -f "$HOME/.claude/ecc/install-state.json" ]]; then
  pass "ECC Claude (~/.claude/ecc/install-state.json)"
else
  warn "ECC Claude install-state em falta"
fi
if [[ -f "$HOME/.codex/ecc-install-state.json" ]]; then
  pass "ECC Codex (~/.codex/ecc-install-state.json)"
else
  warn "ECC Codex install-state em falta"
fi
if [[ -f "$HOME/.claude/skills/od-design-md/SKILL.md" ]]; then
  pass "open-design od-design-md (claude)"
else
  warn "open-design od-design-md em falta"
fi

echo ""
echo "-- Codex --"
if [[ -f "$HOME/.codex/config.toml" ]]; then
  pass "codex config.toml"
else
  fail "codex config.toml em falta"
fi
if [[ -d "$HOME/.codex/plugins" ]]; then
  pass "codex plugins dir"
else
  fail "codex plugins dir em falta"
fi
if command -v codex >/dev/null 2>&1; then
  pass "codex CLI no PATH"
else
  warn "codex CLI ausente (opcional em hosts só Cursor/Claude)"
fi

echo ""
if [[ "$FAIL" -eq 0 ]]; then
  echo "RESULT: PASS (warn=$WARN)"
  exit 0
fi
echo "RESULT: FAIL (fail=$FAIL warn=$WARN)"
exit 1
