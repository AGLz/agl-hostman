#!/usr/bin/env bash
# Sincroniza os 6 repos do plano Six Repos + content-skills (humanizer, fact-check, prompt-improver).
# Plano: ai-docs/planning/SIX-REPOS-MULTI-AGENT-PLAN.md
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOSTMAN_ROOT="${HOSTMAN_ROOT_OVERRIDE:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
LLM_WIKI_DIR="${LLM_WIKI_DIR:-/mnt/overpower/apps/dev/agl/llm-wiki}"
TEMP_BASE="/tmp/six-repos-sync-$$"

DRY_RUN=0
METHOD="copy"
REPOS="all"
HARNESS="all"

YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_ok() { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }

usage() {
  cat <<USAGE
Usage: $(basename "$0") [options]

Sincroniza repos GitHub (plano Six Repos) para harnesses locais.

Options:
  --dry-run              Mostrar acções sem executar
  --method copy|symlink  Método para skills (default: copy)
  --repo <name|all>      obsidian|superpowers|ecc|qa-devsecops|ruflo|open-design|karpathy|harness-router|content-skills|humanizer|fact-check|prompt-improver|all
  --harness <csv|all>    claude,cursor,codex,verdent,llm-wiki,hostman (default: all)
  -h, --help

Exemplos:
  $(basename "$0") --dry-run
  $(basename "$0") --repo obsidian --harness claude,cursor,codex,verdent
  $(basename "$0") --repo obsidian --method symlink --harness llm-wiki
  $(basename "$0") --repo content-skills --harness cursor,hostman-cursor
  $(basename "$0") --repo humanizer --dry-run
USAGE
}

trim() {
  local v="$1"
  v="${v#${v%%[![:space:]]*}}"
  v="${v%${v##*[![:space:]]}}"
  printf '%s' "$v"
}

harness_root() {
  case "$1" in
    claude|claude-code) printf '%s' "$HOME/.claude/skills" ;;
    cursor) printf '%s' "$HOME/.cursor/skills" ;;
    codex) printf '%s' "$HOME/.codex/skills" ;;
    verdent) printf '%s' "$HOME/.verdent/skills" ;;
    llm-wiki) printf '%s' "$LLM_WIKI_DIR/.claude/skills" ;;
    hostman) printf '%s' "$HOSTMAN_ROOT/.claude/skills" ;;
    hostman-cursor) printf '%s' "$HOSTMAN_ROOT/.cursor/skills" ;;
    *) printf '%s' "" ;;
  esac
}

run_or_echo() {
  if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "  [dry-run] $*"
  else
    "$@"
  fi
}

copy_dir_sync() {
  local source_dir="$1"
  local dest_dir="$2"
  if command -v rsync >/dev/null 2>&1; then
    rsync -a --delete \
      --exclude '.git' \
      --exclude '.DS_Store' \
      --exclude '*.zip' \
      --exclude '*.skill' \
      "$source_dir/" "$dest_dir/"
  else
    rm -rf "$dest_dir"
    mkdir -p "$dest_dir"
    cp -a "$source_dir/." "$dest_dir/"
  fi
}

sync_skill_dir() {
  local source_dir="$1"
  local skill_name="$2"
  local harness_csv="$3"

  if [[ ! -f "$source_dir/SKILL.md" ]]; then
    echo "SKILL.md em falta: $source_dir" >&2
    return 1
  fi

  IFS=',' read -r -a agents <<< "$harness_csv"
  for raw in "${agents[@]}"; do
    local agent
    agent="$(trim "$raw")"
    [[ -z "$agent" ]] && continue

    local root
    root="$(harness_root "$agent")"
    if [[ -z "$root" ]]; then
      log_warn "Harness desconhecido: $agent"
      continue
    fi

    local dest="$root/$skill_name"
    if [[ "$DRY_RUN" -eq 1 ]]; then
      echo "  [dry-run] sync $skill_name -> $dest ($METHOD)"
      continue
    fi

    mkdir -p "$root"
    if [[ "$METHOD" == "symlink" ]]; then
      rm -rf "$dest"
      ln -s "$source_dir" "$dest"
      log_ok "[$agent] symlink $dest -> $source_dir"
    else
      if [[ -L "$dest" ]]; then
        rm -f "$dest"
      fi
      mkdir -p "$dest"
      copy_dir_sync "$source_dir" "$dest"
      log_ok "[$agent] copied $dest"
    fi
  done
}

clone_repo() {
  local url="$1"
  local dir="$2"
  if [[ -d "$dir/.git" ]]; then
    log_info "Pull $url"
    if [[ "$DRY_RUN" -eq 1 ]]; then
      echo "  [dry-run] git -C $dir pull --ff-only"
    else
      git -C "$dir" pull --ff-only
    fi
  else
    log_info "Clone $url -> $dir"
    if command -v gh >/dev/null 2>&1 && [[ "$url" =~ github\.com[:/]([^/]+)/([^/.]+)(\.git)?$ ]]; then
      local slug="${BASH_REMATCH[1]}/${BASH_REMATCH[2]}"
      run_or_echo gh repo clone "$slug" "$dir" -- --depth 1
    else
      run_or_echo git clone --depth 1 "$url" "$dir"
    fi
  fi
}

resolve_harness_list() {
  if [[ "$HARNESS" == "all" ]]; then
    printf '%s' "claude,cursor,codex,verdent,llm-wiki,hostman"
  else
    printf '%s' "$HARNESS"
  fi
}

resolve_content_harness_list() {
  local base
  base="$(resolve_harness_list)"
  # hostman-cursor só quando hostman está seleccionado (não confundir com harness "cursor"=home)
  if [[ "$HARNESS" == "all" || "$HARNESS" == *hostman* ]]; then
    if [[ "$base" != *hostman-cursor* ]]; then
      base="${base},hostman-cursor"
    fi
  fi
  printf '%s' "$base"
}

harness_selected() {
  local agent="$1"
  if [[ "$HARNESS" == "all" ]]; then
    return 0
  fi
  IFS=',' read -r -a agents <<< "$HARNESS"
  for raw in "${agents[@]}"; do
    if [[ "$(trim "$raw")" == "$agent" ]]; then
      return 0
    fi
  done
  return 1
}

ecc_repo_dir() {
  printf '%s' "${ECC_REPO_DIR:-$HOME/dev/everything-claude-code}"
}

ensure_ecc_repo() {
  local repo_dir
  repo_dir="$(ecc_repo_dir)"
  clone_repo "https://github.com/affaan-m/everything-claude-code.git" "$repo_dir"
  if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "  [dry-run] npm install em $repo_dir (se node_modules em falta)"
    return 0
  fi
  if [[ ! -d "$repo_dir/node_modules" ]]; then
    log_info "npm install em $repo_dir"
    (cd "$repo_dir" && npm install --omit=dev)
  fi
}

run_ecc_install() {
  local target="$1"
  local project_dir="${2:-}"
  local repo_dir
  repo_dir="$(ecc_repo_dir)"
  local -a cmd=(node "$repo_dir/scripts/install-apply.js" --profile minimal --target "$target")
  if [[ "$DRY_RUN" -eq 1 ]]; then
    cmd+=(--dry-run)
  fi
  if [[ -n "$project_dir" ]]; then
    log_info "ECC minimal -> $target (cwd=$project_dir)"
    if [[ "$DRY_RUN" -eq 1 ]]; then
      echo "  [dry-run] (cd $project_dir && ${cmd[*]})"
    else
      (cd "$project_dir" && "${cmd[@]}")
    fi
  else
    log_info "ECC minimal -> $target (home)"
    if [[ "$DRY_RUN" -eq 1 ]]; then
      echo "  [dry-run] ${cmd[*]}"
    else
      "${cmd[@]}"
    fi
  fi
}

sync_obsidian() {
  log_info "=== obsidian-cli (pablo-mano/Obsidian-CLI-skill) ==="
  local repo_dir="$TEMP_BASE/Obsidian-CLI-skill"
  clone_repo "https://github.com/pablo-mano/Obsidian-CLI-skill.git" "$repo_dir"

  if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "  [dry-run] sync obsidian-cli -> $(resolve_harness_list)"
    echo "  [dry-run] ensure plugin config in $LLM_WIKI_DIR/.claude/settings.json"
    return 0
  fi

  sync_skill_dir "$repo_dir/skills/obsidian-cli" "obsidian-cli" "$(resolve_content_harness_list)"

  local settings="$LLM_WIKI_DIR/.claude/settings.json"
  if [[ -d "$LLM_WIKI_DIR" ]]; then
    mkdir -p "$LLM_WIKI_DIR/.claude"
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
      log_ok "Criado $settings (plugin obsidian-cli)"
    else
      log_warn "Já existe $settings — rever plugin obsidian-cli manualmente"
    fi
  fi
}

sync_superpowers() {
  log_info "=== superpowers (obra/superpowers) ==="
  local cache="$HOME/.claude/plugins/cache/superpowers-marketplace/superpowers"
  local source=""
  if [[ -d "$cache" ]]; then
    source="$(find "$cache" -mindepth 1 -maxdepth 1 -type d | head -1)/skills"
  fi
  if [[ ! -d "$source" ]]; then
    local repo_dir="$TEMP_BASE/superpowers"
    clone_repo "https://github.com/obra/superpowers.git" "$repo_dir"
    source="$repo_dir/skills"
  fi

  local subset="using-superpowers,brainstorming,executing-plans,verification-before-completion,dispatching-parallel-agents,systematic-debugging,test-driven-development"
  IFS=',' read -r -a names <<< "$subset"
  local harness_csv
  harness_csv="$(resolve_harness_list)"

  for name in "${names[@]}"; do
    local skill_path="$source/$name"
    if [[ ! -d "$skill_path" ]]; then
      log_warn "Skill superpowers em falta: $name"
      continue
    fi
    sync_skill_dir "$skill_path" "$name" "$harness_csv"
  done
  log_warn "Claude Code: usar plugin 'superpowers@superpowers-marketplace' como fonte principal"
}

sync_qa_devsecops() {
  log_info "=== QA + DevSecOps pack (agl-hostman) ==="
  if [[ -x "$HOSTMAN_ROOT/scripts/skills/install-agl-pack-qa-devsecops.sh" ]]; then
    if [[ "$DRY_RUN" -eq 1 ]]; then
      echo "  [dry-run] install-agl-pack-qa-devsecops.sh"
      return 0
    fi
    SKIP_SCAN="${SKIP_SCAN:-0}" bash "$HOSTMAN_ROOT/scripts/skills/install-agl-pack-qa-devsecops.sh" || log_warn "qa-devsecops pack parcial"
    log_ok "QA+DevSecOps pack aplicado"
  else
    log_warn "install-agl-pack-qa-devsecops.sh em falta"
  fi
}

sync_ecc() {
  log_info "=== everything-claude-code / ECC ==="
  log_warn "Perfil minimal (sem hooks-runtime) — evita conflito com plugin superpowers"
  ensure_ecc_repo

  if harness_selected claude; then
    run_ecc_install claude
  fi
  if harness_selected codex; then
    run_ecc_install codex
  fi
  if harness_selected hostman || harness_selected cursor; then
    run_ecc_install cursor "$HOSTMAN_ROOT"
  fi
  if harness_selected llm-wiki; then
    if [[ -d "$LLM_WIKI_DIR" ]]; then
      run_ecc_install claude-project "$LLM_WIKI_DIR"
    else
      log_warn "LLM_WIKI_DIR inacessível: $LLM_WIKI_DIR"
    fi
  fi
  if harness_selected verdent; then
    log_warn "ECC não tem target Verdent — skills partilhadas via Codex (~/.codex/.agents/skills)"
  fi

  if [[ "$DRY_RUN" -eq 0 ]]; then
    rm -f "$HOME/.claude/.ecc-install-pending" 2>/dev/null || true
    log_ok "ECC minimal aplicado — estado em ~/.claude/ecc/install-state.json e project .cursor/ecc-install-state.json"
  fi
}

sync_ruflo() {
  log_info "=== ruflo (ruvnet/ruflo) ==="
  if [[ "${SKIP_RUFLO_SYNC:-0}" == "1" ]]; then
    log_warn "SKIP_RUFLO_SYNC=1 — saltar ruflo"
    return 0
  fi
  if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "  [dry-run] npm i -g --force ruflo@latest @claude-flow/cli@latest"
    echo "  [dry-run] python3 scripts/ruflo/apply-claude-flow-headless-dsp.py"
    echo "  [dry-run] npx --yes ruflo@latest init --minimal (em $HOSTMAN_ROOT)"
  else
    # ponytail: sempre @latest — versões antigas do claude-flow quebram hive-mind com Claude Code
    run_or_echo npm i -g --force ruflo@latest @claude-flow/cli@latest
    npm uninstall -g claude-flow 2>/dev/null || true
    run_or_echo python3 "$HOSTMAN_ROOT/scripts/ruflo/apply-claude-flow-headless-dsp.py"
    run_or_echo python3 "$HOSTMAN_ROOT/scripts/ruflo/apply-ruv-swarm-mcp-fix.py" || true
    if [[ "${SKIP_RUFLO_INIT:-0}" != "1" && ! -d "$HOSTMAN_ROOT/.claude-flow" ]]; then
      (cd "$HOSTMAN_ROOT" && npx --yes ruflo@latest init --minimal) || log_warn "ruflo init falhou — verificar manualmente"
    elif [[ "${SKIP_RUFLO_INIT:-0}" == "1" ]]; then
      log_warn "SKIP_RUFLO_INIT=1 — saltar ruflo init"
    fi
    log_ok "ruflo: $(npx --yes ruflo@latest --version 2>/dev/null || echo 'npx disponível')"
  fi
}

# Layout OD pós-split: skills/ = funcionais; design-templates/ = renderáveis.
# Clones incompletos (ex. CT unprivileged/NFS) podem ter o blob no git sem materializar skills/.
ensure_open_design_tree() {
  local target="$1"
  [[ -d "$target/.git" ]] || return 0

  # ponytail: dir não-vazio basta; não depender de slugs concretos do subset
  if [[ -d "$target/skills" ]] && [[ -n "$(ls -A "$target/skills" 2>/dev/null)" ]]; then
    return 0
  fi

  log_warn "Árvore open-design incompleta (skills/ ausente) — materializar checkout"
  if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "  [dry-run] git -C $target checkout HEAD -- skills design-templates .claude/skills"
    return 0
  fi

  git -C "$target" sparse-checkout disable 2>/dev/null || true
  # Reason: checkout explícito evita worktrees a meio (pull --ff-only sem ficheiros)
  git -C "$target" checkout HEAD -- skills design-templates .claude/skills 2>/dev/null || \
    git -C "$target" checkout HEAD -- skills 2>/dev/null || true

  if [[ ! -d "$target/skills" ]]; then
    log_warn "skills/ continua em falta em $target — rever clone (git status / disco)"
    return 1
  fi
  log_ok "open-design: skills/ materializado"
}

# Resolve path no layout actual (skills → design-templates → .claude/skills).
resolve_open_design_skill_path() {
  local target="$1"
  local name="$2"
  local cand
  for cand in \
    "$target/skills/$name" \
    "$target/design-templates/$name" \
    "$target/.claude/skills/od-$name" \
    "$target/.claude/skills/$name"; do
    if [[ -f "$cand/SKILL.md" ]]; then
      printf '%s' "$cand"
      return 0
    fi
  done
  return 1
}

open_design_dest_name() {
  local name="$1"
  local source_dir="$2"
  local base
  base="$(basename "$source_dir")"
  if [[ "$base" == od-* ]]; then
    printf '%s' "$base"
  elif [[ "$name" == od-* ]]; then
    printf '%s' "$name"
  else
    printf 'od-%s' "$name"
  fi
}

sync_open_design() {
  log_info "=== open-design (nexu-io/open-design) — layout skills/ + design-templates/ ==="
  local target="${OPEN_DESIGN_DIR:-$HOME/dev/open-design}"
  # Subset AGL estável (funcionais em skills/); override via OPEN_DESIGN_SKILL_SUBSET
  local subset="${OPEN_DESIGN_SKILL_SUBSET:-design-md,design-review,design-brief,design-consultation,frontend-design,frontend-dev,ui-ux-pro-max,shadcn-ui,web-design-guidelines,color-expert,creative-director}"
  local harness_csv
  harness_csv="$(resolve_harness_list)"

  clone_repo "https://github.com/nexu-io/open-design.git" "$target"
  ensure_open_design_tree "$target" || true

  if [[ ! -d "$target/skills" && ! -d "$target/design-templates" && ! -d "$target/.claude/skills" ]]; then
    log_warn "Sem skills/ nem design-templates/ em $target — instalar conforme README upstream"
    return 0
  fi

  local synced=()
  local dest_names=()
  IFS=',' read -r -a names <<< "$subset"
  for name in "${names[@]}"; do
    name="$(trim "$name")"
    [[ -z "$name" ]] && continue
    local skill_path=""
    if ! skill_path="$(resolve_open_design_skill_path "$target" "$name")"; then
      log_warn "Skill open-design em falta: $name (skills/ | design-templates/ | .claude/skills/)"
      continue
    fi
    local dest_name
    dest_name="$(open_design_dest_name "$name" "$skill_path")"
    sync_skill_dir "$skill_path" "$dest_name" "$harness_csv"
    synced+=("$name")
    dest_names+=("$dest_name")
  done

  # Extra: od-contribute (contrib upstream, vive em .claude/skills/)
  if [[ -f "$target/.claude/skills/od-contribute/SKILL.md" ]]; then
    sync_skill_dir "$target/.claude/skills/od-contribute" "od-contribute" "$harness_csv"
    synced+=("od-contribute")
    dest_names+=("od-contribute")
  fi

  if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "  [dry-run] escrever $target/.agl-sync-state.json (${#dest_names[@]} skills od-*)"
    return 0
  fi

  if [[ ${#dest_names[@]} -eq 0 ]]; then
    log_warn "Nenhuma skill open-design sincronizada — rever OPEN_DESIGN_SKILL_SUBSET / checkout"
    return 0
  fi

  local state_file="$target/.agl-sync-state.json"
  local skills_json=""
  local dn
  for dn in "${dest_names[@]}"; do
    if [[ -n "$skills_json" ]]; then
      skills_json+=","
    fi
    skills_json+="\"$dn\""
  done
  cat >"$state_file" <<JSON
{
  "repo": "nexu-io/open-design",
  "layout": "skills+design-templates",
  "synced_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "prefix": "od-",
  "skills": [$skills_json]
}
JSON
  log_ok "open-design: ${#dest_names[@]} skills (prefixo od-) + estado em $state_file"
  log_info "Referência: $target/skills/ (funcionais) · $target/design-templates/ · $target/design-systems/"
}

sync_harness_router() {
  log_info "=== harness-router (skills AGL agl-*) ==="
  local script="$HOSTMAN_ROOT/scripts/agl/sync-harness-skills.sh"
  if [[ ! -x "$script" ]]; then
    chmod +x "$script" 2>/dev/null || true
  fi
  if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "  [dry-run] bash $script --dry-run --harness $HARNESS"
    return 0
  fi
  bash "$script" --harness "$HARNESS"
  log_ok "harness-router: skills agl-* sincronizadas"
}

sync_karpathy() {
  log_info "=== karpathy-skills ==="
  local repo_dir="$TEMP_BASE/andrej-karpathy-skills"
  clone_repo "https://github.com/multica-ai/andrej-karpathy-skills.git" "$repo_dir"

  if [[ -f "$repo_dir/SKILL.md" ]]; then
    sync_skill_dir "$repo_dir" "andrej-karpathy-skills" "$(resolve_harness_list)"
  elif [[ -d "$repo_dir/skills" ]]; then
    sync_skill_dir "$repo_dir/skills/andrej-karpathy-skills" "andrej-karpathy-skills" "$(resolve_harness_list)" 2>/dev/null || \
      sync_skill_dir "$(find "$repo_dir/skills" -mindepth 1 -maxdepth 1 -type d | head -1)" "andrej-karpathy-skills" "$(resolve_harness_list)"
  else
    log_warn "Estrutura karpathy inesperada — manter CLAUDE.md + karpathy-skills.mdc"
  fi
}

sync_content_skill_entry() {
  local skill_name="$1"
  local source_dir="$2"
  local harness_csv
  harness_csv="$(resolve_content_harness_list)"
  sync_skill_dir "$source_dir" "$skill_name" "$harness_csv"
}

sync_content_skills() {
  local which="${1:-all}"
  log_info "=== content-skills (humanizer, fact-check, prompt-improver) ==="
  local harness_csv
  harness_csv="$(resolve_content_harness_list)"
  local -a synced=()

  if [[ "$which" == "all" || "$which" == "humanizer" ]]; then
    local humanizer_dir="$TEMP_BASE/humanizer"
    clone_repo "https://github.com/blader/humanizer.git" "$humanizer_dir"
    if [[ "$DRY_RUN" -eq 1 ]]; then
      echo "  [dry-run] sync humanizer -> $harness_csv"
    else
      sync_content_skill_entry "humanizer" "$humanizer_dir"
    fi
    synced+=("humanizer")
  fi

  if [[ "$which" == "all" || "$which" == "fact-check" ]]; then
    local fact_check_dir="$TEMP_BASE/fact-check-skill"
    clone_repo "https://github.com/petar-nauka/fact-check-skill.git" "$fact_check_dir"
    if [[ "$DRY_RUN" -eq 1 ]]; then
      echo "  [dry-run] sync fact-check -> $harness_csv"
    else
      sync_content_skill_entry "fact-check" "$fact_check_dir"
    fi
    synced+=("fact-check")
  fi

  if [[ "$which" == "all" || "$which" == "prompt-improver" ]]; then
    local prompt_repo="$TEMP_BASE/claude-code-prompt-improver"
    clone_repo "https://github.com/severity1/claude-code-prompt-improver.git" "$prompt_repo"
    local prompt_skill="$prompt_repo/skills/prompt-improver"
    if [[ "$DRY_RUN" -eq 0 && ! -f "$prompt_skill/SKILL.md" ]]; then
      echo "SKILL.md em falta: $prompt_skill" >&2
      return 1
    fi
    if [[ "$DRY_RUN" -eq 1 ]]; then
      echo "  [dry-run] sync prompt-improver -> $harness_csv"
    else
      sync_content_skill_entry "prompt-improver" "$prompt_skill"
    fi
    synced+=("prompt-improver")
  fi

  if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "  [dry-run] escrever $HOSTMAN_ROOT/.cursor/content-skills-sync-state.json (${#synced[@]} skills)"
    if [[ " ${synced[*]} " == *" prompt-improver "* ]]; then
      log_warn "prompt-improver: hooks Claude Code ignorados — só SKILL.md + references/"
    fi
    return 0
  fi

  if [[ ${#synced[@]} -eq 0 ]]; then
    log_warn "Nenhuma content-skill sincronizada — rever --repo"
    return 0
  fi

  local skills_json=""
  for name in "${synced[@]}"; do
    if [[ -n "$skills_json" ]]; then
      skills_json+=","
    fi
    skills_json+="\"$name\""
  done
  mkdir -p "$HOSTMAN_ROOT/.cursor"
  cat >"$HOSTMAN_ROOT/.cursor/content-skills-sync-state.json" <<JSON
{
  "repos": {
    "humanizer": "blader/humanizer",
    "fact-check": "petar-nauka/fact-check-skill",
    "prompt-improver": "severity1/claude-code-prompt-improver (skills/prompt-improver only)"
  },
  "synced_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "skills": [$skills_json]
}
JSON
  log_ok "content-skills: ${#synced[@]} skills + estado em $HOSTMAN_ROOT/.cursor/content-skills-sync-state.json"
  if [[ " ${synced[*]} " == *" prompt-improver "* ]]; then
    log_warn "prompt-improver: hooks Claude Code ignorados — só SKILL.md + references/"
  fi
}

cleanup() {
  if [[ -d "$TEMP_BASE" && "$DRY_RUN" -eq 0 ]]; then
    rm -rf "$TEMP_BASE"
  fi
}
trap cleanup EXIT

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=1; shift ;;
    --method) METHOD="$2"; shift 2 ;;
    --repo) REPOS="$2"; shift 2 ;;
    --harness) HARNESS="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Opção desconhecida: $1" >&2; usage; exit 1 ;;
  esac
done

if [[ "$METHOD" != "copy" && "$METHOD" != "symlink" ]]; then
  echo "Invalid --method: $METHOD" >&2
  exit 1
fi

mkdir -p "$TEMP_BASE"

should_run() {
  [[ "$REPOS" == "all" || "$REPOS" == "$1" ]]
}

should_run_content() {
  [[ "$REPOS" == "all" || "$REPOS" == "content-skills" || "$REPOS" == "$1" ]]
}

should_run obsidian && sync_obsidian
should_run superpowers && sync_superpowers
should_run ecc && sync_ecc
should_run qa-devsecops && sync_qa_devsecops
should_run ruflo && sync_ruflo
should_run open-design && sync_open_design
should_run karpathy && sync_karpathy
should_run harness-router && sync_harness_router

if should_run_content humanizer && should_run_content fact-check && should_run_content prompt-improver; then
  if [[ "$REPOS" == "content-skills" || "$REPOS" == "all" ]]; then
    sync_content_skills all
  fi
elif should_run_content humanizer; then
  sync_content_skills humanizer
elif should_run_content fact-check; then
  sync_content_skills fact-check
elif should_run_content prompt-improver; then
  sync_content_skills prompt-improver
fi

log_ok "sync-six-repos concluído (dry_run=$DRY_RUN repo=$REPOS)"
