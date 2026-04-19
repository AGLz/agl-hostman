# Próximos Passos - Deployment agl-hostman

> **Status Atual**: Infraestrutura 100% operacional, pronta para primeiro deployment
> **Localização**: CT179 limpo, Harbor e Dokploy operacionais em CT182 e CT180

---

## ✅ Infraestrutura Pronta

### Harbor Registry (CT182)
- **URL**: https://harbor.aglz.io
- **Status**: ✅ OPERACIONAL
- **Imagem Disponível**: harbor.aglz.io/dev/agl-hostman:dev-test (52.1MB)
- **Credenciais**: admin / Harbor12345
- **Projetos**: dev, qa, uat, prod (todos criados)

### Dokploy Platform (CT180)
- **URL Local**: http://192.168.0.180:3000/
- **URL Pública**: https://dok.aglz.io (pode ter erro "Invalid origin")
- **Status**: ✅ OPERACIONAL
- **Aguardando**: Registro de conta admin

### CT179 (agldv03)
- **Status**: ✅ LIMPO
- **Docker**: Configuração padrão restaurada
- **Imagens Harbor**: Removidas
- **Credenciais**: Removidas

---

## 🎯 Próximos Passos (20 minutos)

### Passo 1: Registrar Conta Admin no Dokploy (5 minutos)

**Acesse**: http://192.168.0.180:3000/

**Informações de Registro**:
- **Email**: carlos@aguileraz.net
- **Senha**: (escolher senha segura)
- **Nome da Organização**: AGL Infrastructure

**Completar**:
- Wizard de configuração inicial
- Configurações básicas da plataforma

---

### Passo 2: Configurar Harbor Registry no Dokploy (5 minutos)

Após login, adicionar o Harbor como registry:

**Configuração do Registry**:
- **Nome**: Harbor AGL
- **Tipo**: Harbor / Docker Registry
- **URL**: https://harbor.aglz.io
- **Username**: admin
- **Password**: Harbor12345
- **Verificar Conexão**: Testar antes de salvar

---

### Passo 3: Criar Primeiro Deployment (10 minutos)

**Criar Nova Aplicação**:
1. **Nome**: agl-hostman-dev
2. **Ambiente**: Development

**Configurar Source**:
- **Tipo**: Docker Image
- **Registry**: Harbor AGL (configurado no passo 2)
- **Imagem**: harbor.aglz.io/dev/agl-hostman:dev-test
- **Tag**: dev-test (ou latest)

**Configurações da Aplicação**:
- **Porta Interna**: 3000
- **Health Check Path**: /health
- **Health Check Interval**: 30s
- **Domain** (opcional): agl-hostman-dev.aglz.io

**Variáveis de Ambiente** (se necessário):
```bash
NODE_ENV=development
PORT=3000
LOG_LEVEL=info
```

**Recursos** (opcional):
- CPU Limit: 1 core
- Memory Limit: 512MB
- Restart Policy: always

**Deploy**:
- Clicar em "Deploy"
- Aguardar pull da imagem (~1 minuto)
- Aguardar container start (~30 segundos)

---

### Passo 4: Verificar Deployment (5 minutos)

**Verificações Automáticas no Dokploy**:
- Status do container: Running
- Health checks: Passing
- Logs: Sem erros
- Porta: Mapeamento correto

**Testes Manuais**:

```bash
# 1. Health endpoint
curl http://agl-hostman-dev.aglz.io/health
# Esperado: {"status":"healthy","timestamp":"...","environment":"development"}

# 2. API Overview
curl http://agl-hostman-dev.aglz.io/api/overview
# Esperado: JSON com informações gerais

# 3. API Containers
curl http://agl-hostman-dev.aglz.io/api/containers
# Esperado: Lista de containers

# 4. API Network
curl http://agl-hostman-dev.aglz.io/api/network
# Esperado: Status da rede
```

**Indicadores de Sucesso**:
- ✅ Container rodando no Dokploy
- ✅ Health checks passando
- ✅ Endpoint /health retorna HTTP 200
- ✅ APIs retornam JSON válido
- ✅ Logs não mostram erros críticos

---

## 🔧 Troubleshooting

### Se Dokploy Não Carregar
```bash
# Verificar serviços no CT180
ssh root@192.168.0.245 'pct exec 180 -- docker ps'

# Verificar logs
ssh root@192.168.0.245 'pct exec 180 -- docker logs dokploy-app --tail 50'

# Reiniciar se necessário
ssh root@192.168.0.245 'pct exec 180 -- docker compose -f /opt/dokploy/docker-compose.yml restart'
```

### Se Harbor Pull Falhar
```bash
# Testar credenciais do Harbor
curl -k -u admin:Harbor12345 https://harbor.aglz.io/api/v2.0/projects

# Verificar imagem existe
curl -k -u admin:Harbor12345 https://harbor.aglz.io/api/v2.0/projects/dev/repositories/agl-hostman/artifacts
```

### Se Container Não Subir
- Verificar logs no Dokploy
- Verificar porta 3000 não está em uso
- Verificar variáveis de ambiente
- Verificar health check path está correto

---

## 📊 Checklist de Deployment

### Pré-Deployment
- [x] Harbor operacional
- [x] Dokploy operacional
- [x] Imagem no Harbor registry
- [x] CT179 limpo e pronto
- [ ] **Conta admin Dokploy registrada** ← VOCÊ ESTÁ AQUI
- [ ] Registry Harbor configurado no Dokploy

### Deployment
- [ ] Aplicação criada no Dokploy
- [ ] Configuração de source definida
- [ ] Health checks configurados
- [ ] Deploy executado
- [ ] Container rodando

### Pós-Deployment
- [ ] Health endpoint respondendo
- [ ] APIs funcionando
- [ ] Logs sem erros
- [ ] Domínio configurado (opcional)
- [ ] Monitoramento configurado (fase futura)

---

## 🎯 Meta Final

**Objetivo**: Ter agl-hostman rodando e acessível via Dokploy

**Resultado Esperado**:
```bash
$ curl http://agl-hostman-dev.aglz.io/health
{"status":"healthy","timestamp":"2025-10-29T13:00:00.000Z","uptime":120.5,"environment":"development","version":"1.0.0"}
```

**Tempo Estimado**: 20 minutos do registro ao deployment funcionando

---

## 🚀 Após Primeiro Deployment

### Próximas Fases
1. **CI/CD Integration**: Conectar GitHub Actions ao Dokploy
2. **Multi-Environment**: Deployar em QA, UAT, e Prod
3. **Monitoring**: Configurar Grafana dashboards
4. **Scaling**: Configurar auto-scaling e load balancing
5. **Backup**: Configurar backup automatizado

### Documentação Relacionada
- **DEPLOYMENT-COMPLETE.md**: Status completo da infraestrutura
- **DEPLOYMENT-STATUS.md**: Histórico de deployment
- **DOKPLOY.md**: Guia completo do Dokploy
- **harbor-setup.md**: Guia do Harbor Registry

---

**Documento**: Próximos Passos
**Versão**: 1.0
**Data**: 2025-10-29
**Status**: Aguardando registro admin Dokploy
**Tempo Estimado**: 20 minutos até primeiro deployment
