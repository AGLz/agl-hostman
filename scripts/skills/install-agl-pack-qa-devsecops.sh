#!/usr/bin/env bash
# Pack AGL QA + DevSecOps — skills, sync ECC subset, regras, verify.
#
# Uso:
#   bash scripts/skills/install-agl-pack-qa-devsecops.sh
#   bash scripts/skills/install-agl-pack-qa-devsecops.sh --global-only
#   SKIP_GIT_CLONE=1 bash scripts/skills/install-agl-pack-qa-devsecops.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOSTMAN_ROOT="${AGL_SOURCE:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
TMP_BASE="${TMPDIR:-/tmp}/agl-qa-devsecops-$$"
GLOBAL_ONLY=0
PROJECT_ONLY=0
SKIP_SCAN="${SKIP_SCAN:-0}"

log() { echo "[qa-devsecops-pack] $*"; }
ok() { echo "[OK] $*"; }
warn() { echo "[WARN] $*" >&2; }

AGL_NATIVE_SKILLS=(
  agl-testing-policy
  agl-stack-testing
  agl-devsecops
  agl-sast-gate
  agl-incident-response
  agl-qa-regression
  code-review-and-quality
  security-and-hardening
)

ECC_SKILLS=(
  tdd-workflow
  verification-loop
  e2e-testing
  ai-regression-testing
  eval-harness
  production-audit
  skill-scout
)

SUPERPOWERS_EXTRA=(
  testing-anti-patterns
  condition-based-waiting
  defense-in-depth
)

usage() {
  cat <<USAGE
Usage: $(basename "$0") [--global-only] [--project-only]

  --global-only   Só ~/.claude/skills e ~/.cursor/skills
  --project-only  Só agl-hostman/.cursor/skills (já versionado)
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

cleanup() { rm -rf "$TMP_BASE"; }
trap cleanup EXIT

sync_skill_to_harnesses() {
  local src="$1" name="$2"
  [[ -f "$src/SKILL.md" ]] || { warn "SKILL.md em falta: $src"; return 1; }

  if [[ "$PROJECT_ONLY" -eq 1 ]]; then
    ok "skill $name (project-only — já em repo)"
    return 0
  fi

  for dest_root in "$HOME/.cursor/skills" "$HOME/.claude/skills" "$HOME/.codex/skills"; do
    mkdir -p "$dest_root"
    local dest="$dest_root/$name"
    if command -v rsync >/dev/null 2>&1; then
      rsync -a --delete --exclude '.git' "$src/" "$dest/"
    else
      rm -rf "$dest"
      mkdir -p "$dest"
      cp -a "$src/." "$dest/"
    fi
  done
  ok "skill $name → global harnesses"
}

sync_agl_native() {
  log "=== skills AGL-native ==="
  local name
  for name in "${AGL_NATIVE_SKILLS[@]}"; do
    sync_skill_to_harnesses "$HOSTMAN_ROOT/.cursor/skills/$name" "$name"
  done
}

sync_ecc_from_hostman() {
  log "=== ECC subset (de .cursor/skills) ==="
  local name
  for name in "${ECC_SKILLS[@]}"; do
    local src="$HOSTMAN_ROOT/.cursor/skills/$name"
    [[ -d "$src" ]] || continue
    sync_skill_to_harnesses "$src" "$name"
  done
}

sync_superpowers_extras() {
  [[ "${SKIP_GIT_CLONE:-0}" == "1" ]] && return 0
  log "=== superpowers extras ==="
  local repo="$TMP_BASE/superpowers"
  [[ -d "$repo/.git" ]] || git clone --depth 1 https://github.com/obra/superpowers.git "$repo"

  local name
  for name in "${SUPERPOWERS_EXTRA[@]}"; do
    local found=""
    if [[ -f "$repo/skills/testing-anti-patterns/SKILL.md" ]]; then
      found="$repo/skills/testing-anti-patterns"
    elif [[ -f "$repo/skills/systematic-debugging/${name}.md" ]]; then
      mkdir -p "$TMP_BASE/_skill/$name"
      {
        echo "---"
        echo "name: $name"
        echo "origin: superpowers"
        echo "---"
        echo ""
        cat "$repo/skills/systematic-debugging/${name}.md"
      } >"$TMP_BASE/_skill/$name/SKILL.md"
      found="$TMP_BASE/_skill/$name"
    elif [[ -d "$repo/skills/$name" ]]; then
      found="$repo/skills/$name"
    fi
    [[ -n "$found" ]] && sync_skill_to_harnesses "$found" "$name"
  done

  for name in verification-before-completion systematic-debugging test-driven-development; do
    [[ -d "$repo/skills/$name" ]] && sync_skill_to_harnesses "$repo/skills/$name" "$name"
  done
}

install_review_wrappers() {
  [[ "$PROJECT_ONLY" -eq 1 ]] && return 0
  for name in review-security review-bugbot; do
    local src="$HOSTMAN_ROOT/.cursor/skills/$name"
    if [[ -f "$src/SKILL.md" ]]; then
      sync_skill_to_harnesses "$src" "$name"
      continue
    fi
    local src_cursor="$HOME/.cursor/skills-cursor/$name"
    [[ -f "$src_cursor/SKILL.md" ]] && sync_skill_to_harnesses "$src_cursor" "$name"
  done
}

install_claude_skills_subset() {
  [[ "$PROJECT_ONLY" -eq 1 ]] && return 0
  log "=== claude/skills subset (semgrep, gha-validator) ==="
  for name in semgrep-rule-creator github-actions-validator; do
    local src="$HOME/.claude/skills/$name"
    [[ -d "$src" ]] || src="$HOME/.claude/skills/ecc/$name"
    [[ -f "${src}/SKILL.md" ]] || continue
    sync_skill_to_harnesses "$src" "$name"
  done
  # defense-in-depth já vem de superpowers extras — não re-sync
}

install_project_rule() {
  local src="$HOSTMAN_ROOT/.cursor/rules/agl-testing-policy.mdc"
  [[ -f "$src" ]] || return 0
  ok "rule agl-testing-policy.mdc (project)"
}

scan_external_skills() {
  [[ "$SKIP_SCAN" == "1" ]] && return 0
  local scanner="$HOSTMAN_ROOT/scripts/skills/scan-skill-security.sh"
  [[ -x "$scanner" ]] || { warn "scan-skill-security.sh não executável — saltar"; return 0; }
  log "=== SkillSpector (skills AGL-native) ==="
  local name
  for name in "${AGL_NATIVE_SKILLS[@]}"; do
    bash "$scanner" "$HOSTMAN_ROOT/.cursor/skills/$name" 2>/dev/null || warn "scan $name com avisos"
  done
  ok "security scan concluído"
}

run_sync_six_repos() {
  : # propagate/sync-six-repos invoca este script; evitar loop
}

main() {
  log "hostman=$HOSTMAN_ROOT"
  install_project_rule
  sync_agl_native
  sync_ecc_from_hostman
  sync_superpowers_extras
  install_review_wrappers
  install_claude_skills_subset
  scan_external_skills
  # sync-six-repos --repo qa-devsecops chama este script; não re-entrar

  if [[ -x "$SCRIPT_DIR/verify-agl-qa-devsecops-pack.sh" ]]; then
    bash "$SCRIPT_DIR/verify-agl-qa-devsecops-pack.sh" || warn "verify com FAIL"
  fi
  ok "Pack QA+DevSecOps instalado"
}

main "$@"
