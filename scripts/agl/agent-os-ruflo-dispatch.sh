#!/usr/bin/env bash
# Agent-OS spec → fila Ruflo: parse tasks.md, orchestration.yml, dispatch harness.
#
# Uso:
#   bash scripts/agl/agent-os-ruflo-dispatch.sh --spec infrastructure/wireguard-peer-setup --dry-run
#   bash scripts/agl/agent-os-ruflo-dispatch.sh --spec infrastructure/wireguard-peer-setup --write-orchestration --json
#   bash scripts/agl/agent-os-ruflo-dispatch.sh --spec infrastructure/wireguard-peer-setup --group pre-deployment-validation
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
PARSER="${SCRIPT_DIR}/lib/parse-agent-os-tasks.py"
SWARM_TEMPLATE="${REPO_ROOT}/config/ruflo/agent-os-swarm.yml"
HARNESS_DISPATCH="${REPO_ROOT}/scripts/agl/harness-dispatch.sh"

SPEC=""
GROUP=""
DRY_RUN=1
JSON_OUT=0
WRITE_ORCH=0
QUEUE_ONLY=0

usage() {
  sed -n '2,9p' "$0" | sed 's/^# \{0,1\}//'
  exit 2
}

log() { echo "[agent-os-ruflo] $*" >&2; }

resolve_spec_dir() {
  local raw="$1"
  local candidates=(
    "$REPO_ROOT/agent-os/specs/$raw"
    "$REPO_ROOT/agent-os/specs/infrastructure/$raw"
    "$REPO_ROOT/$raw"
  )
  local c
  for c in "${candidates[@]}"; do
    if [[ -d "$c" && -f "$c/tasks.md" ]]; then
      printf '%s' "$c"
      return 0
    fi
  done
  return 1
}

write_orchestration() {
  local spec_dir="$1" parsed="$2"
  local orch="${spec_dir}/orchestration.yml"
  local tmp
  tmp="$(mktemp)"
  {
    echo "# Gerado/atualizado por agent-os-ruflo-dispatch.sh"
    echo "swarm:"
    echo "  topology: hierarchical"
    echo "  max_agents: 6"
    echo "  strategy: specialized"
    echo "  consensus: raft"
    echo "  queen_type: tactical"
    echo "task_groups:"
    python3 - "$parsed" <<'PY'
import json, sys
data = json.load(open(sys.argv[1]))
for g in data["task_groups"]:
    status = "done" if g["tasks_open"] == 0 and g["tasks_total"] > 0 else "pending"
    print(f"  - name: {g['name']}")
    print(f"    title: \"{g['title']}\"")
    print(f"    ruflo_worker: {g['ruflo_worker']}")
    print(f"    status: {status}")
    print(f"    tasks_open: {g['tasks_open']}")
    print(f"    tasks_total: {g['tasks_total']}")
PY
  } >"$tmp"
  if [[ "$DRY_RUN" -eq 1 ]]; then
    log "[dry-run] orchestration.yml:"
    cat "$tmp"
    rm -f "$tmp"
    return
  fi
  mv "$tmp" "$orch"
  log "OK orchestration.yml → $orch"
}

write_queue() {
  local spec_dir="$1" spec_name="$2" parsed="$3"
  local queue="${spec_dir}/.ruflo-queue.json"
  local payload
  payload="$(python3 - "$parsed" "$spec_name" "$spec_dir" <<'PY'
import json, sys
parsed = json.load(open(sys.argv[1]))
spec_name = sys.argv[2]
spec_dir = sys.argv[3]
queue = {
    "spec": spec_name,
    "spec_dir": spec_dir,
    "swarm_template": "config/ruflo/agent-os-swarm.yml",
    "groups": parsed["task_groups"],
    "summary": parsed["summary"],
    "next_workers": [g for g in parsed["task_groups"] if g["tasks_open"] > 0][:6],
}
print(json.dumps(queue, indent=2))
PY
)"
  if [[ "$DRY_RUN" -eq 1 ]]; then
    printf '%s\n' "$payload"
    return
  fi
  printf '%s\n' "$payload" >"$queue"
  log "OK queue → $queue"
}

build_ruflo_task() {
  local spec_name="$1" group="$2" parsed="$3"
  python3 - "$parsed" "$spec_name" "$group" <<'PY'
import json, sys
parsed = json.load(open(sys.argv[1]))
spec = sys.argv[2]
group = sys.argv[3]
groups = parsed["task_groups"]
if group:
    groups = [g for g in groups if g["name"] == group]
    if not groups:
        raise SystemExit(f"grupo desconhecido: {group}")
else:
    groups = [g for g in groups if g["tasks_open"] > 0]
    if not groups:
        groups = parsed["task_groups"][:1]
target = groups[0]
print(
    f"Agent-OS spec {spec}: implementar task group '{target['name']}' "
    f"({target['title']}) como worker {target['ruflo_worker']}. "
    f"Ler tasks.md, spec.md, agent-os/standards/. Marcar [x] ao concluir."
)
PY
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --spec) SPEC="$2"; shift 2 ;;
    --group) GROUP="$2"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    --apply) DRY_RUN=0; shift ;;
    --write-orchestration) WRITE_ORCH=1; shift ;;
    --queue-only) QUEUE_ONLY=1; shift ;;
    --json) JSON_OUT=1; shift ;;
    -h|--help) usage ;;
    *) log "Opção desconhecida: $1"; usage ;;
  esac
done

[[ -n "$SPEC" ]] || usage
[[ -f "$PARSER" ]] || { log "ERRO: parser em falta"; exit 1; }

SPEC_DIR="$(resolve_spec_dir "$SPEC")" || {
  log "ERRO: spec sem tasks.md: $SPEC"
  exit 1
}
SPEC_NAME="$(basename "$SPEC_DIR")"
TASKS_MD="${SPEC_DIR}/tasks.md"

PARSED_JSON="$(mktemp)"
python3 "$PARSER" "$TASKS_MD" >"$PARSED_JSON"

[[ "$WRITE_ORCH" -eq 1 ]] && write_orchestration "$SPEC_DIR" "$PARSED_JSON"

QUEUE_JSON="$(write_queue "$SPEC_DIR" "$SPEC_NAME" "$PARSED_JSON" 2>/dev/null || true)"
if [[ "$QUEUE_ONLY" -eq 1 ]]; then
  rm -f "$PARSED_JSON"
  exit 0
fi

RUflo_TASK="$(build_ruflo_task "$SPEC_NAME" "$GROUP" "$PARSED_JSON")"

if [[ "$JSON_OUT" -eq 1 ]]; then
  python3 - "$PARSED_JSON" "$SPEC_NAME" "$SPEC_DIR" "$RUflo_TASK" "$GROUP" "$REPO_ROOT" <<'PY'
import json, sys
parsed = json.load(open(sys.argv[1]))
spec, spec_dir, task, group, repo = sys.argv[2:7]
hd = (
    f"bash scripts/agl/harness-dispatch.sh --harness ruflo --auth litellm "
    f"--task {json.dumps(task)} --repo {json.dumps(spec_dir)}"
)
out = {
    "spec": spec,
    "spec_dir": spec_dir,
    "ruflo_task": task,
    "group_filter": group or None,
    "summary": parsed["summary"],
    "task_groups": parsed["task_groups"],
    "harness_dispatch": hd,
    "post_task_hook": f"bash scripts/agl/agent-os-post-task-hook.sh --spec {spec} --group <group>",
    "verifier": ".claude/agents/agent-os/implementation-verifier.md",
}
print(json.dumps(out, indent=2))
PY
  rm -f "$PARSED_JSON"
  exit 0
fi

cat <<PLAN
SPEC: ${SPEC_NAME}
DIR: ${SPEC_DIR}
SUMMARY: $(python3 -c "import json; d=json.load(open('$PARSED_JSON')); print(d['summary'])")
GROUP: ${GROUP:-<primeiro aberto>}
RUflo_TASK: ${RUflo_TASK}
NEXT: bash scripts/agl/harness-dispatch.sh --dry-run --harness ruflo --auth litellm --task "$(printf '%q' "$RUflo_TASK")" --repo "$(printf '%q' "$SPEC_DIR")"
HOOK: bash scripts/agl/agent-os-post-task-hook.sh --spec ${SPEC_NAME} --group ${GROUP:-<group>} [--bd-close bd-XXX]
VERIFY: .claude/agents/agent-os/implementation-verifier.md (quando todos [x])
PLAN

if [[ "$DRY_RUN" -eq 0 && -x "$HARNESS_DISPATCH" ]]; then
  log "A executar harness-dispatch ruflo..."
  exec bash "$HARNESS_DISPATCH" --harness ruflo --auth litellm --task "$RUflo_TASK" --repo "$SPEC_DIR" --skip-probe
fi

rm -f "$PARSED_JSON"
