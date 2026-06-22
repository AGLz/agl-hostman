#!/usr/bin/env bash
# Hook pós-task Agent-OS: actualiza orchestration, sugere verifier, opcional bd close.
#
# Uso:
#   bash scripts/agl/agent-os-post-task-hook.sh --spec wireguard-peer-setup --group pre-deployment-validation
#   bash scripts/agl/agent-os-post-task-hook.sh --spec infrastructure/wireguard-peer-setup --group verification-testing --bd-close bd-abc
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
PARSER="${SCRIPT_DIR}/lib/parse-agent-os-tasks.py"
DISPATCH="${SCRIPT_DIR}/agent-os-ruflo-dispatch.sh"

SPEC=""
GROUP=""
BD_ID=""
DRY_RUN=1

usage() {
  sed -n '2,6p' "$0" | sed 's/^# \{0,1\}//'
  exit 2
}

log() { echo "[agent-os-hook] $*" >&2; }

resolve_spec_dir() {
  local raw="$1"
  local candidates=(
    "$REPO_ROOT/agent-os/specs/$raw"
    "$REPO_ROOT/agent-os/specs/infrastructure/$raw"
  )
  local c
  for c in "${candidates[@]}"; do
    [[ -d "$c" && -f "$c/tasks.md" ]] && { printf '%s' "$c"; return 0; }
  done
  return 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --spec) SPEC="$2"; shift 2 ;;
    --group) GROUP="$2"; shift 2 ;;
    --bd-close) BD_ID="$2"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    --apply) DRY_RUN=0; shift ;;
    -h|--help) usage ;;
    *) log "Opção desconhecida: $1"; usage ;;
  esac
done

[[ -n "$SPEC" && -n "$GROUP" ]] || usage

SPEC_DIR="$(resolve_spec_dir "$SPEC")" || { log "ERRO: spec inválido"; exit 1; }
PARSED="$(python3 "$PARSER" "${SPEC_DIR}/tasks.md")"

GROUP_OPEN="$(printf '%s' "$PARSED" | python3 -c "import json,sys; d=json.load(sys.stdin); g=next((x for x in d['task_groups'] if x['name']==sys.argv[1]), None); print(g['tasks_open'] if g else -1)" "$GROUP")"
GROUP_TOTAL="$(printf '%s' "$PARSED" | python3 -c "import json,sys; d=json.load(sys.stdin); g=next((x for x in d['task_groups'] if x['name']==sys.argv[1]), None); print(g['tasks_total'] if g else 0)" "$GROUP")"

if [[ "$GROUP_OPEN" == "-1" ]]; then
  log "ERRO: grupo não encontrado: $GROUP"
  exit 1
fi

if [[ "$GROUP_OPEN" -gt 0 ]]; then
  log "Grupo ${GROUP}: ${GROUP_OPEN}/${GROUP_TOTAL} tarefas ainda abertas — marcar [x] em tasks.md"
  exit 1
fi

log "Grupo ${GROUP}: completo (${GROUP_TOTAL} tarefas)"

if [[ "$DRY_RUN" -eq 0 ]]; then
  bash "$DISPATCH" --spec "$SPEC" --write-orchestration --apply
fi

PARSED="$(python3 "$PARSER" "${SPEC_DIR}/tasks.md")"
SUMMARY_OPEN="$(printf '%s' "$PARSED" | python3 -c "import json,sys; print(json.load(sys.stdin)['summary']['tasks_open'])")"

if [[ "$BD_ID" != "" ]]; then
  if [[ "$DRY_RUN" -eq 1 ]]; then
    log "[dry-run] bd close $BD_ID"
  elif command -v bd >/dev/null 2>&1; then
    bd close "$BD_ID" --reason "Agent-OS group ${GROUP} done" --json || log "WARN: bd close falhou"
  else
    log "WARN: bd não no PATH — saltar close"
  fi
fi

if [[ "$SUMMARY_OPEN" -eq 0 ]]; then
  cat <<DONE
ALL_GROUPS_COMPLETE: true
VERIFY: Invocar implementation-verifier em ${SPEC_DIR}
CMD: /implement-tasks (PHASE 3) ou agent .claude/agents/agent-os/implementation-verifier.md
DONE
else
  NEXT_GROUP="$(printf '%s' "$PARSED" | python3 -c "import json,sys; d=json.load(sys.stdin); g=next((x['name'] for x in d['task_groups'] if x['tasks_open']>0), ''); print(g)")"
  echo "NEXT_GROUP: ${NEXT_GROUP}"
  echo "DISPATCH: bash scripts/agl/agent-os-ruflo-dispatch.sh --spec ${SPEC} --group ${NEXT_GROUP} --apply"
fi
