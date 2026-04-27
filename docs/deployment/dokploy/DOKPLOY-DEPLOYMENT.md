# Deployment agl-hostman no Dokploy

> **Status**: Registry configurado ✅ - Pronto para criar aplicação
> **Data**: 2025-10-29

---

## ✅ Pré-requisitos Completos

- [x] Harbor Registry operacional (harbor.aglz.io)
- [x] Dokploy operacional (dok.aglz.io)
- [x] Imagem Docker no Harbor (harbor.aglz.io/dev/agl-hostman:dev-test - 155MB)
- [x] Registry Harbor adicionado no Dokploy ✅

---

## 🚀 Criar Aplicação no Dokploy (10 minutos)

### Passo 1: Criar Nova Aplicação

**Acesse o Dokploy**: https://dok.aglz.io

**Navegação**:
1. Clique em **"Projects"** ou **"Applications"** no menu lateral
2. Clique em **"New Application"** ou **"Create Application"**

**Configurações Básicas**:
- **Application Name**: `agl-hostman-dev`
- **Project** (se solicitado): Criar novo projeto "Development" ou usar default
- **Environment**: `development`
- **Description** (opcional): "AGL Infrastructure Dashboard - Development"

---

### Passo 2: Configurar Source (Docker Image)

**Source Configuration**:
- **Deployment Type**: `Docker Image` (não Git)
- **Registry**: Selecionar **"Harbor AGL"** (registry que você acabou de adicionar)
- **Image Name**: `harbor.aglz.io/dev/agl-hostman`
- **Image Tag**: `dev-test` (ou `latest`)

**Imagem Completa**: `harbor.aglz.io/dev/agl-hostman:dev-test`

---

### Passo 3: Configurar Application Settings

**Port Configuration**:
- **Internal Port**: `3000` (porta onde a aplicação escuta)
- **External Port** (opcional): Auto ou `80`/`443` se configurar domínio

**Health Check**:
- **Enable Health Check**: ✅ Yes
- **Health Check Type**: `HTTP`
- **Health Check Path**: `/health`
- **Health Check Interval**: `30s` (30 segundos)
- **Health Check Timeout**: `5s`
- **Health Check Retries**: `3`

**Domain Configuration** (opcional):
- **Domain**: `agl-hostman-dev.aglz.io` (se quiser URL personalizada)
- **Enable SSL**: Conforme disponibilidade no Dokploy
- **Se não configurar**: Aplicação ficará acessível via IP:Port

---

### Passo 4: Environment Variables (Opcional)

Se a aplicação precisar de variáveis de ambiente:

```bash
NODE_ENV=development
PORT=3000
LOG_LEVEL=info
```

**Nota**: A aplicação agl-hostman funciona sem variáveis específicas, essas são opcionais.

---

### Passo 5: Resource Limits (Opcional mas Recomendado)

**CPU & Memory**:
- **CPU Limit**: `1` core (1000m)
- **Memory Limit**: `512MB` (512Mi)
- **CPU Request**: `0.5` core (500m)
- **Memory Request**: `256MB` (256Mi)

**Restart Policy**:
- **Restart Policy**: `always`
- **Max Restart Attempts**: `3`

---

### Passo 6: Deploy!

1. **Revisar Configurações**: Verificar se tudo está correto
2. **Click "Deploy"** ou **"Create and Deploy"**
3. **Aguardar**:
   - Pull da imagem do Harbor (~1 minuto para 155MB)
   - Container start (~30 segundos)
   - Health check pass (~30 segundos)

**Monitorar Deployment**:
- Acompanhar logs em tempo real no Dokploy
- Ver status do container: "Starting" → "Healthy" → "Running"

---

## ✅ Verificação de Deployment

### Verificações Automáticas no Dokploy

**Status Dashboard**:
- ✅ Container Status: **Running**
- ✅ Health Check: **Passing** (verde)
- ✅ Logs: Sem erros críticos
- ✅ Resources: CPU e Memory dentro dos limites

**Logs Esperados**:
```
Server listening on port 3000
Health check endpoint ready at /health
Environment: development
```

---

### Testes Manuais

**1. Obter URL da Aplicação**:
- Se configurou domínio: `http://agl-hostman-dev.aglz.io`
- Se não configurou: Verificar no Dokploy qual porta foi exposta (ex: `http://192.168.0.180:8080`)

**2. Testar Health Endpoint**:
```bash
# Substituir URL conforme seu deployment
curl http://agl-hostman-dev.aglz.io/health

# Resposta esperada:
{
  "status": "healthy",
  "timestamp": "2025-10-29T...",
  "uptime": 120.5,
  "environment": "development",
  "version": "1.0.0"
}
```

**3. Testar API Endpoints**:
```bash
# Overview endpoint
curl http://agl-hostman-dev.aglz.io/api/overview
# Esperado: JSON com informações gerais do sistema

# Containers endpoint
curl http://agl-hostman-dev.aglz.io/api/containers
# Esperado: Lista de containers Docker

# Network endpoint
curl http://agl-hostman-dev.aglz.io/api/network
# Esperado: Status e informações de rede
```

**4. Testar Interface Web**:
```bash
# Abrir no navegador
http://agl-hostman-dev.aglz.io
# Esperado: Dashboard web carregando
```

---

## 🎯 Indicadores de Sucesso

### Deployment Bem-Sucedido
- ✅ Container status: **Running** no Dokploy
- ✅ Health checks: **Passing** (verde)
- ✅ Endpoint `/health`: Retorna HTTP 200 com JSON válido
- ✅ APIs retornam: JSON válido sem erros
- ✅ Logs mostram: Servidor iniciado sem erros críticos
- ✅ Resources: CPU/Memory estáveis e dentro dos limites

---

## 🔧 Troubleshooting

### Se Container Não Iniciar

**Verificar Logs no Dokploy**:
1. Acessar página da aplicação
2. Clicar na aba "Logs" ou "Console"
3. Procurar por erros:
   - Permission errors
   - Port already in use
   - Missing dependencies

**Comandos de Debug** (via Dokploy terminal ou SSH no CT180):
```bash
# Ver status do container
docker ps -a | grep agl-hostman

# Ver logs do container
docker logs <container-id>

# Verificar porta em uso
netstat -tlnp | grep 3000
```

---

### Se Image Pull Falhar

**Erro Comum**: "unauthorized" ou "failed to pull"

**Verificação**:
```bash
# No CT180, testar manualmente
ssh root@192.168.0.245 'pct exec 180 -- docker pull harbor.aglz.io/dev/agl-hostman:dev-test'

# Se falhar, verificar:
# 1. Registry credentials no Dokploy
# 2. /etc/hosts no CT180 (deve ter 192.168.0.182 harbor.aglz.io)
# 3. /etc/docker/daemon.json (insecure-registries configurado)
```

---

### Se Health Check Falhar

**Erro Comum**: "Health check failed" ou container restart loop

**Verificações**:
1. Container está realmente escutando na porta 3000?
   ```bash
   docker exec <container-id> netstat -tlnp | grep 3000
   ```

2. Endpoint `/health` está acessível?
   ```bash
   docker exec <container-id> curl -s http://localhost:3000/health
   ```

3. Health check path está correto no Dokploy? (deve ser `/health`)

---

### Se Aplicação Não Responder

**Verificar Rede**:
1. Container tem IP interno?
   ```bash
   docker inspect <container-id> | grep IPAddress
   ```

2. Porta está exposta corretamente?
   ```bash
   docker port <container-id>
   ```

3. Firewall ou iptables bloqueando?
   ```bash
   # No CT180
   iptables -L -n | grep 3000
   ```

---

## 📊 Métricas e Monitoramento

### Métricas no Dokploy

**Dashboard**:
- **CPU Usage**: Deve estar < 50% em idle
- **Memory Usage**: Deve estar ~200-300MB em idle
- **Network I/O**: Traffic normal para API requests
- **Restart Count**: Deve ser 0 (sem restarts)

**Logs**:
- Monitorar por erros recorrentes
- Verificar latência de requests
- Acompanhar uso de recursos ao longo do tempo

---

## 🎯 Próximos Passos Após Deployment

### Fase 1: Validação (Concluída com este deployment)
- [x] Harbor Registry operacional
- [x] Dokploy operacional
- [x] Registry configurado no Dokploy
- [ ] **Primeiro deployment funcionando** ← VOCÊ ESTÁ AQUI

### Fase 2: Automação (Próxima)
- [ ] CI/CD Pipeline (GitHub Actions)
- [ ] Deployment automático em push para branch `develop`
- [ ] Testes automáticos antes do deploy
- [ ] Notificações de deployment

### Fase 3: Multi-Environment (Futura)
- [ ] Deploy em QA (ambiente de testes)
- [ ] Deploy em UAT (ambiente de homologação)
- [ ] Deploy em Prod (ambiente de produção)
- [ ] Estratégia de rollback

### Fase 4: Observabilidade (Futura)
- [ ] Grafana dashboards
- [ ] Prometheus metrics
- [ ] Alerting rules
- [ ] Log aggregation

---

## 📝 Checklist de Deployment

### Pré-Deployment
- [x] Harbor operacional
- [x] Dokploy operacional
- [x] Imagem no Harbor
- [x] Registry configurado no Dokploy

### During Deployment
- [ ] Aplicação criada no Dokploy
- [ ] Source configurado (Docker Image)
- [ ] Health checks configurados
- [ ] Resource limits definidos
- [ ] Deploy executado

### Post-Deployment
- [ ] Container rodando (status: Running)
- [ ] Health check passando
- [ ] Endpoint `/health` retorna HTTP 200
- [ ] APIs retornam JSON válido
- [ ] Interface web carregando
- [ ] Logs sem erros críticos

---

## 🎉 Sucesso Esperado

**Resultado Final**:
```bash
$ curl http://agl-hostman-dev.aglz.io/health
{
  "status": "healthy",
  "timestamp": "2025-10-29T13:00:00.000Z",
  "uptime": 120.5,
  "environment": "development",
  "version": "1.0.0"
}

$ curl http://agl-hostman-dev.aglz.io/api/overview
{
  "containers": {
    "total": 68,
    "running": 65,
    "stopped": 3
  },
  "resources": {
    "cpu": "45%",
    "memory": "38.2GB / 128GB"
  },
  "network": {
    "interfaces": 4,
    "status": "healthy"
  }
}
```

**Dokploy Dashboard**:
- 🟢 Application: agl-hostman-dev
- 🟢 Status: Running
- 🟢 Health: Healthy
- 🟢 Uptime: 5m 30s
- 📊 CPU: 5% / Memory: 245MB

---

## 📚 Documentação Relacionada

- **DEPLOYMENT-COMPLETE.md**: Status completo da infraestrutura
- **NEXT-STEPS.md**: Guia em português dos próximos passos
- **DEPLOYMENT-STATUS.md**: Histórico de deployment
- **harbor-setup.md**: Configuração do Harbor Registry

---

**Documento**: Deployment no Dokploy
**Versão**: 1.0
**Data**: 2025-10-29
**Próximo Passo**: Criar aplicação agl-hostman-dev no Dokploy
**Tempo Estimado**: 10 minutos
