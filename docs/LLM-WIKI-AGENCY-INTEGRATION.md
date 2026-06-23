# LLM Wiki — integração com a AGLz Agency (Hermes)

Repositório: **[github.com/AGLz/llm-wiki](https://github.com/AGLz/llm-wiki)**  
Base de conhecimento em Markdown/Obsidian (~**120** páginas `wiki/`, ~**1470** fontes em `raw/`).

Substitui o **RAG do Archon (CT183)** para conhecimento curado. **Não** substitui Honcho nem Linear.

---

## Três camadas (não confundir)

| Sistema                                          | O quê                                               | Quem escreve                                             | Exemplo                                    |
| ------------------------------------------------ | --------------------------------------------------- | -------------------------------------------------------- | ------------------------------------------ |
| **[llm-wiki](https://github.com/AGLz/llm-wiki)** | Factos, runbooks, síntese, entidades                | Agentes mantêm `wiki/`; humanos colocam fontes em `raw/` | Página `[[Dokploy]]`, `[[Archon]]`, índice |
| **Honcho (CT192)**                               | Memória episódica, conclusões, contexto entre chats | Deriver + peers `jarvis`/`elon`/`satya`/`werner`         | "Sr.Big preferiu Tailscale em CT188"       |
| **Linear**                                       | Backlog, estados, entrega                           | Humanos + agentes via MCP/CLI                            | Issue `AGL-42` _In Progress_               |

**Archon CT183:** legado — descontinuar para a agência após cutover (Linear + llm-wiki). O script `scripts/sync-archon-kb.sh` fica obsoleto para este fluxo.

---

## Modelo llm-wiki (resumo)

```
raw/          ← fontes imutáveis (clippings, PDFs, exports)
wiki/         ← markdown interligado (agente mantém)
wiki/index.md ← catálogo (query começa aqui)
wiki/log.md   ← cronologia ingest/query/lint
AGENTS.md     ← schema e fluxos (ingest, query, lint)
```

Fluxos definidos em `AGENTS.md` do repo:

- **Ingest** — nova fonte em `raw/` → actualizar páginas + `index.md` + `log.md`
- **Query** — ler índice → páginas → responder com citações; respostas reutilizáveis viram páginas
- **Lint** — contradições, órfãos, lacunas (registar em `log.md`)

---

## Onde corre (CT188 Hermes)

Clone read-mostly no CT188, montado no contentor:

| Host (CT188)        | Contentor       | Modo                                        |
| ------------------- | --------------- | ------------------------------------------- |
| `/opt/agl-llm-wiki` | `/opt/llm-wiki` | `ro` para gateway; `rw` só se ingest activo |

```bash
# No CT188 (root)
git clone https://github.com/AGLz/llm-wiki.git /opt/agl-llm-wiki
# Ou no agldv03 (repo privado — gh auth):
gh repo clone AGLz/llm-wiki /mnt/overpower/apps/dev/agl/llm-wiki
bash /caminho/agl-hostman/scripts/proxmox/ensure-llm-wiki-ct188.sh
cd /opt/agl-hermes && docker compose -f docker-compose.aglz-quartet.yml up -d --force-recreate
```

Variável no compose: `LLM_WIKI_DIR=/opt/agl-llm-wiki` (ver `docker/hermes/docker-compose.ct188.yml`).

---

## Integração Hermes por agente

| Agente                | Uso principal do wiki                                              |
| --------------------- | ------------------------------------------------------------------ |
| **Jarvis (CEO)**      | Query estratégica — contexto AGL, decisões passadas documentadas   |
| **Elon (CPO/CRO)**    | Ingest de pesquisa, lint de domínios produto, síntese para roadmap |
| **Satya (COO)**       | Runbooks de deploy/app; infra pesada → **Werner**                  |
| **Werner (VP Infra)** | Runbooks infra, `docs/INFRA.md`, ingest pós-incidente              |

**Leitura (query):** toolset `file` — começar por `/opt/llm-wiki/wiki/index.md`.

**Escrita (ingest/lint):** clone **rw** ou branch + PR no GitHub; Satya/Elon commitam via terminal com identidade de serviço.

---

## MCP e skills (repo llm-wiki)

O próprio `llm-wiki` inclui:

| Artefacto        | Função                                    |
| ---------------- | ----------------------------------------- |
| `.mcp.json`      | MCP `filesystem` sobre `wiki/` e `raw/`   |
| `llm-wiki.skill` | Skill empacotada para agentes compatíveis |
| `scripts/`       | Automação local (search, etc.)            |

No Hermes CT188, alinhar com o mesmo padrão quando MCP estiver activo no gateway — ou usar `file` + path `/opt/llm-wiki`.

**Escala (opcional):** [qmd](https://github.com/tobi/qmd) — BM25 + vector local sobre `wiki/`; MCP qmd quando > ~200 páginas ou queries frequentes.

---

## Cursor (agl-hostman)

Integração do segundo cérebro na IDE diária:

| Artefacto                                       | Função                                                                     |
| ----------------------------------------------- | -------------------------------------------------------------------------- |
| `.cursor/mcp.json` → `llm-wiki-fs`              | MCP filesystem sobre `wiki/` e `raw/` do vault NFS                         |
| `.cursor/rules/llm-wiki-second-brain.mdc`       | Regra always-on: query `index.md` antes de implementar; ingest pós-mudança |
| `.cursor/skills/obsidian-cli/`                  | Skill project-level (sync via `sync-six-repos --repo obsidian`)            |
| `.cursor/skills/llm-wiki-ingest/`               | Export + síntese conversas Cursor → wiki                                   |
| `.cursor/commands/llm-wiki-ingest.md`           | Comando `/llm-wiki-ingest`                                                 |
| `scripts/cursor/export-cursor-sessions.py`      | Export agent-transcripts + Composer → `raw/cursor/live/`                   |
| `scripts/cursor/sync-cursor-to-wiki.sh`         | Sync incremental (hook + timer systemd)                                    |
| `scripts/cursor/propagate-cursor-wiki-sync.sh`  | Propaga timer + export para agldv03…12                                     |
| `scripts/skills/setup-obsidian-cli-llm-wiki.sh` | Verificar Obsidian CLI + vault default                                     |

**Sync conversas (paralelo Hermes Curator):** export raw automático; ingest curado via agente ou `/llm-wiki-ingest`.

```bash
bash scripts/cursor/sync-cursor-to-wiki.sh              # incremental
LLM_WIKI_GIT_COMMIT=1 bash scripts/cursor/sync-cursor-to-wiki.sh  # + commit vault
./scripts/cursor/propagate-cursor-wiki-sync.sh --host agldv-all   # todos AGLDV*
# timer: config/systemd/agl-cursor-wiki-sync.timer (install via install-cursor-wiki-sync-systemd.sh)
```

**Cutover:** servidores MCP `archon` / `archon-tailscale` removidos de `.cursor/mcp.json` — conhecimento curado via llm-wiki, não RAG Archon.

```bash
./scripts/skills/sync-six-repos.sh --repo obsidian
./scripts/skills/setup-obsidian-cli-llm-wiki.sh
./scripts/skills/verify-six-repos.sh
```

---

## Honcho vs llm-wiki (quando usar o quê)

| Pergunta                                      | Usar                                |
| --------------------------------------------- | ----------------------------------- |
| "O que está documentado sobre Dokploy?"       | **llm-wiki** → `index.md` + páginas |
| "O que combinámos na reunião de ontem?"       | **Honcho** `honcho_search`          |
| "Qual issue está bloqueada?"                  | **Linear** MCP/CLI                  |
| "Actualizar runbook após mudança CT192"       | **llm-wiki** ingest + git commit    |
| "Lembrar preferência do Sr.Big sobre modelos" | **Honcho** `honcho_conclude`        |

---

## Six Repos (vídeo Nuno Tavares)

Plano canónico: [`ai-docs/planning/SIX-REPOS-MULTI-AGENT-PLAN.md`](../ai-docs/planning/SIX-REPOS-MULTI-AGENT-PLAN.md) · wiki: [[Plano Six Repos Multi-Agente]].

| Host                | O quê                                                                                                                                                                                    |
| ------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **agldv03**         | `bash scripts/skills/sync-six-repos.sh --repo all` + `verify-six-repos.sh`                                                                                                               |
| **CT188 Hermes**    | Só **leitura** llm-wiki (`/opt/agl-llm-wiki` → `/opt/llm-wiki`); **não** instalar superpowers no contentor                                                                               |
| **aglwk45 (VM104)** | `git pull` no NFS (`/mnt/overpower/.../agl-hostman`) + `bash scripts/skills/propagate-sync-agl-hostman-wk45-qemu.sh` (robocopy `Z:` → `C:\Users\Administrator\apps\dev\agl\agl-hostman`) |

```bash
# Dev (NFS agldv03 / host actual)
bash scripts/skills/sync-six-repos.sh --repo all
bash scripts/skills/verify-six-repos.sh

# Multi-host
bash scripts/skills/propagate-six-repos.sh --host agldv03
bash scripts/skills/propagate-six-repos.sh --host ct188
bash scripts/skills/propagate-six-repos.sh --host aglwk45

# Hermes smoke (6 páginas wiki + mount Jarvis)
bash scripts/skills/smoke-hermes-six-repos.sh

# aglwk45 sem RDP (SSH AGLSRV1 → qm guest exec 104)
git -C /mnt/overpower/apps/dev/agl/agl-hostman pull --ff-only   # NFS partilhado com Z:\ na VM
bash scripts/skills/propagate-sync-agl-hostman-wk45-qemu.sh
bash scripts/skills/propagate-six-repos-wk45-qemu.sh
ssh root@100.107.113.33 'qm guest exec 104 -- powershell -NoProfile -Command "Get-Content C:/Users/Administrator/wk45-six-repos-result.txt -Tail 20"'

# Fallback manual Windows (RDP + Git Bash)
powershell -ExecutionPolicy Bypass -File scripts/skills/propagate-six-repos.ps1
```

**Verificação aglwk45 (2026-05-26):** guest sync+verify `FAIL=0`; skills em `C:\Users\Administrator\.cursor\skills\` (obsidian-cli, od-design-md, using-superpowers). WARN: obsidian CLI no PATH; clone hostman no guest pode estar desactualizado (sem `karpathy-skills.mdc` no repo local).

Critério Hermes: Jarvis lê `wiki/index.md` e as 6 páginas dos repos (Superpowers, ECC, Ruflo, Open Design, Obsidian CLI, Karpathy).

---

## Bootstrap (ordem)

1. Clone `/opt/agl-llm-wiki` no CT188
2. `bootstrap-ct188-hermes-aglz.sh` (monta volume se compose actualizado)
3. Smoke: Satya lê `wiki/index.md` e cita uma página (ex. LiteLLM/Archon)
4. Elon faz ingest de teste (fonte pequena em `raw/` → entrada em `log.md`)
5. Desactivar sync Archon para docs da agência

---

## Referências

- Plano agência: [`AGLZ-HERMES-ONLY-AGENCY.md`](AGLZ-HERMES-ONLY-AGENCY.md)
- Honcho CT192: [`HONCHO-CT192-DEDICATED-LXC.md`](HONCHO-CT192-DEDICATED-LXC.md)
- Linear: [`LINEAR-MCP-INTEGRATION.md`](LINEAR-MCP-INTEGRATION.md)
- README upstream: [AGLz/llm-wiki](https://github.com/AGLz/llm-wiki)
