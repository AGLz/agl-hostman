# MCP Implementation Guide - AGL Hostman

**Data**: 2026-02-14 | **Versão**: 1.0.0

## 📋 Resumo Executivo

Este guia fornece implementação completa do MCP Runtime Layer no projeto AGL Hostman, seguindo as melhores práticas pesquisadas.

**Pré-requisitos**:
- Docker e Docker Compose
- Node.js 18+
- Redis (para caching)
- Prometheus (para métricas)

---

## 🚀 Implementação Rápida

### 1. Configurar Variáveis de Ambiente

```bash
# Copiar arquivo de exemplo
cp mcp-runtime/.env.example mcp-runtime/.env

# Editar variáveis
nano mcp-runtime/.env
```

**Variáveis Obrigatórias**:
```bash
# Authentication
GITHUB_TOKEN=ghp_xxxxxxxxxxxx
PROXMOX_TOKEN=your_proxmox_token_here
ARCHON_TOKEN=your_archon_token_here

# Rate Limiting
DEFAULT_RATE_LIMIT=60
DEFAULT_BURST=10

# Caching
REDIS_HOST=localhost
REDIS_PORT=6379
DEFAULT_CACHE_TTL=3600

# Metrics
PROMETHEUS_PORT=9090
TOKEN_TRACKING=true
LATENCY_TRACKING=true
```

### 2. Iniciar com Docker Compose

```bash
cd mcp-runtime

# Iniciar serviços
docker compose up -d

# Ver logs
docker compose logs -f mcp-runtime
```

**Serviços Iniciados**:
- `mcp-runtime` (porta 3000) - API principal
- `redis` (porta 6379) - Cache
- `prometheus` (porta 9090) - Métricas

### 3. Verificar Saúde dos Serviços

```bash
# Health check
curl http://localhost:3000/health

# Métricas
curl http://localhost:3000/metrics

# Status
curl http://localhost:3000/status
```

### 4. Integração com Archon

```typescript
// No projeto AGL Hostman
import { MCPRuntime } from './mcp-runtime/src/runtime'

const runtime = new MCPRuntime({
  auth: authManager,
  rateLimiter: rateLimiter,
  errorHandler: errorHandler,
  cache: cacheManager,
  metrics: metricsCollector,
})

// Uso em ferramentas existentes
const result = await runtime.callTool('archon_search_knowledge', {
  query: 'wireguard mesh',
  matchCount: 5
})
```

---

## 📊 Monitoramento

### Métricas Disponíveis

#### Acesso via Prometheus

```bash
# Métricas em formato Prometheus
curl http://localhost:9090/metrics

# Métricas específicas
curl http://localhost:9090/metrics | grep mcp_tool_calls_total
curl http://localhost:9090/metrics | grep mcp_tool_tokens_total
curl http://localhost:9090/metrics | grep mcp_tool_latency_seconds
```

#### Métricas Principais

| Métrica | Descrição | Tipo |
|----------|------------|------|
| `mcp_tool_calls_total` | Total de tool calls | Counter |
| `mcp_tool_tokens_total` | Tokens consumidos | Counter |
| `mcp_tool_latency_seconds` | Latência média | Gauge |
| `mcp_tool_success_rate` | Taxa de sucesso | Gauge |
| `mcp_cache_hit_rate` | Taxa de cache hit | Gauge |
| `mcp_rate_limit_hits` | Hits de rate limit | Counter |

### Dashboard (Grafana)

**Configuração Recomendada**:

```json
{
  "dashboard": {
    "title": "MCP Runtime Layer",
    "panels": [
      {
        "title": "Tool Calls (Rate)",
        "targets": [
          {
            "expr": "rate(mcp_tool_calls_total[5m])"
          }
        ]
      },
      {
        "title": "Token Usage",
        "targets": [
          {
            "expr": "rate(mcp_tool_tokens_total[5m])"
          }
        ]
      },
      {
        "title": "Average Latency",
        "targets": [
          {
            "expr": "mcp_tool_latency_seconds"
          }
        ]
      },
      {
        "title": "Success Rate",
        "targets": [
          {
            "expr": "mcp_tool_success_rate"
          }
        ]
      },
      {
        "title": "Cache Hit Rate",
        "targets": [
          {
            "expr": "mcp_cache_hit_rate"
          }
        ]
      }
    ]
  }
}
```

---

## 🧪 Testes

### Testes de Integração

```bash
# Testar autenticação
curl -X POST http://localhost:3000/test/auth \
  -H "Content-Type: application/json" \
  -d '{"toolName":"github_api"}'

# Testar rate limiting
curl -X POST http://localhost:3000/test/rate-limit \
  -H "Content-Type: application/json" \
  -d '{"toolName":"github_api"}'

# Testar caching
curl -X POST http://localhost:3000/test/cache \
  -H "Content-Type: application/json" \
  -d '{"key":"test_key","value":"test_value"}'

# Testar error handling
curl -X POST http://localhost:3000/test/error-handling \
  -H "Content-Type: application/json" \
  -d '{"toolName":"github_api","error":"Test error"}'
```

### Testes de Carga

```bash
# Testar 100 tool calls sequenciais
for i in {1..100}; do
  curl http://localhost:3000/status &
done
wait

# Verificar métricas
curl http://localhost:3000/metrics | grep mcp_tool_calls_total
```

---

## 🔧 Configuração Avançada

### Rate Limiting Personalizado

```yaml
# config/runtime.yml
rateLimiting:
  perTool:
    github_api: 100      # 100 requests/min
    proxmox_api: 30       # 30 requests/min
    harbor_api: 50        # 50 requests/min
    archon_api: 80        # 80 requests/min
```

### Caching Inteligente

```yaml
# config/runtime.yml
caching:
  perCategory:
    tool_discovery: 7200   # 2 hours (mudança rara)
    tool_responses: 3600    # 1 hour (dados dinâmicos)
    user_sessions: 1800    # 30 min (sessões ativas)
```

### Métricas Personalizadas

```typescript
// Adicionar métricas customizadas
runtime.config.metrics.recordCustomMetric('custom_operation', {
  duration: 1234,
  metadata: { user_id: '123', operation: 'backup' }
})
```

---

## 📚 Referências de Uso

### Exemplo 1: Tool Call Básico

```typescript
import { runtime } from './mcp-runtime'

const result = await runtime.callTool('github_search_repos', {
  query: 'language:typescript stars:>1000',
  perPage: 10,
})

if (result.success) {
  console.log('Repos found:', result.data)
} else {
  console.error('Error:', result.error)
  if (result.retryable) {
    console.log('This operation can be retried')
  }
}
```

### Exemplo 2: Tool Call com Retry

```typescript
// O runtime layer automaticamente retrya falhas
// Mas também pode ser feito manualmente
const result = await runtime.callTool('proxmox_list_vms', {
  type: 'vm'
})

if (!result.success && result.retryable) {
  console.log('Retrying in 5 seconds...')
  await new Promise(resolve => setTimeout(resolve, 5000))
  const retry = await runtime.callTool('proxmox_list_vms', {
    type: 'vm'
  })
}
```

### Exemplo 3: Métricas por Tool

```typescript
const metrics = await runtime.getMetrics()
const githubMetrics = metrics.perToolMetrics.github_api

console.log({
  calls: githubMetrics.calls,
  avgTokensPerCall: githubMetrics.tokens / githubMetrics.calls,
  avgLatency: githubMetrics.totalLatency / githubMetrics.calls,
  successRate: (githubMetrics.calls - githubMetrics.errors) / githubMetrics.calls,
  cacheHitRate: githubMetrics.cacheHits / githubMetrics.calls,
})
```

---

## 🐛 Troubleshooting

### Problema: Redis não conecta

```bash
# Verificar se Redis está rodando
docker ps | grep redis

# Verificar logs do Redis
docker compose logs redis

# Testar conexão
redis-cli -h localhost -p 6379 ping
```

### Problema: Rate limits muito baixos

```yaml
# Aumentar limites padrão
rateLimiting:
  default:
    requestsPerMinute: 120  # Aumentar de 60
    burst: 20                # Aumentar de 10
```

### Problema: Cache não funciona

```bash
# Invalidar cache completamente
curl -X POST http://localhost:3000/invalidate-cache \
  -H "Content-Type: application/json" \
  -d '{"pattern":"*"}'

# Verificar estatísticas do cache
redis-cli -h localhost -p 6379 info stats
```

### Problema: Métricas não aparecem no Prometheus

```bash
# Verificar se Prometheus está coletando
curl http://localhost:9090/metrics | grep mcp

# Verificar configuração do Prometheus
docker compose logs prometheus | grep error

# Reiniciar Prometheus
docker compose restart prometheus
```

---

## 📈 Próximos Passos

1. ✅ Documento de melhores práticas criado
2. ✅ MCP Runtime Layer implementado
3. ✅ Docker Compose configurado
4. ⏳ Integração com ferramentas existentes
5. ⏳ Testes completos de integração
6. ⏳ Dashboard Grafana configurado
7. ⏳ Métricas personalizadas implementadas
8. ⏳ Documentação de API completa
9. ⏳ Sistema de alertas configurado
10. ⏳ Testes de carga executados

---

## 📚 Documentação Relacionada

- [MCP Best Practices Guide](/mnt/overpower/apps/dev/agl/agl-hostman/docs/MCP-BEST-PRACTICES.md)
- [MCP Runtime Layer README](/mnt/overpower/apps/dev/agl/agl-hostman/mcp-runtime/README.md)
- [Archon Integration Guide](/mnt/overpower/apps/dev/agl/agl-hostman/docs/ARCHON.md)
- [INFRA.md](/mnt/overpower/apps/dev/agl/agl-hostman/docs/INFRA.md)

---

**Versão**: 1.0.0
**Autor**: Claude Code (agl-hostman)
**Data**: 2026-02-14
