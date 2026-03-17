# Claude Code Configuration - Claude Flow V3

## Behavioral Rules (Always Enforced)

- Do what has been asked; nothing more, nothing less
- NEVER create files unless they're absolutely necessary for achieving your goal
- ALWAYS prefer editing an existing file to creating a new one
- NEVER proactively create documentation files (*.md) or README files unless explicitly requested
- NEVER save working files, text/mds, or tests to the root folder
- Never continuously check status after spawning a swarm — wait for results
- ALWAYS read a file before editing it
- NEVER commit secrets, credentials, or .env files

## File Organization

- NEVER save to root folder — use the directories below
- Use `/src` for source code files
- Use `/tests` for test files
- Use `/docs` for documentation and markdown files
- Use `/config` for configuration files
- Use `/scripts` for utility scripts
- Use `/examples` for example code

## Project Architecture

- Follow Domain-Driven Design with bounded contexts
- Keep files under 500 lines
- Use typed interfaces for all public APIs
- Prefer TDD London School (mock-first) for new code
- Use event sourcing for state changes
- Ensure input validation at system boundaries

### Project Config

- **Topology**: hierarchical-mesh
- **Max Agents**: 15
- **Memory**: hybrid
- **HNSW**: Enabled
- **Neural**: Enabled

## Build & Test

```bash
# Build
npm run build

# Test
npm test

# Lint
npm run lint
```

- ALWAYS run tests after making code changes
- ALWAYS verify build succeeds before committing

## Security Rules

- NEVER hardcode API keys, secrets, or credentials in source files
- NEVER commit .env files or any file containing secrets
- Always validate user input at system boundaries
- Always sanitize file paths to prevent directory traversal
- Run `npx @claude-flow/cli@latest security scan` after security-related changes

## Concurrency: 1 MESSAGE = ALL RELATED OPERATIONS

- All operations MUST be concurrent/parallel in a single message
- Use Claude Code's Task tool for spawning agents, not just MCP
- ALWAYS batch ALL todos in ONE TodoWrite call (5-10+ minimum)
- ALWAYS spawn ALL agents in ONE message with full instructions via Task tool
- ALWAYS batch ALL file reads/writes/edits in ONE message
- ALWAYS batch ALL Bash commands in ONE message

## Swarm Orchestration

- MUST initialize the swarm using CLI tools when starting complex tasks
- MUST spawn concurrent agents using Claude Code's Task tool
- Never use CLI tools alone for execution — Task tool agents do the actual work
- MUST call CLI tools AND Task tool in ONE message for complex work

### 3-Tier Model Routing (ADR-026)

| Tier | Handler | Latency | Cost | Use Cases |
|------|---------|---------|------|-----------|
| **1** | Agent Booster (WASM) | <1ms | $0 | Simple transforms (var→const, add types) — Skip LLM |
| **2** | Haiku | ~500ms | $0.0002 | Simple tasks, low complexity (<30%) |
| **3** | Sonnet/Opus | 2-5s | $0.003-0.015 | Complex reasoning, architecture, security (>30%) |

- Always check for `[AGENT_BOOSTER_AVAILABLE]` or `[TASK_MODEL_RECOMMENDATION]` before spawning agents
- Use Edit tool directly when `[AGENT_BOOSTER_AVAILABLE]`

## Swarm Configuration & Anti-Drift

- ALWAYS use hierarchical topology for coding swarms
- Keep maxAgents at 6-8 for tight coordination
- Use specialized strategy for clear role boundaries
- Use `raft` consensus for hive-mind (leader maintains authoritative state)
- Run frequent checkpoints via `post-task` hooks
- Keep shared memory namespace for all agents

```bash
npx @claude-flow/cli@latest swarm init --topology hierarchical --max-agents 8 --strategy specialized
```

## Swarm Execution Rules

- ALWAYS use `run_in_background: true` for all agent Task calls
- ALWAYS put ALL agent Task calls in ONE message for parallel execution
- After spawning, STOP — do NOT add more tool calls or check status
- Never poll TaskOutput or check swarm status — trust agents to return
- When agent results arrive, review ALL results before proceeding

## V3 CLI Commands

### Core Commands

| Command | Subcommands | Description |
|---------|-------------|-------------|
| `init` | 4 | Project initialization |
| `agent` | 8 | Agent lifecycle management |
| `swarm` | 6 | Multi-agent swarm coordination |
| `memory` | 11 | AgentDB memory with HNSW search |
| `task` | 6 | Task creation and lifecycle |
| `session` | 7 | Session state management |
| `hooks` | 17 | Self-learning hooks + 12 workers |
| `hive-mind` | 6 | Byzantine fault-tolerant consensus |

### Quick CLI Examples

```bash
npx @claude-flow/cli@latest init --wizard
npx @claude-flow/cli@latest agent spawn -t coder --name my-coder
npx @claude-flow/cli@latest swarm init --v3-mode
npx @claude-flow/cli@latest memory search --query "authentication patterns"
npx @claude-flow/cli@latest doctor --fix
```

## Available Agents (60+ Types)

### Core Development
`coder`, `reviewer`, `tester`, `planner`, `researcher`

### Specialized
`security-architect`, `security-auditor`, `memory-specialist`, `performance-engineer`

### Swarm Coordination
`hierarchical-coordinator`, `mesh-coordinator`, `adaptive-coordinator`

### GitHub & Repository
`pr-manager`, `code-review-swarm`, `issue-tracker`, `release-manager`

### SPARC Methodology
`sparc-coord`, `sparc-coder`, `specification`, `pseudocode`, `architecture`

## Memory Commands Reference

```bash
# Store (REQUIRED: --key, --value; OPTIONAL: --namespace, --ttl, --tags)
npx @claude-flow/cli@latest memory store --key "pattern-auth" --value "JWT with refresh" --namespace patterns

# Search (REQUIRED: --query; OPTIONAL: --namespace, --limit, --threshold)
npx @claude-flow/cli@latest memory search --query "authentication patterns"

# List (OPTIONAL: --namespace, --limit)
npx @claude-flow/cli@latest memory list --namespace patterns --limit 10

# Retrieve (REQUIRED: --key; OPTIONAL: --namespace)
npx @claude-flow/cli@latest memory retrieve --key "pattern-auth" --namespace patterns
```

## Quick Setup

```bash
claude mcp add claude-flow -- npx -y @claude-flow/cli@latest
npx @claude-flow/cli@latest daemon start
npx @claude-flow/cli@latest doctor --fix
```

## Claude Code vs CLI Tools

- Claude Code's Task tool handles ALL execution: agents, file ops, code generation, git
- CLI tools handle coordination via Bash: swarm init, memory, hooks, routing
- NEVER use CLI tools as a substitute for Task tool agents

## Support

- Documentation: https://github.com/ruvnet/claude-flow
- Issues: https://github.com/ruvnet/claude-flow/issues

---

## Project: agl-hostman

> **Last Updated**: 2026-03-12
> **PRD**: `docs/PRD.md`
> **Infra Map**: `docs/INFRA.md`
> **Cloudflare Tunnels**: `docs/CLOUDFLARE-TUNNELS.md`

### O que é este projeto

AGL Host Management System — plataforma unificada para gerenciar a infraestrutura AGL (Proxmox, WireGuard, NFS, storage, AI stack). Consolida ferramentas de infra, scripts de automação e documentação de múltiplos hosts.

### Estrutura real do projeto

```
agl-hostman/
├── src/
│   ├── api/                    # REST API Fastify (porta 3030)
│   │   ├── server.js           # Entry point com Bearer auth
│   │   └── routes/             # hosts.js, storage.js, ai.js
│   ├── services/               # proxmox.js, storage-monitor.js, ai-stack.js
│   ├── hive-mind-integration/  # HiveMindWorkerPool, AgentTemplates, PerformanceMonitor
│   ├── performance/worker-pool/ # WorkerPool.js (2.8-4.4x perf)
│   ├── database/database.sqlite # SQLite local (hive state)
│   ├── web/                    # Dashboard React + Vite + Tailwind
│   │   └── src/components/     # HostGrid, StorageBar, AIStackStatus, HealthCard
│   └── .env.example
├── projects/
│   └── hive-migration/         # Migração API1→API8 (Falg Imóveis)
│       └── hive/code/
│           ├── shim/           # LegacyDatabaseShim.php, RouteMapper.php, FeatureFlags.php
│           ├── rollback-api.sh
│           └── transform-namespaces.sh
├── scripts/
│   ├── monitoring/             # storage-alert.sh, host-health.sh, ai-stack-health.sh,
│   │                           # wireguard-mesh.sh, morning-briefing.sh
│   └── setup-monitoring.sh     # Instala timer systemd no agldv03
├── config/
│   ├── systemd/                # hostman.service, hostman-monitor.service/.timer
│   ├── litellm/                # config.yaml, .env.example
│   ├── ruflo/                  # hive-mind.env, ruvector.env, background-workers.json
│   └── openclaw/               # litellm-gateway-client.env, openclaw-patch.json
└── docs/
    ├── PRD.md                  # Product Requirements Document completo
    ├── INFRA.md                # Mapa de infra (sempre ler antes de queries de infra)
    ├── OPENCLAW.md             # Config multi-model OpenClaw
    ├── RUFLO-ADVANCED.md       # Stack AI avançada (Ruflo, RuVector, Hive Mind)
    └── CLAUDE-FLOW-LITELLM.md # Gateway multi-model LiteLLM
```

### Como iniciar os serviços

```bash
# API (porta 3030) — em agldv03
cp src/.env.example src/.env   # configurar vars
npm start                       # ou: npm run dev (watch mode)

# Dashboard (porta 5173)
cd src/web && npm install && npm run dev

# Monitoramento
./scripts/monitoring/morning-briefing.sh   # manual
sudo ./scripts/setup-monitoring.sh         # instala timer 15min

# Ruflo daemon (garantir que está rodando)
npx ruflo@latest daemon status
npx ruflo@latest daemon start
```

### Hosts AGL (referência rápida)

| Host | Tailscale IP | Papel |
|------|-------------|-------|
| agldv03 (CT179) | 100.94.221.87 | **Dev principal** — Node 24, Ruflo, LiteLLM |
| aglsrv1 | 100.107.113.33 | Proxmox VE principal (68 CTs/VMs) |
| aglsrv6 | 100.98.108.66 | Proxmox VE secundário |
| fgsrv3 | 100.67.99.115 | MySQL master (falgimoveis11) |
| fgsrv5 | 100.71.107.26 | APIs Falg (fg_OLD2_NEW + fg_API8_d) |
| fgsrv6 | 100.83.51.9 | WireGuard Hub (10.6.0.5) |
| aglwk45 (VM104) | 100.117.146.21 | Windows workstation — OpenClaw, usa LiteLLM remoto (agldv03) |

- **SSH padrão**: `ssh root@<tailscale-ip>`
- **WireGuard mesh**: 10.6.0.0/24 (14 nós)
- **Prioridade de rede em agldv03**: WireGuard > LAN > Tailscale

### Variáveis de ambiente críticas (src/.env)

```bash
HOSTMAN_PORT=3030
HOSTMAN_API_KEY=              # Bearer token para a API
PROXMOX_HOST=192.168.0.245
PROXMOX_TOKEN_ID=             # API token Proxmox (não usuário/senha)
PROXMOX_TOKEN_SECRET=
LITELLM_BASE_URL=http://localhost:4000
LITELLM_MASTER_KEY=           # do config/litellm/.env
STORAGE_ALERT_THRESHOLD=90    # spark em 91.5%, overpower em 92.5% — CRÍTICO
```

### AI Stack (agldv03)

| Componente | Versão/Status | Config |
|-----------|--------------|--------|
| Ruflo | v3.5.2 | `npx ruflo@latest` |
| LiteLLM | 19 modelos, porta 4000 | `config/litellm/` |
| OpenClaw | v2026.2.26+ | `~/.openclaw/openclaw.json` — gateway.mode=local, ANTHROPIC_API_KEY=sk-optional (placeholder) |
| Hive Mind | 23 workers, byzantine | `npx ruflo@latest hive-mind status` |
| Memory | 117k entradas, HNSW | `npx ruflo@latest memory search` |

- **ANTHROPIC_BASE_URL**: `http://localhost:4000` (via LiteLLM)
- **Modelo primário**: `zai/glm-5` → fallback chain configurado
- **Deploy OpenClaw**: `./scripts/deploy-openclaw-config.sh` (agldv03, fgsrv06, agldv04-06)

### OpenClaw — verificação multi-host

| Host | Comando |
|------|---------|
| agldv03 | `source ~/.openclaw/zshrc-openclaw.env && openclaw status` |
| fgsrv06 | `ssh root@100.83.51.9 'openclaw status'` |
| aglwk45 (VM104) | Via AGLSRV1: `ssh root@192.168.0.245 'qm agent 104 ping'` e `qm guest exec 104 -- openclaw --version` |

Scripts: `scripts/verify-openclaw-aglwk45.sh`, `scripts/verify-openclaw-aglwk45.ps1` (ver `docs/AGLWK45-SETUP.md`)

### Projeto hive-migration (Falg Imóveis)

- **API1** (legacy): Laravel 5.5 / PHP 7.4 — `/var/www/fg_OLD2_NEW` — `api.falg.com.br`
- **API8** (target): Laravel 8.x / PHP 8.1 — `/var/www/fg_API8_d`
- **DB produção**: `falgimoveis11` em 191.252.201.205 (fgsrv3)
- **DB dev/staging**: `fgdev` (sync 4x/dia via backup-db-sync.sh)
- **Shim layer**: `projects/hive-migration/hive/code/shim/` — **registrar em `config/app.php` do Laravel 8**
- Adicionar `App\Shim\ShimServiceProvider::class` em `config/app.php`

### Alertas de storage (crítico)

- `spark` (7.1TB): **91.5% usado** — alerta acima de 90%
- `overpower` (9.8TB): **92.5% usado** — alerta acima de 90%
- Script: `scripts/monitoring/storage-alert.sh`
- **Não gravar dados volumosos em storage local sem verificar espaço**

### Preferências do usuário (registradas)

- **Idioma**: Respostas em pt-BR
- **Execução paralela**: Sempre spawnar múltiplos agentes em paralelo (1 mensagem, todos os Task calls juntos)
- **PRD primeiro**: Para projetos novos ou avanço, criar PRD antes de implementar
- **Análise de docs**: Ler toda documentação existente (infra, outros projetos) antes de propor soluções
- **Quick wins junto com implementação**: Aplicar correções imediatas (daemons parados, permissões, etc.) enquanto agentes rodam em background
- **Validação pós-implementação**: Sempre rodar syntax check / smoke test após implementar
- **Sem estimativas de tempo**: Não dar estimativas de quanto vai demorar
- **Respostas concisas**: Preferência por sumários diretos ao final, não explicações longas durante execução

### Infra: troubleshooting rápido (AGLSRV1)

| Problema | Solução |
|----------|---------|
| **Restart CT** | Executar do host (100.107.113.33) ou via Proxmox Web UI — **nunca** do próprio CT (ex: CT179) |
| **CT locked (snapshot)** | `ssh root@100.107.113.33 'pct unlock <vmid> && pct start <vmid>'` |
| **CT102 (pihole) parado** | `pct unlock 102 && pct start 102` |
| **Cloudflared (CT117) sem túnel** | `pct exec 117 -- systemctl restart cloudflared` |
| **DNS no aglsrv1** | `tailscale set --accept-dns=false`; `/etc/resolv.conf`: 192.168.0.102, 1.1.1.1, 8.8.8.8 |
| **Host sobrecarregado** | Verificar load, swap, zombies; VM125 (AGLMAC06) alta CPU → `qm stop 125` |
| **OpenClaw em aglwk45** | VM104 sem SSH — usar `qm guest exec 104` do AGLSRV1: `ssh root@192.168.0.245 'qm guest exec 104 -- openclaw --version'` |

### Sessões recentes (agent-transcripts)

- **HA fileserver7 + agldv07**: CT240/241, storage NFS, WireGuard+Tailscale fallback
- **AGLSRV1 sobrecarga**: VM125 parada, zombies containerd, pct move-volume lento via NFS
- **CT102/CT117/CT179**: lock snapshot, cloudflared restart, DNS config
- **OpenClaw multi-host**: verificação agldv03, fgsrv06, aglwk45; qm guest exec para VM104; ANTHROPIC_API_KEY placeholder; gateway.mode=local
