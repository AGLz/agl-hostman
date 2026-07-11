# Spike — Hermes multi-gateway (profiles + routing)

> **Estado:** planeamento · **CT:** 188 · **Bloqueio upstream:** [PR #25660](https://github.com/NousResearch/hermes-agent/pull/25660)  
> **Relacionado:** [`HERMES-AGENCY-AGENTS.md`](HERMES-AGENCY-AGENTS.md) · [`AGLZ-HERMES-ONLY-AGENCY.md`](AGLZ-HERMES-ONLY-AGENCY.md) · `docker/hermes/config.aglz-multi-agent.yaml.example`  
> **Wiki:** [[Hermes — Operações CT188]]

## Objetivo

Validar se podemos consolidar **9 processos `gateway run`** (9 contentores ou 9 units systemd) num **único gateway multi-agent**, mantendo:

- 9 **profiles** (`SOUL.md`, skills, crons, Honcho peer)
- 8 **bots Telegram** públicos + Verifier interno
- Hierarquia **Verdent Manager** (Jarvis → `delegate_task` → Verifier → review-queue)
- Hub HTTP Jarvis (`:8642`, Mission Control, Minions)

Este spike **não** substitui a migração Docker → nativo; são caminhos complementares. O ganho de RAM relevante para “menos processos” vem do **multi-gateway upstream**, não de tirar Docker sozinho.

---

## Situação actual (baseline Jul 2026)

| Camada | Hoje | Notas |
|--------|------|-------|
| Organização | 9 profiles em `/opt/agl-hermes/` | Jarvis em `data/`, resto em `profiles/<id>/` |
| Runtime | 9× `hermes gateway run` | 1 bot Telegram = 1 processo (Hermes 0.14.x) |
| Empacotamento | Docker-in-LXC CT188 | Alternativa: systemd nativo (mesmos 9 processos) |
| Hierarquia | Lógica (SOUL, tools, queue) | **Não** depende do número de gateways |

**RAM stack Hermes (docker stats, Jul 2026):** ~2.7 GiB nos 12 contentores agency (9 gateways + minions + claw3d).

---

## Modelo alvo (quando PR #25660 mergear)

Config de referência no repo: `docker/hermes/config.aglz-multi-agent.yaml.example`

```yaml
default_agent: jarvis

agents:
  jarvis:
    home_dir: profiles/jarvis   # ou data/ no CT188
  elon:
    home_dir: profiles/elon
  # …

routes:
  - match: { platform: telegram, account: default }
    agent: jarvis
  - match: { platform: telegram, account: elon }
    agent: elon
  # …
```

Um processo, vários `home_dir`, routing por conta Telegram.

---

## Fases do spike

### Fase 0 — Pré-requisitos (antes de tocar produção)

- [ ] Confirmar merge/release Hermes com multi-bot no mesmo gateway (PR #25660 ou tag documentada).
- [ ] Ler changelog upstream: breaking changes em `config.yaml`, Telegram accounts, crons.
- [ ] Fixar versão Hermes no spike (ex. `hermes-agent==0.15.x`).
- [ ] Backup CT188: `data/`, `profiles/*`, tokens `.env`, `docker-compose` actual.
- [ ] Janela de rollback: manter compose 9-way parado 48h (não `docker compose down -v`).

### Fase 1 — PoC quartet (4 profiles, 4 bots, 1 gateway)

**Âmbito:** jarvis, elon, satya, werner — menor blast radius.

| # | Teste | Comando / acção | Pass? |
|---|-------|-----------------|-------|
| 1.1 | Gateway arranca com multi-agent config | `hermes gateway run` + config derivado do `.example` | |
| 1.2 | 4 bots Telegram respondem na persona certa | Mensagem de teste em cada @hermes_jarvis_h_* | |
| 1.3 | `default_agent` é jarvis | Mensagem ambígua / routing default | |
| 1.4 | API `:8642/health` | `curl -sf http://127.0.0.1:8642/health` | |
| 1.5 | `delegate_task` Jarvis → Satya | Prompt CEO com tarefa técnica mínima | |
| 1.6 | `read_agent_context` pós-delegação | Jarvis stand-up ou prompt manual | |
| 1.7 | Cron quartet isolado por profile | Verificar job no `home_dir` correcto (ex. Werner) | |
| 1.8 | Honcho peers distintos | Escrever memória em elon; jarvis não “vê” como própria | |
| 1.9 | LiteLLM + modelos zero-OR | Smoke `agl-primary-zai-glm-flash` / fallbacks | |
| 1.10 | Sem `Conflict: terminated by other getUpdates` | Restart gateway; logs 15 min sem duplicate polling | |

**Critério de saída Fase 1:** 10/10 PASS em ambiente de teste (branch CT188 ou contentor `hermes-poc-multi`).

### Fase 2 — Extensão agência completa (9 agents)

Adicionar: curator, orion, argus, verifier, composio.

| # | Teste | Pass? |
|---|-------|-------|
| 2.1 | 8 bots Telegram + Verifier só interno | |
| 2.2 | Curator cron `curator-maintenance` no profile curator | |
| 2.3 | Orion cron media (se activo) no profile orion | |
| 2.4 | Argus FinOps / gate quota LiteLLM | |
| 2.5 | Composio MCP / acções SaaS | |
| 2.6 | Verifier via `delegate_task` + `verifier_verdict` na review-queue | |
| 2.7 | `jarvis-standup-2h` lê contexto dos 9 peers | |
| 2.8 | Minions KanBan + `HERMES_HOME` jarvis | |
| 2.9 | Claw3D adapter (`:18789`) com gateway único | |
| 2.10 | Langfuse traces por agente (labels distintos) | |

### Fase 3 — Recursos e operação

| Métrica | Baseline (9 gateways) | Alvo multi-gateway | Medido |
|---------|----------------------|-------------------|--------|
| RAM processo(s) Hermes | ~2.7 GiB (12 ctr) | < ~1.5 GiB (estimativa) | |
| Processos `gateway run` | 9 | 1 | |
| Tempo cold start | ~90s health | < 60s | |
| Disco imagens Docker | ~7.8 GB | N/A se nativo | |

- [ ] `systemd` unit única `hermes-gateway.service` (se nativo) ou 1 contentor agency.
- [ ] Documentar rollback: `systemctl stop hermes-gateway` + `docker compose up -d` (9-way).
- [ ] Actualizar `scripts/proxmox/smoke-hermes-aglz-quartet.sh` para modo multi-gateway.

---

## Checklist hierarquia Verdent (não regressão)

Estes comportamentos **devem** manter-se independentemente de 1 ou 9 gateways:

- [ ] Jarvis **não executa** código directamente — delega (`SOUL.md` Manager).
- [ ] Toda delegação relevante entra na **review-queue** com `acceptance_criteria`.
- [ ] Verifier emite PASS/FAIL antes de Jarvis declarar `done`.
- [ ] Curator/Orion **não** substituem quartet por omissão em `delegate_task` CEO.
- [ ] Werner mantém domínio infra (Proxmox, LiteLLM, rede).
- [ ] Skills partilhadas (`llm-wiki`, `review-queue`, `strategic-debate`) resolvem no `home_dir` correcto.

---

## Riscos conhecidos

| Risco | Severidade | Mitigação |
|-------|------------|-----------|
| Crash do processo único derruba todos os bots | Alta | Healthcheck agressivo; `Restart=always`; rollback compose 9-way |
| Crons de agentes A correm no contexto de B | Alta | Fase 1.7 + inspecção `cron/jobs.json` por `home_dir` |
| Conflito Telegram `getUpdates` na migração | Média | Parar 9 gateways antes de subir 1; tokens únicos |
| Regressão Honcho (peer errado) | Média | Teste 1.8 por agente |
| PR #25660 atrasada / API instável | — | **Não** cortar produção; optimizar Docker (prune cache) entretanto |

---

## Rollback

```bash
# CT188 — ordem sugerida
systemctl stop hermes-gateway 2>/dev/null || true
docker stop agl-hermes-multi-poc 2>/dev/null || true
cd /opt/agl-hermes
docker compose -f docker-compose.aglz-quartet.ct188.yml up -d
bash scripts/proxmox/smoke-hermes-aglz-quartet.sh
```

Manter `docker-compose.aglz-quartet.ct188.yml` e profiles intactos até 1 semana estável em multi-gateway.

---

## Decisão go/no-go (após Fase 2)

| Resultado | Acção |
|-----------|--------|
| **GO** — checklist ≥ 95% PASS, RAM ↓ mensurável | Cutover produção; desactivar 8 contentores gateway; manter minions/langfuse como hoje |
| **GO híbrido** — quartet OK, extensão falha parcial | Manter curator/orion/argus em gateway dedicado até upstream fix |
| **NO-GO** — crons ou delegate quebrados | Reverter 9-way; abrir issue upstream com logs; considerar só nativo 9× systemd |

---

## Entregáveis deste spike

| Artefacto | Estado |
|-----------|--------|
| Este documento | ✅ |
| Script PoC `scripts/proxmox/poc-hermes-multi-gateway-ct188.sh` | Pendente (após merge PR) |
| `config.aglz-multi-agent.ct188.yaml` (produção) | Pendente |
| Actualização `HERMES-AGENCY-AGENTS.md` | Pendente pós-PoC |
| Entrada wiki [[Hermes — Multi-Gateway PoC]] | Pendente |

---

## Referências

- [PR #25660 — multi-bot single gateway](https://github.com/NousResearch/hermes-agent/pull/25660)
- [Issue #25698 — A2A entre profiles](https://github.com/NousResearch/hermes-agent/issues/25698)
- `docker/hermes/config.aglz-multi-agent.yaml.example`
- `docker/hermes/docker-compose.aglz-quartet.ct188.yml`
- Research Docker → nativo (sessão Jul 2026): ganho infra ~0.5–1 GiB; ganho processos requer este spike.

---

*Última actualização: 2026-07-09 · Owner: força-tarefa Hermes CT188*
