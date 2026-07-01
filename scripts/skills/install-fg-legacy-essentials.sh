#!/usr/bin/env bash
# Regras fg + superpowers extra + MCP node20 + scripts maint (CT549 / fg_antigo).
#
# Uso:
#   AGL_SOURCE=/tmp/agl-bundle FG_LEGACY_ROOT=/var/www/fg_antigo bash install-fg-legacy-essentials.sh
#   PRUNE_SKILLS=1 bash install-fg-legacy-essentials.sh  # remove skills de outros stacks
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FG_LEGACY_ROOT="${FG_LEGACY_ROOT:-/var/www/fg_antigo}"
AGL_SOURCE="${AGL_SOURCE:-$(cd "$SCRIPT_DIR/../.." && pwd 2>/dev/null || echo /tmp/agl-bundle)}"
LLM_WIKI_DIR="${LLM_WIKI_DIR:-/opt/agl-llm-wiki}"
TMP_BASE="${TMPDIR:-/tmp}/fg-essentials-$$"
PRUNE_SKILLS="${PRUNE_SKILLS:-0}"
INSTALL_NODE="${INSTALL_NODE:-0}"

log() { echo "[fg-essentials] $*"; }
ok() { echo "[OK] $*"; }
warn() { echo "[WARN] $*" >&2; }

cleanup() { rm -rf "$TMP_BASE"; }
trap cleanup EXIT

resolve_npx() {
  if [[ -x /usr/local/bin/npx20 ]]; then
    echo /usr/local/bin/npx20
  elif command -v npx20 >/dev/null 2>&1; then
    command -v npx20
  elif command -v npx >/dev/null 2>&1; then
    local maj
    maj="$(node -p "process.versions.node.split('.')[0]" 2>/dev/null || echo 0)"
    [[ "$maj" -ge 18 ]] && command -v npx && return
    echo ""
  else
    echo ""
  fi
}

install_rules() {
  local rules_src="$AGL_SOURCE/.cursor/rules"
  local dst="$FG_LEGACY_ROOT/.cursor/rules"
  mkdir -p "$dst"
  local f
  for f in \
    learned-memories-fg-legacy.mdc \
    common-security-fg-legacy.mdc \
    php-security-fg-legacy.mdc \
    mandatory-delivery-pipeline-fg-legacy.mdc \
    common-git-workflow.mdc
  do
    [[ -f "$rules_src/$f" ]] || continue
    /usr/bin/install -m 0644 "$rules_src/$f" "$dst/$f"
    ok "rule $f"
  done
}

sync_skill() {
  local src="$1" name="$2"
  [[ -f "$src/SKILL.md" ]] || return 1
  for root in "$FG_LEGACY_ROOT/.cursor/skills" "$FG_LEGACY_ROOT/.claude/skills"; do
    mkdir -p "$root/$name"
    if command -v rsync >/dev/null 2>&1; then
      rsync -a --delete --exclude '.git' "$src/" "$root/$name/"
    else
      cp -a "$src/." "$root/$name/"
    fi
  done
  ok "skill $name"
}

sync_superpowers_extra() {
  local repo="$TMP_BASE/superpowers"
  mkdir -p "$TMP_BASE"
  if [[ ! -d "$repo/.git" ]]; then
    git clone --depth 1 https://github.com/obra/superpowers.git "$repo"
  fi
  local sd="$repo/skills/systematic-debugging"
  # ponytail: root-cause-tracing e defense-in-depth vivem como .md dentro de systematic-debugging
  if [[ -f "$sd/root-cause-tracing.md" ]]; then
    for root in "$FG_LEGACY_ROOT/.cursor/skills" "$FG_LEGACY_ROOT/.claude/skills"; do
      mkdir -p "$root/root-cause-tracing"
      {
        echo "---"
        echo "name: root-cause-tracing"
        echo "description: Rastrear causa raiz antes de corrigir bugs. Usar com systematic-debugging."
        echo "---"
        echo ""
        cat "$sd/root-cause-tracing.md"
      } >"$root/root-cause-tracing/SKILL.md"
    done
    ok "root-cause-tracing (from systematic-debugging)"
  fi
  if [[ -f "$sd/defense-in-depth.md" ]]; then
    for root in "$FG_LEGACY_ROOT/.cursor/skills" "$FG_LEGACY_ROOT/.claude/skills"; do
      mkdir -p "$root/defense-in-depth"
      {
        echo "---"
        echo "name: defense-in-depth"
        echo "description: Validação em múltiplas camadas — tornar bugs estruturalmente impossíveis."
        echo "---"
        echo ""
        cat "$sd/defense-in-depth.md"
      } >"$root/defense-in-depth/SKILL.md"
    done
    ok "defense-in-depth (from systematic-debugging)"
  fi
  if [[ -f "$sd/condition-based-waiting.md" ]]; then
    for root in "$FG_LEGACY_ROOT/.cursor/skills" "$FG_LEGACY_ROOT/.claude/skills"; do
      mkdir -p "$root/condition-based-waiting"
      cp -f "$sd/condition-based-waiting.md" "$root/condition-based-waiting/SKILL.md" 2>/dev/null || true
      [[ -f "$root/condition-based-waiting/SKILL.md" ]] && ok "condition-based-waiting"
    done
  fi
}

install_mcp_json() {
  local npx_bin
  npx_bin="$(resolve_npx)"
  [[ -n "$npx_bin" ]] || npx_bin="npx"
  mkdir -p "$FG_LEGACY_ROOT/.cursor"
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
      "description": "Segundo cérebro AGL — llm-wiki (fg-legacy CT549)"
    }
  }
}
JSON
  ok "mcp.json → ${npx_bin}"
}

install_maint_scripts() {
  mkdir -p "$FG_LEGACY_ROOT/scripts/maint"
  for s in install-node20-ct549.sh prepare-cursor-runtime-ct549.sh; do
    [[ -f "$AGL_SOURCE/scripts/maint/$s" ]] || continue
    /usr/bin/install -m 0755 "$AGL_SOURCE/scripts/maint/$s" "$FG_LEGACY_ROOT/scripts/maint/$s"
  done
  [[ -f "$AGL_SOURCE/scripts/maint/fgsrv07/lib/ct243-locale-php-pt-br.sh" ]] && {
    mkdir -p "$FG_LEGACY_ROOT/scripts/maint/fgsrv07/lib"
    /usr/bin/install -m 0755 "$AGL_SOURCE/scripts/maint/fgsrv07/lib/ct243-locale-php-pt-br.sh" \
      "$FG_LEGACY_ROOT/scripts/maint/fgsrv07/lib/"
  }
  /usr/bin/install -m 0755 "$SCRIPT_DIR/prune-fg-legacy-skills.sh" \
    "$FG_LEGACY_ROOT/scripts/skills/prune-fg-legacy-skills.sh" 2>/dev/null || true
  /usr/bin/install -m 0755 "$SCRIPT_DIR/verify-fg-legacy-pack.sh" \
    "$FG_LEGACY_ROOT/scripts/skills/verify-fg-legacy-pack.sh" 2>/dev/null || true
  ok "scripts maint + verify/prune"
}

patch_agents_md() {
  local agents="$FG_LEGACY_ROOT/AGENTS.md"
  [[ -f "$agents" ]] || return 0
  grep -q 'fg-legacy essentials' "$agents" 2>/dev/null && return 0
  cat >>"$agents" <<'EOF'

## fg-legacy essentials + Cursor no CT549

- Regras: `.cursor/rules/learned-memories-fg-legacy.mdc`, `mandatory-delivery-pipeline-fg-legacy.mdc`
- Node 20 (MCP): `bash scripts/maint/install-node20-ct549.sh` → `prepare-cursor-runtime-ct549.sh`
- Verificar pack: `bash scripts/skills/verify-fg-legacy-pack.sh`
- Podar skills irrelevantes: `PRUNE_SKILLS=1 bash scripts/skills/install-fg-legacy-essentials.sh`
- Wiki: [[fg-legacy — Operações CT549]]
EOF
  ok "AGENTS.md essentials"
}

main() {
  [[ -d "$FG_LEGACY_ROOT" ]] || { warn "FG_LEGACY_ROOT inexistente"; exit 1; }
  install_rules
  sync_superpowers_extra
  install_mcp_json
  install_maint_scripts
  if [[ "$INSTALL_NODE" == "1" ]] && [[ -f "$FG_LEGACY_ROOT/scripts/maint/install-node20-ct549.sh" ]]; then
    bash "$FG_LEGACY_ROOT/scripts/maint/install-node20-ct549.sh" || warn "install node20 falhou"
    install_mcp_json
    bash "$FG_LEGACY_ROOT/scripts/maint/prepare-cursor-runtime-ct549.sh" || warn "prepare cursor runtime falhou"
  fi
  if [[ "$PRUNE_SKILLS" == "1" ]] && [[ -x "$FG_LEGACY_ROOT/scripts/skills/prune-fg-legacy-skills.sh" ]]; then
    bash "$FG_LEGACY_ROOT/scripts/skills/prune-fg-legacy-skills.sh"
  fi
  patch_agents_md
  ok "fg-legacy essentials concluído"
}

main "$@"
