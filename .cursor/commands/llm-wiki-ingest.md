---
description: Exportar conversas Cursor para llm-wiki e sintetizar decisões/runbooks (paralelo ao Hermes Curator)
---

# /llm-wiki-ingest

Sincroniza histórico Cursor → **llm-wiki** e (opcionalmente) cura conhecimento reutilizável.

## Quando usar

- Fim de sessão com decisões de infra, bugs resolvidos ou runbooks novos
- Pedido explícito para «enviar para a wiki» (como no fluxo Hermes)
- Após `/save-session` — export raw + síntese wiki

## Passo 1 — Export automático (raw)

```bash
bash scripts/cursor/sync-cursor-to-wiki.sh
```

- Saída incremental: `llm-wiki/raw/cursor/live/`
- Fila de curadoria: `raw/cursor/ingest-queue.jsonl`
- Estado: `raw/cursor/.export-state.json`
- **Não** precisa fechar o Cursor (usa `agent-transcripts` JSONL)

Variáveis úteis:

| Variável               | Default                                | Função                 |
| ---------------------- | -------------------------------------- | ---------------------- |
| `LLM_WIKI_DIR`         | `/mnt/overpower/apps/dev/agl/llm-wiki` | Vault                  |
| `CURSOR_EXPORT_FILTER` | `agl`                                  | `agl` ou `all`         |
| `AGL_HOME_SYNC_ROOT`   | `agl-home-sync` NFS                    | Transcripts espelhados |
| `LLM_WIKI_GIT_COMMIT`  | `0`                                    | `1` → commit no vault  |

Export em massa + snapshot datado:

```bash
python scripts/cursor/export-cursor-sessions.py --wiki "$LLM_WIKI_DIR" --full --snapshot --filter agl
```

## Passo 2 — Query (não inventar)

1. Ler `wiki/index.md`
2. Ler páginas ligadas à sessão
3. Consultar `raw/cursor/live/manifest.json` para sessões exportadas

## Passo 3 — Ingest curado (wiki/)

**Não** colar chats inteiros na wiki. Extrair só:

- Problemas e sintomas
- Decisões e trade-offs
- Soluções verificadas (comandos, paths, commits)
- Entidades novas (hosts, CTs, serviços)

Para cada item durável:

1. Criar/actualizar página em `wiki/` (frontmatter + wikilinks)
2. Actualizar `wiki/index.md`
3. Entrada em `wiki/log.md` — `ingest | Cursor — <tema>`

## Passo 4 — Honcho vs wiki

| Tipo                                         | Destino      |
| -------------------------------------------- | ------------ |
| Runbooks, factos, decisões                   | **llm-wiki** |
| Preferências episódicas, «Sr.Big preferiu X» | Honcho CT192 |
| Tarefas / estado de entrega                  | Linear / bd  |

## Relacionado

- Skill: `.cursor/skills/llm-wiki-ingest/SKILL.md`
- Página wiki: `[[Cursor — segundo cérebro AGL]]`
- Hermes Curator: cron `curator-maintenance` (mesmo vault, ingest de `/opt/data/wiki-ingest/`)
