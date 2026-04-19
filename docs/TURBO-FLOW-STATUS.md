# Turbo Flow v4.0 — Status Report

> **Atualizado**: 2026-03-20
> **Ambiente**: DevPod/CT185 (agldv12)

## Resumo Executivo

| Componente | Status | Versão | Nota |
|------------|--------|--------|------|
| **Ruflo** | ✅ Funcionando | v3.5.2 | Orquestração de swarms operacional |
| **Beads** | ✅ Funcionando | v0.61.0 | Memória cross-session com Dolt |
| **Dolt** | ✅ Funcionando | v1.83.8 | Backend SQL para Beads |
| **GitNexus** | ❌ Falhando | v1.4.6 | GLIBC 2.38 requerido (sistema: 2.36) |
| **flow-nexus swarm** | ❌ Falhando | v0.1.128 | Incompatível com Node.js v24 |
| **claude-flow MCP** | ✅ Funcionando | v3.1.0-alpha | 215+ MCP tools disponíveis |

## Análise Detalhada

### 1. GitNexus — GLIBC Incompatibility

**Erro:**
```
Error: /lib/x86_64-linux-gnu/libc.so.6: version `GLIBC_2.38' not found
```

**Causa Raiz:**
- GitNexus depende de `@ladybugdb/core` (v0.15.1)
- `@ladybugdb/core` tem dependência nativa que requer GLIBC 2.38
- Sistema Debian 12 tem GLIBC 2.36

**Soluções Possíveis:**

1. **Usar alternativa**: `@sparkleideas/plugin-code-intelligence` (v3.0.0-alpha)
   ```bash
   npm install -g @sparkleideas/plugin-code-intelligence
   ```

2. **Container Docker**: Rodar GitNexus em container com GLIBC atualizado
   ```bash
   docker run --rm -v $(pwd):/workspace node:20-slim npx gitnexus analyze
   ```

3. **Atualizar sistema**: Upgrade para Debian 13 (quando disponível) ou Ubuntu 24.04

### 2. flow-nexus — Node.js v24 Incompatibility

**Erros:**
```
Error [ERR_USE_AFTER_CLOSE]: readline was closed
TypeError: Cannot read properties of null (reading 'id')
```

**Causa Raiz:**
- Node.js v24.13.0 mudou comportamento do readline
- Biblioteca `inquirer` não é compatível com Node v24
- flow-nexus usa APIs depreciadas

**Soluções Possíveis:**

1. **Usar Ruflo**: Ruflo é a alternativa recomendada e funciona corretamente
   ```bash
   ruflo swarm init --topology hierarchical --max-agents 8
   ruflo swarm start --objective "sua tarefa"
   ```

2. **Downgrade Node**: Usar Node v20 ou v22 LTS
   ```bash
   nvm install 20
   nvm use 20
   npx flow-nexus swarm init --topology hierarchical
   ```

3. **Aguardar fix**: Issues #42, #45, #48, #49 no GitHub do flow-nexus

### 3. Ruflo — Funcionando Corretamente

**Comandos Disponíveis:**
```bash
ruflo status              # Status do swarm
ruflo swarm init          # Inicializar swarm
ruflo swarm start         # Iniciar swarm
ruflo doctor              # Health check
ruflo agent spawn         # Criar agente
ruflo task orchestrate    # Orquestrar tarefa
```

**Exemplo de Uso:**
```bash
ruflo swarm init --topology hierarchical --max-agents 8
ruflo swarm start --objective "Analisar codebase e documentar arquitetura"
```

### 4. Beads — Funcionando com Dolt

**Comandos Disponíveis:**
```bash
bd ready         # Ver estado do projeto
bd add           # Adicionar issue/decisão
bd commit        # Commitar mudanças
bd doctor        # Health check
bd issues        # Listar issues
```

**Inicialização:**
```bash
# Dolt já instalado e configurado
bd init          # Já executado
bd ready         # "No open issues" ✅
```

## Recomendações

### Curto Prazo

1. **Usar Ruflo para orquestração** — Funciona perfeitamente
2. **Usar Beads para memória** — Funciona com Dolt
3. **Pular GitNexus** — Usar `grep`, `rg`, ou Claude Code nativo para análise de código

### Médio Prazo

1. **Instalar plugin alternativo** para code intelligence:
   ```bash
   npm install -g @sparkleideas/plugin-code-intelligence
   ```

2. **Considerar DevContainer** com Node v20 para compatibilidade total

### Longo Prazo

1. **Aguardar updates** dos pacotes para Node v24
2. **Contribuir com fixes** nos repositórios (open source)

## Comandos Turbo Flow Operacionais

```bash
# Aliases configurados em ~/.turboflow_aliases
turbo-status     # Ruflo status
turbo-help       # Ruflo help
rf-doctor        # Ruflo doctor
rf-swarm         # Ruflo swarm hierárquico
bd-ready         # Beads ready
bd-add           # Beads add
bd-commit        # Beads commit
wt-list          # Git worktree list
wt-add           # Git worktree add
```

## Referências

- [Ruflo GitHub](https://github.com/ruvnet/claude-flow) — Orquestração
- [Beads GitHub](https://github.com/steveyegge/beads) — Memória
- [GitNexus GitHub](https://github.com/abhigyanpatwari/GitNexus) — Code Intelligence
- [flow-nexus GitHub](https://github.com/ruvnet/flow-nexus) — Alternativa swarm
- [Dolt](https://github.com/dolthub/dolt) — SQL Database com Git
