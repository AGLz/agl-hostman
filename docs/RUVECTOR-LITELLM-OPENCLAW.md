# RuVector + LiteLLM + OpenClaw Integration

> **Last Updated**: 2026-03-13
> **Hosts**: agldv03 (100.94.221.87), fgsrv06 (100.83.51.9)

## Visão Geral

Integração tripla para criar um sistema de memória vetorial compartilhada entre agentes AI:

```
┌──────────────────────────────────────────────────────────────┐
│                    Claude Code / Cursor                       │
│                 (via OpenClaw config)                        │
└─────────────────────────┬────────────────────────────────────┘
                          │
                          ▼
┌──────────────────────────────────────────────────────────────┐
│                     OpenClaw                                  │
│  gateway.mode=local → LiteLLM (:4000)                       │
│  memory.backend=ruvector                                     │
└─────────────────────────┬────────────────────────────────────┘
                          │
          ┌───────────────┴───────────────┐
          ▼                               ▼
┌──────────────────────┐      ┌──────────────────────┐
│      LiteLLM         │      │      RuVector        │
│  Model routing       │      │  Vector memory       │
│  Fallback chains     │      │  HNSW search         │
│  Redis cache         │      │  PostgreSQL          │
└──────────────────────┘      └──────────────────────┘
```

## Componentes

### 1. RuVector (Vector Store)

O RuVector é o sistema de memória vetorial do RuFlo/Claude-Flow:

```bash
# Inicialização
npx ruflo@latest ruvector init --database agl_ruvector --user admin

# Benchmark
npx ruflo@latest ruvector benchmark --iterations 1000

# Otimização
npx ruflo@latest ruvector optimize --analyze
```

**Configuração**: `config/ruflo/ruvector.env`

### 2. LiteLLM (Model Gateway)

Gateway multi-modelo com fallbacks:

```bash
# Iniciar proxy
./scripts/litellm/start.sh

# Verificar modelos
curl -s http://localhost:4000/models -H "Authorization: Bearer $LITELLM_MASTER_KEY"
```

**Configuração**: `config/litellm/config.yaml`

### 3. OpenClaw (Claude Desktop Wrapper)

Wrapper para Claude Desktop com suporte multi-model:

```bash
# Status
openclaw status

# Configurar
openclaw config set gateway.mode local
openclaw config set gateway.endpoint http://localhost:4000
```

**Configuração**: `~/.openclaw/openclaw.json`

## Integração

### Variáveis de Ambiente Compartilhadas

```bash
# ~/.openclaw/zshrc-openclaw.env

# LiteLLM Gateway
ANTHROPIC_BASE_URL=http://localhost:4000
ANTHROPIC_AUTH_TOKEN=$LITELLM_MASTER_KEY

# RuVector
RUVECTOR_DATABASE_URL=postgresql://user:pass@localhost:5432/agl_ruvector
RUVECTOR_NAMESPACE=agl-agents

# OpenClaw
OPENCLAW_GATEWAY_MODE=local
OPENCLAW_MEMORY_BACKEND=ruvector
```

### Fluxo de Dados

1. **Agente solicita memória** → OpenClaw detecta necessidade
2. **OpenClaw consulta RuVector** → Busca semântica HNSW
3. **RuVector retorna contexto** → Embeddings relevantes
4. **OpenClaw envia para LiteLLM** → Com contexto enriquecido
5. **LiteLLM roteia para modelo** → Com fallback automático
6. **Resposta processada** → Memória atualizada no RuVector

### Namespaces RuVector

| Namespace | Uso | TTL |
|-----------|-----|-----|
| `agents` | Estado de agentes | 7 dias |
| `patterns` | Padrões ReasoningBank | 30 dias |
| `infrastructure` | Configs de infra | 90 dias |
| `docs` | Documentação | 365 dias |
| `sessions` | Sessões ativas | 1 dia |

### Sincronização Multi-Host

```bash
# agldv03 → fgsrv06
npx ruflo@latest ruvector sync --target 100.83.51.9 --namespace agents

# Status de replicação
npx ruflo@latest ruvector status --replication
```

## Uso via CLI

### Memória

```bash
# Armazenar
npx ruflo@latest memory store "auth-pattern" "JWT + refresh tokens" --namespace patterns

# Buscar
npx ruflo@latest memory search "authentication" --namespace patterns --limit 5

# Listar
npx ruflo@latest memory list --namespace agents
```

### Integração Claude-Flow

```bash
# Com ReasoningBank
npx claude-flow@alpha memory store "api-config" "REST API config" --namespace backend --reasoningbank

# Query com HNSW
npx claude-flow@alpha memory query "API config" --namespace backend --reasoningbank
```

## Configuração PostgreSQL

### Criar extensões

```sql
-- Conectar ao banco agl_ruvector
CREATE EXTENSION IF NOT EXISTS vector;
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- Tabela de embeddings
CREATE TABLE IF NOT EXISTS ruvector_embeddings (
    id SERIAL PRIMARY KEY,
    namespace VARCHAR(255) NOT NULL,
    key VARCHAR(512) NOT NULL,
    content TEXT NOT NULL,
    embedding vector(1536),
    metadata JSONB,
    created_at TIMESTAMP DEFAULT NOW(),
    expires_at TIMESTAMP,
    UNIQUE(namespace, key)
);

-- Índice HNSW
CREATE INDEX IF NOT EXISTS ruvector_hnsw_idx
ON ruvector_embeddings
USING hnsw (embedding vector_cosine_ops)
WITH (M = 16, ef_construction = 64);

-- Índice de namespace
CREATE INDEX IF NOT EXISTS ruvector_namespace_idx
ON ruvector_embeddings (namespace);
```

## Troubleshooting

| Problema | Solução |
|----------|---------|
| RuVector não conecta | Verificar `RUVECTOR_DATABASE_URL` |
| Embeddings não encontrados | Verificar namespace e TTL |
| Sync falha | Verificar conectividade WireGuard/Tailscale |
| LiteLLM timeout | Aumentar `timeout` no config.yaml |
| OpenClaw não usa LiteLLM | Verificar `gateway.mode=local` |

## Referências

- [Ruflo Advanced](RUFLO-ADVANCED.md)
- [Claude-Flow LiteLLM](CLAUDE-FLOW-LITELLM.md)
- [OpenClaw Multi-Model](OPENCLAW.md)
- [Cursor Integration](CURSOR-LITELLM-INTEGRATION.md)
