# Hermes Agency — Agentes (Jarvis · Quartet · Curator · Orion)

> **CT188** · LiteLLM `http://100.125.249.8:4000` · Honcho `aglz-agency`  
> Complementa [`AGLZ-HERMES-ONLY-AGENCY.md`](AGLZ-HERMES-ONLY-AGENCY.md) (quartet executivo).

## Mapa de agentes

| ID            | Nome        | Grupo          | Contentor                | Telegram                     | Domínio                          |
| ------------- | ----------- | -------------- | ------------------------ | ---------------------------- | -------------------------------- |
| `jarvis`      | Jarvis      | Executive      | `agl-hermes-jarvis`      | @hermes_jarvis_h_bot         | CEO, delegação, crons gerais     |
| `elon`        | Elon        | Executive      | `agl-hermes-elon`        | @hermes_jarvis_h_elon_bot    | Produto, pesquisa                |
| `satya`       | Satya       | Executive      | `agl-hermes-satya`       | @hermes_jarvis_h_satya_bot   | Entrega, código                  |
| `werner`      | Werner      | Infrastructure | `agl-hermes-werner`      | @hermes_jarvis_h_werner_bot  | Proxmox, LiteLLM, rede           |
| **`curator`** | **Curator** | **Knowledge**  | **`agl-hermes-curator`** | @hermes_jarvis_h_curator_bot | **llm-wiki** lint/ingest (todos) |
| **`orion`**   | **Orion**   | **Media**      | **`agl-hermes-orion`**   | @hermes_jarvis_h_orion_bot   | **Media \*arr** / media-grabber  |

UI Laravel: `HermesAgentCatalog` inclui os seis perfis.

---

## Gateway: um contentor = um gateway (não “presos” ao Jarvis)

Hermes **0.14.x** não suporta vários bots Telegram no **mesmo** processo gateway ([PR #25660](https://github.com/NousResearch/hermes-agent/pull/25660)). Por isso **cada agente** tem:

- contentor Docker próprio (`agl-hermes-<agente>`)
- comando `gateway run` (processo Hermes independente)
- volume `profiles/<agente>` → `/opt/data` (config, SOUL, crons, memória local)
- bot Telegram próprio (`TELEGRAM_BOT_TOKEN` no `.env` do perfil)

**Curator e Orion não correm “dentro” do Jarvis** — têm gateway próprio como Elon/Satya/Werner. A diferença prática face ao quartet original:

| Aspecto | Quartet (Jarvis…Werner) | Curator / Orion (novos) |
| ------- | ------------------------ | ------------------------ |
| Contentor + gateway | ✅ desde `configure-ct188-hermes-quartet.sh` | ✅ desde `configure-hermes-curator-orion-ct188.sh` |
| HTTP API `:8642` exposta | **Só Jarvis** (Mission Control, Claw3D, minions) | Não — Telegram + crons internos |
| Dashboard `:9119` | Jarvis | Não |
| Crons | Jarvis: crons agência; Werner/…: alguns dedicados | Crons no **próprio** perfil (`profiles/curator/cron/`, `profiles/orion/cron/`) |
| `delegate_task` | Jarvis delega para Elon/Satya/Werner | Curator/Orion **não** entram no trio CEO por omissão |
| Bootstrap | Maduro, documentado em `AGLZ-HERMES-ONLY-AGENCY.md` | Perfil + compose adicionados depois; smoke Telegram por vezes `disconnected` até tokens/restart |

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
bash scripts/proxmox/fix-hermes-quartet-models-ct188.sh --free-tier
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

## Docker Compose

Serviços em `docker/hermes/docker-compose.aglz-quartet.ct188.yml`:

- `hermes-curator` → `CURATOR_DATA_DIR=./profiles/curator`
- `hermes-orion` → `ORION_DATA_DIR=./profiles/orion`

Mesma imagem `agl-hermes-agency` que o quartet.

---

## Modelos (quota esgotada)

Perfil **`--free-tier`** (recomendado quando OpenAI/Z.AI paid falham):

| Agente          | Primário      | Fallback          |
| --------------- | ------------- | ----------------- |
| Jarvis          | zai-glm-flash | agl-primary-vm110 |
| Quartet         | glm-4.7-flash | agl-primary-vm110 |
| Curator / Orion | glm-4.7-flash | agl-primary-vm110 |

```bash
bash scripts/proxmox/fix-hermes-quartet-models-ct188.sh --free-tier
```

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
