# LiteLLM Multi-Host Deployment — Local em Cada Host

> **Objetivo**: LiteLLM em produção no **CT186** (`/opt/agl-litellm`); réplicas opcionais em agldv04, agldv12 e fgsrv06.  
> **Canónico (2026-06):** CT186 — LAN `http://192.168.0.186:4000`, Tailscale `http://100.125.249.8:4000`.  
> **agldv03 (CT179):** LiteLLM **descontinuado** — não deployar nem sincronizar para `/opt/litellm` neste host.  
> **Regra (hosts com stack local):** OpenClaw e Claude-flow usam **localhost:4000** no próprio host; clientes sem stack local apontam ao **CT186**.

**OpenClaw no agldv12**: o CT **agldv12** é clone do ambiente de dev; **não** deve correr o gateway OpenClaw em paralelo ao agldv03 (Telegram/bots duplicados, estado partilhado). Serviço `openclaw-gateway.service` (**systemd --user**) mantido **desativado**; ficheiros da unit renomeados para `*.disabled-on-clone` no host. LiteLLM no agldv12 pode permanecer para testes multi-host se necessário.

---

## Visão geral

**Base (repo):** `config/litellm/config.yaml` no **agl-hostman** — fonte única de verdade. Deploy canónico: **CT186** via `scripts/proxmox/bootstrap-ct186-litellm.sh` (`/opt/agl-litellm`). Sync opcional para agldv04, agldv12, fgsrv06 (scripts em `scripts/litellm/`).

| Host | Tailscale IP | Rede | Config / path | Ollama | Redis |
|------|--------------|------|---------------|--------|-------|
| **CT186** (agl-litellm) | 100.125.249.8 | LAN AGLSRV1 | `config.yaml` → `/opt/agl-litellm` | `100.67.253.52` (VM310 TS) | — |
| **agldv03** | 100.94.221.87 | LAN AGLSRV1 | ~~`/opt/litellm`~~ **descontinuado 2026-06-05** | — | — |
| **agldv04** | 100.113.9.98 | LAN AGLSRV1 | `config.yaml` → `/opt/litellm` | `100.67.253.52` (via config canónico) | 192.168.0.137 |
| **agldv12** | 100.71.217.115 | LAN AGLSRV1 | `config.yaml` → `/opt/litellm` | `100.67.253.52` | 192.168.0.137 |
| **fgsrv06** | 100.83.51.9 | Cloud VPS | `config-remote.yaml` | Groq/OR fallbacks (VM110 offline) | litellm-redis (Docker) |

**Ollama primário (2026-06-11) — VM310 AGLSRV3:** `http://100.67.253.52:11434` (Tailscale `aglsrv3-ollama`); LAN `192.168.15.210`. LiteLLM canónico (`config.yaml`): `agl-primary` → `qwen3:8b`; `ollama-gemma3-4b` → `gemma3:4b`; ver [`docs/AGL-OLLAMA-VM310.md`](AGL-OLLAMA-VM310.md).

**Legado AGLSRV1:** VM110/CT200 (`192.168.0.200`, TS `100.116.57.111`) **offline** — [`docs/AGL-OLLAMA-VM110.md`](AGL-OLLAMA-VM110.md).

---

## Pré-requisitos por host

1. **Docker** e **Docker Compose** instalados
2. **Acesso SSH** como root
3. **API keys** no `.env` (Anthropic, ZAI, DeepSeek, etc.)
4. **`LITELLM_MASTER_KEY`** (recomendada em `/opt/litellm/.env`): ver `config/litellm/.env.example`. Sem esta variável o LiteLLM pode aceitar pedidos **sem** cabeçalho `Authorization` (útil em LAN fechada; **evitar** se a porta 4000 for acessível fora da equipa). Os scripts em `scripts/litellm/` usam `_litellm-master-key.sh` e omitam `Bearer` se a chave estiver vazia.
5. **Tailscale** (fgsrv06: Ollama local indisponível — usar fallbacks em `config-remote.yaml`)

---

## Deploy em cada host

### 1. Estrutura de diretórios (padrão)

```
/opt/litellm/
├── config.yaml          # ou config-remote.yaml (fgsrv06)
├── .env                 # LITELLM_MASTER_KEY + API keys
├── docker-compose.yml
└── litellm-db-data/     # volume PostgreSQL (criado automaticamente)
```

### 2. Script de deploy

```bash
# Do repositório agl-hostman (qualquer máquina com SSH aos hosts)
./scripts/litellm/deploy-litellm-host.sh <host>
# Produção canónica: bootstrap CT186 — scripts/proxmox/bootstrap-ct186-litellm.sh
# Ex: ./scripts/litellm/deploy-litellm-host.sh agldv04
# Ex: ./scripts/litellm/deploy-litellm-host.sh fgsrv06
```

### 3. Sync de config (repo → hosts)

```bash
# Editar config/litellm/config.yaml no repo, depois:
./scripts/litellm/sync-litellm-repo-to-opt.sh   # repo → /opt/litellm local (se aplicável)
./scripts/litellm/sync-config-all-hosts.sh       # agldv04, agldv12, fgsrv06 (+ CT186 quando script actualizado)
# CT186: copiar manualmente ou scripts/proxmox/bootstrap-ct186-litellm.sh após alterar config no repo
```

### 4. Deploy manual (por host)

#### Hosts LAN (agldv04, agldv12) — legado multi-host

```bash
# No host de destino (ex: ssh root@100.113.9.98)
mkdir -p /opt/litellm
cd /opt/litellm

# Copiar config do repo (não do agldv03 — descontinuado):
# scp /caminho/agl-hostman/config/litellm/config.yaml .

# Criar .env
cp /caminho/agl-hostman/config/litellm/.env.example .env
# Editar: LITELLM_MASTER_KEY, ANTHROPIC_API_KEY, ZAI_API_KEY, etc.

# docker-compose.yml (ver seção abaixo)
docker compose up -d

# Verificar
curl -s http://localhost:4000/health/readiness
```

#### fgsrv06 (remoto)

```bash
# Usar config-remote.yaml (sem Ollama local — fallbacks Groq/OpenRouter)
# Redis: cache desabilitado ou Redis local se disponível
```

---

## Configuração OpenClaw e Claude-flow (LOCAL)

**Em cada host**, OpenClaw e Claude-flow devem usar **localhost:4000**:

### OpenClaw

```bash
# Executar no host (agldv03, agldv04, agldv12, fgsrv06)
node scripts/openclaw/use-litellm-local.mjs
# ou
./scripts/openclaw/use-litellm-local.sh
```

Isso configura:
- `~/.config/openclaw/litellm-gateway.env` → `LITELLM_GATEWAY_URL=http://localhost:4000`
- `openclaw.json` → providers com `baseUrl: http://localhost:4000`

### Claude-flow / Ruflo

No `~/.zshrc` ou `~/.claude/turbo-flow.env`:

```bash
export LITELLM_GATEWAY_URL="http://localhost:4000"
export ANTHROPIC_BASE_URL="http://localhost:4000"
export ANTHROPIC_AUTH_TOKEN="sk-litellm-default"  # ou LITELLM_MASTER_KEY do .env
```

### Cursor / Claude Code

O `.claude/settings.json` do projeto já usa `ANTHROPIC_BASE_URL=http://localhost:4000`.  
**Não usar** `litellm-gateway-client.env` legado (apontava ao agldv03). Preferir CT186: `http://100.125.249.8:4000` ou LAN `http://192.168.0.186:4000`.

---

## Variantes de config

### config.yaml (hosts LAN — canónico CT186)

- Ollama: `http://100.67.253.52:11434` (VM310 AGLSRV3 via Tailscale)
- Redis: `192.168.0.137:6379` (CT137) — opcional no CT186
- Todos os modelos cloud + 10 aliases Ollama local (ver `LITELLM-MODEL-TIERS.md`)

### config-remote.yaml (fgsrv06)

- Ollama: **não** — VM110 offline; aliases `ollama-*` fazem fallback Groq/OpenRouter
- Redis: `litellm-redis:6379` (container no mesmo compose)
- Stack: `docker-compose-fgsrv06.yml` inclui PostgreSQL + Redis + LiteLLM
- **Fallbacks Claude/Haiku**: mesma ordem que `config.yaml` — **GLM (ZAI) primeiro**, depois deepseek, qwen3.5-plus, gemini (Haiku: `glm-flash` primeiro). Evita que qwen/deepseek fiquem à frente do GLM em falhas de Anthropic (ex.: claude-flow hive-mind via `claude-*`).

---

## Docker Compose (template)

```yaml
services:
  litellm-db:
    image: postgres:16-alpine
    container_name: litellm-db
    restart: unless-stopped
    environment:
      POSTGRES_USER: litellm
      POSTGRES_PASSWORD: litellm_db_pass
      POSTGRES_DB: litellm
    volumes:
      - litellm-db-data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U litellm -d litellm"]
      interval: 10s
      timeout: 5s
      retries: 5
    networks:
      - litellm-net

  litellm-proxy:
    image: ghcr.io/berriai/litellm:main-latest
    container_name: litellm-proxy
    restart: unless-stopped
    depends_on:
      litellm-db:
        condition: service_healthy
    ports:
      - "4000:4000"
    env_file:
      - .env
    environment:
      - CONFIG_FILE_PATH=/app/config.yaml
      - DATABASE_URL=postgresql://litellm:litellm_db_pass@litellm-db:5432/litellm
    volumes:
      - ./config.yaml:/app/config.yaml:ro
    healthcheck:
      test: ["CMD", "python", "-c", "import urllib.request; urllib.request.urlopen('http://localhost:4000/health/readiness', timeout=5)"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 15s
    networks:
      - litellm-net

volumes:
  litellm-db-data:

networks:
  litellm-net:
    driver: bridge
```

---

## Verificação

```bash
# Em cada host
curl -s http://localhost:4000/health/readiness
curl -s -H "Authorization: Bearer $LITELLM_MASTER_KEY" http://localhost:4000/v1/models | jq '.data[].id'

# OpenClaw
openclaw --model glm "teste"

# Claude-flow
claude --model glm "teste"
```

---

## Sincronização de config

**Repo é a base**. Para propagar alterações:

```bash
# 1. Editar config/litellm/config.yaml no agl-hostman
# 2. Deploy CT186 (canónico)
bash scripts/proxmox/bootstrap-ct186-litellm.sh   # ou pct exec 186 — ver LITELLM-OPENCLAW-DEDICATED-LXC.md
# 3. Réplicas opcionais
./scripts/litellm/sync-config-all-hosts.sh
./scripts/litellm/sync-fgsrv06.sh                 # só fgsrv06
```

---

## Arquivos relacionados

| Arquivo | Descrição |
|---------|-----------|
| `config/litellm/config.yaml` | Config padrão (LAN) |
| `config/litellm/config-remote.yaml` | Config para fgsrv06 (Ollama via Tailscale) |
| `docker/litellm/docker-compose-fgsrv06.yml` | Compose fgsrv06 (PostgreSQL + Redis + LiteLLM) |
| `config/litellm/.env.example` | Template de variáveis |
| `config/openclaw/litellm-gateway-local.env` | LITELLM_GATEWAY_URL=localhost:4000 |
| `scripts/openclaw/use-litellm-local.mjs` | Configura OpenClaw para local |
| `scripts/proxmox/bootstrap-ct186-litellm.sh` | Bootstrap inicial CT186 (Docker + `/opt/agl-litellm`) |
| `scripts/litellm/_litellm-sync-common.sh` | Funções partilhadas (repo → hosts; paths CT186 vs /opt/litellm) |
| `scripts/litellm/deploy-litellm-callbacks-ct186.sh` | Sync config + callbacks → CT186 (`/opt/agl-litellm`) |
| `scripts/litellm/replicate-all-hosts.sh` | Replica config + .env do repo → CT186 + agldv04/12/fgsrv06 |
| `scripts/litellm/deploy-litellm-host.sh` | Deploy em ct186/agldv04/12/fgsrv06 (config do repo) |
| `scripts/litellm/sync-config-all-hosts.sh` | Sync config repo → CT186 + agldv04, agldv12, fgsrv06 |
| `scripts/litellm/sync-fgsrv06.sh` | Sync config → fgsrv06 (variante remota) |
| `scripts/litellm/validate-all-hosts.sh` | Valida LiteLLM em todos os hosts (health + Docker) |
| `scripts/litellm/test-claude-code-all-hosts.sh` | Testa fluxo Claude Code (chat completion) em todos os hosts |
| `scripts/litellm/benchmark-models-all-hosts.sh` | Benchmark multi-model (glm-flash, glm, deepseek, etc.) — ordena por latência |
| `scripts/litellm/benchmark-consolidate.sh` | Benchmark consolidado — tabela comparativa entre hosts (Markdown + CSV) |

---

## IDs de modelo (sync com repo)

As listas de `model_list` seguem os identificadores das APIs (mar/2026): **OpenAI** flagship **`gpt-5.4`**; fluxo rápido **gpt-5.4-mini** com aliases LiteLLM `openai/gpt-5.3-chat-latest`, `openai/gpt-5.3-instant` e `gpt-5.3-instant` (mesmo backend). **Google** código API **`gemini-3.1-pro-preview`** (entradas `gemini-3.1-pro` / `google/*` no proxy). **Qwen (DashScope, modo OpenAI-compat):** `qwen3.5-plus-2026-02-15`, `qwen3-coder-plus`; **OpenRouter** fallback `openrouter/qwen/qwen3.5-plus-02-15` (slug diferente do DashScope). **Anthropic** `claude-*-4-6` / haiku snapshot. **Groq** (`groq-llama-33`, `groq-gpt-oss-120b`) requerem `GROQ_API_KEY` no `.env`. **OpenRouter** inclui `openrouter-free` e `openrouter-llama-3.2-3b-free`. Deploy: `config/litellm/config.yaml` → **CT186** (`/opt/agl-litellm`); réplicas agldv04/12 em `/opt/litellm`; **fgsrv06** usar `config/litellm/config-remote.yaml`; depois `docker compose up -d --force-recreate litellm-proxy`. **agldv03:** descontinuado (2026-06-05).

**Maintainer**: agl-hostman  
**Relacionado**: [CLAUDE-FLOW-LITELLM.md](CLAUDE-FLOW-LITELLM.md), [OPENCLAW.md](OPENCLAW.md), [CURSOR-LITELLM-INTEGRATION.md](CURSOR-LITELLM-INTEGRATION.md)
