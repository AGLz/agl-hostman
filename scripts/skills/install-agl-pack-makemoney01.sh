#!/usr/bin/env bash
# Pack AGL para makemoney01 — segundo cérebro, Six Repos, graphify, pipeline skills.
#
# Uso:
#   bash scripts/skills/install-agl-pack-makemoney01.sh
#   MAKEMONEY01_ROOT=/mnt/overpower/apps/dev/agl/makemoney01 bash scripts/skills/install-agl-pack-makemoney01.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOSTMAN_ROOT="${AGL_SOURCE:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
MAKEMONEY01_ROOT="${MAKEMONEY01_ROOT:-/mnt/overpower/apps/dev/agl/makemoney01}"
LLM_WIKI_DIR="${LLM_WIKI_DIR:-/mnt/overpower/apps/dev/agl/llm-wiki}"
TMP_BASE="${TMPDIR:-/tmp}/makemoney01-pack-$$"
SKIP_GIT_CLONE="${SKIP_GIT_CLONE:-0}"

log() { echo "[makemoney01-pack] $*"; }
ok() { echo "[OK] $*"; }
warn() { echo "[WARN] $*" >&2; }

cleanup() { rm -rf "$TMP_BASE"; }
trap cleanup EXIT

sync_skill_to_project() {
  local src="$1" name="$2"
  [[ -f "$src/SKILL.md" ]] || { warn "SKILL.md em falta: $src"; return 1; }
  local src_real
  src_real="$(cd "$src" && pwd -P)"
  for dest_root in "$MAKEMONEY01_ROOT/.cursor/skills" "$MAKEMONEY01_ROOT/.claude/skills"; do
    mkdir -p "$dest_root"
    local dest="$dest_root/$name"
    if [[ -d "$dest" ]]; then
      local dest_real
      dest_real="$(cd "$dest" && pwd -P)"
      if [[ "$src_real" == "$dest_real" ]]; then
        ok "skill $name (já em $(basename "$dest_root"))"
        continue
      fi
    fi
    if command -v rsync >/dev/null 2>&1; then
      rsync -a --delete --exclude '.git' "$src/" "$dest/"
    else
      rm -rf "$dest"
      mkdir -p "$dest"
      cp -a "$src/." "$dest/"
    fi
  done
  ok "skill $name"
}

clone_and_sync() {
  local url="$1" name="$2" subpath="${3:-}"
  [[ "$SKIP_GIT_CLONE" == "1" ]] && return 0
  local dir="$TMP_BASE/$name"
  [[ -d "$dir/.git" ]] || git clone --depth 1 "$url" "$dir"
  local src="$dir"
  [[ -n "$subpath" ]] && src="$dir/$subpath"
  sync_skill_to_project "$src" "$name"
}

install_core_rules() {
  local rules_src="$HOSTMAN_ROOT/.cursor/rules"
  local dst="$MAKEMONEY01_ROOT/.cursor/rules"
  mkdir -p "$dst"

  for f in mandatory-delivery-pipeline.mdc karpathy-skills.mdc ponytail.mdc \
    prompt-improve.mdc self-improve.mdc session-reflect.mdc memory.mdc \
    makemoney01-project.mdc; do
    [[ -f "$rules_src/$f" ]] || continue
    /usr/bin/install -m 0644 "$rules_src/$f" "$dst/$f"
    ok "rule $f"
  done

  if [[ -f "$rules_src/llm-wiki-second-brain.mdc" ]]; then
    sed 's|agl-hostman|makemoney01|g' "$rules_src/llm-wiki-second-brain.mdc" >"$dst/llm-wiki-second-brain.mdc"
    ok "llm-wiki-second-brain.mdc (makemoney01)"
  fi

  apply_makemoney_ponytail_override "$dst/ponytail.mdc"
  apply_makemoney_pipeline_override "$dst/mandatory-delivery-pipeline.mdc"
}

apply_makemoney_ponytail_override() {
  local file="$1"
  [[ -f "$file" ]] || return 0
  grep -q "makemoney01 override" "$file" 2>/dev/null && return 0
  cat >>"$file" <<'EOF'

## makemoney01 override

Pipeline de oportunidades AI: **diff mínimo** em `data/`, `scripts/`, `wiki-ingest/`. Não reescrever dossiês inteiros — actualizar secções afectadas. Testes: `python3 tests/test_*.py`. Prioridade Q3: Speed-to-Lead (ver `makemoney01-project.mdc`).
EOF
  ok "ponytail makemoney01 override"
}

apply_makemoney_pipeline_override() {
  local file="$1"
  [[ -f "$file" ]] || return 0
  grep -q "makemoney01" "$file" 2>/dev/null && return 0
  cat >>"$file" <<'EOF'

## makemoney01 — testes

```bash
python3 tests/test_dossiers.py
python3 tests/test_pipeline.py 2>/dev/null || true
bash scripts/wiki/graphify-makemoney.sh
```
EOF
  ok "pipeline makemoney01 override"
}

install_learned_memories() {
  local dst="$MAKEMONEY01_ROOT/.cursor/rules/learned-memories.mdc"
  if [[ -f "$dst" ]]; then
    ok "learned-memories.mdc (já existe)"
    return 0
  fi
  cat >"$dst" <<'EOF'
---
trigger: model_decision
description: Conhecimento específico makemoney01 — pipeline AI, Hermes, monetização AGLz.
---

# Project Memory — makemoney01

## Preferências

- Idioma: Português (pt-BR) em conteúdo de negócio.
- Diff mínimo (`ponytail.mdc`); não commitar `.env`.

## Decisões

- **Q3 P0:** Speed-to-Lead Imobiliária — meta R$2,5k MRR ([[makemoney01-Q3-Decisao-Speed-to-Lead]]).
- Mount canónico: `/mnt/overpower/apps/dev/agl/makemoney01`.
- Hermes Satya: crons 06:30–08:15; scripts em `agl-hostman/scripts/monitoring/`.
- Wiki: `wiki-ingest/` → Curator; runbooks em llm-wiki, não duplicar em README longo.

## APIs research

- Exa/Firecrawl: `.env` local; sync via `agl-hostman/scripts/makemoney/sync-video-api-keys-agldv.sh`.
EOF
  ok "learned-memories.mdc (starter)"
}

install_reflect_pack() {
  local src="$HOSTMAN_ROOT/.cursor/skills/reflect-yourself"
  [[ -f "$src/SKILL.md" ]] || return 0
  sync_skill_to_project "$src" "reflect-yourself"
  [[ -f "$HOSTMAN_ROOT/.cursor/commands/reflect-yourself.md" ]] && {
    mkdir -p "$MAKEMONEY01_ROOT/.cursor/commands"
    /usr/bin/install -m 0644 "$HOSTMAN_ROOT/.cursor/commands/reflect-yourself.md" \
      "$MAKEMONEY01_ROOT/.cursor/commands/reflect-yourself.md"
  }
  ok "reflect-yourself pack"
}

install_wiki_ingest_pack() {
  local skill_src="$HOSTMAN_ROOT/.cursor/skills/llm-wiki-ingest/SKILL.md"
  local cmd_src="$HOSTMAN_ROOT/.cursor/commands/llm-wiki-ingest.md"
  [[ -f "$skill_src" ]] || return 0
  mkdir -p "$MAKEMONEY01_ROOT/.cursor/skills/llm-wiki-ingest" \
    "$MAKEMONEY01_ROOT/.claude/skills/llm-wiki-ingest" \
    "$MAKEMONEY01_ROOT/.cursor/commands"
  /usr/bin/install -m 0644 "$skill_src" "$MAKEMONEY01_ROOT/.cursor/skills/llm-wiki-ingest/SKILL.md"
  /usr/bin/install -m 0644 "$skill_src" "$MAKEMONEY01_ROOT/.claude/skills/llm-wiki-ingest/SKILL.md"
  [[ -f "$cmd_src" ]] && /usr/bin/install -m 0644 "$cmd_src" "$MAKEMONEY01_ROOT/.cursor/commands/llm-wiki-ingest.md"
  ok "llm-wiki-ingest"
}

merge_mcp_llm_wiki() {
  local mcp="$MAKEMONEY01_ROOT/.cursor/mcp.json"
  mkdir -p "$MAKEMONEY01_ROOT/.cursor"
  [[ -f "$mcp" ]] || echo '{"mcpServers":{}}' >"$mcp"
  python3 - "$mcp" "$LLM_WIKI_DIR" <<'PY'
import json, sys
path, wiki = sys.argv[1], sys.argv[2]
with open(path, encoding="utf-8") as f:
    data = json.load(f)
servers = data.setdefault("mcpServers", {})
servers["llm-wiki-fs"] = {
    "type": "stdio",
    "command": "npx",
    "args": ["-y", "@modelcontextprotocol/server-filesystem", f"{wiki}/wiki", f"{wiki}/raw"],
    "description": "Segundo cérebro AGL — llm-wiki (makemoney01)",
}
with open(path, "w", encoding="utf-8") as f:
    json.dump(data, f, indent=2, ensure_ascii=False)
    f.write("\n")
PY
  ok "mcp.json llm-wiki-fs"
}

sync_superpowers_subset() {
  [[ "$SKIP_GIT_CLONE" == "1" ]] && return 0
  local repo="$TMP_BASE/superpowers"
  mkdir -p "$TMP_BASE"
  [[ -d "$repo/.git" ]] || git clone --depth 1 https://github.com/obra/superpowers.git "$repo"
  local name
  for name in using-superpowers brainstorming executing-plans verification-before-completion systematic-debugging; do
    [[ -f "$repo/skills/$name/SKILL.md" ]] && sync_skill_to_project "$repo/skills/$name" "$name"
  done
  local sd="$repo/skills/systematic-debugging"
  for extra in root-cause-tracing defense-in-depth; do
    [[ -f "$sd/${extra}.md" ]] || continue
    for root in "$MAKEMONEY01_ROOT/.cursor/skills" "$MAKEMONEY01_ROOT/.claude/skills"; do
      mkdir -p "$root/$extra"
      { echo "---"; echo "name: $extra"; echo "---"; echo ""; cat "$sd/${extra}.md"; } >"$root/$extra/SKILL.md"
    done
    ok "$extra"
  done
}

sync_content_skills() {
  clone_and_sync "https://github.com/blader/humanizer.git" "humanizer"
  clone_and_sync "https://github.com/petar-nauka/fact-check-skill.git" "fact-check"
  clone_and_sync "https://github.com/severity1/claude-code-prompt-improver.git" "prompt-improver" "skills/prompt-improver"
  mkdir -p "$MAKEMONEY01_ROOT/.cursor"
  cat >"$MAKEMONEY01_ROOT/.cursor/content-skills-sync-state.json" <<JSON
{"synced_at":"$(date -u +%Y-%m-%dT%H:%M:%SZ)","host":"makemoney01","skills":["humanizer","fact-check","prompt-improver"]}
JSON
  ok "content-skills"
}

sync_obsidian_cli() {
  [[ "$SKIP_GIT_CLONE" == "1" ]] && return 0
  local repo="$TMP_BASE/Obsidian-CLI-skill"
  [[ -d "$repo/.git" ]] || git clone --depth 1 https://github.com/pablo-mano/Obsidian-CLI-skill.git "$repo"
  sync_skill_to_project "$repo/skills/obsidian-cli" "obsidian-cli"
}

sync_arsenal_subset() {
  [[ "$SKIP_GIT_CLONE" == "1" ]] && return 0
  [[ -f "$HOSTMAN_ROOT/.cursor/skills/improve/SKILL.md" ]] && sync_skill_to_project "$HOSTMAN_ROOT/.cursor/skills/improve" "improve"
  [[ -f "$HOSTMAN_ROOT/.cursor/skills/agl-architecture-diagram/SKILL.md" ]] && sync_skill_to_project "$HOSTMAN_ROOT/.cursor/skills/agl-architecture-diagram" "agl-architecture-diagram"
  local drawio_repo="$TMP_BASE/drawio-skill"
  [[ -d "$drawio_repo/.git" ]] || git clone --depth 1 https://github.com/Agents365-ai/drawio-skill.git "$drawio_repo"
  local drawio_src="$drawio_repo/skills/drawio-skill"
  [[ ! -f "$drawio_src/SKILL.md" && -f "$drawio_repo/SKILL.md" ]] && drawio_src="$drawio_repo"
  [[ -f "$drawio_src/SKILL.md" ]] && sync_skill_to_project "$drawio_src" "drawio-skill"
}

install_makemoney_native_skills() {
  local src="$MAKEMONEY01_ROOT/.cursor/skills/makemoney-pipeline"
  [[ -f "$src/SKILL.md" ]] && sync_skill_to_project "$src" "makemoney-pipeline"
  # marketing-agent thin copy from agl-hostman agency rules — skip heavy agency/*
  if [[ -f "$HOSTMAN_ROOT/.cursor/skills/marketing-agent/SKILL.md" ]]; then
    sync_skill_to_project "$HOSTMAN_ROOT/.cursor/skills/marketing-agent" "marketing-agent"
  fi
}

install_graphify() {
  mkdir -p "$MAKEMONEY01_ROOT/scripts/wiki" "$MAKEMONEY01_ROOT/data/graph"
  chmod +x "$MAKEMONEY01_ROOT/scripts/wiki/graphify-makemoney.sh" 2>/dev/null || true
  if [[ -f "$MAKEMONEY01_ROOT/scripts/wiki/makemoney-graphify.py" ]]; then
    chmod +x "$MAKEMONEY01_ROOT/scripts/wiki/makemoney-graphify.py"
    MAKEMONEY_ROOT="$MAKEMONEY01_ROOT" LLM_WIKI_DIR="$LLM_WIKI_DIR" \
      python3 "$MAKEMONEY01_ROOT/scripts/wiki/makemoney-graphify.py" || warn "graphify primeira corrida falhou"
    ok "graphify data/graph/"
  fi
}

install_verify_script() {
  mkdir -p "$MAKEMONEY01_ROOT/scripts/skills"
  /usr/bin/install -m 0755 "$SCRIPT_DIR/verify-makemoney01-pack.sh" \
    "$MAKEMONEY01_ROOT/scripts/skills/verify-makemoney01-pack.sh"
  ok "verify script"
}

patch_readme() {
  local readme="$MAKEMONEY01_ROOT/README.md"
  [[ -f "$readme" ]] || return 0
  grep -q 'Pack AGL (makemoney01)' "$readme" 2>/dev/null && return 0
  cat >>"$readme" <<EOF

## Pack AGL (Cursor / Claude Code)

- Regras: \`.cursor/rules/makemoney01-project.mdc\`, \`llm-wiki-second-brain.mdc\`, \`ponytail.mdc\`
- Skills: \`makemoney-pipeline\`, Six Repos subset, \`llm-wiki-ingest\`, \`reflect-yourself\`
- MCP: \`llm-wiki-fs\` em \`.cursor/mcp.json\`
- Graphify: \`bash scripts/wiki/graphify-makemoney.sh\` → \`data/graph/\`
- Verificar: \`bash scripts/skills/verify-makemoney01-pack.sh\`
- Reinstalar: \`agl-hostman/scripts/skills/install-agl-pack-makemoney01.sh\`
EOF
  ok "README pack section"
}

write_agents_md() {
  local agents="$MAKEMONEY01_ROOT/AGENTS.md"
  grep -q 'Pack AGL' "$agents" 2>/dev/null && return 0
  cat >"$agents" <<EOF
# makemoney01 — AGENTS

Pipeline autónomo de oportunidades AI para AGLz. Ver \`README.md\`.

## Pack AGL

| Item | Path |
|------|------|
| Project rule | \`.cursor/rules/makemoney01-project.mdc\` |
| Segundo cérebro | \`llm-wiki-second-brain.mdc\`, MCP \`llm-wiki-fs\` |
| Pipeline skill | \`.cursor/skills/makemoney-pipeline/\` |
| Graphify | \`scripts/wiki/graphify-makemoney.sh\` |
| Verify | \`scripts/skills/verify-makemoney01-pack.sh\` |

## Wiki

- [[makemoney01]] — índice
- [[makemoney01-Q3-Decisao-Speed-to-Lead]] — prioridade Q3
- [[makemoney01 - Hermes Integration & Pipeline]]

## Hermes (agl-hostman)

\`scripts/monitoring/hermes-makemoney-*.sh\` — não duplicar aqui.
EOF
  ok "AGENTS.md"
}

main() {
  [[ -d "$MAKEMONEY01_ROOT" ]] || { warn "MAKEMONEY01_ROOT inexistente"; exit 1; }
  mkdir -p "$TMP_BASE" "$MAKEMONEY01_ROOT/.cursor/rules" "$MAKEMONEY01_ROOT/scripts/wiki"
  install_core_rules
  install_learned_memories
  install_reflect_pack
  install_wiki_ingest_pack
  merge_mcp_llm_wiki
  sync_obsidian_cli
  sync_superpowers_subset
  sync_content_skills
  sync_arsenal_subset
  install_makemoney_native_skills
  install_graphify
  install_verify_script
  write_agents_md
  patch_readme
  ok "makemoney01 pack → $MAKEMONEY01_ROOT"
}

main "$@"
