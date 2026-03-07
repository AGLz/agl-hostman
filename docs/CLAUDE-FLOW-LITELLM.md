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

**Deploy completo**: `./scripts/ruflo-deploy-agldv03.sh` — ver `docs/RUFLO-ADVANCED.md`

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

O script `./scripts/deploy-openclaw-config.sh` aplica:

| Host      | IP            | OpenClaw | Multi-model (LiteLLM)      |
|-----------|---------------|----------|----------------------------|
| agldv03   | 100.94.221.87 | ✅       | Gateway (localhost:4000)   |
| fgsrv6    | 100.83.51.9   | ✅       | Gateway (localhost:4000)   |
| agldv04   | 100.113.9.98  | ❌       | Cliente → agldv03:4000     |
| agldv05   | 100.119.41.63 | ❌       | Cliente → agldv03:4000     |
| agldv06   | 100.71.229.12 | ❌       | Cliente → agldv03:4000     |

**Gateway central**: agldv03. Para clientes (agldv04/05/06) funcionarem, o LiteLLM deve estar rodando em agldv03:

```bash
# Em agldv03 (ou onde o repo está)
./scripts/litellm/start.sh
```

---

## Arquivos criados

| Arquivo                         | Descrição                    |
|---------------------------------|------------------------------|
| `config/litellm/config.yaml`    | Modelos, fallbacks, settings  |
| `config/litellm/.env.example`   | Template de variáveis        |
| `config/openclaw/litellm-gateway-client.env` | Override para hosts cliente |
| `docker/litellm/docker-compose.yml` | Stack Docker LiteLLM     |
| `scripts/litellm/start.sh`      | Script de inicialização       |

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
