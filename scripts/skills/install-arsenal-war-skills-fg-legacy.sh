#!/usr/bin/env bash
# Propaga arsenal "4 pérolas" + pack Cursor AGL para fg_antigo (PHP legado CT549).
#
# Uso (no CT fg-legacy ou após staging em /tmp/agl-arsenal-bundle):
#   AGL_SOURCE=/tmp/agl-arsenal-bundle bash install-arsenal-war-skills-fg-legacy.sh
#   SKIP_SKILL_SCAN=1 bash install-arsenal-war-skills-fg-legacy.sh
#
# Variáveis:
#   FG_LEGACY_ROOT   — default /var/www/fg_antigo
#   AGL_SOURCE       — cópia rsync de agl-hostman (skills AGL + vtd + scripts)
#   INSTALL_GLOBAL   — 1 = também ~/.cursor e ~/.claude (default 1)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FG_LEGACY_ROOT="${FG_LEGACY_ROOT:-/var/www/fg_antigo}"
AGL_SOURCE="${AGL_SOURCE:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
TMP_BASE="${TMPDIR:-/tmp}/agl-arsenal-fg-$$"
PONYTAIL_REPO="${PONYTAIL_REPO:-https://github.com/DietrichGebert/ponytail.git}"
IMPROVE_REPO="${IMPROVE_REPO:-https://github.com/shadcn/improve.git}"
DRAWIO_REPO="${DRAWIO_REPO:-https://github.com/Agents365-ai/drawio-skill.git}"
SCAN_SCRIPT="${FG_LEGACY_ROOT}/scripts/skills/scan-skill-security.sh"
INSTALL_GLOBAL="${INSTALL_GLOBAL:-1}"

log() { echo "[arsenal-fg] $*"; }
ok() { echo "[OK] $*"; }
warn() { echo "[WARN] $*" >&2; }

cleanup() { rm -rf "$TMP_BASE"; }
trap cleanup EXIT

apply_fg_ponytail_override() {
  local file="$1"
  [[ -f "$file" ]] || return 0
  if grep -q "FG legado override" "$file" 2>/dev/null; then
    return 0
  fi
  cat >>"$file" <<'EOF'

## FG legado override

Em `public_html/**` (PHP 5.6 legado, jQuery, ISO-8859-1): **diff mínimo**, guards antes de plugins jQuery, não converter encoding nem reformatar em massa. CSP/Nginx em `conf/` ou `/etc/nginx/sites-available/fg-antigo-www5.conf` — validar com `nginx -t` antes de reload.
EOF
}

clone_repos() {
  mkdir -p "$TMP_BASE"
  if [[ ! -d "$TMP_BASE/ponytail/.git" ]]; then
    log "clone ponytail"
    git clone --depth 1 "$PONYTAIL_REPO" "$TMP_BASE/ponytail"
  fi
  if [[ ! -d "$TMP_BASE/improve/.git" ]]; then
    log "clone improve"
    git clone --depth 1 "$IMPROVE_REPO" "$TMP_BASE/improve"
  fi
  if [[ ! -d "$TMP_BASE/drawio-skill/.git" ]]; then
    log "clone drawio-skill"
    git clone --depth 1 "$DRAWIO_REPO" "$TMP_BASE/drawio-skill"
  fi
}

install_ponytail() {
  local src_rule="$TMP_BASE/ponytail/.cursor/rules/ponytail.mdc"
  local src_agents="$TMP_BASE/ponytail/AGENTS.md"
  local dst_rule="$FG_LEGACY_ROOT/.cursor/rules/ponytail.mdc"

  [[ -f "$src_rule" ]] || { warn "ponytail.mdc em falta"; return 1; }

  /usr/bin/install -d -m 0755 "$FG_LEGACY_ROOT/.cursor/rules"
  /usr/bin/install -m 0644 "$src_rule" "$dst_rule"
  apply_fg_ponytail_override "$dst_rule"
  ok "ponytail → $dst_rule"

  /usr/bin/install -d -m 0755 "$FG_LEGACY_ROOT/.claude/skills/ponytail"
  /usr/bin/install -m 0644 "$src_agents" "$FG_LEGACY_ROOT/.claude/skills/ponytail/SKILL.md"
  ok "ponytail claude skill"

  if [[ "$INSTALL_GLOBAL" == "1" ]]; then
    /usr/bin/install -d -m 0755 "$HOME/.cursor/rules" "$HOME/.claude/skills/ponytail"
    /usr/bin/install -m 0644 "$src_rule" "$HOME/.cursor/rules/ponytail.mdc"
    apply_fg_ponytail_override "$HOME/.cursor/rules/ponytail.mdc"
    /usr/bin/install -m 0644 "$src_agents" "$HOME/.claude/skills/ponytail/SKILL.md"
    ok "ponytail global"
  fi
}

rsync_skill() {
  local src="$1" dest="$2"
  [[ -d "$src" ]] || return 1
  /usr/bin/install -d -m 0755 "$dest"
  rsync -a --delete "$src/" "$dest/"
}

install_improve() {
  local src="$TMP_BASE/improve/skills/improve"
  [[ -d "$src" ]] || { warn "improve em falta"; return 0; }
  rsync_skill "$src" "$FG_LEGACY_ROOT/.cursor/skills/improve"
  rsync_skill "$src" "$FG_LEGACY_ROOT/.claude/skills/improve"
  ok "improve"
}

install_drawio() {
  local src="$TMP_BASE/drawio-skill/skills/drawio-skill"
  [[ ! -f "$src/SKILL.md" && -f "$TMP_BASE/drawio-skill/SKILL.md" ]] && src="$TMP_BASE/drawio-skill"
  [[ -f "$src/SKILL.md" ]] || { warn "drawio-skill em falta"; return 0; }
  rsync_skill "$src" "$FG_LEGACY_ROOT/.cursor/skills/drawio-skill"
  rsync_skill "$src" "$FG_LEGACY_ROOT/.claude/skills/drawio-skill"
  ok "drawio-skill"
}

install_video_transcript() {
  local src="$AGL_SOURCE/.agents/skills/video-transcript-downloader"
  [[ ! -d "$src" && -d "$AGL_SOURCE/.cursor/skills/video-transcript-downloader" ]] && \
    src="$AGL_SOURCE/.cursor/skills/video-transcript-downloader"
  [[ -f "$src/scripts/vtd.js" ]] || { warn "video-transcript-downloader em falta em AGL_SOURCE"; return 0; }
  rsync_skill "$src" "$FG_LEGACY_ROOT/.cursor/skills/video-transcript-downloader"
  rsync_skill "$src" "$FG_LEGACY_ROOT/.claude/skills/video-transcript-downloader"
  if command -v node >/dev/null 2>&1; then
    local major
    major="$(node -p "process.versions.node.split('.')[0]" 2>/dev/null || echo 0)"
    if [[ "$major" -ge 18 ]]; then
      (cd "$FG_LEGACY_ROOT/.cursor/skills/video-transcript-downloader" && npm ci --silent) \
        || warn "npm ci vtd falhou"
    else
      warn "Node $major < 18 — vtd.js pode falhar; usar agldv ou yt-dlp manual"
    fi
  fi
  ok "video-transcript-downloader"
}

install_agl_thin_skills() {
  local name src
  for name in agl-video-analysis agl-architecture-diagram; do
    src="$AGL_SOURCE/.cursor/skills/$name/SKILL.md"
    [[ -f "$src" ]] || continue
    for dest in \
      "$FG_LEGACY_ROOT/.cursor/skills/$name" \
      "$FG_LEGACY_ROOT/.claude/skills/$name"
    do
      /usr/bin/install -d -m 0755 "$dest"
      /usr/bin/install -m 0644 "$src" "$dest/SKILL.md"
    done
    ok "$name"
  done
}

install_cursor_agent_pack() {
  local rules_src="$AGL_SOURCE/.cursor/rules"
  local pack=(prompt-improve.mdc self-improve.mdc session-reflect.mdc memory.mdc)
  /usr/bin/install -d -m 0755 "$FG_LEGACY_ROOT/.cursor/rules" \
    "$FG_LEGACY_ROOT/.cursor/skills/reflect-yourself" \
    "$FG_LEGACY_ROOT/.cursor/commands"
  local f
  for f in "${pack[@]}"; do
    [[ -f "$rules_src/$f" ]] || continue
    /usr/bin/install -m 0644 "$rules_src/$f" "$FG_LEGACY_ROOT/.cursor/rules/$f"
  done
  [[ -f "$AGL_SOURCE/.cursor/skills/reflect-yourself/SKILL.md" ]] && \
    /usr/bin/install -m 0644 "$AGL_SOURCE/.cursor/skills/reflect-yourself/SKILL.md" \
      "$FG_LEGACY_ROOT/.cursor/skills/reflect-yourself/SKILL.md"
  [[ -f "$AGL_SOURCE/.cursor/commands/reflect-yourself.md" ]] && \
    /usr/bin/install -m 0644 "$AGL_SOURCE/.cursor/commands/reflect-yourself.md" \
      "$FG_LEGACY_ROOT/.cursor/commands/reflect-yourself.md"
  ok "cursor agent pack (self-improve)"
}

install_project_scripts() {
  /usr/bin/install -d -m 0755 "$FG_LEGACY_ROOT/scripts/skills"
  for s in scan-skill-security.sh install-skillspector.sh; do
    [[ -f "$AGL_SOURCE/scripts/skills/$s" ]] || continue
    /usr/bin/install -m 0755 "$AGL_SOURCE/scripts/skills/$s" "$FG_LEGACY_ROOT/scripts/skills/$s"
  done
  /usr/bin/install -m 0755 "$SCRIPT_DIR/install-arsenal-war-skills-fg-legacy.sh" \
    "$FG_LEGACY_ROOT/scripts/skills/install-arsenal-war-skills-fg-legacy.sh"
  ok "scripts/skills"
}

install_ci_workflow() {
  [[ -f "$AGL_SOURCE/.github/workflows/skill-security-scan.yml" ]] || return 0
  /usr/bin/install -d -m 0755 "$FG_LEGACY_ROOT/.github/workflows"
  /usr/bin/install -m 0644 "$AGL_SOURCE/.github/workflows/skill-security-scan.yml" \
    "$FG_LEGACY_ROOT/.github/workflows/skill-security-scan.yml"
  ok "CI skill-security-scan"
}

patch_agents_md() {
  local agents="$FG_LEGACY_ROOT/AGENTS.md"
  [[ -f "$agents" ]] || return 0
  grep -q 'Arsenal de Guerra' "$agents" 2>/dev/null && return 0
  cat >>"$agents" <<'EOF'

## Arsenal de Guerra + Cursor AGL (2026-06)

- **Ponytail** (diff mínimo): `.cursor/rules/ponytail.mdc`
- **Improve / draw.io / vídeo**: `.cursor/skills/{improve,drawio-skill,agl-video-analysis,video-transcript-downloader}/`
- **Propagação**: `bash scripts/skills/install-arsenal-war-skills-fg-legacy.sh` (ou via `agl-hostman/scripts/proxmox/propagate-arsenal-war-fg-legacy-ct549.sh`)
- **SkillSpector**: `bash scripts/skills/scan-skill-security.sh .cursor/skills/improve`
- Wiki: [[Arsenal de Guerra — Vibe Coding com IA]] (llm-wiki)
EOF
  ok "AGENTS.md pointer"
}

main() {
  [[ -d "$FG_LEGACY_ROOT" ]] || { warn "FG_LEGACY_ROOT inexistente: $FG_LEGACY_ROOT"; exit 1; }
  clone_repos
  install_ponytail
  install_improve
  install_drawio
  install_video_transcript
  install_agl_thin_skills
  install_cursor_agent_pack
  install_project_scripts
  install_ci_workflow
  patch_agents_md
  if [[ -x "$FG_LEGACY_ROOT/scripts/skills/install-skillspector.sh" ]]; then
    SKIP_SKILL_SCAN="${SKIP_SKILL_SCAN:-1}" bash "$FG_LEGACY_ROOT/scripts/skills/install-skillspector.sh" \
      || warn "install-skillspector falhou (Docker?)"
  fi
  ok "install-arsenal-war-skills-fg-legacy concluído em $FG_LEGACY_ROOT"
}

main "$@"
