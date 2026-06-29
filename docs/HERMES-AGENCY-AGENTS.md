# Hermes Agency — Agentes (Jarvis · Quartet · Curator · Orion · Argus)

> **CT188** · LiteLLM `http://100.125.249.8:4000` · Honcho `aglz-agency`  
> Complementa [`AGLZ-HERMES-ONLY-AGENCY.md`](AGLZ-HERMES-ONLY-AGENCY.md) (quartet executivo).

## Mapa de agentes

| ID            | Nome        | Grupo          | Contentor                | Telegram                     | Domínio                             |
| ------------- | ----------- | -------------- | ------------------------ | ---------------------------- | ----------------------------------- |
| `jarvis`      | Jarvis      | Executive      | `agl-hermes-jarvis`      | @hermes_jarvis_h_bot         | CEO, delegação, crons gerais        |
| `elon`        | Elon        | Executive      | `agl-hermes-elon`        | @hermes_jarvis_h_elon_bot    | Produto, pesquisa                   |
| `satya`       | Satya       | Executive      | `agl-hermes-satya`       | @hermes_jarvis_h_satya_bot   | Entrega, código                     |
| `werner`      | Werner      | Infrastructure | `agl-hermes-werner`      | @hermes_jarvis_h_werner_bot  | Proxmox, LiteLLM, rede              |
| **`curator`** | **Curator** | **Knowledge**  | **`agl-hermes-curator`** | @hermes_jarvis_h_curator_bot | **llm-wiki** lint/ingest (todos)    |
| **`orion`**   | **Orion**   | **Media**      | **`agl-hermes-orion`**   | @hermes_jarvis_h_orion_bot   | **Media \*arr** / media-grabber     |
| **`argus`**   | **Argus**   | **FinOps**     | **`agl-hermes-argus`**   | @hermes_jarvis_h_argus_bot   | **Limites/quota LLM**, gate LiteLLM |
| **`verifier`** | **Verifier** | **Quality**  | **`agl-hermes-verifier`** | — (interno)                | **Gate QA PASS/FAIL** vs acceptance criteria |

UI Laravel: `HermesAgentCatalog` inclui os oito perfis.

> **Modelo operacional:** o Jarvis opera como **Manager** (modelo [Verdent](https://docs.verdent.ai/verdent-manager/core-features/manager)) — ver secção [Modelo Manager (Verdent)](#modelo-manager-verdent) abaixo. Não é executor: decompõe, delega e verifica via Verifier.

---

## Gateway: um contentor = um gateway (não “presos” ao Jarvis)

Hermes **0.14.x** não suporta vários bots Telegram no **mesmo** processo gateway ([PR #25660](https://github.com/NousResearch/hermes-agent/pull/25660)). Por isso **cada agente** tem:

- contentor Docker próprio (`agl-hermes-<agente>`)
- comando `gateway run` (processo Hermes independente)
- volume `profiles/<agente>` → `/opt/data` (config, SOUL, crons, memória local)
- bot Telegram próprio (`TELEGRAM_BOT_TOKEN` no `.env` do perfil)

**Curator e Orion não correm “dentro” do Jarvis** — têm gateway próprio como Elon/Satya/Werner. A diferença prática face ao quartet original:

| Aspecto                  | Quartet (Jarvis…Werner)                             | Curator / Orion (novos)                                                                         |
| ------------------------ | --------------------------------------------------- | ----------------------------------------------------------------------------------------------- |
| Contentor + gateway      | ✅ desde `configure-ct188-hermes-quartet.sh`        | ✅ desde `configure-hermes-curator-orion-ct188.sh`                                              |
| HTTP API `:8642` exposta | **Só Jarvis** (Mission Control, Claw3D, minions)    | Não — Telegram + crons internos                                                                 |
| Dashboard `:9119`        | Jarvis                                              | Não                                                                                             |
| Crons                    | Jarvis: crons agência; Werner/…: alguns dedicados   | Crons no **próprio** perfil (`profiles/curator/cron/`, `profiles/orion/cron/`)                  |
| `delegate_task`          | Jarvis delega para Elon/Satya/Werner                | Curator/Orion **não** entram no trio CEO por omissão                                            |
| Bootstrap                | Maduro, documentado em `AGLZ-HERMES-ONLY-AGENCY.md` | Perfil + compose adicionados depois; smoke Telegram por vezes `disconnected` até tokens/restart |

**Hub operacional:** Jarvis continua o **ponto de entrada HTTP** (`8642`) e orquestração CEO — não substitui o gateway dos outros contentores.

### Criar novos agentes (recomendado)

1. **Repo:** `docker/hermes/profiles/<id>/` — `SOUL.md`, `config.yaml.example`, skills, `SECOND-BRAIN.md` (symlink ou referência).
2. **Compose:** copiar bloco `hermes-satya` em `docker-compose.aglz-quartet.ct188.yml` → `hermes-<id>` (sem `ports` salvo API explícita).
3. **Scripts:** `bootstrap-hermes-<id>-profile-ct188.sh` + `setup-hermes-<id>-crons-ct188.sh` se houver crons.
4. **Telegram:** `TELEGRAM_TOKEN_<ID>` em tokens env; bot dedicado (1 token = 1 gateway).
5. **Second brain:** adicionar `<id>` ao array `AGENTS` em `fix-hermes-llm-wiki-secondbrain-ct188.sh`.
6. **Deploy CT188:** `configure-hermes-curator-orion-ct188.sh` como modelo; `docker compose up -d hermes-<id>`.
7. **UI:** registar em `HermesAgentCatalog` (Laravel).

Evitar crons só no Jarvis para agentes com contentor dedicado — o scheduler lê `cron/jobs.json` do volume montado em `/opt/data` **desse** contentor.

---

## Segundo cérebro (llm-wiki) — todos os agentes

Protocolo partilhado: `docker/hermes/profiles/SECOND-BRAIN.md`

| Script                                                     | Função                                               |
| ---------------------------------------------------------- | ---------------------------------------------------- |
| `scripts/proxmox/fix-hermes-llm-wiki-secondbrain-ct188.sh` | Skill + `WIKI_PATH` nos 6 perfis                     |
| `scripts/proxmox/fix-curator-llm-wiki-skill-ct188.sh`      | Cron curator-maintenance (chamado pelo script acima) |

```bash
bash scripts/proxmox/fix-hermes-llm-wiki-secondbrain-ct188.sh /mnt/overpower/apps/dev/agl/agl-hostman
bash scripts/proxmox/setup-hermes-wiki-git-ct188.sh --test   # git safe + credentials nos perfis
bash scripts/proxmox/setup-hermes-wiki-git-ct188.sh --push     # push origin main (requer gh root)
bash scripts/proxmox/smoke-hermes-aglz-quartet.sh
```

---

## Modelo Manager (Verdent)

Desde 2026-06-29 o Jarvis segue o modo de operação dos "Managers" do [Verdent](https://docs.verdent.ai/verdent-manager/core-features/manager): **gerencial, não executor**. Wiki: [[Verdent Manager]] · [[Hermes — Operações CT188]].

### Loop Plan → Execute → Verify → Deliver

1. **Plan/Align** — clarifica (perguntas objetivas) e decompõe em fases → subtasks → dependências → **acceptance criteria**.
2. **Execute** — `delegate_task` ao especialista; paraleliza ortogonais (`max_concurrent_children=3`); `read_agent_context` antes de re-delegar.
3. **Verify** — nada é "feito" sem veredito do **Verifier** (PASS/FAIL vs critérios).
4. **Deliver** — sintetiza, atualiza review-queue, traz ao humano só o que precisa de decisão.

### Review-Queue (coluna "To Review")

- **Path (rw via `LLM_WIKI_DIR`):** `/opt/llm-wiki/raw/hermes/review-queue/queue.json`
  - O mount `/mnt/overpower` é **NFS root-squashed** (nobody:nogroup) → não escrevível pelos agentes; por isso a fila vive no vault `llm-wiki` (rw).
- **Helper:** `scripts/proxmox/hermes-review-queue.sh` — `add <id> <agent> "<goal>" "<crit1;crit2>"` · `set-status <id> <status>` · `verdict <id> PASS|FAIL "<evidência>"` · `list [status]`.
- **Estados:** `planned → in_progress → to_review → verifying → done | blocked | failed`.
- **Fluxo:** Jarvis `add` (criteria) → delega → agente `set-status` → Verifier `verdict` → Jarvis fecha (`done`) ou re-delega (`failed`).

### Stand-up cron 2h (acompanhamento)

`jarvis-standup-2h` (`0 */2 * * *`, LLM no Jarvis): varre `read_agent_context` de cada agente + lê a review-queue, resume progresso/bloqueios em PT e surfaca só pendências de decisão. Setup: `scripts/proxmox/setup-hermes-jarvis-standup-cron-ct188.sh`.

### Debate estratégico (Opção B — skill, no-logging)

Para decisões de alto impacto na fase **Plan**, o Jarvis invoca `scripts/hermes/strategic-debate.sh` (instalado em `/opt/data/scripts/` no CT188):

| Persona  | Modelo                | Papel |
| -------- | --------------------- | ----- |
| Advocate | `or-qwen3-coder-free` | Defende direcção / oportunidade |
| Skeptic  | `or-hermes-free`      | Riscos, premissas, alternativas |
| Síntese  | `or-qwen3-next-free`  | Recomendação + decisões humanas |

- **Sem contentores novos** — debate via LiteLLM, contexto passado explicitamente pelo Jarvis (pode incluir wiki/pipeline; modelos no-logging).
- **Bloqueio:** `or-owl-alpha` / `or-nemotron-*` / Sonoma / Horizon (logam) — script recusa salvo `--allow-logging`.
- Setup CT188: `scripts/proxmox/setup-hermes-jarvis-strategic-debate-ct188.sh`
- Skill: `docker/hermes/profiles/jarvis/skills/strategic-debate/SKILL.md`
- Wiki: [[Hermes — Strategic Debate (Jarvis)]]

### Migração de crons executor (Jarvis 16 → 5)

Auditoria 2026-06-29: Jarvis estava sobrecarregado como executor (e vários `makemoney-*` partidos). `scripts/proxmox/migrate-hermes-jarvis-crons-ct188.sh` move (com fix de scripts):

| Destino | Crons |
| ------- | ----- |
| **Werner** | daily-maintenance, daily-backup, health-check |
| **Elon** | AI Opportunity Research, AI Implementation Planning Sprint |
| **Satya** | 6× makemoney-* (sync-crons, deep-dive, wiki-feed, generate-dossiers, pipeline-report, git-sync) |
| **Jarvis (mantém)** | daily-briefing, 3× email, jarvis-standup-2h |

---

## Verifier — QA Gate

### Missão

Gate de qualidade da agência (equivalente ao `@Verifier` do Verdent): valida entregas **contra os acceptance criteria** e devolve veredito **PASS** (com evidência) ou **FAIL** (lista do que falhou + sugestão). **Não implementa correções** (isso é Satya/Werner/etc.) **nem decide prioridades** (Jarvis).

### Ficheiros (repo)

| Path                                                        | Descrição          |
| ----------------------------------------------------------- | ------------------ |
| `docker/hermes/profiles/verifier/SOUL.md`                   | Persona            |
| `scripts/proxmox/bootstrap-hermes-verifier-profile-ct188.sh`| Bootstrap CT188    |
| `scripts/proxmox/hermes-review-queue.sh`                    | Helper review-queue |

### Modelo

`or-nemotron-ultra-free` (reasoning) · fallback `or-owl-alpha` · aux `groq-llama-31-8b`. Em modo privacidade (`--secure`), usa `agl-sensitive` local como os restantes (ver secção Modelos abaixo).

### Deploy

```bash
bash scripts/proxmox/bootstrap-hermes-verifier-profile-ct188.sh /mnt/overpower/apps/dev/agl/agl-hostman
docker compose -f docker-compose.aglz-quartet.yml up -d hermes-verifier
```

Sem bot Telegram (agente interno; interage via `delegate_task` do Jarvis + review-queue).

---

## Curator — KB Steward

### Missão

Manter o vault **llm-wiki** curado: ingest de `/opt/data/wiki-ingest/`, lint, `index.md`, `log.md`, backups.

### Ficheiros (repo)

| Path                                                        | Descrição           |
| ----------------------------------------------------------- | ------------------- |
| `docker/hermes/profiles/curator/SOUL.md`                    | Persona             |
| `docker/hermes/profiles/curator/config.yaml.example`        | Template config     |
| `scripts/proxmox/bootstrap-hermes-curator-profile-ct188.sh` | Bootstrap CT188     |
| `scripts/proxmox/fix-curator-llm-wiki-skill-ct188.sh`       | Skill + cron prompt |

### Runtime (CT188)

```
/opt/agl-hermes/profiles/curator/
├── config.yaml
├── SOUL.md
├── .env                    # WIKI_PATH=/opt/llm-wiki/wiki
├── skills/research/llm-wiki → symlink ou cópia
└── cron/jobs.json          # curator-maintenance (2h) — migrar do Jarvis
```

**Mount:** `/opt/llm-wiki` (**rw**) · `/opt/agl-hostman` (ro)

### Cron `curator-maintenance`

- Skill **llm-wiki** (não CLI shell `llm-wiki`)
- Resposta `[SILENT]` se nada a fazer
- Job ID legado: `e54ffa964a1f` (Jarvis `data/cron/jobs.json`) — migrar para `profiles/curator/cron/`

### Deploy

```bash
# No CT188 (após quartet)
bash scripts/proxmox/configure-hermes-curator-orion-ct188.sh /mnt/overpower/apps/dev/agl/agl-hostman [/root/.aglz-telegram-tokens.env]
bash scripts/proxmox/fix-curator-llm-wiki-skill-ct188.sh
bash scripts/proxmox/fix-hermes-quartet-models-ct188.sh --no-logging
```

Tokens opcionais: `TELEGRAM_TOKEN_CURATOR=...` no ficheiro tokens.

---

## Orion — VP Media (\*arr)

### Missão

Operador do stack **media-grabber** (conceito Mission Control §5.5): modo grabs-only, verificação freeze, filas Radarr/Sonarr, preparação unfreeze.

**Nota:** o repo `agl-media-grabber` ainda **não existe** — Orion herda `docs/MEDIA-ARR-*` + `scripts/media/`.

### Ficheiros (repo)

| Path                                                      | Descrição                  |
| --------------------------------------------------------- | -------------------------- |
| `docker/hermes/profiles/orion/SOUL.md`                    | Persona                    |
| `docker/hermes/profiles/orion/config.yaml.example`        | Template                   |
| `docker/hermes/profiles/orion/skills/agl-media/SKILL.md`  | Skill media                |
| `scripts/proxmox/bootstrap-hermes-orion-profile-ct188.sh` | Bootstrap                  |
| `scripts/proxmox/setup-hermes-orion-media-crons-ct188.sh` | Crons diário/semanal       |
| `scripts/monitoring/hermes-orion-media-daily.sh`          | `arr-freeze --verify-only` |

### Stack AGLSR1 (referência)

| CT  | Serviço                        |
| --- | ------------------------------ |
| 172 | Prowlarr                       |
| 123 | Radarr                         |
| 124 | Sonarr                         |
| 121 | qBittorrent                    |
| 144 | Autobrr (parado em grabs-only) |

**Modo actual:** grabs ON · downloads OFF — [`MEDIA-ARR-MAINTENANCE.md`](MEDIA-ARR-MAINTENANCE.md)

### Crons Orion

| Job                         | Schedule  | Acção                  |
| --------------------------- | --------- | ---------------------- |
| `orion-media-daily-verify`  | 08:00     | Script `--verify-only` |
| `orion-media-weekly-status` | Seg 09:00 | Relatório semanal      |

### Deploy

```bash
bash scripts/proxmox/configure-hermes-curator-orion-ct188.sh /mnt/overpower/apps/dev/agl/agl-hostman
# Token opcional: TELEGRAM_TOKEN_ORION=...
docker compose -f docker-compose.aglz-quartet.yml up -d hermes-orion
```

---

## Argus — Quota Steward & LLM FinOps

### Missão

Manter o **fluxo contínuo de execuções** dos harnesses AGL (Cursor, Claude Code ±OpenClaw, Codex, Ruflo, Hermes, Verdent) vivo e barato, vigiando limites/uso/saúde de todos os providers/models e sendo o **gate** das mudanças no LiteLLM. Detentor da skill `agl-llm-monitor`. Reporta ao **Jarvis**, canal Telegram direto com o operador, e **delega ao Werner** a aplicação física no LiteLLM CT186.

### Ficheiros (repo)

| Path                                                        | Descrição                          |
| ----------------------------------------------------------- | ---------------------------------- |
| `docker/hermes/profiles/argus/SOUL.md`                      | Persona                            |
| `docker/hermes/profiles/argus/config.yaml.example`          | Template (free-tier + bloco argus) |
| `.claude/skills/agl-llm-monitor/SKILL.md`                   | Skill cross-harness (contrato+CLI) |
| `scripts/proxmox/bootstrap-hermes-argus-profile-ct188.sh`   | Bootstrap                          |
| `scripts/proxmox/setup-hermes-argus-monitor-crons-ct188.sh` | Crons digest/watch                 |
| `scripts/monitoring/hermes-argus-quota-digest.sh`           | Digest leve (no_agent)             |

### Modelo

Free-tier por defeito (a monitorização não deve queimar quota paga): `glm-4.7-flash` · fallback `agl-primary-vm110` · aux `groq-llama-31-8b`. **Nota:** free-tier também tem limites de uso (req/dia, rpm/tpm) e **janela de contexto menor** — Argus monitoriza estes limites e não encaminha tarefas long-context para um free insuficiente.

### Gate de mudança no LiteLLM (2 tiers)

- **Tier A — automático:** failover seguro para modelos free quando um provider pago falha (estilo `--apply-hermes`). Argus aplica e **notifica**. Ressalva: free-tier também tem limites (uso + contexto menor) — se não servir a tarefa/ferramenta, Argus escala em vez de insistir.
- **Tier B — requer OK humano via Telegram:** reescrita estrutural do `config.yaml`. Argus prepara diff + justificação, pede o OK no Telegram, e só depois **delega ao Werner** o pipeline com guardrails (backup `.bak` → validação → deploy → smoke → rollback).

### Crons Argus

| Job                        | Schedule  | Acção                               |
| -------------------------- | --------- | ----------------------------------- |
| `argus-quota-digest-daily` | 07:30     | Digest diário de limites (Telegram) |
| `argus-limits-watch`       | a cada 6h | Verificação 5h/semanal/mensal/RL    |

### Deploy

```bash
# No CT188 (após quartet + curator/orion)
bash scripts/proxmox/configure-hermes-argus-ct188.sh /mnt/overpower/apps/dev/agl/agl-hostman [/root/.aglz-telegram-tokens.env]
# ou manual:
bash scripts/proxmox/bootstrap-hermes-argus-profile-ct188.sh /mnt/overpower/apps/dev/agl/agl-hostman
bash scripts/proxmox/fix-hermes-llm-wiki-secondbrain-ct188.sh /mnt/overpower/apps/dev/agl/agl-hostman
docker compose -f docker-compose.aglz-quartet.yml up -d hermes-argus
```

Token: `TELEGRAM_TOKEN_ARGUS=...` em `/root/.aglz-telegram-tokens.env` no CT188; depois:

```bash
bash scripts/proxmox/setup-hermes-argus-telegram-ct188.sh /root/.aglz-telegram-tokens.env
```

Bot sugerido: `@hermes_jarvis_h_argus_bot` (criar no BotFather antes do script acima).

---

## Docker Compose

Serviços em `docker/hermes/docker-compose.aglz-quartet.ct188.yml`:

- `hermes-curator` → `CURATOR_DATA_DIR=./profiles/curator`
- `hermes-orion` → `ORION_DATA_DIR=./profiles/orion`
- `hermes-argus` → `ARGUS_DATA_DIR=./profiles/argus`
- `hermes-verifier` → `VERIFIER_DATA_DIR=./profiles/verifier`

Mesma imagem `agl-hermes-agency` que o quartet.

---

## Modelos (swarm — política privacidade 2026-06-29)

**Distinção-chave:** o problema não é "free", é **logging**. No OpenRouter, `provider.data_collection=deny`
faz o request só ser roteado para providers que **NÃO treinam/retêm** prompts (ex. Venice ZDR). Logo
há free models **seguros** para dados AGL — só os **stealth que logam** (`or-owl-alpha`, `or-nemotron-*`)
ficam restritos. Todos os agentes leem o **segundo cérebro** (`llm-wiki`: infra+agência) e os crons leem
**leads/emails/LinkedIn**, por isso o default usa só modelos no-logging.

### Tiers de privacidade

| Tier | Quando | Modelos |
| ---- | ------ | ------- |
| **`--no-logging`** (default) | swarm geral, paralelismo, dados AGL | free **no-logging** (`data_collection=deny`) + fallback local |
| **`--local`** | soberania máxima / OpenRouter indisponível | 100% on-prem (`agl-sensitive` → família `agl-primary`) |
| **`--logging-public`** | SÓ tarefas públicas, sem dados AGL | `or-owl-alpha`/`or-nemotron-*` (LOGAM) |

Swarm **`--no-logging`** (default; seguro p/ dados AGL; bom p/ parallel tool calling):

| Agente | Primário (no-logging) | Fallback |
| ------ | --------------------- | -------- |
| Jarvis, Curator | `or-qwen3-coder-free` (Qwen3 Coder 480B) | `or-hermes-free` → `or-qwen3-next-free` → `or-llama-3.3-70b-free` → `agl-sensitive` |
| Elon, Satya, Werner, Orion | `or-qwen3-next-free` (Qwen3 Next 80B MoE) | `or-llama-3.3-70b-free` → `or-hermes-free` → `or-qwen3-coder-free` → `agl-sensitive` |
| Aux / delegation | `or-qwen3-next-free` | — |
| Crons (vault/leads/email) | `agl-sensitive` (local) | `agl-primary-vm110` |

> **No-logging free** (LiteLLM `data_policy: no-logging-data-collection-deny`): `or-qwen3-coder-free`,
> `or-qwen3-next-free`, `or-hermes-free` (Nous Hermes 3 405B), `or-llama-3.3-70b-free` — todos com
> `provider.data_collection=deny` no `extra_body`. Fallback final sempre `agl-sensitive` (local).
> **`agl-sensitive`** = VM310 local, fallback 100% local (tier de soberania).

```bash
# Default (no-logging free + fallback local)
bash scripts/proxmox/hermes-openrouter-free-ct188.sh
bash scripts/proxmox/fix-hermes-quartet-models-ct188.sh --no-logging
# 100% on-prem
bash scripts/proxmox/fix-hermes-quartet-models-ct188.sh --local
# Tarefas públicas (modelos que logam)
bash scripts/proxmox/fix-hermes-quartet-models-ct188.sh --logging-public
```

### Pré-requisito de conta OpenRouter

Para reforçar globalmente: **Privacy settings → desligar "Allow providers that may train on your data"
para free models**. Assim, mesmo sem o `data_collection=deny` por-request, o OpenRouter nunca roteia
para providers que treinam. O `data_collection=deny` no LiteLLM garante isto a nível de request.

> **AVISO:** `or-owl-alpha`/`or-nemotron-*-free` (stealth/NVIDIA) **logam prompts** — só via
> `--logging-public`, nunca com vault, agência, infra, emails ou LinkedIn no contexto.

---

## Smoke

```bash
bash scripts/proxmox/smoke-hermes-aglz-quartet.sh
docker ps --filter name=agl-hermes-curator --filter name=agl-hermes-orion
```

---

## Roadmap

| Item                                           | Estado                                                       |
| ---------------------------------------------- | ------------------------------------------------------------ |
| Curator contentor + SOUL + docs                | ✅ repo                                                      |
| Orion + skill agl-media + crons                | ✅ repo                                                      |
| Bot Telegram Curator/Orion                     | ✅ @hermes_jarvis_h_curator_bot · @hermes_jarvis_h_orion_bot |
| Migrar cron curator → `profiles/curator/cron/` | ⏳ CT188                                                     |
| Mission Control `/mission-control/media`       | 📋 Fase 4 roadmap                                            |
| Repo `agl-media-grabber`                       | 📋 externo                                                   |

---

## Referências

- [`docs/LLM-WIKI-AGENCY-INTEGRATION.md`](LLM-WIKI-AGENCY-INTEGRATION.md)
- [`docs/MEDIA-ARR-STACK-AGL.md`](MEDIA-ARR-STACK-AGL.md)
- [`ai-docs/planning/MISSION-CONTROL-ROADMAP.md`](../ai-docs/planning/MISSION-CONTROL-ROADMAP.md) §5.5 Media Grabs
