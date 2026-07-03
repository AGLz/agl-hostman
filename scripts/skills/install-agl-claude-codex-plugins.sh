#!/usr/bin/env bash
# Instala/activa plugins Claude Code + prepara Codex (CLI, config, plugins dir)
# e sincroniza ECC + open-design no pipeline AGL pack.
#
# Uso:
#   bash scripts/skills/install-agl-claude-codex-plugins.sh
#   SKIP_CLAUDE_PLUGINS=1 bash scripts/skills/install-agl-claude-codex-plugins.sh
#   SKIP_CODEX=1 bash scripts/skills/install-agl-claude-codex-plugins.sh
#   AGL_INSTALL_ANTIGRAVITY=1 bash scripts/skills/install-agl-claude-codex-plugins.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOSTMAN_ROOT="${HOSTMAN_ROOT_OVERRIDE:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
LLM_WIKI_DIR="${LLM_WIKI_DIR:-/mnt/overpower/apps/dev/agl/llm-wiki}"
PROMPT_REPO="${PROMPT_REPO:-/tmp/claude-code-prompt-improver-install}"

# Plugins Anthropic já instalados por defeito — activar subset AGL
CLAUDE_OFFICIAL_PLUGINS=(
  github@claude-plugins-official
  context7@claude-plugins-official
  code-review@claude-plugins-official
  commit-commands@claude-plugins-official
  feature-dev@claude-plugins-official
  frontend-design@claude-plugins-official
)

log() { echo "[agl-plugins] $*"; }
ok() { echo "[OK] $*"; }
warn() { echo "[WARN] $*" >&2; }

plugin_enabled() {
  local id="$1"
  claude plugin list 2>/dev/null | awk -v id="$id" '
    index($0, id) { block=1 }
    block && /Status: ✔ enabled/ { found=1; exit }
    block && /^  ❯/ && index($0, id) == 0 { block=0 }
    END { exit !found }
  '
}

install_superpowers_plugin() {
  if ! command -v claude >/dev/null 2>&1; then
    warn "claude CLI ausente — saltar superpowers plugin"
    return 0
  fi

  if ! claude plugin list 2>/dev/null | grep -q 'superpowers@superpowers-marketplace'; then
    log "marketplace superpowers"
    claude plugin marketplace add obra/superpowers-marketplace 2>/dev/null || true
    claude plugin install superpowers@superpowers-marketplace 2>/dev/null \
      || warn "superpowers plugin install falhou"
  fi

  if claude plugin list 2>/dev/null | grep -q 'superpowers@superpowers-marketplace'; then
    if ! plugin_enabled 'superpowers@superpowers-marketplace'; then
      claude plugin enable superpowers@superpowers-marketplace 2>/dev/null \
        || warn "superpowers enable falhou"
    fi
    ok "superpowers@superpowers-marketplace"
  else
    warn "superpowers plugin não presente após install"
  fi
}

enable_claude_official_plugins() {
  if ! command -v claude >/dev/null 2>&1; then
    warn "claude CLI ausente — saltar plugins official"
    return 0
  fi

  local id
  for id in "${CLAUDE_OFFICIAL_PLUGINS[@]}"; do
    if ! claude plugin list 2>/dev/null | grep -qF "$id"; then
      claude plugin install "$id" 2>/dev/null || warn "install falhou: $id"
    fi
    if plugin_enabled "$id"; then
      ok "enabled: $id"
    else
      if claude plugin enable "$id" 2>/dev/null; then
        ok "enabled: $id"
      else
        warn "enable falhou: $id"
      fi
    fi
  done

  # P1: Serena LSP — só enable se já instalado (evita deps pesadas)
  if claude plugin list 2>/dev/null | grep -q 'serena@'; then
    local serena_id
    serena_id="$(claude plugin list 2>/dev/null | awk '/serena@/ {print $2; exit}')"
    if [[ -n "$serena_id" ]] && ! plugin_enabled "$serena_id"; then
      claude plugin enable "$serena_id" 2>/dev/null && ok "enabled: $serena_id" \
        || warn "serena enable falhou"
    fi
  fi
}

install_prompt_improver_plugin() {
  if [[ "${SKIP_PROMPT_IMPROVER_PLUGIN:-0}" == "1" ]]; then
    warn "SKIP_PROMPT_IMPROVER_PLUGIN=1 — saltar plugin (skill mantida)"
    return 0
  fi
  if ! command -v claude >/dev/null 2>&1; then
    warn "claude CLI ausente — prompt-improver plugin não instalado"
    return 0
  fi

  if ! claude plugin list 2>/dev/null | grep -q 'prompt-improver@'; then
    if [[ ! -d "$PROMPT_REPO/.dev-marketplace/.claude-plugin" ]]; then
      rm -rf "$PROMPT_REPO"
      git clone --depth 1 https://github.com/severity1/claude-code-prompt-improver.git "$PROMPT_REPO" \
        2>/dev/null || true
    fi
    if [[ -d "$PROMPT_REPO/.dev-marketplace/.claude-plugin" ]]; then
      claude plugin marketplace add "$PROMPT_REPO/.dev-marketplace/.claude-plugin/marketplace.json" 2>/dev/null || true
      claude plugin install prompt-improver@local-dev 2>/dev/null \
        || warn "prompt-improver plugin install falhou"
    fi
  fi

  if claude plugin list 2>/dev/null | grep -q 'prompt-improver@'; then
    local pid
    pid="$(claude plugin list 2>/dev/null | awk '/prompt-improver@/ {print $2; exit}')"
    if [[ -n "$pid" ]] && ! plugin_enabled "$pid"; then
      claude plugin enable "$pid" 2>/dev/null || true
    fi
    ok "prompt-improver plugin"
  fi
}

sync_ecc_and_open_design() {
  cd "$HOSTMAN_ROOT"
  export LLM_WIKI_DIR
  export SKIP_SCAN="${SKIP_SCAN:-1}"
  for repo in ecc open-design; do
    log "sync-six-repos --repo $repo"
    ./scripts/skills/sync-six-repos.sh --repo "$repo" \
      || warn "sync $repo parcial"
  done
}

install_codex_cli() {
  if [[ "${SKIP_CODEX:-0}" == "1" ]]; then
    warn "SKIP_CODEX=1 — saltar Codex CLI/config"
    return 0
  fi

  if command -v codex >/dev/null 2>&1; then
    ok "codex CLI: $(codex --version 2>/dev/null | head -1 || echo presente)"
  elif command -v npm >/dev/null 2>&1; then
    log "npm i -g @openai/codex"
    npm i -g @openai/codex 2>/dev/null \
      && ok "codex CLI instalado" \
      || warn "codex CLI install falhou (npm @openai/codex)"
  else
    warn "npm ausente — codex CLI não instalado"
  fi
}

install_codex_config() {
  local template="$HOSTMAN_ROOT/config/dotfiles/linux/codex/config.toml"
  local dest="$HOME/.codex/config.toml"
  mkdir -p "$HOME/.codex/plugins"

  if [[ ! -f "$template" ]]; then
    warn "template config.toml em falta: $template"
    return 0
  fi

  if [[ ! -f "$dest" ]]; then
    cp "$template" "$dest"
    ok "codex config.toml copiado de dotfiles"
  elif ! grep -q 'Codex ECC' "$dest" 2>/dev/null \
    && grep -q 'Codex ECC' "$template" 2>/dev/null; then
    # ponytail: não sobrescrever config custom — só garantir MCP mínimo se vazio
    ok "codex config.toml existente mantido"
  else
    ok "codex config.toml presente"
  fi

  # Marcador para audit — plugins Codex ainda via TUI `/plugins` (GitHub, Security)
  local marker="$HOME/.codex/plugins/.agl-pack-readme"
  if [[ ! -f "$marker" ]]; then
    cat >"$marker" <<'EOF'
# AGL pack — Codex plugins
#
# Instalar plugins curated via Codex TUI:
#   codex
#   /plugins
# Recomendados: GitHub, Security (alinha agl-sast-gate)
#
# Skills já sync em ~/.codex/skills/ via sync-six-repos.
EOF
    ok "codex plugins dir preparado (~/.codex/plugins/)"
  fi
}

install_antigravity_subset() {
  if [[ "${AGL_INSTALL_ANTIGRAVITY:-0}" != "1" ]]; then
    return 0
  fi
  local script="$HOSTMAN_ROOT/scripts/skills/install-antigravity-skills.sh"
  if [[ -x "$script" ]]; then
    log "Antigravity subset (AGL_INSTALL_ANTIGRAVITY=1)"
    bash "$script" || warn "Antigravity install parcial"
  else
    warn "install-antigravity-skills.sh em falta"
  fi
}

main() {
  log "=== install-agl-claude-codex-plugins em $(hostname -s 2>/dev/null || hostname) ==="

  sync_ecc_and_open_design

  if [[ "${SKIP_CLAUDE_PLUGINS:-0}" != "1" ]]; then
    install_superpowers_plugin
    enable_claude_official_plugins
    install_prompt_improver_plugin
  else
    warn "SKIP_CLAUDE_PLUGINS=1"
  fi

  install_codex_cli
  install_codex_config
  install_antigravity_subset

  ok "install-agl-claude-codex-plugins concluído"
}

main "$@"
