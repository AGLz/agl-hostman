# Pesquisa: ler ofertas de grupos Telegram (Python)

Documento de referência para o projeto `pc-gamer-cotacoes`. Objetivo: **capturar mensagens de grupos/canais de promoções** e extrair preço + produto para alimentar cotações de PC gamer.

## Abordagens comuns

| Abordagem | Biblioteca | Quando usar |
|-----------|------------|-------------|
| **Userbot (conta pessoal)** | [Telethon](https://github.com/LonamiWebs/Telethon) ou [Pyrogram](https://github.com/pyrogram/pyrogram) | Ler histórico e mensagens em tempo real em grupos onde **já és membro** |
| **Bot oficial** | `python-telegram-bot`, `aiogram` | Comandos, notificações, **não** lê histórico completo de grupos sem ser adicionado e com permissões |
| **Pipeline + LLM** | Telethon + OpenAI/local | Mensagens ambíguas; extrair JSON estruturado (produto, preço, cupom) |

Para **grupos de ofertas** (Kabum, Terabyte, Amazon BR, etc.), o padrão da comunidade é **Telethon userbot** + parser (regex/heurística ou LLM) + SQLite/PostgreSQL.

## Repositórios úteis (referência)

### Leitura / monitorização Telegram

| Repo | Descrição | Relevância |
|------|-----------|------------|
| [Lonky1995/tg-channel-digest](https://github.com/Lonky1995/tg-channel-digest) | Userbot Telethon, SQLite, API REST, digest por cron | Modelo de arquitetura (listener + persistência + consulta) |
| [sergebulaev/telegram-channel-saver](https://github.com/sergebulaev/telegram-channel-saver) | Download incremental de mensagens, índice pesquisável | Backfill de histórico grande |
| [JustinGuese/python_tradingbot_framework](https://github.com/JustinGuese/python_tradingbot_framework) | Guia `telegram-monitor.md` — polling Telethon + DB | Padrão CronJob / sync periódico |
| [rafaelpanegassi/api-pipeline-with-llm](https://github.com/rafaelpanegassi/api-pipeline-with-llm) | Telethon → filtro → **GPT extrai JSON** → PostgreSQL | Quando regex não chega (cupons, texto livre) |

### Ofertas / preços (padrões de produto)

| Repo | Descrição | Relevância |
|------|-----------|------------|
| [joaomenkdev-cloud/Bot-ofertas-Telegram](https://github.com/joaomenkdev-cloud/Bot-ofertas-Telegram) | Scraping ML + envio a grupos, anti-duplicata SHA256, fila | Ideias de deduplicação e categorias tech |
| [Rostislav62/PriceParser](https://github.com/Rostislav62/PriceParser) | Histórico de preços + bot aiogram | Modelo de `/history` e alertas |
| [kar1m0vf/trendyol-price-tracker](https://github.com/kar1m0vf/trendyol-price-tracker) | Watchlist, APScheduler, SQLite | Scheduler robusto para sync periódico |
| [RevantPatel/Price-Bot](https://github.com/RevantPatel/Price-Bot) | Tracker Amazon + Telegram | Validação de URL e canonical links |

## Credenciais e requisitos

1. Criar app em [my.telegram.org/apps](https://my.telegram.org/apps) → `api_id` + `api_hash`
2. A conta Telegram deve **entrar nos grupos** de ofertas manualmente
3. Grupos privados: usar **ID numérico** (positivo ou `-100…`) — ver `scripts/list_groups.py`
4. Respeitar [ToS Telegram](https://telegram.org/tos) e rate limits (Telethon já faz throttling)

## O que implementámos neste projeto

- `src/telegram/sync_history.py` — backfill das últimas N mensagens
- `src/telegram/listener.py` — novas mensagens em tempo real
- `src/telegram/parsers/offer_parser.py` — heurística PT-BR (preço R$, categorias PC)
- Tabela `telegram_offers` com hash anti-duplicata
- CLI: `sync-telegram`, `listen-telegram`, `offers`

## Evolução recomendada (fase 2)

1. **Matching automático** — associar oferta → slot da montagem (`build_items.offer_id`)
2. **LLM opcional** — mensagens tipo "combo Ryzen + B650 + 32GB" → JSON (inspirado em api-pipeline-with-llm)
3. **Alertas** — quando preço de categoria X cair abaixo do último usado numa cotação
4. **StringSession** — deploy em CT/cron sem ficheiro `.session` interativo

## Aviso legal / operacional

- Não reencaminhar spam comercial em massa; uso interno para cotação
- Rotacionar sessão se exposta; nunca commitar `.env` ou `.session`
- Grupos de ofertas mudam links frequentemente — manter lista em env ou tabela `telegram_sources`
