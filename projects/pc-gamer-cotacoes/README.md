# PC Gamer — Cotações e Catálogo

> **Migração Laravel (2026-06-30):** produção em `https://ah.aglz.io/pc-gamer/*` (CT134). Sync/validação Telegram correm no scheduler Laravel — **desinstalar cron local** com `bash scripts/uninstall-tme-cron.sh`. Sidecar Python mantém-se só para testes CLI offline.

Projeto local em `projects/pc-gamer-cotacoes` para montar **cotações de PCs gamer** (AMD), guardar histórico de montagens/efetivações e importar **ofertas de grupos Telegram**.

## Escopo da montagem (template)

Incluído no template padrão:

- Gabinete
- Placa-mãe (Asus, Gigabyte, MSI ou ASRock)
- Processador AMD
- Memória DDR5
- SSD NVMe 1TB (ex.: Samsung)
- Placa de vídeo
- Water cooler
- Fans
- Fonte
- Suporte/conector VGA (ex.: bracket 3 fans)

**Fora de escopo inicial:** monitor, teclado, rato.

## Fluxo de negócio

```
draft → quoted → approved → ordered → assembly → completed
                                              ↘ cancelled
```

| Estado      | Significado                              |
| ----------- | ---------------------------------------- |
| `draft`     | Montagem/cotação em elaboração           |
| `quoted`    | Proposta enviada ao cliente              |
| `approved`  | Cliente aceitou                          |
| `ordered`   | Peças compradas (links/ofertas fechadas) |
| `assembly`  | Cliente enviou peças / montagem em curso |
| `completed` | Entregue                                 |
| `cancelled` | Cancelada                                |

Cada transição fica em `build_events` (histórico auditável).

## Setup rápido

```bash
cd projects/pc-gamer-cotacoes
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env
# Editar .env com TELEGRAM_API_ID / TELEGRAM_API_HASH
python scripts/cli.py init-db
```

## CLI — exemplos

```bash
# Categorias e catálogo
python scripts/cli.py categories
python scripts/cli.py add-component --category motherboard --brand asus --model "TUF B650-PLUS WIFI"

# Nova cotação (template AMD gamer)
python scripts/cli.py new-build "PC Gamer AMD 7800X3D" --customer "João" --contact "@joao"

# Listar e detalhar
python scripts/cli.py builds
python scripts/cli.py show-build 1

# Preencher item (preço em reais)
python scripts/cli.py set-item 1 3 --label "Ryzen 7 7800X3D" --cost 1899.90

# Efetivação — cliente comprou / montagem
python scripts/cli.py status 1 approved --notes "Cliente confirmou WhatsApp"
python scripts/cli.py status 1 ordered
python scripts/cli.py status 1 assembly --notes "Peças recebidas para montar"
python scripts/cli.py status 1 completed

# Telegram — descobrir grupos
python scripts/list_groups.py

# Configurar no .env: TELEGRAM_MONITOR_CHATS=@grupo1,-1001234567890
python scripts/cli.py sync-telegram --limit 150
python scripts/cli.py offers --category placa_video
python scripts/cli.py listen-telegram   # tempo real

# Referências BR (MEUPC, KaBuM, Pichau, Terabyte…)
python scripts/cli.py sites
python scripts/cli.py wizard-steps
python scripts/cli.py presets
python scripts/cli.py preset amd-mid-7800x3d-5070
python scripts/cli.py new-from-preset amd-mid-7800x3d-5070 --customer "Cliente"
python scripts/cli.py seed-market
python scripts/cli.py compare-build 1

# Automação Mercado Livre + Pichau + AliExpress + 4Gamers (vendedores BR)
python scripts/cli.py fetch-market --build 1
python scripts/cli.py fetch-market --category placa_video --query "RTX 5070"
python scripts/cli.py fetch-market --all-categories
python scripts/cli.py fetch-market --category processador --providers pichau,mercadolivre
python scripts/cli.py market-prices --retailer pichau
```

## Telegram

Ver pesquisa detalhada: [docs/TELEGRAM_RESEARCH.md](docs/TELEGRAM_RESEARCH.md)

## Sites BR de referência

Comparativo de configuradores e estratégia de preços: [docs/REFERENCIAS_SITES_BR.md](docs/REFERENCIAS_SITES_BR.md)

Principais referências:

| Site                                                                         | Uso no projeto               |
| ---------------------------------------------------------------------------- | ---------------------------- |
| [MEUPC.NET](https://meupc.net/build)                                         | Comparar preços multi-loja   |
| [KaBuM!](https://www.kabum.com.br/monte-seu-pc)                              | Compatibilidade + montagem   |
| [Pichau](https://www.pichau.com.br/monte-seu-pc)                             | Ordem do wizard de slots     |
| [Terabyte Full Custom](https://www.terabyteshop.com.br/pc-gamer/full-custom) | Tiers AM5 / presets high-end |

4 **presets** (`entry`, `mid`, `high`, `enthusiast`) com preços indicativos para baseline e `compare-build`.

## Automação de preços (ML, Pichau, AliExpress, 4Gamers)

Ver [docs/MARKET_FETCH.md](docs/MARKET_FETCH.md). Comando principal: `fetch-market` grava em `market_prices` para uso em `compare-build`. Providers priorizam **vendedores do Brasil** (MLB nacional, Pichau/4Gamers lojas BR, AliExpress `ship_from=BR`).

## Estrutura

```
pc-gamer-cotacoes/
├── data/                 # SQLite + sessões Telethon (gitignored)
├── docs/
├── scripts/
│   ├── cli.py
│   └── list_groups.py
├── src/
│   ├── catalog/          # modelos + repositório
│   ├── db/               # schema SQL
│   └── telegram/         # sync, listener, parser
├── .env.example
└── requirements.txt
```

## Base de dados

Ficheiro padrão: `data/pc_gamer.sqlite3`

Tabelas principais: `components`, `builds`, `build_items`, `build_events`, `telegram_offers`.

## Próximos passos sugeridos

- UI web (FastAPI + React) para montar cotação visualmente
- Botão "aplicar oferta Telegram" num slot da montagem
- Export PDF da cotação para cliente
- LLM para mensagens de promoção complexas
