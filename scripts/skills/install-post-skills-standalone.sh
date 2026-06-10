#!/usr/bin/env bash
# Instala post skills em ~/.claude/skills (+ cursor/codex/verdent) sem repo agl-hostman.
# Para agldv05/06/07 ou hosts sem NFS /mnt/overpower/...
set -euo pipefail

TEMP="${TMPDIR:-/tmp}/agl-post-skills-$$"
mkdir -p "$TEMP"
trap 'rm -rf "$TEMP"' EXIT

log() { echo "[INFO] $*"; }
ok() { echo "[OK] $*"; }
warn() { echo "[WARN] $*"; }

sync_to_dest() {
  local src="$1"
  local dest="$2"
  mkdir -p "$dest"
  if command -v rsync >/dev/null 2>&1; then
    rsync -a --delete \
      --exclude '.git' \
      --exclude '*.zip' \
      --exclude '*.skill' \
      "$src/" "$dest/"
  else
    rm -rf "$dest"
    mkdir -p "$dest"
    cp -a "$src/." "$dest/"
  fi
}

install_skill_dir() {
  local url="$1"
  local name="$2"
  local subpath="${3:-}"
  local dir="$TEMP/$name"
  if [[ -d "$dir/.git" ]]; then
    git -C "$dir" pull --ff-only
  else
    git clone --depth 1 "$url" "$dir"
  fi
  local src="$dir"
  [[ -n "$subpath" ]] && src="$dir/$subpath"
  if [[ ! -f "$src/SKILL.md" ]]; then
    echo "SKILL.md em falta: $src" >&2
    return 1
  fi
  for root in "$HOME/.claude/skills" "$HOME/.cursor/skills" "$HOME/.codex/skills" "$HOME/.verdent/skills"; do
    mkdir -p "$root"
    sync_to_dest "$src" "$root/$name"
    ok "$name -> $root/$name"
  done
}

log "=== standalone post skills em $(hostname -s 2>/dev/null || hostname) ==="
install_skill_dir "https://github.com/blader/humanizer.git" "humanizer"
install_skill_dir "https://github.com/petar-nauka/fact-check-skill.git" "fact-check"
install_skill_dir "https://github.com/severity1/claude-code-prompt-improver.git" "prompt-improver" "skills/prompt-improver"

# frontend-slides: ECC curada (zarazhangrui-inspired) via raw clone upstream
FE_DIR="$TEMP/frontend-slides-upstream"
if [[ ! -d "$FE_DIR/.git" ]]; then
  git clone --depth 1 https://github.com/zarazhangrui/frontend-slides.git "$FE_DIR" 2>/dev/null || true
fi
if [[ -f "$FE_DIR/SKILL.md" ]]; then
  for root in "$HOME/.claude/skills" "$HOME/.cursor/skills"; do
    sync_to_dest "$FE_DIR" "$root/frontend-slides"
    ok "frontend-slides -> $root/frontend-slides"
  done
else
  warn "frontend-slides upstream sem SKILL.md — saltar"
fi

# superpowers subset (find-skills / using-superpowers)
SP_CACHE="$HOME/.claude/plugins/cache/superpowers-marketplace/superpowers"
SP_SRC=""
if [[ -d "$SP_CACHE" ]]; then
  SP_SRC="$(find "$SP_CACHE" -mindepth 1 -maxdepth 1 -type d | head -1)/skills"
fi
if [[ -z "$SP_SRC" || ! -d "$SP_SRC" ]]; then
  SP_REPO="$TEMP/superpowers"
  git clone --depth 1 https://github.com/obra/superpowers.git "$SP_REPO"
  SP_SRC="$SP_REPO/skills"
fi
for name in using-superpowers brainstorming executing-plans verification-before-completion; do
  if [[ -f "$SP_SRC/$name/SKILL.md" ]]; then
    for root in "$HOME/.claude/skills" "$HOME/.cursor/skills"; do
      mkdir -p "$root"
      sync_to_dest "$SP_SRC/$name" "$root/$name"
    done
    ok "superpowers/$name"
  fi
done

if command -v claude >/dev/null 2>&1; then
  if ! claude plugin list 2>/dev/null | grep -q 'superpowers@'; then
    claude plugin marketplace add obra/superpowers-marketplace 2>/dev/null || true
    claude plugin install superpowers@superpowers-marketplace 2>/dev/null || warn "superpowers plugin install falhou"
  fi
  if ! claude plugin list 2>/dev/null | grep -q 'prompt-improver@'; then
    PROMPT_REPO="$TEMP/claude-code-prompt-improver"
    git clone --depth 1 https://github.com/severity1/claude-code-prompt-improver.git "$PROMPT_REPO"
    claude plugin marketplace add "$PROMPT_REPO/.dev-marketplace/.claude-plugin/marketplace.json" 2>/dev/null || true
    claude plugin install prompt-improver@local-dev 2>/dev/null || warn "prompt-improver plugin install falhou"
  fi
else
  warn "claude CLI ausente — plugins não instalados"
fi

ok "standalone post skills concluído"
