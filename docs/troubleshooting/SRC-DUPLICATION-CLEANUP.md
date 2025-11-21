# Limpeza de Estrutura Duplicada src/src/

**Data**: 2025-11-11
**Ação**: Remoção de diretório duplicado obsoleto
**Status**: ✅ Concluído

---

## 🚨 Problema Identificado

Foi detectada uma estrutura Laravel duplicada e obsoleta em:
```
/mnt/overpower/apps/dev/agl/agl-hostman/src/src/
```

Este diretório continha uma instalação Laravel base antiga (93MB) que não deveria existir na estrutura do projeto.

---

## 📊 Comparação dos Arquivos .env

### src/.env (ATIVO - Mantido)
```env
APP_NAME="AGL Infrastructure Admin"
APP_ENV=local
APP_KEY=base64:mn5e+ovoaKXd2rzKMBVaEgWjj8ctWcGPBzaDQSMHsxg=
APP_DEBUG=true
APP_URL=http://localhost:8080

APP_LOCALE=pt_BR
APP_FALLBACK_LOCALE=en
APP_FAKER_LOCALE=pt_BR
APP_TIMEZONE=America/Sao_Paulo
```

### src/src/.env (DUPLICADO - Removido)
```env
APP_NAME=Laravel
APP_ENV=local
APP_KEY=base64:bH26OTvu03rHha8M/emSL4W/xTXV3BdxKLUtutnA/6k=
APP_DEBUG=true
APP_URL=http://localhost

APP_LOCALE=en
APP_FALLBACK_LOCALE=en
APP_FAKER_LOCALE=en_US
```

**Diferenças Críticas**:
- APP_NAME: "AGL Infrastructure Admin" vs "Laravel" (padrão)
- APP_KEY: Chaves diferentes (risco de conflito)
- Locale: pt_BR (configurado) vs en (padrão)
- Timezone: America/Sao_Paulo vs UTC (padrão)

---

## ✅ Ação Executada

### 1. Backup de Segurança
```bash
tar -czf /tmp/src-src-backup-20251111-HHMMSS.tar.gz \
  /mnt/overpower/apps/dev/agl/agl-hostman/src/src/
```

**Localização do Backup**: `/tmp/src-src-backup-20251111-*.tar.gz`
**Tamanho**: ~93MB compactado

### 2. Remoção do Diretório Duplicado
```bash
rm -rf /mnt/overpower/apps/dev/agl/agl-hostman/src/src/
```

### 3. Validação Pós-Remoção
- ✅ `src/.env` mantido e ativo
- ✅ Estrutura de diretórios correta
- ✅ `src/src/` removido completamente
- ✅ 93MB de espaço liberado

---

## 📁 Estrutura Correta (Após Limpeza)

```
/mnt/overpower/apps/dev/agl/agl-hostman/
├── docs/                    # Documentação do projeto
│   ├── INFRA.md
│   ├── ARCHON.md
│   ├── WORKFLOWS.md
│   └── troubleshooting/
│       └── SRC-DUPLICATION-CLEANUP.md  # Este arquivo
├── src/                     # Laravel app ROOT (ÚNICO)
│   ├── app/
│   │   ├── Console/
│   │   ├── Exceptions/
│   │   ├── Http/
│   │   │   ├── Controllers/
│   │   │   └── Middleware/
│   │   ├── Livewire/
│   │   │   ├── RolePermissionManager.php
│   │   │   ├── RoleTable.php
│   │   │   ├── RoleUsersList.php
│   │   │   ├── UserActivityLog.php
│   │   │   ├── UserQuickActions.php
│   │   │   ├── UserRoleManager.php
│   │   │   └── UserTable.php
│   │   ├── Models/
│   │   │   ├── AuditLog.php
│   │   │   ├── PhysicalLocation.php
│   │   │   └── User.php
│   │   ├── Providers/
│   │   └── Repositories/
│   ├── bootstrap/
│   ├── config/
│   ├── database/
│   │   ├── migrations/
│   │   │   ├── 2024_11_08_000001_add_rbac_fields_to_users_table.php
│   │   │   ├── 2024_11_08_000002_create_audit_logs_table.php
│   │   │   └── ...
│   │   └── seeders/
│   │       ├── RolesAndPermissionsSeeder.php
│   │       └── ...
│   ├── public/
│   ├── resources/
│   │   ├── css/
│   │   ├── js/
│   │   └── views/
│   │       ├── auth/
│   │       │   ├── login.blade.php
│   │       │   ├── register.blade.php
│   │       │   ├── forgot-password.blade.php
│   │       │   └── reset-password.blade.php
│   │       ├── users/
│   │       │   ├── index.blade.php
│   │       │   ├── show.blade.php
│   │       │   ├── create.blade.php
│   │       │   └── edit.blade.php
│   │       ├── roles/
│   │       │   ├── index.blade.php
│   │       │   ├── show.blade.php
│   │       │   ├── create.blade.php
│   │       │   └── edit.blade.php
│   │       └── livewire/
│   │           ├── role-permission-manager.blade.php
│   │           ├── role-table.blade.php
│   │           ├── role-users-list.blade.php
│   │           ├── user-activity-log.blade.php
│   │           ├── user-quick-actions.blade.php
│   │           ├── user-role-manager.blade.php
│   │           └── user-table.blade.php
│   ├── routes/
│   ├── storage/
│   ├── tests/
│   ├── vendor/
│   ├── .env                 # Configuração ATIVA
│   ├── .env.example
│   ├── artisan
│   ├── composer.json
│   ├── composer.lock
│   ├── package.json
│   └── vite.config.js
└── README.md
```

---

## 🔍 Causa Provável da Duplicação

Possíveis origens do problema:

1. **Composer create-project mal executado**:
   ```bash
   # ERRADO (cria src/src/)
   cd /mnt/overpower/apps/dev/agl/agl-hostman/src
   composer create-project laravel/laravel src

   # CORRETO
   cd /mnt/overpower/apps/dev/agl/agl-hostman
   composer create-project laravel/laravel src
   ```

2. **Clone Git dentro de diretório existente**:
   ```bash
   # ERRADO (clona dentro de src/)
   cd src/
   git clone <repo> src

   # CORRETO
   cd /mnt/overpower/apps/dev/agl/agl-hostman
   git clone <repo> src
   ```

3. **Script de Deploy com path incorreto**:
   ```bash
   # ERRADO
   rsync -av source/ /path/to/src/src/

   # CORRETO
   rsync -av source/ /path/to/src/
   ```

---

## 🛡️ Prevenção Futura

### 1. Validação de Estrutura no Deploy

Adicionar check em scripts de deploy:

```bash
# deploy.sh
if [ -d "$APP_ROOT/src/src" ]; then
    echo "❌ ERRO: Estrutura duplicada detectada em src/src/"
    echo "Execute limpeza antes do deploy"
    exit 1
fi
```

### 2. Atualizar .gitignore

Garantir que `.gitignore` está correto:

```gitignore
# .gitignore (na raiz do repositório)
/src/vendor/
/src/node_modules/
/src/public/hot
/src/public/storage
/src/storage/*.key
/src/.env
/src/.env.backup
/src/.phpunit.result.cache

# Prevenir duplicações acidentais
/src/src/
```

### 3. Documentação de Deploy

Atualizar documentação de deploy com comandos corretos e validações.

---

## 📝 Validação Pós-Limpeza

### Checklist de Verificação

- [x] Backup criado em `/tmp/src-src-backup-*.tar.gz`
- [x] Diretório `src/src/` removido completamente
- [x] Arquivo `src/.env` mantido e ativo
- [x] Estrutura de diretórios correta (sem duplicações)
- [x] 93MB de espaço em disco liberado
- [x] Documentação atualizada

### Comandos de Verificação

```bash
# Verificar que src/src/ não existe mais
ls -la /mnt/overpower/apps/dev/agl/agl-hostman/src/ | grep "src$"
# Saída esperada: nenhuma linha com "src$"

# Verificar que .env está correto
head -10 /mnt/overpower/apps/dev/agl/agl-hostman/src/.env
# Saída esperada: APP_NAME="AGL Infrastructure Admin"

# Verificar estrutura Laravel
ls -la /mnt/overpower/apps/dev/agl/agl-hostman/src/app/
# Saída esperada: Console, Exceptions, Http, Livewire, Models, etc.
```

---

## 🔄 Rollback (Se Necessário)

Caso seja necessário restaurar o backup:

```bash
# Extrair backup
cd /
tar -xzf /tmp/src-src-backup-20251111-HHMMSS.tar.gz

# Validar extração
ls -la /mnt/overpower/apps/dev/agl/agl-hostman/src/src/
```

**⚠️ ATENÇÃO**: O rollback deve ser feito apenas se algum arquivo crítico for identificado no backup. A estrutura duplicada **NÃO** deve ser mantida.

---

## ✅ Resultado Final

- **Espaço Liberado**: 93MB
- **Estrutura**: Corrigida e validada
- **Backup**: Disponível em `/tmp/` por segurança
- **Configuração**: `src/.env` mantido e funcional
- **Impacto**: Zero (diretório duplicado não era usado)

---

**Executado por**: Claude Code (agl-hostman Phase 5)
**Aprovado por**: Usuário
**Registro**: docs/troubleshooting/SRC-DUPLICATION-CLEANUP.md
