#!/usr/bin/env bash
# Instala symlinks dotfiles AGL: configs Git + live data em AGL_HOME_SYNC_ROOT (NFS).
#
# Uso:
#   ./scripts/dotfiles/install-agl-home-sync.sh
#   ./scripts/dotfiles/install-agl-home-sync.sh --dry-run
#   AGL_HOME_USER=linux-root ./scripts/dotfiles/install-agl-home-sync.sh
#
# Regra: fechar Cursor/Claude antes de migrar globalStorage (SQLite em NFS).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOSTMAN_ROOT="${HOSTMAN_ROOT_OVERRIDE:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
DOTFILES_ROOT="$HOSTMAN_ROOT/config/dotfiles"

AGL_HOME_SYNC_ROOT="${AGL_HOME_SYNC_ROOT:-/mnt/overpower/apps/dev/agl/agl-home-sync}"
AGL_HOME_SYNC_ROOT="${AGL_HOME_SYNC_ROOT//$'\r'/}"
AGL_HOME_USER="${AGL_HOME_USER:-linux-root}"
DRY_RUN=0
SKIP_MIGRATE=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=1; shift ;;
    --skip-migrate) SKIP_MIGRATE=1; shift ;;
    -h|--help)
      sed -n '2,12p' "$0"
      exit 0
      ;;
    *) echo "Opção desconhecida: $1" >&2; exit 1 ;;
  esac
done

LIVE_ROOT="$AGL_HOME_SYNC_ROOT/$AGL_HOME_USER"

log() { echo "[INFO] $*"; }
ok() { echo "[OK] $*"; }
warn() { echo "[WARN] $*"; }

run() {
  if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "  [dry-run] $*"
  else
    "$@"
  fi
}

ensure_dir() {
  local d="$1"
  run mkdir -p "$d"
}

backup_path() {
  local p="$1"
  if [[ -e "$p" && ! -L "$p" ]]; then
    local bak="${p}.bak.$(date +%Y%m%d%H%M%S)"
    run mv "$p" "$bak"
    ok "backup $p -> $bak"
  fi
}

migrate_to_live() {
  local local_path="$1"
  local live_path="$2"
  local kind="${3:-dir}"

  ensure_dir "$(dirname "$live_path")"

  if [[ "$SKIP_MIGRATE" -eq 1 ]]; then
    if [[ "$kind" == "file" ]]; then
      [[ -f "$live_path" ]] || run touch "$live_path"
    else
      ensure_dir "$live_path"
    fi
    return 0
  fi

  if [[ "$kind" == "file" ]]; then
    if [[ -f "$local_path" && ! -L "$local_path" ]]; then
      if [[ ! -s "$live_path" ]]; then
        run /bin/cp -f "$local_path" "$live_path"
        ok "migrado ficheiro $local_path -> $live_path"
      else
        warn "live já tem dados — skip migrate $live_path"
      fi
    elif [[ ! -f "$live_path" ]]; then
      run touch "$live_path"
    fi
  else
    if [[ -d "$local_path" && ! -L "$local_path" ]]; then
      if [[ -z "$(ls -A "$live_path" 2>/dev/null || true)" ]]; then
        if run rsync -a "$local_path/" "$live_path/"; then
          ok "migrado dir $local_path -> $live_path"
        else
          warn "rsync falhou — tentar cp manual após verificar mount NFS"
          run /bin/cp -a "$local_path/." "$live_path/"
          ok "migrado dir (cp fallback) $local_path -> $live_path"
        fi
      else
        warn "live já tem dados — skip migrate $live_path"
      fi
    else
      ensure_dir "$live_path"
    fi
  fi
}

link_live() {
  local local_path="$1"
  local remote_rel="$2"
  local kind="${3:-dir}"
  local live_path="$LIVE_ROOT/$remote_rel"

  ensure_dir "$(dirname "$local_path")"
  migrate_to_live "$local_path" "$live_path" "$kind"
  backup_path "$local_path"
  run ln -sfn "$live_path" "$local_path"
  ok "symlink $local_path -> $live_path"
}

link_git_file() {
  local local_path="$1"
  local rel_source="$2"
  local source="$HOSTMAN_ROOT/$rel_source"

  if [[ ! -f "$source" ]]; then
    warn "fonte Git em falta: $source"
    return 0
  fi

  ensure_dir "$(dirname "$local_path")"
  backup_path "$local_path"
  run ln -sfn "$source" "$local_path"
  ok "symlink git $local_path -> $source"
}

copy_if_missing() {
  local local_path="$1"
  local rel_source="$2"
  local source="$HOSTMAN_ROOT/$rel_source"

  if [[ -f "$local_path" ]]; then
    ok "mantido existente $local_path"
    return 0
  fi
  if [[ ! -f "$source" ]]; then
    warn "template em falta: $source"
    return 0
  fi
  ensure_dir "$(dirname "$local_path")"
  run cp "$source" "$local_path"
  ok "copiado template $source -> $local_path"
}

log "=== install-agl-home-sync host=$(hostname -s) user=$AGL_HOME_USER dry_run=$DRY_RUN ==="
log "LIVE_ROOT=$LIVE_ROOT"
log "HOSTMAN_ROOT=$HOSTMAN_ROOT"

if [[ ! -d "$AGL_HOME_SYNC_ROOT" ]]; then
  if [[ "$DRY_RUN" -eq 1 ]]; then
    warn "sync root ainda não existe — dry-run continua"
  else
    run mkdir -p "$AGL_HOME_SYNC_ROOT"
    ok "criado $AGL_HOME_SYNC_ROOT"
  fi
fi

ensure_dir "$LIVE_ROOT/cursor/globalStorage"
ensure_dir "$LIVE_ROOT/cursor/dot-cursor/chats"
ensure_dir "$LIVE_ROOT/cursor/dot-cursor/projects"
ensure_dir "$LIVE_ROOT/claude/file-history"

# --- Live symlinks (NFS) ---
link_live "$HOME/.config/Cursor/User/globalStorage" "cursor/globalStorage" dir
link_live "$HOME/.cursor/chats" "cursor/dot-cursor/chats" dir
link_live "$HOME/.cursor/projects" "cursor/dot-cursor/projects" dir
link_live "$HOME/.claude/history.jsonl" "claude/history.jsonl" file
link_live "$HOME/.claude/file-history" "claude/file-history" dir

# --- Git-managed symlinks ---
link_git_file "$HOME/.config/Cursor/User/settings.json" "config/dotfiles/linux/cursor/User/settings.json"
link_git_file "$HOME/.config/Cursor/User/keybindings.json" "config/dotfiles/linux/cursor/User/keybindings.json"
link_git_file "$HOME/.claude/settings.json" "config/dotfiles/linux/claude/settings.json"

# --- Templates (não sobrescrever) ---
copy_if_missing "$HOME/.cursor/mcp.json" "config/dotfiles/linux/cursor/dot-cursor/mcp.json.example"
copy_if_missing "$HOME/.codex/config.toml" "config/dotfiles/linux/codex/config.toml"

# --- Shell env ---
ensure_dir "$HOME/.config/agl"
ENV_LINK="$HOME/.config/agl/env.sh"
ENV_SRC="$DOTFILES_ROOT/linux/shell/agl-env.sh"
backup_path "$ENV_LINK"
run ln -sfn "$ENV_SRC" "$ENV_LINK"
ok "symlink $ENV_LINK -> $ENV_SRC"

# Hook zsh (idempotente)
ZSHRC="${ZDOTDIR:-$HOME}/.zshrc"
MARKER="# AGL dotfiles env"
if [[ -f "$ZSHRC" ]] && ! grep -qF "$MARKER" "$ZSHRC" 2>/dev/null; then
  if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "  [dry-run] append AGL env block to $ZSHRC"
  else
    cat >>"$ZSHRC" <<'EOF'

# AGL dotfiles env
[[ -f "$HOME/.config/agl/env.sh" ]] && source "$HOME/.config/agl/env.sh"
EOF
    ok "append AGL env em $ZSHRC"
  fi
else
  ok "zshrc AGL env já presente ou .zshrc ausente"
fi

echo ""
ok "install concluído — correr: ./scripts/dotfiles/verify-agl-home-sync.sh"
if [[ "$DRY_RUN" -eq 0 ]]; then
  warn "Regra single-writer: não abrir Cursor em 2 hosts em simultâneo com globalStorage partilhado"
fi
