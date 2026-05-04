# 📋 INVENTÁRIO DE CTs - AGLSRV1

> **Data**: 2026-04-18
> **Host**: AGLSRV1 (192.168.0.245)
> **Responsável**: Jarvis AI
> **Projeto**: AGLz AI Agency

---

## ✅ CTs EXISTENTES - INFRASTRUCTURE

### CT-131: MySQL
| Atributo | Valor |
|----------|-------|
| **IP** | 192.168.0.131 |
| **Status** | ✅ Running |
| **Memory** | 2GB |
| **Cores** | 2 |
| **Uso no Projeto** | Dados legados |
| **Serviço** | MySQL 8.0 |
| **Porta** | 3306 |

**Verificação:**
```bash
pct exec 131 -- mysql -V
# mysql  Ver 8.0.35
```

---

### CT-137: Redis ⭐
| Atributo | Valor |
|----------|-------|
| **IP** | 192.168.0.137 |
| **Status** | ✅ Running |
| **Memory** | 2GB |
| **Cores** | 1 |
| **Uso no Projeto** | **Cache compartilhado** |
| **Serviço** | Redis 7 |
| **Porta** | 6379 |

**Verificação:**
```bash
pct exec 137 -- redis-cli ping
# PONG
```

**Uso:** Cache do LiteLLM, sessões, rate limiting

---

### CT-149: PostgreSQL ⭐
| Atributo | Valor |
|----------|-------|
| **IP** | 192.168.0.149 |
| **Status** | ✅ Running |
| **Memory** | 4GB |
| **Cores** | 2 |
| **Uso no Projeto** | **Database principal** |
| **Serviço** | PostgreSQL 16 |
| **Porta** | 5432 |

**Verificação:**
```bash
pct exec 149 -- pg_isready
# /var/run/postgresql:5432 - accepting connections
```

**Uso:** LiteLLM, CrewAI, OpenClaw, Hermes, Ruflo

---

### CT-180: Dokploy
| Atributo | Valor |
|----------|-------|
| **IP** | 192.168.0.180 |
| **Status** | ✅ Running |
| **Memory** | 4GB |
| **Cores** | 2 |
| **Uso no Projeto** | Deploys |
| **Serviço** | Dokploy PaaS |
| **Porta** | 3000 |

**Verificação:**
```bash
curl -s http://192.168.0.180:3000/api/status | jq
```

---

### CT-182: Harbor
| Atributo | Valor |
|----------|-------|
| **IP** | 192.168.0.182 |
| **Status** | ✅ Running |
| **Memory** | 4GB |
| **Cores** | 2 |
| **Uso no Projeto** | Docker Registry |
| **Serviço** | Harbor |
| **Porta** | 443 |

**Verificação:**
```bash
curl -s -o /dev/null -w "%{http_code}" https://192.168.0.182
# 200
```

---

### CT-183: Archon
| Atributo | Valor |
|----------|-------|
| **IP** | 192.168.0.183 |
| **Status** | ✅ Running |
| **Memory** | 4GB |
| **Cores** | 2 |
| **Uso no Projeto** | Knowledge Base |
| **Serviço** | Archon AI MCP |
| **Porta** | 8051 |

**Verificação:**
```bash
curl -s http://192.168.0.183:8051/health
```

---

### CT-184: Supabase
| Atributo | Valor |
|----------|-------|
| **IP** | 192.168.0.184 |
| **Status** | ✅ Running |
| **Memory** | 4GB |
| **Cores** | 2 |
| **Uso no Projeto** | Vector DB + Auth |
| **Serviço** | Supabase |
| **Porta** | 8000 |

**Verificação:**
```bash
curl -s http://192.168.0.184:8000/health
```

---

## 🤖 CTs EXISTENTES - AI/ML

### CT-200: Ollama ⭐
| Atributo | Valor |
|----------|-------|
| **IP** | 192.168.0.200 |
| **Tailscale** | 100.116.57.111 |
| **Status** | ✅ Running |
| **Memory** | 8GB |
| **Cores** | 4 |
| **GPU** | GTX 1650 4GB |
| **Uso no Projeto** | **LLMs locais** |
| **Serviço** | Ollama |
| **Porta** | 11434 |

**Verificação:**
```bash
curl -s http://192.168.0.200:11434/api/tags | jq '.models | length'
# 5+ modelos
```

**Modelos disponíveis:**
- llama3.1:70b
- codellama:70b
- mistral:7b
- qwen2.5:14b

---

### CT-202: N8N
| Atributo | Valor |
|----------|-------|
| **IP** | 192.168.0.202 |
| **Status** | ✅ Running |
| **Memory** | 4GB |
| **Cores** | 2 |
| **Uso no Projeto** | Workflows |
| **Serviço** | N8N |
| **Porta** | 5678 |

**Verificação:**
```bash
curl -s http://192.168.0.202:5678/healthz
```

---

## ❌ CTs NÃO UTILIZADOS

### CT-201: AMP Server
| Atributo | Valor |
|----------|-------|
| **IP** | 192.168.0.201 |
| **Status** | ✅ Running |
| **Uso no Projeto** | ❌ Não fará parte |
| **Motivo** | Serviço legado (AMP Game Panel) |

**Ação:** Manter como está, não integrar ao projeto

---

### CT-210: (Existente)
| Atributo | Valor |
|----------|-------|
| **Status** | ✅ Running |
| **Uso no Projeto** | ❌ Não usaremos |
| **Motivo** | Já existe, ID reservado para outro uso |

**Ação:** Não criar novo CT-210, usar CT-207 para LiteLLM

---

## 🆕 CTs A SEREM CRIADOS

| CT | Nome | IP | Recursos | Função |
|----|------|-----|----------|--------|
| **CT-203** | openclaw-agent | 192.168.0.203 | 4GB / 2 CPU | Assistente Executivo |
| **CT-204** | hermes-agent | 192.168.0.204 | 4GB / 2 CPU | Assistente Estratégico |
| **CT-205** | **aglz-crew** | **192.168.0.205** | **16GB / 8 CPU** | **Agência Principal** |
| **CT-206** | ruflo-orch | 192.168.0.206 | 4GB / 2 CPU | Orquestração |
| **CT-207** | **litellm-proxy** | **192.168.0.207** | **8GB / 4 CPU** | **LiteLLM Gateway** |
| **CT-209** | monitoring | 192.168.0.209 | 4GB / 2 CPU | Prometheus/Grafana |

---

## 📊 RESUMO

| Categoria | Quantidade | CTs |
|-----------|------------|-----|
| **Infrastructure** | 7 | 131, 137, 149, 180, 182, 183, 184 |
| **AI/ML** | 2 | 200, 202 |
| **Não utilizados** | 2 | 201, 210 |
| **Novos (a criar)** | 6 | 203, 204, 205, 206, 207, 209 |
| **Total** | **17** | - |

---

## 🔧 PRÓXIMOS PASSOS

1. **Criar databases** no CT-149 (PostgreSQL)
2. **Criar CT-207** (LiteLLM Proxy)
3. **Criar CTs 203, 204, 205, 206, 209**
4. **Configurar integrações**
5. **Testar comunicação**

---

**Documento gerado por**: Jarvis AI
**Data**: 2026-04-18
**Local**: D:\apps\dev\agl\agl-hostman\docs\
**Status**: ✅ Inventário completo
