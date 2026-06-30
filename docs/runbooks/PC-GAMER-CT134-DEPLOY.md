# PC Gamer — Deploy CT134

> Runbook operacional para activar o módulo PC Gamer em produção (`https://ah.aglz.io`).

## Pré-requisitos

- CT134 com stack agl-hostman a correr (ver [`CT134-AGL-HOSTMAN-PRODUCTION.md`](../CT134-AGL-HOSTMAN-PRODUCTION.md))
- Horizon + scheduler activos (`agl-hostman-prod-horizon`, `agl-hostman-prod-scheduler`)
- Acesso SSH AGLSRV1 (`root@100.107.113.33`) e Docker/Harbor configurados

## Deploy rápido

```bash
cd /path/to/agl-hostman
bash scripts/proxmox/deploy-pcgamer-ct134.sh
```

Só migrate (imagem já actualizada):

```bash
bash scripts/proxmox/deploy-pcgamer-ct134.sh --migrate-only
```

## O que o script faz

1. Build + push imagem Harbor (ou `--skip-build`)
2. Variáveis `.env` PC Gamer no CT134 (`TELEGRAM_MONITOR_CHATS`, tolerâncias validação, providers)
3. `php artisan migrate` — migration `2026_06_30_000001_create_pcgamer_tables.php`
4. `PcgCatalogSeeder` (idempotente se já existir)
5. Smoke: rotas `/pc-gamer/*`, comandos `pcg:*`, testes `--filter=PcGamer`
6. Restart Horizon + scheduler

## Scheduler (automático)

| Job | Intervalo | Comando equivalente |
|-----|-----------|---------------------|
| `SyncTmeOffersJob` | 15 min | `pcg:sync-tme` |
| `ValidateTelegramOffersJob` | 30 min | `pcg:validate-offers` |
| `FetchMarketPricesJob` | 08:00 BRT | `pcg:fetch-market --all-categories` |

Fila Horizon: **`pc-gamer`**.

## Sidecar Python (transição)

Enquanto o scheduler Laravel não estiver validado em prod:

- Sidecar em `projects/pc-gamer-cotacoes` com `LARAVEL_INGEST_URL=https://ah.aglz.io/api/pcgamer/telegram-offers`
- API key: `API_KEY` do `.env` CT134 (`/root/.agl-hostman-api-key.generated`)

Após confirmar sync Laravel:

```bash
bash scripts/uninstall-tme-cron.sh
# ou manualmente:
crontab -l | grep -v pc-gamer-cotacoes-tme-scraper | crontab -
```

## Credenciais opcionais (melhor cobertura mercado)

| Variável | Uso |
|----------|-----|
| `MERCADOLIVRE_ACCESS_TOKEN` | API ML (contorna WAF) |
| `ALIEXPRESS_APP_KEY` / `SECRET` / `TRACKING_ID` | Affiliate API |
| `PCG_MARKET_FETCH_PROVIDERS` | Default: `mercadolivre,pichau,aliexpress,4gamers` |

## Verificação pós-deploy

```bash
ssh root@100.107.113.33 pct exec 134 -- docker exec agl-hostman-prod-app php artisan schedule:list | grep pcg
curl -fsS -o /dev/null -w '%{http_code}\n' https://ah.aglz.io/health/
# UI (login): https://ah.aglz.io/pc-gamer/builds
```

## Rollback

Redeploy imagem anterior via Dokploy/Harbor; tabelas `pcg_*` permanecem (sem migration down automática).

## Referências

- Plano migração: [`ai-docs/planning/PC-GAMER-LARAVEL-MIGRATION.md`](../../ai-docs/planning/PC-GAMER-LARAVEL-MIGRATION.md)
- Sidecar legado: [`projects/pc-gamer-cotacoes/README.md`](../../projects/pc-gamer-cotacoes/README.md)
