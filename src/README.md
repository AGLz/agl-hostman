# agl-hostman — aplicação Laravel (Admin Platform)

Parte **PHP/Laravel** do monorepo **[agl-hostman](../README.md)** na raiz: na mesma árvore, a API **Fastify** está em **`api/`** relativo a esta pasta ([`api/`](api/)); comandos `npm` na **raiz** do repositório. **LiteLLM:** [`config/litellm/`](../config/litellm/). **Docs:** [`docs/`](../docs/). Contexto para agentes: [`AGENTS.md`](../AGENTS.md), [`CLAUDE.md`](../CLAUDE.md).

Plataforma de administração de infraestrutura AGL: multi-IA (incl. Hive-Mind), automação com N8N, operações e Scrum integrados.

## Características principais

### 1. **Autenticação Empresarial**
- **WorkOS AuthKit** para SSO empresarial
- **RBAC Multi-tenant** com 4 níveis de acesso:
  - `admin`: Acesso total
  - `advanced`: Gerenciamento avançado
  - `common`: Operações básicas
  - `restricted`: Apenas leitura
- **Permissões por Localização Física**: Controle granular por servidor/container

### 2. **Integração Multi-AI (Hive-Mind)**
- **5 Modelos de IA Integrados**:
  - Claude (Anthropic) - Análise e código
  - Gemini (Google) - Multimodal
  - GPT-4 (OpenAI) - Function calling
  - AbacusAI - Data analysis
  - Ollama - Local/Offline
- **Orquestração Multi-Agent**: Execução paralela de múltiplos modelos
- **Seleção Inteligente**: Escolha automática do melhor modelo por tarefa

### 3. **Automação com N8N**
- **Integração Bidirectional** Laravel ↔ N8N
- **Workflows Automáticos**:
  - Monitoramento de infraestrutura
  - Deploy automatizado
  - Análise com IA
- **Webhooks** para eventos em tempo real

### 4. **Gestão de Infraestrutura**
- **Monitoramento de Servidores**:
  - 6 servidores Proxmox (AGLSRV1-6)
  - 68+ containers LXC
  - Redes WireGuard e Tailscale
- **Dashboard em Tempo Real**
- **Alertas Inteligentes** com análise AI

### 5. **Memória diária (sessões com IA)**
- **URL:** `/daily-memory` (autenticado)
- Registo de **resumos por dia** com etiquetas de **projeto** e **tópicos**, pesquisa e filtros por data
- Build front: `npm run build` (ou `npm run dev`) para o entry `resources/js/app-inertia.jsx`

### 6. **Scrum Board Completo**
- **Sprints**: Planejamento, execução e revisão
- **Tasks com Drag & Drop**: Kanban board interativo
- **Story Points**: Estimativa com IA
- **Burndown Charts**: Visualização de progresso
- **Velocity Tracking**: Métricas de performance

### 7. **Tecnologias utilizadas**
- **Backend**: Laravel 12 (`laravel/framework` ^12), PHP ^8.2 (ver `composer.json`)
- **Frontend**: Inertia + React + Vite + shadcn/ui + Tailwind
- **Databases**: MySQL + Redis
- **Queue**: Laravel Horizon
- **Monitoring**: Laravel Telescope
- **Containers**: Docker + Docker Compose
- **Deploy**: Harbor Registry + Dokploy (conforme pipeline da equipa)

## Instalação

### Pré-requisitos
- Docker e Docker Compose (se usar stack containerizada)
- PHP 8.2+ e [Composer](https://getcomposer.org/)
- Node.js 18+ (assets front-end)
- MySQL 8+ e Redis (ou serviços via Compose)

### Passo a passo

1. **Repositório (raiz do monorepo, depois esta pasta)**
```bash
git clone <url-do-repositorio> agl-hostman
cd agl-hostman/src
```

2. **Dependências PHP e Inertia**
```bash
composer install
```
Inclui **`inertiajs/inertia-laravel`** ^2 (servidor Inertia para `Inertia::render`).

3. **Dependências Node (front-end)** — na pasta `src/`, com **devDependencies** (Vite):
```bash
npm install
# Se o teu npm tiver `omit=dev` global, usa: npm install --include=dev
npm run build
```
O ficheiro **`src/.npmrc`** define `omit=` para o projeto instalar sempre o Vite e plugins.

4. **Ambiente (`.env`)**
```bash
cp .env.example .env
touch database/database.sqlite   # se usar SQLite como no exemplo
php artisan key:generate         # preenche APP_KEY
```
O ficheiro **`.env.example`** inclui valores mínimos Laravel + variáveis HOSTMAN/Proxmox/LiteLLM. Para MySQL/Redis via Docker, ver comentários no próprio exemplo e `docker-compose.yml`.

5. **Configure as variáveis de ambiente (alternativa MySQL / Compose)**
```env
# Banco de dados
DB_CONNECTION=mysql
DB_HOST=mysql
DB_PORT=3306
DB_DATABASE=agl_admin
DB_USERNAME=agl
DB_PASSWORD=seu_password

# Redis
REDIS_HOST=redis
REDIS_PASSWORD=null
REDIS_PORT=6379

# WorkOS
WORKOS_API_KEY=seu_workos_key
WORKOS_CLIENT_ID=seu_client_id

# N8N
N8N_API_URL=http://n8n:5678
N8N_API_KEY=seu_n8n_key
N8N_WEBHOOK_SECRET=seu_webhook_secret

# AI Models
CLAUDE_API_KEY=seu_claude_key
GEMINI_API_KEY=seu_gemini_key
OPENAI_API_KEY=seu_openai_key
ABACUSAI_API_KEY=seu_abacusai_key
```

6. **Inicie os containers**
```bash
docker-compose up -d
```

7. **Execute as migrações**
```bash
docker-compose exec app php artisan migrate --seed
```

8. **Build do frontend (se usares só Docker depois ou alterares JS/CSS)**
```bash
npm install
npm run build
```

9. **Acesse a aplicação**
```
http://localhost
```

### Artisan / PHP CLI

- Se **`php artisan`** sair com código **255** e sem output no teu sistema, o bootstrap ainda pode estar íntegro: `php -r "require 'vendor/autoload.php'; require 'bootstrap/app.php'; echo 'ok';"` deve mostrar `ok`. Nesse caso usa **Docker** (`docker compose` nesta pasta) ou outro runtime PHP para comandos Artisan.
- **Git / Composer:** se aparecer *dubious ownership*, define `git config --global --add safe.directory /caminho/do/agl-hostman`.

## Configuração

### Laravel Horizon
Acesse o dashboard do Horizon em `/horizon` para monitorar filas.

### Laravel Telescope
Acesse o Telescope em `/telescope` para debugging (apenas em desenvolvimento).

### N8N Workflows
1. Acesse N8N em `http://localhost:5678`
2. Importe os workflows de `n8n-workflows/`
3. Configure os webhooks para o Laravel

## API Endpoints

### Autenticação
- `GET /auth/workos/redirect` - Iniciar login SSO
- `GET /auth/workos/callback` - Callback do SSO
- `POST /logout` - Fazer logout

### Infraestrutura
- `GET /api/infrastructure/locations` - Listar localizações
- `GET /api/infrastructure/servers/{code}` - Detalhes do servidor

### N8N Integration
- `POST /api/n8n/webhook` - Webhook endpoint
- `POST /api/n8n/execute` - Executar workflow
- `POST /api/n8n/monitoring` - Trigger monitoramento
- `GET /api/n8n/workflows` - Listar workflows

### AI Models
- `POST /api/ai/query` - Query único modelo
- `POST /api/ai/multi-agent` - Query múltiplos modelos
- `GET /api/ai/models` - Modelos disponíveis
- `POST /api/ai/analyze-infrastructure` - Análise de infra
- `POST /api/ai/review-code` - Code review com IA

### Scrum Board
- `GET /api/scrum/dashboard` - Dashboard overview
- `GET /api/scrum/board` - Board completo
- `GET /api/scrum/sprints` - Listar sprints
- `POST /api/scrum/sprints` - Criar sprint
- `GET /api/scrum/tasks` - Listar tasks
- `POST /api/scrum/tasks` - Criar task
- `POST /api/scrum/tasks/{id}/move` - Mover task

## Deploy para produção

### Com Harbor + Dokploy

1. **Build e push para Harbor**
```bash
./deploy.sh
```

2. **Deploy no Dokploy**
O webhook é triggered automaticamente após push para Harbor.

### Manual com Docker

1. **Build da imagem**
```bash
docker build -t agl-hostman:latest .
```

2. **Run em produção**
```bash
docker-compose -f docker-compose.prod.yml up -d
```

## Desenvolvimento

### Estrutura do Projeto
```
src/
├── app/
│   ├── Http/Controllers/   # Controllers
│   ├── Models/             # Eloquent Models
│   ├── Services/           # Business Logic
│   └── Jobs/              # Background Jobs
├── database/
│   ├── migrations/        # Database Migrations
│   └── seeders/          # Database Seeders
├── resources/
│   ├── js/               # React Components
│   └── views/            # Blade Templates
├── routes/               # API & Web Routes
└── deploy/              # Deployment configs
```

### Comandos Úteis

```bash
# Executar testes
php artisan test

# Limpar caches
php artisan optimize:clear

# Monitorar logs
docker-compose logs -f app

# Executar Job de monitoramento
php artisan queue:work --queue=monitoring

# Gerar relatório de cobertura
php artisan test --coverage
```

## Monitoramento

### Métricas Disponíveis
- **Infrastructure Health**: Status em tempo real de todos servidores
- **Task Velocity**: Velocidade de conclusão de tarefas
- **AI Usage**: Estatísticas de uso dos modelos de IA
- **Queue Performance**: Métricas do Horizon
- **Error Tracking**: Logs e exceções no Telescope

### Alertas Configurados
- Servidor offline
- CPU > 90%
- Memória > 85%
- Disk > 80%
- Queue backlog > 100 jobs
- AI API failures

## Segurança

### Implementações de Segurança
- Autenticação SSO com WorkOS
- RBAC granular por localização
- Rate limiting em APIs
- Encryption at rest (Redis, MySQL)
- Secrets management com environment variables
- CORS configurado
- CSRF protection
- XSS protection

## Roadmap

### Phase 2 (Em desenvolvimento)
- [ ] WebSocket para atualizações em tempo real
- [ ] Backup automatizado
- [ ] Métricas avançadas com Grafana
- [ ] Integração com Prometheus
- [ ] Mobile app com React Native

### Phase 3 (Planejado)
- [ ] Kubernetes orchestration
- [ ] Multi-cloud support (AWS, GCP, Azure)
- [ ] Advanced AI training
- [ ] Predictive analytics
- [ ] Cost optimization engine

## Contribuindo

1. Branch a partir do padrão da equipa (`feature/…`, `fix/…`, etc.).
2. Commits no estilo convencional (`feat(scope): …`, `fix: …`); ver **[`AGENTS.md`](../AGENTS.md)** e fluxo **bd** se aplicável.
3. `php artisan test` (Pest) antes de abrir PR; na raiz do monorepo, `npm test` quando alterar a API Node.

## Licença

Proprietary — AGL (ajustar ano/legal conforme contrato interno).

## Suporte e docs

- Documentação de infra: **[`docs/INFRA.md`](../docs/INFRA.md)** e **[`docs/README.md`](../docs/README.md)**.
- Integração Cursor + LiteLLM: **[`docs/CURSOR-LITELLM-INTEGRATION.md`](../docs/CURSOR-LITELLM-INTEGRATION.md)**.
- Contactos internos (email, Discord, docs públicos): manter alinhados com a política da organização; atualizar esta secção com URLs oficiais válidos.

## Agradecimentos

Comunidades Laravel, ecossistema Inertia/React, fornecedores de API de IA, N8N e Docker.

---

*Última revisão: 2026-03-19.*