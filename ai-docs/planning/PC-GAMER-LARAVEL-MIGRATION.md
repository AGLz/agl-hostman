# Plano de Migração — `pc-gamer-cotacoes` → app Laravel (`src/`)

> **Objetivo:** mover o sistema de cotações de PC gamer (hoje Python/SQLite/CLI em
> `projects/pc-gamer-cotacoes`) para dentro da app Laravel 12 (`src/`), reutilizando
> os padrões existentes (Inertia React + shadcn, Horizon, `Http` facade, Pest).
>
> **Decisões do utilizador (2026-06-29):**
>
> - Cotações reais via **APIs oficiais** (Mercado Livre OAuth + AliExpress Affiliate);
>   Pichau/4Gamers ficam por scraping `Http` onde o egress permitir.
> - O destino é a **app Laravel `agl-hostman`** (não o CT134 de produção diretamente —
>   o deploy chega ao CT134 via pipeline Dokploy/Harbor existente).
>
> Inventário-base: [projeto Python](#) e [app Laravel](#) (subagents explore, 2026-06-29).

---

## 1. Princípios e decisões de arquitetura

| Tema                | Decisão                                                                                              | Razão                                                                             |
| ------------------- | ---------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------- |
| Namespace domínio   | `App\Services\PcGamer\`, `App\Models\PcGamer\`, `App\Jobs\PcGamer\`, `App\Http\Controllers\PcGamer\` | Isolar o domínio; seguir subpastas já usadas (`Services/Hermes/`, `Jobs/Archon/`) |
| Prefixo de tabelas  | **`pcg_`** (`pcg_components`, `pcg_builds`, `pcg_retailers`, `pcg_market_prices`, …)                 | Evitar colisão semântica com as 50 tabelas existentes                             |
| DB                  | Connection default da app (sqlite dev → mysql/pgsql prod)                                            | Reutilizar infra; nada de SQLite paralelo                                         |
| Dinheiro            | Sempre **centavos** (`integer`)                                                                      | Manter convenção do projeto Python                                                |
| JSON                | Colunas `json` + `casts()` (`specs_json`, `parsed_json`, `items_json`)                               | Padrão Laravel 12 (`casts()` method)                                              |
| Providers HTTP      | Interface `MarketProvider` + classes com **`Http` facade** (substitui `httpx`)                       | Padrão `*ApiClient` já dominante (LiteLLM, Dokploy, Harbor)                       |
| APIs oficiais       | ML OAuth + AliExpress Affiliate via `config/pcgamer.php` (lidos de `env` só em config)               | Decisão do utilizador; contorna WAF                                               |
| Automação           | `FetchMarketPricesJob` (`ShouldQueue`, fila `pc-gamer`) + Artisan command + scheduler                | Horizon já existe; alinhar com jobs atuais                                        |
| CLI                 | Comandos `php artisan pcg:*` (espelham `cli.py`)                                                     | Substituir Click                                                                  |
| UI                  | **Inertia React** em `Pages/PcGamer/` com shadcn/ui                                                  | Stack override AGL; padrão `daily-memory`/`Memory/Dashboard`                      |
| Telegram (Telethon) | **Sidecar Python** mantido; faz `POST` para endpoint Laravel `api.key`                               | Sem equivalente PHP maduro; menor risco (ver Fase 5)                              |
| Coexistência        | Projeto Python mantém-se funcional até F6; só então deprecado                                        | Migração incremental sem downtime                                                 |

---

## 2. Mapa de migração (Python → Laravel)

| Python                                      | Laravel                                                                 |
| ------------------------------------------- | ----------------------------------------------------------------------- |
| `src/db/schema.sql` (10 tabelas + seeds)    | Migrations `pcg_*` + Seeders                                            |
| `catalog/models.py` (enums, Pydantic)       | Enums PHP (`BuildStatus`, `ComponentCategory`) + casts                  |
| `catalog/repository.py` (~615 l)            | Eloquent models + `BuildService`, `CatalogService`                      |
| `catalog/comparison.py`                     | `BuildComparisonService`                                                |
| `catalog/presets.py` + `reference_sites.py` | Seeder `PcgPresetSeeder` + `config/pcgamer.php`                         |
| `market/models.py` (`MarketListing`)        | DTO `App\DTO\PcGamer\MarketListing`                                     |
| `market/http.py`                            | `Http::withHeaders()` central (ou `PcgHttp` helper)                     |
| `market/providers/*`                        | `App\Services\PcGamer\Providers\*Provider` + interface                  |
| `market/orchestrator.py`                    | `MarketFetchService` + `FetchMarketPricesJob`                           |
| `market/queries.py`                         | `config/pcgamer.php` (queries default por categoria)                    |
| `scripts/cli.py`                            | `app/Console/Commands/PcGamer/*`                                        |
| `scripts/fetch_market_cron.py`              | Scheduler em `app/Console/Kernel.php`                                   |
| `telegram/*` (Telethon)                     | Sidecar Python + endpoint `POST /api/pcgamer/telegram-offers`           |
| `tests/*`                                   | `tests/Feature/PcGamer/*`, `tests/Unit/PcGamer/*` (Pest + `Http::fake`) |

---

## 3. Fases e tarefas

### F0 — Fundação: schema + models + enums (sem lógica externa)

- **T0.1** Migrations `pcg_*` traduzindo `src/db/schema.sql`:
  `pcg_component_categories`, `pcg_components`, `pcg_telegram_sources`,
  `pcg_telegram_offers`, `pcg_builds`, `pcg_build_items`, `pcg_build_events`,
  `pcg_retailers`, `pcg_market_prices`, `pcg_build_presets`.
  Preservar UKs, FKs (cascade em build_items/events), índices.
  `php artisan make:migration --no-interaction`.
- **T0.2** Models Eloquent (`App\Models\PcGamer\*`) com `casts()`, `$fillable`,
  relações tipadas (`hasMany`/`belongsTo`) e scopes (`scopeActive`, `scopeByCategory`).
- **T0.3** Enums PHP: `BuildStatus` (draft→quoted→approved→ordered→assembly→completed|cancelled),
  `ComponentCategory` (10 slots). `php artisan make:enum`.
- **T0.4** Seeders: categorias, retailers (10), presets (4 tiers) — a partir de `presets.py`.
  Factories para `Component`, `Build` (testes).
- **Aceitação:** `php artisan migrate:fresh --seed` cria schema + dados base; testes de factory passam.

### F1 — Market providers (`Http`) + APIs oficiais

- **T1.1** Interface `App\Services\PcGamer\Providers\MarketProvider` (`search(string $query, string $categorySlug, int $limit): array<MarketListing>`).
- **T1.2** DTO `MarketListing` (provider, category_slug, product_name, price_cents, currency, url, external_id, query, notes, confidence).
- **T1.3** `MercadoLivreProvider` — **API oficial OAuth** (`config/pcgamer.php`: client_id/secret/token),
  `sites/MLB/search` `condition=new`, filtro `seller_address.country.id == BR`, notas `ship:BR`/`vendedor:`/`loja_oficial:`. Fallback HTML opcional.
- **T1.4** `AliExpressProvider` — **Affiliate API** (appkey/secret, sign MD5), `target_currency=BRL`, `ship_to_country=BR`; fallback wholesale HTML.
- **T1.5** `PichauProvider` — Magento 2 GraphQL + fallback HTML JSON-LD (porta direta do `pichau.py`).
- **T1.6** `FourGamersProvider` — Nuvemshop API + fallback HTML.
- **T1.7** Registry: bind no container (`config/pcgamer.php` lista de slugs) → `MarketFetchService` resolve.
- **Aceitação:** Unit tests por provider com `Http::fake()` (parsing + filtro BR + fallback). ML/AliExpress validados contra API oficial (credenciais em `.env`).

### F2 — Orquestração e automação

- **T2.1** `MarketFetchService` (espelha `orchestrator.py`): `fetchCategory`, `fetchBuild`, `fetchAllPresetCategories`; persiste em `pcg_market_prices` (`source=fetch:{provider}`), ignora `price_cents<=0`.
- **T2.2** `FetchMarketPricesJob implements ShouldQueue` (`onQueue('pc-gamer')`), com retry/backoff.
- **T2.3** Scheduler: `app/Console/Kernel.php` → `FetchMarketPricesJob` diário (08:00 BRT).
- **T2.4** `config/horizon.php`: adicionar fila `pc-gamer` ao supervisor.
- **Aceitação:** `php artisan pcg:fetch-market --all-categories` enfileira e persiste; teste Feature com `Http::fake` confirma gravação.

### F3 — Domínio builds + comparação + API REST

- **T3.1** `CatalogService` (CRUD componentes/categorias) + `BuildService` (novo build via template AMD 10 slots, código `PC-{ano}-{seq}`, set-item, `cost_cents`/`quote_cents` com `margin_percent`, transição de estado → `pcg_build_events`).
- **T3.2** `BuildComparisonService` (porta de `comparison.py`): melhor `market_prices` + melhor oferta Telegram por categoria, deltas e totais.
- **T3.3** Form Requests (`StoreBuildRequest`, `UpdateBuildItemRequest`, `AddMarketPriceRequest`) — validação dedicada.
- **T3.4** API REST em `routes/api.php` (sanctum, padrão `scrum`): builds, items, market-prices, compare, presets.
- **Aceitação:** Feature tests dos endpoints (happy + falha + autorização).

### F4 — UI Inertia React

- **T4.1** Controllers Inertia (`PcGamer\BuildController`, `CatalogController`, `MarketPriceController`) com `Inertia::render('PcGamer/...')`.
- **T4.2** Pages `resources/js/Pages/PcGamer/`: `Builds/Index`, `Builds/Show` (itens + comparação), `Catalog/Index`, `MarketPrices/Index`, `Presets/Index`. Reutilizar `AuthenticatedLayout` + shadcn (`card`, `table`, `badge`, `button`).
- **T4.3** Rotas web (`auth`), entradas no menu/sidebar.
- **Aceitação:** `assertInertia` por página; `npm run build` sem erros.

### F5 — Ingest Telegram (sidecar) — ver §7 (research)

- **T5.1** Endpoint `POST /api/pcgamer/telegram-offers` (middleware `api.key`, padrão `daily-memory`) — recebe oferta parseada, dedup por `message_hash`.
- **T5.2** Manter listener/sync Python **Telethon (MTProto/userbot)** como **sidecar**; trocar persistência SQLite por POST ao endpoint. (Alternativa futura: avaliar MadelineProto PHP — fora de âmbito.)
- **T5.3** Adicionar scraper `t.me/s/<canal>` (Laravel `Http`) como **fallback** para canais públicos (sem conta, sem risco de ban) — job agendado.
- **T5.4** Documentar operação do sidecar (onde corre, credenciais, supervisão).
- **Aceitação:** Feature test do endpoint (auth + dedup); smoke do sidecar + scraper contra ambiente dev.

### F6 — Testes, qualidade, docs e deprecação

- **T6.1** Suite Pest completa (Unit providers + Feature endpoints/UI); cobertura >80% do domínio.
- **T6.2** `vendor/bin/pint` + `larastan` limpos.
- **T6.3** Atualizar docs da app (apenas se pedido) e marcar `projects/pc-gamer-cotacoes` como legado (README aponta para o módulo Laravel).
- **T6.4** Code review (code-reviewer) → corrigir CRITICAL/HIGH → commit/push/PR (pipeline obrigatório).
- **Aceitação:** `php artisan test` verde; PR aberto.

---

## 4. Decisões pendentes (precisam de confirmação)

1. **Telegram**: confirmar o **userbot Telethon (sidecar) + fallback `t.me/s/`** como abordagem (ver §7 — Composio/Bot API **não** serve para grupos de terceiros).
2. **UI**: Inertia React (recomendado) ou SPA React Router (`app.jsx` + axios)?
3. **Prefixo de tabelas** `pcg_` — confirmar (alternativa: schema/DB separado).
4. **Credenciais**: quem fornece ML OAuth (client_id/secret) e AliExpress appkey/secret?

---

## 5. Riscos

- **WAF** continua a bloquear Pichau/4Gamers a partir da infra AGL (testado: AGLSRV1 dá 403). Mitigação: APIs oficiais onde existem; scraping só como best-effort com `confidence` baixa e nota `blocked:waf`.
- **Telethon** sem equivalente PHP → dependência de processo Python externo.
- **Colisão de nomes** com 50 models existentes → mitigada pelo prefixo `pcg_` e namespace `PcGamer`.

---

## 6. Ordem de execução (paralelizável)

```
F0 ──► F1 ──► F2 ──┐
          └──► F3 ──► F4
F5 (após F0+F3)     │
F6 (último) ◄───────┘
```

F0 é bloqueante. Depois, F1→F2 (automação) e F3→F4 (domínio+UI) podem correr em paralelo (subagents distintos). F5 depende de F0+F3. F6 fecha.

---

## 7. Research — Ler ofertas de grupos/canais Telegram (2026-06-29)

**Pergunta:** o Composio comunica com Telegram e dá para ler mensagens de grupos?

**Composio TEM toolkit Telegram** (slug `TELEGRAM`, 18 tools, conta já conectada),
**MAS é baseado na Telegram _Bot API_** (auth por Bot Token via BotFather), não MTProto.
Isto impõe limites que o **inviabilizam para o nosso caso** (monitorizar grupos/canais
de **terceiros**):

| Limitação (Bot API / Composio)                                                                                | Impacto                                                        |
| ------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------- |
| `TELEGRAM_GET_CHAT_HISTORY` usa `getUpdates`; "bot só recebe mensagens **enviadas depois de entrar** no chat" | Sem histórico; só o que chega após adicionar o bot             |
| Bot tem de **ser membro** do chat; em canais só **admins** adicionam bots                                     | Impossível em grupos/canais de terceiros que não administramos |
| _Privacy mode_ dos bots em grupos: só veem menções/comandos (salvo admin)                                     | Não capta posts normais de ofertas                             |
| `GET_CHAT_MEMBERS_COUNT`/moderação exigem admin                                                               | N/A para terceiros                                             |

→ **Composio/Bot API só serve se criarmos um canal/grupo agregador _próprio_** (ex. para o
bot **publicar/encaminhar** ofertas curadas), **não** para ingerir grupos de terceiros.

### Soluções para ler grupos de terceiros (recomendação)

| Solução                                                |    Lê grupos/canais de terceiros?    |    Histórico     |    Tempo real    | Notas                                                                   |
| ------------------------------------------------------ | :----------------------------------: | :--------------: | :--------------: | ----------------------------------------------------------------------- |
| **Telethon/Pyrogram userbot (MTProto)** ✅ recomendado |        Sim (qualquer público)        |       Sim        |       Sim        | Conta de utilizador (nº dedicado/virtual). É o que o projeto **já usa** |
| **Scraping `https://t.me/s/<canal>`** ✅ fallback      |        Só **canais** públicos        | Parcial (página) |   Por polling    | Sem conta, sem risco de ban; leve via `Http`                            |
| Composio / Bot API ❌                                  | Não (só chats próprios c/ bot admin) |       Não        | Sim (getUpdates) | Útil só p/ canal agregador próprio                                      |
| Serviços pagos (telemetr.io, tgstat)                   |             Sim (canais)             |       Sim        |      Varia       | Custo; analytics de canais                                              |

**Decisão técnica:** manter o **userbot Telethon** como núcleo de ingestão (já implementado),
complementado por **scraper `t.me/s/`** para canais públicos como fallback resiliente.
Reservar o **Composio Telegram** para uma futura camada de _saída_ (publicar ofertas
curadas num canal próprio), se desejado.

> Fontes: docs.composio.dev/toolkits/telegram, composio.dev/auth/telegram (consultadas 2026-06-29).
