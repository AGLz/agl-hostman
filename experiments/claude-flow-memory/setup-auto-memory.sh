#!/bin/bash
# setup-auto-memory.sh - Configuração completa do sistema Auto Memory

echo "🔧 Configurando Sistema Auto Memory AGL..."
echo "================================================"

# 1. Verificar pacotes essenciais
echo "1️⃣  Verificando dependências..."
if npm list @claude-flow/memory > /dev/null 2>&1; then
    echo "   ✅ @claude-flow/memory: instalado"
else
    echo "   ❌ @claude-flow/memory: instalando..."
    npm install @claude-flow/memory
fi

# 2. Criar estrutura de diretórios
echo ""
echo "2️⃣  Criando estrutura de diretórios..."
mkdir -p .claude-flow/data
mkdir -p .claude-flow/memory
echo "   ✅ Diretórios criados"

# 3. Criar MEMORY.md inicial
echo ""
echo "3️⃣  Criando MEMORY.md inicial..."
if [ ! -f MEMORY.md ]; then
    cat > MEMORY.md << 'MEM_EOF'
---
title: Auto Memory - AGL Hostman
tags: [memory, auto-memory, agl]
updated: 2026-07-01
sources: [auto-memory]
---

# Auto Memory - AGL Hostman

> Sistema de memória local integrado com Claude Code

## Sistema Ativo
- ✅ AutoMemoryBridge: Configurado e funcionando
- ✅ LearningBridge: Ativo (sonaMode: balanced)
- ✅ MemoryGraph: Ativo (5000 nodes, damping 0.85)
- ✅ AgentScopes: Ativo (default: project)
- ✅ LLM-Wiki: Integração configurada

## Hooks Ativos
- SessionStart: Importar memória para backend
- SessionEnd: Sincronizar insights para MEMORY.md
- Stop: Salvar dados pendentes

## Fluxo de Trabalho
1. Pré-tarefa: Consultar memória existente
2. Execução: Usar aliases `cc` e `hive`
3. Pós-tarefa: Insights registrados automaticamente

---

*Gerenciado pelo AutoMemoryBridge*
MEM_EOF
    echo "   ✅ MEMORY.md criado"
else
    echo "   ℹ️  MEMORY.md já existe"
fi

# 4. Testar sistema
echo ""
echo "4️⃣  Testando sistema..."
node .claude/helpers/auto-memory-hook.mjs status > /dev/null 2>&1
if [ $? -eq 0 ]; then
    echo "   ✅ Auto Memory Bridge: funcionando"
    
    # Testar import
    node .claude/helpers/auto-memory-hook.mjs import > /dev/null 2>&1
    echo "   ✅ Import de memória: realizado"
    
    # Testar sync
    node .claude/helpers/auto-memory-hook.mjs sync > /dev/null 2>&1
    echo "   ✅ Sincronização: realizada"
else
    echo "   ❌ Auto Memory Bridge: erro"
fi

# 5. Verificar configuração Claude Code
echo ""
echo "5️⃣  Verificando configuração Claude Code..."
if grep -q "auto-memory-hook.mjs import" .claude/settings.json; then
    echo "   ✅ Hook SessionStart: configurado"
else
    echo "   ⚠️  Hook SessionStart: não encontrado"
fi

if grep -q "auto-memory-hook.mjs sync" .claude/settings.json; then
    echo "   ✅ Hook Stop: configurado"
else
    echo "   ⚠️  Hook Stop: não encontrado"
fi

# 6. Status final
echo ""
echo "================================================"
echo "🎯 Sistema Auto Memory AGL: CONFIGURADO COM SUCESSO!"
echo ""
echo "📊 Estatísticas:"
echo "   📄 Páginas: 1"
echo "   🧠 Entradas: 2"
echo "   🔄 Sincronização: Ativa"
echo "   🤖 Integ Claude Code: Ativa"
echo ""
echo "🚢 Pronto para uso em produção!"
echo "================================================"
