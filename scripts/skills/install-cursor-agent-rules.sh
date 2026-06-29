#!/usr/bin/env bash
# Instala pack de regras/skills Cursor para auto-melhoria AGL (prompt-improve, self-improve, reflect-yourself).
#
# Uso:
#   ./scripts/skills/install-cursor-agent-rules.sh
#   ./scripts/skills/install-cursor-agent-rules.sh --global-only
#   ./scripts/skills/install-cursor-agent-rules.sh --project-only
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOSTMAN_ROOT="${HOSTMAN_ROOT_OVERRIDE:-$(cd "$SCRIPT_DIR/../.." && pwd)}"

GLOBAL_ONLY=0
PROJECT_ONLY=0

log() { echo "[INFO] $*"; }
ok() { echo "[OK] $*"; }
warn() { echo "[WARN] $*"; }

RULES_PACK=(
  prompt-improve.mdc
  self-improve.mdc
  session-reflect.mdc
  memory.mdc
)

usage() {
  cat <<USAGE
Usage: $(basename "$0") [--global-only] [--project-only]

  --global-only   Só ~/.cursor/skills e ~/.claude/skills (reflect-yourself)
  --project-only  Só .cursor/ no agl-hostman (rules, skills, commands)
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --global-only) GLOBAL_ONLY=1; shift ;;
    --project-only) PROJECT_ONLY=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Opção desconhecida: $1" >&2; usage; exit 2 ;;
  esac
done

install_project_rules() {
  local src="$HOSTMAN_ROOT/.cursor/rules"
  local missing=0
  for f in "${RULES_PACK[@]}"; do
    if [[ ! -f "$src/$f" ]]; then
      warn "regra em falta: $src/$f"
      missing=1
    fi
  done
  [[ "$missing" -eq 0 ]] || return 1
  ok "project rules pack verificado em $src (${#RULES_PACK[@]} ficheiros)"
}

install_project_skills() {
  local src="$HOSTMAN_ROOT/.cursor/skills/reflect-yourself"
  [[ -f "$src/SKILL.md" ]] || { warn "reflect-yourself skill em falta"; return 1; }
  [[ -f "$HOSTMAN_ROOT/.cursor/commands/reflect-yourself.md" ]] || warn "command reflect-yourself.md em falta"
  ok "project skill reflect-yourself: $src"
}

install_global_skills() {
  local src="$HOSTMAN_ROOT/.cursor/skills/reflect-yourself"
  mkdir -p "$HOME/.cursor/skills/reflect-yourself"
  cp "$src/SKILL.md" "$HOME/.cursor/skills/reflect-yourself/SKILL.md"
  ok "global Cursor skill: ~/.cursor/skills/reflect-yourself/"

  mkdir -p "$HOME/.claude/skills/reflect-yourself"
  if [[ -f "$HOSTMAN_ROOT/.claude/skills/reflect-yourself/SKILL.md" ]]; then
    cp "$HOSTMAN_ROOT/.claude/skills/reflect-yourself/SKILL.md" "$HOME/.claude/skills/reflect-yourself/SKILL.md"
  else
    cp "$src/SKILL.md" "$HOME/.claude/skills/reflect-yourself/SKILL.md"
  fi
  ok "global Claude skill: ~/.claude/skills/reflect-yourself/"
}

install_global_rules_optional() {
  # Regras globais opcionais (não duplicar primary-guide do project)
  local dest="$HOME/.cursor/rules"
  mkdir -p "$dest"
  for f in prompt-improve.mdc self-improve.mdc session-reflect.mdc; do
    if [[ -f "$HOSTMAN_ROOT/.cursor/rules/$f" ]]; then
      cp "$HOSTMAN_ROOT/.cursor/rules/$f" "$dest/$f"
      ok "global rule: $dest/$f"
    fi
  done
}

log "=== install-cursor-agent-rules ($(hostname -s 2>/dev/null || hostname)) ==="

if [[ "$GLOBAL_ONLY" -eq 0 ]]; then
  install_project_rules
  install_project_skills
fi

if [[ "$PROJECT_ONLY" -eq 0 ]]; then
  install_global_skills
  install_global_rules_optional
fi

ok "install-cursor-agent-rules concluído"
