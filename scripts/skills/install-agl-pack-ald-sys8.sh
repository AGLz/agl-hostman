#!/usr/bin/env bash
# Pack AGL para ald-sys8 — segundo cérebro, Six Repos subset, arsenal, regras de entrega.
#
# Uso (NFS local ou agldv12):
#   bash scripts/skills/install-agl-pack-ald-sys8.sh
#   ALD_SYS8_ROOT=/mnt/overpower/apps/dev/ald/ald-sys8 bash scripts/skills/install-agl-pack-ald-sys8.sh
#   SKIP_GIT_CLONE=1 bash ...  # só regras + MCP merge (sem clone remoto)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOSTMAN_ROOT="${AGL_SOURCE:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
ALD_SYS8_ROOT="${ALD_SYS8_ROOT:-/mnt/overpower/apps/dev/ald/ald-sys8}"
LLM_WIKI_DIR="${LLM_WIKI_DIR:-/mnt/overpower/apps/dev/agl/llm-wiki}"
TMP_BASE="${TMPDIR:-/tmp}/ald-sys8-pack-$$"
SKIP_GIT_CLONE="${SKIP_GIT_CLONE:-0}"

log() { echo "[ald-sys8-pack] $*"; }
ok() { echo "[OK] $*"; }
warn() { echo "[WARN] $*" >&2; }

cleanup() { rm -rf "$TMP_BASE"; }
trap cleanup EXIT

sync_skill_to_project() {
  local src="$1" name="$2"
  [[ -f "$src/SKILL.md" ]] || { warn "SKILL.md em falta: $src"; return 1; }
  for dest_root in "$ALD_SYS8_ROOT/.cursor/skills" "$ALD_SYS8_ROOT/.claude/skills"; do
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
  local url="$1" name="$2" subpath="${3:-}"
  local dir="$TMP_BASE/$name"
  if [[ "$SKIP_GIT_CLONE" == "1" ]]; then
    warn "SKIP_GIT_CLONE=1 — saltar clone $name"
    return 0
  fi
  if [[ ! -d "$dir/.git" ]]; then
    git clone --depth 1 "$url" "$dir"
  fi
  local src="$dir"
  [[ -n "$subpath" ]] && src="$dir/$subpath"
  sync_skill_to_project "$src" "$name"
}

install_core_rules() {
  local rules_src="$HOSTMAN_ROOT/.cursor/rules"
  local dst="$ALD_SYS8_ROOT/.cursor/rules"
  mkdir -p "$dst"

  for f in mandatory-delivery-pipeline.mdc karpathy-skills.mdc ponytail.mdc; do
    [[ -f "$rules_src/$f" ]] || continue
    /usr/bin/install -m 0644 "$rules_src/$f" "$dst/$f"
    ok "rule $f"
  done

  # Segundo cérebro — adaptar paths do agl-hostman para ald-sys8
  if [[ -f "$rules_src/llm-wiki-second-brain.mdc" ]]; then
    sed \
      -e 's|agl-hostman|ald-sys8|g' \
      -e 's|Antes de implementar (ald-sys8)|Antes de implementar (ald-sys8)|g' \
      -e 's|Em `ald-sys8`, limitar|Em `ald-sys8`, limitar|g' \
      "$rules_src/llm-wiki-second-brain.mdc" >"$dst/llm-wiki-second-brain.mdc"
    ok "llm-wiki-second-brain.mdc (ald-sys8)"
  fi

  apply_ald_ponytail_override "$dst/ponytail.mdc"
  apply_ald_pipeline_override "$dst/mandatory-delivery-pipeline.mdc"
}

apply_ald_ponytail_override() {
  local file="$1"
  [[ -f "$file" ]] || return 0
  grep -q "ald-sys8 override" "$file" 2>/dev/null && return 0
  cat >>"$file" <<'EOF'

## ald-sys8 override

Migração VB.NET → Laravel 11 (TALL) em `src/`: **diff mínimo**, reutilizar padrões Livewire existentes, não reformatar ficheiros inteiros. Testes: `cd src && php artisan test --filter=...`. Paridade legado: skill `ald-migration-parity` antes de alterar regras de negócio.
EOF
  ok "ponytail ald-sys8 override"
}

apply_ald_pipeline_override() {
  local file="$1"
  [[ -f "$file" ]] || return 0
  grep -q "ald-sys8" "$file" 2>/dev/null && return 0
  cat >>"$file" <<'EOF'

## ald-sys8 — testes Laravel

```bash
cd src && php artisan test --filter=NomeDoTeste
cd src && php artisan test tests/Feature/CaminhoTest.php
./scripts/run-comprehensive-tests.sh   # suite alargada (repo root)
```

Dusk E2E: skill `ald-dusk-e2e` — não correr em CI sem browser configurado.
EOF
  ok "pipeline ald-sys8 override"
}

install_learned_memories() {
  local dst="$ALD_SYS8_ROOT/.cursor/rules/learned-memories.mdc"
  if [[ -f "$dst" ]]; then
    ok "learned-memories.mdc (já existe — não sobrescrever)"
    return 0
  fi
  cat >"$dst" <<'EOF'
---
trigger: model_decision
description: Conhecimento específico do projeto ald-sys8, convenções e preferências aprendidas.
---

# Project Memory — ald-sys8

Consultar antes de propor soluções. Actualizar via `/reflect-yourself` ou quando o utilizador corrigir o agente.

## User Preferences

- **Idioma:** responder sempre em Português.
- **Diff mínimo:** seguir `ponytail.mdc` — migração incremental VB.NET → Laravel.

## Technical Decisions

### Stack

- Laravel 11 + Livewire 3 (TALL) em `src/`.
- Legado SQL Server: skill `ald-legacy-sqlserver`; credenciais em `src/.env`.
- Rotas admin: preferir nomes em português (`/admin/usuarios` vs `/admin/users`) — verificar `routes/web.php` antes de assumir paths de testes.

### Testes

- Artisan a partir de `src/`: `php artisan test`.
- Isolamento de testes ainda problemático em alguns módulos — ver `AGENTS.md` blockers.

## Wiki

- Runbooks e decisões duráveis → llm-wiki (`wiki/index.md`), não duplicar em `docs/` solto.
- Contrato agentes: [[agl-hostman — Contrato Agentes Cursor]]
EOF
  ok "learned-memories.mdc (starter ald-sys8)"
}

install_wiki_ingest_pack() {
  local skill_src="$HOSTMAN_ROOT/.cursor/skills/llm-wiki-ingest/SKILL.md"
  local cmd_src="$HOSTMAN_ROOT/.cursor/commands/llm-wiki-ingest.md"
  [[ -f "$skill_src" ]] || return 0
  mkdir -p "$ALD_SYS8_ROOT/.cursor/skills/llm-wiki-ingest" \
    "$ALD_SYS8_ROOT/.claude/skills/llm-wiki-ingest" \
    "$ALD_SYS8_ROOT/.cursor/commands"
  /usr/bin/install -m 0644 "$skill_src" "$ALD_SYS8_ROOT/.cursor/skills/llm-wiki-ingest/SKILL.md"
  /usr/bin/install -m 0644 "$skill_src" "$ALD_SYS8_ROOT/.claude/skills/llm-wiki-ingest/SKILL.md"
  [[ -f "$cmd_src" ]] && /usr/bin/install -m 0644 "$cmd_src" "$ALD_SYS8_ROOT/.cursor/commands/llm-wiki-ingest.md"
  ok "llm-wiki-ingest skill + command"
}

merge_mcp_llm_wiki() {
  local mcp="$ALD_SYS8_ROOT/.cursor/mcp.json"
  mkdir -p "$ALD_SYS8_ROOT/.cursor"
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
    "args": [
        "-y",
        "@modelcontextprotocol/server-filesystem",
        f"{wiki}/wiki",
        f"{wiki}/raw",
    ],
    "description": "Segundo cérebro AGL — llm-wiki wiki/ e raw/ (ald-sys8)",
}
with open(path, "w", encoding="utf-8") as f:
    json.dump(data, f, indent=2, ensure_ascii=False)
    f.write("\n")
PY
  ok "mcp.json merge llm-wiki-fs"
}

sync_superpowers_subset() {
  [[ "$SKIP_GIT_CLONE" == "1" ]] && return 0
  local repo="$TMP_BASE/superpowers"
  mkdir -p "$TMP_BASE"
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
    for root in "$ALD_SYS8_ROOT/.cursor/skills" "$ALD_SYS8_ROOT/.claude/skills"; do
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
    ok "root-cause-tracing"
  fi
  if [[ -f "$sd/defense-in-depth.md" ]]; then
    for root in "$ALD_SYS8_ROOT/.cursor/skills" "$ALD_SYS8_ROOT/.claude/skills"; do
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
    ok "defense-in-depth"
  fi
}

sync_content_skills() {
  clone_and_sync "https://github.com/blader/humanizer.git" "humanizer"
  clone_and_sync "https://github.com/petar-nauka/fact-check-skill.git" "fact-check"
  clone_and_sync "https://github.com/severity1/claude-code-prompt-improver.git" "prompt-improver" "skills/prompt-improver"
  mkdir -p "$ALD_SYS8_ROOT/.cursor"
  cat >"$ALD_SYS8_ROOT/.cursor/content-skills-sync-state.json" <<JSON
{
  "synced_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "host": "ald-sys8",
  "skills": ["humanizer", "fact-check", "prompt-improver"]
}
JSON
  ok "content-skills state"
}

sync_obsidian_cli() {
  [[ "$SKIP_GIT_CLONE" == "1" ]] && return 0
  local repo="$TMP_BASE/Obsidian-CLI-skill"
  if [[ ! -d "$repo/.git" ]]; then
    git clone --depth 1 https://github.com/pablo-mano/Obsidian-CLI-skill.git "$repo"
  fi
  sync_skill_to_project "$repo/skills/obsidian-cli" "obsidian-cli"
}

sync_arsenal_subset() {
  [[ "$SKIP_GIT_CLONE" == "1" ]] && return 0
  if [[ -f "$HOSTMAN_ROOT/.cursor/skills/improve/SKILL.md" ]]; then
    sync_skill_to_project "$HOSTMAN_ROOT/.cursor/skills/improve" "improve"
  else
    local improve_repo="$TMP_BASE/improve"
    if [[ ! -d "$improve_repo/.git" ]]; then
      git clone --depth 1 https://github.com/shadcn/improve.git "$improve_repo"
    fi
    if [[ -f "$improve_repo/skills/improve/SKILL.md" ]]; then
      sync_skill_to_project "$improve_repo/skills/improve" "improve"
    elif [[ -f "$improve_repo/SKILL.md" ]]; then
      sync_skill_to_project "$improve_repo" "improve"
    fi
  fi
  local drawio_repo="$TMP_BASE/drawio-skill"
    git clone --depth 1 https://github.com/Agents365-ai/drawio-skill.git "$drawio_repo"
  fi
  local drawio_src="$drawio_repo/skills/drawio-skill"
  [[ ! -f "$drawio_src/SKILL.md" && -f "$drawio_repo/SKILL.md" ]] && drawio_src="$drawio_repo"
  if [[ -f "$drawio_src/SKILL.md" ]]; then
    sync_skill_to_project "$drawio_src" "drawio-skill"
  else
    warn "drawio-skill em falta no clone — saltar"
  fi
  if [[ -f "$HOSTMAN_ROOT/.cursor/skills/agl-architecture-diagram/SKILL.md" ]]; then
    sync_skill_to_project "$HOSTMAN_ROOT/.cursor/skills/agl-architecture-diagram" "agl-architecture-diagram"
  fi
}

install_verify_script() {
  mkdir -p "$ALD_SYS8_ROOT/scripts/skills"
  /usr/bin/install -m 0755 "$SCRIPT_DIR/verify-ald-sys8-pack.sh" \
    "$ALD_SYS8_ROOT/scripts/skills/verify-ald-sys8-pack.sh"
  ok "verify-ald-sys8-pack.sh → projeto"
}

patch_agents_md() {
  local agents="$ALD_SYS8_ROOT/AGENTS.md"
  [[ -f "$agents" ]] || return 0
  grep -q 'Pack AGL (ald-sys8)' "$agents" 2>/dev/null && return 0
  cat >>"$agents" <<EOF

## Pack AGL (ald-sys8)

- Segundo cérebro: \`.cursor/rules/llm-wiki-second-brain.mdc\`, MCP \`llm-wiki-fs\`, vault \`${LLM_WIKI_DIR}\`
- Six Repos subset: humanizer, fact-check, prompt-improver, obsidian-cli, superpowers, karpathy
- Entrega: \`mandatory-delivery-pipeline.mdc\`, \`ponytail.mdc\`, \`learned-memories.mdc\`
- Ingest wiki: skill \`llm-wiki-ingest\`, comando \`/llm-wiki-ingest\`
- Verificar: \`bash scripts/skills/verify-ald-sys8-pack.sh\`
- Reinstalar: \`agl-hostman/scripts/skills/install-agl-pack-ald-sys8.sh\`
EOF
  ok "AGENTS.md pack AGL"
}

main() {
  [[ -d "$ALD_SYS8_ROOT" ]] || { warn "ALD_SYS8_ROOT inexistente: $ALD_SYS8_ROOT"; exit 1; }
  [[ -f "$LLM_WIKI_DIR/wiki/index.md" ]] || warn "llm-wiki vault em falta: $LLM_WIKI_DIR/wiki/index.md"
  mkdir -p "$TMP_BASE"
  install_core_rules
  install_learned_memories
  install_wiki_ingest_pack
  merge_mcp_llm_wiki
  sync_obsidian_cli
  sync_superpowers_subset
  sync_content_skills
  sync_arsenal_subset
  install_verify_script
  patch_agents_md
  ok "ald-sys8 pack concluído → $ALD_SYS8_ROOT"
}

main "$@"
