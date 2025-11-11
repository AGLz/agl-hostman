# Análise da Pasta .cursor - agl-hostman

**Data**: 2025-01-27
**Projeto**: agl-hostman (Infrastructure Management)
**Tipo**: Node.js/JavaScript (não Laravel)

---

## 📊 Resumo Executivo

A pasta `.cursor` contém **regras mistas** de diferentes tipos de projetos. Algumas são **relevantes**, outras **não aplicáveis** para este projeto de infraestrutura Node.js.

---

## ✅ Arquivos RELEVANTES e APLICÁVEIS

### 1. **Regras de Linguagem/Framework**
- ✅ `memory.mdc` - **APLICÁVEL** - Gestão de memória do AI é universal
- ✅ `task-lists.mdc` - **APLICÁVEL** - Gestão de tarefas é universal
- ✅ `primary-guide.mdc` - **APLICÁVEL** - Guia principal com contexto do projeto
- ❌ `react.mdc` - **NÃO APLICÁVEL** - Dashboard usa HTML/CSS/JS vanilla, não React
- ❌ `tailwind.mdc` - **NÃO APLICÁVEL** - Dashboard usa CSS customizado, não Tailwind
- ✅ `vuejs.mdc` - **NÃO APLICÁVEL** - Projeto não usa Vue.js
- ✅ `react-native.mdc` - **NÃO APLICÁVEL** - Não é projeto mobile

### 2. **Regras de Banco de Dados**
- ✅ `mysql.mdc` - **APLICÁVEL** - Se usar MySQL (verificar infraestrutura)
- ✅ `postgresql.mdc` - **APLICÁVEL** - Se usar PostgreSQL
- ✅ `sqlite.mdc` - **APLICÁVEL** - Se usar SQLite

### 3. **Regras de API**
- ✅ `fastapi.mdc` - **NÃO APLICÁVEL** - Projeto é Node.js/Express, não Python/FastAPI

### 4. **Regras Laravel**
- ❌ `laravel.mdc` - **NÃO APLICÁVEL** - Projeto não é Laravel
- ❌ `laravel-boost.mdc` - **NÃO APLICÁVEL** - Não é Laravel
- ❌ `add-feature-laravel.mdc` - **NÃO APLICÁVEL** - Não é Laravel
- ❌ `rule-laravel-coding-standards.mdc` - **NÃO APLICÁVEL** - Não é Laravel

### 5. **Regras Agent OS**
- ⚠️ `analyze-product.mdc` - **REFERENCIA INEXISTENTE** - Aponta para `~/.agent-os/` mas projeto tem `agent-os/` na raiz
- ⚠️ `create-spec.mdc` - **REFERENCIA INEXISTENTE** - Aponta para `~/.agent-os/` mas projeto tem `agent-os/` na raiz
- ⚠️ `create-tasks.mdc` - **REFERENCIA PARCIALMENTE CORRETA** - Aponta para `.agent-os/` (relativo) que existe
- ⚠️ `execute-tasks.mdc` - **REFERENCIA INEXISTENTE** - Aponta para `~/.agent-os/` mas projeto tem `agent-os/` na raiz
- ⚠️ `plan-product.mdc` - **REFERENCIA INEXISTENTE** - Aponta para `~/.agent-os/` mas projeto tem `agent-os/` na raiz

**Observação**: O projeto TEM uma pasta `agent-os/` na raiz, mas a maioria das regras referenciam `~/.agent-os/` (home directory). Apenas `create-tasks.mdc` usa caminho relativo correto.

---

## 🔧 Arquivos de Configuração

### 1. **mcp.json**
```json
{
  "mcpServers": {
    "laravel-boost": {
      "command": "php",
      "args": ["./artisan", "boost:mcp"]
    },
    "shadcn": {
      "command": "npx",
      "args": ["shadcn@latest", "mcp"]
    }
  }
}
```

**Análise**:
- ❌ `laravel-boost` - **NÃO APLICÁVEL** - Projeto não é Laravel, não tem `artisan`
- ✅ `shadcn` - **CONDICIONAL** - Aplicável se usar componentes shadcn/ui

### 2. **mcp-config.json**
```json
{
  "mcpServers": {
    "playwright": {
      "cwd": "/mnt/overpower/apps/dev/agl/apis-evo/api9",
      ...
    },
    "archon": {
      "cwd": "/mnt/overpower/apps/dev/agl/apis-evo/api9",
      ...
    }
  }
}
```

**Análise**:
- ⚠️ **CAMINHOS ABSOLUTOS ERRADOS** - Apontam para `api9`, não para `agl-hostman`
- ⚠️ **DEVE SER CORRIGIDO** - Caminhos devem apontar para este projeto

---

## 📋 Problemas Identificados

### 🔴 Críticos

1. **Regras Laravel Inaplicáveis**
   - 4 arquivos de regras Laravel em projeto Node.js
   - **Ação**: Remover ou mover para `.cursor/rules/archive/`

2. **Caminhos Absolutos Incorretos**
   - `mcp-config.json` aponta para projeto `api9` diferente
   - **Ação**: Corrigir caminhos ou remover se não aplicável

3. **Referências Agent OS Quebradas**
   - Regras apontam para `~/.agent-os/` mas projeto tem `agent-os/` na raiz
   - **Ação**: Corrigir referências ou criar estrutura esperada

### 🟡 Moderados

4. **Regras Não Aplicáveis Confirmadas**
   - React, Tailwind - confirmado que não são usados (dashboard é vanilla JS)
   - MySQL, PostgreSQL - verificar se são usados na infraestrutura
   - **Ação**: Remover React/Tailwind, verificar bancos de dados

5. **MCP Laravel Boost Configurado**
   - Configuração para Laravel em projeto Node.js
   - **Ação**: Remover se não aplicável

### 🟢 Menores

6. **Regras Vue.js, React Native, React e Tailwind**
   - Não aplicáveis confirmados (dashboard é vanilla JS)
   - **Ação**: Mover para archive junto com Laravel

---

## ✅ Recomendações

### Ações Imediatas

1. **Remover Regras Laravel**
   ```bash
   # Mover para archive
   mkdir -p .cursor/rules/archive
   mv .cursor/rules/laravel*.mdc .cursor/rules/archive/
   mv .cursor/rules/add-feature-laravel.mdc .cursor/rules/archive/
   mv .cursor/rules/rule-laravel-coding-standards.mdc .cursor/rules/archive/
   ```

2. **Corrigir mcp-config.json**
   - Remover configurações de `api9`
   - Ou atualizar caminhos para este projeto
   - Ou remover arquivo se não usado

3. **Corrigir Referências Agent OS**
   - Verificar estrutura `agent-os/` existente
   - Atualizar regras para apontar corretamente
   - Ou criar symlink `~/.agent-os` → `./agent-os`

4. **Verificar Regras Condicionais**
   - Verificar se projeto usa React (`src/dashboard`)
   - Verificar se usa Tailwind CSS
   - Verificar bancos de dados usados
   - Manter apenas os aplicáveis

### Estrutura Recomendada

```
.cursor/
├── rules/
│   ├── primary-guide.mdc ✅
│   ├── memory.mdc ✅
│   ├── task-lists.mdc ✅
│   ├── (react.mdc removido - não usa React)
│   ├── (tailwind.mdc removido - não usa Tailwind)
│   ├── mysql.mdc ⚠️ (verificar uso)
│   ├── postgresql.mdc ⚠️ (verificar uso)
│   ├── sqlite.mdc ⚠️ (verificar uso)
│   ├── archive/
│   │   ├── laravel.mdc
│   │   ├── laravel-boost.mdc
│   │   ├── add-feature-laravel.mdc
│   │   ├── rule-laravel-coding-standards.mdc
│   │   ├── vuejs.mdc
│   │   ├── react-native.mdc
│   │   ├── react.mdc
│   │   ├── tailwind.mdc
│   │   └── fastapi.mdc
│   └── agent-os/
│       ├── analyze-product.mdc (corrigir referências)
│       ├── create-spec.mdc (corrigir referências)
│       ├── create-tasks.mdc (corrigir referências)
│       ├── execute-tasks.mdc (corrigir referências)
│       └── plan-product.mdc (corrigir referências)
├── mcp.json (remover laravel-boost)
├── mcp-config.json (corrigir caminhos ou remover)
└── logs/
```

---

## 📊 Estatísticas

| Categoria | Total | Aplicáveis | Não Aplicáveis | Condicionais |
|-----------|-------|------------|----------------|--------------|
| **Regras** | 20 | 3 | 11 | 6 |
| **Configs** | 2 | 0 | 1 | 1 |
| **Total** | 22 | 3 (14%) | 12 (55%) | 7 (32%) |

---

## 🎯 Conclusão

A pasta `.cursor` foi copiada de outro projeto (provavelmente Laravel) e contém **muitas regras não aplicáveis** para este projeto Node.js de infraestrutura.

**Prioridade de Ação**:
1. 🔴 **Alta**: Remover regras Laravel e corrigir caminhos MCP
2. 🟡 **Média**: Verificar e manter apenas regras condicionais aplicáveis
3. 🟢 **Baixa**: Organizar estrutura e documentar

**Impacto**: Regras não aplicáveis podem confundir o AI e gerar sugestões incorretas.

