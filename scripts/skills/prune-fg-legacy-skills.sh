#!/usr/bin/env bash
# Remove skills de outros stacks do fg_antigo — reduz ruído para agentes Cursor.
#
# Uso: DRY_RUN=1 bash prune-fg-legacy-skills.sh   # listar
#      bash prune-fg-legacy-skills.sh             # mover para .cursor/skills-archive/
set -euo pipefail

FG_LEGACY_ROOT="${FG_LEGACY_ROOT:-/var/www/fg_antigo}"
SKILLS_DIR="${FG_LEGACY_ROOT}/.cursor/skills"
ARCHIVE="${FG_LEGACY_ROOT}/.cursor/skills-archive"
DRY_RUN="${DRY_RUN:-0}"

# Skills a manter (whitelist)
KEEP=(
  improve humanizer fact-check prompt-improver obsidian-cli llm-wiki-ingest
  using-superpowers brainstorming executing-plans verification-before-completion
  systematic-debugging root-cause-tracing defense-in-depth condition-based-waiting
  drawio-skill video-transcript-downloader agl-video-analysis agl-architecture-diagram
  reflect-yourself andrej-karpathy-skills
  php-dev-legacy php-debug-runtime php-performance-triage
  nginx-csp-triage legacy-console-triage security-web-basics
  ui-ux-legacy-improvements shadcn-legacy-coexistence
  infra-ops-triage observability-logging-triage
  accessibility-quickcheck documentation-lookup market-research article-writing
  content-engine investor-materials investor-outreach release-smokecheck
  web-performance-triage seo-basics
)

is_kept() {
  local name="$1" k
  for k in "${KEEP[@]}"; do
    [[ "$name" == "$k" ]] && return 0
  done
  return 1
}

[[ -d "$SKILLS_DIR" ]] || { echo "skills dir em falta: $SKILLS_DIR"; exit 1; }

MOVED=0
while IFS= read -r -d '' skill_path; do
  name="$(basename "$skill_path")"
  is_kept "$name" && continue
  if [[ "$DRY_RUN" == "1" ]]; then
    echo "prune: $name"
    MOVED=$((MOVED + 1))
    continue
  fi
  mkdir -p "$ARCHIVE"
  rm -rf "$ARCHIVE/$name"
  mv "$skill_path" "$ARCHIVE/$name"
  rm -rf "${FG_LEGACY_ROOT}/.claude/skills/$name" 2>/dev/null || true
  echo "archived: $name"
  MOVED=$((MOVED + 1))
done < <(find "$SKILLS_DIR" -mindepth 1 -maxdepth 1 -type d -print0)

echo "=== prune: $MOVED skills ${DRY_RUN:+[dry-run]}==="
