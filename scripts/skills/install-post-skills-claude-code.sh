#!/usr/bin/env bash
# Instala skills citadas no post (humanizer, fact-check, prompt-improver, frontend-slides)
# + superpowers subset + plugin prompt-improver no Claude Code.
#
# Uso:
#   ./scripts/skills/install-post-skills-claude-code.sh
#   SKIP_PROMPT_IMPROVER_PLUGIN=1 ./scripts/skills/install-post-skills-claude-code.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOSTMAN_ROOT="${HOSTMAN_ROOT_OVERRIDE:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
PROMPT_REPO="${PROMPT_REPO:-/tmp/claude-code-prompt-improver-install}"
MARKETPLACE_NAME="${PROMPT_IMPROVER_MARKETPLACE:-local-dev-agl}"

log() { echo "[INFO] $*"; }
ok() { echo "[OK] $*"; }
warn() { echo "[WARN] $*"; }

log "=== post skills: sync content-skills + superpowers ==="
cd "$HOSTMAN_ROOT"
LLM_WIKI_DIR="${LLM_WIKI_DIR:-/mnt/overpower/apps/dev/agl/llm-wiki}" \
  ./scripts/skills/sync-six-repos.sh --repo content-skills
LLM_WIKI_DIR="${LLM_WIKI_DIR:-/mnt/overpower/apps/dev/agl/llm-wiki}" \
  ./scripts/skills/sync-six-repos.sh --repo superpowers

if [[ -f "$HOSTMAN_ROOT/.cursor/skills/frontend-slides/SKILL.md" ]]; then
  mkdir -p "$HOME/.claude/skills/frontend-slides"
  rsync -a --delete \
    "$HOSTMAN_ROOT/.cursor/skills/frontend-slides/" \
    "$HOME/.claude/skills/frontend-slides/"
  ok "frontend-slides -> $HOME/.claude/skills/frontend-slides"
else
  warn "frontend-slides em falta no project — correr sync-six-repos --repo ecc"
fi

if [[ "${SKIP_PROMPT_IMPROVER_PLUGIN:-0}" == "1" ]]; then
  warn "SKIP_PROMPT_IMPROVER_PLUGIN=1 — saltar plugin (skill ~/.claude/skills/prompt-improver mantida)"
  exit 0
fi

if ! command -v claude >/dev/null 2>&1; then
  warn "claude CLI ausente — plugin prompt-improver não instalado"
  exit 0
fi

if claude plugin list 2>/dev/null | grep -q 'prompt-improver@'; then
  ok "plugin prompt-improver já instalado"
  exit 0
fi

log "=== prompt-improver plugin (local-dev marketplace) ==="
if [[ ! -d "$PROMPT_REPO/.dev-marketplace/.claude-plugin" ]]; then
  rm -rf "$PROMPT_REPO"
  git clone --depth 1 https://github.com/severity1/claude-code-prompt-improver.git "$PROMPT_REPO"
fi

if ! claude plugin marketplace list 2>/dev/null | grep -qE 'local-dev|local-dev-agl'; then
  claude plugin marketplace add "$PROMPT_REPO/.dev-marketplace/.claude-plugin/marketplace.json" 2>/dev/null || true
fi

if claude plugin install prompt-improver@local-dev 2>/dev/null; then
  ok "plugin prompt-improver@local-dev instalado"
else
  warn "falha ao instalar plugin — skill manual em ~/.claude/skills/prompt-improver disponível"
fi

ok "install-post-skills-claude-code concluído em $(hostname -s 2>/dev/null || hostname)"
