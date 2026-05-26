#!/usr/bin/env bash
# Propaga Six Repos para hosts AGL (Fase 5).
# Plano: ai-docs/planning/SIX-REPOS-MULTI-AGENT-PLAN.md
#
# Uso:
#   ./scripts/skills/propagate-six-repos.sh --host agldv03
#   ./scripts/skills/propagate-six-repos.sh --host ct188
#   ./scripts/skills/propagate-six-repos.sh --host aglwk45
#   ./scripts/skills/propagate-six-repos.sh --host all --dry-run
#
# Variáveis:
#   AGLDV03_HOST     default root@100.94.221.87
#   AGLSRV1_HOST     default root@100.107.113.33 (pct exec CT188, qm guest VM104)
#   CT188_VMID       default 188
#   AGLWK45_VMID     default 104
#   WK45_REPO_WIN    default U:\apps\dev\agl\agl-hostman
#   LLM_WIKI_DIR     path Linux llm-wiki (sync remoto)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOSTMAN_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
LLM_WIKI_DIR="${LLM_WIKI_DIR:-/mnt/overpower/apps/dev/agl/llm-wiki}"

AGLDV03_HOST="${AGLDV03_HOST:-root@100.94.221.87}"
AGLSRV1_HOST="${AGLSRV1_HOST:-root@100.107.113.33}"
CT188_VMID="${CT188_VMID:-188}"
AGLWK45_VMID="${AGLWK45_VMID:-104}"
WK45_REPO_WIN="${WK45_REPO_WIN:-U:\\\\apps\\\\dev\\\\agl\\\\agl-hostman}"

DRY_RUN=0
HOST=""

SSH=(ssh -o BatchMode=yes -o ConnectTimeout=25 -o StrictHostKeyChecking=accept-new)

usage() {
  cat <<USAGE
Usage: $(basename "$0") --host <agldv03|ct188|aglwk45|all> [--dry-run]

Propaga instalação Six Repos (sync + verify + smoke) para hosts AGL.

  agldv03   Dev principal — sync completo em ~/.claude|cursor|codex|verdent
  ct188     Hermes — ensure llm-wiki NFS + smoke leitura (sem superpowers no contentor)
  aglwk45   Windows VM104 — propagate-six-repos.ps1 via qm guest exec (AGLSRV1)
  all       agldv03 + ct188 + aglwk45 (best-effort)
USAGE
}

log() { echo "[INFO] $*"; }
ok() { echo "[OK] $*"; }
warn() { echo "[WARN] $*"; }

remote_bash() {
  local target="$1"
  shift
  if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "  [dry-run] ssh $target bash -lc $(printf '%q ' "$@")"
    return 0
  fi
  "${SSH[@]}" "$target" "bash -lc $(printf '%q ' "$@")"
}

pct_exec() {
  local inner="$1"
  if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "  [dry-run] ssh $AGLSRV1_HOST pct exec $CT188_VMID -- bash -lc $(printf '%q' "$inner")"
    return 0
  fi
  "${SSH[@]}" "$AGLSRV1_HOST" "pct exec $CT188_VMID -- bash -lc $(printf '%q' "$inner")"
}

propagate_agldv03() {
  log "=== agldv03 ($AGLDV03_HOST) ==="
  local sync_cmd="cd '$HOSTMAN_ROOT' && LLM_WIKI_DIR='$LLM_WIKI_DIR' ./scripts/skills/sync-six-repos.sh --repo all"
  local verify_cmd="cd '$HOSTMAN_ROOT' && LLM_WIKI_DIR='$LLM_WIKI_DIR' ./scripts/skills/verify-six-repos.sh"
  local smoke_cmd="cd '$HOSTMAN_ROOT' && LLM_WIKI_DIR='$LLM_WIKI_DIR' ./scripts/skills/smoke-obsidian-cli-wiki.sh"

  if [[ "$(hostname -s 2>/dev/null || hostname)" == "agldv03" ]] && [[ -d "$HOSTMAN_ROOT/.git" ]]; then
    log "local agldv03 detectado"
    if [[ "$DRY_RUN" -eq 1 ]]; then
      echo "  [dry-run] $sync_cmd"
      echo "  [dry-run] $verify_cmd"
      echo "  [dry-run] $smoke_cmd"
    else
      bash -lc "$sync_cmd"
      bash -lc "$verify_cmd"
      bash -lc "$smoke_cmd" || warn "smoke Obsidian CLI (opcional se CLI inactivo)"
    fi
  else
    remote_bash "$AGLDV03_HOST" "$sync_cmd"
    remote_bash "$AGLDV03_HOST" "$verify_cmd"
    remote_bash "$AGLDV03_HOST" "$smoke_cmd" || warn "smoke Obsidian remoto (opcional)"
  fi
  ok "agldv03 propagate concluído"
}

propagate_ct188() {
  log "=== CT188 Hermes (via $AGLSRV1_HOST pct $CT188_VMID) ==="
  local ensure="$HOSTMAN_ROOT/scripts/proxmox/ensure-llm-wiki-ct188.sh"
  local smoke="$HOSTMAN_ROOT/scripts/skills/smoke-hermes-six-repos.sh"

  if [[ "$DRY_RUN" -eq 1 ]]; then
    pct_exec "bash '$ensure'"
    echo "  [dry-run] smoke-hermes-six-repos.sh"
    return 0
  fi

  if pct_exec "test -f '$ensure'"; then
    pct_exec "bash '$ensure'"
  else
    warn "ensure-llm-wiki-ct188.sh não encontrado em $ensure — verificar NFS"
    pct_exec "test -r /opt/agl-llm-wiki/wiki/index.md"
  fi

  if [[ -f "$smoke" ]]; then
    "${SSH[@]}" "$AGLSRV1_HOST" "pct exec $CT188_VMID -- bash -s" < "$smoke"
  else
    pct_exec "test -r /opt/agl-llm-wiki/wiki/Plano\\ Six\\ Repos\\ Multi-Agente.md"
  fi
  ok "CT188 propagate + smoke concluído (sem superpowers no contentor)"
}

propagate_aglwk45() {
  log "=== aglwk45 (VM$AGLWK45_VMID via AGLSRV1 guest agent) ==="
  local qemu="$HOSTMAN_ROOT/scripts/skills/propagate-six-repos-wk45-qemu.sh"
  if [[ ! -f "$qemu" ]]; then
    warn "propagate-six-repos-wk45-qemu.sh em falta"
    return 1
  fi
  if [[ "$DRY_RUN" -eq 1 ]]; then
    DRY_RUN=1 WK45_REPO_WIN="${WK45_REPO_WIN:-C:/Users/Administrator/apps/dev/agl/agl-hostman}" \
      bash "$qemu"
    return 0
  fi
  WK45_REPO_WIN="${WK45_REPO_WIN:-C:/Users/Administrator/apps/dev/agl/agl-hostman}" \
    bash "$qemu"
  ok "aglwk45 propagate via qm guest exec"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --host) HOST="$2"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Opção desconhecida: $1" >&2; usage; exit 1 ;;
  esac
done

[[ -n "$HOST" ]] || { usage; exit 1; }

run_host() {
  case "$1" in
    agldv03) propagate_agldv03 ;;
    ct188) propagate_ct188 ;;
    aglwk45) propagate_aglwk45 ;;
    *) echo "Host desconhecido: $1" >&2; exit 1 ;;
  esac
}

if [[ "$HOST" == "all" ]]; then
  FAIL=0
  run_host agldv03 || FAIL=1
  run_host ct188 || FAIL=1
  run_host aglwk45 || { warn "aglwk45 skipped/failed (VM offline ou U: indisponível)"; FAIL=1; }
  [[ "$FAIL" -eq 0 ]] || exit 1
else
  run_host "$HOST"
fi

ok "propagate-six-repos host=$HOST dry_run=$DRY_RUN"
