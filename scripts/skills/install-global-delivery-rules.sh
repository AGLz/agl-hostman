#!/usr/bin/env bash
# Instala regra global "mandatory-delivery-pipeline" em Cursor, Claude Code e Codex.
# Propagável via install-post-skills-claude-code.sh e propagate-six-repos.sh (agldv*).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOSTMAN_ROOT="${HOSTMAN_ROOT_OVERRIDE:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
TEMPLATE="$SCRIPT_DIR/templates/global-agent-rules/mandatory-delivery-pipeline.mdc"
CLAUDE_SNIPPET="$SCRIPT_DIR/templates/global-agent-rules/mandatory-delivery-pipeline-claude.md"

log() { echo "[INFO] $*"; }
ok() { echo "[OK] $*"; }
warn() { echo "[WARN] $*"; }

if [[ ! -f "$TEMPLATE" ]]; then
  echo "FAIL: template em falta: $TEMPLATE" >&2
  exit 1
fi

install_cursor_global() {
  local dest_dir="$HOME/.cursor/rules"
  mkdir -p "$dest_dir"
  cp "$TEMPLATE" "$dest_dir/mandatory-delivery-pipeline.mdc"
  ok "Cursor global: $dest_dir/mandatory-delivery-pipeline.mdc"
}

install_cursor_project() {
  local dest_dir="$HOSTMAN_ROOT/.cursor/rules"
  if [[ -d "$dest_dir" ]]; then
    cp "$TEMPLATE" "$dest_dir/mandatory-delivery-pipeline.mdc"
    ok "Cursor project (agl-hostman): $dest_dir/mandatory-delivery-pipeline.mdc"
  fi
}

install_claude_user() {
  local rules_dir="$HOME/.claude/rules"
  mkdir -p "$rules_dir"
  if [[ -f "$CLAUDE_SNIPPET" ]]; then
    cp "$CLAUDE_SNIPPET" "$rules_dir/mandatory-delivery-pipeline.md"
  else
    sed '1,/^---$/d; /^---$/d' "$TEMPLATE" > "$rules_dir/mandatory-delivery-pipeline.md"
  fi
  ok "Claude Code user rules: $rules_dir/mandatory-delivery-pipeline.md"

  local skill_dir="$HOME/.claude/skills/mandatory-delivery-pipeline"
  mkdir -p "$skill_dir"
  cat > "$skill_dir/SKILL.md" <<'SKILL'
---
name: mandatory-delivery-pipeline
description: Pipeline obrigatório AGL — testes, code review, commit, push, PR/merge e resolução de conflitos. Use SEMPRE ao implementar código ou fechar tarefas com alterações versionáveis.
---

# Mandatory Delivery Pipeline

Seguir a regra em `~/.claude/rules/mandatory-delivery-pipeline.md` (ou `.cursor/rules/mandatory-delivery-pipeline.mdc` no Cursor).

Resumo: implementar → testar → code-reviewer → commit (se pedido) → push → PR → resolver conflitos → verificar `git status` limpo/sync.
SKILL
  ok "Claude skill: $skill_dir/SKILL.md"
}

install_codex() {
  local codex_rules="$HOME/.codex/skills/mandatory-delivery-pipeline"
  if [[ -d "$HOME/.codex" ]]; then
    mkdir -p "$codex_rules"
    cp "$HOME/.claude/skills/mandatory-delivery-pipeline/SKILL.md" "$codex_rules/SKILL.md"
    ok "Codex skill: $codex_rules/SKILL.md"
  else
    warn "Codex (~/.codex) ausente — saltar"
  fi
}

install_cursor_user_skills() {
  local dest="$HOME/.cursor/skills/mandatory-delivery-pipeline"
  mkdir -p "$dest"
  cp "$HOME/.claude/skills/mandatory-delivery-pipeline/SKILL.md" "$dest/SKILL.md"
  ok "Cursor user skill: $dest/SKILL.md"
}

log "=== install-global-delivery-rules ($(hostname -s 2>/dev/null || hostname)) ==="
install_cursor_global
install_cursor_project
install_claude_user
install_codex
install_cursor_user_skills
ok "install-global-delivery-rules concluído"
