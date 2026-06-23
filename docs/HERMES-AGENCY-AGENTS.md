# Hermes Agency — Agentes (Jarvis · Quartet · Curator · Orion)

> **CT188** · LiteLLM `http://100.125.249.8:4000` · Honcho `aglz-agency`  
> Complementa [`AGLZ-HERMES-ONLY-AGENCY.md`](AGLZ-HERMES-ONLY-AGENCY.md) (quartet executivo).

## Mapa de agentes

| ID            | Nome        | Grupo          | Contentor                | Telegram                     | Domínio                         |
| ------------- | ----------- | -------------- | ------------------------ | ---------------------------- | ------------------------------- |
| `jarvis`      | Jarvis      | Executive      | `agl-hermes-jarvis`      | @hermes_jarvis_h_bot         | CEO, delegação, crons gerais    |
| `elon`        | Elon        | Executive      | `agl-hermes-elon`        | @hermes_jarvis_h_elon_bot    | Produto, pesquisa               |
| `satya`       | Satya       | Executive      | `agl-hermes-satya`       | @hermes_jarvis_h_satya_bot   | Entrega, código                 |
| `werner`      | Werner      | Infrastructure | `agl-hermes-werner`      | @hermes_jarvis_h_werner_bot  | Proxmox, LiteLLM, rede          |
| **`curator`** | **Curator** | **Knowledge**  | **`agl-hermes-curator`** | @hermes_jarvis_h_curator_bot | **llm-wiki** ingest/lint        |
| **`orion`**   | **Orion**   | **Media**      | **`agl-hermes-orion`**   | @hermes_jarvis_h_orion_bot   | **Media \*arr** / media-grabber |

UI Laravel: `HermesAgentCatalog` inclui os seis perfis.

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
