#!/usr/bin/env bash
# Seed KanBan Minions — uma task template por agente (atribuições AGLz).
set -euo pipefail

MINIONS_URL="${MINIONS_URL:-http://127.0.0.1:6969}"

python3 - "${MINIONS_URL}" <<'PY'
import json, sys, urllib.request

base = sys.argv[1].rstrip("/")
agents = {
    "jarvis": "CEO Manager — Plan/Execute/Verify/Deliver; delega, não executa",
    "elon": "Produto / pesquisa / roadmap / AI Opportunity",
    "satya": "Código / deploys / makemoney pipeline",
    "werner": "Proxmox / LiteLLM / rede / incidentes infra",
    "orion": "Media *arr / media-grabber",
    "curator": "KB llm-wiki lint/ingest",
    "argus": "FinOps LLM / quotas / limites",
    "verifier": "QA gate PASS/FAIL vs acceptance criteria",
    "composio": "Integrações SaaS via Composio MCP",
}
created = 0
for agent, role in agents.items():
    body = json.dumps({
        "title": f"Atribuição: {agent}",
        "description": f"[{agent}] {role}",
    }).encode()
    req = urllib.request.Request(
        f"{base}/api/tasks",
        data=body,
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=15) as resp:
            if resp.status in (200, 201):
                created += 1
                print(f"OK task {agent}")
    except Exception as e:
        print(f"WARN {agent}: {e}")
print(f"Seed KanBan: {created}/{len(agents)} tasks")
PY
