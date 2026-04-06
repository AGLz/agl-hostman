# AGL Hostman — Contexto Qwen

## Visão Geral do Projeto

**agl-hostman** é um sistema de gestão de infraestrutura e orquestração multi-agente para a infraestrutura AGL. O repositório contém:

1. **API Node.js (Fastify)** — localizada em `src/api/`, com servidor em `src/api/server.js`
2. **Aplicação Laravel 12** — plataforma de administração em `src/` com Inertia + React, painel de infraestrutura, autenticação SSO (WorkOS), integração multi-IA (Hive-Mind), automação N8N, Scrum Board, e gestão de memória diária
3. **Gateway LiteLLM** — configuração em `config/litellm/config.yaml`, proxy OpenAI/Anthropic para integração com Cursor IDE e múltiplos modelos de IA
4. **Docker / Compose** — stacks completas na raiz (`docker-compose.yml`, `docker/`)

## Stack Tecnológica

| Componente | Tecnologia |
|------------|-----------|
| **API Node** | Fastify 4, SQLite, Node.js 18+ |
| **Backend PHP** | Laravel 12, PHP 8.2+ |
| **Frontend** | Inertia + React + Vite + shadcn/ui + Tailwind |
| **Database** | MySQL / PostgreSQL + Redis |
| **Queue** | Laravel Horizon |
| **Monitoring** | Laravel Telescope |
| **Gateway LLM** | LiteLLM (config em `config/litellm/`) |
| **Infra** | Proxmox, Docker, WireGuard, Tailscale, Cloudflare Tunnels |

## Estrutura do Repositório

| Caminho | Descrição |
|---------|-----------|
| `src/api/` | API Fastify (entrada: `server.js`) |
| `src/app/`, `src/routes/`, `src/resources/` | Aplicação Laravel |
| `config/litellm/` | Gateway LLM (`config.yaml`, `config-remote.yaml`) |
| `docker/` | Stacks Docker (LiteLLM, monitoring, nginx, etc.) |
| `docs/` | Documentação operacional, guias, troubleshooting |
| `scripts/` | Automação (backup, litellm, openclaw, etc.) |
| `tests/api/`, `tests/unit/`, `tests/integration/` | Testes Node.js |
| `infrastructure/` | Terraform / docs de plataforma |
| `ops/` | Runbooks / operações |
| `.cursor/rules/` | Regras Cursor (Laravel Boost) |
| `AGENTS.md` | Normas para agentes, bd/beads, OpenClaw, LiteLLM |
| `CLAUDE.md` | Contexto do workspace e caminhos-chave |

## Comandos Principais

### API Node (raiz do repositório)

```bash
npm install                    # Instalar dependências
npm run dev                    # Iniciar com watch (node --watch src/api/server.js)
npm start                      # Iniciar produção (node src/api/server.js)
npm test                       # Executar testes (tests/api/, tests/unit/)
npm run lint                   # ESLint
npm run lint:fix               # ESLint auto-fix
npm run test:integration:litellm  # Teste integração LiteLLM
npm run test:litellm:battery   # Benchmark completo LiteLLM
npm run migrate                # Executar migrações DB
```

### Aplicação Laravel (`src/`)

```bash
cd src
composer install               # Instalar dependências PHP
npm install                    # Instalar dependências Node (Vite)
npm run build                  # Build frontend
cp .env.example .env           # Configurar ambiente
php artisan key:generate       # Gerar chave APP
php artisan migrate --seed     # Executar migrações
php artisan test               # Executar testes (Pest)
php artisan horizon            # Iniciar queue worker
php artisan reverb:start       # Iniciar WebSocket server
```

### Docker Compose

```bash
docker compose up -d           # Iniciar todos os serviços
docker compose up app db       # Iniciar serviços específicos
docker compose logs -f         # Ver logs
docker compose down            # Parar todos os serviços
docker compose exec app php artisan migrate  # Executar migrações via Docker
```

### Orquestração (Ruflo / Claude Flow)

```bash
ruflo doctor                   # Diagnóstico
ruflo init --minimal           # Inicializar .claude-flow
ruflo status                   # Status swarm / agentes
ruflo memory store --key "nome" --value "descrição" --namespace patterns
ruflo memory search --query "termos" --namespace patterns
```

## Variáveis de Ambiente

- Ver `.env.example` na raiz e em `src/`
- **Nunca commitar** `.env` com credenciais
- Configurações mínimas: Laravel APP_KEY, DB credentials, WorkOS, N8N, chaves de API de IA

## Convenções de Desenvolvimento

### Commits
Estilo convencional: `feat|fix|docs|style|refactor|perf|test|chore(scope): descrição`

### Código
- Ficheiros < 500 linhas quando possível
- Sem segredos no Git; usar variáveis de ambiente
- Validação nas fronteiras (HTTP, forms, paths — anti-traversal)
- Queries parametrizadas; output escapado onde houver HTML

### Testes
- **Node:** `npm test` na raiz
- **Laravel:** `php artisan test` em `src/` (Pest)
- Executar testes antes de abrir PRs

## Issue Tracking (Beads / bd)

```bash
bd ready --json                # Trabalho desbloqueado
bd create "Título" --description="..." -t bug|feature|task -p 0-4 --json
bd update <id> --claim --json
bd close <id> --reason "..." --json
```

## Integração LiteLLM + Cursor

- **`cursor-composer`** / **`cursor-composer-2-fast`** → `gpt-5.4-mini`
- **`openai/gpt-5.3-chat-latest`** / **`gpt-5.3-instant`** → mesmo backend
- Configuração: `config/litellm/config.yaml`
- Documentação detalhada: `docs/CURSOR-LITELLM-INTEGRATION.md`

## Infra AGL — Operações Rápidas

| Tema | Comando |
|------|---------|
| Restart CT (no host) | `pct unlock <vmid> && pct start <vmid>` |
| Pi-hole CT102 | `pct unlock 102 && pct start 102` |
| Cloudflared CT117 | `pct exec 117 -- systemctl restart cloudflared` |

## Documentação Importante

| Documento | Conteúdo |
|-----------|----------|
| [`AGENTS.md`](AGENTS.md) | Normas para agentes, bd/beads, OpenClaw, LiteLLM |
| [`CLAUDE.md`](CLAUDE.md) | Contexto do workspace |
| [`README.md`](README.md) | Visão geral do projeto |
| [`src/README.md`](src/README.md) | Guia da aplicação Laravel |
| [`docs/INFRA.md`](docs/INFRA.md) | Mapa de infra, operações recorrentes |
| [`docs/README.md`](docs/README.md) | Índice da documentação AGL |
| [`docs/CURSOR-LITELLM-INTEGRATION.md`](docs/CURSOR-LITELLM-INTEGRATION.md) | Cursor IDE + LiteLLM |

## Notas de Operação

- **Localização:** `/mnt/overpower/apps/dev/agl/agl-hostman` (agldv03, NFS overpower)
- **Novos ficheiros:** preferir `docs/`, `scripts/`, `config/` ou o módulo `src/` adequado — não adicionar ficheiros soltos sem propósito
- **Landing the plane (fim de sessão):** registar follow-up em bd, correr testes, `git pull --rebase` → `git push`, verificar `git status` up to date

---

*Última atualização: 2026-04-06*
