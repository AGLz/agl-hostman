# AGL Infrastructure Admin Platform

Uma plataforma completa de administração de infraestrutura para AGL, integrando múltiplos modelos de IA, automação com N8N, e metodologia Scrum.

## 🚀 Características Principais

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

### 5. **Scrum Board Completo**
- **Sprints**: Planejamento, execução e revisão
- **Tasks com Drag & Drop**: Kanban board interativo
- **Story Points**: Estimativa com IA
- **Burndown Charts**: Visualização de progresso
- **Velocity Tracking**: Métricas de performance

### 6. **Tecnologias Utilizadas**
- **Backend**: Laravel 12 com PHP 8.4
- **Frontend**: React + Vite + shadcn/ui
- **Databases**: MySQL + Redis
- **Queue**: Laravel Horizon
- **Monitoring**: Laravel Telescope
- **Containers**: Docker + Docker Compose
- **Deploy**: Harbor Registry + Dokploy

## 📦 Instalação

### Pré-requisitos
- Docker e Docker Compose
- PHP 8.4+
- Node.js 18+
- MySQL 8.0+
- Redis

### Passo a Passo

1. **Clone o repositório**
```bash
git clone https://github.com/agl/agl-hostman.git
cd agl-hostman/src
```

2. **Configure o ambiente**
```bash
cp .env.example .env
```

3. **Configure as variáveis de ambiente**
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

4. **Inicie os containers**
```bash
docker-compose up -d
```

5. **Execute as migrações**
```bash
docker-compose exec app php artisan migrate --seed
```

6. **Instale dependências do frontend**
```bash
npm install
npm run build
```

7. **Acesse a aplicação**
```
http://localhost
```

## 🔧 Configuração

### Laravel Horizon
Acesse o dashboard do Horizon em `/horizon` para monitorar filas.

### Laravel Telescope
Acesse o Telescope em `/telescope` para debugging (apenas em desenvolvimento).

### N8N Workflows
1. Acesse N8N em `http://localhost:5678`
2. Importe os workflows de `n8n-workflows/`
3. Configure os webhooks para o Laravel

## 📊 API Endpoints

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

## 🚢 Deploy para Produção

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

## 🛠️ Desenvolvimento

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

## 🔍 Monitoramento

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

## 🔐 Segurança

### Implementações de Segurança
- Autenticação SSO com WorkOS
- RBAC granular por localização
- Rate limiting em APIs
- Encryption at rest (Redis, MySQL)
- Secrets management com environment variables
- CORS configurado
- CSRF protection
- XSS protection

## 📈 Roadmap

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

## 🤝 Contribuindo

1. Fork o projeto
2. Crie sua feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit suas mudanças (`git commit -m 'Add some AmazingFeature'`)
4. Push para a branch (`git push origin feature/AmazingFeature`)
5. Abra um Pull Request

## 📝 Licença

Proprietary - AGL © 2025

## 📞 Suporte

- **Email**: admin@agl.com.br
- **Discord**: discord.gg/agl
- **Documentation**: https://docs.aglz.io

## 🙏 Agradecimentos

- Laravel Team
- Anthropic (Claude)
- Google (Gemini)
- OpenAI
- N8N Community
- Docker Community

---

**Desenvolvido com ❤️ pela equipe AGL**