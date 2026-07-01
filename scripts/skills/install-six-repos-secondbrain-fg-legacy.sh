#!/usr/bin/env bash
# Six Repos + segundo cérebro (llm-wiki) para fg_antigo — PHP legado CT549.
#
# Uso (no CT fg-legacy):
#   AGL_SOURCE=/tmp/agl-bundle bash install-six-repos-secondbrain-fg-legacy.sh
#   SKIP_RUFLO_SYNC=1 (default) — CT servidor, sem ruflo/ECC pesado
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FG_LEGACY_ROOT="${FG_LEGACY_ROOT:-/var/www/fg_antigo}"
AGL_SOURCE="${AGL_SOURCE:-$(cd "$SCRIPT_DIR/../.." && pwd 2>/dev/null || echo /tmp/agl-arsenal-bundle)}"
LLM_WIKI_DIR="${LLM_WIKI_DIR:-/opt/agl-llm-wiki}"
TMP_BASE="${TMPDIR:-/tmp}/six-repos-fg-$$"
SKIP_RUFLO_SYNC="${SKIP_RUFLO_SYNC:-1}"

log() { echo "[six-repos-fg] $*"; }
ok() { echo "[OK] $*"; }
warn() { echo "[WARN] $*" >&2; }

cleanup() { rm -rf "$TMP_BASE"; }
trap cleanup EXIT

sync_skill_to_project() {
  local src="$1" name="$2"
  [[ -f "$src/SKILL.md" ]] || { warn "SKILL.md em falta: $src"; return 1; }
  for dest_root in "$FG_LEGACY_ROOT/.cursor/skills" "$FG_LEGACY_ROOT/.claude/skills"; do
    mkdir -p "$dest_root"
    if command -v rsync >/dev/null 2>&1; then
      rsync -a --delete --exclude '.git' "$src/" "$dest_root/$name/"
    else
      rm -rf "$dest_root/$name"
      mkdir -p "$dest_root/$name"
      cp -a "$src/." "$dest_root/$name/"
    fi
  done
  ok "$name → project .cursor/.claude"
}

clone_and_sync() {
  local url="$1" name="$2" subpath="${3:-}"
  local dir="$TMP_BASE/$name"
  if [[ ! -d "$dir/.git" ]]; then
    git clone --depth 1 "$url" "$dir"
  fi
  local src="$dir"
  [[ -n "$subpath" ]] && src="$dir/$subpath"
  sync_skill_to_project "$src" "$name"
}

ensure_wiki() {
  local ensure="${AGL_SOURCE}/scripts/proxmox/ensure-llm-wiki-fg-legacy-ct549.sh"
  if [[ -x "$ensure" ]]; then
    bash "$ensure"
  elif [[ -x "$SCRIPT_DIR/../proxmox/ensure-llm-wiki-fg-legacy-ct549.sh" ]]; then
    bash "$SCRIPT_DIR/../proxmox/ensure-llm-wiki-fg-legacy-ct549.sh"
  else
    warn "ensure-llm-wiki script em falta — esperar ${LLM_WIKI_DIR}/wiki/index.md"
    test -r "${LLM_WIKI_DIR}/wiki/index.md"
  fi
}

install_second_brain_rule() {
  local src="$AGL_SOURCE/.cursor/rules/llm-wiki-second-brain-fg-legacy.mdc"
  local fallback="$AGL_SOURCE/.cursor/rules/llm-wiki-second-brain.mdc"
  local dst="$FG_LEGACY_ROOT/.cursor/rules/llm-wiki-second-brain.mdc"
  mkdir -p "$FG_LEGACY_ROOT/.cursor/rules"
  if [[ -f "$src" ]]; then
    /usr/bin/install -m 0644 "$src" "$dst"
  elif [[ -f "$fallback" ]]; then
    sed 's|/mnt/overpower/apps/dev/agl/llm-wiki|/opt/agl-llm-wiki|g; s|agl-hostman|fg_antigo (fg-legacy)|g' \
      "$fallback" >"$dst"
  else
    warn "llm-wiki-second-brain.mdc em falta no bundle"
    return 0
  fi
  ok "llm-wiki-second-brain.mdc"
}

install_mcp_wiki() {
  mkdir -p "$FG_LEGACY_ROOT/.cursor"
  local npx_bin="npx"
  if [[ -x /usr/local/bin/npx20 ]]; then
    npx_bin="/usr/local/bin/npx20"
  elif command -v npx20 >/dev/null 2>&1; then
    npx_bin="$(command -v npx20)"
  fi
  cat >"$FG_LEGACY_ROOT/.cursor/mcp.json" <<JSON
{
  "mcpServers": {
    "llm-wiki-fs": {
      "type": "stdio",
      "command": "${npx_bin}",
      "args": [
        "-y",
        "@modelcontextprotocol/server-filesystem",
        "${LLM_WIKI_DIR}/wiki",
        "${LLM_WIKI_DIR}/raw"
      ],
      "description": "Segundo cérebro AGL — llm-wiki wiki/ e raw/ (fg-legacy CT549)"
    }
  }
}
JSON
  ok ".cursor/mcp.json (llm-wiki-fs, ${npx_bin})"
}

install_wiki_ingest_pack() {
  local skill_src="$AGL_SOURCE/.cursor/skills/llm-wiki-ingest/SKILL.md"
  local cmd_src="$AGL_SOURCE/.cursor/commands/llm-wiki-ingest.md"
  if [[ -f "$skill_src" ]]; then
    mkdir -p "$FG_LEGACY_ROOT/.cursor/skills/llm-wiki-ingest" \
      "$FG_LEGACY_ROOT/.claude/skills/llm-wiki-ingest" \
      "$FG_LEGACY_ROOT/.cursor/commands"
    /usr/bin/install -m 0644 "$skill_src" "$FG_LEGACY_ROOT/.cursor/skills/llm-wiki-ingest/SKILL.md"
    /usr/bin/install -m 0644 "$skill_src" "$FG_LEGACY_ROOT/.claude/skills/llm-wiki-ingest/SKILL.md"
    [[ -f "$cmd_src" ]] && /usr/bin/install -m 0644 "$cmd_src" "$FG_LEGACY_ROOT/.cursor/commands/llm-wiki-ingest.md"
    ok "llm-wiki-ingest skill + command"
  fi
}

install_obsidian_wiki_plugin() {
  if [[ ! -d "$LLM_WIKI_DIR" ]]; then
    return 0
  fi
  mkdir -p "$LLM_WIKI_DIR/.claude"
  local settings="$LLM_WIKI_DIR/.claude/settings.json"
  if [[ ! -f "$settings" ]]; then
    cat >"$settings" <<'JSON'
{
  "plugins": {
    "obsidian-cli": {
      "source": {
        "source": "github",
        "repo": "pablo-mano/Obsidian-CLI-skill"
      }
    }
  }
}
JSON
    ok "llm-wiki .claude/settings.json (obsidian-cli)"
  fi
}

sync_obsidian_cli() {
  local repo="$TMP_BASE/Obsidian-CLI-skill"
  if [[ ! -d "$repo/.git" ]]; then
    git clone --depth 1 https://github.com/pablo-mano/Obsidian-CLI-skill.git "$repo"
  fi
  sync_skill_to_project "$repo/skills/obsidian-cli" "obsidian-cli"
  if [[ -d "$LLM_WIKI_DIR" ]]; then
    mkdir -p "$LLM_WIKI_DIR/.claude/skills"
    rsync -a "$repo/skills/obsidian-cli/" "$LLM_WIKI_DIR/.claude/skills/obsidian-cli/" 2>/dev/null || true
  fi
}

sync_superpowers_subset() {
  local repo="$TMP_BASE/superpowers"
  if [[ ! -d "$repo/.git" ]]; then
    git clone --depth 1 https://github.com/obra/superpowers.git "$repo"
  fi
  local name
  for name in using-superpowers brainstorming executing-plans verification-before-completion systematic-debugging; do
    [[ -f "$repo/skills/$name/SKILL.md" ]] || continue
    sync_skill_to_project "$repo/skills/$name" "$name"
  done
  local sd="$repo/skills/systematic-debugging"
  if [[ -f "$sd/root-cause-tracing.md" ]]; then
    for root in "$FG_LEGACY_ROOT/.cursor/skills" "$FG_LEGACY_ROOT/.claude/skills"; do
      mkdir -p "$root/root-cause-tracing"
      {
        echo "---"
        echo "name: root-cause-tracing"
        echo "description: Rastrear causa raiz antes de corrigir bugs."
        echo "---"
        echo ""
        cat "$sd/root-cause-tracing.md"
      } >"$root/root-cause-tracing/SKILL.md"
    done
  fi
  if [[ -f "$sd/defense-in-depth.md" ]]; then
    for root in "$FG_LEGACY_ROOT/.cursor/skills" "$FG_LEGACY_ROOT/.claude/skills"; do
      mkdir -p "$root/defense-in-depth"
      {
        echo "---"
        echo "name: defense-in-depth"
        echo "description: Validação em múltiplas camadas."
        echo "---"
        echo ""
        cat "$sd/defense-in-depth.md"
      } >"$root/defense-in-depth/SKILL.md"
    done
  fi
  ok "superpowers subset"
}

sync_content_skills() {
  clone_and_sync "https://github.com/blader/humanizer.git" "humanizer"
  clone_and_sync "https://github.com/petar-nauka/fact-check-skill.git" "fact-check"
  clone_and_sync "https://github.com/severity1/claude-code-prompt-improver.git" "prompt-improver" "skills/prompt-improver"
  mkdir -p "$FG_LEGACY_ROOT/.cursor"
  cat >"$FG_LEGACY_ROOT/.cursor/content-skills-sync-state.json" <<JSON
{
  "synced_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "host": "fg-legacy-ct549",
  "skills": ["humanizer", "fact-check", "prompt-improver"]
}
JSON
  ok "content-skills state"
}

sync_karpathy() {
  local repo="$TMP_BASE/andrej-karpathy-skills"
  if [[ ! -d "$repo/.git" ]]; then
    git clone --depth 1 https://github.com/multica-ai/andrej-karpathy-skills.git "$repo"
  fi
  if [[ -f "$repo/SKILL.md" ]]; then
    sync_skill_to_project "$repo" "andrej-karpathy-skills"
  fi
  local krule="$AGL_SOURCE/.cursor/rules/karpathy-skills.mdc"
  [[ -f "$krule" ]] && /usr/bin/install -m 0644 "$krule" "$FG_LEGACY_ROOT/.cursor/rules/karpathy-skills.mdc" && ok "karpathy-skills.mdc"
}

patch_agents_md() {
  local agents="$FG_LEGACY_ROOT/AGENTS.md"
  [[ -f "$agents" ]] || return 0
  grep -q 'Segundo cérebro' "$agents" 2>/dev/null && return 0
  cat >>"$agents" <<EOF

## Segundo cérebro (llm-wiki)

- Vault: \`${LLM_WIKI_DIR}\` — começar por \`wiki/index.md\`
- Regra Cursor: \`.cursor/rules/llm-wiki-second-brain.mdc\`
- MCP: \`.cursor/mcp.json\` → \`llm-wiki-fs\`
- Ingest: skill \`llm-wiki-ingest\`, comando \`/llm-wiki-ingest\`
- Six Repos (subset): obsidian-cli, humanizer, fact-check, prompt-improver, superpowers, karpathy
- Verificar: \`bash scripts/skills/verify-six-repos-fg-legacy.sh\`
EOF
  ok "AGENTS.md second brain"
}

main() {
  [[ -d "$FG_LEGACY_ROOT" ]] || { warn "FG_LEGACY_ROOT inexistente"; exit 1; }
  mkdir -p "$TMP_BASE"
  ensure_wiki
  install_second_brain_rule
  install_mcp_wiki
  install_wiki_ingest_pack
  install_obsidian_wiki_plugin
  sync_obsidian_cli
  sync_superpowers_subset
  sync_content_skills
  sync_karpathy
  patch_agents_md
  ok "six-repos + secondbrain fg-legacy concluído"
}

main "$@"
