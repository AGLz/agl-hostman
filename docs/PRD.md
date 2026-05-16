# PRD — AGL Host Management System (agl-hostman)

> **Version**: 1.0.0
> **Date**: 2026-03-02
> **Status**: Draft
> **Author**: Hive Mind Collective — Strategic Queen

---

## 1. Visão Geral

### 1.1 Problema

A infraestrutura AGL é composta por múltiplos hosts Proxmox (AGLSRV1, AGLSRV5, AGLSRV6, FGSRV3-7), 68+ containers/VMs, storage distribuído via WireGuard/NFS/SSHFS e uma stack de IA (LiteLLM + OpenClaw + Ruflo). Atualmente:

- **Não existe uma interface unificada** para gerenciar a infraestrutura
- Scripts de diagnóstico e automação estão **dispersos** em arquivos soltos na raiz do repositório
- O código em `src/` iniciou integrações (HiveMind, WorkerPool) mas **não há aplicação** que os consuma
- A migração API1→API8 (Falg Imóveis) está **pendente** na fase de shim layer
- O daemon Ruflo está **parado** e workers de background não estão sendo aproveitados
- Monitoramento e alertas são **manuais** e descentralizados

### 1.2 Solução

Construir o **agl-hostman** como uma aplicação real composta por:

1. **CLI + REST API** — Controle programático de toda a infraestrutura
2. **Web Dashboard** — Visibilidade centralizada de hosts, containers, storage e AI stack
3. **Shim Layer PHP** — Completa a migração API1→API8 da Falg Imóveis
4. **Observabilidade automatizada** — Alertas, health checks e métricas consolidadas

### 1.3 Usuários

| Persona | Necessidade |
|---------|-------------|
| Admin de infra (AGL) | Ver status de todos os hosts, executar operações remotas, receber alertas |
| Dev (agldv03) | Deploy, rollback, acesso a logs, gerenciar banco de dev |
| AI Operator | Monitorar LiteLLM, Ruflo daemon, Hive Mind, Archon |

---

## 2. Estado Atual (`src/`)

### O que existe

```
src/
├── hive-mind-integration/
│   ├── HiveMindWorkerPool.js     ✅ Integração Claude Flow ↔ WorkerPool
│   ├── AgentTemplates.js         ✅ Templates de agentes
│   ├── PerformanceMonitor.js     ✅ Monitor de performance
│   └── index.js                  ✅ Exports
├── performance/worker-pool/
│   ├── WorkerPool.js             ✅ Pool de workers Node.js (2.8-4.4x perf)
│   └── worker.js                 ✅ Worker script
├── database/
│   └── database.sqlite           ✅ SQLite local (hive state)
└── vendor/                       ⚠️  PHP vendored (phpstan/phpdoc-parser — fora de lugar)
```

### O que falta em `src/`

```
src/
├── api/                          ❌ REST API (Express/Fastify)
├── web/                          ❌ Web dashboard (React/Vue)
├── services/
│   ├── proxmox/                  ❌ Cliente Proxmox API
│   ├── wireguard/                ❌ Gestão WireGuard
│   ├── storage/                  ❌ Monitor NFS/ZFS/SSHFS
│   └── monitoring/               ❌ Coleta de métricas
└── php/                          ❌ Shim Layer PHP (migração API1→API8)
    ├── LegacyDatabaseShim.php
    ├── RouteMapper.php
    └── FeatureFlags.php
```

---

## 3. Projetos Ativos e Seus Gaps

### 3.1 Hive Migration (Falg Imóveis — API1 → API8)

**Contexto**: Migração de `fg_OLD2_NEW` (Laravel 5.5 / PHP 7.4) para `fg_API8_d` (Laravel 8.x / PHP 8.1).
**Host**: FGSRV5 (100.71.107.26) / FGSRV3 (MySQL master).

| Entregável | Status | Pendência |
|-----------|--------|-----------|
| Sistema de backup 4x/dia | ✅ | — |
| Arquitetura de migração | ✅ | — |
| Relatório de compatibilidade PHP | ✅ (pesquisa) | — |
| `LegacyDatabaseShim.php` | ❌ | Aguardando implementação |
| `RouteMapper.php` | ❌ | Aguardando mapeamento de rotas críticas |
| `FeatureFlags.php` | ❌ | Aguardando definição de caminhos críticos |
| `rollback-api.sh` | ❌ | Aguardando mapa de rotas |
| `transform-namespaces.sh` | ❌ | Aguardando auditoria PHP |
| Suite de testes de validação | ❌ | Após shim layer |

**APIs mapeadas**:
- API1: 126 controllers, PHP 7.4, Laravel 5.5 — `api.falg.com.br`
- API8: 75 controllers, PHP 8.1, Laravel 8.x — `api8.falg.com.br`
- BD compartilhado: `falgimoveis11` em 191.252.201.205 (MySQL master FGSRV3)

### 3.2 AI Stack (agldv03 — CT179)

| Componente | Status | Pendência |
|-----------|--------|-----------|
| LiteLLM (19 modelos) | ✅ healthy | — |
| Ruflo v3.5.2 | ✅ | — |
| OpenClaw v2026.2.26 | ✅ | — |
| Hive Mind (23 workers) | ✅ | — |
| Memory (117k entradas, HNSW) | ✅ | — |
| 3-tier router (Q-Learning) | ✅ | — |
| Daemon (5 workers) | ⚠️ STOPPED | `npx ruflo@latest daemon start` |
| MCP configurado | ⚠️ 0 MCPs | Configurar `ruflo mcp start` |
| Archon integrado | ⚠️ Parcial | Conectar RuVector ao PostgreSQL do Archon |

### 3.3 Infraestrutura (Geral)

| Componente | Status | Pendência |
|-----------|--------|-----------|
| WireGuard mesh (14 nós) | ✅ | — |
| Tailscale (31 ativos) | ✅ | — |
| NFS mounts AGLSRV1 | ✅ | spark (91%) e overpower (92%) críticos |
| MySQL HA (master/slave) | ✅ | — |
| Harbor CT182 | ✅ | — |
| VPS timeouts fgsrv3-5 | ✅ Correções aplicadas | Monitoramento contínuo |
| Dashboard de monitoramento | ❌ | Implementar |

---

## 4. Escopo do PRD — O Que Vamos Construir

### Prioridade 1 — Quick Wins (Sem nova estrutura)

Coisas que podem ser feitas agora com mínimo esforço:

| Item | Ação | Impacto |
|------|------|---------|
| Iniciar daemon Ruflo | `npx ruflo@latest daemon start` | Workers automáticos |
| Mover `src/vendor` | Deletar ou mover para projeto PHP correto | Limpeza |
| Configurar MCP | `claude mcp add ruflo -- npx -y ruflo@latest mcp start` | Integração CLI |
| Validar storage ZFS | Script de alerta quando spark/overpower > 90% | Prevenir falha |

### Prioridade 2 — Shim Layer (Hive Migration)

Implementar os arquivos PHP pendentes da migração API1→API8:

**`projects/hive-migration/hive/code/shim/LegacyDatabaseShim.php`**
- Wrapper que traduz queries do schema antigo (falgimoveis11) para o schema fgdev
- Intercepta chamadas de modelo e redireciona para conexão correta

**`projects/hive-migration/hive/code/shim/RouteMapper.php`**
- Mapeia rotas `/api/v1/*` (API1) para equivalentes em `/api/v8/*` (API8)
- Regras baseadas nas 126 rotas do `fg_OLD2_NEW` vs 75 do `fg_API8_d`

**`projects/hive-migration/hive/code/shim/FeatureFlags.php`**
- Sistema de flags para rollout gradual (rota por rota)
- Permite ativar API8 por rota sem derrubar API1

**`projects/hive-migration/hive/code/rollback-api.sh`**
- Script de emergência para reverter nginx para API1

**`projects/hive-migration/hive/code/transform-namespaces.sh`**
- Automatiza renomeação de namespaces PHP 5.x/7.x para PHP 8.x

### Prioridade 3 — Aplicação Node.js (agl-hostman core)

Transformar `src/` em uma aplicação real.

#### 3.1 API REST (`src/api/`)

```
src/api/
├── server.ts               # Fastify app entry point
├── routes/
│   ├── hosts.ts            # GET /api/hosts — status de todos os Proxmox hosts
│   ├── containers.ts       # GET /api/containers — lista CTs/VMs por host
│   ├── storage.ts          # GET /api/storage — NFS/ZFS status e uso
│   ├── ai.ts               # GET /api/ai — LiteLLM, Ruflo, OpenClaw status
│   └── health.ts           # GET /api/health — health check geral
├── services/
│   ├── proxmox.ts          # Cliente Proxmox API (usando credenciais via env)
│   ├── storage-monitor.ts  # Monitor de uso NFS/ZFS
│   └── ai-stack.ts         # Monitor LiteLLM + Ruflo daemon
└── middleware/
    └── auth.ts             # Bearer token (HOSTMAN_API_KEY)
```

**Endpoints mínimos v1:**

| Endpoint | Método | Descrição |
|----------|--------|-----------|
| `/api/health` | GET | Status geral — todos os componentes |
| `/api/hosts` | GET | Lista hosts Proxmox + status |
| `/api/hosts/:id/containers` | GET | CTs/VMs de um host |
| `/api/storage` | GET | Uso de storage (NFS, ZFS) com alertas |
| `/api/ai/status` | GET | Status da AI stack |
| `/api/ai/daemon` | POST | Start/stop Ruflo daemon |

#### 3.2 Serviço de Monitoramento (`src/services/monitoring/`)

Substitui os scripts shell manuais por um processo contínuo:

```typescript
// src/services/monitoring/StorageMonitor.ts
// Alerta quando spark/overpower > 90% (já em 91.54% e 92.54%)
// Polling: a cada 15 minutos

// src/services/monitoring/HostHealthMonitor.ts
// Checa reachability de todos os 14 nós WireGuard
// Usa ping e SSH health check

// src/services/monitoring/HiveMindMonitor.ts
// Garante que daemon Ruflo está rodando
// Reinicia automaticamente se cair
```

#### 3.3 Web Dashboard (`src/web/`)

Interface simples para o time — não precisa ser complexa:

```
src/web/
├── index.html
├── components/
│   ├── HostGrid.tsx        # Grid de hosts com status colorido (verde/vermelho)
│   ├── StorageBar.tsx      # Barra de uso por storage pool
│   ├── AIStackStatus.tsx   # Cards de LiteLLM, Ruflo, OpenClaw
│   └── AlertFeed.tsx       # Feed de alertas em tempo real
└── App.tsx
```

Stack sugerida: React + Vite + Tailwind (leve, sem framework pesado).

---

## 5. Arquitetura Técnica

```
┌─────────────────────────────────────────────────────┐
│                  agl-hostman                        │
├─────────────────────────────────────────────────────┤
│                                                     │
│  Web Dashboard (React)          CLI (Node.js)       │
│       │                              │              │
│       ▼                              ▼              │
│  REST API (Fastify)  ←──────────────┘              │
│       │                                             │
│  ┌────┴────────────────────────────────────┐        │
│  │              Services                  │        │
│  ├────────────┬──────────┬────────────────┤        │
│  │  Proxmox   │ Storage  │   AI Stack     │        │
│  │  Client    │ Monitor  │   Monitor      │        │
│  └────────────┴──────────┴────────────────┘        │
│       │               │            │               │
│       ▼               ▼            ▼               │
│  Proxmox API    NFS/ZFS/SSHFS  LiteLLM:4000       │
│  (AGLSRV1/5/6)  (ct111,fgsrv5) Ruflo daemon       │
│                                                     │
│  HiveMindWorkerPool (src/hive-mind-integration/)   │
│  WorkerPool (src/performance/)                     │
│  SQLite (src/database/database.sqlite)             │
└─────────────────────────────────────────────────────┘
```

### Tech Stack

| Camada | Tecnologia | Justificativa |
|--------|-----------|---------------|
| Runtime | Node.js 24 (já instalado em agldv03) | Consistência |
| API | Fastify | Performance, TypeScript nativo |
| Frontend | React + Vite + Tailwind | Leve, rápido para prototipar |
| Banco local | SQLite (já em `src/database/`) | Sem infra adicional |
| Processo | systemd unit | Consistente com outros serviços |
| PHP (shim) | PHP 8.1 (já em fgsrv5) | Compatível com API8 |

### Configuração (variáveis de ambiente)

```bash
# src/.env.example
HOSTMAN_PORT=3030
HOSTMAN_API_KEY=          # Bearer token para a API
HOSTMAN_CORS_ORIGIN=      # Ex.: "https://falg.com.br,https://www5.falg.com.br" (ou JSON array)
PROXMOX_HOST=192.168.0.245
PROXMOX_TOKEN_ID=         # API token Proxmox
PROXMOX_TOKEN_SECRET=
LITELLM_BASE_URL=http://localhost:4000
LITELLM_MASTER_KEY=       # do config/litellm/.env
STORAGE_ALERT_THRESHOLD=90  # % de uso para alertar
```

---

## 6. Roadmap

### Fase 1 — Fundação (prioridade imediata)

**Objetivo**: Habilitar operação estável e iniciar a estrutura da aplicação.

| Tarefa | Arquivo/Localização | Responsável |
|--------|-------------------|-------------|
| Iniciar Ruflo daemon | `npx ruflo@latest daemon start` | Ops |
| Configurar MCP | `.mcp.json` (adicionar ruflo) | Dev |
| Remover `src/vendor/` PHP | Mover para `projects/hive-migration/` | Dev |
| Criar `src/api/server.ts` | Fastify básico com `/health` | Dev |
| Criar `src/.env.example` | Variáveis documentadas | Dev |
| Alert script storage ZFS | `scripts/monitoring/storage-alert.sh` | Dev |

### Fase 2 — Shim Layer PHP (migração Falg Imóveis)

**Objetivo**: Completar a migração API1→API8 com rollback seguro.

| Tarefa | Arquivo | Status atual |
|--------|---------|-------------|
| Implementar `LegacyDatabaseShim.php` | `projects/hive-migration/hive/code/shim/` | ❌ |
| Implementar `RouteMapper.php` | `projects/hive-migration/hive/code/shim/` | ❌ |
| Implementar `FeatureFlags.php` | `projects/hive-migration/hive/code/shim/` | ❌ |
| Script `rollback-api.sh` | `projects/hive-migration/hive/code/` | ❌ |
| Script `transform-namespaces.sh` | `projects/hive-migration/hive/code/` | ❌ |
| Testes de integração API8 | `tests/hive-migration/` | ❌ |

### Fase 3 — API REST + Monitoring

**Objetivo**: Substituir scripts manuais por serviços programáticos.

| Tarefa | Arquivo | Depende de |
|--------|---------|-----------|
| `src/services/proxmox.ts` | Cliente Proxmox API | Fase 1 |
| `src/services/storage-monitor.ts` | Monitor NFS/ZFS | Fase 1 |
| `src/services/ai-stack.ts` | Monitor LiteLLM/Ruflo | Fase 1 |
| `src/api/routes/hosts.ts` | Endpoint /api/hosts | Proxmox service |
| `src/api/routes/storage.ts` | Endpoint /api/storage | Storage service |
| `src/api/routes/ai.ts` | Endpoint /api/ai | AI service |
| systemd unit `hostman.service` | `config/systemd/hostman.service` | API completa |

### Fase 4 — Web Dashboard

**Objetivo**: Interface visual para o time.

| Tarefa | Arquivo | Depende de |
|--------|---------|-----------|
| Setup React + Vite | `src/web/` | Fase 3 |
| `HostGrid.tsx` | Status dos hosts | API /hosts |
| `StorageBar.tsx` | Barras de uso | API /storage |
| `AIStackStatus.tsx` | Cards AI | API /ai |
| `AlertFeed.tsx` | Feed de alertas | WebSocket |
| Deploy via Dokploy (CT180) | Dokploy config | Dashboard pronto |

---

## 7. Restrições e Dependências

### Dependências externas

| Sistema | Status | Crítico para |
|---------|--------|-------------|
| Proxmox API (AGLSRV1: 192.168.0.245:8006) | ✅ Ativo | Fase 3 |
| LiteLLM (:4000 em agldv03) | ✅ Ativo | Fase 1 |
| MySQL FGSRV3 (falgimoveis11) | ✅ Ativo | Fase 2 |
| CT183 Archon (PostgreSQL/Supabase) | ✅ Ativo | RuVector |
| CT180 Dokploy | ✅ Ativo | Deploy Fase 4 |

### Restrições técnicas

- `spark` (7.1TB) e `overpower` (9.8TB) estão a **>91% de capacidade** — qualquer feature que grave dados locais deve ser cautelosa
- O código PHP da shim layer precisa rodar no PHP 8.1 do FGSRV5 — sem PHP 7 compat
- Não usar senha/credenciais hardcoded em nenhum arquivo (já acontece em arquivos antigos — não replicar)
- Manter `src/` abaixo de 500 linhas por arquivo (regra CLAUDE.md)

### Segurança

- Credenciais MySQL em análises antigas podem estar em texto claro — **não replicar**; usar cofre e variáveis de ambiente
- A API REST deve exigir Bearer token (`HOSTMAN_API_KEY`)
- Proxmox API: usar token de API (não usuário/senha)

---

## 8. Métricas de Sucesso

### Fase 1

- [ ] Ruflo daemon rodando continuamente (sem restart manual)
- [ ] Script de alerta ZFS disparando quando `spark` ou `overpower` > 90%

### Fase 2

- [ ] 100% das rotas críticas da API1 mapeadas em `RouteMapper.php`
- [ ] Feature flag ativa para pelo menos 5 rotas na API8
- [ ] Rollback testado com sucesso em ambiente de dev

### Fase 3

- [ ] `/api/health` respondendo com status de todos os hosts
- [ ] `/api/storage` com dados reais de NFS/ZFS
- [ ] Serviço `hostman.service` em autostart no agldv03

### Fase 4

- [ ] Dashboard acessível via Cloudflare Tunnel (aglsrv1-dokploy)
- [ ] Tempo de carregamento < 2s
- [ ] AlertFeed mostrando alertas de storage em tempo real

---

## 9. Próximos Passos Imediatos

Em ordem de execução:

1. **Agora**: Iniciar daemon Ruflo em agldv03
   ```bash
   ssh root@100.94.221.87 'npx ruflo@latest daemon start'
   ```

2. **Hoje**: Criar estrutura base `src/api/`
   - `src/api/server.ts` — Fastify com `/api/health`
   - `src/api/.env.example`
   - `package.json` atualizado com dependências

3. **Esta semana**: Implementar shim layer PHP
   - `LegacyDatabaseShim.php`
   - `RouteMapper.php` com mapeamento das rotas críticas
   - `FeatureFlags.php`

4. **Esta semana**: Script de alerta de storage
   - `scripts/monitoring/storage-alert.sh`
   - Cron em agldv03: `0 */15 * * * scripts/monitoring/storage-alert.sh`

---

## Apêndice A — Referências

- [INFRA.md](INFRA.md) — Mapa completo da infraestrutura AGL
- [OPENCLAW.md](OPENCLAW.md) — Configuração multi-model
- [RUFLO-ADVANCED.md](RUFLO-ADVANCED.md) — Stack AI avançada
- [CLAUDE-FLOW-LITELLM.md](CLAUDE-FLOW-LITELLM.md) — Gateway multi-model
- [AGLDV03-RUFLO-TEST-RESULTS.md](AGLDV03-RUFLO-TEST-RESULTS.md) — Estado atual do agldv03
- [hive-migration/hive/code/README.md](../projects/hive-migration/hive/code/README.md) — Status da migração
- [hive-migration/hive/code/MIGRATION_ARCHITECTURE.md](../projects/hive-migration/hive/code/MIGRATION_ARCHITECTURE.md) — Arquitetura da migração

## Apêndice B — Acesso rápido

```bash
# Agldv03 (dev principal)
ssh root@100.94.221.87

# AGLSRV1 (Proxmox principal)
ssh root@100.107.113.33

# FGSRV5 (APIs Falg)
ssh root@100.71.107.26

# Repositório
/mnt/overpower/apps/dev/agl/agl-hostman   # local
/mnt/overpower/apps/dev/agl/agl-hostman   # mesma path em agldv03 (NFS overpower)
```
