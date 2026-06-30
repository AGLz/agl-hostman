#!/usr/bin/env bash
# Propaga arsenal "4 pérolas" (Ponytail, Improve, video-transcript, scan wrapper)
# para Cursor, Claude Code e opcionalmente Hermes.
#
# Uso:
#   ./scripts/skills/install-arsenal-war-skills.sh
#   ./scripts/skills/install-arsenal-war-skills.sh --global-only
#   ./scripts/skills/install-arsenal-war-skills.sh --dry-run
#   SKIP_SKILL_SCAN=1 ./scripts/skills/install-arsenal-war-skills.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOSTMAN_ROOT="${HOSTMAN_ROOT_OVERRIDE:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
TMP_BASE="${TMPDIR:-/tmp}/agl-arsenal-sync-$$"
PONYTAIL_REPO="${PONYTAIL_REPO:-https://github.com/DietrichGebert/ponytail.git}"
IMPROVE_REPO="${IMPROVE_REPO:-https://github.com/shadcn/improve.git}"
DRAWIO_REPO="${DRAWIO_REPO:-https://github.com/Agents365-ai/drawio-skill.git}"
SCAN_SCRIPT="${SCRIPT_DIR}/scan-skill-security.sh"

GLOBAL_ONLY=0
DRY_RUN=0

log() { echo "[arsenal-war] $*"; }
ok() { echo "[OK] $*"; }
warn() { echo "[WARN] $*" >&2; }

cleanup() {
  [[ "$DRY_RUN" == "1" ]] && return 0
  rm -rf "$TMP_BASE"
}
trap cleanup EXIT

usage() {
  cat <<USAGE
Usage: $(basename "$0") [--global-only] [--dry-run]

  Instala Ponytail, Improve, drawio-skill, video-transcript-downloader, skills AGL locais.
  SkillSpector: scan-skill-security.sh (antes de repos externos) + install-skillspector.sh.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --global-only) GLOBAL_ONLY=1; shift ;;
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Opção desconhecida: $1" >&2; usage; exit 2 ;;
  esac
done

run() {
  if [[ "$DRY_RUN" == "1" ]]; then
    log "[dry-run] $*"
  else
    "$@"
  fi
}

apply_agl_ponytail_override() {
  local file="$1"
  [[ -f "$file" ]] || return 0
  if grep -q "AGL stack override" "$file" 2>/dev/null; then
    return 0
  fi
  cat >>"$file" <<'EOF'

## AGL stack override

Em `src/**` (Laravel 12 + Inertia React + shadcn/ui): quando existir componente ou padrão do design system instalado, **reutilizar** (rung 2/5) em vez de HTML nativo genérico. Em conflito com `laravel-boost.mdc` ou convenções do repo, prevalecem as regras da stack AGL.
EOF
}

scan_external_skill() {
  local path="$1"
  local name="$2"
  [[ "${SKIP_SKILL_SCAN:-0}" == "1" ]] && { warn "SKIP_SKILL_SCAN=1 — saltar scan de $name"; return 0; }
  [[ -x "$SCAN_SCRIPT" ]] || { warn "scan script em falta — saltar $name"; return 0; }
  if [[ "$DRY_RUN" == "1" ]]; then
    log "[dry-run] scan $name"
    return 0
  fi
  log "SkillSpector scan: $name"
  SKILLSPECTOR_NO_LLM=1 bash "$SCAN_SCRIPT" "$path"
}

clone_repos() {
  run mkdir -p "$TMP_BASE"
  if [[ ! -d "$TMP_BASE/ponytail/.git" ]]; then
    log "clone ponytail"
    run git clone --depth 1 "$PONYTAIL_REPO" "$TMP_BASE/ponytail"
  fi
  if [[ ! -d "$TMP_BASE/improve/.git" ]]; then
    log "clone improve"
    run git clone --depth 1 "$IMPROVE_REPO" "$TMP_BASE/improve"
  fi
  if [[ ! -d "$TMP_BASE/drawio-skill/.git" ]]; then
    log "clone drawio-skill"
    run git clone --depth 1 "$DRAWIO_REPO" "$TMP_BASE/drawio-skill"
  fi
  scan_external_skill "$TMP_BASE/ponytail" "ponytail"
  scan_external_skill "$TMP_BASE/improve/skills/improve" "improve"
  scan_external_skill "$TMP_BASE/drawio-skill" "drawio-skill"
}

install_ponytail() {
  local src_rule="$TMP_BASE/ponytail/.cursor/rules/ponytail.mdc"
  local src_agents="$TMP_BASE/ponytail/AGENTS.md"
  local canonical_rule="$HOSTMAN_ROOT/.cursor/rules/ponytail.mdc"
  [[ -f "$src_rule" ]] || { warn "ponytail.mdc em falta"; return 1; }

  if [[ "$GLOBAL_ONLY" != "1" ]]; then
    run /usr/bin/install -d -m 0755 "$HOSTMAN_ROOT/.cursor/rules"
    if [[ -f "$canonical_rule" ]] && grep -q "AGL stack override" "$canonical_rule"; then
      log "project ponytail: manter canonical AGL em $canonical_rule"
    else
      run /usr/bin/install -m 0644 "$src_rule" "$canonical_rule"
      apply_agl_ponytail_override "$canonical_rule"
    fi
    run /usr/bin/install -d -m 0755 "$HOSTMAN_ROOT/.claude/skills/ponytail"
    run /usr/bin/install -m 0644 "$src_agents" "$HOSTMAN_ROOT/.claude/skills/ponytail/SKILL.md"
    ok "project ponytail"
  fi

  run /usr/bin/install -d -m 0755 "$HOME/.cursor/rules" "$HOME/.claude/skills/ponytail"
  run /usr/bin/install -m 0644 "$src_rule" "$HOME/.cursor/rules/ponytail.mdc"
  apply_agl_ponytail_override "$HOME/.cursor/rules/ponytail.mdc"
  run /usr/bin/install -m 0644 "$src_agents" "$HOME/.claude/skills/ponytail/SKILL.md"
  ok "global ponytail"
}

install_improve() {
  local src="$TMP_BASE/improve/skills/improve"
  [[ -d "$src" ]] || { warn "improve skill em falta"; return 1; }
  [[ -f "$src/SKILL.md" ]] || { warn "improve/SKILL.md ausente — clone incompleto"; return 1; }

  local dest
  for dest in \
    "$HOSTMAN_ROOT/.cursor/skills/improve" \
    "$HOSTMAN_ROOT/.claude/skills/improve" \
    "$HOME/.cursor/skills/improve" \
    "$HOME/.claude/skills/improve"
  do
    if [[ "$GLOBAL_ONLY" == "1" && "$dest" == "$HOSTMAN_ROOT/"* ]]; then
      continue
    fi
    run /usr/bin/install -d -m 0755 "$dest"
    run rsync -a --delete "$src/" "$dest/"
    ok "improve → $dest"
  done
}

install_video_transcript() {
  local src="$HOSTMAN_ROOT/.agents/skills/video-transcript-downloader"
  [[ -f "$src/scripts/vtd.js" ]] || { warn "video-transcript-downloader em falta em .agents/skills"; return 0; }

  local dest
  for dest in \
    "$HOSTMAN_ROOT/.cursor/skills/video-transcript-downloader" \
    "$HOME/.cursor/skills/video-transcript-downloader" \
    "$HOME/.claude/skills/video-transcript-downloader"
  do
    if [[ "$GLOBAL_ONLY" == "1" && "$dest" == "$HOSTMAN_ROOT/"* ]]; then
      continue
    fi
    run /usr/bin/install -d -m 0755 "$dest"
    run rsync -a --delete "$src/" "$dest/"
    if [[ "$DRY_RUN" != "1" && -f "$dest/package.json" ]]; then
      (cd "$dest" && npm ci --silent) || warn "npm ci falhou em $dest"
    fi
    ok "video-transcript → $dest"
  done
}

install_drawio_skill() {
  local src="$TMP_BASE/drawio-skill/skills/drawio-skill"
  if [[ ! -f "$src/SKILL.md" && -f "$TMP_BASE/drawio-skill/SKILL.md" ]]; then
    src="$TMP_BASE/drawio-skill"
  fi
  [[ -f "$src/SKILL.md" ]] || { warn "drawio-skill/SKILL.md em falta"; return 0; }

  local dest
  for dest in \
    "$HOSTMAN_ROOT/.cursor/skills/drawio-skill" \
    "$HOSTMAN_ROOT/.claude/skills/drawio-skill" \
    "$HOME/.cursor/skills/drawio-skill" \
    "$HOME/.claude/skills/drawio-skill"
  do
    if [[ "$GLOBAL_ONLY" == "1" && "$dest" == "$HOSTMAN_ROOT/"* ]]; then
      continue
    fi
    run /usr/bin/install -d -m 0755 "$dest"
    run rsync -a --delete "$src/" "$dest/"
    ok "drawio-skill → $dest"
  done
}

install_agl_local_skills() {
  local name src dest
  for name in agl-video-analysis agl-architecture-diagram; do
    src="$HOSTMAN_ROOT/.cursor/skills/$name"
    [[ -f "$src/SKILL.md" ]] || continue
    for dest in \
      "$HOSTMAN_ROOT/.claude/skills/$name" \
      "$HOME/.cursor/skills/$name" \
      "$HOME/.claude/skills/$name"
    do
      if [[ "$GLOBAL_ONLY" == "1" && "$dest" == "$HOSTMAN_ROOT/"* ]]; then
        continue
      fi
      run /usr/bin/install -d -m 0755 "$dest"
      run /usr/bin/install -m 0644 "$src/SKILL.md" "$dest/SKILL.md"
      ok "$name → $dest"
    done
  done
}

main() {
  clone_repos
  install_ponytail
  install_improve
  install_drawio_skill
  install_video_transcript
  install_agl_local_skills
  if [[ "$DRY_RUN" != "1" && -x "$SCRIPT_DIR/install-skillspector.sh" ]]; then
    bash "$SCRIPT_DIR/install-skillspector.sh" || warn "install-skillspector falhou (Docker?)"
  fi
  ok "install-arsenal-war-skills concluído ($(hostname -s 2>/dev/null || hostname))"
  log "SkillSpector: bash $SCAN_SCRIPT <path>"
}

main "$@"
