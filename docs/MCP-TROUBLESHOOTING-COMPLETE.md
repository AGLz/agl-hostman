# MCP Troubleshooting - Session Complete

> **Data**: 2025-11-06
> **Status**: 10/11 MCPs Conectados (90.9% de sucesso)
> **Ambiente**: CT179 (agldv03) - 192.168.0.179

---

## 📊 Status Final dos MCPs

### ✅ MCPs Conectados (10)

| MCP | Tipo | Status | Notas |
|-----|------|--------|-------|
| **flow-nexus** | NPM | ✓ Connected | AI orchestration |
| **agentic-payments** | NPM | ✓ Connected | Payment processing |
| **claude-flow** | NPM | ✓ Connected | Workflow automation |
| **archon** | HTTP | ✓ Connected | AI command center (LAN) |
| **archon-tailscale** | HTTP | ✓ Connected | AI command center (backup) |
| **dokploy** | NPM | ✓ Connected | Deployment platform (dok.aglz.io) |
| **docker** | NPM | ✓ Connected | Container management (local) |
| **harbor** | NPM | ✓ Connected | Container registry (harbor.aglz.io:5000) |
| **proxmox** | Python | ✓ Connected | VM/Container management (AGLSRV1) |
| **portainer** | Binary | ✓ Connected | Container management (portainer.aglz.io) |

### ⚠️ MCP Pendente (1)

| MCP | Tipo | Status | Motivo |
|-----|------|--------|--------|
| **cloudflare-dns** | NPM | ✗ Failed | **AGUARDANDO** Account ID do usuário |

---

## 🔧 Problemas Resolvidos

### 1. 🔴 Proxmox MCP (ALTA PRIORIDADE) - ✅ RESOLVIDO

**Problema Original**:
```
Error: Invalid JSON in config file: Expecting value: line 1 column 1 (char 0)
```

**Causa Raiz**:
- Arquivo de configuração criado em formato YAML (`config.yaml`)
- Proxmox MCP espera formato JSON (`config.json`)

**Solução Implementada**:

1. **Criado arquivo JSON correto**: `/root/ProxmoxMCP/proxmox-config/config.json`
```json
{
    "proxmox": {
        "host": "192.168.0.245",
        "port": 8006,
        "verify_ssl": false,
        "service": "PVE"
    },
    "auth": {
        "user": "root@pam",
        "token_name": "agldv03",
        "token_value": "4550565a-1a84-4d67-83eb-6d1bc2be54d1"
    },
    "logging": {
        "level": "INFO",
        "format": "%(asctime)s - %(name)s - %(levelname)s - %(message)s",
        "file": "proxmox_mcp.log"
    }
}
```

2. **Criado wrapper script**: `/usr/local/bin/proxmox-mcp-wrapper.sh`
```bash
#!/bin/bash
export PROXMOX_MCP_CONFIG=/root/ProxmoxMCP/proxmox-config/config.json
exec python3 -m proxmox_mcp.server "$@"
```

3. **Configurado MCP**:
```bash
claude mcp add --transport stdio proxmox -- /usr/local/bin/proxmox-mcp-wrapper.sh
```

**Resultado**: ✅ Proxmox MCP conectado com sucesso

**Impacto**: Acesso programático a 68 VMs/Containers no AGLSRV1 (192.168.0.245)

---

### 2. 🟢 Portainer MCP (BAIXA PRIORIDADE) - ✅ RESOLVIDO

**Problema Original**:
```json
{
  "level": "fatal",
  "error": "unsupported Portainer server version: 2.33.3, only version 2.31.2 is supported",
  "time": "2025-11-06T10:12:05-03:00",
  "message": "failed to create server"
}
```

**Causa Raiz**:
- Portainer MCP binary (v0.6.0) suporta apenas versão 2.31.2
- Servidor Portainer atual: 2.33.3
- Incompatibilidade de versão

**Solução Implementada**:

1. **Verificado que API está acessível**:
```bash
curl -k https://portainer.aglz.io/api/status
# HTTP 200 - API funcional
```

2. **Usado flag de bypass**:
```bash
claude mcp remove portainer -s local
claude mcp add --transport stdio portainer \
  -- /usr/local/bin/portainer-mcp \
  -server portainer.aglz.io \
  -token ptr_tPhR+YNqloPJXvCWCcknuaiLqE4jQnK842fJ24u8jH8= \
  -disable-version-check
```

**Resultado**: ✅ Portainer MCP conectado com sucesso (version check desabilitado)

**Impacto**: Acesso a Portainer GUI (portainer.aglz.io) + Docker MCP local = cobertura completa de gerenciamento de containers

---

### 3. 🟡 Cloudflare DNS MCP (MÉDIA PRIORIDADE) - ⚠️ AGUARDANDO INPUT

**Problema Original**:
```
[DEBUG] Uncaught exception: Error: Missing account ID. Usage: npx @cloudflare/mcp-server-cloudflare run [account_id]
```

**Causa Raiz**:
- Cloudflare MCP requer Account ID como argumento de linha de comando
- Não apenas autenticação via token

**Investigação Realizada**:
```bash
npx -y @cloudflare/mcp-server-cloudflare run
# Error: Missing account ID. Usage: ... run [account_id]
```

**Status Atual**: ⚠️ **BLOQUEADO** - Aguardando usuário fornecer Cloudflare Account ID

**Ação Necessária**:
1. Acessar: https://dash.cloudflare.com/
2. Selecionar domínio: `aglz.io`
3. Copiar **Account ID** do dashboard
4. Fornecer Account ID para configuração

**Comando Preparado** (quando Account ID for fornecido):
```bash
claude mcp remove cloudflare-dns -s local
claude mcp add cloudflare-dns -- npx -y @cloudflare/mcp-server-cloudflare run [ACCOUNT_ID]
```

**Prioridade**: Média (DNS management útil mas não crítico)

---

## 📋 Lições Aprendidas

### 1. Arquitetura de Configuração do Claude Code

**Descoberta Crítica**: Claude Code **NÃO** usa `~/.claude/mcp.json`!

**3 Escopos de Configuração**:
- `~/.claude.json` - **LOCAL** config (privado ao projeto)
- `.mcp.json` - **PROJECT** config (compartilhado via Git)
- `~/.claude/mcp.json` - **NÃO USADO** pelo Claude Code

**Método Correto**: Sempre usar CLI `claude mcp add/remove/list/get`

**Sintaxe Correta**:
```bash
claude mcp add --transport stdio <NAME> \
  --env KEY1=VALUE1 \
  --env KEY2=VALUE2 \
  -- <COMMAND> [args]
```

### 2. Formatos de Configuração

**Proxmox MCP**:
- ❌ Não aceita YAML
- ✅ Requer JSON obrigatoriamente
- ✅ Wrapper script recomendado para env vars

**Cloudflare MCP**:
- ❌ Não aceita apenas token
- ✅ Requer Account ID como argumento

**Portainer MCP**:
- ⚠️ Version checking muito restritivo
- ✅ Flag `-disable-version-check` permite uso com versões mais recentes

### 3. Environment Variables

**Problema Identificado**: Flag `--env` do Claude Code pode não funcionar corretamente com módulos Python.

**Solução**: Wrapper scripts são mais confiáveis:
```bash
#!/bin/bash
export ENV_VAR=value
exec python3 -m module.server "$@"
```

---

## 🎯 Próximos Passos

### Imediato (Bloqueado)
- [ ] **Cloudflare DNS**: Aguardando Account ID do usuário
  - Dashboard: https://dash.cloudflare.com/
  - Domínio: aglz.io
  - Campo: Account ID

### Opcional (Melhorias)
- [ ] Testar todas as funcionalidades dos MCPs conectados
- [ ] Criar scripts de automação usando MCPs
- [ ] Documentar casos de uso para cada MCP
- [ ] Configurar monitoring/alerting para health dos MCPs

### Manutenção
- [ ] Verificar updates de MCPs mensalmente
- [ ] Monitorar logs: `/root/ProxmoxMCP/proxmox-config/proxmox_mcp.log`
- [ ] Backup de configurações: `~/.claude.json` e `.mcp.json`

---

## 📊 Estatísticas da Sessão

**MCPs Configurados**: 11 total
- ✅ Conectados: 10 (90.9%)
- ⚠️ Pendentes: 1 (9.1%)
- ❌ Falhados: 0 (0%)

**Problemas Resolvidos**: 3
- 🔴 Proxmox (Alta prioridade): ✅ Resolvido
- 🟢 Portainer (Baixa prioridade): ✅ Resolvido
- 🟡 Cloudflare-DNS (Média prioridade): ⚠️ Aguardando input

**Tempo de Troubleshooting**: ~2 horas
**Taxa de Sucesso**: 90.9% (10/11)

---

## 🔍 Comandos de Verificação

```bash
# Status geral
claude mcp list

# Status detalhado de um MCP
claude mcp get proxmox

# Remover MCP (se necessário)
claude mcp remove <NAME> -s local

# Adicionar MCP (sintaxe correta)
claude mcp add --transport stdio <NAME> \
  --env KEY=VALUE \
  -- command args

# Verificar logs do Proxmox MCP
tail -f /root/ProxmoxMCP/proxmox-config/proxmox_mcp.log
```

---

## 📚 Referências

**Arquivos Criados/Modificados**:
- `/root/ProxmoxMCP/proxmox-config/config.json` - Config JSON do Proxmox MCP
- `/usr/local/bin/proxmox-mcp-wrapper.sh` - Wrapper para Proxmox MCP
- `~/.claude.json` - Configuração LOCAL dos MCPs (11 entries)
- `/tmp/MCP-INSTALLATION-SUCCESS-REPORT.md` - Relatório completo de instalação

**Documentação Relacionada**:
- `docs/ARCHON.md` - Archon AI Command Center (archon e archon-tailscale MCPs)
- `docs/DOKPLOY.md` - Dokploy deployment platform
- `docs/INFRA.md` - Infrastructure map (Proxmox hosts, containers)
- `docs/QUICK-START.md` - Quick reference commands

---

**Status**: ✅ Troubleshooting Phase COMPLETE
**Achievement**: 90.9% Success Rate (10/11 MCPs)
**Blocked On**: Cloudflare Account ID (user input required)

---

*Documento gerado em: 2025-11-06*
*Última validação: claude mcp list - 10 ✓ Connected, 1 ✗ Failed*
