# Claude-Flow + LiteLLM — Multi-Model e Fallback

> **Last Updated**: 2026-02-19  
> **Integração**: Claude-Flow (Ruflo) v3.1.x + LiteLLM Proxy

## Visão geral

O **Claude-Flow/Ruflo** já oferece suporte nativo a múltiplos modelos e failover. Para centralizar roteamento, fallbacks e custo, a abordagem recomendada é usar o **LiteLLM** como gateway.

### Fluxo de arquitetura

```
Claude Code / CLI  →  LiteLLM Proxy (:4000)  →  LLM Providers
       │                      │
       │              ┌───────┴───────┐
       │              │  Fallbacks    │
       │              │  Load Bal     │
       │              └───────────────┘
       │
       └── ANTHROPIC_BASE_URL + ANTHROPIC_AUTH_TOKEN
```

---

## Quick start (5 minutos)

### 1. Configurar ambiente

```bash
# Copiar e editar .env
cp config/litellm/.env.example config/litellm/.env
# Adicionar LITELLM_MASTER_KEY e pelo menos um provider (ZAI_API_KEY, etc.)
```

### 2. Iniciar LiteLLM

```bash
./scripts/litellm/start.sh
# ou
docker compose -f docker/litellm/docker-compose.yml up -d
```

### 3. Configurar Claude Code / Claude-Flow

```bash
export ANTHROPIC_BASE_URL=http://localhost:4000
export ANTHROPIC_AUTH_TOKEN=sk-your-master-key  # = LITELLM_MASTER_KEY do .env
```

### 4. Testar

```bash
claude --model claude-sonnet "Hello, world!"
claude --model glm "Hello, world!"
claude --model deepseek "Explique este código"
claude --model kimi "Resuma este documento longo"
```

---

## Modelos disponíveis (config AGL)

> **Última atualização**: 2026-02 — modelos mais recentes por provider

| Alias          | Provider   | Modelo                    | Contexto | Uso principal        |
|----------------|------------|---------------------------|----------|----------------------|
| `claude-opus`  | Anthropic  | claude-opus-4-6           | 200k/1M  | Premium, agentes     |
| `claude-sonnet`| Anthropic  | claude-sonnet-4-6         | 200k/1M  | Balanceado, PRO      |
| `claude-haiku` | Anthropic  | claude-haiku-4-5          | 200k     | Rápido, barato       |
| `glm`          | ZAI        | glm-4.7                   | 200k     | Primário, uso geral  |
| `glm-flash`  | ZAI        | glm-4.5-flash             | 128k     | Gratuito, rápido     |
| `glm-5`      | OpenRouter | z-ai/glm-5                | 205k     | Código, agentes      |
| `kimi`       | Moonshot   | kimi-k2.5                 | 256k     | Contexto longo       |
| `kimi-128k`  | Moonshot   | moonshot-v1-128k          | 128k     | Fallback Kimi        |
| `deepseek`   | DeepSeek   | deepseek-chat (V3.2)      | 128k     | Código               |
| `r1`         | DeepSeek   | deepseek-reasoner         | 128k     | Raciocínio           |
| `gpt`        | OpenAI     | gpt-5.2                   | -        | Mais recente OpenAI  |
| `gpt-4o`     | OpenAI     | gpt-4o                    | 128k     | Fallback robusto     |
| `gpt-mini`   | OpenAI     | gpt-4o-mini               | 128k     | Rápido               |
| `gemini`     | Google     | gemini-2.5-flash          | 1M       | Mais recente Gemini  |
| `gemini-2.0` | Google     | gemini-2.0-flash          | 1M       | Fallback Gemini      |
| `glm-free`   | OpenRouter | glm-4.5-air:free          | 128k     | Gratuito             |
| `qwen-coder` | OpenRouter | qwen-3-coder              | 64k      | Código               |
| `qwen3.5-plus` | OpenRouter | qwen3.5-plus-02-15      | 1M       | Contexto longo       |

---

## 3-tier router (Ruflo v3.5+)

O **3-tier router** (SONA) complementa o fallback do LiteLLM: escolhe o modelo ideal **por tipo de tarefa** antes de chamar, economizando ~75% em custos de API.

| Aspecto | LiteLLM (fallback) | 3-tier router |
|---------|-------------------|---------------|
| **Quando** | Modelo falha / excede contexto | Antes de chamar |
| **Critério** | Erro | Tipo de tarefa |
| **Economia** | Resiliência | ~75% custo API |

```bash
# Roteamento inteligente por tipo de tarefa
npx agentic-flow@alpha hooks intel route "Optimize database queries" --top-k 3
npx ruflo@latest hooks intel route "Build REST API" --top-k 3
```

**Deploy completo**: `./scripts/ruflo-deploy-agldv03.sh [host]` — ver `docs/RUFLO-ADVANCED.md`  
**Sync config multi-host**: `./scripts/ruflo/sync-config-all-hosts.sh` — ver `docs/CLAUDE-FLOW-CONFIG.md`

---

## Cadeias de fallback

O LiteLLM aplica fallbacks automaticamente quando o modelo primário falha ou excede o contexto:

| Cenário        | Fallback automático                          |
|----------------|----------------------------------------------|
| `glm` falha    | glm-flash → deepseek → glm-free              |
| `kimi` falha   | gemini → deepseek                            |
| `deepseek` falha | gpt → kimi                                 |
| `r1` falha     | deepseek → gpt                               |
| Contexto excedido (glm) | kimi → gemini                        |

---

## Variáveis de ambiente

### Para o LiteLLM (config/litellm/.env)

| Variável           | Obrigatório | Descrição                    |
|--------------------|-------------|------------------------------|
| `LITELLM_MASTER_KEY` | Sim        | Chave de autenticação do proxy |
| `ANTHROPIC_API_KEY` | Recomendado | Claude (conta PRO)           |
| `ZAI_API_KEY`      | Recomendado | GLM/Z.AI (GLM_AUTH no OpenClaw) |
| `MOONSHOT_API_KEY`| Opcional   | Kimi (KIMI_AUTH no OpenClaw)  |
| `DEEPSEEK_API_KEY`| Opcional   | DeepSeek (DEEPSEEK_AUTH)     |
| `OPENAI_API_KEY`  | Opcional   | OpenAI                       |
| `GEMINI_API_KEY`  | Opcional   | Google Gemini                |
| `OPENROUTER_API_KEY` | Opcional | OpenRouter (fallbacks free)   |

### Para Claude Code / Claude-Flow

```bash
export ANTHROPIC_BASE_URL=http://localhost:4000
export ANTHROPIC_AUTH_TOKEN=$LITELLM_MASTER_KEY  # mesma chave do .env
```

**Config no repositório**: `.claude/settings.json` já define `ANTHROPIC_BASE_URL=http://localhost:4000` e `ANTHROPIC_AUTH_TOKEN=sk-litellm-default` para uso com LiteLLM local.

### Compatibilidade com OpenClaw

Se já usa `~/.zshrc` com `GLM_AUTH`, `KIMI_AUTH`, etc.:

```bash
export ZAI_API_KEY=$GLM_AUTH
export MOONSHOT_API_KEY=$KIMI_AUTH
export DEEPSEEK_API_KEY=$DEEPSEEK_AUTH
```

---

## Verificação

```bash
# Health check
curl -s http://localhost:4000/health \
  -H "Authorization: Bearer $LITELLM_MASTER_KEY" | jq .

# Listar modelos
curl -s http://localhost:4000/models \
  -H "Authorization: Bearer $LITELLM_MASTER_KEY" | jq .

# Teste de completão
curl -X POST http://localhost:4000/chat/completions \
  -H "Authorization: Bearer $LITELLM_MASTER_KEY" \
  -H "Content-Type: application/json" \
  -d '{"model": "glm", "messages": [{"role": "user", "content": "Hello!"}]}'
```

### Testes de integração (LiteLLM + Claude-Flow + Turbo-Flow)

```bash
# Executar cenários e caso de uso real
npm run test:integration:litellm
```

**Cenários cobertos:**
- LiteLLM health/readiness
- LiteLLM models list (requer `LITELLM_MASTER_KEY` válido)
- **Multi-model latency**: glm-flash, glm, deepseek, claude-haiku, gemini-2.0 — ordena por velocidade
- **Modelos gratuitos**: glm-flash, glm-air, qwen-turbo, qwen-plus, qwen3.5-plus — ordena por velocidade
- Chat completion via LiteLLM (caso de uso: analisar estrutura de projeto)
- API hostman `GET /api/ai/status`
- Ruflo daemon status
- Ruflo 3-tier router (`hooks intel route`)
- Turbo Flow status

**Benchmark multi-model em todos os hosts:**
```bash
./scripts/litellm/benchmark-models-all-hosts.sh
./scripts/litellm/benchmark-models-all-hosts.sh --free   # apenas gratuitos (qwen, glm-air)
./scripts/litellm/test-claude-code-all-hosts.sh --benchmark
```

**Resultados consolidados (tabela comparativa):**
```bash
./scripts/litellm/benchmark-consolidate.sh           # gera docs/litellm-benchmark/benchmark-*.md e *.csv
./scripts/litellm/benchmark-consolidate.sh --free   # apenas modelos gratuitos
```

**Variáveis:**
- `LITELLM_BASE_URL` (default: http://localhost:4000)
- `LITELLM_MASTER_KEY` (para testes com auth)
- `SKIP_LIVE_LITELLM=1` (pula testes que exigem LiteLLM online)

---

## Integração MCP (Claude-Flow)

Para usar o Claude-Flow MCP com LiteLLM:

```bash
# Adicionar servidor MCP
claude mcp add ruflo -- npx -y ruflo@latest mcp start

# As variáveis ANTHROPIC_* devem apontar para o LiteLLM
export ANTHROPIC_BASE_URL=http://localhost:4000
export ANTHROPIC_AUTH_TOKEN=$LITELLM_MASTER_KEY
```

---

## Deploy em hosts AGL

**Modelo multi-host** (cada host com LiteLLM local): agldv03, agldv04, agldv12, fgsrv06.

| Host      | IP            | LiteLLM local | OpenClaw/Claude-flow |
|-----------|---------------|---------------|----------------------|
| agldv03   | 100.94.221.87 | ✅ localhost:4000 | localhost:4000 |
| agldv04   | 100.113.9.98  | ✅ localhost:4000 | localhost:4000 |
| agldv12   | 100.71.217.115| ✅ localhost:4000 | localhost:4000 |
| fgsrv06   | 100.83.51.9   | ✅ localhost:4000 | localhost:4000 |

**Deploy**: Ver [LITELLM-MULTI-HOST-DEPLOYMENT.md](LITELLM-MULTI-HOST-DEPLOYMENT.md)

```bash
# Deploy em host específico
./scripts/litellm/deploy-litellm-host.sh agldv04
./scripts/litellm/deploy-litellm-host.sh fgsrv06

# Em cada host: configurar OpenClaw para local
node scripts/openclaw/use-litellm-local.mjs
```

**Hosts legados** (agldv05, agldv06) sem LiteLLM local: usar `litellm-gateway-client.env` apontando para agldv03.

---

## Arquivos criados

| Arquivo                         | Descrição                    |
|---------------------------------|------------------------------|
| `config/litellm/config.yaml`    | Modelos, fallbacks (LAN)      |
| `config/litellm/config-remote.yaml` | Config para fgsrv06 (Ollama via Tailscale) |
| `config/litellm/.env.example`   | Template de variáveis        |
| `config/openclaw/litellm-gateway-local.env` | localhost:4000 (hosts com LiteLLM) |
| `config/openclaw/litellm-gateway-client.env` | Override para hosts legados (agldv05/06) |
| `docker/litellm/docker-compose.yml` | Stack Docker LiteLLM     |
| `scripts/litellm/start.sh`      | Inicialização (repo local)    |
| `scripts/litellm/deploy-litellm-host.sh` | Deploy em host remoto  |
| `scripts/litellm/sync-config-all-hosts.sh` | Sync config para todos |

---

## Troubleshooting

- **401 Unauthorized**: Use `Authorization: Bearer $LITELLM_MASTER_KEY` ou endpoints públicos `/health/readiness`, `/health/liveliness`
- **Container unhealthy**: O healthcheck padrão usa `/health` (exige auth). Use o compose em `docker/litellm/docker-compose.yml` que usa `/health/readiness`
- **Guia completo**: [docs/LITELLM-TROUBLESHOOTING.md](LITELLM-TROUBLESHOOTING.md)

---

## Referências

- [Claude-Flow LiteLLM Wiki](https://github.com/ruvnet/claude-flow/wiki/litellm-integration)
- [LiteLLM Proxy Config](https://docs.litellm.ai/docs/proxy/configs)
- [Claude Code LLM Gateway](https://docs.claude.com/en/docs/claude-code/llm-gateway)
- [OpenClaw Multi-Model](docs/OPENCLAW.md) — cadeia de fallback AGL
- [Ruflo Advanced](docs/RUFLO-ADVANCED.md) — 3-tier router, RuVector, Hive Mind, ReasoningBank

---

**Maintainer**: agl-hostman  
**Relacionado**: `docs/OPENCLAW.md`, `docs/FREE-LLM-MODELS.md`, `docs/RUFLO-ADVANCED.md`
