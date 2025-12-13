# Guia de Extração de Tokens do Dokploy

**Data**: 2025-12-12
**Status**: Ação necessária para completar deployment

---

## 📋 Resumo

Para que o deployment automático via GitHub Actions funcione, precisamos dos tokens de autenticação dos webhooks do Dokploy.

## 🔍 Passos para Extrair os Tokens

### Passo 1: Acesse o Dokploy

Você já está com a página aberta: https://dok.aglz.io/

Se precisar fazer login:
- **URL**: https://dok.aglz.io
- **Alternativa LAN**: http://192.168.0.180:3000 (mais rápido, sem Cloudflare)

### Passo 2: Navegue até as Aplicações

1. No menu lateral, clique em **Applications** ou **Projects**
2. Localize os seguintes projetos (se existirem):
   - `agl-hostman-qa`
   - `agl-hostman-uat`
   - `agl-hostman-production`

### Passo 3: Extraia as URLs dos Webhooks

Para **cada aplicação**:

1. Clique na aplicação
2. Vá para **Settings** (Configurações)
3. Procure a seção **Webhooks** ou **Deploy Triggers**
4. Copie a URL completa do webhook

**Formato esperado**:
```
https://dok.aglz.io/api/webhook/deploy/{app-name}?token={SECRET_TOKEN}
```

### Passo 4: Atualize os Secrets do GitHub

Abra um terminal PowerShell e execute:

```powershell
# QA Webhook
echo -n "URL_COMPLETA_QA_AQUI" | gh secret set DOKPLOY_WEBHOOK_URL_QA --repo aguileraz/agl-hostman

# UAT Webhook
echo -n "URL_COMPLETA_UAT_AQUI" | gh secret set DOKPLOY_WEBHOOK_URL_UAT --repo aguileraz/agl-hostman

# Production Webhook
echo -n "URL_COMPLETA_PROD_AQUI" | gh secret set DOKPLOY_WEBHOOK_URL_PRODUCTION --repo aguileraz/agl-hostman
```

### Passo 5: Verificação

```powershell
# Listar secrets configurados
gh secret list --repo aguileraz/agl-hostman

# Testar webhook (localmente no CT180)
ssh root@192.168.0.180 'curl -X POST "http://localhost:3000/api/webhook/deploy/agl-hostman-qa?token=SEU_TOKEN" -H "Content-Type: application/json" -d "{}"'
```

---

## 🚨 Alternativa: Se as Aplicações Ainda Não Existem

Se as aplicações `agl-hostman-qa`, `agl-hostman-uat` e `agl-hostman-production` ainda não existem no Dokploy, você precisará criá-las primeiro:

### Criar Aplicação no Dokploy

1. Clique em **+ Create Application**
2. Configure:
   - **Name**: `agl-hostman-qa`
   - **Type**: Docker (ou Docker Compose)
   - **Image**: `ghcr.io/aguileraz/agl-hostman:qa-latest`
3. Após criar, vá em **Settings** → **Webhooks** para obter o token

### Configuração Mínima por Ambiente

| Ambiente | Nome | Imagem | Porta |
|----------|------|--------|-------|
| QA | `agl-hostman-qa` | `ghcr.io/aguileraz/agl-hostman:qa-latest` | 3001 |
| UAT | `agl-hostman-uat` | `ghcr.io/aguileraz/agl-hostman:uat-latest` | 3002 |
| Production | `agl-hostman-production` | `ghcr.io/aguileraz/agl-hostman:production-latest` | 3000 |

---

## 📊 Checklist

- [ ] Acessar Dokploy UI
- [ ] Verificar se aplicações existem (criar se necessário)
- [ ] Extrair token do webhook QA
- [ ] Extrair token do webhook UAT
- [ ] Extrair token do webhook Production
- [ ] Atualizar secrets do GitHub
- [ ] Testar webhook localmente
- [ ] Configurar bypass Cloudflare WAF (ver `docs/CLOUDFLARE-BYPASS-SOLUTION.md`)
- [ ] Executar deployment de teste

---

## 🔗 Referências

- **Dokploy Docs**: https://docs.dokploy.com
- **Cloudflare Bypass**: `docs/CLOUDFLARE-BYPASS-SOLUTION.md`
- **GitHub Actions IPs**: https://api.github.com/meta
- **Script de Configuração**: `scripts/configure-github-secrets.sh`

---

**Status**: Aguardando extração de tokens pelo usuário
