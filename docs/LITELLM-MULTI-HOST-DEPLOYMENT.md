# LiteLLM Multi-Host Deployment — Local em Cada Host

> **Objetivo**: LiteLLM com config e DB locais em agldv03, agldv04, agldv12 e fgsrv06.  
> **Regra**: OpenClaw e Claude-flow em cada host usam **localhost:4000**, nunca o gateway remoto do agldv03.

**OpenClaw no agldv12**: o CT **agldv12** é clone do ambiente de dev; **não** deve correr o gateway OpenClaw em paralelo ao agldv03 (Telegram/bots duplicados, estado partilhado). Serviço `openclaw-gateway.service` (**systemd --user**) mantido **desativado**; ficheiros da unit renomeados para `*.disabled-on-clone` no host. LiteLLM no agldv12 pode permanecer para testes multi-host se necessário.

---

## Visão geral

**Base**: agldv03 é a fonte das configs (`/opt/litellm/config.yaml`). Sync propaga para agldv04, agldv12, fgsrv06. Se agldv03 rodar do repo, copie a config para `/opt/litellm/` antes do sync.

| Host | Tailscale IP | Rede | Config | Ollama | Redis |
|------|--------------|------|--------|--------|-------|
| **agldv03** | 100.94.221.87 | LAN AGLSRV1 | `config.yaml` | 192.168.0.200 | 192.168.0.137 |
| **agldv04** | 100.113.9.98 | LAN AGLSRV1 | `config.yaml` | 192.168.0.200 | 192.168.0.137 |
| **agldv12** | 100.71.217.115 | LAN AGLSRV1 | `config.yaml` | 192.168.0.200 | 192.168.0.137 |
| **fgsrv06** | 100.83.51.9 | Cloud VPS | `config-remote.yaml` | 100.116.57.111 (TS) | litellm-redis (Docker) |

**Nota (2026-04) — alias `agl-primary` (LAN, `config.yaml`)**: no agldv03/04/12 o primário Ollama local é **`ollama/qwen3:4b`** (CT200 `192.168.0.200:11434`); **`ollama-nemotron-3-nano-4b`** fica na cadeia de fallbacks. No **fgsrv06** o `agl-primary` em `config-remote.yaml` continua a ser **DashScope `qwen3.5-flash`**, com Ollama CT200 só como fallback via Tailscale.

---

## Pré-requisitos por host

1. **Docker** e **Docker Compose** instalados
2. **Acesso SSH** como root
3. **API keys** no `.env` (Anthropic, ZAI, DeepSeek, etc.)
4. **`LITELLM_MASTER_KEY`** (recomendada em `/opt/litellm/.env`): ver `config/litellm/.env.example`. Sem esta variável o LiteLLM pode aceitar pedidos **sem** cabeçalho `Authorization` (útil em LAN fechada; **evitar** se a porta 4000 for acessível fora da equipa). Os scripts em `scripts/litellm/` usam `_litellm-master-key.sh` e omitam `Bearer` se a chave estiver vazia.
5. **Tailscale** (fgsrv06 precisa para Ollama via 100.116.57.111)

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
# Do repositório agl-hostman (agldv03 ou máquina com acesso)
./scripts/litellm/deploy-litellm-host.sh <host>
# Ex: ./scripts/litellm/deploy-litellm-host.sh agldv04
# Ex: ./scripts/litellm/deploy-litellm-host.sh fgsrv06
```

### 3. Sync de config (agldv03 → demais)

```bash
# Propagar config do agldv03 (base) para agldv04, agldv12, fgsrv06
./scripts/litellm/sync-config-all-hosts.sh
```

### 4. Deploy manual (por host)

#### Hosts LAN (agldv03, agldv04, agldv12)

```bash
# No host de destino (ex: ssh root@100.113.9.98)
mkdir -p /opt/litellm
cd /opt/litellm

# Copiar config do agldv03 (base): scp root@100.94.221.87:/opt/litellm/config.yaml .

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
# Usar config-remote.yaml (Ollama via Tailscale 100.116.57.111)
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
**Não usar** `litellm-gateway-client.env` (que aponta para agldv03 remoto).

---

## Variantes de config

### config.yaml (hosts LAN)

- Ollama: `http://192.168.0.200:11434` (CT200)
- Redis: `192.168.0.137:6379` (CT137)
- Todos os modelos cloud + Ollama local

### config-remote.yaml (fgsrv06)

- Ollama: `http://100.116.57.111:11434` (CT200 via Tailscale)
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

**agldv03 é a base**. Para propagar alterações para os demais hosts:

```bash
# Sync agldv03 → agldv04, agldv12, fgsrv06
./scripts/litellm/sync-config-all-hosts.sh

# Apenas fgsrv06
./scripts/litellm/sync-fgsrv06.sh
```

Edite a config em agldv03 (`/opt/litellm/config.yaml`) e rode o sync.

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
| `scripts/litellm/deploy-litellm-host.sh` | Deploy em host (agldv04/12/fgsrv06 puxam config de agldv03) |
| `scripts/litellm/sync-config-all-hosts.sh` | Sync agldv03 → agldv04, agldv12, fgsrv06 |
| `scripts/litellm/sync-fgsrv06.sh` | Sync agldv03 → fgsrv06 (variante remota) |
| `scripts/litellm/validate-all-hosts.sh` | Valida LiteLLM em todos os hosts (health + Docker) |
| `scripts/litellm/test-claude-code-all-hosts.sh` | Testa fluxo Claude Code (chat completion) em todos os hosts |
| `scripts/litellm/benchmark-models-all-hosts.sh` | Benchmark multi-model (glm-flash, glm, deepseek, etc.) — ordena por latência |
| `scripts/litellm/benchmark-consolidate.sh` | Benchmark consolidado — tabela comparativa entre hosts (Markdown + CSV) |

---

## IDs de modelo (sync com repo)

As listas de `model_list` seguem os identificadores das APIs (mar/2026): **OpenAI** flagship **`gpt-5.4`**; fluxo rápido **gpt-5.4-mini** com aliases LiteLLM `openai/gpt-5.3-chat-latest`, `openai/gpt-5.3-instant` e `gpt-5.3-instant` (mesmo backend). **Google** código API **`gemini-3.1-pro-preview`** (entradas `gemini-3.1-pro` / `google/*` no proxy). **Qwen (DashScope, modo OpenAI-compat):** `qwen3.5-plus-2026-02-15`, `qwen3-coder-plus`; **OpenRouter** fallback `openrouter/qwen/qwen3.5-plus-02-15` (slug diferente do DashScope). **Anthropic** `claude-*-4-6` / haiku snapshot. **Groq** (`groq-llama-33`, `groq-gpt-oss-120b`) requerem `GROQ_API_KEY` no `.env`. **OpenRouter** inclui `openrouter-free` e `openrouter-llama-3.2-3b-free`. Deploy: `config/litellm/config.yaml` → agldv03 (e clones com mesma stack); **fgsrv06** usar `config/litellm/config-remote.yaml` como `/opt/litellm/config.yaml`; depois `docker compose up -d --force-recreate litellm-proxy`.

**Maintainer**: agl-hostman  
**Relacionado**: [CLAUDE-FLOW-LITELLM.md](CLAUDE-FLOW-LITELLM.md), [OPENCLAW.md](OPENCLAW.md), [CURSOR-LITELLM-INTEGRATION.md](CURSOR-LITELLM-INTEGRATION.md)
