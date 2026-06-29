#!/usr/bin/env bash
# Review-Queue Hermes (modelo Verdent "To Review") — fila partilhada Jarvis/Verifier.
#
# Path partilhado (rw em todos os perfis via mount LLM_WIKI_DIR → /opt/llm-wiki):
#   /opt/llm-wiki/raw/hermes/review-queue/queue.json
#   (o mount /mnt/overpower é NFS root-squashed, não escrevível pelos agentes)
#
# Uso:
#   hermes-review-queue.sh add <id> <agent> "<goal>" "<criterio1;criterio2>"
#   hermes-review-queue.sh set-status <id> <status>
#   hermes-review-queue.sh verdict <id> <PASS|FAIL> "<evidencia>"
#   hermes-review-queue.sh list [status]
#
# Estados: planned|in_progress|to_review|verifying|done|blocked|failed

set -euo pipefail

QUEUE="${REVIEW_QUEUE:-/opt/llm-wiki/raw/hermes/review-queue/queue.json}"
ACTION="${1:-list}"

mkdir -p "$(dirname "${QUEUE}")"
[[ -f "${QUEUE}" ]] || echo '{"items":[]}' > "${QUEUE}"

python3 - "${QUEUE}" "$@" <<'PY'
import json, sys
from datetime import datetime, timezone
from pathlib import Path

queue = Path(sys.argv[1])
action = sys.argv[2] if len(sys.argv) > 2 else "list"
args = sys.argv[3:]

VALID = {"planned","in_progress","to_review","verifying","done","blocked","failed"}

data = json.loads(queue.read_text() or '{"items":[]}')
items = data.setdefault("items", [])
by_id = {it["id"]: it for it in items}
now = datetime.now(timezone.utc).isoformat()

def save():
    queue.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")

if action == "add":
    tid, agent, goal = args[0], args[1], args[2]
    criteria = [c.strip() for c in (args[3].split(";") if len(args) > 3 else []) if c.strip()]
    it = by_id.get(tid) or {"id": tid}
    it.update({
        "agent": agent, "goal": goal, "acceptance_criteria": criteria,
        "status": "planned", "verifier_verdict": None, "updated_at": now,
    })
    if tid not in by_id:
        items.append(it)
    save(); print(f"OK add {tid} → {agent} ({len(criteria)} criteria)")

elif action == "set-status":
    tid, status = args[0], args[1]
    if status not in VALID:
        sys.exit(f"status inválido: {status} (válidos: {sorted(VALID)})")
    if tid not in by_id:
        sys.exit(f"id desconhecido: {tid}")
    by_id[tid]["status"] = status
    by_id[tid]["updated_at"] = now
    save(); print(f"OK {tid} → {status}")

elif action == "verdict":
    tid, verdict = args[0], args[1].upper()
    if verdict not in {"PASS","FAIL"}:
        sys.exit("veredito deve ser PASS ou FAIL")
    if tid not in by_id:
        sys.exit(f"id desconhecido: {tid}")
    it = by_id[tid]
    it["verifier_verdict"] = {"result": verdict, "evidence": args[2] if len(args) > 2 else "", "at": now}
    it["status"] = "done" if verdict == "PASS" else "failed"
    it["updated_at"] = now
    save(); print(f"OK {tid} verdict={verdict} → {it['status']}")

elif action == "list":
    flt = args[0] if args else None
    rows = [it for it in items if not flt or it.get("status") == flt]
    if not rows:
        print("(fila vazia)" if not flt else f"(sem itens em {flt})")
    for it in sorted(rows, key=lambda x: x.get("updated_at", "")):
        v = it.get("verifier_verdict")
        vr = v["result"] if isinstance(v, dict) else "—"
        print(f"- [{it.get('status')}] {it['id']} ({it.get('agent')}) {it.get('goal','')[:60]} | verdict={vr}")
else:
    sys.exit(f"ação desconhecida: {action}")
PY
