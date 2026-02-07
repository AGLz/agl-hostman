# Claude Flow Hive-Mind Database Fix

> **Date**: 2026-01-03
> **Issue**: Database initialization failure due to better-sqlite3 module version mismatch
> **Status**: ✅ RESOLVED

---

## 🔍 Problema Identificado

### Sintomas

```bash
$ claude-flow hive-mind init
✖ Failed to initialize Hive Mind system
Error: The module '/root/node_modules/better-sqlite3/build/Release/better_sqlite3.node'
was compiled against a different Node.js version using
NODE_MODULE_VERSION 115. This version of Node.js requires
NODE_MODULE_VERSION 108.
```

### Causa Raiz

1. **Módulo better-sqlite3 compilado para Node.js 22** (NODE_MODULE_VERSION 115)
2. **Claude Flow usando Node.js 18** (NODE_MODULE_VERSION 108)
3. **Arquivo hive.db principal ausente** - apenas arquivos auxiliares (WAL/SHM) existiam
4. **Módulo não recompilado** para a versão correta do Node.js

### Arquivos Encontrados

```bash
.hive-mind/
├── hive.db-shm      # Shared memory (33KB) - órfão
├── hive.db-wal      # Write-ahead log (4.1MB) - órfão
├── memory.db        # Database de memória (16KB) - OK
└── hive.db          # ❌ AUSENTE (arquivo principal)
```

---

## ✅ Solução Implementada

### Passo 1: Verificar Versão do Node.js

```bash
nvm use 18.20.8
node --version  # v18.20.8
```

### Passo 2: Recompilar better-sqlite3

```bash
cd /root/node_modules/better-sqlite3
npm run build-release
```

**Output esperado**:
```
SOLINK_MODULE(target) Release/obj.target/better_sqlite3.node
COPY Release/better_sqlite3.node
✔ Build successful
```

### Passo 3: Inicializar Hive Mind

```bash
claude-flow hive-mind init
```

**Output esperado**:
```
✔ Hive Mind system initialized successfully!
✓ Created .hive-mind directory
✓ Initialized SQLite database
✓ Created configuration file
```

### Passo 4: Limpar Arquivos Órfãos

```bash
rm -f .hive-mind/hive.db-shm .hive-mind/hive.db-wal
```

### Passo 5: Verificar Integridade

```bash
sqlite3 .hive-mind/hive.db "PRAGMA integrity_check;"
# Output: ok

sqlite3 .hive-mind/hive.db ".tables"
# Output: (tabelas criadas)
```

---

## 🔧 Comandos de Verificação

### Verificar Status do Hive Mind

```bash
claude-flow hive-mind status
# Output: No active swarms found (ou status de swarms ativos)
```

### Verificar Arquivos do Database

```bash
ls -lah .hive-mind/*.db*
# Deve mostrar:
# - .hive-mind/hive.db (arquivo principal)
# - .hive-mind/memory.db (database de memória)
```

### Verificar Integridade do Database

```bash
sqlite3 .hive-mind/hive.db "PRAGMA integrity_check;"
# Deve retornar: ok
```

---

## 📋 Pré-requisitos para Build

### Dependências Necessárias

```bash
# Python 3 (para node-gyp)
which python3  # Deve retornar caminho

# Make (para compilação)
which make     # Deve retornar caminho

# Build tools (se necessário)
sudo apt-get install build-essential python3
```

### Verificar Versão do Node.js

```bash
# O wrapper usa Node.js 18.20.8
cat /root/.local/bin/hive-mind-wrapper
# Deve mostrar: nvm use 18.20.8
```

---

## 🚨 Troubleshooting

### Problema: Build Falha

**Sintoma**:
```
Error: Cannot find module 'node-gyp'
```

**Solução**:
```bash
npm install -g node-gyp
cd /root/node_modules/better-sqlite3
npm run build-release
```

### Problema: Permissões Negadas

**Sintoma**:
```
EACCES: permission denied
```

**Solução**:
```bash
sudo chown -R $USER:$USER /root/node_modules/better-sqlite3
chmod -R 755 /root/node_modules/better-sqlite3
```

### Problema: Módulo Ainda Não Funciona

**Sintoma**: Erro persiste após rebuild

**Solução**:
```bash
# Remover completamente e reinstalar
cd /root
rm -rf node_modules/better-sqlite3
npm install better-sqlite3@11.10.0
cd node_modules/better-sqlite3
npm run build-release
```

### Problema: Database Corrompido

**Sintoma**:
```
Error: database disk image is malformed
```

**Solução**:
```bash
# Backup
cp .hive-mind/hive.db .hive-mind/hive.db.backup

# Recriar database
rm .hive-mind/hive.db
claude-flow hive-mind init
```

---

## 📊 Estrutura do Database Após Fix

```
.hive-mind/
├── hive.db          # ✅ Arquivo principal (criado)
├── memory.db         # ✅ Database de memória
├── config.json       # ✅ Configuração do sistema
├── sessions/         # Sessions ativas
├── backups/          # Backups automáticos
├── logs/             # Logs do sistema
└── memory/            # Memória coletiva
```

**Tabelas no hive.db**:
- `swarms` - Swarms ativos e históricos
- `sessions` - Sessões de trabalho
- `workers` - Workers e seus estados
- `tasks` - Tarefas atribuídas
- `consensus` - Resultados de consenso
- `memory` - Memória compartilhada

---

## ✅ Checklist de Verificação

- [x] Node.js 18.20.8 ativo
- [x] better-sqlite3 recompilado para Node.js 18
- [x] hive.db criado com sucesso
- [x] Arquivos WAL/SHM órfãos removidos
- [x] Database integridade verificada
- [x] Hive Mind inicializado corretamente
- [x] Status do hive-mind funcionando

---

## 🔄 Prevenção Futura

### 1. Manter Versão do Node.js Consistente

```bash
# Sempre usar Node.js 18.20.8 para claude-flow
nvm use 18.20.8
```

### 2. Recompilar Após Atualizar Node.js

```bash
# Se mudar versão do Node.js, recompilar:
cd /root/node_modules/better-sqlite3
npm run build-release
```

### 3. Verificar Antes de Usar

```bash
# Verificar se hive.db existe
test -f .hive-mind/hive.db && echo "OK" || claude-flow hive-mind init
```

### 4. Backup Regular

```bash
# Backup do database
cp .hive-mind/hive.db .hive-mind/backups/hive.db.$(date +%Y%m%d)
```

---

## 📚 Referências

- **Claude Flow Docs**: https://github.com/ruvnet/claude-flow
- **better-sqlite3**: https://github.com/WiseLibs/better-sqlite3
- **Node.js Module Versions**: https://nodejs.org/api/modules.html#modules_module_versions
- **SQLite WAL Mode**: https://www.sqlite.org/wal.html

---

## 🎯 Resultado Final

✅ **Database funcionando corretamente**
✅ **Hive Mind inicializado com sucesso**
✅ **Arquivos órfãos removidos**
✅ **Sistema pronto para uso**

**Próximos passos**:
```bash
# Criar primeiro swarm
claude-flow hive-mind spawn "seu objetivo" --auto-spawn --claude

# Verificar status
claude-flow hive-mind status
```

---

**Document Version**: 1.0.0
**Last Updated**: 2026-01-03
**Related Docs**: `docs/CLAUDE-FLOW.md`, `docs/claude-flow-node18-fix-2025-11-01.md`




