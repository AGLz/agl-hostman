# CT183 Management Scripts

Scripts para gerenciar containers Supabase e Archon no servidor CT183 (192.168.0.183).

## ⚠️ ORDEM CRÍTICA

**Supabase PRECISA iniciar ANTES do Archon**

O Archon depende do Supabase para:
- Banco de dados PostgreSQL
- API PostgREST
- API Gateway (Kong)

## 📜 Scripts Disponíveis

### 1. `ct183-startup.sh` - Iniciar Serviços

Inicia todos os containers na ordem correta com health checks.

```bash
# Uso normal
sudo ./ct183-startup.sh

# Forçar reinício completa (para + iniciar)
sudo ./ct183-startup.sh --force-restart
```

**O que faz:**
1. Verifica instalação do Docker
2. Inicia Supabase (13 containers)
3. Aguarda Supabase ficar saudável (timeout: 120s)
4. Inicia Archon (3 containers)
5. Aguarda Archon ficar saudável (timeout: 60s)
6. Verifica conectividade entre serviços
7. Mostra status final e endpoints

### 2. `ct183-stop.sh` - Parar Serviços

Para containers na ordem reversa (Archon primeiro, depois Supabase).

```bash
# Uso normal
sudo ./ct183-stop.sh

# Modo verbose (mostra mais detalhes)
sudo ./ct183-stop.sh --verbose
```

### 3. `ct183-health.sh` - Verificação de Saúde

Verifica o status de saúde de todos os serviços.

```bash
# Verificação básica
sudo ./ct183-health.sh

# Verificação detalhada (com logs)
sudo ./ct183-health.sh --detailed
```

**O que verifica:**
- Status de saúde dos containers (healthy/unhealthy/starting)
- Supabase: 8 serviços críticos
- Archon: 3 serviços
- Conectividade Archon → Supabase
- Endpoints e portas

## 🚀 Início Rápido

### Primeira Configuração

```bash
# 1. Copiar scripts para CT183
scp ./scripts/ct183-*.sh root@192.168.0.183:/root/

# 2. Acessar CT183
ssh root@192.168.0.183

# 3. Dar permissão de execução
chmod +x /root/ct183-*.sh

# 4. Executar script de startup
/root/ct183-startup.sh
```

### Operações Diárias

```bash
# Iniciar serviços
/root/ct183-startup.sh

# Verificar saúde
/root/ct183-health.sh

# Parar serviços
/root/ct183-stop.sh
```

## 🔌 Endpoints de Serviço

### Supabase
- API Gateway: http://192.168.0.183:8000
- PostgreSQL: postgres://postgres:***@192.168.0.183:5432/postgres

### Archon
- Web UI: http://192.168.0.183:3737
- MCP Server: http://192.168.0.183:8051/mcp
- API Backend: http://192.168.0.183:8181

## 📊 Códigos de Saída

| Código | Significado | Ação |
|--------|-------------|------|
| 0 | Todos os serviços saudáveis | Nenhuma |
| 1 | Alguns serviços degradados | Verificar logs |
| 2 | Serviços não rodando | Executar startup |

## 🔧 Troubleshooting

### Archon falha ao iniciar

```bash
# 1. Verificar se Supabase está rodando
docker ps | grep supabase

# 2. Iniciar Supabase primeiro
cd /root/supabase-self-hosted/supabase/docker
docker compose up -d

# 3. Aguardar Supabase ficar saudável
docker ps --filter "name=supabase" --filter "health=healthy"

# 4. Iniciar Archon
cd /root/Archon
docker compose up -d
```

### Timeout no health check

```bash
# Verificar logs dos containers
docker logs supabase-kong --tail 50
docker logs archon-server --tail 50

# Verificar conectividade manualmente
docker exec archon-server curl http://host.docker.internal:8000/rest/v1/
```

## 📝 Manutenção

```bash
# Health check diário
/root/ct183-health.sh

# Health check detalhado semanal
/root/ct183-health.sh --detailed

# Ver logs recentes
docker logs --tail 100 archon-server
docker logs --tail 100 supabase-kong
```

## 📚 Documentação Relacionada

- `../docs/CT183-STARTUP-GUIDE.md` - Guia completo de startup
- `../docs/updates/archon-supabase-integration-success.md` - Detalhes da integração

---

**Versão**: 1.0
**Última atualização**: 2025-01-05
**Responsável**: AGL Team
