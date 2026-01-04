# Archon Tailscale MCP Connection - Fix Guide

> **Date**: 2026-01-03
> **Issue**: MCP connection via Tailscale (100.80.30.59:8051)
> **Status**: ✅ Servidor funcionando, comando de conexão corrigido

---

## 🔍 Diagnóstico

### Status do Servidor

✅ **Servidor respondendo**: Porta 8051 acessível via Tailscale
✅ **Conectividade**: Ping OK, porta escutando corretamente
⚠️ **Health check**: Falhando (problema no script, não afeta serviço)
✅ **Logs**: Conexões SSE bem-sucedidas de outros clientes

### Erro Observado

```
HTTP/1.1 406 Not Acceptable
"Client must accept text/event-stream"
```

**Causa**: O servidor MCP usa Server-Sent Events (SSE) e requer headers específicos.

---

## ✅ Solução

### Comando Correto para Claude Code

```bash
# Tailscale (backup external)
claude mcp add --transport http archon-tailscale http://100.80.30.59:8051/mcp
```

**Importante**: Use `--transport http` (não `sse`), pois o Claude Code gerencia o protocolo SSE internamente.

### Verificar Conexão

```bash
# Listar servidores MCP
claude mcp list

# Deve mostrar:
# archon-tailscale - Connected ✅
```

### Testar Endpoint Manualmente

```bash
# Teste básico (deve retornar erro 406 - esperado)
curl http://100.80.30.59:8051/mcp

# Teste com headers SSE (deve retornar erro de sessão - esperado)
curl -H "Accept: text/event-stream" http://100.80.30.59:8051/mcp
```

**Nota**: Erros 406/400 em `curl` são esperados - o MCP requer um cliente compatível (Claude Code).

---

## 🔧 Troubleshooting

### Se a conexão ainda falhar:

1. **Verificar se o container está rodando**:
```bash
ssh root@192.168.0.245 'pct exec 183 -- docker ps --filter name=archon-mcp'
```

2. **Verificar logs do container**:
```bash
ssh root@192.168.0.245 'pct exec 183 -- docker logs archon-mcp --tail 20'
```

3. **Reiniciar o serviço MCP**:
```bash
ssh root@192.168.0.245 'pct exec 183 -- bash -c "cd /root/Archon && docker compose restart archon-mcp"'
```

4. **Verificar conectividade Tailscale**:
```bash
ping -c 3 100.80.30.59
```

5. **Testar porta**:
```bash
telnet 100.80.30.59 8051
# ou
nc -zv 100.80.30.59 8051
```

---

## 📋 Comandos Alternativos

### Se `--transport http` não funcionar:

```bash
# Tentar sem especificar transporte (Claude Code detecta automaticamente)
claude mcp add archon-tailscale http://100.80.30.59:8051/mcp
```

### Remover e readicionar:

```bash
# Remover conexão existente
claude mcp remove archon-tailscale

# Adicionar novamente
claude mcp add --transport http archon-tailscale http://100.80.30.59:8051/mcp
```

---

## 🎯 Endpoints Disponíveis

| Endpoint | URL | Status | Uso |
|----------|-----|--------|-----|
| **MCP** | http://100.80.30.59:8051/mcp | ✅ | Claude Code MCP |
| **UI** | http://100.80.30.59:3737 | ✅ | Interface Web |
| **API** | http://100.80.30.59:8181 | ✅ | FastAPI Backend |

---

## 📝 Notas Técnicas

### Health Check Issue

O container está marcado como "unhealthy" devido a um erro no script de health check:
```
NameError: name 'localhost' is not defined
```

**Impacto**: Nenhum - o serviço funciona normalmente. O health check pode ser corrigido posteriormente.

### Protocolo MCP

O Archon MCP usa **Server-Sent Events (SSE)**:
- Requer `Accept: text/event-stream` header
- Usa POST para requisições JSON-RPC
- Mantém sessão persistente via SSE stream

O Claude Code gerencia isso automaticamente quando você usa `--transport http`.

---

## ✅ Checklist de Verificação

- [ ] Ping para 100.80.30.59 funciona
- [ ] Porta 8051 está acessível
- [ ] Comando `claude mcp add` executado corretamente
- [ ] `claude mcp list` mostra archon-tailscale como Connected
- [ ] Teste de ferramenta MCP funciona (ex: `rag_search_knowledge_base`)

---

**Document Version**: 1.0.0
**Last Updated**: 2026-01-03
**Related Docs**: `docs/ARCHON.md`, `docs/QUICK-START.md`

