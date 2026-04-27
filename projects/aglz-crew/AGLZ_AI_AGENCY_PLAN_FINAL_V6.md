# 🏢 AGLz AI Agency - Plano Final v6

> **Data**: 2026-04-18
> **Mudança**: LiteLLM movido de CT-210 para **CT-207**
> **Motivo**: CT-210 já existe e não será usado neste planejamento
> **Rede**: LAN 192.168.0.0/24

---

## 📋 CTs EXISTENTES NO AGLSRV1 (Inventário)

### CTs de Infrastructure (Não serão modificados)
| CT | Nome | IP LAN | Função | Status | Uso no Projeto |
|----|------|--------|--------|--------|----------------|
| **CT-131** | mysql | 192.168.0.131 | MySQL Database | ✅ Running | Dados legados |
| **CT-137** | redis | 192.168.0.137 | Redis Cache | ✅ Running | **Cache compartilhado** |
| **CT-149** | postgres | 192.168.0.149 | PostgreSQL | ✅ Running | **Database principal** |
| **CT-180** | dokploy | 192.168.0.180 | Dokploy PaaS | ✅ Running | Deploys |
| **CT-182** | harbor | 192.168.0.182 | Harbor Registry | ✅ Running | Docker images |
| **CT-183** | archon | 192.168.0.183 | Archon AI MCP | ✅ Running | Knowledge Base |
| **CT-184** | supabase | 192.168.0.184 | Supabase | ✅ Running | Vector DB |

### CTs de AI/ML (Integrados ao projeto)
| CT | Nome | IP LAN | Função | Status | Uso no Projeto |
|----|------|--------|--------|--------|----------------|
| **CT-200** | ollama | 192.168.0.200 | Ollama GPU | ✅ Running | **LLMs locais** |
| **CT-202** | n8n | 192.168.0.202 | N8N Workflows | ✅ Running | Workflows |

### CTs NÃO utilizados neste projeto
| CT | Nome | IP LAN | Status | Motivo |
|----|------|--------|--------|--------|
| **CT-201** | amp-server | 192.168.0.201 | ✅ Running | Não fará parte do projeto |
| **CT-210** | (existente) | - | ✅ Running | Já existe, não usaremos |

---

## 🆕 NOVOS CTs (AGLz AI Agency)

| CT | Nome | IP LAN | Recursos | Função | Status |
|----|------|--------|----------|--------|--------|
| **CT-203** | openclaw-agent | 192.168.0.203 | 4GB / 2 CPU | Assistente Executivo | 🆕 Novo |
| **CT-204** | hermes-agent | 192.168.0.204 | 4GB / 2 CPU | Assistente Estratégico | 🆕 Novo |
| **CT-205** | **aglz-crew** | **192.168.0.205** | **16GB / 8 CPU** | **Agência Principal** | 🆕 Novo |
| **CT-206** | ruflo-orch | 192.168.0.206 | 4GB / 2 CPU | Orquestração | 🆕 Novo |
| **CT-207** | **litellm-proxy** | **192.168.0.207** | **8GB / 4 CPU** | **LiteLLM Gateway** | 🆕 Novo |
| **CT-208** | (reservado) | 192.168.0.208 | - | Futuro uso | 🔒 Reservado |
| **CT-209** | monitoring | 192.168.0.209 | 4GB / 2 CPU | Prometheus/Grafana | 🆕 Novo |

---

## 🏗️ ARQUITETURA FINAL

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    AGLSRV1 - Proxmox VE - REDE LAN                          │
│                         192.168.0.0/24                                      │
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │                    CTs EXISTENTES (INFRASTRUCTURE)                   │    │
│  │                                                                      │    │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐            │    │
│  │  │ CT-131   │  │ CT-137   │  │ CT-149   │  │ CT-184   │            │    │
│  │  │  MySQL   │  │  Redis   │  │ Postgres │  │ Supabase │            │    │
│  │  │ .0.131   │  │ .0.137   │  │ .0.149   │  │ .0.184   │            │    │
│  │  └──────────┘  └────┬─────┘  └────┬─────┘  └──────────┘            │    │
│  │                     │             │                                 │    │
│  │  ┌──────────┐       │             │       ┌──────────┐            │    │
│  │  │ CT-180   │       │             │       │ CT-182   │            │    │
│  │  │ Dokploy  │       │             │       │ Harbor   │            │    │
│  │  │ .0.180   │       │             │       │ .0.182   │            │    │
│  │  └──────────┘       │             │       └──────────┘            │    │
│  │                     │             │                               │    │
│  │  ┌──────────┐       │             │       ┌──────────┐            │    │
│  │  │ CT-183   │◄──────┴─────────────┴──────►│ CT-200   │            │    │
│  │  │ Archon   │       (Cache/DB)            │ Ollama   │            │    │
│  │  │ .0.183   │                             │ .0.200   │            │    │
│  │  └──────────┘                             │  GPU     │            │    │
│  │                                           └────┬─────┘            │    │
│  │                                                │                   │    │
│  └────────────────────────────────────────────────┼───────────────────┘    │
│                                                   │                        │
│                          ┌────────────────────────┘                        │
│                          ▼                                                 │
│  ┌─────────────────────────────────────────────────────────────────────┐  │
│  │                    CT-207 - LITELLM PROXY                            │  │
│  │                    192.168.0.207:4000                                │  │
│  │                                                                      │  │
│  │  ┌─────────────────────────────────────────────────────────────┐    │  │
│  │  │  Roteamento:                                                 │    │  │
│  │  │  ├──► Ollama (CT-200:192.168.0.200:11434) - 90%              │    │  │
│  │  │  ├──► GLM (cloud) - 5%                                       │    │  │
│  │  │  └──► Claude (cloud) - 5%                                    │    │  │
│  │  │                                                             │    │  │
│  │  │  Cache: CT-137 (Redis)                                       │    │  │
│  │  │  DB: CT-149 (PostgreSQL)                                     │    │  │
│  │  └─────────────────────────────────────────────────────────────┘    │  │
│  │                                                                      │  │
│  │  Clientes:                                                           │  │
│  │  ├── CT-203 (OpenClaw)                                              │  │
│  │  ├── CT-204 (Hermes)                                                │  │
│  │  ├── CT-205 (AGLz Crew)                                             │  │
│  │  ├── CT-206 (Ruflo)                                                 │  │
│  │  ├── CT-202 (N8N)                                                   │  │
│  │  └── (futuro: CTs dev, fgsrv7)                                      │  │
│  │                                                                      │  │
│  └─────────────────────────────────────────────────────────────────────┘  │
│                                 │                                          │
│         ┌───────────────────────┼───────────────────────┐                   │
│         │                       │                       │                   │
│         ▼                       ▼                       ▼                   │
│  ┌──────────────┐      ┌──────────────┐      ┌──────────────┐              │
│  │   CT-203     │      │   CT-205     │      │   CT-204     │              │
│  │  OpenClaw    │      │  AGLz Crew   │      │   Hermes     │              │
│  │              │      │              │      │              │              │
│  │ Assistente   │      │   Agência    │      │ Assistente   │              │
│  │ Executivo    │      │   Principal  │      │ Estratégico  │              │
│  └──────────────┘      └──────────────┘      └──────────────┘              │
│                                                              │              │
│  ┌──────────────┐      ┌──────────────┐      ┌──────────────┐              │
│  │   CT-206     │      │   CT-209     │      │   CT-202     │              │
│  │    Ruflo     │      │  Monitoring  │      │     N8N      │              │
│  │  Orquestra-  │      │ Prometheus/  │      │  Workflows   │              │
│  │     ção      │      │   Grafana    │      │   (integrado)│              │
│  └──────────────┘      └──────────────┘      └──────────────┘              │
│                                                               │              │
└───────────────────────────────────────────────────────────────┼──────────────┘
                                                                │
                    ┌───────────────────────────────────────────┘
                    │
                    ▼ (Futuro - WireGuard/Tailscale)
        ┌──────────────────────┐
        │      fgsrv7          │
        │   (remoto)           │
        │   Acesso ao          │
        │   LiteLLM            │
        │   (CT-207)           │
        └──────────────────────┘
```

---

## 🔧 CONFIGURAÇÃO DO LITELLM (CT-207)

### Criar CT-207
```bash
# No AGLSRV1
pct create 207 /var/lib/vz/template/cache/ubuntu-24.04-standard_24.04-2_amd64.tar.zst \
  --hostname litellm-proxy \
  --memory 8192 \
  --cores 4 \
  --net0 name=eth0,bridge=vmbr0,ip=192.168.0.207/24,gw=192.168.0.1 \
  --rootfs local-zfs:50 \
  --ostype ubuntu

pct set 207 -features nesting=1,keyctl=1,fuse=1
pct start 207

# Instalar Docker
pct exec 207 -- bash -c "
  apt update && apt install -y docker.io docker-compose git curl jq
  systemctl enable docker && systemctl start docker
"
```

### Docker Compose
```bash
# No CT-207
mkdir -p /opt/litellm
cd /opt/litellm

cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  litellm-proxy:
    image: ghcr.io/berriai/litellm:main-latest
    container_name: litellm-proxy
    restart: unless-stopped
    ports:
      - "4000:4000"
    environment:
      - CONFIG_FILE_PATH=/app/config.yaml
      - DATABASE_URL=postgresql://litellm:${DB_PASSWORD}@192.168.0.149:5432/litellm
      - REDIS_URL=redis://192.168.0.137:6379/0
      - LITELLM_MASTER_KEY=${LITELLM_MASTER_KEY}
      - LITELLM_SALT_KEY=${LITELLM_SALT_KEY}
    volumes:
      - ./config.yaml:/app/config.yaml:ro
      - ./logs:/app/logs
    networks:
      - litellm-net
    healthcheck:
      test: ["CMD", "python", "-c", "import urllib.request; urllib.request.urlopen('http://localhost:4000/health/readiness', timeout=5)"]
      interval: 30s
      timeout: 10s
      retries: 3

networks:
  litellm-net:
    driver: bridge
EOF
```

### Configuração (config.yaml)
```bash
cat > config.yaml << 'EOF'
# ============================================================================
# LiteLLM Proxy - CT-207
# Gateway unificado para AGLz AI Agency
# ============================================================================

model_list:
  # TIER 1: OLLAMA LOCAL (CT-200) - 90% das requisições
  - model_name: "local-llm"
    litellm_params:
      model: "ollama/llama3.1:70b"
      api_base: "http://192.168.0.200:11434"
      timeout: 120
      
  - model_name: "local-code"
    litellm_params:
      model: "ollama/codellama:70b"
      api_base: "http://192.168.0.200:11434"
      timeout: 180
      
  - model_name: "local-fast"
    litellm_params:
      model: "ollama/mistral:7b"
      api_base: "http://192.168.0.200:11434"
      timeout: 60

  # TIER 2: CLOUD PROVIDERS (10% das requisições)
  - model_name: "glm"
    litellm_params:
      model: "openai/glm-5"
      api_base: "https://api.z.ai/v1"
      api_key: "os.environ/ZAI_API_KEY"
      
  - model_name: "claude-opus"
    litellm_params:
      model: "anthropic/claude-opus-4-6"
      api_key: "os.environ/ANTHROPIC_API_KEY"

  - model_name: "gpt-4"
    litellm_params:
      model: "openai/gpt-4"
      api_key: "os.environ/OPENAI_API_KEY"

router_settings:
  routing_strategy: "cost-based"
  fallback_strategy: "lowest-cost"
  cooldown_time: 30

litellm_settings:
  cache: true
  cache_params:
    type: "redis"
    host: "192.168.0.137"
    port: 6379
    ttl: 3600
  
  rate_limit:
    - model: "local-llm"
      tpm: 10000
      rpm: 1000

general_settings:
  master_key: "os.environ/LITELLM_MASTER_KEY"
EOF

# Iniciar
docker-compose up -d
```

---

## 🔗 ENDPOINTS DOS SERVIÇOS

| Serviço | CT | IP:Port | Clientes |
|---------|-----|---------|----------|
| **LiteLLM** | CT-207 | 192.168.0.207:4000 | Todos os serviços |
| **Ollama** | CT-200 | 192.168.0.200:11434 | Via LiteLLM |
| **OpenClaw** | CT-203 | 192.168.0.203:8080 | Usuários |
| **Hermes** | CT-204 | 192.168.0.204:8080 | Usuários |
| **AGLz Crew** | CT-205 | 192.168.0.205:8080 | Usuários |
| **Ruflo** | CT-206 | 192.168.0.206:8080 | Sistema |
| **N8N** | CT-202 | 192.168.0.202:5678 | Workflows |
| **Redis** | CT-137 | 192.168.0.137:6379 | Cache |
| **PostgreSQL** | CT-149 | 192.168.0.149:5432 | Database |
| **Monitoring** | CT-209 | 192.168.0.209:3000 | Dashboards |

---

## 📋 RESUMO FINAL

### CTs Existentes (11 CTs)
- **Infrastructure**: CT-131, CT-137, CT-149, CT-180, CT-182, CT-183, CT-184
- **AI/ML**: CT-200, CT-202
- **Não usados**: CT-201, CT-210

### Novos CTs (5 CTs)
- **CT-203**: OpenClaw Agent
- **CT-204**: Hermes Agent
- **CT-205**: AGLz Crew (Agência)
- **CT-206**: Ruflo Orchestrator
- **CT-207**: **LiteLLM Proxy** ⭐
- **CT-209**: Monitoring

**Total**: 16 CTs (11 existentes + 5 novos)

---

**Plano finalizado por**: Jarvis AI
**Data**: 2026-04-18
**Versão**: 6.0 (LiteLLM em CT-207)
**Status**: ✅ Pronto para implementação
