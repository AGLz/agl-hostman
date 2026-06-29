#!/usr/bin/env bash
# Propaga cursor-agent-rules (self-improve pack) para hosts AGL e outros repos.
#
# Uso:
#   ./scripts/skills/propagate-cursor-agent-rules.sh --host agldv03
#   ./scripts/skills/propagate-cursor-agent-rules.sh --host agldv-all
#   ./scripts/skills/propagate-cursor-agent-rules.sh --repo agl-media-grabber
#   ./scripts/skills/propagate-cursor-agent-rules.sh --repo all --dry-run
#
# Ordem recomendada: validar agl-hostman → --host agldv03 → --repo agl-media-grabber → restantes
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOSTMAN_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
AGL_ROOT="${AGL_ROOT:-/mnt/overpower/apps/dev/agl}"
LLM_WIKI_DIR="${LLM_WIKI_DIR:-/mnt/overpower/apps/dev/agl/llm-wiki}"

AGLDV03_HOST="${AGLDV03_HOST:-root@100.94.221.87}"
AGLDV04_HOST="${AGLDV04_HOST:-root@100.113.9.98}"
AGLDV05_HOST="${AGLDV05_HOST:-root@100.82.71.49}"
AGLDV06_HOST="${AGLDV06_HOST:-root@100.71.229.12}"
AGLDV07_HOST="${AGLDV07_HOST:-root@100.64.175.89}"
AGLDV12_HOST="${AGLDV12_HOST:-root@100.71.217.115}"

DRY_RUN=0
HOST=""
REPO=""

SSH=(ssh -o BatchMode=yes -o ConnectTimeout=25 -o StrictHostKeyChecking=accept-new)

REPO_TARGETS=(
  # Desenvolvimento ativo (AGL-owned)
  agl-media-grabber
  crowbar
  crowbar-demo
  nn-brad
  # Config repos (backups — pack já presente, mantidos por idempotência)
  agl-cursor-config
  agl-claude-code-config
  agl-codex-config
  agl-openclaw-config
  agl-ruflo-config
)

usage() {
  cat <<USAGE
Usage: $(basename "$0") (--host <agldv03|agldv-all> | --repo <name|all>) [--dry-run]

  --host   Instala skills globais nos dev LXC (via install-cursor-agent-rules.sh)
  --repo   Copia pack essencial para outro repo em \$AGL_ROOT (1 a 1)
USAGE
}

log() { echo "[INFO] $*"; }
ok() { echo "[OK] $*"; }
warn() { echo "[WARN] $*"; }

remote_install() {
  local name="$1"
  local ssh_target="$2"
  local cmd="git config --global --add safe.directory '$HOSTMAN_ROOT' 2>/dev/null || true; cd '$HOSTMAN_ROOT' && (test -d .git && git pull --ff-only || true) && bash scripts/skills/install-cursor-agent-rules.sh"
  local standalone_global="
    mkdir -p ~/.cursor/rules ~/.cursor/skills/reflect-yourself ~/.claude/skills/reflect-yourself
  "
  local local_short
  local_short="$(hostname -s 2>/dev/null || hostname)"

  log "=== host $name ==="
  if [[ "$local_short" == "$name" ]]; then
    if [[ "$DRY_RUN" -eq 1 ]]; then
      echo "  [dry-run] local install-cursor-agent-rules.sh"
      return 0
    fi
    bash "$HOSTMAN_ROOT/scripts/skills/install-cursor-agent-rules.sh"
  else
    if [[ "$DRY_RUN" -eq 1 ]]; then
      echo "  [dry-run] ssh $ssh_target $cmd"
      return 0
    fi
    if "${SSH[@]}" "$ssh_target" "test -f '$HOSTMAN_ROOT/scripts/skills/install-cursor-agent-rules.sh'"; then
      "${SSH[@]}" "$ssh_target" "bash -lc $(printf '%q' "$cmd")" || warn "$name: install falhou"
    else
      warn "$name: agl-hostman NFS em falta — standalone global via scp"
      if [[ "$DRY_RUN" -eq 1 ]]; then
        echo "  [dry-run] scp rules pack to $ssh_target"
        return 0
      fi
      "${SSH[@]}" "$ssh_target" "bash -lc $(printf '%q' "$standalone_global")"
      for f in prompt-improve.mdc self-improve.mdc session-reflect.mdc memory.mdc; do
        scp -o BatchMode=yes -o ConnectTimeout=25 \
          "$HOSTMAN_ROOT/.cursor/rules/$f" \
          "${ssh_target}:~/.cursor/rules/$f" || { warn "$name: scp $f falhou"; return 1; }
      done
      scp -o BatchMode=yes -o ConnectTimeout=25 \
        "$HOSTMAN_ROOT/.cursor/skills/reflect-yourself/SKILL.md" \
        "${ssh_target}:~/.cursor/skills/reflect-yourself/SKILL.md" || warn "$name: scp skill falhou"
      scp -o BatchMode=yes -o ConnectTimeout=25 \
        "$HOSTMAN_ROOT/.claude/skills/reflect-yourself/SKILL.md" \
        "${ssh_target}:~/.claude/skills/reflect-yourself/SKILL.md" 2>/dev/null || \
        scp -o BatchMode=yes -o ConnectTimeout=25 \
          "$HOSTMAN_ROOT/.cursor/skills/reflect-yourself/SKILL.md" \
          "${ssh_target}:~/.claude/skills/reflect-yourself/SKILL.md" || warn "$name: scp claude skill falhou"
    fi
  fi
  ok "$name"
}

propagate_repo() {
  local repo="$1"
  local dest="$AGL_ROOT/$repo"
  if [[ ! -d "$dest" ]]; then
    warn "repo ausente: $dest — skip"
    return 0
  fi

  log "=== repo $repo ==="
  local rules_dest="$dest/.cursor/rules"
  local skills_dest="$dest/.cursor/skills/reflect-yourself"
  local cmds_dest="$dest/.cursor/commands"

  if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "  [dry-run] mkdir $rules_dest + copy pack + optional AGENTS lean pointer"
    return 0
  fi

  mkdir -p "$rules_dest" "$skills_dest" "$cmds_dest"

  for f in prompt-improve.mdc self-improve.mdc session-reflect.mdc memory.mdc; do
    cp "$HOSTMAN_ROOT/.cursor/rules/$f" "$rules_dest/$f"
  done
  cp "$HOSTMAN_ROOT/.cursor/skills/reflect-yourself/SKILL.md" "$skills_dest/SKILL.md"
  cp "$HOSTMAN_ROOT/.cursor/commands/reflect-yourself.md" "$cmds_dest/reflect-yourself.md"

  # Pointer wiki no AGENTS.md se existir e ainda não tiver contrato lean
  if [[ -f "$dest/AGENTS.md" ]] && ! grep -q 'Contrato Agentes Cursor' "$dest/AGENTS.md" 2>/dev/null; then
    cat >> "$dest/AGENTS.md" <<'POINTER'

## Cursor self-improve (AGL)

- Pack: `prompt-improve`, `self-improve`, `reflect-yourself` em `.cursor/`
- Wiki: [[agl-hostman — Contrato Agentes Cursor]] em llm-wiki
- Instalar global: `agl-hostman/scripts/skills/install-cursor-agent-rules.sh`
POINTER
    ok "$repo: pointer adicionado a AGENTS.md"
  fi

  ok "$repo: pack copiado para $dest/.cursor/"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --host) HOST="${2:-}"; shift 2 ;;
    --repo) REPO="${2:-}"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Opção desconhecida: $1" >&2; usage; exit 2 ;;
  esac
done

[[ -n "$HOST" || -n "$REPO" ]] || { usage; exit 2; }

if [[ -n "$HOST" ]]; then
  case "$HOST" in
    agldv03) remote_install agldv03 "$AGLDV03_HOST" ;;
    agldv04) remote_install agldv04 "$AGLDV04_HOST" ;;
    agldv05) remote_install agldv05 "$AGLDV05_HOST" ;;
    agldv06) remote_install agldv06 "$AGLDV06_HOST" ;;
    agldv07) remote_install agldv07 "$AGLDV07_HOST" ;;
    agldv12) remote_install agldv12 "$AGLDV12_HOST" ;;
    agldv-all)
      FAIL=0
      remote_install agldv03 "$AGLDV03_HOST" || FAIL=1
      remote_install agldv04 "$AGLDV04_HOST" || FAIL=1
      remote_install agldv05 "$AGLDV05_HOST" || FAIL=1
      remote_install agldv06 "$AGLDV06_HOST" || FAIL=1
      remote_install agldv07 "$AGLDV07_HOST" || FAIL=1
      remote_install agldv12 "$AGLDV12_HOST" || FAIL=1
      [[ "$FAIL" -eq 0 ]] || exit 1
      ;;
    *) echo "Host desconhecido: $HOST" >&2; exit 2 ;;
  esac
fi

if [[ -n "$REPO" ]]; then
  if [[ "$REPO" == "all" ]]; then
    for r in "${REPO_TARGETS[@]}"; do
      propagate_repo "$r"
    done
  else
    propagate_repo "$REPO"
  fi
fi

ok "propagate-cursor-agent-rules concluído"
