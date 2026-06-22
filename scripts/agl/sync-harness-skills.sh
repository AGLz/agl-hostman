#!/usr/bin/env bash
# Sincroniza skills AGL harness-router de .claude/skills/ para harnesses locais.
# Uso: bash scripts/agl/sync-harness-skills.sh [--dry-run] [--harness claude,cursor,verdent]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOSTMAN_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
DRY_RUN=0
HARNESS="${HARNESS:-all}"

SKILLS=(
  agl-harness-router
  agl-claude-code-agent
  agl-cursor-agent
  agl-verdent-agent
  agl-ruflo-orchestrator
)

declare -A SKILL_HARNESS=(
  [agl-harness-router]="claude,cursor,verdent,codex,hostman-cursor"
  [agl-claude-code-agent]="claude,codex"
  [agl-cursor-agent]="cursor,hostman-cursor"
  [agl-verdent-agent]="verdent"
  [agl-ruflo-orchestrator]="claude,cursor,verdent,codex,hostman-cursor"
)

harness_root() {
  case "$1" in
    claude|claude-code) printf '%s' "$HOME/.claude/skills" ;;
    cursor) printf '%s' "$HOME/.cursor/skills" ;;
    codex) printf '%s' "$HOME/.codex/skills" ;;
    verdent) printf '%s' "$HOME/.verdent/skills" ;;
    hostman-cursor) printf '%s' "$HOSTMAN_ROOT/.cursor/skills" ;;
    *) return 1 ;;
  esac
}

should_harness() {
  [[ "$HARNESS" == "all" ]] && return 0
  [[ ",$HARNESS," == *",$1,"* ]]
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=1; shift ;;
    --harness) HARNESS="$2"; shift 2 ;;
    -h|--help)
      echo "Usage: $0 [--dry-run] [--harness claude,cursor,verdent,codex|all]"
      exit 0
      ;;
    *) echo "Opção desconhecida: $1" >&2; exit 1 ;;
  esac
done

for skill in "${SKILLS[@]}"; do
  src="${HOSTMAN_ROOT}/.claude/skills/${skill}"
  [[ -f "${src}/SKILL.md" ]] || { echo "ERRO: falta ${src}/SKILL.md" >&2; exit 1; }

  IFS=',' read -r -a agents <<< "${SKILL_HARNESS[$skill]}"
  for agent in "${agents[@]}"; do
    should_harness "$agent" || continue
    root="$(harness_root "$agent")" || continue
    dest="${root}/${skill}"
    if [[ "$DRY_RUN" -eq 1 ]]; then
      echo "[dry-run] ${skill} -> ${dest}"
      continue
    fi
    mkdir -p "$root"
    rm -rf "$dest"
    cp -a "$src" "$dest"
    echo "OK ${skill} -> ${dest}"
  done
done

echo "sync-harness-skills concluído (dry_run=${DRY_RUN})"
