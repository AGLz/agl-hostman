#!/usr/bin/env bash
# Verifica symlinks dotfiles + live sync AGL.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOSTMAN_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

AGL_HOME_SYNC_ROOT="${AGL_HOME_SYNC_ROOT:-/mnt/overpower/apps/dev/agl/agl-home-sync}"
AGL_HOME_USER="${AGL_HOME_USER:-linux-root}"
LIVE_ROOT="$AGL_HOME_SYNC_ROOT/$AGL_HOME_USER"

FAIL=0
WARN=0

pass() { echo "  OK   $1"; }
fail() { echo "  FAIL $1"; FAIL=$((FAIL + 1)); }
warn() { echo "  WARN $1"; WARN=$((WARN + 1)); }

check_symlink() {
  local local_path="$1"
  local expected_target="$2"

  if [[ ! -L "$local_path" ]]; then
    fail "não é symlink: $local_path"
    return
  fi
  local actual
  actual="$(readlink -f "$local_path" 2>/dev/null || readlink "$local_path")"
  local exp
  exp="$(readlink -f "$expected_target" 2>/dev/null || echo "$expected_target")"
  if [[ "$actual" == "$exp" ]] || [[ "$(readlink "$local_path")" == "$expected_target" ]]; then
    pass "$local_path -> $expected_target"
  else
    warn "$local_path aponta para $actual (esperado ~$expected_target)"
  fi
}

check_no_secrets_in_git() {
  local f="$1"
  if [[ ! -f "$f" ]]; then
    return
  fi
  if grep -qE '(api[_-]?key|secret|password|Bearer )' "$f" 2>/dev/null; then
    if grep -qE '\$\{|example|YOUR_|placeholder' "$f" 2>/dev/null; then
      pass "template sem secrets hardcoded: $f"
    else
      fail "possível secret em ficheiro Git: $f"
    fi
  else
    pass "sem padrões secret óbvios: $f"
  fi
}

echo "=== Verify AGL Home Sync ==="
echo "host: $(hostname -s 2>/dev/null || hostname)"
echo "live: $LIVE_ROOT"
echo ""

echo "-- NFS live root --"
if [[ -d "$AGL_HOME_SYNC_ROOT" ]]; then
  pass "AGL_HOME_SYNC_ROOT existe ($AGL_HOME_SYNC_ROOT)"
else
  fail "AGL_HOME_SYNC_ROOT em falta ($AGL_HOME_SYNC_ROOT)"
fi
if [[ -d "$LIVE_ROOT" ]]; then
  pass "LIVE_ROOT existe"
else
  fail "LIVE_ROOT em falta ($LIVE_ROOT)"
fi

echo ""
echo "-- Live symlinks --"
check_symlink "$HOME/.config/Cursor/User/globalStorage" "$LIVE_ROOT/cursor/globalStorage"
check_symlink "$HOME/.cursor/chats" "$LIVE_ROOT/cursor/dot-cursor/chats"
check_symlink "$HOME/.cursor/projects" "$LIVE_ROOT/cursor/dot-cursor/projects"
check_symlink "$HOME/.claude/file-history" "$LIVE_ROOT/claude/file-history"
if [[ -L "$HOME/.claude/history.jsonl" ]]; then
  check_symlink "$HOME/.claude/history.jsonl" "$LIVE_ROOT/claude/history.jsonl"
elif [[ -f "$LIVE_ROOT/claude/history.jsonl" ]]; then
  pass "history.jsonl em live (symlink opcional)"
else
  warn "history.jsonl ainda não migrado"
fi

echo ""
echo "-- Git symlinks --"
check_symlink "$HOME/.config/Cursor/User/settings.json" "$HOSTMAN_ROOT/config/dotfiles/linux/cursor/User/settings.json"
check_symlink "$HOME/.claude/settings.json" "$HOSTMAN_ROOT/config/dotfiles/linux/claude/settings.json"
check_symlink "$HOME/.config/agl/env.sh" "$HOSTMAN_ROOT/config/dotfiles/linux/shell/agl-env.sh"

echo ""
echo "-- Segurança Git dotfiles --"
check_no_secrets_in_git "$HOSTMAN_ROOT/config/dotfiles/linux/cursor/dot-cursor/mcp.json.example"
check_no_secrets_in_git "$HOSTMAN_ROOT/config/dotfiles/linux/claude/settings.json"

echo ""
echo "-- Ficheiros locais (não partilhar) --"
if [[ -f "$HOME/.claude/.credentials.json" && ! -L "$HOME/.claude/.credentials.json" ]]; then
  pass ".credentials.json local"
else
  warn ".credentials.json ausente ou symlink (deve ser local)"
fi

echo ""
if [[ "$FAIL" -gt 0 ]]; then
  echo "RESULT: FAIL ($FAIL erros, $WARN avisos)"
  exit 1
fi
echo "RESULT: OK ($WARN avisos)"
exit 0
