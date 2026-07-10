# Força-tarefa — Crons & Telegram Hermes (CT188)

> **Data:** 2026-07-09 · **Owner:** Jarvis (Cron Steward) · **Script:** `fix-hermes-cron-governance-ct188.sh`

## Mandato

Auditar, corrigir e evoluir **todos** os cronjobs Hermes e tudo o que envia mensagens Telegram — eliminar flood, completar digests diários, centralizar governança.

## Composição

| Agente | Papel na força-tarefa |
|--------|------------------------|
| **Jarvis** | **Cron Steward** — registo, política notify, digest 07:00, stand-up 2h |
| **Werner** | Infra/host crons (health, backup, AGLSRV1) — silencioso em OK |
| **Satya** | Pipeline makemoney — `[SILENT]` quando sem novidade |
| **Elon** | Research/impl LLM — alert-only |
| **Argus** | Quota LiteLLM — 1×/dia (removido watch 6h) |
| **Curator** | llm-wiki maintenance — `[SILENT]` sem lint |
| **Orion** | Media verify — alert-only |
| **Verifier** | Sem crons TG — gate via review-queue |
| **Composio** | Futuro: inbox/email (reactivar crons CEO) |

## Diagnóstico (Jul 2026 — CT188 live)

### Causas de flood identificadas

| Problema | Impacto | Acção |
|----------|---------|-------|
| `email-critico-monitor` `0,30 9-18` | **~20 msgs/dia** LLM sem tools/inbox | **Desactivado** |
| `email-digest-manha` @ 07:00 | Duplica briefing | **Desactivado** |
| `hermes-ct188-health-check` `*/30` | **~34 msgs/dia** OK | **→ 8h,20h + [SILENT]** |
| `argus-limits-watch` 6h | 5× digest igual | **Removido** |
| maintenance/backup OK diário | 2 msgs redundantes | **[SILENT] + resumo no briefing** |
| 9 bots → chat `1272190248` | Percepção de spam | **Digest único + alert-only** |
| `jarvis-standup-2h` ausente no live | Gap Verdent | **Re-aplicar setup** |

### Crons email (Jarvis) — root cause

Prompts pedem síntese de inbox mas `[SEM FERRAMENTAS]` — **impossível ler email**. Crons corriam loja (515+ execs no crítico) e geravam ruído/hallucinação.

**Reactivação:** integrar Composio/Gmail no profile `composio` ou Jarvis com tools; depois `enabled: true` no registo.

## Política de notificação (pós-fix)

```
┌─────────────────────────────────────────────────────────┐
│ 07:00  Jarvis  hermes-daily-briefing-fleet  (SEMPRE)    │
│ 07:30  Argus   quota digest compacto                    │
│ 07:15–08:15  Satya makemoney (condicional / pipeline)   │
│ */2h   Jarvis  stand-up [SILENT] se OK                  │
│ Resto  monitores → [SILENT] ou deliver:null em OK       │
│ Falha  stdout com alerta → Telegram pontual             │
└─────────────────────────────────────────────────────────┘
```

Registo canónico: `scripts/proxmox/hermes-cron-registry.yaml`

## Jarvis como gerenciador de crons

**Jarvis** é o **Cron Steward** — não executa todos os jobs, **governa** o fleet:

1. **Registo** — `hermes-cron-registry.yaml` + inventário no briefing 07:00
2. **Anti-flood** — desactiva/ajusta jobs que violam política (email sem inbox)
3. **Digest matinal** — agrega estado de **todos** os agentes + hosts
4. **Stand-up 2h** — `read_agent_context` + review-queue; `[SILENT]` se nada crítico
5. **Delegação** — crons executor vivem nos profiles (Werner/Satya/…); Jarvis não reimplementa
6. **Host crons** — Werner supervisiona `fix-hermes-cron-perms`, disk cleanup; Jarvis vê falhas no briefing

Skill: `docker/hermes/profiles/jarvis/skills/cron-steward/SKILL.md`

## Aplicar no CT188

```bash
cd /mnt/overpower/apps/dev/agl/agl-hostman
git pull
bash scripts/proxmox/fix-hermes-cron-governance-ct188.sh
```

Validar:

```bash
python3 -c "import json;d=json.load(open('/opt/agl-hermes/data/cron/jobs.json')); print([(j['name'],j.get('enabled')) for j in d['jobs']])"
docker exec agl-hermes-jarvis hermes cron list
```

## Checklist pós-deploy

- [ ] Email crons `enabled: false`
- [ ] Briefing 07:00 inclui fleet + falhas + backup + pipeline
- [ ] Health check silencioso em OK (test: `hermes cron run hermes-ct188-health-check`)
- [ ] `argus-limits-watch` ausente
- [ ] `jarvis-standup-2h` presente
- [ ] ≤ 5 mensagens Telegram na janela 07:00–08:30 (dia normal)

## Entregáveis repo

| Ficheiro | Função |
|----------|--------|
| `docs/HERMES-CRON-TASK-FORCE.md` | Este documento |
| `scripts/proxmox/hermes-cron-registry.yaml` | Registo + política notify |
| `scripts/proxmox/fix-hermes-cron-governance-ct188.sh` | Orquestrador deploy |
| `scripts/monitoring/hermes-notify-lib.sh` | Helper `[SILENT]` |
| `scripts/monitoring/hermes-ct188-daily-briefing-fleet.sh` | Digest consolidado |

## Próximos passos

1. Integrar email real via **Composio** → reactivar digest manhã/noite
2. Consolidar makemoney 07:15–08:15 num único bloco no briefing (fase 2)
3. Versionar snapshots `jobs.json` (gitignored secrets) para diff
4. Dashboard Minions: painel crons fleet

---

*Wiki:* [[Hermes — Operações CT188]] · [[Hermes — Cron Steward]]
