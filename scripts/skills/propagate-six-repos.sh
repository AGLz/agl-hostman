#!/usr/bin/env bash
# Propaga Six Repos + post skills para hosts AGL (Fase 5).
# Plano: ai-docs/planning/SIX-REPOS-MULTI-AGENT-PLAN.md
#
# Uso:
#   ./scripts/skills/propagate-six-repos.sh --host agldv04
#   ./scripts/skills/propagate-six-repos.sh --host agldv-all
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

AGLDV02_HOST="${AGLDV02_HOST:-root@100.95.204.85}"
AGLDV03_HOST="${AGLDV03_HOST:-root@100.94.221.87}"
AGLDV04_HOST="${AGLDV04_HOST:-root@100.113.9.98}"
AGLDV05_HOST="${AGLDV05_HOST:-root@100.82.71.49}"
AGLDV06_HOST="${AGLDV06_HOST:-root@100.71.229.12}"
AGLDV07_HOST="${AGLDV07_HOST:-root@100.64.175.89}"
AGLDV12_HOST="${AGLDV12_HOST:-root@100.71.217.115}"
AGLSRV1_HOST="${AGLSRV1_HOST:-root@100.107.113.33}"
CT188_VMID="${CT188_VMID:-188}"
AGLWK45_VMID="${AGLWK45_VMID:-104}"
WK45_REPO_WIN="${WK45_REPO_WIN:-U:\\\\apps\\\\dev\\\\agl\\\\agl-hostman}"

DRY_RUN=0
HOST=""

SSH=(ssh -o BatchMode=yes -o ConnectTimeout=25 -o StrictHostKeyChecking=accept-new)

usage() {
  cat <<USAGE
Usage: $(basename "$0") --host <agldv02|agldv03|agldv04|agldv05|agldv06|agldv07|agldv12|agldv-all|ct188|aglwk45|all> [--dry-run]

Propaga instalação Six Repos + post skills (sync + verify + Claude Code plugins).

  agldv02..12  Dev LXC/CT — install-post-skills-claude-code.sh + verify
  agldv-all    Todos os agldv* acima (best-effort SSH)
  ct188        Hermes — ensure llm-wiki NFS + smoke leitura
  aglwk45      Windows VM104 — propagate-six-repos-wk45-qemu.sh
  all          agldv-all + ct188 + aglwk45
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

propagate_agldv_host() {
  local name="$1"
  local ssh_target="$2"
  log "=== $name ($ssh_target) ==="
  local install_cmd="cd '$HOSTMAN_ROOT' && LLM_WIKI_DIR='$LLM_WIKI_DIR' ./scripts/skills/install-post-skills-claude-code.sh"
  local standalone_cmd="bash -s"
  local verify_cmd="cd '$HOSTMAN_ROOT' && LLM_WIKI_DIR='$LLM_WIKI_DIR' SKIP_LLM_WIKI=${SKIP_LLM_WIKI:-0} ./scripts/skills/verify-six-repos.sh"

  local local_short
  local_short="$(hostname -s 2>/dev/null || hostname)"

  run_local() {
    if [[ -d "$HOSTMAN_ROOT/.git" && -x "$HOSTMAN_ROOT/scripts/skills/install-post-skills-claude-code.sh" ]]; then
      bash -lc "$install_cmd"
    else
      warn "$name: repo agl-hostman indisponível — modo standalone"
      bash "$HOSTMAN_ROOT/scripts/skills/install-post-skills-standalone.sh" 2>/dev/null || \
        bash -s < "$HOSTMAN_ROOT/scripts/skills/install-post-skills-standalone.sh"
    fi
  }

  run_remote() {
    if "${SSH[@]}" "$ssh_target" "test -d '$HOSTMAN_ROOT/.git'"; then
      remote_bash "$ssh_target" "$install_cmd"
    else
      warn "$name: sem NFS em $HOSTMAN_ROOT — standalone via stdin"
      if [[ "$DRY_RUN" -eq 1 ]]; then
        echo "  [dry-run] ssh $ssh_target bash -s < install-post-skills-standalone.sh"
      else
        "${SSH[@]}" "$ssh_target" "bash -s" < "$HOSTMAN_ROOT/scripts/skills/install-post-skills-standalone.sh"
      fi
    fi
  }

  if [[ "$local_short" == "$name" ]]; then
    log "local $name detectado"
    if [[ "$DRY_RUN" -eq 1 ]]; then
      echo "  [dry-run] install post skills (local)"
      echo "  [dry-run] $verify_cmd"
    else
      run_local
      if [[ -d "$HOSTMAN_ROOT/.git" ]]; then
        bash -lc "$verify_cmd" || warn "verify $name com WARNs"
      fi
    fi
  else
    if [[ "$DRY_RUN" -eq 1 ]]; then
      echo "  [dry-run] remote install $name"
      echo "  [dry-run] $verify_cmd"
    else
      run_remote
      if "${SSH[@]}" "$ssh_target" "test -d '$HOSTMAN_ROOT/.git'"; then
        remote_bash "$ssh_target" "$verify_cmd" || warn "verify remoto $name (WARNs ok)"
      fi
    fi
  fi
  ok "$name propagate concluído"
}

propagate_agldv02() { propagate_agldv_host agldv02 "$AGLDV02_HOST"; }
propagate_agldv03() { propagate_agldv_host agldv03 "$AGLDV03_HOST"; }
propagate_agldv04() { propagate_agldv_host agldv04 "$AGLDV04_HOST"; }
propagate_agldv05() { propagate_agldv_host agldv05 "$AGLDV05_HOST"; }
propagate_agldv06() { propagate_agldv_host agldv06 "$AGLDV06_HOST"; }
propagate_agldv07() { propagate_agldv_host agldv07 "$AGLDV07_HOST"; }
propagate_agldv12() { propagate_agldv_host agldv12 "$AGLDV12_HOST"; }

propagate_agldv_all() {
  local FAIL=0
  propagate_agldv02 || { warn "agldv02 falhou"; FAIL=1; }
  propagate_agldv03 || { warn "agldv03 falhou"; FAIL=1; }
  propagate_agldv04 || { warn "agldv04 falhou"; FAIL=1; }
  propagate_agldv05 || { warn "agldv05 falhou"; FAIL=1; }
  propagate_agldv06 || { warn "agldv06 falhou"; FAIL=1; }
  propagate_agldv07 || { warn "agldv07 falhou"; FAIL=1; }
  propagate_agldv12 || { warn "agldv12 falhou"; FAIL=1; }
  [[ "$FAIL" -eq 0 ]] || return 1
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
    agldv02) propagate_agldv02 ;;
    agldv03) propagate_agldv03 ;;
    agldv04) propagate_agldv04 ;;
    agldv05) propagate_agldv05 ;;
    agldv06) propagate_agldv06 ;;
    agldv07) propagate_agldv07 ;;
    agldv12) propagate_agldv12 ;;
    agldv-all) propagate_agldv_all ;;
    ct188) propagate_ct188 ;;
    aglwk45) propagate_aglwk45 ;;
    *) echo "Host desconhecido: $1" >&2; exit 1 ;;
  esac
}

if [[ "$HOST" == "all" ]]; then
  FAIL=0
  propagate_agldv_all || FAIL=1
  run_host ct188 || FAIL=1
  run_host aglwk45 || { warn "aglwk45 skipped/failed (VM offline ou U: indisponível)"; FAIL=1; }
  [[ "$FAIL" -eq 0 ]] || exit 1
else
  run_host "$HOST"
fi

ok "propagate-six-repos host=$HOST dry_run=$DRY_RUN"
