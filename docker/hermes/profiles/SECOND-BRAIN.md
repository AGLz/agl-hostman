# llm-wiki — segundo cérebro (todos os agentes Hermes)

Vault **llm-wiki** montado em **`/opt/llm-wiki`** (**rw**). Factos duráveis vivem aqui; **Honcho** guarda contexto episódico; **Linear** gere entrega.

## Antes de decidir ou actuar

1. Ler **`/opt/llm-wiki/wiki/index.md`** (catálogo).
2. Aprofundar páginas em `wiki/` com a skill **`llm-wiki`** (fluxo _Query_ em `AGENTS.md`).
3. Se lacuna crítica: pesquisa web ou pedir ao **Curator** lint/ingest agendado — não inventar runbooks.

## Depois de mudanças documentáveis

Quando alterares infra, deploy, media, produto ou decisões de arquitectura:

1. Criar ou actualizar página(s) em **`/opt/llm-wiki/wiki/`** (wikilinks `[[...]]`, frontmatter).
2. Actualizar **`wiki/index.md`**.
3. Append em **`wiki/log.md`**: `## [YYYY-MM-DD] ingest | hermes/<agente> | título curto`.
4. Opcional: stub em **`/opt/data/wiki-ingest/<agente>/`** ou **`/opt/llm-wiki/raw/hermes/<agente>/`** para o Curator consolidar no cron.

**Não** duplicar runbooks completos em `agl-hostman/docs/` — pointer + link wiki.

## Paths

| Variável / path   | Valor                                                                                |
| ----------------- | ------------------------------------------------------------------------------------ |
| `WIKI_PATH`       | `/opt/llm-wiki/wiki`                                                                 |
| Fontes imutáveis  | `/opt/llm-wiki/raw/` (não editar excepto `raw/hermes/<agente>/` stubs)               |
| Schema            | `/opt/llm-wiki/AGENTS.md`                                                            |
| Ingest por agente | `${CURATOR_DATA}/wiki-ingest/<agente>/` (host) → `/opt/data/wiki-ingest/` no Curator |
| Stubs Hermes      | `${LLM_WIKI_DIR}/raw/hermes/<agente>/`                                               |

## Papéis

| Agente      | Leitura              | Escrita típica                                      |
| ----------- | -------------------- | --------------------------------------------------- |
| **Jarvis**  | Estratégia, decisões | Síntese CEO, prioridades documentadas               |
| **Elon**    | Pesquisa, produto    | Specs, PMF, análises de mercado                     |
| **Satya**   | Runbooks deploy/app  | Procedimentos entrega, checklists                   |
| **Werner**  | Infra, incidentes    | Runbooks Proxmox/LiteLLM pós-mortem                 |
| **Orion**   | Media stack          | Estado \*arr, freeze/unfreeze, MEDIA-ARR            |
| **Curator** | Vault inteiro        | Ingest/lint agendado (2h), consolida stubs de todos |

Curator **não** monopoliza escrita — mantém qualidade e cron; os restantes escrevem no domínio deles.
