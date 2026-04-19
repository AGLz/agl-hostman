# Ruflo / Claude-Flow — Recursos Avançados AGL

> **Last Updated**: 2026-03-01  
> **Host alvo**: agldv03 (CT179) — 100.94.221.87  
> **Path no agldv03**: `/mnt/overpower/apps/dev/agl/agl-hostman` (mesma pasta que local)  
> **Integração**: LiteLLM (multi-model) + OpenClaw + Archon

## Visão geral

Este documento descreve a implementação dos recursos avançados do Ruflo/Claude-Flow no agl-hostman, complementando o multi-model e fallback já configurados via LiteLLM.

### Roadmap implementado

| Passo | Feature | Status | Benefício |
|-------|---------|--------|-----------|
| 1 | Ruflo v3.5 + 3-tier router | ✅ | Otimizar custos API |
| 2 | RuVector + PostgreSQL | ✅ | Memória vetorial |
| 3 | Background workers | ✅ | Automação WireGuard/NFS |
| 4 | Hive Mind | ✅ | Coordenação multi-agente |
| 5 | ReasoningBank + AgentDB | ✅ | Padrões reutilizáveis |

---

## Passo 1: Ruflo v3.5 + 3-tier router

### Diferença: Fallback vs 3-tier

| Aspecto | LiteLLM (fallback) | 3-tier router (SONA) |
|---------|-------------------|----------------------|
| **Quando** | Modelo falha / excede contexto | Antes de chamar |
| **Critério** | Erro | Tipo de tarefa |
| **Economia** | Resiliência | ~75% custo API |

### Validação

```bash
# Em agldv03
./scripts/ruflo/validate-ruflo.sh
```

### Uso do 3-tier router

```bash
# Roteamento inteligente por tipo de tarefa
npx agentic-flow@alpha hooks intel route "Optimize database queries" --top-k 3
# Output: Agent: perf-analyzer | Confidence: 96.2% | Latency: 0.34ms

# Com Ruflo
npx ruflo@latest hooks intel route "Build REST API" --top-k 3
```

### Variáveis de ambiente (agldv03)

O LiteLLM continua como gateway. O 3-tier router escolhe o modelo ideal; o LiteLLM aplica fallback se falhar:

```bash
# Já configurado em ~/.openclaw/zshrc-openclaw.env
export ANTHROPIC_BASE_URL=http://localhost:4000
export ANTHROPIC_AUTH_TOKEN=$LITELLM_MASTER_KEY
```

---

## Passo 2: RuVector + PostgreSQL

### Integração com Archon (CT183)

O Archon já usa Supabase (PostgreSQL + PGVector). O RuVector pode usar um banco local ou conectar ao Archon para memória vetorial compartilhada.

### Configuração

```bash
# Em agldv03
./scripts/ruflo/setup-ruvector.sh
```

Arquivo de config: `config/ruflo/ruvector.env`

### Comandos RuVector

```bash
ruflo ruvector init --database agl_ruvector --user admin
ruflo ruvector benchmark --iterations 1000
ruflo ruvector optimize --analyze
```

### Conexão Archon (opcional)

Para integrar com o PostgreSQL do Archon (Supabase):

```bash
# config/ruflo/ruvector.env
RUVECTOR_DATABASE_URL=postgresql://user:pass@host:5432/archon_db
```

---

## Passo 3: Background workers

### Workers disponíveis

| Worker | Uso | Hooks |
|--------|-----|-------|
| `ultralearn` | Aprendizado contínuo | post-task |
| `consolidate` | Consolidação de memória | session-end |
| `deepdive` | Análise profunda | pre-task |
| `testgaps` | Detecção de gaps de teste | post-edit |
| `refactor` | Sugestões de refatoração | post-edit |
| `benchmark` | Benchmarks de performance | manual |

### Configuração

```bash
./scripts/ruflo/setup-background-workers.sh
```

### Specs de infra automatizados

Os workers podem rodar os specs do Agent OS em background:

- `agent-os/specs/infrastructure/wireguard-peer-setup.md`
- `agent-os/specs/infrastructure/nfs-storage-mount.md`
- `agent-os/specs/infrastructure/archon-integration.md`

### Daemon systemd (opcional)

```bash
# config/ruflo/ruflo-daemon.service
# 10 workers com autoStart: true
```

---

## Passo 4: Hive Mind

### Inicialização

```bash
./scripts/ruflo/setup-hive-mind.sh
```

### Comandos

```bash
npx ruflo hive-mind init
npx ruflo hive-mind spawn "Build API" --queen-type tactical
npx ruflo hive-mind spawn "Research AI" --consensus byzantine --claude
```

### Topologias

- **mesh**: Todos conectados (default)
- **hierarchical**: Queen → workers
- **ring**: Cadeia circular
- **star**: Hub central

### Consenso

- `raft`: Padrão, balanceado
- `byzantine`: Máxima tolerância a falhas
- `gossip`: Alta escalabilidade
- `crdt`: Sem conflitos em distribuição

---

## Passo 5: ReasoningBank + AgentDB

### Benefício

Padrões de solução reutilizáveis entre projetos. Integração com skills existentes:

- `.claude/skills/reasoningbank-agentdb/SKILL.md`
- `.claude/skills/reasoningbank-intelligence/SKILL.md`

### Setup

```bash
./scripts/ruflo/setup-reasoningbank.sh
```

### Módulos agentic-flow

```typescript
import {
  HybridReasoningBank,
  AdvancedMemorySystem,
  ReflexionMemory,
  CausalRecall,
  NightlyLearner,
  SkillLibrary,
  EmbeddingService,
  CausalMemoryGraph
} from 'agentic-flow/reasoningbank';
```

### Uso via CLI

```bash
npx claude-flow@alpha memory store "API config" "REST API configuration" --namespace backend --reasoningbank
npx claude-flow@alpha memory query "API config" --namespace backend --reasoningbank
npx claude-flow@alpha memory status --reasoningbank
```

---

## Deploy unificado

### Executar em host específico

```bash
# Do repositório agl-hostman
./scripts/ruflo-deploy-agldv03.sh [host]
# host: root@100.94.221.87 (agldv03), root@100.113.9.98 (agldv04), root@100.71.217.115 (agldv12), root@100.83.51.9 (fgsrv06), ou "local"
```

### Sync config para todos os hosts

```bash
./scripts/ruflo/sync-config-all-hosts.sh
# Replica .claude/, config/ruflo/, scripts/ruflo/ para agldv03, agldv04, agldv12, fgsrv06
```

Ver `docs/CLAUDE-FLOW-CONFIG.md` para checklist e procedimento.

O script de deploy:

1. Valida Ruflo/claude-flow
2. Configura RuVector (se PostgreSQL disponível)
3. Inicializa background workers
4. Configura Hive Mind
5. Inicializa ReasoningBank

### Pré-requisitos

- Node.js 18+
- npm 9+
- Acesso SSH a agldv03 (100.94.221.87)
- LiteLLM rodando em agldv03:4000
- Variáveis de ambiente em ~/.openclaw/zshrc-openclaw.env

---

## Tool Groups (ENV)

```bash
# Grupos de ferramentas por modo
export CLAUDE_FLOW_TOOL_GROUPS=implement,test,fix,memory
# ou
export CLAUDE_FLOW_TOOL_MODE=develop

# Grupos: create, issue, branch, implement, test, fix, optimize, monitor, security, memory, all, minimal
```

---

## Referências

- [Ruflo GitHub](https://github.com/ruvnet/ruflo)
- [Claude-Flow Wiki](https://github.com/ruvnet/ruflo/wiki)
- [LiteLLM Integration](docs/CLAUDE-FLOW-LITELLM.md)
- [OpenClaw Multi-Model](docs/OPENCLAW.md)
- [Archon MCP](docs/ARCHON.md)
