#!/usr/bin/env bash
# Pack AGL genérico para projetos CRM/ERP makemoney01 (por nicho).
#
# Uso:
#   bash scripts/skills/install-agl-pack-makemoney-niche.sh crm-imobiliaria
#   NICHE_ROOT=/path/to/erp-padaria bash scripts/skills/install-agl-pack-makemoney-niche.sh erp-padaria
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOSTMAN_ROOT="${AGL_SOURCE:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
NICHE_SLUG="${1:-${NICHE_SLUG:-}}"
NICHE_ROOT="${NICHE_ROOT:-/mnt/overpower/apps/dev/agl/${NICHE_SLUG}}"
LLM_WIKI_DIR="${LLM_WIKI_DIR:-/mnt/overpower/apps/dev/agl/llm-wiki}"
TMP_BASE="${TMPDIR:-/tmp}/niche-pack-${NICHE_SLUG:-x}-$$"
SKIP_GIT_CLONE="${SKIP_GIT_CLONE:-0}"

[[ -n "$NICHE_SLUG" ]] || { echo "ERRO: slug obrigatório" >&2; exit 1; }
[[ -d "$NICHE_ROOT" ]] || { echo "ERRO: NICHE_ROOT inexistente: $NICHE_ROOT" >&2; exit 1; }

log() { echo "[${NICHE_SLUG}-pack] $*"; }
ok() { echo "[OK] $*"; }
warn() { echo "[WARN] $*" >&2; }
cleanup() { rm -rf "$TMP_BASE"; }
trap cleanup EXIT

sync_skill_to_project() {
  local src="$1" name="$2"
  [[ -f "$src/SKILL.md" ]] || return 0
  for dest_root in "$NICHE_ROOT/.cursor/skills" "$NICHE_ROOT/.claude/skills"; do
    mkdir -p "$dest_root"
    if command -v rsync >/dev/null 2>&1; then
      rsync -a --delete --exclude '.git' "$src/" "$dest_root/$name/"
    else
      rm -rf "$dest_root/$name"
      mkdir -p "$dest_root/$name"
      cp -a "$src/." "$dest_root/$name/"
    fi
  done
  ok "skill $name"
}

clone_and_sync() {
  [[ "$SKIP_GIT_CLONE" == "1" ]] && return 0
  local url="$1" name="$2" subpath="${3:-}"
  local dir="$TMP_BASE/$name"
  [[ -d "$dir/.git" ]] || git clone --depth 1 "$url" "$dir"
  local src="$dir"
  [[ -n "$subpath" ]] && src="$dir/$subpath"
  sync_skill_to_project "$src" "$name"
}

install_core_rules() {
  local rules_src="$HOSTMAN_ROOT/.cursor/rules"
  local dst="$NICHE_ROOT/.cursor/rules"
  mkdir -p "$dst"
  for f in mandatory-delivery-pipeline.mdc karpathy-skills.mdc ponytail.mdc \
    prompt-improve.mdc self-improve.mdc session-reflect.mdc memory.mdc; do
    [[ -f "$rules_src/$f" ]] || continue
    /usr/bin/install -m 0644 "$rules_src/$f" "$dst/$f"
    ok "rule $f"
  done
  if [[ -f "$rules_src/llm-wiki-second-brain.mdc" ]]; then
    sed "s|agl-hostman|${NICHE_SLUG}|g" "$rules_src/llm-wiki-second-brain.mdc" >"$dst/llm-wiki-second-brain.mdc"
    ok "llm-wiki-second-brain.mdc"
  fi
  local proj_rule="$NICHE_ROOT/.cursor/rules/${NICHE_SLUG}-project.mdc"
  [[ -f "$proj_rule" ]] || warn "falta ${NICHE_SLUG}-project.mdc (correr scaffold)"

  local ponytail="$dst/ponytail.mdc"
  if [[ -f "$ponytail" ]] && ! grep -q "${NICHE_SLUG} override" "$ponytail" 2>/dev/null; then
    cat >>"$ponytail" <<EOF

## ${NICHE_SLUG} override

Demo CRM/ERP Alphaville — Laravel 12 + Inertia em \`src/\`. FAQ demo: makemoney01 \`data/clients/\`. Diff mínimo; testes: \`cd src && php artisan test\`.
EOF
    ok "ponytail override"
  fi

  local pipe="$dst/mandatory-delivery-pipeline.mdc"
  if [[ -f "$pipe" ]] && ! grep -q "${NICHE_SLUG}" "$pipe" 2>/dev/null; then
    cat >>"$pipe" <<EOF

## ${NICHE_SLUG} — testes

\`\`\`bash
bash scripts/skills/verify-${NICHE_SLUG}-pack.sh
php -l src/public/index.php
cd src && php artisan test
\`\`\`
EOF
    ok "pipeline override"
  fi
}

install_learned_memories() {
  local dst="$NICHE_ROOT/.cursor/rules/learned-memories.mdc"
  [[ -f "$dst" ]] && return 0
  cat >"$dst" <<EOF
---
trigger: model_decision
description: Conhecimento ${NICHE_SLUG} — demo CRM/ERP Alphaville.
---

# Project Memory — ${NICHE_SLUG}

- Mount: \`${NICHE_ROOT}\`
- Parent pipeline: makemoney01 (\`config/niche-projects.json\`)
- CT194 nginx: \`${NICHE_SLUG}.mm01.aglz.io\`
- Nunca commitar \`.env\` ou secrets.
EOF
  ok "learned-memories.mdc"
}

merge_mcp() {
  local mcp="$NICHE_ROOT/.cursor/mcp.json"
  mkdir -p "$NICHE_ROOT/.cursor"
  [[ -f "$mcp" ]] || echo '{"mcpServers":{}}' >"$mcp"
  python3 - "$mcp" "$LLM_WIKI_DIR" "$NICHE_SLUG" <<'PY'
import json, sys
path, wiki, slug = sys.argv[1:4]
with open(path, encoding="utf-8") as f:
    data = json.load(f)
servers = data.setdefault("mcpServers", {})
servers["llm-wiki-fs"] = {
    "type": "stdio",
    "command": "npx",
    "args": ["-y", "@modelcontextprotocol/server-filesystem", f"{wiki}/wiki", f"{wiki}/raw"],
    "description": f"llm-wiki ({slug})",
}
with open(path, "w", encoding="utf-8") as f:
    json.dump(data, f, indent=2, ensure_ascii=False)
    f.write("\n")
PY
  ok "mcp.json"
}

install_reflect_and_wiki() {
  [[ -f "$HOSTMAN_ROOT/.cursor/skills/reflect-yourself/SKILL.md" ]] && \
    sync_skill_to_project "$HOSTMAN_ROOT/.cursor/skills/reflect-yourself" "reflect-yourself"
  [[ -f "$HOSTMAN_ROOT/.cursor/skills/llm-wiki-ingest/SKILL.md" ]] && \
    sync_skill_to_project "$HOSTMAN_ROOT/.cursor/skills/llm-wiki-ingest" "llm-wiki-ingest"
}

sync_superpowers_subset() {
  [[ "$SKIP_GIT_CLONE" == "1" ]] && return 0
  local repo="$TMP_BASE/superpowers"
  [[ -d "$repo/.git" ]] || git clone --depth 1 https://github.com/obra/superpowers.git "$repo"
  for name in using-superpowers verification-before-completion systematic-debugging; do
    [[ -f "$repo/skills/$name/SKILL.md" ]] && sync_skill_to_project "$repo/skills/$name" "$name"
  done
}

install_verify() {
  mkdir -p "$NICHE_ROOT/scripts/skills"
  local dst="$NICHE_ROOT/scripts/skills/verify-${NICHE_SLUG}-pack.sh"
  if [[ -x "$dst" ]] && grep -q "verify-makemoney-niche-pack.sh" "$dst" 2>/dev/null; then
    ok "verify script (scaffold)"
    return 0
  fi
  cat >"$dst" <<EOF
#!/usr/bin/env bash
set -euo pipefail
ROOT="\$(cd "\$(dirname "\${BASH_SOURCE[0]}")/../.." && pwd)"
exec bash "$HOSTMAN_ROOT/scripts/skills/verify-makemoney-niche-pack.sh" "\$ROOT" "${NICHE_SLUG}"
EOF
  chmod +x "$dst"
  ok "verify script"
}

main() {
  mkdir -p "$TMP_BASE" "$NICHE_ROOT/.cursor/rules" "$NICHE_ROOT/.agents"
  install_core_rules
  install_learned_memories
  install_reflect_and_wiki
  merge_mcp
  sync_superpowers_subset
  clone_and_sync "https://github.com/blader/humanizer.git" "humanizer"
  install_verify
  ok "pack → $NICHE_ROOT"
}

main "$@"
