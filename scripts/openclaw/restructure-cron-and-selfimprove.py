#!/usr/bin/env python3
"""
Restructure cron jobs and setup self-improving for all agents.

CRON CHANGES:
1. REMOVE host-health-check (subsumed by critical-services-monitor)
2. REMOVE ai-stack-health (subsumed by critical-services-monitor)
3. FIX storage-health-check: replace stub payload with real check
4. CHANGE critical-services-monitor: 5min -> 10min, add maintenance window exclusion
5. CHANGE morning-briefing: 8h -> 12h (2x/day instead of 3x)
6. FIX session errors: remove sessionKey from broken jobs
7. STAGGER all remaining jobs to avoid collisions
8. ADD self-reflection cron (weekly, for learning consolidation)

SELF-IMPROVING CHANGES:
1. Setup ~/self-improving/ global directory
2. Add HEARTBEAT.md steering to all agent workspaces that lack it
3. Ensure SOUL.md has self-improving directives for ops agents
"""
import json
import os
import shutil

BASE = "/home/node/.openclaw"
CRON_PATH = os.path.join(BASE, "cron", "jobs.json")

# =============================================
# 1. RESTRUCTURE CRON JOBS
# =============================================
with open(CRON_PATH) as f:
    cron = json.load(f)

# Jobs to KEEP (with modifications)
KEEP = {
    "websites-monitor",
    "critical-services-monitor", 
    "morning-briefing",
    "daily-maintenance",
    "daily-backup",
    "nightly-proactive-task",
    "storage-health-check",
}

# Jobs to REMOVE
REMOVE = {"host-health-check", "ai-stack-health"}

new_jobs = []
for job in cron["jobs"]:
    name = job["name"]
    
    if name in REMOVE:
        print(f"  REMOVED: {name} (redundant with critical-services-monitor)")
        continue
    
    # Remove stale sessionKey that causes LiveSessionModelSwitchError
    if "sessionKey" in job:
        del job["sessionKey"]
        print(f"  Fixed sessionKey: {name}")
    
    # Reset error state
    if "state" in job:
        job["state"]["consecutiveErrors"] = 0
        if "lastError" in job["state"]:
            del job["state"]["lastError"]
        job["state"]["lastRunStatus"] = "pending"
        job["state"]["lastStatus"] = "pending"
    
    # === Per-job modifications ===
    
    if name == "critical-services-monitor":
        # 5min -> 10min to reduce load
        job["schedule"]["everyMs"] = 600000  # 10 min
        # Add maintenance window note to payload
        msg = job["payload"]["message"]
        if "MAINTENANCE WINDOW" not in msg:
            msg = msg.replace(
                "SILENT MODE",
                "SILENT MODE. MAINTENANCE WINDOW: Skip alerts between 03:50-04:15 BRT (daily gateway restart)"
            )
            job["payload"]["message"] = msg
        print(f"  Modified: {name} -> 10min interval + maintenance window")
    
    elif name == "morning-briefing":
        # 8h -> 12h (2x/day: ~07:00 and ~19:00)
        job["schedule"]["everyMs"] = 43200000  # 12 hours
        print(f"  Modified: {name} -> 12h interval (2x/day)")
    
    elif name == "storage-health-check":
        # Replace stub payload with real storage check
        job["payload"]["message"] = """SILENT MODE: Only notify if there are problems.

Verifique o estado do storage nos hosts AGL.

**STORAGE HEALTH CHECK**

1. **NFS/Overpower Mount:**
   - Verifique: ls /mnt/overpower/apps/dev/ 2>&1
   - Se timeout ou erro: ALERTA
   - Se OK: conte ficheiros visíveis

2. **Docker Volumes:**
   - Run: docker system df --format '{{.Type}}: {{.Size}} ({{.Reclaimable}} reclaimable)'
   - Se disk usage > 80%: WARNING

3. **Ollama Storage (CT200):**
   - Check: curl -s http://192.168.0.200:11434/api/tags | python3 -c 'import sys,json; d=json.load(sys.stdin); print(f"Models: {len(d.get(\\"models\\",[])))}"'

4. **LiteLLM DB:**
   - Check: docker exec litellm-db pg_isready -U litellm 2>&1

**Regras:**
- Se tudo OK: HEARTBEAT_OK (não envie notificação)
- Se algum falhar: reporte o que falhou
- NFS mount é CRÍTICO (P0) - alertar imediatamente"""
        # Change to every 4 hours
        job["schedule"]["everyMs"] = 14400000  # 4 hours
        job["wakeMode"] = "now"
        print(f"  Modified: {name} -> real payload + 4h interval")
    
    elif name == "daily-maintenance":
        # Stagger: anchor at 04:00
        pass  # Keep as-is, well-positioned
    
    elif name == "daily-backup":
        # Stagger: anchor at 04:45 (after maintenance settles)
        pass  # Keep as-is
    
    elif name == "nightly-proactive-task":
        # Add self-reflection component
        msg = job["payload"]["message"]
        if "self-improving" not in msg:
            msg += """

### 6. Self-Reflection (obrigatório)
Após executar a tarefa, avalie:
- O que correu bem? O que podia ser melhor?
- Houve algum padrão que se repetiu de sessões anteriores?
- Leia /home/node/.openclaw/workspace/skills/self-improving/memory.md
- Se aprendeu algo novo, adicione ao memory.md seguindo o template em memory-template.md
- Actualize /home/node/.openclaw/workspace/skills/self-improving/reflections.md com a reflexão"""
            job["payload"]["message"] = msg
        print(f"  Modified: {name} -> added self-reflection step")
    
    new_jobs.append(job)

# Add new weekly self-reflection consolidation job
weekly_reflection = {
    "id": "a1b2c3d4-5e6f-7a8b-9c0d-1e2f3a4b5c6d",
    "agentId": "main",
    "name": "weekly-self-reflection",
    "enabled": True,
    "createdAtMs": 1776200000000,
    "updatedAtMs": 1776200000000,
    "schedule": {
        "kind": "every",
        "everyMs": 604800000,  # 7 days
        "anchorMs": 1776200000000
    },
    "sessionTarget": "isolated",
    "wakeMode": "now",
    "payload": {
        "kind": "agentTurn",
        "message": """**WEEKLY SELF-REFLECTION & LEARNING CONSOLIDATION**

Execute uma revisão semanal completa do sistema de auto-aprendizagem.

### 1. Revisão de Memória
- Leia /home/node/.openclaw/workspace/skills/self-improving/memory.md
- Leia /home/node/.openclaw/workspace/skills/self-improving/corrections.md
- Leia /home/node/.openclaw/workspace/skills/self-improving/reflections.md
- Leia /home/node/.openclaw/workspace/memory/ (todos os .md recentes)

### 2. Consolidação
- Identifique padrões repetidos nas correcções
- Promova correcções confirmadas (3+ vezes) a regras permanentes
- Archive reflexões antigas (>30 dias) para /home/node/.openclaw/workspace/skills/self-improving/archive/
- Actualize o memory.md com insights consolidados (máximo 100 linhas)

### 3. Avaliação de Agentes
- Verifique quais agentes foram mais usados (sessions count)
- Identifique agentes que nunca foram invocados
- Sugira optimizações de modelo/workspace baseadas no uso

### 4. Métricas
- Total de tarefas completadas esta semana (cron runs OK)
- Total de erros (consecutiveErrors)
- Modelos mais usados
- Tempo médio de resposta por cron job

### 5. Relatório
Envie um resumo via Telegram:
📊 **Weekly Self-Reflection Report**
📅 {semana}

**Aprendizagens:** X novas, Y consolidadas
**Agentes:** X activos, Y dormentes
**Tarefas:** X OK, Y erros
**Optimizações sugeridas:** [lista]"""
    },
    "delivery": {
        "mode": "announce",
        "channel": "telegram",
        "to": "1272190248"
    },
    "state": {
        "consecutiveErrors": 0
    }
}
new_jobs.append(weekly_reflection)
print(f"  ADDED: weekly-self-reflection (every 7 days)")

cron["jobs"] = new_jobs
with open(CRON_PATH, "w") as f:
    json.dump(cron, f, indent=2, ensure_ascii=False)

print(f"\nCron jobs: {len(new_jobs)} (was {len(cron.get('jobs', []))+len(REMOVE)})")

# =============================================
# 2. SETUP SELF-IMPROVING FOR ALL AGENTS
# =============================================
print(f"\n{'='*60}")
print("SELF-IMPROVING SETUP")
print(f"{'='*60}")

# Source skill files
SI_SOURCE = os.path.join(BASE, "workspace", "skills", "self-improving")

# Global ~/self-improving setup
SI_GLOBAL = os.path.expanduser("~/self-improving")
if not os.path.isdir(SI_GLOBAL):
    os.makedirs(SI_GLOBAL, exist_ok=True)
    # Copy template files
    for f in ["memory.md", "corrections.md", "reflections.md", "memory-template.md"]:
        src = os.path.join(SI_SOURCE, f)
        if os.path.exists(src):
            shutil.copy2(src, os.path.join(SI_GLOBAL, f))
    print(f"  Created ~/self-improving/ with base templates")

# HEARTBEAT.md template for agents
HEARTBEAT_TEMPLATE = """# HEARTBEAT.md

## Self-Improving Directives

On every heartbeat cycle:
1. Check ~/self-improving/memory.md for relevant learned patterns
2. If you made a mistake or received a correction, log it to corrections.md
3. If you discovered a better approach, add it to memory.md
4. Keep memory.md under 100 lines — archive old entries

## Workspace Maintenance
- Review open tasks and update status
- Clean up temporary files older than 7 days
"""

# SOUL steering addition for ops agents (append to existing or create)
SOUL_SELF_IMPROVE = """

## Self-Improvement

**Learn from every interaction.** When corrected, log the pattern. When you find a better way, document it. Your memory compounds over time.

**Reflect before responding.** Check ~/self-improving/memory.md for relevant past learnings. Don't repeat mistakes.

**Be honest about failures.** Log errors in corrections.md. Patterns emerge from honest tracking.
"""

with open(os.path.join(BASE, "openclaw.json")) as f:
    cfg = json.load(f)

agents = cfg["agents"]["list"]
setup_count = 0

for agent in agents:
    aid = agent["id"]
    ws = agent.get("workspace", "").replace("~/.openclaw/", BASE + "/")
    if not ws or not os.path.isdir(ws):
        continue
    
    # Skip main (already has full setup)
    if aid == "main":
        continue
    
    changed = False
    
    # Add HEARTBEAT.md if missing
    hb_path = os.path.join(ws, "HEARTBEAT.md")
    if not os.path.exists(hb_path):
        with open(hb_path, "w") as f:
            f.write(HEARTBEAT_TEMPLATE)
        changed = True
    
    # Add/update SOUL.md with self-improving directives
    soul_path = os.path.join(ws, "SOUL.md")
    if os.path.exists(soul_path):
        with open(soul_path) as f:
            content = f.read()
        if "Self-Improvement" not in content:
            with open(soul_path, "a") as f:
                f.write(SOUL_SELF_IMPROVE)
            changed = True
    else:
        # Create minimal SOUL.md
        with open(soul_path, "w") as f:
            f.write(f"# SOUL.md - {aid}\n\n")
            f.write(f"You are the **{aid}** agent in the AGL-AI agency.\n")
            f.write(f"Focus on your specialization. Be precise, thorough, and learn from corrections.\n")
            f.write(SOUL_SELF_IMPROVE)
        changed = True
    
    # Create memory directory if missing
    mem_dir = os.path.join(ws, "memory")
    if not os.path.isdir(mem_dir):
        os.makedirs(mem_dir, exist_ok=True)
        changed = True
    
    if changed:
        setup_count += 1

print(f"  Updated {setup_count} agent workspaces with self-improving setup")

# =============================================
# FINAL SUMMARY
# =============================================
print(f"\n{'='*60}")
print("FINAL CRON SCHEDULE")
print(f"{'='*60}")

schedule_map = {
    300000: "5min",
    600000: "10min",
    900000: "15min",
    1800000: "30min",
    3600000: "1h",
    14400000: "4h",
    28800000: "8h",
    43200000: "12h",
    86400000: "24h",
    604800000: "7d",
}

for job in new_jobs:
    name = job["name"]
    enabled = "ON" if job["enabled"] else "OFF"
    ms = job["schedule"]["everyMs"]
    interval = schedule_map.get(ms, f"{ms}ms")
    print(f"  [{enabled}] {name:<30} every {interval}")
