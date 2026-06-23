---
name: llm-wiki-ingest
description: Exporta conversas Cursor para llm-wiki (raw/cursor) e sintetiza problemas, decisões e soluções em páginas wiki — fluxo paralelo ao Hermes Curator.
---

# llm-wiki-ingest (Cursor → segundo cérebro)

Pedido de referência (sessão 2026-06-19, aglwk45): _«pedi ao Hermes que colocasse todas as conversas, problemas, decisões e soluções no llm-wiki — quero o mesmo no Cursor»_.

## Pipeline

```
Cursor agent-transcripts (JSONL)
        ↓ export-cursor-sessions.py (incremental)
llm-wiki/raw/cursor/live/ + ingest-queue.jsonl
        ↓ agente / Curator (síntese)
llm-wiki/wiki/ + index.md + log.md
```

## Export (sempre primeiro)

```bash
bash scripts/cursor/sync-cursor-to-wiki.sh
```

Hook automático: `.cursor/hooks/llm-wiki-export.js` no `sessionEnd` (desactivar com `AGL_CURSOR_WIKI_SYNC=0`).

Timer opcional (todos AGLDV*): `agl-cursor-wiki-sync.timer` — cada 30 min.

Propagação multi-host:

```bash
./scripts/cursor/propagate-cursor-wiki-sync.sh --host agldv-all
```

Cada host exporta com `CURSOR_EXPORT_HOST=<hostname>`; o agregador em NFS (`CURSOR_EXPORT_ALL_HOSTS=1`) varre `agl-home-sync/*/cursor/dot-cursor/projects`. Ficheiros em `raw/cursor/live/agent-transcripts/<host>/`.

## Ingest curado

1. Ler `wiki/index.md` e `raw/cursor/ingest-queue.jsonl` (últimas entradas).
2. Abrir markdown em `raw/cursor/live/agent-transcripts/`.
3. Sintetizar **factos reutilizáveis** — não transcript completo.
4. Actualizar `wiki/`, `wiki/index.md`, `wiki/log.md`.

### Template de síntese (sessão)

```markdown
---
title: <Tema>
tags: [cursor, <domínio>, agl]
updated: YYYY-MM-DD
sources:
  - raw/cursor/live/agent-transcripts/<ficheiro>.md
---

# <Tema>

## Problema

...

## Decisões

...

## Solução

...

## Verificação

...
```

## Filtro AGL

Default `--filter agl` — sessões com keywords AGL ou projectos `*agl*`. Usar `--all` para export total.

## Git no vault

```bash
LLM_WIKI_GIT_COMMIT=1 LLM_WIKI_GIT_PUSH=1 bash scripts/cursor/sync-cursor-to-wiki.sh
```

Bridge CT193: `agl-llm-wiki-bridge` puxa `main` após push.
